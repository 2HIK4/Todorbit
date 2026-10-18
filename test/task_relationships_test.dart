import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/scheduling_engine.dart';
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
    'dependencies cross projects, reject cycles, and unblock on completion',
    () async {
      final firstCategory = await repository.addCategory('First');
      final secondCategory = await repository.addCategory('Second');
      final firstProject = await repository.addProject(firstCategory.id, 'One');
      final secondProject = await repository.addProject(
        secondCategory.id,
        'Two',
      );
      final a = await repository.addTask(
        TaskDraft(
          title: 'A',
          categoryId: firstCategory.id,
          projectId: firstProject.id,
        ),
      );
      final b = await repository.addTask(
        TaskDraft(
          title: 'B',
          categoryId: secondCategory.id,
          projectId: secondProject.id,
        ),
      );
      final c = await repository.addTask(const TaskDraft(title: 'C'));
      await repository.setPrerequisites(b, {a.id});
      await repository.setPrerequisites(c, {b.id});
      await expectLater(
        repository.setPrerequisites(a, {c.id}),
        throwsArgumentError,
      );
      expect((await repository.dependencies()).length, 2);
      expect(
        (await repository.dependencies()).where((link) => link.taskId == a.id),
        isEmpty,
      );
      await repository.setComplete(a, true);
      final byId = {for (final task in await repository.tasks()) task.id: task};
      final unmet = (await repository.dependencies()).where(
        (link) =>
            link.taskId == b.id &&
            byId[link.prerequisiteId]?.status != TaskStatus.completed,
      );
      expect(unmet, isEmpty);
    },
  );

  test('stale prerequisite editor cannot erase a later link', () async {
    final a = await repository.addTask(const TaskDraft(title: 'A'));
    final b = await repository.addTask(const TaskDraft(title: 'B'));
    final dependent = await repository.addTask(
      const TaskDraft(title: 'Dependent'),
    );
    await repository.setPrerequisites(dependent, {a.id});
    await expectLater(
      repository.setPrerequisites(dependent, {b.id}),
      throwsStateError,
    );
    expect((await repository.dependencies()).single.prerequisiteId, a.id);
  });

  test('manual date edit requires an explicit prerequisite override', () async {
    final prerequisite = await repository.addTask(
      const TaskDraft(title: 'First', scheduledDate: '2026-10-20'),
    );
    final dependent = await repository.addTask(const TaskDraft(title: 'Next'));
    await repository.setPrerequisites(dependent, {prerequisite.id});
    final current = (await repository.tasks()).firstWhere(
      (task) => task.id == dependent.id,
    );
    const draft = TaskDraft(title: 'Next', scheduledDate: '2026-10-19');
    await expectLater(repository.updateTask(current, draft), throwsStateError);
    expect(
      (await repository.tasks())
          .firstWhere((task) => task.id == dependent.id)
          .scheduledDate,
      isNull,
    );
    await repository.updateTask(
      current,
      draft,
      reviewedPrerequisiteIds: {prerequisite.id},
    );
    expect(
      (await repository.tasks())
          .firstWhere((task) => task.id == dependent.id)
          .scheduledDate,
      '2026-10-19',
    );
  });

  test(
    'sequence reordering persists and failed membership edit rolls back',
    () async {
      final a = await repository.addTask(const TaskDraft(title: 'A'));
      final b = await repository.addTask(const TaskDraft(title: 'B'));
      final c = await repository.addTask(const TaskDraft(title: 'C'));
      var sequence = await repository.addSequence('Morning');
      await repository.setSequenceTasks(sequence, [a.id, b.id, c.id]);
      sequence = (await repository.sequences()).single;
      await repository.setSequenceTasks(sequence, [c.id, a.id, b.id]);
      sequence = (await repository.sequences()).single;
      expect(sequence.taskIds, [c.id, a.id, b.id]);
      final other = await repository.addSequence('Evening');
      await expectLater(
        repository.setSequenceTasks(other, [b.id]),
        throwsA(anything),
      );
      expect(
        (await repository.sequences())
            .firstWhere((item) => item.id == sequence.id)
            .taskIds,
        [c.id, a.id, b.id],
      );
      expect(
        (await repository.sequences())
            .firstWhere((item) => item.id == other.id)
            .taskIds,
        isEmpty,
      );
    },
  );

  test(
    'scheduling before a prerequisite requires a reviewed warning',
    () async {
      final prerequisite = await repository.addTask(
        const TaskDraft(title: 'Prerequisite', scheduledDate: '2026-10-20'),
      );
      final task = await repository.addTask(
        const TaskDraft(title: 'Dependent'),
      );
      await repository.setPrerequisites(task, {prerequisite.id});
      final current = (await repository.tasks()).firstWhere(
        (item) => item.id == task.id,
      );
      final preview = const SchedulingEngine().moveTasks(
        selected: [current],
        targetDay: DateTime(2026, 10, 19),
        scope: 'test',
      );
      await expectLater(
        repository.applySchedulingPreview(preview),
        throwsA(isA<StaleSchedulePreviewException>()),
      );
      expect(
        (await repository.tasks())
            .firstWhere((item) => item.id == task.id)
            .scheduledDate,
        isNull,
      );
      final reviewed = SchedulingPreview(
        operation: preview.operation,
        scope: preview.scope,
        changes: preview.changes,
        issues: [
          ScheduleIssue(
            kind: ScheduleIssueKind.dependencyOrder,
            severity: ScheduleIssueSeverity.warning,
            targetId: task.id,
            relatedId: prerequisite.id,
            message: 'Reviewed dependency order',
          ),
        ],
        createdAt: preview.createdAt,
      );
      await repository.applySchedulingPreview(reviewed);
      expect(
        (await repository.tasks())
            .firstWhere((item) => item.id == task.id)
            .scheduledDate,
        '2026-10-19',
      );
    },
  );

  test('joint schedule move checks the prerequisite proposed day', () async {
    final prerequisite = await repository.addTask(
      const TaskDraft(title: 'Prerequisite', scheduledDate: '2026-10-20'),
    );
    final dependent = await repository.addTask(
      const TaskDraft(title: 'Dependent', scheduledDate: '2026-10-25'),
    );
    await repository.setPrerequisites(dependent, {prerequisite.id});
    final current = {
      for (final task in await repository.tasks()) task.id: task,
    };
    final preview = SchedulingPreview(
      operation: ScheduleOperationType.reorder,
      scope: 'test',
      changes: [
        ScheduleChange(
          targetKind: ScheduleTargetKind.task,
          targetId: prerequisite.id,
          expectedUpdatedAt: current[prerequisite.id]!.updatedAt,
          beforeDate: '2026-10-20',
          afterDate: '2026-10-30',
        ),
        ScheduleChange(
          targetKind: ScheduleTargetKind.task,
          targetId: dependent.id,
          expectedUpdatedAt: current[dependent.id]!.updatedAt,
          beforeDate: '2026-10-25',
          afterDate: '2026-10-21',
        ),
      ],
      issues: const [],
      createdAt: DateTime.now().toUtc(),
    );
    await expectLater(
      repository.applySchedulingPreview(preview),
      throwsA(isA<StaleSchedulePreviewException>()),
    );
    expect(
      (await repository.tasks())
          .firstWhere((task) => task.id == prerequisite.id)
          .scheduledDate,
      '2026-10-20',
    );
  });

  test('schema v4 task data migrates through relationships to v7', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life_manager_v4_');
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      final oldTask = await LifeRepository(first)
          .addTask(const TaskDraft(title: 'Keep me'));
      await first.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE time_entry_history');
      raw.execute('DROP TABLE time_entries');
      raw.execute('DROP TABLE timer_runs');
      raw.execute('DROP TABLE goal_habit_links');
      raw.execute('DROP TABLE goal_project_links');
      raw.execute('DROP TABLE goal_task_links');
      raw.execute('DROP TABLE goal_progress_entries');
      raw.execute('DROP TABLE goal_milestones');
      raw.execute('DROP TABLE goals');
      raw.execute('DROP TABLE habit_entry_history');
      raw.execute('DROP TABLE habit_rest_days');
      raw.execute('DROP TABLE habit_entries');
      raw.execute('DROP TABLE habits');
      raw.execute('DROP TRIGGER recurrence_task_schedule_updated');
      raw.execute('DROP TRIGGER recurrence_task_content_updated');
      raw.execute('DROP TRIGGER recurrence_task_cancelled');
      raw.execute('DROP TABLE series_edit_history');
      raw.execute('DROP TABLE recurrence_collision_history');
      raw.execute('DROP TABLE recurrence_occurrences');
      raw.execute('DROP TABLE recurrence_series');
      raw.execute('DROP TABLE task_dependencies');
      raw.execute('DROP TABLE sequence_tasks');
      raw.execute('DROP TABLE task_sequences');
      raw.execute('PRAGMA user_version = 4');
      raw.close();
      final migrated = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(migrated);
        expect((await repo.tasks()).single.id, oldTask.id);
        final sequence = await repo.addSequence('After upgrade');
        await repo.setSequenceTasks(sequence, [oldTask.id]);
        expect((await repo.sequences()).single.taskIds, [oldTask.id]);
      } finally {
        await migrated.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
