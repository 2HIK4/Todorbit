import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';

void main() {
  test(
    'task, category, project and recurring-series icons persist and reset',
    () async {
      final root = await Directory.systemTemp.createTemp('life-icons-');
      final file = File('${root.path}${Platform.pathSeparator}icons.sqlite');
      try {
        final first = AppDatabase(NativeDatabase(file));
        final repo = LifeRepository(first);
        final category = await repo.addCategory('University');
        final project = await repo.addProject(category.id, 'Course');
        final task = await repo.addTask(
          TaskDraft(
            title: 'Read',
            categoryId: category.id,
            projectId: project.id,
          ),
        );
        final recurring = await repo.addRecurringTask(
          const TaskDraft(title: 'Study', scheduledDate: '2026-10-18'),
          RecurrenceRule(kind: RecurrenceKind.weekly, startDate: '2026-10-18'),
        );
        await repo.setEntityIcon('category', category.id, 'school');
        await repo.setEntityIcon('project', project.id, 'book');
        await repo.setEntityIcon('task', task.id, 'code');
        await repo.setEntityIcon(
          'series',
          recurring.recurrenceSeriesId!,
          'time',
        );
        await first.close();

        final second = AppDatabase(NativeDatabase(file));
        final reopened = LifeRepository(second);
        final icons = await reopened.entityIcons();
        expect(icons['category:${category.id}'], 'school');
        expect(icons['project:${project.id}'], 'book');
        expect(icons['task:${task.id}'], 'code');
        expect(icons['series:${recurring.recurrenceSeriesId}'], 'time');
        await reopened.setEntityIcon('task', task.id, null);
        expect(
          (await reopened.entityIcons()).containsKey('task:${task.id}'),
          isFalse,
        );
        await second.close();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
