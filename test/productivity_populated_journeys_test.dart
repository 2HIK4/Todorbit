import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/goals/goals_view.dart';
import 'package:life_manager/features/habits/habits_view.dart';

void main() {
  late AppDatabase database;
  late LifeRepository repo;
  late AppController controller;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(database);
    controller = AppController(repo);
    await controller.refresh();
  });
  tearDown(() async => database.close());

  Future<void> host(WidgetTester tester, Widget view) async {
    await tester.binding.setSurfaceSize(const Size(1000, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await controller.refresh();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(home: Scaffold(body: view)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'numeric habit corrections, rest days, archive and restore retain history',
    (tester) async {
      final today = localDate(DateTime.now());
      final habit = await repo.addHabit(
        HabitDraft(
          title: 'Synthetic reading علوم',
          kind: HabitKind.minimum,
          target: 3,
          unit: 'pages',
          rule: RecurrenceRule(kind: RecurrenceKind.daily, startDate: today),
        ),
      );
      await host(tester, const HabitsView());
      await tester.tap(find.text('Log value'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('numeric-entry-value')),
        '4',
      );
      await tester.tap(find.text('Save log'));
      await tester.pumpAndSettle();
      final first = (await repo.habitEntries()).single;
      expect(first.value, 4);
      expect(find.textContaining('Target met'), findsOneWidget);
      await tester.tap(find.text('Edit value'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('numeric-entry-value')),
        '2',
      );
      await tester.tap(find.text('Save log'));
      await tester.pumpAndSettle();
      final corrected = (await repo.habitEntries()).single;
      expect(corrected.id, first.id);
      expect(corrected.value, 2);
      expect(corrected.habitId, habit.id);
      expect(find.textContaining('Target missed'), findsOneWidget);
      await tester.tap(find.text('Clear log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear log').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark rest day'));
      await tester.pumpAndSettle();
      expect(await repo.habitRestDays(), hasLength(1));
      expect(find.textContaining('Rest day'), findsWidgets);
      await tester.tap(find.byTooltip('Archive habit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Restore habit'));
      await tester.pumpAndSettle();
      expect((await repo.habits()).single.id, habit.id);
      expect(await repo.habitRestDays(), hasLength(1));
      expect(
        (await database
                .customSelect('SELECT COUNT(*) AS n FROM habit_entry_history')
                .getSingle())
            .read<int>('n'),
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'populated goal completion and archive preserve linked progress and milestones',
    (tester) async {
      final category = await repo.addCategory('Research');
      final project = await repo.addProject(category.id, 'Synthetic project');
      final task = await repo.addTask(
        TaskDraft(
          title: 'Completed linked task',
          categoryId: category.id,
          projectId: project.id,
        ),
      );
      await repo.setComplete(task, true);
      var goal = await repo.addGoal(
        const GoalDraft(
          title: 'Long synthetic goal محفوظ',
          target: 10,
          startDate: '2026-01-01',
        ),
      );
      await repo.setGoalLinks(
        goal,
        GoalLinks(taskIds: {task.id}, projectIds: {project.id}, habitIds: {}),
      );
      goal = (await repo.goals()).single;
      await repo.addGoalMilestone(goal, 'First checkpoint', 2, null);
      await repo.addGoalMilestone(goal, 'Second checkpoint', 5, null);
      await repo.addGoalProgress(goal, 2, 'Manual contribution');
      await host(tester, const GoalsView());
      expect(find.text('First checkpoint'), findsOneWidget);
      expect(find.text('Second checkpoint'), findsOneWidget);
      expect(find.textContaining('3.0 / 10.0'), findsOneWidget);
      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await repo.goals()).single.completed, isFalse);
      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark complete').last);
      await tester.pumpAndSettle();
      expect((await repo.goals()).single.completed, isTrue);
      await tester.tap(find.byTooltip('Archive goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Restore goal'));
      await tester.pumpAndSettle();
      final restored = (await repo.goals()).single;
      expect(restored.id, goal.id);
      expect(restored.archived, isFalse);
      expect(restored.completed, isTrue);
      expect(restored.progress.tasks, 1);
      expect(restored.progress.manual, 2);
      expect(await repo.goalMilestones(), hasLength(2));
      expect((await repo.goalLinks(goal.id)).projectIds, {project.id});
      expect(tester.takeException(), isNull);
    },
  );
}
