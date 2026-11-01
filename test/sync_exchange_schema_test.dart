import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_schema.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'support/legacy_sync_fixture.dart';

class _Schema23Connection extends AppDatabase {
  _Schema23Connection(super.executor);
  @override
  int get schemaVersion => 23;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      throw StateError('An existing synthetic schema-23 fixture is required');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );
}

void main() {
  test('schema 23 queue upgrades intact and quarantines prototype capture until reviewed recovery', () async {
    final root = await Directory.systemTemp.createTemp('todorbit-sync-v23-');
    final file = File('${root.path}/life.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      await db.customSelect('SELECT 1').get();
      await db.close();
      final fixture = sqlite.sqlite3.open(file.path);
      try {
        stripSyncSchemaForLegacyFixture(fixture);
        fixture.execute('PRAGMA user_version=23');
      } finally {
        fixture.close();
      }
      // Install the actual schema-23 capture model, not a relabeled schema 24.
      db = _Schema23Connection(NativeDatabase(file));
      await createSyncSchema(db);
      const device = 'd9866493-688e-4a6f-bf94-886e20472503';
      await db.customStatement(
        "UPDATE sync_capture_context SET workspace_id='fixture-workspace',account_id='fixture-account',device_id=?,capture_enabled=1 WHERE id=1",
        [device],
      );
      final first = await LifeRepository(db)
          .addTask(const TaskDraft(title: 'Retain queued work'));
      final before = await db
          .customSelect('SELECT * FROM sync_journal')
          .getSingle();
      await db.customStatement('PRAGMA user_version=23');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      final retained = await db
          .customSelect('SELECT * FROM sync_journal')
          .getSingle();
      expect(
        retained.read<String>('operation_id'),
        before.read<String>('operation_id'),
      );
      expect(retained.read<int>('origin_sequence'), 1);
      expect((await LifeRepository(db).tasks()).single.id, first.id);
      await LifeRepository(db)
          .addTask(const TaskDraft(title: 'Next offline edit'));
      final retainedAfterEdit =
          (await db
                  .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
                  .get())
              .single;
      expect(
        retainedAfterEdit.read<String>('operation_id'),
        before.read<String>('operation_id'),
      );
      expect(retainedAfterEdit.read<int>('origin_sequence'), 1);
      expect((await LifeRepository(db).tasks()), hasLength(2));
      final context = await db
          .customSelect('SELECT * FROM sync_capture_context')
          .getSingle();
      expect(context.read<int>('capture_enabled'), 0);
      expect(context.read<int>('restore_quarantined'), 1);
      expect(context.read<int>('automatic_sync'), 0);
      expect(context.read<int>('device_sequence'), 1);
      expect(jsonDecode(context.read<String>('observed_json')), {device: 1});
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });
}
