import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('full SQLite export imports through reviewed restore', () async {
    final directory = await Directory.systemTemp.createTemp('life-transfer-');
    final firstFile = File('${directory.path}/first.sqlite');
    final secondFile = File('${directory.path}/second.sqlite');
    final exportedFile = File('${directory.path}/portable.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(firstFile));
      final firstRepo = LifeRepository(first);
      await first.customStatement('PRAGMA journal_mode=WAL');
      final category = await firstRepo.addCategory('Research');
      final project = await firstRepo.addProject(category.id, 'Paper');
      final task = await firstRepo.addTask(
        TaskDraft(
          title: 'Portable work',
          categoryId: category.id,
          projectId: project.id,
          scheduledDate: '2026-10-18',
          deadlineDate: '2026-10-20',
        ),
      );
      final firstService = BackupService(firstFile);
      await firstService.exportTo(exportedFile);
      await firstRepo.addTask(const TaskDraft(title: 'Added after export'));
      await first.close();

      final exported = sqlite.sqlite3.open(
        exportedFile.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          exported.select('PRAGMA quick_check').single.values.single,
          'ok',
        );
        expect(
          exported.select('SELECT COUNT(*) AS n FROM tasks').single['n'],
          1,
        );
        expect(
          exported.select('PRAGMA user_version').single.values.single,
          AppDatabase.currentSchemaVersion,
        );
      } finally {
        exported.close();
      }

      final second = AppDatabase(NativeDatabase(secondFile));
      final secondRepo = LifeRepository(second);
      await secondRepo.addTask(const TaskDraft(title: 'Original destination'));
      final secondService = BackupService(secondFile);
      final staged = await secondService.importSnapshot(
        exportedFile,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      expect(staged.kind, BackupKind.manual);
      expect((await secondRepo.tasks()).single.title, 'Original destination');
      await secondService.scheduleRestore(
        staged,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await secondService.cancelScheduledRestore();
      expect(await secondService.pendingRestoreName(), isNull);
      expect((await secondRepo.tasks()).single.title, 'Original destination');
      await secondService.scheduleRestore(
        staged,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await second.close();
      final rollback = await secondService.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      expect(rollback?.kind, BackupKind.beforeRestore);
      final restored = AppDatabase(NativeDatabase(secondFile));
      try {
        final restoredRepo = LifeRepository(restored);
        expect((await restoredRepo.tasks()).single.id, task.id);
        expect((await restoredRepo.projects()).single.name, 'Paper');
        expect((await restoredRepo.categories()).single.name, 'Research');
        expect(
          await restored.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await restored.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('export never overwrites an existing file', () async {
    final directory = await Directory.systemTemp.createTemp('life-transfer-');
    try {
      final databaseFile = File('${directory.path}/live.sqlite');
      final destination = File('${directory.path}/existing.sqlite');
      final database = AppDatabase(NativeDatabase(databaseFile));
      await LifeRepository(database).addTask(const TaskDraft(title: 'Work'));
      await destination.writeAsString('keep');
      await expectLater(
        BackupService(databaseFile).exportTo(destination),
        throwsStateError,
      );
      expect(await destination.readAsString(), 'keep');
      await database.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'bad or newer import leaves live data and managed backups intact',
    () async {
      final directory = await Directory.systemTemp.createTemp('life-transfer-');
      try {
        final liveFile = File('${directory.path}/live.sqlite');
        final live = AppDatabase(NativeDatabase(liveFile));
        await LifeRepository(live).addTask(const TaskDraft(title: 'Keep'));
        final service = BackupService(liveFile);
        final badFile = File('${directory.path}/bad.sqlite');
        await badFile.writeAsString('not sqlite');
        await expectLater(
          service.importSnapshot(
            badFile,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
        await expectLater(
          service.importSnapshot(
            liveFile,
            appSchemaVersion: AppDatabase.currentSchemaVersion - 1,
          ),
          throwsStateError,
        );
        final incomplete = File('${directory.path}/incomplete.sqlite');
        await service.exportTo(incomplete);
        final raw = sqlite.sqlite3.open(incomplete.path);
        try {
          raw.execute('DROP TABLE notification_deliveries');
        } finally {
          raw.close();
        }
        await expectLater(
          service.importSnapshot(
            incomplete,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsStateError,
        );
        final damaged = File('${directory.path}/damaged.sqlite');
        await service.exportTo(damaged);
        final damagedBytes = await damaged.readAsBytes();
        await damaged.writeAsBytes(damagedBytes.sublist(0, 80), flush: true);
        await expectLater(
          service.importSnapshot(
            damaged,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsA(isA<Exception>()),
        );
        final brokenLinks = File('${directory.path}/broken-links.sqlite');
        await service.exportTo(brokenLinks);
        final broken = sqlite.sqlite3.open(brokenLinks.path);
        try {
          broken.execute('PRAGMA foreign_keys=OFF');
          broken.execute("UPDATE tasks SET category_id='missing-category'");
        } finally {
          broken.close();
        }
        await expectLater(
          service.importSnapshot(
            brokenLinks,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsStateError,
        );
        expect(await service.list(), isEmpty);
        expect(await service.pendingRestoreName(), isNull);
        expect((await LifeRepository(live).tasks()).single.title, 'Keep');
        await live.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
