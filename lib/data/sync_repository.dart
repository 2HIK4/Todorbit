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
      for (final table in portableSyncTables) {
        final columns =
            (await db.customSelect('PRAGMA table_info("$table")').get())
                .map((row) => row.data)
                .toList();
        await db.customStatement(
          '''INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,after_json,origin_sequence,observed_json,parent_ids_json,mutation_group_id)
          SELECT $syncOperationUuidSql,?,?,?,'$table',${syncKeyJson(columns, 'source.')},${syncRowJson(columns, 'source.')},
            context.device_sequence+row_number() OVER(ORDER BY ${syncKeyJson(columns, 'source.')}),
            json_set(context.observed_json,'\$.' || json_quote(context.device_id),context.device_sequence+row_number() OVER(ORDER BY ${syncKeyJson(columns, 'source.')})-1),'[]',context.mutation_group
          FROM "$table" AS source CROSS JOIN sync_capture_context AS context
          WHERE context.id=1 AND ${syncRowIsPortable(table, 'source.')}''',
          [workspaceId, accountId, deviceId],
        );
        await db.customStatement(
          'UPDATE sync_capture_context SET device_sequence=device_sequence+changes(), observed_json=json_set(observed_json,$syncDeviceClockPathSql,device_sequence+changes()) WHERE id=1',
        );
      }
      final firstSequence = current.read<int>('device_sequence') + 1;
      await db.customStatement(
        '''INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence,complete)
        SELECT mutation_group,workspace_id,account_id,device_id,?,device_sequence,1 FROM sync_capture_context WHERE id=1 AND device_sequence>=?''',
        [firstSequence, firstSequence],
      );
      await db.customStatement(
        '''INSERT INTO sync_entity_heads(workspace_id,entity,record_key,visible_revision)
        SELECT workspace_id,entity,record_key,operation_id FROM sync_journal
        WHERE workspace_id=? AND account_id=?
        ON CONFLICT(workspace_id,entity,record_key) DO UPDATE SET visible_revision=excluded.visible_revision''',
        [workspaceId, accountId],
      );
      await db.customStatement(
        'UPDATE sync_capture_context SET capture_enabled=1,mutation_group=NULL WHERE id=1',
      );
    });
    return beforeSync;
  }

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
