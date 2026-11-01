part of 'life_repository.dart';

String _syncScope(String entity, String key) =>
    jsonEncode([entity, _syncCanonical(jsonDecode(key))]);

String _syncMetadataJson(String column) =>
    '''CASE WHEN j.entity='task_resources'
  AND json_extract(j.$column,'\$.kind')='managed' THEN json_set(j.$column,'\$.content',
  json_object('\$managedSha256',json_extract(j.$column,'\$.sha256'),'\$managedBytes',json_extract(j.$column,'\$.byte_size')))
  ELSE j.$column END AS $column''';

String get _syncReviewProjection =>
    '''j.operation_id,j.workspace_id,j.account_id,j.device_id,j.entity,j.record_key,
  j.origin_sequence,j.observed_json,j.visible_json,j.parent_ids_json,j.mutation_group_id,
  ${_syncMetadataJson('before_json')},${_syncMetadataJson('after_json')}''';

Map<String, Object?>? _syncJsonRow(Object? value) => value == null
    ? null
    : (jsonDecode(value as String) as Map).cast<String, Object?>();

Map<String, Object?> _syncUserFields(Map<String, Object?> value) =>
    {...value}..remove('updated_at');

Variable _syncSqlVariable(Object? value) => switch (value) {
  null => const Variable<String>(null),
  String() => Variable.withString(value),
  int() => Variable.withInt(value),
  double() => Variable.withReal(value),
  Uint8List() => Variable.withBlob(value),
  _ => throw const FormatException('Unsupported portable SQLite field'),
};

Future<Uint8List> _syncManagedBytesInWorker(
  String hex,
  String digest,
  int length,
) => Isolate.run(() {
  if (length < 0 ||
      length > 16 * 1024 * 1024 ||
      hex.length != length * 2 ||
      !RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex)) {
    throw const FormatException('Retained managed bytes are damaged');
  }
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  if (sha256.convert(bytes).toString() != digest) {
    throw const FormatException('Retained managed bytes are damaged');
  }
  return bytes;
});

class _SyncRecordDraft {
  _SyncRecordDraft(this.entity, this.key, this.current, this.review);
  final String entity, key;
  final Map<String, Object?>? current;
  final SyncRecordReview review;
}

class _SyncGroupDraft {
  _SyncGroupDraft({
    required this.id,
    required this.device,
    required this.first,
    required this.last,
    required this.localSequence,
    required this.visibleState,
    required this.records,
    required this.operations,
    this.reason,
  });
  final String id, device, visibleState;
  final int first, last, localSequence;
  final List<_SyncRecordDraft> records;
  final List<Map<String, Object?>> operations;
  final String? reason;
}

class _SyncDomainBlock implements Exception {
  const _SyncDomainBlock(this.reason);
  final String reason;
}

class _SyncApplySchema {
  _SyncApplySchema(this.repository, this.candidate, this.binding);
  final LifeRepository repository;
  final SyncBinding binding;
  final Map<String, Map<String, Object?>> candidate;
  final _columns = <String, List<Map<String, Object?>>>{};
  final _foreign = <String, List<Map<String, Object?>>>{};
  final _rows = <String, Map<String, Object?>?>{};
  final _prior = <String, Map<String, Object?>?>{};
  Future<List<Map<String, Object?>>> columns(String table) async {
    if (!portableSyncTables.contains(table)) {
      throw const FormatException('Unknown portable record');
    }
    return _columns[table] ??=
        (await repository.db.customSelect('PRAGMA table_info("$table")').get())
            .map((r) => r.data)
            .toList();
  }

  Future<String> key(String table, Map<String, Object?> value) async {
    final primary =
        (await columns(table)).where((c) => (c['pk'] as int) > 0).toList()
          ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
    return jsonEncode({
      for (final column in primary)
        column['name'] as String: value[column['name']],
    });
  }

  Future<Map<String, Object?>?> current(String table, String key) async {
    final scope = _syncScope(table, key);
    if (_rows.containsKey(scope)) return _rows[scope];
    final fields = await columns(table);
    final identity = (jsonDecode(key) as Map).cast<String, Object?>();
    final json =
        'json_object(${fields.map((c) {
          final name = c['name'] as String;
          if (c['type'] == 'BLOB') {
            if (table != 'task_resources' || name != 'content') {
              throw const FormatException('Unsupported portable binary field');
            }
            return "'$name',CASE WHEN r.content IS NULL THEN NULL ELSE json_object('\$managedSha256',r.sha256,'\$managedBytes',r.byte_size) END";
          }
          return "'$name',r.\"$name\"";
        }).join(',')})';
    final rows = await repository.db
        .customSelect(
          'SELECT $json AS value FROM "$table" r WHERE ${identity.keys.map((k) => 'r."$k"=?').join(' AND ')}',
          variables: identity.values.map(_syncSqlVariable).toList(),
        )
        .get();
    return _rows[scope] = rows.isEmpty
        ? null
        : _syncJsonRow(rows.single.read<String>('value'));
  }

  Future<Map<String, Object?>?> reference(
    String table,
    Map<String, Object?> identity,
  ) async {
    final recordKey = await key(table, identity);
    return await current(table, recordKey) ??
        candidate[_syncScope(table, recordKey)] ??
        await prior(table, recordKey);
  }

  Future<Map<String, Object?>?> prior(String table, String key) async {
    final scope = _syncScope(table, key);
    if (_prior.containsKey(scope)) return _prior[scope];
    final rows = await repository.db
        .customSelect(
          '''SELECT $_syncReviewProjection FROM sync_journal j
      JOIN sync_mutation_groups g ON g.id=j.mutation_group_id WHERE j.workspace_id=? AND j.account_id=?
      AND j.entity=? AND j.record_key=? AND j.known=1 AND g.materialized=1 AND j.after_json IS NOT NULL
      ORDER BY j.sequence DESC LIMIT 1''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
            Variable.withString(table),
            Variable.withString(key),
          ],
        )
        .get();
    return _prior[scope] = rows.isEmpty
        ? null
        : _syncJsonRow(rows.single.data['after_json']);
  }

  Future<Set<String>> references(
    String table,
    Map<String, Object?> value,
  ) async {
    final result = <String>{};
    final visited = <String>{};
    final queue = <(String, Map<String, Object?>)>[(table, value)];
    for (var index = 0; index < queue.length; index++) {
      final (entity, row) = queue[index];
      final recordKey = await key(entity, row);
      final scope = _syncScope(entity, recordKey);
      if (!visited.add(scope)) continue;
      result.add(scope);
      final foreign = _foreign[entity] ??=
          (await repository.db
                  .customSelect('PRAGMA foreign_key_list("$entity")')
                  .get())
              .map((r) => r.data)
              .toList();
      for (final link in foreign) {
        final parent = link['table'] as String;
        if (!portableSyncTables.contains(parent)) continue;
        final value = row[link['from']];
        if (value == null) continue;
        final parentKey = {link['to'] as String: value};
        result.add(_syncScope(parent, await key(parent, parentKey)));
        final parentRow = await reference(parent, parentKey);
        if (parentRow != null) queue.add((parent, parentRow));
      }
      if (entity == 'entity_icons') {
        final parent = switch (row['kind']) {
          'task' => 'tasks',
          'project' => 'projects',
          'category' => 'categories',
          'series' => 'recurrence_series',
          _ => null,
        };
        if (parent != null) {
          result.add(_syncScope(parent, jsonEncode({'id': row['entity_id']})));
          final parentRow = await reference(parent, {'id': row['entity_id']});
          if (parentRow != null) queue.add((parent, parentRow));
        }
      }
      if (entity == 'tasks') {
        final links = await repository.db
            .customSelect(
              'SELECT parent_id FROM task_parent_links WHERE child_id=?',
              variables: [Variable.withString(row['id'] as String)],
            )
            .get();
        for (final link in links) {
          final parentRow = await reference('tasks', {
            'id': link.read<String>('parent_id'),
          });
          if (parentRow != null) queue.add(('tasks', parentRow));
        }
        final occurrences = await repository.db
            .customSelect(
              'SELECT series_id FROM recurrence_occurrences WHERE task_id=?',
              variables: [Variable.withString(row['id'] as String)],
            )
            .get();
        final seriesIds = {
          for (final occurrence in occurrences)
            occurrence.read<String>('series_id'),
          for (final entry in candidate.entries.where(
            (entry) =>
                entry.key.startsWith('["recurrence_occurrences",') &&
                entry.value['task_id'] == row['id'],
          ))
            entry.value['series_id'] as String,
        };
        for (final id in seriesIds) {
          final series = await reference('recurrence_series', {'id': id});
          if (series != null) queue.add(('recurrence_series', series));
        }
      }
      if (entity == 'recurrence_series' ||
          entity == 'progressive_plans' ||
          entity == 'progressive_plan_steps') {
        if (row['family_id'] is String) {
          result.add(jsonEncode(['recurrence-family', row['family_id']]));
        }
      }
    }
    return result;
  }
}

extension SyncApplyRepository on LifeRepository {
  Future<_SyncGroupDraft?> _prepareSyncGroup(
    SyncBinding binding,
    SyncLease lease,
  ) async {
    await _requireSyncExchange(binding, lease);
    final context = await db
        .customSelect(
          'SELECT device_sequence,visible_json FROM sync_capture_context WHERE id=1',
        )
        .getSingle();
    final eligible = await db
        .customSelect(
          '''SELECT g.* FROM sync_mutation_groups g
      WHERE g.workspace_id=? AND g.account_id=? AND g.complete=1 AND g.materialized=0
      AND (g.blocked_reason IS NULL OR CASE WHEN json_valid(g.blocked_reason) THEN
        json_extract(g.blocked_reason,'\$.sequence')!=(SELECT device_sequence FROM sync_capture_context WHERE id=1)
        OR json_extract(g.blocked_reason,'\$.visible')!=(SELECT visible_json FROM sync_capture_context WHERE id=1) ELSE 0 END)
      AND NOT EXISTS(SELECT 1 FROM sync_journal j,json_each(j.parent_ids_json) p
      JOIN sync_journal a ON a.operation_id=p.value JOIN sync_mutation_groups parent ON parent.id=a.mutation_group_id
      WHERE j.mutation_group_id=g.id AND parent.materialized=0 AND parent.id!=g.id)
      ORDER BY g.first_sequence,g.device_id LIMIT 1''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
          ],
        )
        .get();
    if (eligible.isEmpty) return null;
    final group = eligible.single;
    final id = group.read<String>('id');
    final operations =
        (await db
                .customSelect(
                  'SELECT $_syncReviewProjection FROM sync_journal j WHERE j.mutation_group_id=? ORDER BY j.origin_sequence',
                  variables: [Variable.withString(id)],
                )
                .get())
            .map((r) => Map<String, Object?>.from(r.data))
            .toList();
    final candidate = <String, Map<String, Object?>>{};
    for (final op in operations) {
      final value =
          _syncJsonRow(op['after_json']) ?? _syncJsonRow(op['before_json']);
      if (value != null) {
        candidate[_syncScope(
              op['entity'] as String,
              op['record_key'] as String,
            )] =
            value;
      }
    }
    final schema = _SyncApplySchema(this, candidate, binding);
    final records = <_SyncRecordDraft>[];
    String? reason;
    final reviewed = <String>{};
    for (final op in operations) {
      final entity = op['entity'] as String, key = op['record_key'] as String;
      if (!reviewed.add(_syncScope(entity, key))) continue;
      final history =
          (await db
                  .customSelect(
                    '''SELECT $_syncReviewProjection FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id
        WHERE j.workspace_id=? AND j.account_id=? AND j.entity=? AND j.record_key=? AND j.known=1
        AND (g.materialized=1 OR g.id=?) ORDER BY j.sequence''',
                    variables: [
                      Variable.withString(binding.workspace),
                      Variable.withString(binding.account),
                      Variable.withString(entity),
                      Variable.withString(key),
                      Variable.withString(id),
                    ],
                  )
                  .get())
              .map((r) => r.data)
              .toList();
      final current = await schema.current(entity, key);
      final baseline = reviewPortableRecord(
        entity,
        history
            .where((r) => r['mutation_group_id'] != id)
            .map(_syncRevisionFromJournal),
      );
      if (baseline.needsDecision ||
          !_syncSame(
            baseline.merged == null ? null : _syncUserFields(baseline.merged!),
            current == null ? null : _syncUserFields(current),
          )) {
        reason ??= 'unverifiedLocalState';
      }
      final review = reviewPortableRecord(
        entity,
        history.map(_syncRevisionFromJournal),
      );
      if (review.needsDecision) reason ??= 'recordConflict';
      records.add(_SyncRecordDraft(entity, key, current, review));
    }
    reason ??= await _syncCrossRecordHazard(binding, operations, schema);
    return _SyncGroupDraft(
      id: id,
      device: group.read<String>('device_id'),
      first: group.read<int>('first_sequence'),
      last: group.read<int>('last_sequence'),
      localSequence: context.read<int>('device_sequence'),
      visibleState: context.read<String>('visible_json'),
      records: records,
      operations: operations,
      reason: reason,
    );
  }

  Future<String?> _syncCrossRecordHazard(
    SyncBinding binding,
    List<Map<String, Object?>> candidate,
    _SyncApplySchema schema,
  ) async {
    final first = _syncRevisionFromJournal(candidate.first);
    final references = <String>{},
        deletions = <String>{},
        families = <String>{};
    var changesRule = false;
    final ownKeys = <String>{};
    for (final op in candidate) {
      final entity = op['entity'] as String, key = op['record_key'] as String;
      ownKeys.add(_syncScope(entity, key));
      final after = _syncJsonRow(op['after_json']);
      final before =
          _syncJsonRow(op['before_json']) ??
          await schema.current(entity, key) ??
          await schema.prior(entity, key);
      if (after == null ||
          after['deleted_at'] != null ||
          after['archived_at'] != null) {
        deletions.add(_syncScope(entity, key));
      }
      for (final value in [before, after]) {
        if (value != null) {
          references.addAll(await schema.references(entity, value));
        }
      }
      if (entity == 'recurrence_series' ||
          entity.startsWith('progressive_plan')) {
        changesRule = true;
      }
      if (entity == 'tasks' && after == null) {
        final taskId = (jsonDecode(key) as Map)['id'] as String;
        final local = await db
            .customSelect(
              'SELECT 1 FROM task_resources WHERE task_id=? AND NOT (${syncRowIsPortable('task_resources', '')}) LIMIT 1',
              variables: [Variable.withString(taskId)],
            )
            .get();
        if (local.isNotEmpty) return 'deviceLocalResources';
      }
    }
    families.addAll(
      references.where((scope) => scope.startsWith('["recurrence-family",')),
    );
    final heads = await db
        .customSelect(
          '''SELECT DISTINCT $_syncReviewProjection FROM sync_entity_heads h,
      json_each(h.visible_heads_json) v JOIN sync_journal j ON j.operation_id=v.value
      WHERE h.workspace_id=? AND j.account_id=?''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
          ],
        )
        .get();
    for (final head in heads) {
      final row = head.data;
      final revision = _syncRevisionFromJournal(row);
      if (revision.device == first.device ||
          first.visible!.contains(revision.device, revision.sequence) ||
          revision.visible!.contains(first.device, first.sequence)) {
        continue;
      }
      final entity = row['entity'] as String, key = row['record_key'] as String;
      if (ownKeys.contains(_syncScope(entity, key))) continue;
      final after = _syncJsonRow(row['after_json']);
      final before =
          _syncJsonRow(row['before_json']) ?? await schema.prior(entity, key);
      final deleted =
          after == null ||
          after['deleted_at'] != null ||
          after['archived_at'] != null;
      if (deleted && references.contains(_syncScope(entity, key))) {
        return 'relatedDeletion';
      }
      final rule =
          entity == 'recurrence_series' ||
          entity.startsWith('progressive_plan');
      if (deletions.isEmpty && (families.isEmpty || !(changesRule || rule))) {
        continue;
      }
      final related = <String>{};
      for (final value in [before, after]) {
        if (value != null) {
          related.addAll(await schema.references(entity, value));
        }
      }
      if (deletions.intersection(related).isNotEmpty) return 'relatedDeletion';
      if ((changesRule || rule) && families.intersection(related).isNotEmpty) {
        return 'relatedRecurrence';
      }
    }
    return null;
  }

  Future<SyncApplyResult> applyNextSyncGroup(
    SyncBinding binding, {
    required SyncLease lease,
  }) async {
    final draft = await _prepareSyncGroup(binding, lease);
    if (draft == null) {
      final pending = await db
          .customSelect(
            'SELECT 1 FROM sync_mutation_groups WHERE workspace_id=? AND account_id=? AND materialized=0 LIMIT 1',
            variables: [
              Variable.withString(binding.workspace),
              Variable.withString(binding.account),
            ],
          )
          .get();
      return SyncApplyResult(
        pending.isEmpty ? SyncApplyState.idle : SyncApplyState.waiting,
      );
    }
    return db.transaction(() async {
      await _requireSyncExchange(binding, lease);
      final context = await db
          .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
          .getSingle();
      if (context.read<int>('device_sequence') != draft.localSequence ||
          context.read<String>('visible_json') != draft.visibleState) {
        return SyncApplyResult(SyncApplyState.retry, groupId: draft.id);
      }
      final current = await db
          .customSelect(
            'SELECT materialized FROM sync_mutation_groups WHERE id=?',
            variables: [Variable.withString(draft.id)],
          )
          .getSingle();
      if (current.read<int>('materialized') == 1) {
        return SyncApplyResult(SyncApplyState.retry, groupId: draft.id);
      }
      // Excluded device-local records deliberately do not advance the portable
      // sequence. Check the actual rows too before using an outside-lock draft.
      final fresh = _SyncApplySchema(this, {}, binding);
      for (final record in draft.records) {
        if (!_syncSame(
          await fresh.current(record.entity, record.key),
          record.current,
        )) {
          return SyncApplyResult(SyncApplyState.retry, groupId: draft.id);
        }
      }
      Future<SyncApplyResult> block(String reason) async {
        await db.customStatement(
          'UPDATE sync_mutation_groups SET blocked_reason=? WHERE id=?',
          [
            jsonEncode({
              'reason': reason,
              'sequence': draft.localSequence,
              'visible': draft.visibleState,
            }),
            draft.id,
          ],
        );
        return SyncApplyResult(
          SyncApplyState.needsReview,
          groupId: draft.id,
          reason: reason,
        );
      }

      if (draft.reason != null) return block(draft.reason!);
      final deferred =
          (await db.customSelect('PRAGMA defer_foreign_keys').getSingle())
                  .data
                  .values
                  .single
              as int;
      try {
        return await db.transaction(() async {
          await db.customStatement('PRAGMA defer_foreign_keys=ON');
          final domainTriggers = await db
              .customSelect(
                "SELECT name,sql FROM sqlite_schema WHERE type='trigger' AND name NOT GLOB 'sync_*'",
              )
              .get();
          const audited = {
            'recurrence_task_schedule_updated',
            'recurrence_task_content_updated',
            'recurrence_task_cancelled',
            'tasks_icon_cleanup',
            'categories_icon_cleanup',
            'projects_icon_cleanup',
            'recurrence_series_icon_cleanup',
          };
          if (domainTriggers.length != audited.length ||
              domainTriggers.any(
                (r) => !audited.contains(r.read<String>('name')),
              )) {
            throw const _SyncDomainBlock('unreviewedDatabaseTrigger');
          }
          // These triggers express local commands. The received group already
          // contains their effects; suppress/recreate them inside this one
          // atomic transaction so no engine reruns recurrence or icon cleanup.
          for (final trigger in domainTriggers) {
            await db.customStatement(
              'DROP TRIGGER "${trigger.read<String>('name')}"',
            );
          }
          await db.customStatement(
            'UPDATE sync_capture_context SET applying_remote=1 WHERE id=1',
          );
          final schema = _SyncApplySchema(this, {}, binding);
          final depths = <String, int>{};
          Future<int> depth(String table) async {
            if (depths.containsKey(table)) return depths[table]!;
            depths[table] = 0;
            final links = await db
                .customSelect('PRAGMA foreign_key_list("$table")')
                .get();
            var value = 0;
            for (final link in links) {
              final parent = link.read<String>('table');
              if (portableSyncTables.contains(parent) && parent != table) {
                final parentDepth = await depth(parent) + 1;
                if (parentDepth > value) value = parentDepth;
              }
            }
            return depths[table] = value;
          }

          for (final record in draft.records) {
            await depth(record.entity);
          }
          final writes =
              draft.records.where((r) => r.review.merged != null).toList()
                ..sort(
                  (a, b) => (depths[a.entity]!).compareTo(depths[b.entity]!),
                );
          final deletes =
              draft.records.where((r) => r.review.merged == null).toList()
                ..sort(
                  (a, b) => (depths[b.entity]!).compareTo(depths[a.entity]!),
                );
          // Redirect existing FK relationships before deleting their old owner.
          for (final record in writes.where((r) => r.current != null)) {
            await _writeSyncRecord(binding, record, schema);
            if (!await renewSyncLease(lease)) {
              throw StateError('Sync ownership expired during apply');
            }
          }
          for (final record in deletes) {
            await _writeSyncRecord(binding, record, schema);
            if (!await renewSyncLease(lease)) {
              throw StateError('Sync ownership expired during apply');
            }
          }
          for (final record in writes.where((r) => r.current == null)) {
            await _writeSyncRecord(binding, record, schema);
            if (!await renewSyncLease(lease)) {
              throw StateError('Sync ownership expired during apply');
            }
          }
          await _validateSyncDomainState(draft.records);
          for (final record in draft.records) {
            final heads = record.review.heads.toList()..sort();
            if (heads.isEmpty) {
              throw const _SyncDomainBlock('missingRecordAncestry');
            }
            await db.customStatement(
              '''INSERT INTO sync_entity_heads(workspace_id,entity,record_key,visible_revision,visible_heads_json)
              VALUES(?,?,?,?,?) ON CONFLICT(workspace_id,entity,record_key) DO UPDATE SET
              visible_revision=excluded.visible_revision,visible_heads_json=excluded.visible_heads_json,materialized=1,blocked_reason=NULL''',
              [
                binding.workspace,
                record.entity,
                record.key,
                heads.last,
                jsonEncode(heads),
              ],
            );
          }
          final visible = SyncVisibility.fromJson(
            (jsonDecode(context.read<String>('visible_json')) as Map)
                .cast<String, dynamic>(),
          ).withRange(draft.device, draft.first, draft.last);
          final observed = (jsonDecode(
            context.read<String>('received_json'),
          ) as Map).cast<String, int>();
          observed[binding.device] = context.read<int>('device_sequence');
          await db.customStatement(
            'UPDATE sync_capture_context SET visible_json=?,observed_json=?,applying_remote=0 WHERE id=1',
            [jsonEncode(visible.toJson()), jsonEncode(observed)],
          );
          await db.customStatement(
            'UPDATE sync_mutation_groups SET materialized=1,blocked_reason=NULL WHERE id=?',
            [draft.id],
          );
          for (final trigger in domainTriggers) {
            await db.customStatement(trigger.read<String>('sql'));
          }
          await _requireSyncExchange(binding, lease);
          return SyncApplyResult(
            SyncApplyState.applied,
            groupId: draft.id,
            records: draft.records.length,
          );
        }, requireNew: true);
      } on _SyncDomainBlock catch (error) {
        return block(error.reason);
      } on sqlite.SqliteException catch (error) {
        if (error.resultCode != 19) rethrow;
        return block('recordConstraint');
      } on FormatException {
        return block('invalidPortableState');
      } finally {
        await db.customStatement(
          'PRAGMA defer_foreign_keys=${deferred == 0 ? 'OFF' : 'ON'}',
        );
      }
    });
  }

  Future<void> _writeSyncRecord(
    SyncBinding binding,
    _SyncRecordDraft record,
    _SyncApplySchema schema,
  ) async {
    final identity = (jsonDecode(record.key) as Map).cast<String, Object?>();
    final value = record.review.merged == null
        ? null
        : Map<String, Object?>.from(record.review.merged!);
    if (value == null) {
      if (record.entity == 'tasks') {
        final local = await db
            .customSelect(
              'SELECT 1 FROM task_resources WHERE task_id=? AND NOT (${syncRowIsPortable('task_resources', '')}) LIMIT 1',
              variables: [Variable.withString(identity['id'] as String)],
            )
            .get();
        if (local.isNotEmpty) {
          throw const _SyncDomainBlock('deviceLocalResources');
        }
      }
      await db.customStatement(
        'DELETE FROM "${record.entity}" WHERE ${identity.keys.map((k) => '"$k"=?').join(' AND ')}',
        identity.values.toList(),
      );
      return;
    }
    if (record.current != null &&
        !value.containsKey('updated_at') &&
        _syncSame(_syncUserFields(record.current!), _syncUserFields(value))) {
      return;
    }
    if (value.containsKey('updated_at') &&
        record.current?['updated_at'] is String) {
      final previous = DateTime.parse(record.current!['updated_at'] as String);
      final received = DateTime.parse(value['updated_at'] as String);
      value['updated_at'] = _nextTaskRevision(
        previous.isAfter(received) ? previous : received,
      ).toIso8601String();
    }
    final columns = await schema.columns(record.entity);
    if (value.length != columns.length ||
        columns.any((c) => !value.containsKey(c['name']))) {
      throw const _SyncDomainBlock('incompletePortableRow');
    }
    for (final column in columns) {
      final name = column['name'] as String;
      final field = value[name];
      if (column['type'] == 'BLOB' && field != null) {
        if (record.entity != 'task_resources' ||
            name != 'content' ||
            field is! Map ||
            field[r'$managedSha256'] is! String ||
            field[r'$managedBytes'] is! int ||
            field[r'$managedSha256'] != value['sha256'] ||
            field[r'$managedBytes'] != value['byte_size']) {
          throw const _SyncDomainBlock('invalidManagedBytes');
        }
        final bytes = await db
            .customSelect(
              r'''SELECT json_extract(after_json,'$.content."$blob"') AS hex FROM sync_journal
          WHERE workspace_id=? AND account_id=? AND entity='task_resources' AND record_key=? AND known=1
          AND json_extract(after_json,'$.sha256')=? AND json_extract(after_json,'$.byte_size')=?
          AND json_extract(after_json,'$.content."$blob"') IS NOT NULL LIMIT 1''',
              variables: [
                Variable.withString(binding.workspace),
                Variable.withString(binding.account),
                Variable.withString(record.key),
                Variable.withString(field[r'$managedSha256'] as String),
                Variable.withInt(field[r'$managedBytes'] as int),
              ],
            )
            .get();
        if (bytes.isEmpty) throw const _SyncDomainBlock('missingManagedBytes');
        value[name] = await _syncManagedBytesInWorker(
          bytes.single.read<String>('hex'),
          field[r'$managedSha256'] as String,
          field[r'$managedBytes'] as int,
        );
      }
      if (name.endsWith('_json') && field is String) jsonDecode(field);
    }
    final names = columns.map((c) => c['name'] as String).toList();
    final mutable = names.where((name) => !identity.containsKey(name)).toList();
    await db.customStatement(
      '''INSERT INTO "${record.entity}"(${names.map((n) => '"$n"').join(',')})
      VALUES(${List.filled(names.length, '?').join(',')}) ON CONFLICT(${identity.keys.map((n) => '"$n"').join(',')})
      ${mutable.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET ${mutable.map((n) => '"$n"=excluded."$n"').join(',')}'}''',
      names.map((name) => value[name]).toList(),
    );
  }

  Future<void> _validateSyncDomainState(List<_SyncRecordDraft> records) async {
    if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw const _SyncDomainBlock('recordRelationship');
    }
    final cycle = await db.customSelect(
      '''WITH RECURSIVE paths(origin,node) AS (
      SELECT task_id,prerequisite_id FROM task_dependencies UNION
      SELECT p.origin,d.prerequisite_id FROM paths p JOIN task_dependencies d ON d.task_id=p.node)
      SELECT 1 FROM paths WHERE origin=node LIMIT 1''',
    ).get();
    if (cycle.isNotEmpty) throw const _SyncDomainBlock('dependencyCycle');
    final hierarchy = await db.customSelect(
      '''SELECT 1 FROM task_parent_links child
      JOIN task_parent_links parent ON child.parent_id=parent.child_id LIMIT 1''',
    ).get();
    if (hierarchy.isNotEmpty) throw const _SyncDomainBlock('taskHierarchy');
    final assignment = await db.customSelect(
      '''SELECT 1 FROM tasks t JOIN projects p ON p.id=t.project_id
      WHERE t.category_id IS NOT p.category_id LIMIT 1''',
    ).get();
    if (assignment.isNotEmpty) throw const _SyncDomainBlock('taskAssignment');
    for (final record in records.where(
      (r) => r.entity == 'tasks' && r.review.merged != null,
    )) {
      final notification = record.review.merged!['notification_json'];
      TaskNotification.fromJson(
        (jsonDecode(notification as String) as Map).cast<String, dynamic>(),
      );
    }
  }
}
