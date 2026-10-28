import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  test('the portable snapshot retains identities across distinct desktop/mobile profiles', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-cross-platform-',
    );
    final windows = File('${root.path}/desktop/life_manager.sqlite');
    final android = File('${root.path}/mobile/life_manager.sqlite');
    await windows.parent.create();
    await android.parent.create();
    var desktop = AppDatabase(NativeDatabase(windows));
    var mobile = AppDatabase(NativeDatabase(android));
    try {
      final source = LifeRepository(desktop);
      final category = await source.addCategory('Portable category');
      final project = await source.addProject(category.id, 'Portable project');
      final task = await source.addTask(
        TaskDraft(
          title: 'Portable task',
          categoryId: category.id,
          projectId: project.id,
          scheduledDate: '2026-10-28',
          deadlineDate: '2026-11-01',
          plannedDurationMinutes: 30,
        ),
      );
      await source.addEvent(
        EventDraft(
          title: 'Portable event',
          startsAt: DateTime.utc(2026, 10, 28, 12),
          endsAt: DateTime.utc(2026, 10, 28, 13),
          repeat: const EventRepeat(kind: EventRepeatKind.weekly),
        ),
      );
      final mobileService = BackupService(android);
      await LifeRepository(mobile)
          .addTask(const TaskDraft(title: 'Recoverable old mobile data'));
      final exported = await BackupService(windows)
          .exportTo(File('${root.path}/transfer.sqlite'));
      final imported = await mobileService.importSnapshot(
        exported,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      final summary = await mobileService.summarize(imported);
      expect(summary.description, contains('1 task'));
      await mobileService.scheduleRestore(
        imported,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await mobile.close();
      await mobileService.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      mobile = AppDatabase(NativeDatabase(android));
      final target = LifeRepository(mobile);
      final restored = (await target.tasks()).single;
      expect(restored.id, task.id);
      expect(restored.updatedAt, task.updatedAt);
      expect(restored.categoryId, category.id);
      expect(restored.projectId, project.id);
      expect(restored.scheduledDate, '2026-10-28');
      expect(restored.deadlineDate, '2026-11-01');
      expect(
        (await target.events()).single.repeat!.kind,
        EventRepeatKind.weekly,
      );
      expect(
        (await mobileService.list()).any(
          (b) => b.kind == BackupKind.beforeRestore,
        ),
        isTrue,
      );
      // The same format can travel back; no Android schema fork is introduced.
      await mobile.close();
      final back = await mobileService.exportTo(
        File('${root.path}/return.sqlite'),
      );
      final desktopService = BackupService(windows);
      final returned = await desktopService.importSnapshot(
        back,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await desktopService.scheduleRestore(
        returned,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await desktop.close();
      await desktopService.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      desktop = AppDatabase(NativeDatabase(windows));
      expect((await LifeRepository(desktop).tasks()).single.id, task.id);
    } finally {
      await desktop.close();
      await mobile.close();
      await root.delete(recursive: true);
    }
  });
}
