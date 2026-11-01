import 'package:drift/drift.dart';

import 'sync_schema.dart';

Future<void> createSyncPortableFields(GeneratedDatabase db) async {
  final columns = await db.customSelect('PRAGMA table_info(timer_runs)').get();
  if (!columns.any((r) => r.read<String>('name') == 'owner_device_id')) {
    await db.customStatement(
      'ALTER TABLE timer_runs ADD COLUMN owner_device_id TEXT',
    );
  }
  await db.customStatement('''CREATE TABLE IF NOT EXISTS portable_preferences (
    key TEXT PRIMARY KEY, value_json TEXT NOT NULL CHECK(json_valid(value_json)),
    updated_at TEXT NOT NULL)''');
}

Future<void> upgradeSyncDeviceCapture(GeneratedDatabase db) async {
  await db.customStatement(
    "ALTER TABLE sync_journal ADD COLUMN intent TEXT NOT NULL DEFAULT 'edit' CHECK(intent IN ('edit','restore'))",
  );
  await db.customStatement("""CREATE TRIGGER sync_journal_intent_immutable BEFORE UPDATE OF intent ON sync_journal
    BEGIN SELECT RAISE(ABORT,'Sync intent is immutable'); END""");
  // Previously enabled prototype profiles need an explicit reconciliation:
  // adding a portable field cannot silently rewrite immutable journal facts.
  await db.customStatement('''UPDATE sync_capture_context SET automatic_sync=0,
    capture_enabled=CASE WHEN workspace_id IS NULL THEN capture_enabled ELSE 0 END,
    restore_quarantined=CASE WHEN workspace_id IS NULL THEN restore_quarantined ELSE 1 END,
    lease_owner=NULL,lease_until_ms=NULL,lease_heartbeat_ms=NULL WHERE id=1''');
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
}
