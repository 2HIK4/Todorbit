import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('snapshot includes event detail catalog and inherited colors', () async {
    final directory = await Directory.systemTemp.createTemp('todorbit-event-backup-');
    final file = File('${directory.path}/life.sqlite');
    final database = AppDatabase(NativeDatabase(file));
    try {
      final repo = LifeRepository(database);
      final category = await repo.addCategory('Meetings');
      await repo.setCategoryEventColor(category.id, 0xFF123456);
      final type = await repo.addEventDetailType('Organizer');
      await repo.addEvent(EventDraft(
        title: 'Review', startsAt: DateTime(2026, 10, 25, 9),
        endsAt: DateTime(2026, 10, 25, 10), categoryId: category.id,
        details: [EventDetail(typeId: type.id, label: type.name, value: 'Alex')],
      ));
      final backup = await BackupService(file).createBackup(BackupKind.manual);
      final snapshot = sqlite.sqlite3.open(backup.file.path, mode: sqlite.OpenMode.readOnly);
      try {
        expect(snapshot.select('SELECT event_color FROM categories').single['event_color'], 0xFF123456);
        expect(snapshot.select('SELECT name FROM event_detail_types').single['name'], 'Organizer');
        expect(snapshot.select('SELECT details_json FROM fixed_events').single['details_json'], contains('Alex'));
      } finally {
        snapshot.close();
      }
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'snapshot includes WAL data and is independent of later writes',
    () async {
      final directory = await Directory.systemTemp.createTemp('life-backup-');
      final file = File('${directory.path}/life.sqlite');
      final database = AppDatabase(NativeDatabase(file));
      try {
        await database.customStatement('PRAGMA journal_mode=WAL');
        final repository = LifeRepository(database);
        await repository.addTask(const TaskDraft(title: 'Before'));
        final service = BackupService(file);
        final backup = await service.createBackup(BackupKind.manual);
        await repository.addTask(const TaskDraft(title: 'After'));
        final snapshot = sqlite.sqlite3.open(
          backup.file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(
            snapshot.select('PRAGMA quick_check').single.values.single,
            'ok',
          );
          expect(
            snapshot.select('SELECT title FROM tasks').single['title'],
            'Before',
          );
        } finally {
          snapshot.close();
        }
        expect((await repository.tasks()), hasLength(2));
        expect(
          (await service.list()).single.schemaVersion,
          AppDatabase.currentSchemaVersion,
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'automatic policy snapshots before upgrade and retains 14 autos',
    () async {
      final directory = await Directory.systemTemp.createTemp('life-backup-');
      final file = File('${directory.path}/life.sqlite');
      final database = AppDatabase(NativeDatabase(file));
      try {
        await LifeRepository(database).addTask(const TaskDraft(title: 'Keep'));
        final service = BackupService(file);
        final first = DateTime.utc(2026, 10, 1);
        final preupgrade = await service.ensureAutomaticBackup(
          appSchemaVersion: AppDatabase.currentSchemaVersion + 1,
          now: first,
        );
        expect(preupgrade?.kind, BackupKind.beforeUpgrade);
        for (var index = 0; index < 16; index++) {
          await service.createBackup(
            BackupKind.automatic,
            now: first.add(Duration(days: index)),
          );
        }
        final records = await service.list();
        expect(
          records.where((item) => item.kind == BackupKind.automatic),
          hasLength(14),
        );
        expect(
          records.where((item) => item.kind == BackupKind.beforeUpgrade),
          hasLength(1),
        );
        expect(
          await service.ensureAutomaticBackup(
            appSchemaVersion: AppDatabase.currentSchemaVersion,
            now: first.add(const Duration(days: 15, hours: 1)),
          ),
          isNull,
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('pre-upgrade snapshot remains at old schema after migration', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-backup-upgrade-',
    );
    final file = File('${directory.path}/life.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(initial)
          .addTask(const TaskDraft(title: 'Keep through upgrade'));
      await initial.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE saved_views');
        raw.execute('PRAGMA user_version = 11');
      } finally {
        raw.close();
      }
      final service = BackupService(file);
      final snapshot = await service.ensureAutomaticBackup(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      expect(snapshot?.kind, BackupKind.beforeUpgrade);
      expect(snapshot?.schemaVersion, 11);
      final migrated = AppDatabase(NativeDatabase(file));
      try {
        expect((await LifeRepository(migrated).tasks()).single.id, task.id);
        expect(await LifeRepository(migrated).savedViews(), isEmpty);
      } finally {
        await migrated.close();
      }
      expect((await service.list()).single.schemaVersion, 11);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'reviewed restore replaces data and preserves a rollback snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp('life-restore-');
      final file = File('${directory.path}/life.sqlite');
      try {
        final initial = AppDatabase(NativeDatabase(file));
        await initial.customStatement('PRAGMA journal_mode=WAL');
        final repository = LifeRepository(initial);
        final before = await repository.addTask(
          const TaskDraft(title: 'Before'),
        );
        final service = BackupService(file);
        final chosen = await service.createBackup(BackupKind.manual);
        await repository.addTask(const TaskDraft(title: 'After'));
        await initial.close();
        await service.scheduleRestore(
          chosen,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        expect(
          await service.pendingRestoreName(),
          chosen.file.uri.pathSegments.last,
        );
        final rollback = await service.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        expect(rollback?.kind, BackupKind.beforeRestore);
        expect(await service.pendingRestoreName(), isNull);
        final restored = AppDatabase(NativeDatabase(file));
        try {
          expect((await LifeRepository(restored).tasks()).single.id, before.id);
        } finally {
          await restored.close();
        }
        final rollbackDb = sqlite.sqlite3.open(
          rollback!.file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(
            rollbackDb.select('SELECT COUNT(*) AS n FROM tasks').single['n'],
            2,
          );
        } finally {
          rollbackDb.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'changed scheduled backup is rejected without altering live data',
    () async {
      final directory = await Directory.systemTemp.createTemp('life-restore-');
      final file = File('${directory.path}/life.sqlite');
      try {
        final initial = AppDatabase(NativeDatabase(file));
        final repository = LifeRepository(initial);
        await repository.addTask(const TaskDraft(title: 'Live'));
        final service = BackupService(file);
        final chosen = await service.createBackup(BackupKind.manual);
        await service.scheduleRestore(
          chosen,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await chosen.file.writeAsBytes([1], mode: FileMode.append);
        await initial.close();
        await expectLater(
          service.applyScheduledRestore(
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsStateError,
        );
        expect(await service.pendingRestoreName(), isNotNull);
        final reopened = AppDatabase(NativeDatabase(file));
        try {
          expect((await LifeRepository(reopened).tasks()).single.title, 'Live');
        } finally {
          await reopened.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('same-size backup change is rejected by content digest', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-restore-hash-',
    );
    final file = File('${directory.path}/life.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      await LifeRepository(initial).addTask(const TaskDraft(title: 'Live'));
      final service = BackupService(file);
      final chosen = await service.createBackup(BackupKind.manual);
      await service.scheduleRestore(
        chosen,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      final oldStat = await chosen.file.stat();
      final altered = sqlite.sqlite3.open(chosen.file.path);
      try {
        altered.execute("UPDATE tasks SET title='Lime' WHERE title='Live'");
      } finally {
        altered.close();
      }
      await chosen.file.setLastModified(oldStat.modified);
      expect((await chosen.file.stat()).size, oldStat.size);
      await initial.close();
      await expectLater(
        service.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        ),
        throwsStateError,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('restore waits for another reader to release the database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-restore-lock-',
    );
    final file = File('${directory.path}/life.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      await initial.customStatement('PRAGMA journal_mode=WAL');
      final repository = LifeRepository(initial);
      await repository.addTask(const TaskDraft(title: 'Old'));
      final service = BackupService(file);
      final chosen = await service.createBackup(BackupKind.manual);
      await repository.addTask(const TaskDraft(title: 'New'));
      await initial.close();
      final reader = sqlite.sqlite3.open(file.path);
      try {
        reader.execute('BEGIN');
        reader.select('SELECT COUNT(*) FROM tasks');
        await service.scheduleRestore(
          chosen,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await expectLater(
          service.applyScheduledRestore(
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsA(isA<Exception>()),
        );
        expect(await service.pendingRestoreName(), isNotNull);
      } finally {
        reader.close();
      }
      await service.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      final restored = AppDatabase(NativeDatabase(file));
      try {
        expect((await LifeRepository(restored).tasks()).single.title, 'Old');
      } finally {
        await restored.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('restored older snapshot migrates forward on reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-restore-v11-',
    );
    final file = File('${directory.path}/life.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      await LifeRepository(initial).addTask(const TaskDraft(title: 'Old'));
      await initial.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE saved_views');
        raw.execute('PRAGMA user_version=11');
      } finally {
        raw.close();
      }
      final service = BackupService(file);
      final chosen = await service.createBackup(BackupKind.manual);
      expect(chosen.schemaVersion, 11);
      final migrated = AppDatabase(NativeDatabase(file));
      await LifeRepository(migrated).addTask(const TaskDraft(title: 'New'));
      await migrated.close();
      await service.scheduleRestore(
        chosen,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await service.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect((await LifeRepository(reopened).tasks()).single.title, 'Old');
        expect(await LifeRepository(reopened).savedViews(), isEmpty);
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
