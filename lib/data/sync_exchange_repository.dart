part of 'life_repository.dart';

Future<String> _syncBytesDigest(Uint8List bytes) =>
    Isolate.run(() => sha256.convert(bytes).toString());
Future<SyncBatch> _syncBuildInWorker(
  List<Map<String, Object?>> rows,
  SyncBinding binding,
  String id,
) => Isolate.run(() => _buildOutgoingSyncBatch(rows, binding, id));

Map<String, Object?>? _syncPortableValue(String? source) {
  if (source == null) return null;
  final value = (jsonDecode(source) as Map).cast<String, Object?>();
  return value.map((name, field) {
    if (field is Map && field.length == 1 && field[r'$blob'] is String) {
      final hex = field[r'$blob'] as String;
      if (hex.length.isOdd ||
          hex.length > 32 * 1024 * 1024 ||
          !RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex)) {
        throw const FormatException('Invalid managed bytes in sync journal');
      }
      final bytes = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return MapEntry(name, {r'$bytes': base64Encode(bytes)});
    }
    return MapEntry(name, field);
  });
}

SyncRevision _syncRevisionFromJournal(Map<String, Object?> row) => SyncRevision(
  id: row['operation_id'] as String,
  device: row['device_id'] as String,
  sequence: row['origin_sequence'] as int,
  parents: (jsonDecode(row['parent_ids_json'] as String) as List)
      .cast<String>(),
  observed: (jsonDecode(row['observed_json'] as String) as Map)
      .cast<String, int>(),
  value: _syncPortableValue(row['after_json'] as String?),
);

SyncBatch _buildOutgoingSyncBatch(
  List<Map<String, Object?>> rows,
  SyncBinding binding,
  String id,
) {
  final operations = <SyncRecordOperation>[];
  var bytes = 4096;
  for (final row in rows) {
    final entity = row['entity'] as String;
    if (!portableSyncTables.contains(entity)) {
      throw const FormatException('Unknown portable journal entity');
    }
    final operation = SyncRecordOperation(
      entity: entity,
      recordKey: row['record_key'] as String,
      revision: _syncRevisionFromJournal(row),
      group: SyncMutationGroup(
        id: row['mutation_group_id'] as String,
        first: row['group_first'] as int,
        last: row['group_last'] as int,
      ),
    );
    final length = utf8.encode(jsonEncode(operation.toJson())).length + 1;
    if (bytes + length > SyncBatchCodec.maxPlaintextBytes) {
      if (operations.isEmpty) {
        throw const FormatException(
          'A retained operation exceeds the sync batch limit. Use independent backups and retain this queue.',
        );
      }
      break;
    }
    operations.add(operation);
    bytes += length;
  }
  return SyncBatch(
    id: id,
    device: binding.device,
    schema: AppDatabase.currentSchemaVersion,
    operations: operations,
  );
}

extension SyncExchangeRepository on LifeRepository {
  Future<void> _requireSyncBinding(SyncBinding binding) async {
    final row = await db
        .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
        .getSingle();
    if (row.readNullable<String>('workspace_id') != binding.workspace ||
        row.readNullable<String>('account_id') != binding.account ||
        row.readNullable<String>('device_id') != binding.device ||
        row.read<int>('capture_enabled') != 1 ||
        row.read<int>('restore_quarantined') != 0 ||
        row.read<int>('suspended_for_restore') != 0) {
      throw StateError(
        'Sync binding changed or needs reconciliation. Pending work is retained.',
      );
    }
  }

  Future<PendingSyncBatch> _pendingSyncBatch(
    Map<String, Object?> row,
    SyncBinding binding,
  ) async {
    if (row['workspace_id'] != binding.workspace ||
        row['account_id'] != binding.account ||
        row['device_id'] != binding.device ||
        row['direction'] != 'outgoing') {
      throw StateError(
        'The staged sync batch belongs to another binding. Retain its queue.',
      );
    }
    final bytes = row['payload'] as Uint8List;
    final digest = await _syncBytesDigest(bytes);
    if (digest != row['sha256']) {
      throw StateError(
        'A staged sync batch is damaged. Retain the profile and queue for recovery.',
      );
    }
    return PendingSyncBatch(
      id: row['id'] as String,
      binding: binding,
      bytes: bytes,
      sha256: digest,
    );
  }

  Future<PendingSyncBatch?> prepareNextSyncBatch(
    SyncBinding binding,
    SyncWorkspaceKey key, {
    SyncBatchCodec? codec,
    SyncLease? lease,
  }) async {
    await _requireSyncExchange(binding, lease);
    final existing = await db
        .customSelect(
          "SELECT * FROM sync_batches WHERE workspace_id=? AND account_id=? AND device_id=? AND direction='outgoing' AND uploaded=0 ORDER BY created_at,id LIMIT 1",
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
            Variable.withString(binding.device),
          ],
        )
        .get();
    if (existing.isNotEmpty) {
      final pending = await _pendingSyncBatch(existing.single.data, binding);
      await _requireSyncExchange(binding, lease);
      return pending;
    }
    final headers = await db
        .customSelect(
          '''SELECT j.operation_id,
      coalesce(length(CAST(j.after_json AS BLOB)),0)+length(j.observed_json)+length(j.parent_ids_json)+length(j.record_key)+1024 AS payload_bytes
      FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id AND g.complete=1
      WHERE j.workspace_id=? AND j.account_id=? AND j.device_id=?
      AND j.uploaded=0 AND j.batch_id IS NULL AND j.known=1 ORDER BY j.origin_sequence LIMIT 512''',
          variables: [
            Variable.withString(binding.workspace),
            Variable.withString(binding.account),
            Variable.withString(binding.device),
          ],
        )
        .get();
    if (headers.isEmpty) {
      final pending = await db
          .customSelect(
            'SELECT 1 FROM sync_journal WHERE workspace_id=? AND account_id=? AND device_id=? AND uploaded=0 AND batch_id IS NULL LIMIT 1',
            variables: [
              Variable.withString(binding.workspace),
              Variable.withString(binding.account),
              Variable.withString(binding.device),
            ],
          )
          .get();
      if (pending.isNotEmpty) {
        throw StateError(
          'A retained mutation group is incomplete. Preserve the queue for reconciliation.',
        );
      }
      return null;
    }
    final ids = <String>[];
    var rawBytes = 0;
    for (final header in headers) {
      rawBytes += header.read<int>('payload_bytes');
      if (rawBytes > SyncBatchCodec.maxPlaintextBytes * 2) {
        if (ids.isEmpty) {
          throw const FormatException(
            'A journal entry exceeds the sync memory bound. Its local data and queue are retained.',
          );
        }
        break;
      }
      ids.add(header.read<String>('operation_id'));
    }
    final rows = (await db.customSelect(
      '''SELECT j.operation_id,j.device_id,j.origin_sequence,j.parent_ids_json,j.observed_json,j.entity,j.record_key,j.after_json,j.mutation_group_id,
        g.first_sequence AS group_first,g.last_sequence AS group_last
      FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id
      WHERE j.operation_id IN (${List.filled(ids.length, '?').join(',')}) ORDER BY j.origin_sequence''',
      variables: ids.map(Variable.withString).toList(),
    ).get()).map((row) => Map<String, Object?>.from(row.data)).toList();
    if (rows.length != ids.length) {
      throw StateError(
        'Retained sync journal changed unexpectedly. Stop exchange and preserve this profile.',
      );
    }
    final id = _uuid.v4();
    final batch = await _syncBuildInWorker(rows, binding, id);
    final encrypted = await (codec ?? SyncBatchCodec()).encrypt(
      batch,
      key,
      workspace: binding.workspace,
      account: binding.account,
    );
    final digest = await _syncBytesDigest(encrypted);
    await db.transaction(() async {
      await _requireSyncExchange(binding, lease);
      await db.customStatement(
        'INSERT INTO sync_batches(id,workspace_id,account_id,device_id,direction,payload,sha256,created_at) VALUES(?,?,?,?,?,?,?,?)',
        [
          batch.id,
          binding.workspace,
          binding.account,
          binding.device,
          'outgoing',
          encrypted,
          digest,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
      for (final operation in batch.operations) {
        final changed = await db.customUpdate(
          'UPDATE sync_journal SET batch_id=? WHERE operation_id=? AND uploaded=0 AND batch_id IS NULL',
          variables: [
            Variable.withString(batch.id),
            Variable.withString(operation.revision.id),
          ],
        );
        if (changed != 1) {
          throw StateError(
            'Another job changed the staged queue. Retry without discarding local work.',
          );
        }
      }
    });
    return PendingSyncBatch(
      id: batch.id,
      binding: binding,
      bytes: encrypted,
      sha256: digest,
    );
  }

  Future<void> acknowledgeSyncBatch(
    PendingSyncBatch batch,
    CloudObject remote, {
    SyncLease? lease,
  }) => db.transaction(() async {
    await _requireSyncExchange(batch.binding, lease);
    final persisted = await db
        .customSelect(
          'SELECT * FROM sync_batches WHERE id=?',
          variables: [Variable.withString(batch.id)],
        )
        .getSingle();
    final stored = await _pendingSyncBatch(persisted.data, batch.binding);
    await _requireSyncExchange(batch.binding, lease);
    if (remote.accountId != batch.binding.account ||
        remote.bytes != stored.bytes.length ||
        remote.md5 != md5.convert(stored.bytes).toString() ||
        remote.properties['batchId'] != batch.id ||
        remote.properties['workspaceId'] != batch.binding.workspace ||
        remote.properties['application'] != 'todorbit-sync' ||
        remote.properties['deviceId'] != batch.binding.device ||
        remote.properties['protocol'] != '1' ||
        remote.properties['kind'] != 'operations' ||
        remote.properties['verified'] != 'true' ||
        stored.sha256 != batch.sha256) {
      throw StateError(
        'Uploaded sync identity or content verification differs. The queued operations remain pending.',
      );
    }
    final existing = await db
        .customSelect(
          'SELECT * FROM sync_remote_objects WHERE object_id=?',
          variables: [Variable.withString(remote.id)],
        )
        .get();
    if (existing.isNotEmpty &&
        existing.single.read<String>('batch_id') != batch.id) {
      throw StateError(
        'A cloud object was reused for different sync content. Retain both batches for review.',
      );
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO sync_remote_objects(object_id,batch_id,md5,bytes) VALUES(?,?,?,?)',
      [remote.id, batch.id, remote.md5, remote.bytes],
    );
    await db.customStatement('UPDATE sync_batches SET uploaded=1 WHERE id=?', [
      batch.id,
    ]);
    await db.customStatement(
      'UPDATE sync_journal SET uploaded=1 WHERE batch_id=?',
      [batch.id],
    );
  });
}
