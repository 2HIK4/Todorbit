import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/migration_gate.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('old database is detected without writing or migrating it', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-manager-gate-',
    );
    final file = File('${directory.path}/legacy.sqlite');
    try {
      expect(await MigrationGate.olderSchema(file), isNull);
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('CREATE TABLE sample(id TEXT PRIMARY KEY, value TEXT)');
      raw.execute("INSERT INTO sample VALUES('stable-id','keep me')");
      raw.execute('PRAGMA user_version = 4');
      raw.close();
      final before = await file.readAsBytes();
      expect(await MigrationGate.olderSchema(file), 4);
      expect(await file.readAsBytes(), before);
      final verify = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      expect(verify.select('PRAGMA user_version').single.values.single, 4);
      expect(
        verify.select('SELECT value FROM sample').single.values.single,
        'keep me',
      );
      verify.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('current and unsupported database versions are distinguished', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-manager-gate-',
    );
    final file = File('${directory.path}/version.sqlite');
    try {
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('PRAGMA user_version = ${AppDatabase.currentSchemaVersion}');
      raw.close();
      expect(await MigrationGate.olderSchema(file), isNull);
      final newer = sqlite.sqlite3.open(file.path);
      newer.execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
      );
      newer.close();
      await expectLater(MigrationGate.olderSchema(file), throwsStateError);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
