import 'dart:convert';
import 'dart:isolate';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Logical contents, rather than SQLite/WAL bytes: VACUUM and checkpointing
// must not look like user edits. The snapshot-only widget envelope is excluded.
Future<String> databaseFingerprint(String filename) =>
    Isolate.run(() => _fingerprint(filename));

String _fingerprint(String filename) {
  final db = sqlite.sqlite3.open(filename, mode: sqlite.OpenMode.readOnly);
  try {
    db.execute('BEGIN');
    return databaseContentsFingerprint(db);
  } finally {
    db.close();
  }
}

// Caller owns a consistent read transaction or an exclusive connection lock.
String databaseContentsFingerprint(sqlite.Database db) {
  final parts = <Object?>[db.userVersion];
  final tables = db.select(
    "SELECT name, sql FROM sqlite_master WHERE type='table' "
    "AND name NOT LIKE 'sqlite_%' AND name != 'backup_widget_personalization' ORDER BY name",
  );
  for (final table in tables) {
    final name = (table['name'] as String).replaceAll('"', '""');
    final rows = db.select('SELECT * FROM "$name" ORDER BY rowid');
    parts.add([
      table['name'],
      table['sql'],
      rows.columnNames,
      sha256
          .convert(
            utf8.encode(
              jsonEncode(rows.map((r) => r.values.toList()).toList()),
            ),
          )
          .toString(),
    ]);
  }
  return sha256.convert(utf8.encode(jsonEncode(parts))).toString();
}

Future<String> profilePreferencesFingerprint(Directory directory) async {
  final values = <String, String?>{};
  for (final name in const [
    'appearance-settings.json',
    'calendar-settings.json',
    'widget-tasks-configuration.json',
    'widget-calendar-configuration.json',
    'widget-tasks-presets.json',
    'widget-calendar-presets.json',
    'widget-settings.json',
  ]) {
    final file = File(path.join(directory.path, name));
    values[name] = await file.exists()
        ? sha256.convert(await file.readAsBytes()).toString()
        : null;
  }
  return sha256.convert(utf8.encode(jsonEncode(values))).toString();
}
