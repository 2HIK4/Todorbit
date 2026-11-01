import 'package:drift/drift.dart';

import 'sync_schema.dart';

Future<void> upgradeSyncVisibilitySchema(GeneratedDatabase db) async {
  await db.customStatement(
    "ALTER TABLE sync_capture_context ADD COLUMN visible_json TEXT NOT NULL DEFAULT '{}'",
  );
  await db.customStatement(
    "ALTER TABLE sync_journal ADD COLUMN visible_json TEXT NOT NULL DEFAULT '{}'",
  );
  await db.customStatement(
    "ALTER TABLE sync_entity_heads ADD COLUMN visible_heads_json TEXT NOT NULL DEFAULT '[]'",
  );
  await db.customStatement(
    'ALTER TABLE sync_mutation_groups ADD COLUMN materialized INTEGER NOT NULL DEFAULT 0 CHECK(materialized IN (0,1))',
  );
  await db.customStatement(
    'ALTER TABLE sync_mutation_groups ADD COLUMN blocked_reason TEXT',
  );
  await db.customStatement(
    'ALTER TABLE sync_batches ADD COLUMN superseded INTEGER NOT NULL DEFAULT 0 CHECK(superseded IN (0,1))',
  );
  // Schema24 never materialized incoming operations. Only original local
  // mutations are established as visible; received history is not inferred.
  await db.customStatement(
    '''UPDATE sync_journal SET visible_json=CASE WHEN origin_sequence>1
    THEN json_object(device_id,json_array(json_array(1,origin_sequence-1))) ELSE '{}' END
    WHERE device_id=(SELECT device_id FROM sync_capture_context WHERE id=1)''',
  );
  await db.customStatement(
    '''UPDATE sync_capture_context SET visible_json=CASE WHEN device_sequence>0
    THEN json_object(device_id,json_array(json_array(1,device_sequence))) ELSE '{}' END,
    lease_owner=NULL,lease_until_ms=NULL,lease_heartbeat_ms=NULL,automatic_sync=0 WHERE id=1''',
  );
  await db.customStatement('''UPDATE sync_mutation_groups SET materialized=1
    WHERE device_id=(SELECT device_id FROM sync_capture_context WHERE id=1)''');
  await db.customStatement(
    'UPDATE sync_entity_heads SET visible_heads_json=json_array(visible_revision)',
  );
  // Preserve original encrypted bytes for recovery. Pending old-schema batches
  // are archived and their immutable operations are restaged with visibility.
  await db.customStatement(
    "UPDATE sync_batches SET superseded=1 WHERE direction='outgoing' AND uploaded=0",
  );
  await db.customStatement(
    '''UPDATE sync_journal SET batch_id=NULL WHERE uploaded=0
    AND batch_id IN (SELECT id FROM sync_batches WHERE superseded=1)''',
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
  await installSyncCaptureTriggers(db, causal: true, visibility: true);
  await db.customStatement('''CREATE TRIGGER sync_journal_visibility_immutable BEFORE UPDATE OF visible_json ON sync_journal
    BEGIN SELECT RAISE(ABORT,'Sync visibility is immutable'); END''');
}
