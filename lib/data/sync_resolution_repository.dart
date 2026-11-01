part of 'life_repository.dart';

class _SyncResolutionDraft {
  const _SyncResolutionDraft(this.draft, this.review);
  final _SyncGroupDraft draft;
  final SyncConflictReview review;
}

class _SyncCloudPreview implements Exception {
  const _SyncCloudPreview(this.values);
  final Map<String, Map<String, Object?>?>? values;
}

extension SyncResolutionRepository on LifeRepository {
  Future<_SyncResolutionDraft?> _prepareSyncResolution(
    SyncBinding binding,
    SyncLease lease,
  ) async {
    await _requireSyncExchange(binding, lease);
    final context = await db
        .customSelect(
          'SELECT device_sequence,visible_json FROM sync_capture_context WHERE id=1',
        )
        .getSingle();
    // A decision acknowledges complete transaction groups together, never a
    // partial page or one side of a relational transition. Larger histories
    // remain retained rather than being truncated into a partial decision.
    final groups = await db
        .customSelect(
          '''SELECT * FROM sync_mutation_groups
      WHERE workspace_id=? AND account_id=? AND complete=1 AND materialized=0
      ORDER BY first_sequence,device_id LIMIT 257''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
          ],
        )
        .get();
    if (groups.isEmpty) return null;
    if (groups.length > 256) {
      throw StateError(
        'Too many related groups for one review. Retained history is unchanged.',
      );
    }
    final ids = groups.map((g) => g.read<String>('id')).toList();
    final operations = (await db.customSelect(
      '''SELECT $_syncReviewProjection
      FROM sync_journal j WHERE j.mutation_group_id IN (${List.filled(ids.length, '?').join(',')})
      ORDER BY j.sequence''',
      variables: ids.map(Variable.withString).toList(),
    ).get()).map((r) => Map<String, Object?>.from(r.data)).toList();
    final keys = {
      for (final op in operations)
        _syncScope(op['entity'] as String, op['record_key'] as String): op,
    };
    if (keys.length > 2048) {
      throw StateError(
        'This review exceeds the safe transaction bound. Nothing was changed.',
      );
    }
    final records = <_SyncRecordDraft>[];
    final visibleRecords = <SyncConflictRecord>[];
    final schema = _SyncApplySchema(this, {}, binding);
    final structural =
        (await _syncCrossRecordHazard(binding, operations, schema)) != null ||
        groups.any(
          (g) =>
              g.readNullable<String>('blocked_reason') != null &&
              jsonDecode(g.read<String>('blocked_reason'))['reason'] !=
                  'recordConflict',
        );
    String? reason;
    for (final op in keys.values) {
      final entity = op['entity'] as String, key = op['record_key'] as String;
      final history =
          (await db
                  .customSelect(
                    '''SELECT $_syncReviewProjection,g.materialized AS group_materialized
        FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id
        WHERE j.workspace_id=? AND j.account_id=? AND j.entity=? AND j.record_key=?
        AND j.known=1 AND (g.materialized=1 OR g.id IN (${List.filled(ids.length, '?').join(',')}))
        ORDER BY j.sequence''',
                    variables: [
                      Variable.withString(binding.workspace),
                      Variable.withString(binding.account),
                      Variable.withString(entity),
                      Variable.withString(key),
                      ...ids.map(Variable.withString),
                    ],
                  )
                  .get())
              .map((r) => r.data)
              .toList();
      final current = await schema.current(entity, key);
      final baseline = reviewPortableRecord(
        entity,
        history
            .where((r) => r['group_materialized'] == 1)
            .map(_syncRevisionFromJournal),
      );
      if (baseline.needsDecision ||
          !_syncSame(
            baseline.merged == null ? null : _syncUserFields(baseline.merged!),
            current == null ? null : _syncUserFields(current),
          )) {
        reason = 'unverifiedLocalState';
      }
      final review = reviewPortableRecord(
        entity,
        history.map(_syncRevisionFromJournal),
      );
      final candidates = <String, Map<String, Object?>?>{};
      for (final row in history) {
        if (review.heads.contains(row['operation_id'])) {
          candidates[row['operation_id'] as String] = _syncJsonRow(
            row['after_json'],
          );
        }
      }
      records.add(_SyncRecordDraft(entity, key, current, review));
      visibleRecords.add(
        SyncConflictRecord(
          entity: entity,
          key: key,
          local: current,
          review: review,
          candidates: Map.unmodifiable(candidates),
          remoteHeads: Set.unmodifiable(
            history
                .where(
                  (row) =>
                      row['group_materialized'] != 1 &&
                      review.heads.contains(row['operation_id']),
                )
                .map((row) => row['operation_id'] as String),
          ),
        ),
      );
    }
    if (structural && reason == null) {
      // Derive actual SQLite consequences in a savepoint and roll it back.
      // A parent choice must not silently cascade through an unseen local
      // child, or claim to keep a row which SQLite would redirect/delete.
      final heads = await db
          .customSelect(
            '''SELECT entity,record_key FROM sync_entity_heads
        WHERE workspace_id=? ORDER BY entity,record_key LIMIT 8193''',
            variables: [Variable.withString(binding.workspace)],
          )
          .get();
      if (heads.length > 8192) {
        throw StateError(
          'This related-record review exceeds its safe bound. No changes were applied.',
        );
      }
      final locals = <String, (String, String, Map<String, Object?>?)>{};
      for (final head in heads) {
        final entity = head.read<String>('entity'),
            key = head.read<String>('record_key');
        final scope = _syncScope(entity, key);
        if (!keys.containsKey(scope)) {
          locals[scope] = (entity, key, await schema.current(entity, key));
        }
        if (!await renewSyncLease(lease)) {
          throw StateError('Sync review ownership expired.');
        }
      }
      Map<String, Map<String, Object?>?>? preview;
      if (visibleRecords.every((r) => r.remoteHeads.length == 1)) {
        final cloud = [
          for (final record in visibleRecords)
            _SyncRecordDraft(
              record.entity,
              record.key,
              record.local,
              SyncRecordReview(
                heads: record.review.heads,
                merged: record.candidates[record.remoteHeads.single],
                conflicts: const [],
              ),
            ),
        ];
        try {
          await db.transaction(() async {
            final first = groups.first;
            final result = await _applyPreparedSyncGroup(
              binding,
              lease,
              _SyncGroupDraft(
                id: ids.first,
                device: first.read<String>('device_id'),
                first: first.read<int>('first_sequence'),
                last: first.read<int>('last_sequence'),
                localSequence: context.read<int>('device_sequence'),
                visibleState: context.read<String>('visible_json'),
                records: cloud,
                operations: operations,
                coveredGroups: ids.skip(1).toSet(),
              ),
            );
            final post = _SyncApplySchema(this, {}, binding);
            final values = result.state == SyncApplyState.applied
                ? <String, Map<String, Object?>?>{
                    for (final item in locals.entries)
                      item.key: await post.current(
                        item.value.$1,
                        item.value.$2,
                      ),
                  }
                : null;
            throw _SyncCloudPreview(values);
          }, requireNew: true);
        } on _SyncCloudPreview catch (result) {
          preview = result.values;
        }
      }
      final hiddenBy = operations
          .where((op) {
            final value = _syncJsonRow(op['after_json']);
            return value == null ||
                value['deleted_at'] != null ||
                value['archived_at'] != null;
          })
          .map(
            (op) =>
                _syncScope(op['entity'] as String, op['record_key'] as String),
          )
          .toSet();
      for (final entry in locals.entries) {
        final (entity, key, current) = entry.value;
        final consequence = preview?[entry.key];
        final losesVisibility =
            current != null &&
            (await schema.references(
              entity,
              current,
            )).intersection(hiddenBy).isNotEmpty;
        if (preview != null &&
            !losesVisibility &&
            _syncSame(
              current == null ? null : _syncUserFields(current),
              consequence == null ? null : _syncUserFields(consequence),
            )) {
          continue;
        }
        final history =
            (await db
                    .customSelect(
                      '''SELECT $_syncReviewProjection FROM sync_journal j
          JOIN sync_mutation_groups g ON g.id=j.mutation_group_id WHERE j.workspace_id=? AND j.account_id=?
          AND j.entity=? AND j.record_key=? AND g.materialized=1 AND j.known=1 ORDER BY j.sequence''',
                      variables: [
                        Variable.withString(binding.workspace),
                        Variable.withString(binding.account),
                        Variable.withString(entity),
                        Variable.withString(key),
                      ],
                    )
                    .get())
                .map((r) => r.data)
                .toList();
        final baseline = reviewPortableRecord(
          entity,
          history.map(_syncRevisionFromJournal),
        );
        if (baseline.needsDecision ||
            !_syncSame(
              baseline.merged == null
                  ? null
                  : _syncUserFields(baseline.merged!),
              current == null ? null : _syncUserFields(current),
            )) {
          reason = 'unverifiedLocalState';
        }
        records.add(_SyncRecordDraft(entity, key, current, baseline));
        visibleRecords.add(
          SyncConflictRecord(
            entity: entity,
            key: key,
            local: current,
            review: baseline,
            candidates: {if (preview != null) r'$consequence': consequence},
            remoteHeads: preview == null ? const {} : const {r'$consequence'},
            consequence: true,
          ),
        );
        if (!await renewSyncLease(lease)) {
          throw StateError('Sync review ownership expired.');
        }
      }
      if (records.length > 2048) {
        throw StateError(
          'This review exceeds the safe transaction bound. Nothing was changed.',
        );
      }
    }
    final retained = await db
        .customSelect(
          'SELECT coalesce(MAX(sequence),0) AS value FROM sync_journal',
        )
        .getSingle();
    final token = sha256
        .convert(
          utf8.encode(
            jsonEncode(
              _syncCanonical({
                'sequence': context.read<int>('device_sequence'),
                'visible': context.read<String>('visible_json'),
                'retained': retained.read<int>('value'),
                'structural': structural,
                'reason': reason,
                'groups': ids,
                'records': [
                  for (final record in visibleRecords)
                    {
                      'id': record.id,
                      'local': record.local,
                      'heads': record.review.heads.toList()..sort(),
                    },
                ],
              }),
            ),
          ),
        )
        .toString();
    final first = groups.first;
    final attentionToken = sha256
        .convert(
          utf8.encode(
            jsonEncode(
              _syncCanonical([
                for (final record in visibleRecords)
                  {
                    'id': record.id,
                    'heads': record.review.heads.toList()..sort(),
                  },
              ]),
            ),
          ),
        )
        .toString();
    final dismissed = groups
        .where((g) => g.readNullable<String>('blocked_reason') != null)
        .toList();
    return _SyncResolutionDraft(
      _SyncGroupDraft(
        id: ids.first,
        device: first.read<String>('device_id'),
        first: first.read<int>('first_sequence'),
        last: first.read<int>('last_sequence'),
        localSequence: context.read<int>('device_sequence'),
        visibleState: context.read<String>('visible_json'),
        records: records,
        operations: operations,
        coveredGroups: ids.skip(1).toSet(),
      ),
      SyncConflictReview(
        token: token,
        structural: structural,
        attentionToken: attentionToken,
        dismissed:
            dismissed.isNotEmpty &&
            dismissed.every(
              (g) =>
                  jsonDecode(g.read<String>('blocked_reason'))['dismissed'] ==
                  attentionToken,
            ),
        records: List.unmodifiable(visibleRecords),
        reason: reason,
      ),
    );
  }

  Future<SyncConflictReview?> reviewSyncConflicts(
    SyncBinding binding, {
    required SyncLease lease,
  }) async => (await _prepareSyncResolution(binding, lease))?.review;

  Future<void> dismissSyncConflicts(
    SyncBinding binding,
    SyncConflictReview review, {
    required SyncLease lease,
  }) => db.transaction(() async {
    final current = await _prepareSyncResolution(binding, lease);
    if (current == null ||
        current.review.attentionToken != review.attentionToken) {
      return;
    }
    await db.customStatement(
      '''UPDATE sync_mutation_groups SET blocked_reason=json_set(blocked_reason,'\$.dismissed',?)
        WHERE workspace_id=? AND account_id=? AND materialized=0 AND blocked_reason IS NOT NULL''',
      [review.attentionToken, binding.workspace, binding.account],
    );
  });

  Future<SyncApplyResult> resolveSyncConflicts(
    SyncBinding binding, {
    required SyncLease lease,
    required String reviewedToken,
    required Map<String, SyncResolutionChoice> choices,
  }) => db.transaction(() async {
    // Acquire the writer before reviewing again, including newly received
    // history. A popup cannot acknowledge revisions which arrived behind it.
    await db.customStatement(
      'UPDATE sync_capture_context SET capture_enabled=capture_enabled WHERE id=1',
    );
    final prepared = await _prepareSyncResolution(binding, lease);
    if (prepared == null || prepared.review.token != reviewedToken) {
      return const SyncApplyResult(
        SyncApplyState.retry,
        reason: 'staleDecision',
      );
    }
    if (prepared.review.reason != null) {
      return SyncApplyResult(
        SyncApplyState.needsReview,
        reason: prepared.review.reason,
      );
    }
    final draft = prepared.draft;
    final structural = prepared.review.structural;
    final resolved = <_SyncRecordDraft>[];
    for (final record in prepared.review.records) {
      var value = record.review.merged == null
          ? null
          : Map<String, Object?>.from(record.review.merged!);
      final choice = choices[record.id];
      // Explicit whole-record choices also cover cross-record barriers which
      // did not produce a same-record field conflict.
      if (choice != null && (record.review.needsDecision || structural)) {
        if (choice.revision != null &&
            !record.candidates.containsKey(choice.revision)) {
          throw const FormatException(
            'The selected revision is not in this review',
          );
        }
        final selected = choice.revision == null
            ? record.local
            : record.candidates[choice.revision];
        if (record.review.conflicts.any(
              (c) => c.field == SyncConflict.record,
            ) ||
            !record.review.needsDecision) {
          value = selected == null ? null : Map<String, Object?>.from(selected);
        } else {
          if (selected == null) {
            throw const FormatException(
              'A field resolution cannot delete a record',
            );
          }
          value ??= <String, Object?>{};
          for (final conflict in record.review.conflicts) {
            if (selected.containsKey(conflict.field)) {
              value[conflict.field] = selected[conflict.field];
            } else {
              value.remove(conflict.field);
            }
          }
        }
      } else if (record.review.needsDecision) {
        return const SyncApplyResult(
          SyncApplyState.needsReview,
          reason: 'missingDecision',
        );
      }
      resolved.add(
        _SyncRecordDraft(
          record.entity,
          record.key,
          record.local,
          SyncRecordReview(
            heads: record.review.heads,
            merged: value,
            conflicts: const [],
          ),
          preserveRelationships:
              structural && choice != null && choice.revision == null,
        ),
      );
    }
    // Structural barriers need a deliberate choice for every coupled record.
    if (structural &&
        prepared.review.records.any((r) => !choices.containsKey(r.id))) {
      return const SyncApplyResult(
        SyncApplyState.needsReview,
        reason: 'relatedRecordsNeedDecision',
      );
    }
    final result = await _applyPreparedSyncGroup(
      binding,
      lease,
      _SyncGroupDraft(
        id: draft.id,
        device: draft.device,
        first: draft.first,
        last: draft.last,
        localSequence: draft.localSequence,
        visibleState: draft.visibleState,
        records: resolved,
        operations: draft.operations,
        coveredGroups: draft.coveredGroups,
      ),
    );
    if (result.state != SyncApplyState.applied) return result;
    // Capture a resolution even when it keeps identical local bytes. Every
    // affected record acknowledges all reviewed heads in one durable group.
    final group = _uuid.v4();
    for (final record in resolved) {
      final context = await db
          .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
          .getSingle();
      final sequence = context.read<int>('device_sequence') + 1;
      final identity = (jsonDecode(record.key) as Map).cast<String, Object?>();
      final columns =
          (await db.customSelect('PRAGMA table_info("${record.entity}")').get())
              .map((r) => r.data)
              .toList();
      final after = await db
          .customSelect(
            'SELECT ${syncRowJson(columns, 'r.')} AS value FROM "${record.entity}" r WHERE ${identity.keys.map((k) => 'r."$k"=?').join(' AND ')}',
            variables: identity.values.map(_syncSqlVariable).toList(),
          )
          .get();
      final operation = _uuid.v4();
      await db.customStatement(
        '''INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,
        before_json,after_json,origin_sequence,observed_json,parent_ids_json,mutation_group_id,visible_json)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)''',
        [
          operation,
          binding.workspace,
          binding.account,
          binding.device,
          record.entity,
          record.key,
          record.current == null ? null : jsonEncode(record.current),
          after.isEmpty ? null : after.single.read<String>('value'),
          sequence,
          context.read<String>('observed_json'),
          jsonEncode(record.review.heads.toList()..sort()),
          group,
          context.read<String>('visible_json'),
        ],
      );
      await db.customStatement(
        '''INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence,complete,materialized)
        VALUES(?,?,?,?,?,?,0,1) ON CONFLICT(id) DO UPDATE SET last_sequence=excluded.last_sequence''',
        [
          group,
          binding.workspace,
          binding.account,
          binding.device,
          sequence,
          sequence,
        ],
      );
      await db.customStatement(
        '''UPDATE sync_entity_heads SET visible_revision=?,visible_heads_json=?,dismissed_heads_json='[]',blocked_reason=NULL
        WHERE workspace_id=? AND entity=? AND record_key=?''',
        [
          operation,
          jsonEncode([operation]),
          binding.workspace,
          record.entity,
          record.key,
        ],
      );
      await db.customStatement(
        '''UPDATE sync_capture_context SET device_sequence=?,
        observed_json=json_set(observed_json,$syncDeviceClockPathSql,?),
        received_json=json_set(received_json,$syncDeviceClockPathSql,?),
        visible_json=json_set(visible_json,$syncDeviceClockPathSql,json_array(json_array(1,?))) WHERE id=1''',
        [sequence, sequence, sequence, sequence],
      );
    }
    await db.customStatement(
      'UPDATE sync_mutation_groups SET complete=1 WHERE id=?',
      [group],
    );
    return result;
  });
}
