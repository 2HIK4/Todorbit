import 'package:sqlite3/sqlite3.dart' as sqlite;

// Only for synthetic current-schema files that a migration test converts to an
// older schema. Never remove journals containing work, even in this helper.
void stripSyncSchemaForLegacyFixture(sqlite.Database database) {
  final context = database.select(
    "SELECT name FROM sqlite_schema WHERE type='table' AND name='sync_capture_context'",
  );
  if (context.isEmpty) return;
  if (database.select('SELECT 1 FROM sync_journal LIMIT 1').isNotEmpty ||
      database
          .select(
            'SELECT 1 FROM sync_capture_context WHERE capture_enabled!=0 OR workspace_id IS NOT NULL',
          )
          .isNotEmpty) {
    throw StateError(
      'Legacy fixture must not contain a paired workspace or queued work',
    );
  }
  final triggers = database.select(
    "SELECT name FROM sqlite_schema WHERE type='trigger' AND name GLOB 'sync_capture_*'",
  );
  for (final row in triggers) {
    final name = (row['name'] as String).replaceAll('"', '""');
    database.execute('DROP TRIGGER "$name"');
  }
  for (final table in [
    'sync_journal',
    'sync_entity_heads',
    'sync_capture_context',
  ]) {
    database.execute('DROP TABLE "$table"');
  }
}
