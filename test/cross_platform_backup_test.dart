import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/alarms.dart';

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
          alarm: AlarmConfig(mode: 'custom', at: DateTime.utc(2027, 1, 1)),
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
          categoryId: category.id,
          projectId: project.id,
        ),
      );
      final group = await source.addChecklistGroup(task.id, 'Travel');
      await source.addChecklistItem(task.id, 'Pack notes', groupId: group.id);
      final item = (await source.checklistItems()).single;
      final attachment = File('${root.path}/reference.txt');
      await attachment.writeAsString('Synthetic cross-profile attachment');
      final resource = await source.attachManagedFile(task.id, attachment);
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
      expect(
        (await target.alarmRules()).single.config.at,
        DateTime.utc(2027, 1, 1),
      );
      expect(
        (await target.alarmRules()).single.id,
        (await source.alarmRules()).single.id,
      );
      expect(restored.updatedAt, task.updatedAt);
      expect(restored.categoryId, category.id);
      expect(restored.projectId, project.id);
      expect(restored.scheduledDate, '2026-10-28');
      expect(restored.deadlineDate, '2026-11-01');
      expect((await target.events()).single.projectId, project.id);
      expect((await target.events()).single.categoryId, category.id);
      expect((await target.checklistGroups()).single.id, group.id);
      expect((await target.checklistItems()).single.id, item.id);
      expect((await target.checklistItems()).single.groupId, group.id);
      expect(
        (await target.taskResources(task.id)).single.sha256,
        resource.sha256,
      );
      expect(
        (await mobile
                .customSelect('SELECT content FROM task_resources')
                .getSingle())
            .read<List<int>>('content'),
        'Synthetic cross-profile attachment'.codeUnits,
      );
      final returnedTask = await target.addTask(
        const TaskDraft(title: 'Mobile return sentinel'),
      );
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
      final returnedRepository = LifeRepository(desktop);
      expect(
        (await returnedRepository.tasks()).map((t) => t.id),
        containsAll([task.id, returnedTask.id]),
      );
      expect((await returnedRepository.events()).single.projectId, project.id);
      expect((await returnedRepository.checklistGroups()).single.id, group.id);
      expect(
        (await returnedRepository.checklistItems()).single.groupId,
        group.id,
      );
      expect(
        (await returnedRepository.taskResources(task.id)).single.sha256,
        resource.sha256,
      );
      expect(
        (await desktop
                .customSelect('SELECT content FROM task_resources')
                .getSingle())
            .read<List<int>>('content'),
        'Synthetic cross-profile attachment'.codeUnits,
      );
      expect(
        await desktop.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await desktop.close();
      await mobile.close();
      await root.delete(recursive: true);
    }
  });
}
