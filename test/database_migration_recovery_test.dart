import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/migration_gate.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('Database Migration & Forward Recovery Tests', () {
    test('migrates schema 27 to currentSchemaVersion preserving all user data and relationships', () async {
      final tempDir = await Directory.systemTemp.createTemp('todorbit-mig-test-');
      final dbFile = File('${tempDir.path}/legacy_27.sqlite');

      try {
        // Step 1: Initialize database with full initial schema and insert realistic user data
        var db = AppDatabase(NativeDatabase(dbFile));
        var repo = LifeRepository(db);

        final category = await repo.addCategory('Work');
        final project = await repo.addProject(category.id, 'Q1 Release');
        final task = await repo.addTask(
          TaskDraft(
            title: 'Ship Beta 27',
            notes: 'Critical launch notes',
            status: TaskStatus.inProgress,
            priority: 3,
            categoryId: category.id,
            projectId: project.id,
            plannedDurationMinutes: 120,
          ),
        );
        final event = await repo.addEvent(
          EventDraft(
            title: 'Sprint Review',
            startsAt: DateTime.utc(2026, 11, 25, 14),
            endsAt: DateTime.utc(2026, 11, 25, 15),
            categoryId: category.id,
          ),
        );

        expect(task.title, 'Ship Beta 27');
        expect(event.title, 'Sprint Review');
        await db.close();

        // Step 2: Set user_version to 27 in raw SQLite to simulate upgrading from schema 27
        final raw = sqlite.sqlite3.open(dbFile.path);
        raw.execute('PRAGMA user_version = 27');
        raw.close();

        // Step 3: MigrationGate detects older schema 27
        final olderVersion = await MigrationGate.olderSchema(dbFile);
        expect(olderVersion, 27);

        // Step 4: Open database through AppDatabase which triggers onUpgrade to currentSchemaVersion
        db = AppDatabase(NativeDatabase(dbFile));
        repo = LifeRepository(db);

        final versionRows = await db.customSelect('PRAGMA user_version').get();
        expect(versionRows.single.data['user_version'], AppDatabase.currentSchemaVersion);

        // Step 5: Verify all user data survived migration completely intact
        final loadedTasks = await repo.tasks();
        final loadedTask = loadedTasks.singleWhere((t) => t.id == task.id);
        expect(loadedTask.title, 'Ship Beta 27');
        expect(loadedTask.notes, 'Critical launch notes');
        expect(loadedTask.status, TaskStatus.inProgress);
        expect(loadedTask.priority, 3);
        expect(loadedTask.categoryId, category.id);
        expect(loadedTask.projectId, project.id);
        expect(loadedTask.plannedDurationMinutes, 120);

        final loadedEvents = await repo.events();
        final loadedEvent = loadedEvents.singleWhere((e) => e.id == event.id);
        expect(loadedEvent.title, 'Sprint Review');
        expect(loadedEvent.categoryId, category.id);

        // Step 6: Verify MigrationGate now reports null (up-to-date schema)
        await db.close();
        final gateCheck = await MigrationGate.olderSchema(dbFile);
        expect(gateCheck, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('future schema version throws StateError and aborts without overwriting', () async {
      final tempDir = await Directory.systemTemp.createTemp('todorbit-future-test-');
      final dbFile = File('${tempDir.path}/future.sqlite');

      try {
        final raw = sqlite.sqlite3.open(dbFile.path);
        raw.execute('PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 5}');
        raw.execute('CREATE TABLE sample(id TEXT PRIMARY KEY, data TEXT)');
        raw.execute("INSERT INTO sample VALUES('id-1', 'preserved future data')");
        raw.close();

        // MigrationGate must throw StateError on future schema versions
        await expectLater(
          MigrationGate.olderSchema(dbFile),
          throwsStateError,
        );

        // Verify data was not deleted or mutated
        final verify = sqlite.sqlite3.open(dbFile.path, mode: sqlite.OpenMode.readOnly);
        expect(
          verify.select('SELECT data FROM sample').single.values.single,
          'preserved future data',
        );
        verify.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
