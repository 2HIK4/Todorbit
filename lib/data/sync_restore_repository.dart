part of 'life_repository.dart';

Object? _recoveryFact(String column, Object? value) {
  if (value is String && (column.endsWith('_json') || column == 'record_key')) {
    return jsonDecode(value);
  }
  return value;
}

extension SyncRestoreRepository on LifeRepository {
  Future<void> _retainRecoveryTable(
    AppDatabase source,
    String table,
    String primary,
    SyncBinding binding,
  ) async {
    String after = '';
    while (true) {
      final ids = await source
          .customSelect(
            '''SELECT "$primary" FROM "$table"
        WHERE workspace_id=? AND account_id=? AND "$primary">? ORDER BY "$primary" LIMIT 64''',
            variables: [
              Variable.withString(binding.workspace),
              Variable.withString(binding.account),
              Variable.withString(after),
            ],
          )
          .get();
      if (ids.isEmpty) break;
      for (final identifier in ids) {
        final id = identifier.read<String>(primary);
        final row = await source
            .customSelect(
              'SELECT * FROM "$table" WHERE "$primary"=?',
              variables: [Variable.withString(id)],
            )
            .getSingle();
        final prior = await db
            .customSelect(
              'SELECT * FROM "$table" WHERE "$primary"=?',
              variables: [Variable.withString(id)],
            )
            .get();
        final value = Map<String, Object?>.from(row.data)..remove('sequence');
        if (prior.isNotEmpty) {
          final mutable = table == 'sync_journal'
              ? {'known', 'uploaded', 'batch_id'}
              : table == 'sync_batches'
              ? {'uploaded', 'superseded', 'direction', 'created_at', 'payload'}
              : {'complete', 'materialized', 'blocked_reason'};
          for (final column in value.keys.where(
            (key) => !mutable.contains(key),
          )) {
            if (!_syncSame(
              _recoveryFact(column, prior.single.data[column]),
              _recoveryFact(column, value[column]),
            )) {
              throw StateError(
                'The recovery snapshot reuses an immutable sync identity. No reconciliation was committed.',
              );
            }
          }
          if (table == 'sync_batches') {
            final payload = value['payload'] as Uint8List;
            if (await _syncBytesDigest(payload) != value['sha256'] ||
                await _syncBytesDigest(
                      prior.single.data['payload'] as Uint8List,
                    ) !=
                    value['sha256'] ||
                (prior.single.data['payload'] as Uint8List).length !=
                    payload.length) {
              throw StateError(
                'Recovery ciphertext differs from the retained batch.',
              );
            }
          }
          if (table == 'sync_journal' || table == 'sync_batches') {
            await db.customStatement(
              'UPDATE "$table" SET uploaded=max(uploaded,?) WHERE "$primary"=?',
              [value['uploaded'], id],
            );
          }
        } else {
          if (table == 'sync_mutation_groups') {
            value['materialized'] = 0;
            value['blocked_reason'] = null;
          }
          if (table == 'sync_batches' &&
              await _syncBytesDigest(value['payload'] as Uint8List) !=
                  value['sha256']) {
            throw StateError('Recovery ciphertext is damaged.');
          }
          final columns = value.keys.toList();
          await db.customStatement(
            'INSERT INTO "$table"(${columns.map((c) => '"$c"').join(',')}) VALUES(${List.filled(columns.length, '?').join(',')})',
            columns.map((c) => value[c]).toList(),
          );
        }
        if (table == 'sync_journal') {
          await db.customStatement(
            '''UPDATE sync_journal SET uploaded=max(uploaded,
            coalesce((SELECT uploaded FROM sync_batches WHERE id=sync_journal.batch_id),0)) WHERE operation_id=?''',
            [id],
          );
        }
        after = id;
      }
    }
  }

  // Called only after explicit restored-profile review and workspace proof.
  // Domain rows and immutable facts are never removed. A fresh device identity
  // expresses the restored view as ONE causal action; newer cloud facts remain
  // concurrent candidates rather than being implicitly acknowledged/deleted.
  Future<BackupRecord> reconcileRestoredSync({
    required SyncBinding binding,
    required BackupService recovery,
    AppDatabase? beforeRestore,
  }) async {
    if (!Uuid.isValidUUID(fromString: binding.device) ||
        !Uuid.isValidUUID(fromString: binding.workspace)) {
      throw const FormatException('Invalid restored-profile sync identity');
    }
    final context = await db
        .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
        .getSingle();
    if (context.read<int>('restore_quarantined') != 1 ||
        context.read<int>('capture_enabled') != 0) {
      throw StateError(
        'This profile is not awaiting restored-state reconciliation.',
      );
    }
    if (context.readNullable<String>('workspace_id') != null &&
        (context.readNullable<String>('workspace_id') != binding.workspace ||
            context.readNullable<String>('account_id') != binding.account)) {
      throw StateError(
        'The restored history belongs to another account/workspace. Keep its snapshots and pair that original workspace first.',
      );
    }
    if (await recovery.hasScheduledRestore()) {
      throw StateError('Finish or cancel the pending restore first.');
    }
    final databases = await db.customSelect('PRAGMA database_list').get();
    final filename = databases
        .singleWhere((r) => r.read<String>('name') == 'main')
        .read<String>('file');
    if (!await _syncRecoveryFileMatches(filename, recovery.databaseFile)) {
      throw StateError('Recovery backup does not belong to this profile.');
    }
    final archive = await recovery.createBackup(BackupKind.manual);
    final fingerprint = await databaseFingerprint(archive.file.path);
    await db.transaction(() async {
      await db.customStatement(
        'UPDATE sync_capture_context SET capture_enabled=capture_enabled WHERE id=1',
      );
      final fresh = await db
          .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
          .getSingle();
      if (fresh.data.keys.any(
            (key) => !_syncSame(fresh.data[key], context.data[key]),
          ) ||
          await databaseFingerprint(filename) != fingerprint ||
          await recovery.hasScheduledRestore()) {
        throw StateError(
          'Local data changed during recovery preparation. Review it again; nothing was reconciled.',
        );
      }
      if ((await db
              .customSelect(
                'SELECT 1 FROM sync_journal WHERE device_id=? LIMIT 1',
                variables: [Variable.withString(binding.device)],
              )
              .get())
          .isNotEmpty) {
        throw StateError(
          'Reconciliation requires a fresh device identity, without reused sequence numbers.',
        );
      }
      if (beforeRestore != null) {
        final original = await beforeRestore
            .customSelect('SELECT * FROM sync_capture_context WHERE id=1')
            .getSingle();
        if (original.readNullable<String>('workspace_id') != null) {
          if (original.readNullable<String>('workspace_id') !=
                  binding.workspace ||
              original.readNullable<String>('account_id') != binding.account) {
            throw StateError(
              'Before Restore history belongs to a different workspace. Its pending work must be recovered separately.',
            );
          }
          // Groups first and deferred journal FKs preserve complete original
          // actions. Existing materialized groups retain restored visibility;
          // newly recovered groups are retained but not silently applied.
          await _retainRecoveryTable(
            beforeRestore,
            'sync_mutation_groups',
            'id',
            binding,
          );
          await _retainRecoveryTable(
            beforeRestore,
            'sync_batches',
            'id',
            binding,
          );
          await _retainRecoveryTable(
            beforeRestore,
            'sync_journal',
            'operation_id',
            binding,
          );
        }
      }
      final group = _uuid.v4();
      final observed = (jsonDecode(
        context.read<String>('received_json'),
      ) as Map).cast<String, Object?>();
      observed.remove(binding.device);
      await db.customStatement(
        '''UPDATE sync_capture_context SET workspace_id=?,account_id=?,device_id=?,
        device_sequence=0,observed_json=?,received_json=?,mutation_group=?,lease_owner=NULL,
        lease_until_ms=NULL,lease_heartbeat_ms=NULL WHERE id=1''',
        [
          binding.workspace,
          binding.account,
          binding.device,
          jsonEncode(observed),
          jsonEncode(observed),
          group,
        ],
      );
      for (final table in portableSyncTables) {
        final columns =
            (await db.customSelect('PRAGMA table_info("$table")').get())
                .map((r) => r.data)
                .toList();
        final key = syncKeyJson(columns, 'r.');
        final own = "'\$.' || json_quote(c.device_id)";
        await db.customStatement(
          '''INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,
          parent_id,before_json,after_json,origin_sequence,observed_json,parent_ids_json,mutation_group_id,visible_json,intent)
          SELECT $syncOperationUuidSql,c.workspace_id,c.account_id,c.device_id,'$table',$key,
          h.visible_revision,(SELECT after_json FROM sync_journal WHERE operation_id=h.visible_revision),${syncRowJson(columns, 'r.')},
          c.device_sequence+row_number() OVER(ORDER BY $key),
          json_set(c.observed_json,$own,c.device_sequence+row_number() OVER(ORDER BY $key)-1),
          coalesce(h.visible_heads_json,'[]'),c.mutation_group,
          CASE WHEN c.device_sequence+row_number() OVER(ORDER BY $key)>1 THEN
          json_set(c.visible_json,$own,json_array(json_array(1,c.device_sequence+row_number() OVER(ORDER BY $key)-1))) ELSE c.visible_json END,'restore'
          FROM "$table" r CROSS JOIN sync_capture_context c LEFT JOIN sync_entity_heads h
          ON h.workspace_id=c.workspace_id AND h.entity='$table' AND h.record_key=$key
          WHERE c.id=1 AND ${syncRowIsPortable(table, 'r.')}''',
        );
        await _advanceRestoredLocalSequence();
        final primary = columns
            .where((c) => (c['pk'] as int) > 0)
            .map((c) => c['name'] as String)
            .toList();
        await db.customStatement(
          '''INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,
          parent_id,before_json,after_json,origin_sequence,observed_json,parent_ids_json,mutation_group_id,visible_json,intent)
          SELECT $syncOperationUuidSql,c.workspace_id,c.account_id,c.device_id,h.entity,h.record_key,
          h.visible_revision,j.after_json,NULL,c.device_sequence+row_number() OVER(ORDER BY h.record_key),
          json_set(c.observed_json,$own,c.device_sequence+row_number() OVER(ORDER BY h.record_key)-1),
          h.visible_heads_json,c.mutation_group,
          CASE WHEN c.device_sequence+row_number() OVER(ORDER BY h.record_key)>1 THEN
          json_set(c.visible_json,$own,json_array(json_array(1,c.device_sequence+row_number() OVER(ORDER BY h.record_key)-1))) ELSE c.visible_json END,'restore'
          FROM sync_entity_heads h JOIN sync_journal j ON j.operation_id=h.visible_revision CROSS JOIN sync_capture_context c
          WHERE c.id=1 AND h.workspace_id=c.workspace_id AND h.entity='$table' AND j.after_json IS NOT NULL
          AND NOT EXISTS(SELECT 1 FROM "$table" r WHERE ${primary.map((k) => 'r."$k" IS json_extract(h.record_key,\'\$.$k\')').join(' AND ')})''',
        );
        await _advanceRestoredLocalSequence();
      }
      await db.customStatement(
        '''INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence,complete,materialized)
        SELECT mutation_group,workspace_id,account_id,device_id,1,device_sequence,1,1 FROM sync_capture_context WHERE id=1 AND device_sequence>0''',
      );
      await db.customStatement(
        '''INSERT INTO sync_entity_heads(workspace_id,entity,record_key,visible_revision,visible_heads_json)
        SELECT workspace_id,entity,record_key,operation_id,json_array(operation_id) FROM sync_journal WHERE mutation_group_id=?
        ON CONFLICT(workspace_id,entity,record_key) DO UPDATE SET visible_revision=excluded.visible_revision,
        visible_heads_json=excluded.visible_heads_json,dismissed_heads_json='[]',blocked_reason=NULL,materialized=1''',
        [group],
      );
      await _validateRetainedSyncParents(binding);
      await _advanceKnownSyncHistory(binding);
      await _completeRetainedSyncGroups(binding);
      // Before Restore rows can already be known, so the normal unknown-row
      // closure does not advance their received clocks. Merge them only AFTER
      // capturing the restored view: that action must remain concurrent with
      // newer retained work, while subsequent edits/decisions observe it.
      final known = await db
          .customSelect(
            '''SELECT device_id,max(origin_sequence) AS last_sequence
        FROM sync_journal WHERE workspace_id=? AND account_id=? AND known=1
        GROUP BY device_id''',
            variables: [
              Variable.withString(binding.workspace),
              Variable.withString(binding.account),
            ],
          )
          .get();
      for (final row in known) {
        await db.customStatement(
          '''UPDATE sync_capture_context SET received_json=json_set(received_json,
          '\$.' || json_quote(?),max(coalesce(json_extract(received_json,
          '\$.' || json_quote(?)),0),?)) WHERE id=1''',
          [
            row.read<String>('device_id'),
            row.read<String>('device_id'),
            row.read<int>('last_sequence'),
          ],
        );
      }
      await db.customStatement(
        '''UPDATE sync_capture_context SET capture_enabled=1,restore_quarantined=0,
        suspended_for_restore=0,mutation_group=NULL,automatic_sync=0,change_token=NULL,
        observed_json=received_json,last_error_code=NULL,failure_count=0,next_attempt_utc=NULL WHERE id=1''',
      );
    });
    return archive;
  }

  Future<void> _advanceRestoredLocalSequence() => db.customStatement(
    '''UPDATE sync_capture_context
    SET device_sequence=device_sequence+changes(),observed_json=json_set(observed_json,$syncDeviceClockPathSql,device_sequence+changes()),
    received_json=json_set(received_json,$syncDeviceClockPathSql,device_sequence+changes()),
    visible_json=CASE WHEN device_sequence+changes()>0 THEN json_set(visible_json,$syncDeviceClockPathSql,json_array(json_array(1,device_sequence+changes()))) ELSE visible_json END WHERE id=1''',
  );
}
