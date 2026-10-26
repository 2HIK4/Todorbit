import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'app_database.dart';

/// Reads only the SQLite header/schema. No migration or backup is started here.
/// A result of 0 identifies unfinished initialization, not an approved upgrade.
/// AppDatabase validates and completes only empty, compatible partial schemas.
class MigrationGate {
  static Future<int?> olderSchema(File databaseFile) async {
    if (!await databaseFile.exists()) return null;
    final connection = sqlite.sqlite3.open(
      databaseFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final version =
          connection.select('PRAGMA user_version').single.values.single as int;
      if (version < 0 || version > AppDatabase.currentSchemaVersion) {
        throw StateError('Unsupported database schema $version');
      }
      return version < AppDatabase.currentSchemaVersion ? version : null;
    } finally {
      connection.close();
    }
  }
}
