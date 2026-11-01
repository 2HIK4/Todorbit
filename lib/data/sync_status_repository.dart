part of 'life_repository.dart';

extension SyncStatusRepository on LifeRepository {
  Future<SyncExchangeStatus> syncExchangeStatus() async {
    final c = await db
        .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
        .getSingle();
    final workspace = c.readNullable<String>('workspace_id');
    final account = c.readNullable<String>('account_id');
    final device = c.readNullable<String>('device_id');
    final pending = await db
        .customSelect(
          '''SELECT COUNT(*) AS value FROM sync_journal
      WHERE workspace_id=? AND account_id=? AND device_id=? AND uploaded=0''',
          variables: [
            Variable<String>(workspace),
            Variable<String>(account),
            Variable<String>(device),
          ],
        )
        .getSingle();
    final groups = await db
        .customSelect(
          '''SELECT COUNT(*) AS waiting,
      coalesce(SUM(CASE WHEN blocked_reason IS NOT NULL THEN 1 ELSE 0 END),0) AS conflicts
      FROM sync_mutation_groups WHERE workspace_id=? AND account_id=? AND materialized=0''',
          variables: [Variable<String>(workspace), Variable<String>(account)],
        )
        .getSingle();
    return SyncExchangeStatus(
      binding: workspace == null || account == null || device == null
          ? null
          : SyncBinding(workspace: workspace, account: account, device: device),
      enabled: c.read<int>('capture_enabled') == 1,
      automatic: c.read<int>('automatic_sync') == 1,
      quarantined:
          c.read<int>('restore_quarantined') == 1 ||
          c.read<int>('suspended_for_restore') == 1,
      pending: pending.read<int>('value'),
      conflicts: groups.read<int>('conflicts'),
      waiting: groups.read<int>('waiting'),
      changeToken: c.readNullable<String>('change_token'),
      lastSuccess: DateTime.tryParse(
        c.readNullable<String>('last_success_utc') ?? '',
      ),
      retryAt: DateTime.tryParse(
        c.readNullable<String>('next_attempt_utc') ?? '',
      ),
      errorCode: c.readNullable<String>('last_error_code'),
    );
  }

  Future<void> setAutomaticSync(SyncBinding binding, bool value) =>
      db.transaction(() async {
        await _requireSyncBinding(binding);
        await db.customStatement(
          'UPDATE sync_capture_context SET automatic_sync=? WHERE id=1',
          [value ? 1 : 0],
        );
      });

  Future<void> commitSyncChangeToken(
    SyncBinding binding,
    String? token, {
    required SyncLease lease,
  }) => db.transaction(() async {
    await _requireSyncExchange(binding, lease);
    if (token != null && (token.isEmpty || token.length > 4096)) {
      throw const FormatException('Invalid sync cursor');
    }
    await db.customStatement(
      'UPDATE sync_capture_context SET change_token=? WHERE id=1',
      [token],
    );
  });

  Future<bool> hasRetainedSyncObject(
    SyncBinding binding,
    CloudObject object, {
    required SyncLease lease,
  }) async {
    await _requireSyncExchange(binding, lease);
    if (object.accountId != binding.account ||
        object.properties['workspaceId'] != binding.workspace ||
        object.properties['application'] != 'todorbit-sync' ||
        object.properties['kind'] != 'operations' ||
        object.properties['protocol'] != '1' ||
        object.properties['verified'] != 'true') {
      throw const FormatException('Invalid sync object identity');
    }
    final previous = await db
        .customSelect(
          '''SELECT o.*,b.workspace_id,b.account_id,b.device_id
      FROM sync_remote_objects o JOIN sync_batches b ON b.id=o.batch_id WHERE o.object_id=?''',
          variables: [Variable.withString(object.id)],
        )
        .get();
    if (previous.isEmpty) return false;
    final row = previous.single;
    if (row.read<String>('workspace_id') != binding.workspace ||
        row.read<String>('account_id') != binding.account ||
        row.read<String>('batch_id') != object.properties['batchId'] ||
        row.read<String>('device_id') != object.properties['deviceId'] ||
        row.read<String>('md5') != object.md5 ||
        row.read<int>('bytes') != object.bytes) {
      throw const FormatException('An immutable sync object was replaced');
    }
    return true;
  }

  Future<void> recordSyncExchange(
    SyncBinding binding, {
    required SyncLease lease,
    required bool success,
  }) => db.transaction(() async {
    await _requireSyncExchange(binding, lease);
    if (success) {
      await db.customStatement(
        '''UPDATE sync_capture_context SET last_success_utc=?,failure_count=0,
          next_attempt_utc=NULL,last_error_code=NULL WHERE id=1''',
        [DateTime.now().toUtc().toIso8601String()],
      );
    } else {
      final row = await db
          .customSelect(
            'SELECT failure_count FROM sync_capture_context WHERE id=1',
          )
          .getSingle();
      final count = row.read<int>('failure_count') + 1;
      final delay = Duration(seconds: 15 * (1 << (count > 8 ? 8 : count - 1)));
      await db.customStatement(
        '''UPDATE sync_capture_context SET failure_count=?,next_attempt_utc=?,last_error_code='exchangeFailed' WHERE id=1''',
        [count, DateTime.now().toUtc().add(delay).toIso8601String()],
      );
    }
  });
}
