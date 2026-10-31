import 'package:drift/drift.dart';

import 'sync_schema.dart';

Future<void> upgradeSyncExchangeSchema(GeneratedDatabase db) async {
  for (final definition in [
    'device_sequence INTEGER NOT NULL DEFAULT 0 CHECK(device_sequence>=0)',
    "observed_json TEXT NOT NULL DEFAULT '{}'",
    "received_json TEXT NOT NULL DEFAULT '{}'",
    'automatic_sync INTEGER NOT NULL DEFAULT 0 CHECK(automatic_sync IN (0,1))',
    'change_token TEXT',
    'last_success_utc TEXT',
    'failure_count INTEGER NOT NULL DEFAULT 0 CHECK(failure_count>=0)',
    'next_attempt_utc TEXT',
    'last_error_code TEXT',
    'mutation_group TEXT',
    'lease_owner TEXT',
    'lease_until_ms INTEGER',
    'lease_heartbeat_ms INTEGER',
    'suspended_for_restore INTEGER NOT NULL DEFAULT 0 CHECK(suspended_for_restore IN (0,1))',
  ]) {
    await db.customStatement(
      'ALTER TABLE sync_capture_context ADD COLUMN $definition',
    );
  }
  await db.customStatement('''CREATE TABLE sync_batches (
    id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, account_id TEXT NOT NULL,
    device_id TEXT NOT NULL, direction TEXT NOT NULL CHECK(direction IN ('incoming','outgoing')),
    payload BLOB NOT NULL, sha256 TEXT NOT NULL, created_at TEXT NOT NULL,
    uploaded INTEGER NOT NULL DEFAULT 0 CHECK(uploaded IN (0,1))
  )''');
  await db.customStatement('''CREATE TABLE sync_mutation_groups (
    id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, account_id TEXT NOT NULL, device_id TEXT NOT NULL,
    first_sequence INTEGER NOT NULL CHECK(first_sequence>0), last_sequence INTEGER NOT NULL CHECK(last_sequence>=first_sequence),
    complete INTEGER NOT NULL DEFAULT 0 CHECK(complete IN (0,1))
  )''');
  await db.customStatement('''CREATE TABLE sync_remote_objects (
    object_id TEXT PRIMARY KEY, batch_id TEXT NOT NULL REFERENCES sync_batches(id),
    md5 TEXT NOT NULL, bytes INTEGER NOT NULL CHECK(bytes>0)
  )''');
  for (final definition in [
    'origin_sequence INTEGER',
    "observed_json TEXT NOT NULL DEFAULT '{}'",
    "parent_ids_json TEXT NOT NULL DEFAULT '[]'",
    'batch_id TEXT REFERENCES sync_batches(id)',
    'known INTEGER NOT NULL DEFAULT 1 CHECK(known IN (0,1))',
    'mutation_group_id TEXT REFERENCES sync_mutation_groups(id) DEFERRABLE INITIALLY DEFERRED',
  ]) {
    await db.customStatement('ALTER TABLE sync_journal ADD COLUMN $definition');
  }
  await db.customStatement(
    '''UPDATE sync_journal SET origin_sequence=sequence,
    observed_json=CASE WHEN sequence>1 THEN json_object(device_id,sequence-1) ELSE '{}' END,
    parent_ids_json=CASE WHEN parent_id IS NULL THEN '[]' ELSE json_array(parent_id) END''',
  );
  await db.customStatement(
    '''UPDATE sync_capture_context SET
    device_sequence=coalesce((SELECT MAX(origin_sequence) FROM sync_journal WHERE device_id=sync_capture_context.device_id),0),
    observed_json=CASE WHEN device_id IS NULL THEN '{}' ELSE json_object(device_id,
      coalesce((SELECT MAX(origin_sequence) FROM sync_journal WHERE device_id=sync_capture_context.device_id),0)) END WHERE id=1''',
  );
  await db.customStatement(
    'UPDATE sync_capture_context SET received_json=observed_json WHERE id=1',
  );
  await db.customStatement(
    'CREATE UNIQUE INDEX sync_origin_revision ON sync_journal(workspace_id,account_id,device_id,origin_sequence)',
  );
  await db.customStatement(
    '''INSERT INTO sync_mutation_groups(id,workspace_id,account_id,device_id,first_sequence,last_sequence,complete)
    SELECT $syncOperationUuidSql,workspace_id,account_id,device_id,MIN(origin_sequence),MAX(origin_sequence),1
    FROM sync_journal GROUP BY workspace_id,account_id,device_id''',
  );
  await db.customStatement(
    '''UPDATE sync_journal SET mutation_group_id=(SELECT id FROM sync_mutation_groups g
    WHERE g.workspace_id=sync_journal.workspace_id AND g.account_id=sync_journal.account_id AND g.device_id=sync_journal.device_id)''',
  );
  await db.customStatement(
    "ALTER TABLE sync_entity_heads ADD COLUMN dismissed_heads_json TEXT NOT NULL DEFAULT '[]'",
  );
  await db.customStatement(
    'ALTER TABLE sync_entity_heads ADD COLUMN blocked_reason TEXT',
  );
  await db.customStatement(
    'ALTER TABLE sync_entity_heads ADD COLUMN materialized INTEGER NOT NULL DEFAULT 1 CHECK(materialized IN (0,1))',
  );
  final triggers = await db
      .customSelect(
        "SELECT name FROM sqlite_schema WHERE type='trigger' AND name GLOB 'sync_capture_*'",
      )
      .get();
  for (final trigger in triggers) {
    final name = trigger.read<String>('name').replaceAll('"', '""');
    await db.customStatement('DROP TRIGGER "$name"');
  }
  await installSyncCaptureTriggers(db, causal: true);
  await db.customStatement('''CREATE TRIGGER sync_batches_immutable BEFORE UPDATE OF id,workspace_id,account_id,device_id,direction,payload,sha256,created_at ON sync_batches
    BEGIN SELECT RAISE(ABORT,'Sync batch contents are immutable'); END''');
  await db.customStatement('''CREATE TRIGGER sync_journal_immutable BEFORE UPDATE OF sequence,operation_id,workspace_id,account_id,device_id,entity,record_key,parent_id,before_json,after_json,origin_sequence,observed_json,parent_ids_json,mutation_group_id ON sync_journal
    BEGIN SELECT RAISE(ABORT,'Sync operations are immutable'); END''');
  await db.customStatement(
    '''CREATE TRIGGER sync_groups_immutable BEFORE UPDATE OF workspace_id,account_id,device_id,first_sequence,last_sequence ON sync_mutation_groups
    WHEN OLD.complete=1 BEGIN SELECT RAISE(ABORT,'Completed sync groups are immutable'); END''',
  );
}
