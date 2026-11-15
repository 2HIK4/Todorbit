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

import 'support/legacy_sync_fixture.dart';

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
        stripSyncSchemaForLegacyFixture(raw);
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

  test('multi-value OR within filter types and AND across filter types with duplicate & rename', () async {
    final catA = await repository.addCategory('Work');
    final catB = await repository.addCategory('Personal');
    final catC = await repository.addCategory('Other');

    final projA = await repository.addProject(catA.id, 'Project Alpha');
    final projB = await repository.addProject(catB.id, 'Project Beta');

    // Task 1: Work, Project Alpha, Priority 3 (High)
    final t1 = await repository.addTask(
      TaskDraft(title: 'T1', categoryId: catA.id, projectId: projA.id, priority: 3),
    );
    // Task 2: Personal, Project Beta, Priority 1 (Low)
    final t2 = await repository.addTask(
      TaskDraft(title: 'T2', categoryId: catB.id, projectId: projB.id, priority: 1),
    );
    // Task 3: Other, no project, Priority 3 (High)
    final t3 = await repository.addTask(
      TaskDraft(title: 'T3', categoryId: catC.id, priority: 3),
    );

    final controller = AppController(repository);
    await controller.refresh();

    // OR test: categoryIds {catA, catB} matches t1 and t2, but NOT t3
    final orFilter = TaskFilter(categoryIds: {catA.id, catB.id});
    final orResults = controller.searchTasks(orFilter).map((t) => t.id).toSet();
    expect(orResults, {t1.id, t2.id});
    expect(orResults.contains(t3.id), isFalse);

    // AND across filter types: categoryIds {catA, catB} AND priorities {3} -> only t1 matches
    final andFilter = TaskFilter(
      categoryIds: {catA.id, catB.id},
      priorities: {3},
      iconKey: 'star',
    );
    final andResults = controller.searchTasks(andFilter).map((t) => t.id).toSet();
    expect(andResults, {t1.id});

    // Test saved view duplicate & rename
    final saved = await controller.addSavedView('Original View', andFilter);
    expect(saved.name, 'Original View');
    expect(saved.iconKey, 'star');

    final dup = await controller.duplicateSavedView(saved);
    expect(dup.name, 'Original View (copy)');
    expect(dup.filter.categoryIds, {catA.id, catB.id});
    expect(dup.filter.priorities, {3});
    expect(dup.iconKey, 'star');

    await controller.renameSavedView(dup, 'Renamed View');
    final views = await repository.savedViews();
    final renamed = views.firstWhere((v) => v.id == dup.id);
    expect(renamed.name, 'Renamed View');
  });
}
