import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/saved_views.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });
  tearDown(() async => database.close());

  test(
    'filters combine task content, status, project, dates and blockers',
    () async {
      final category = await repository.addCategory('Writing');
      final project = await repository.addProject(category.id, 'Book');
      final prerequisite = await repository.addTask(
        const TaskDraft(title: 'Outline'),
      );
      final today = localDate(DateTime.now());
      final task = await repository.addTask(
        TaskDraft(
          title: 'Chapter',
          notes: 'Opening scene',
          priority: 3,
          categoryId: category.id,
          projectId: project.id,
          scheduledDate: today,
          deadlineDate: RecurrenceRule.shiftDate(today, 3),
        ),
      );
      await repository.setPrerequisites(task, {prerequisite.id});
      final controller = AppController(repository);
      await controller.refresh();
      final filter = TaskFilter(
        text: 'book',
        categoryId: category.id,
        projectId: project.id,
        statuses: {TaskStatus.notStarted},
        minimumPriority: 2,
        scheduled: ScheduledFilter.today,
        deadline: DeadlineFilter.nextSevenDays,
        blockedOnly: true,
      );
      expect(controller.searchTasks(filter).map((item) => item.id), [task.id]);
      final view = await controller.addSavedView('Write now', filter);
      expect(controller.view, WorkspaceView.saved);
      expect(controller.scopeId, view.id);
      expect(controller.visibleTasks.map((item) => item.id), [task.id]);
      await controller.setComplete(prerequisite, true);
      expect(controller.visibleTasks, isEmpty);
      controller.dispose();
    },
  );

  test(
    'saved views persist unlimited filters and reject stale edits',
    () async {
      for (var index = 0; index < 25; index++) {
        await repository.addSavedView(
          'View $index',
          TaskFilter(text: 'item $index'),
        );
      }
      expect(await repository.savedViews(), hasLength(25));
      final original = (await repository.savedViews()).first;
      await repository.updateSavedView(
        original,
        'Changed',
        const TaskFilter(minimumPriority: 2),
      );
      await expectLater(repository.deleteSavedView(original), throwsStateError);
      final latest = (await repository.savedViews()).firstWhere(
        (item) => item.id == original.id,
      );
      expect(latest.filter.minimumPriority, 2);
      await repository.deleteSavedView(latest);
      expect(await repository.savedViews(), hasLength(24));
    },
  );

  test('v11 migrates saved views without touching templates', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life-view-v11-');
    final file = File('${directory.path}/legacy.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      final repo = LifeRepository(initial);
      final task = await repo.addTask(const TaskDraft(title: 'Keep'));
      await repo.saveTaskTemplate(task, 'Keep template');
      await initial.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE saved_views');
        raw.execute('PRAGMA user_version = 11');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final migrated = LifeRepository(upgraded);
        expect((await migrated.templates()).single.name, 'Keep template');
        await migrated.addSavedView('All', const TaskFilter());
      } finally {
        await upgraded.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await LifeRepository(reopened).savedViews()).single.name,
          'All',
        );
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
