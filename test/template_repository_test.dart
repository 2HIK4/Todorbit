import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/templates.dart';
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
    'task template shifts planned dates and leaves history behind',
    () async {
      final source = await repository.addTask(
        const TaskDraft(
          title: 'Prepare',
          priority: 2,
          scheduledDate: '2026-10-19',
          deadlineDate: '2026-10-21',
          plannedDurationMinutes: 45,
        ),
      );
      await repository.setComplete(source, true);
      final completed = (await repository.tasks()).single;
      final template = await repository.saveTaskTemplate(
        completed,
        'Preparation',
      );
      expect(template.kind, TemplateKind.task);
      final id = await repository.instantiateTemplate(
        template,
        anchorDay: '2026-11-02',
      );
      final created = (await repository.tasks()).singleWhere(
        (item) => item.id == id,
      );
      expect(created.id, isNot(source.id));
      expect(created.status, TaskStatus.notStarted);
      expect(created.completedAt, isNull);
      expect(created.scheduledDate, '2026-11-02');
      expect(created.deadlineDate, '2026-11-04');
      expect(created.plannedDurationMinutes, 45);
      expect(
        (await repository.tasks())
            .singleWhere((item) => item.id == source.id)
            .status,
        TaskStatus.completed,
      );
    },
  );

  test('project template remaps internal dependencies atomically', () async {
    final category = await repository.addCategory('Work');
    final project = await repository.addProject(category.id, 'Launch');
    final first = await repository.addTask(
      TaskDraft(
        title: 'Draft',
        categoryId: category.id,
        projectId: project.id,
        scheduledDate: '2026-10-20',
      ),
    );
    final second = await repository.addTask(
      TaskDraft(
        title: 'Review',
        categoryId: category.id,
        projectId: project.id,
        scheduledDate: '2026-10-22',
        deadlineDate: '2026-10-24',
      ),
    );
    await repository.setPrerequisites(second, {first.id});
    await repository.setComplete(first, true);
    final template = await repository.saveProjectTemplate(
      project,
      'Launch plan',
    );
    expect(template.taskCount, 2);
    await expectLater(
      repository.instantiateTemplate(
        template,
        anchorDay: '2026-11-01',
        categoryId: category.id,
        projectName: 'Launch',
      ),
      throwsA(isA<Exception>()),
    );
    expect((await repository.projects()), hasLength(1));
    final newProjectId = await repository.instantiateTemplate(
      template,
      anchorDay: '2026-11-01',
      categoryId: category.id,
      projectName: 'Launch again',
    );
    final copies = (await repository.tasks())
        .where((item) => item.projectId == newProjectId)
        .toList();
    expect(copies, hasLength(2));
    final newFirst = copies.singleWhere((item) => item.title == 'Draft');
    final newSecond = copies.singleWhere((item) => item.title == 'Review');
    expect(newFirst.id, isNot(first.id));
    expect(newFirst.status, TaskStatus.notStarted);
    expect(newFirst.scheduledDate, '2026-11-01');
    expect(newSecond.scheduledDate, '2026-11-03');
    expect(newSecond.deadlineDate, '2026-11-05');
    expect(
      (await repository.dependencies())
          .where((link) => link.taskId == newSecond.id)
          .single
          .prerequisiteId,
      newFirst.id,
    );
  });

  test('routine template creates an independent recurrence series', () async {
    final source = await repository.addRecurringTask(
      const TaskDraft(title: 'Practice', scheduledDate: '2026-10-19'),
      RecurrenceRule(
        kind: RecurrenceKind.weekdays,
        startDate: '2026-10-19',
        weekdays: {1, 3, 5},
        endDate: '2026-10-30',
      ),
    );
    final template = await repository.saveTaskTemplate(source, 'Practice days');
    expect(template.kind, TemplateKind.routine);
    final id = await repository.instantiateTemplate(
      template,
      anchorDay: '2026-11-02',
    );
    final copy = (await repository.tasks()).singleWhere(
      (item) => item.id == id,
    );
    expect(copy.recurrenceSeriesId, isNot(source.recurrenceSeriesId));
    final definition = await repository.recurrenceDefinition(id);
    expect(definition.rule.weekdays, {1, 3, 5});
    expect(definition.rule.endDate, '2026-11-13');
    await expectLater(
      repository.instantiateTemplate(template, anchorDay: '2026-11-03'),
      throwsArgumentError,
    );
    expect(
      (await repository.tasks()).where((item) => item.title == 'Practice'),
      hasLength(2),
    );
  });

  test(
    'v10 migrates to templates without changing existing time data',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'life-template-v10-',
      );
      final file = File('${directory.path}/legacy.sqlite');
      try {
        final initial = AppDatabase(NativeDatabase(file));
        final task = await LifeRepository(initial)
            .addTask(const TaskDraft(title: 'Keep'));
        await initial.close();
        final raw = sqlite.sqlite3.open(file.path);
        try {
          raw.execute('DROP TABLE templates');
          raw.execute('PRAGMA user_version = 10');
        } finally {
          raw.close();
        }
        final upgraded = AppDatabase(NativeDatabase(file));
        try {
          final repo = LifeRepository(upgraded);
          expect((await repo.tasks()).single.id, task.id);
          expect(await repo.templates(), isEmpty);
          await repo.saveTaskTemplate((await repo.tasks()).single, 'Keep copy');
        } finally {
          await upgraded.close();
        }
        final reopened = AppDatabase(NativeDatabase(file));
        try {
          expect(
            (await LifeRepository(reopened).templates()).single.name,
            'Keep copy',
          );
        } finally {
          await reopened.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
