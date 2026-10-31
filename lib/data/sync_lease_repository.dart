part of 'life_repository.dart';

extension SyncLeaseRepository on LifeRepository {
  // SQLite ownership works across processes and Flutter engines, including
  // engines in the same Android process where file locks are insufficient.
  Future<SyncLease?> acquireSyncLease(SyncBinding binding, {DateTime? now}) =>
      db.transaction(() async {
        await _requireSyncBinding(binding);
        final time = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
        final until = time + SyncLease.duration.inMilliseconds;
        final owner = _uuid.v4();
        final changed = await db.customUpdate(
          '''UPDATE sync_capture_context
      SET lease_owner=?,lease_until_ms=?,lease_heartbeat_ms=?
      WHERE id=1 AND (lease_owner IS NULL OR lease_until_ms IS NULL OR lease_until_ms<=?
      OR lease_until_ms>? OR lease_heartbeat_ms>?)''',
          variables: [
            Variable.withString(owner),
            Variable.withInt(until),
            Variable.withInt(time),
            Variable.withInt(time),
            Variable.withInt(time + 2 * SyncLease.duration.inMilliseconds),
            Variable.withInt(until),
          ],
        );
        return changed == 1 ? SyncLease(binding: binding, owner: owner) : null;
      });

  Future<bool> syncLeaseIsCurrent(SyncLease lease, {DateTime? now}) async {
    final time = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final rows = await db
        .customSelect(
          '''SELECT 1 FROM sync_capture_context
      WHERE id=1 AND workspace_id=? AND account_id=? AND device_id=? AND lease_owner=?
      AND lease_until_ms>? AND lease_until_ms<=? AND capture_enabled=1
      AND restore_quarantined=0 AND suspended_for_restore=0''',
          variables: [
            Variable.withString(lease.binding.workspace),
            Variable.withString(lease.binding.account),
            Variable.withString(lease.binding.device),
            Variable.withString(lease.owner),
            Variable.withInt(time),
            Variable.withInt(time + 2 * SyncLease.duration.inMilliseconds),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<bool> renewSyncLease(SyncLease lease, {DateTime? now}) =>
      db.transaction(() async {
        if (!await syncLeaseIsCurrent(lease, now: now)) return false;
        final time = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
        return await db.customUpdate(
              '''UPDATE sync_capture_context SET lease_until_ms=?,lease_heartbeat_ms=?
      WHERE id=1 AND lease_owner=?''',
              variables: [
                Variable.withInt(time + SyncLease.duration.inMilliseconds),
                Variable.withInt(time),
                Variable.withString(lease.owner),
              ],
            ) ==
            1;
      });

  Future<void> releaseSyncLease(SyncLease lease) => db.customStatement(
    '''UPDATE sync_capture_context
    SET lease_owner=NULL,lease_until_ms=NULL,lease_heartbeat_ms=NULL
    WHERE id=1 AND workspace_id=? AND account_id=? AND device_id=? AND lease_owner=?''',
    [
      lease.binding.workspace,
      lease.binding.account,
      lease.binding.device,
      lease.owner,
    ],
  );

  Future<void> _requireSyncExchange(
    SyncBinding binding,
    SyncLease? lease,
  ) async {
    await _requireSyncBinding(binding);
    if (lease != null) {
      if (lease.binding.workspace == binding.workspace &&
          lease.binding.account == binding.account &&
          lease.binding.device == binding.device &&
          await syncLeaseIsCurrent(lease)) {
        return;
      }
    } else {
      final context = await db
          .customSelect(
            'SELECT lease_owner FROM sync_capture_context WHERE id=1',
          )
          .getSingle();
      if (context.readNullable<String>('lease_owner') == null) return;
    }
    throw StateError(
      'This sync job no longer owns exchange. Its local data and pending batches are retained.',
    );
  }
}
