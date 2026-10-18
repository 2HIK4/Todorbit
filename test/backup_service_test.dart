import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
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
}
