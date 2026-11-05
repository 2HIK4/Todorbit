import 'package:drift/drift.dart';

// Delivery ledgers, device notification policy and OS surface identifiers stay
// local. Managed resource bytes travel with the resource row; external targets
// remain references and never imply copying arbitrary filesystem contents.
const portableSyncTables = <String>{
  'tasks',
  'categories',
  'projects',
  'fixed_events',
  'event_detail_types',
  'work_sessions',
  'availability_windows',
  'availability_exceptions',
  'scheduling_operations',
  'scheduling_changes',
  'task_sequences',
  'sequence_tasks',
  'task_dependencies',
  'recurrence_series',
  'recurrence_occurrences',
  'series_edit_history',
  'recurrence_collision_history',
  'habits',
  'habit_entries',
  'habit_rest_days',
  'habit_entry_history',
  'goals',
  'goal_milestones',
  'goal_progress_entries',
  'goal_task_links',
  'goal_project_links',
  'goal_habit_links',
  'timer_runs',
  'time_entries',
  'time_entry_history',
  'templates',
  'saved_views',
  'deletion_tombstones',
  'task_resources',
  'event_occurrence_changes',
  'entity_icons',
  'task_parent_links',
  'task_checklist',
  'task_checklist_groups',
  'progressive_plans',
  'progressive_plan_steps',
  'progressive_plan_assignments',
  'portable_preferences',
};

const syncOperationUuidSql =
    "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))),2) || '-' || substr('89ab',(random() & 3)+1,1) || substr(lower(hex(randomblob(2))),2) || '-' || lower(hex(randomblob(6)))";
const syncDeviceClockPathSql = r"'$.' || json_quote(device_id)";

String syncRowIsPortable(String table, String prefix) =>
    table == 'task_resources'
    ? "(${prefix}kind='managed' OR (${prefix}kind='url' AND (${prefix}target LIKE 'https://%' OR ${prefix}target LIKE 'http://%')))"
    : '1';

String syncRowJson(List<Map<String, Object?>> columns, String prefix) =>
    'json_object(${columns.map((column) {
      final name = column['name'] as String;
      final reference = '$prefix"$name"';
      return "'$name',CASE WHEN typeof($reference)='blob' THEN json_object('\$blob',hex($reference)) ELSE $reference END";
    }).join(',')})';

String syncKeyJson(List<Map<String, Object?>> columns, String prefix) {
  final keys = columns.where((column) => (column['pk'] as int) > 0).toList()
    ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
  if (keys.isEmpty) {
    throw StateError('Portable sync table has no stable primary key');
  }
  return syncRowJson(keys, prefix);
}

Future<void> createSyncSchema(
  GeneratedDatabase db, {
  bool installTriggers = true,
}) async {
  await db.customStatement('''CREATE TABLE sync_capture_context (
    id INTEGER PRIMARY KEY CHECK(id=1),
    workspace_id TEXT, account_id TEXT, device_id TEXT,
    capture_enabled INTEGER NOT NULL DEFAULT 0 CHECK(capture_enabled IN (0,1)),
    applying_remote INTEGER NOT NULL DEFAULT 0 CHECK(applying_remote IN (0,1)),
    restore_quarantined INTEGER NOT NULL DEFAULT 0 CHECK(restore_quarantined IN (0,1)),
    CHECK(capture_enabled=0 OR (workspace_id IS NOT NULL AND account_id IS NOT NULL AND device_id IS NOT NULL))
  )''');
  await db.customStatement('INSERT INTO sync_capture_context(id) VALUES(1)');
  await db.customStatement('''CREATE TABLE sync_journal (
    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL UNIQUE,
    workspace_id TEXT NOT NULL, account_id TEXT NOT NULL, device_id TEXT NOT NULL,
    entity TEXT NOT NULL, record_key TEXT NOT NULL,
    parent_id TEXT, before_json TEXT, after_json TEXT,
    uploaded INTEGER NOT NULL DEFAULT 0 CHECK(uploaded IN (0,1))
  )''');
  await db.customStatement(
    'CREATE INDEX sync_journal_pending ON sync_journal(workspace_id,account_id,uploaded,sequence)',
  );
  await db.customStatement('''CREATE TABLE sync_entity_heads (
    workspace_id TEXT NOT NULL, entity TEXT NOT NULL, record_key TEXT NOT NULL,
    visible_revision TEXT NOT NULL,
    PRIMARY KEY(workspace_id,entity,record_key)
  )''');
  if (installTriggers) {
    await installSyncCaptureTriggers(db);
  }
}

Future<void> installSyncCaptureTriggers(
  GeneratedDatabase db, {
  bool causal = false,
  bool visibility = false,
}) async {
  for (final table in portableSyncTables) {
    final columns = (await db.customSelect('PRAGMA table_info("$table")').get())
        .map((row) => row.data)
        .toList();
    if (columns.isEmpty) {
      throw StateError('Portable sync table is missing: $table');
    }
    final oldRow = syncRowJson(columns, 'OLD.');
    final newRow = syncRowJson(columns, 'NEW.');
    for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
      final key = syncKeyJson(columns, action == 'DELETE' ? 'OLD.' : 'NEW.');
      final oldKey = syncKeyJson(columns, 'OLD.');
      final oldPortable = syncRowIsPortable(table, 'OLD.');
      final newPortable = syncRowIsPortable(table, 'NEW.');
      final portable = switch (action) {
        'INSERT' => newPortable,
        'DELETE' => oldPortable,
        _ => '($oldPortable OR $newPortable)',
      };
      final before = action == 'INSERT'
          ? 'NULL'
          : 'CASE WHEN $oldPortable ${action == 'UPDATE' ? 'AND $oldKey IS $key' : ''} THEN $oldRow ELSE NULL END';
      final after = action == 'DELETE'
          ? 'NULL'
          : 'CASE WHEN $newPortable THEN $newRow ELSE NULL END';
      await db.customStatement(
        '''CREATE TRIGGER sync_capture_${table}_${action.toLowerCase()}
        AFTER $action ON "$table"
        WHEN (SELECT capture_enabled=1 AND applying_remote=0 FROM sync_capture_context WHERE id=1)
          AND $portable
          ${action == 'UPDATE' ? 'AND $oldRow IS NOT $newRow' : ''}
        BEGIN
          ${action == 'UPDATE' ? _captureMutation(table, oldKey, oldRow, 'NULL', '$oldKey IS NOT $key AND $oldPortable', causal, visibility) : ''}
          ${_captureMutation(table, key, before, after, action == 'UPDATE' ? '($oldKey IS $key OR $newPortable)' : '1', causal, visibility)}
        END''',
      );
    }
  }
}

String _captureMutation(
  String table,
  String key,
  String before,
  String after,
  String condition,
  bool causal,
  bool visibility,
) =>
    '''
  INSERT INTO sync_journal(operation_id,workspace_id,account_id,device_id,entity,record_key,parent_id,before_json,after_json${causal ? ',origin_sequence,observed_json,parent_ids_json,mutation_group_id' : ''}${visibility ? ',visible_json' : ''})
  SELECT $syncOperationUuidSql,workspace_id,account_id,device_id,'$table',$key,
    (SELECT visible_revision FROM sync_entity_heads WHERE workspace_id=sync_capture_context.workspace_id AND entity='$table' AND record_key=$key),
    $before,$after${causal ? ",device_sequence+1,observed_json,coalesce((SELECT ${visibility ? 'visible_heads_json' : 'json_array(visible_revision)'} FROM sync_entity_heads WHERE workspace_id=sync_capture_context.workspace_id AND entity='$table' AND record_key=$key),'[]'),coalesce(mutation_group,$syncOperationUuidSql)" : ''}${visibility ? ',visible_json' : ''} FROM sync_capture_context WHERE id=1 AND ($condition);
  INSERT INTO sync_entity_heads(workspace_id,entity,record_key,visible_revision${visibility ? ',visible_heads_json' : ''})
  SELECT workspace_id,entity,record_key,operation_id${visibility ? ',json_array(operation_id)' : ''} FROM sync_journal WHERE sequence=last_insert_rowid() AND ($condition)
  ON CONFLICT(workspace_id,entity,record_key) DO UPDATE SET visible_revision=excluded.visible_revision${visibility ? ',visible_heads_json=excluded.visible_heads_json' : ''};
  ${causal ? "UPDATE sync_capture_context SET device_sequence=device_sequence+1,observed_json=json_set(observed_json,$syncDeviceClockPathSql,device_sequence+1)${visibility ? ',received_json=json_set(received_json,$syncDeviceClockPathSql,device_sequence+1),visible_json=json_set(visible_json,$syncDeviceClockPathSql,json_array(json_array(1,device_sequence+1)))' : ''} WHERE id=1 AND ($condition);" : ''}
  ${causal ? '''INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence,complete${visibility ? ',materialized' : ''})
    SELECT j.mutation_group_id,j.workspace_id,j.account_id,j.device_id,j.origin_sequence,j.origin_sequence,CASE WHEN c.mutation_group IS NULL THEN 1 ELSE 0 END${visibility ? ',1' : ''}
    FROM sync_journal j JOIN sync_capture_context c ON c.id=1 AND j.device_id=c.device_id AND j.origin_sequence=c.device_sequence
      AND j.workspace_id=c.workspace_id AND j.account_id=c.account_id WHERE ($condition)
    ON CONFLICT(id) DO UPDATE SET last_sequence=excluded.last_sequence;''' : ''}
''';
