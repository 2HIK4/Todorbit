import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });
  tearDown(() async => database.close());

  GoalDraft draft() => const GoalDraft(
    title: 'Finish plan',
    target: 5,
    startDate: '2020-10-01',
    unit: 'steps',
  );

  test('direct and project task links count each completion once', () async {
    final category = await repository.addCategory('Work');
    final project = await repository.addProject(category.id, 'Plan');
    final task = await repository.addTask(
      TaskDraft(title: 'Write', categoryId: category.id, projectId: project.id),
    );
    final second = await repository.addTask(
      TaskDraft(
        title: 'Review',
        categoryId: category.id,
        projectId: project.id,
      ),
    );
    final goal = await repository.addGoal(draft());
    await repository.setGoalLinks(
      goal,
      GoalLinks(taskIds: {task.id}, projectIds: {project.id}, habitIds: {}),
    );
    await repository.setComplete(task, true);
    var current = (await repository.goals()).single;
    expect(current.progress.tasks, 1);
    expect((await repository.goalLinkedEvents(current)).length, 1);
    await repository.setComplete(second, true);
    current = (await repository.goals()).single;
    expect(current.progress.tasks, 2);
    expect(current.completed, isFalse);
    await repository.setComplete(
      (await repository.tasks()).singleWhere((item) => item.id == task.id),
      false,
    );
    expect((await repository.goals()).single.progress.tasks, 1);
  });

  test(
    'manual ledger, binary habit, milestones, and archive stay independent',
    () async {
      final habit = await repository.addHabit(
        HabitDraft(
          title: 'Study',
          kind: HabitKind.binary,
          rule: RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2020-10-01',
          ),
        ),
      );
      await repository.recordHabitDay(habit, '2020-10-19', 1);
      await repository.recordHabitDay(habit, '2020-10-20', 0);
      var goal = await repository.addGoal(draft());
      await repository.setGoalLinks(
        goal,
        GoalLinks(taskIds: {}, projectIds: {}, habitIds: {habit.id}),
      );
      await expectLater(
        repository.updateHabit(
          habit,
          HabitDraft(
            title: 'Numeric study',
            kind: HabitKind.minimum,
            target: 1,
            rule: RecurrenceRule(
              kind: RecurrenceKind.daily,
              startDate: '2020-10-01',
            ),
          ),
        ),
        throwsStateError,
      );
      goal = (await repository.goals()).single;
      expect(goal.progress.habits, 1);
      await repository.addGoalProgress(goal, 2, 'Two steps');
      goal = (await repository.goals()).single;
      expect(goal.progress.total, 3);
      await expectLater(
        repository.addGoalProgress(goal, -3, 'Too much correction'),
        throwsArgumentError,
      );
      await repository.addGoalProgress(goal, -1, 'Correct one step');
      expect((await repository.goals()).single.progress.manual, 1);
      expect(await repository.goalProgressHistory(goal.id), hasLength(2));
      goal = (await repository.goals()).single;
      await repository.addGoalMilestone(goal, 'Halfway', 2.5, null);
      await expectLater(
        repository.updateGoal(
          goal,
          const GoalDraft(title: 'Smaller', target: 2, startDate: '2020-10-01'),
        ),
        throwsArgumentError,
      );
      final milestone = (await repository.goalMilestones()).single;
      expect(milestone.completedAt, isNull);
      await repository.setGoalMilestoneCompleted(milestone, true);
      expect((await repository.goalMilestones()).single.completedAt, isNotNull);
      await repository.setGoalCompleted(goal, true);
      goal = (await repository.goals()).single;
      expect(goal.completed, isTrue);
      await repository.setGoalArchived(goal, true);
      expect((await repository.goals()).single.archived, isTrue);
      expect((await repository.goals()).single.completed, isTrue);
    },
  );

  test('v8 migration keeps habits and adds goals', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life-goals-v8-');
    final file = File('${directory.path}/legacy.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      final habit = await LifeRepository(initial).addHabit(
        HabitDraft(
          title: 'Existing',
          kind: HabitKind.binary,
          rule: RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2020-10-01',
          ),
        ),
      );
      await initial.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE goal_habit_links');
        raw.execute('DROP TABLE goal_project_links');
        raw.execute('DROP TABLE goal_task_links');
        raw.execute('DROP TABLE goal_progress_entries');
        raw.execute('DROP TABLE goal_milestones');
        raw.execute('DROP TABLE goals');
        raw.execute('PRAGMA user_version = 8');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(upgraded);
        expect((await repo.habits()).single.id, habit.id);
        expect((await repo.addGoal(draft())).title, 'Finish plan');
      } finally {
        await upgraded.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
