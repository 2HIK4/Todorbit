part of 'life_repository.dart';

Object? _syncCanonical(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.cast<String>().toList()..sort())
      key: _syncCanonical(value[key]),
  },
  List() => value.map(_syncCanonical).toList(),
  _ => value,
};

bool _syncSame(Object? left, Object? right) =>
    jsonEncode(_syncCanonical(left)) == jsonEncode(_syncCanonical(right));

// Incoming journal values use the same lossless SQLite encoding as local
// triggers. Only declared BLOB columns may carry a binary wire value.
String? _syncStoredIncomingValue(
  SyncRecordOperation operation,
  List<Map<String, Object?>> columns,
) {
  final key = jsonDecode(operation.recordKey);
  final primary = columns.where((column) => (column['pk'] as int) > 0).toList()
    ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
  if (key is! Map ||
      !_syncSame(
        key.keys.toList()..sort(),
        primary.map((c) => c['name']).toList()..sort(),
      ) ||
      key.values.any((value) => value is! String && value is! int)) {
    throw const FormatException('Invalid portable record identity');
  }
  final canonicalKey = jsonEncode({
    for (final column in primary) column['name'] as String: key[column['name']],
  });
  if (canonicalKey != operation.recordKey) {
    throw const FormatException('Portable record identity is not canonical');
  }
  final value = operation.revision.value;
  if (value == null) return null;
  if (value.length != columns.length ||
      columns.any((column) => !value.containsKey(column['name'])) ||
      key.entries.any((entry) => !_syncSame(entry.value, value[entry.key]))) {
    throw const FormatException('Portable record columns or identity differ');
  }
  final stored = <String, Object?>{};
  for (final column in columns) {
    final name = column['name'] as String;
    final field = value[name];
    final type = (column['type'] as String).toUpperCase();
    if (field == null) {
      if (column['notnull'] == 1 || (column['pk'] as int) > 0) {
        throw const FormatException('Required portable field is missing');
      }
      stored[name] = null;
    } else if (type == 'BLOB') {
      if (field is! Map || field.length != 1 || field[r'$bytes'] is! String) {
        throw const FormatException('Invalid managed byte encoding');
      }
      final bytes = base64Decode(field[r'$bytes'] as String);
      if (bytes.length > 16 * 1024 * 1024 ||
          base64Encode(bytes) != field[r'$bytes']) {
        throw const FormatException('Managed bytes exceed the portable limit');
      }
      if (operation.entity == 'task_resources' &&
          (value['byte_size'] != bytes.length ||
              value['sha256'] != sha256.convert(bytes).toString())) {
        throw const FormatException(
          'Managed resource bytes do not match their digest',
        );
      }
      stored[name] = {
        r'$blob': bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase(),
      };
    } else {
      if ((type == 'INTEGER' && field is! int) ||
          (type == 'TEXT' && field is! String) ||
          (type == 'REAL' && field is! num) ||
          field is Map ||
          field is List ||
          field is bool) {
        throw const FormatException('Invalid portable field type');
      }
      stored[name] = field;
    }
  }
  if (operation.entity == 'task_resources' &&
      !(value['kind'] == 'managed' ||
          (value['kind'] == 'url' &&
              value['target'] is String &&
              (Uri.tryParse(value['target'] as String)?.scheme == 'https' ||
                  Uri.tryParse(value['target'] as String)?.scheme ==
                      'http')))) {
    throw const FormatException('Device-local resource cannot be synchronized');
  }
  return jsonEncode(stored);
}

extension SyncIncomingRepository on LifeRepository {
  // Receipt means authenticated, durably retained history. It does not imply
  // materialization, conflict resolution or successful end-to-end sync.
  Future<int> retainIncomingSyncBatch(
    SyncBinding binding,
    SyncWorkspaceKey key,
    CloudObject remote,
    Uint8List source, {
    SyncBatchCodec? codec,
    SyncLease? lease,
  }) async {
    await _requireSyncExchange(binding, lease);
    final bytes = Uint8List.fromList(source);
    if (remote.accountId != binding.account ||
        remote.bytes != bytes.length ||
        remote.md5 != md5.convert(bytes).toString() ||
        remote.properties['application'] != 'todorbit-sync' ||
        remote.properties['workspaceId'] != binding.workspace ||
        remote.properties['protocol'] != '1' ||
        remote.properties['kind'] != 'operations' ||
        remote.properties['verified'] != 'true') {
      throw const FormatException(
        'Incoming sync identity or transport digest differs',
      );
    }
    final batch = await (codec ?? SyncBatchCodec()).decrypt(
      bytes,
      key,
      workspace: binding.workspace,
      account: binding.account,
      expectedSchema: AppDatabase.currentSchemaVersion,
    );
    if (remote.properties['batchId'] != batch.id ||
        remote.properties['deviceId'] != batch.device) {
      throw const FormatException(
        'Incoming sync identity differs from authenticated content',
      );
    }
    final digest = await _syncBytesDigest(bytes);
    return db.transaction(() async {
      await _requireSyncExchange(binding, lease);
      final previous = await db
          .customSelect(
            'SELECT * FROM sync_batches WHERE id=?',
            variables: [Variable.withString(batch.id)],
          )
          .get();
      if (previous.isNotEmpty) {
        final row = previous.single;
        if (row.read<String>('workspace_id') != binding.workspace ||
            row.read<String>('account_id') != binding.account ||
            row.read<String>('device_id') != batch.device ||
            row.read<String>('sha256') != digest ||
            !_syncSame(
              base64Encode(row.read<Uint8List>('payload')),
              base64Encode(bytes),
            )) {
          throw const FormatException(
            'An immutable sync batch identity was reused',
          );
        }
      } else {
        await db.customStatement(
          'INSERT INTO sync_batches(id,workspace_id,account_id,device_id,direction,payload,sha256,created_at,uploaded) VALUES(?,?,?,?,?,?,?,?,1)',
          [
            batch.id,
            binding.workspace,
            binding.account,
            batch.device,
            'incoming',
            bytes,
            digest,
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
      }
      var inserted = 0;
      final columnCache = <String, List<Map<String, Object?>>>{};
      for (final operation in batch.operations) {
        if (!portableSyncTables.contains(operation.entity)) {
          throw const FormatException('Unknown portable sync entity');
        }
        final columns = columnCache[operation.entity] ??=
            (await db
                    .customSelect('PRAGMA table_info("${operation.entity}")')
                    .get())
                .map((row) => row.data)
                .toList();
        final stored = _syncStoredIncomingValue(operation, columns);
        final revision = operation.revision;
        final group = operation.group!;
        final existing = await db
            .customSelect(
              'SELECT j.*,g.first_sequence AS group_first,g.last_sequence AS group_last FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id WHERE j.operation_id=?',
              variables: [Variable.withString(revision.id)],
            )
            .get();
        if (existing.isNotEmpty) {
          final row = existing.single;
          if (row.read<String>('workspace_id') != binding.workspace ||
              row.read<String>('account_id') != binding.account ||
              row.read<String>('entity') != operation.entity ||
              row.read<String>('record_key') != operation.recordKey ||
              !_syncSame(
                _syncRevisionFromJournal(row.data).toJson(),
                revision.toJson(),
              ) ||
              row.read<String>('mutation_group_id') != group.id ||
              row.read<int>('group_first') != group.first ||
              row.read<int>('group_last') != group.last) {
            throw const FormatException(
              'An immutable sync operation identity was reused',
            );
          }
          continue;
        }
        if (batch.device == binding.device) {
          throw StateError(
            'Another installation reused this device identity. Keep both profiles and pair a new device identity.',
          );
        }
        final groups = await db
            .customSelect(
              '''SELECT * FROM sync_mutation_groups WHERE id=? OR
          (workspace_id=? AND account_id=? AND device_id=? AND first_sequence<=? AND last_sequence>=?)''',
              variables: [
                Variable.withString(group.id),
                Variable.withString(binding.workspace),
                Variable.withString(binding.account),
                Variable.withString(batch.device),
                Variable.withInt(group.last),
                Variable.withInt(group.first),
              ],
            )
            .get();
        if (groups.any(
          (row) =>
              row.read<String>('id') != group.id ||
              row.read<String>('workspace_id') != binding.workspace ||
              row.read<String>('account_id') != binding.account ||
              row.read<String>('device_id') != batch.device ||
              row.read<int>('first_sequence') != group.first ||
              row.read<int>('last_sequence') != group.last,
        )) {
          throw const FormatException(
            'Sync mutation groups overlap or changed identity',
          );
        }
        if (groups.isEmpty) {
          await db.customStatement(
            'INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence) VALUES(?,?,?,?,?,?)',
            [
              group.id,
              binding.workspace,
              binding.account,
              batch.device,
              group.first,
              group.last,
            ],
          );
        }
        await db.customStatement(
          '''INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,
          after_json,uploaded,origin_sequence,observed_json,parent_ids_json,batch_id,known,mutation_group_id)
          VALUES(?,?,?,?,?,?,?,1,?,?,?,?,0,?)''',
          [
            revision.id,
            binding.workspace,
            binding.account,
            batch.device,
            operation.entity,
            operation.recordKey,
            stored,
            revision.sequence,
            jsonEncode(revision.observed),
            jsonEncode(revision.parents.toList()..sort()),
            batch.id,
            group.id,
          ],
        );
        inserted++;
      }
      await _validateRetainedSyncParents(binding);
      await _advanceKnownSyncHistory(binding);
      await db.customStatement(
        '''UPDATE sync_mutation_groups SET complete=1
        WHERE workspace_id=? AND account_id=? AND complete=0 AND
        last_sequence-first_sequence+1=(SELECT COUNT(*) FROM sync_journal j WHERE j.mutation_group_id=sync_mutation_groups.id AND j.known=1)''',
        [binding.workspace, binding.account],
      );
      final objects = await db
          .customSelect(
            'SELECT batch_id FROM sync_remote_objects WHERE object_id=?',
            variables: [Variable.withString(remote.id)],
          )
          .get();
      if (objects.isNotEmpty &&
          objects.single.read<String>('batch_id') != batch.id) {
        throw const FormatException('A remote object identity was reused');
      }
      await db.customStatement(
        'INSERT OR IGNORE INTO sync_remote_objects(object_id,batch_id,md5,bytes) VALUES(?,?,?,?)',
        [remote.id, batch.id, remote.md5, remote.bytes],
      );
      await _requireSyncExchange(binding, lease);
      return inserted;
    });
  }

  Future<void> _validateRetainedSyncParents(SyncBinding binding) async {
    final invalid = await db
        .customSelect(
          '''SELECT 1 FROM sync_journal child,json_each(child.parent_ids_json) parent
      JOIN sync_journal ancestor ON ancestor.operation_id=parent.value
      WHERE child.workspace_id=? AND child.account_id=? AND
      (ancestor.workspace_id!=child.workspace_id OR ancestor.account_id!=child.account_id OR
      ancestor.entity!=child.entity OR ancestor.record_key!=child.record_key OR
      coalesce(json_extract(child.observed_json,'\$.' || json_quote(ancestor.device_id)),0)<ancestor.origin_sequence) LIMIT 1''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
          ],
        )
        .get();
    if (invalid.isNotEmpty) {
      throw const FormatException(
        'A sync parent has a different identity or unobserved revision',
      );
    }
    final inconsistent = await db
        .customSelect(
          '''SELECT 1 FROM sync_journal j,json_each(j.observed_json) v
      JOIN sync_journal a ON a.workspace_id=j.workspace_id AND a.account_id=j.account_id AND a.device_id=v.key AND a.origin_sequence=v.value,
      json_each(a.observed_json) inherited
      WHERE j.workspace_id=? AND j.account_id=? AND
      coalesce(json_extract(j.observed_json,'\$.' || json_quote(inherited.key)),0)<inherited.value LIMIT 1''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
          ],
        )
        .get();
    if (inconsistent.isNotEmpty) {
      throw const FormatException(
        'A sync observation contradicts retained causal history',
      );
    }
  }

  Future<void> _advanceKnownSyncHistory(SyncBinding binding) async {
    // Global clocks track authenticated history, never user-visible state.
    // A future materializer must separately track what the user has reviewed.
    while (true) {
      final ready = await db
          .customSelect(
            '''SELECT j.operation_id,j.device_id,j.origin_sequence FROM sync_journal j
        WHERE j.workspace_id=? AND j.account_id=? AND j.known=0
        AND NOT EXISTS(SELECT 1 FROM json_each(j.parent_ids_json) p WHERE NOT EXISTS(
          SELECT 1 FROM sync_journal a WHERE a.operation_id=p.value AND a.known=1))
        AND NOT EXISTS(SELECT 1 FROM json_each(j.observed_json) v WHERE v.value>0 AND NOT EXISTS(
          SELECT 1 FROM sync_journal a WHERE a.workspace_id=j.workspace_id AND a.account_id=j.account_id
          AND a.device_id=v.key AND a.origin_sequence=v.value AND a.known=1))
        ORDER BY j.sequence LIMIT 512''',
            variables: [
              Variable.withString(binding.workspace),
              Variable.withString(binding.account),
            ],
          )
          .get();
      if (ready.isEmpty) break;
      for (final row in ready) {
        await db.customStatement(
          'UPDATE sync_journal SET known=1 WHERE operation_id=?',
          [row.read<String>('operation_id')],
        );
        await db.customStatement(
          '''UPDATE sync_capture_context SET received_json=json_set(received_json,'\$.' || json_quote(?),
          max(coalesce(json_extract(received_json,'\$.' || json_quote(?)),0),?)) WHERE id=1''',
          [
            row.read<String>('device_id'),
            row.read<String>('device_id'),
            row.read<int>('origin_sequence'),
          ],
        );
      }
    }
  }
}
