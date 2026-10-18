import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/trash.dart';

void main() {
  test('checklist edits, order, and progress survive restart', () async {
    final root = await Directory.systemTemp.createTemp('life-checklist-');
    final file = File('${root.path}${Platform.pathSeparator}tasks.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      final repo = LifeRepository(first);
      final task = await repo.addTask(const TaskDraft(title: 'Finish course'));
      await repo.addChecklistItem(task.id, 'Watch lesson');
      await repo.addChecklistItem(task.id, 'Build project');
      var items = await repo.checklistItems();
      await repo.updateChecklistItem(items.first, done: true);
      items = await repo.checklistItems();
      await repo.moveChecklistItem(items.last, -1);
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      final reopened = LifeRepository(second);
      items = await reopened.checklistItems();
      expect(items.map((item) => item.title), [
        'Build project',
        'Watch lesson',
      ]);
      expect(items.where((item) => item.done), hasLength(1));
      expect((await reopened.tasks()).single.status, TaskStatus.notStarted);
      await reopened.updateChecklistItem(items.first, title: 'Ship project');
      await reopened.removeChecklistItem(items.last);
      expect((await reopened.checklistItems()).single.title, 'Ship project');
      await second.close();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'subtask has independent schedule and returns after parent restoration',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(database);
      try {
        final parent = await repo.addTask(const TaskDraft(title: 'Course'));
        final child = await repo.addSubtask(
          parent,
          const TaskDraft(
            title: 'Lesson 1',
            scheduledDate: '2026-10-20',
            priority: 2,
          ),
        );
        expect((await repo.taskParents())[child.id], parent.id);
        await expectLater(
          repo.addSubtask(child, const TaskDraft(title: 'Too deep')),
          throwsStateError,
        );
        await repo.setComplete(child, true);
        expect(
          (await repo.tasks())
              .firstWhere((task) => task.id == parent.id)
              .status,
          TaskStatus.notStarted,
        );
        await repo.deleteTask(parent.id);
        expect(await repo.tasks(), isEmpty);
        final trashed = (await repo.trash()).firstWhere(
          (item) => item.kind == TrashKind.task && item.id == parent.id,
        );
        await repo.restoreTrashItem(trashed);
        final restored = await repo.tasks();
        expect(restored, hasLength(2));
        expect(
          restored.firstWhere((task) => task.id == child.id).status,
          TaskStatus.completed,
        );
      } finally {
        await database.close();
      }
    },
  );
}
