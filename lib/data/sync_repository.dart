part of 'life_repository.dart';

extension SyncRepository on LifeRepository {
  Future<void> quarantineRestoredSync() => db.transaction(() async {
    await db.customStatement(
      'UPDATE sync_capture_context SET capture_enabled=0,applying_remote=0,restore_quarantined=1 WHERE id=1',
    );
  });

  Future<BackupRecord?> activateSyncCapture({
    required String workspaceId,
    required String accountId,
    required String deviceId,
    required BackupService recovery,
  }) async {
    if (!Uuid.isValidUUID(fromString: workspaceId) ||
        !Uuid.isValidUUID(fromString: deviceId) ||
        accountId.isEmpty ||
        accountId.length > 256) {
      throw const FormatException('Invalid sync workspace or device identity');
    }
    final databases = await db.customSelect('PRAGMA database_list').get();
    final filename = databases
        .singleWhere((row) => row.read<String>('name') == 'main')
        .read<String>('file');
    if (filename.isEmpty ||
        !path.equals(
          path.normalize(File(filename).absolute.path),
          path.normalize(recovery.databaseFile.absolute.path),
        )) {
      throw StateError('Before Sync backup must belong to this database');
    }
    final context = await db
        .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
        .getSingle();
    if (context.read<int>('restore_quarantined') == 1) {
      throw StateError(
        'This restored profile needs sync reconciliation. Its retained operations must be reviewed before pairing or uploading.',
      );
    }
    if (context.readNullable<String>('workspace_id') case final previous?) {
      if (previous != workspaceId ||
          context.readNullable<String>('account_id') != accountId ||
          context.readNullable<String>('device_id') != deviceId) {
        throw StateError(
          'This profile already belongs to another sync binding. Preserve and reconcile its queued work before pairing again.',
        );
      }
      if (context.read<int>('capture_enabled') == 1) return null;
      throw StateError(
        'This bound profile requires reviewed reconciliation before capture can resume. Its retained queue is unchanged.',
      );
    }
    if (await recovery.hasScheduledRestore()) {
      throw StateError('Finish or cancel the pending restore before pairing.');
    }
    final beforeSync = await recovery.createBackup(BackupKind.manual);
    final recoveryFingerprint = await databaseFingerprint(beforeSync.file.path);
    await db.transaction(() async {
      await db.customStatement(
        'UPDATE sync_capture_context SET capture_enabled=capture_enabled WHERE id=1',
      );
      final current = await db
          .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
          .getSingle();
      if (current.data.keys.any(
        (key) => current.data[key] != context.data[key],
      )) {
        throw StateError(
          'Sync binding changed while preparing its recovery backup. Retry pairing.',
        );
      }
      if (await databaseFingerprint(filename) != recoveryFingerprint ||
          await recovery.hasScheduledRestore()) {
        throw StateError(
          'Local data or restore state changed during recovery preparation. Nothing was paired; retry after reviewing local work.',
        );
      }
      await db.customStatement(
        'UPDATE sync_capture_context SET workspace_id=?,account_id=?,device_id=?,mutation_group=? WHERE id=1',
        [workspaceId, accountId, deviceId, _uuid.v4()],
      );
      await _seedSyncState(
        workspaceId,
        accountId,
        deviceId,
        current.read<int>('device_sequence') + 1,
      );
    });
    return beforeSync;
  }

  /// Only capture metadata changes. Old histories remain workspace scoped;
  /// every current portable row is seeded with fresh operations.
  Future<void> replaceSyncCapture(
    SyncBinding next, {
    required String? expectedWorkspace,
  }) => db.transaction(() async {
    await db.customStatement(
      'UPDATE sync_capture_context SET capture_enabled=capture_enabled WHERE id=1',
    );
    final current = await db
        .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
        .getSingle();
    if (current.readNullable<String>('workspace_id') == next.workspace &&
        current.readNullable<String>('account_id') == next.account &&
        current.readNullable<String>('device_id') == next.device) {
      return;
    }
    if (!Uuid.isValidUUID(fromString: next.workspace) ||
        !Uuid.isValidUUID(fromString: next.device) ||
        current.readNullable<String>('workspace_id') != expectedWorkspace ||
        (current.readNullable<String>('account_id') != null &&
            current.readNullable<String>('account_id') != next.account) ||
        current.read<int>('restore_quarantined') != 0 ||
        current.read<int>('suspended_for_restore') != 0 ||
        (current.readNullable<int>('lease_until_ms') ?? 0) >
            DateTime.now().toUtc().millisecondsSinceEpoch) {
      throw StateError(
        'Finish the active sync or restore before replacing its binding',
      );
    }
    await db.customStatement(
      """UPDATE sync_capture_context SET workspace_id=?,account_id=?,device_id=?,mutation_group=?,capture_enabled=0,
      device_sequence=0,observed_json='{}',received_json='{}',visible_json='{}',automatic_sync=0,change_token=NULL,last_success_utc=NULL,
      failure_count=0,next_attempt_utc=NULL,last_error_code=NULL,lease_owner=NULL,lease_until_ms=NULL,lease_heartbeat_ms=NULL WHERE id=1""",
      [next.workspace, next.account, next.device, _uuid.v4()],
    );
    await _seedSyncState(next.workspace, next.account, next.device, 1);
  });

  Future<void> _seedSyncState(
    String workspaceId,
    String accountId,
    String deviceId,
    int firstSequence,
  ) async {
    await db.customStatement(
      '''UPDATE timer_runs SET owner_device_id=?
        WHERE state!='stopped' AND owner_device_id IS NULL''',
      [deviceId],
    );
    for (final table in portableSyncTables) {
      final columns =
          (await db.customSelect('PRAGMA table_info("$table")').get())
              .map((row) => row.data)
              .toList();
      await db.customStatement(
        '''INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,after_json,origin_sequence,observed_json,parent_ids_json,mutation_group_id,visible_json)
          SELECT $syncOperationUuidSql,?,?,?,'$table',${syncKeyJson(columns, 'source.')},${syncRowJson(columns, 'source.')},
            context.device_sequence+row_number() OVER(ORDER BY ${syncKeyJson(columns, 'source.')}),
            json_set(context.observed_json,'\$.' || json_quote(context.device_id),context.device_sequence+row_number() OVER(ORDER BY ${syncKeyJson(columns, 'source.')})-1),'[]',context.mutation_group,
            CASE WHEN context.device_sequence+row_number() OVER(ORDER BY ${syncKeyJson(columns, 'source.')})>1
            THEN json_set(context.visible_json,'\$.' || json_quote(context.device_id),json_array(json_array(1,context.device_sequence+row_number() OVER(ORDER BY ${syncKeyJson(columns, 'source.')})-1))) ELSE context.visible_json END
          FROM "$table" AS source CROSS JOIN sync_capture_context AS context
          WHERE context.id=1 AND ${syncRowIsPortable(table, 'source.')}''',
        [workspaceId, accountId, deviceId],
      );
      await db.customStatement(
        '''UPDATE sync_capture_context SET device_sequence=device_sequence+changes(),
          observed_json=json_set(observed_json,$syncDeviceClockPathSql,device_sequence+changes()),
          received_json=json_set(received_json,$syncDeviceClockPathSql,device_sequence+changes()),
          visible_json=CASE WHEN device_sequence+changes()>0 THEN json_set(visible_json,$syncDeviceClockPathSql,json_array(json_array(1,device_sequence+changes()))) ELSE visible_json END WHERE id=1''',
      );
    }

    await db.customStatement(
      '''INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence,complete,materialized)
        SELECT mutation_group,workspace_id,account_id,device_id,?,device_sequence,1,1 FROM sync_capture_context WHERE id=1 AND device_sequence>=?''',
      [firstSequence, firstSequence],
    );
    await db.customStatement(
      '''INSERT INTO sync_entity_heads(workspace_id,entity,record_key,visible_revision,visible_heads_json)
        SELECT workspace_id,entity,record_key,operation_id,json_array(operation_id) FROM sync_journal
        WHERE workspace_id=? AND account_id=?
        ON CONFLICT(workspace_id,entity,record_key) DO UPDATE SET visible_revision=excluded.visible_revision,visible_heads_json=excluded.visible_heads_json''',
      [workspaceId, accountId],
    );
    await db.customStatement(
      'UPDATE sync_capture_context SET capture_enabled=1,mutation_group=NULL WHERE id=1',
    );
  }

  Future<List<Map<String, Object?>>> outgoingResetBatches(
    SyncBinding binding,
  ) async =>
      (await db
              .customSelect(
                "SELECT id,payload,sha256 FROM sync_batches WHERE workspace_id=? AND account_id=? AND direction='outgoing' AND superseded=0 ORDER BY id",
                variables: [
                  Variable.withString(binding.workspace),
                  Variable.withString(binding.account),
                ],
              )
              .get())
          .map((r) => r.data)
          .toList();

  Future<List<Map<String, Object?>>> pendingSyncChanges({
    required String workspaceId,
    required String accountId,
  }) async =>
      (await db
              .customSelect(
                'SELECT * FROM sync_journal WHERE workspace_id=? AND account_id=? AND uploaded=0 ORDER BY sequence',
                variables: [
                  Variable.withString(workspaceId),
                  Variable.withString(accountId),
                ],
              )
              .get())
          .map((row) => Map<String, Object?>.unmodifiable(row.data))
          .toList();
}
