import 'dart:collection';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/progressive_plan.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/saved_views.dart';
import 'package:life_manager/domain/scheduling_models.dart';
import 'package:life_manager/domain/task_composition.dart';
import 'package:life_manager/domain/templates.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/domain/trash.dart';
import 'package:life_manager/features/time_tracking/compact_task_timer.dart';
import 'package:life_manager/features/workspace/workspace.dart';

void main() {
  group(
    'ARCH-06: AppController collection encapsulation (unmodifiable views)',
    () {
      late AppDatabase db;
      late LifeRepository repo;
      late AppController controller;

      setUp(() {
        db = AppDatabase(NativeDatabase.memory());
        repo = LifeRepository(db);
        controller = AppController(repo);
      });

      tearDown(() async {
        controller.dispose();
        await db.close();
      });

      test('all public collections are unmodifiable views and throw UnsupportedError on mutation', () {
        final now = DateTime.utc(2026, 3, 15, 10, 0);

        controller.applyRefreshSnapshotForTesting(
          AppRefreshSnapshot(
            categories: [
              Category(
                id: 'cat-1',
                name: 'Work',
                createdAt: now,
                eventColor: 0xFF123456,
              ),
            ],
            projects: [
              Project(
                id: 'proj-1',
                categoryId: 'cat-1',
                name: 'Todorbit',
                createdAt: now,
              ),
            ],
            tasks: [
              LifeTask(
                id: 'task-1',
                title: 'Implement ARCH-06',
                notes: '',
                status: TaskStatus.inProgress,
                priority: 1,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            events: [
              FixedEvent(
                id: 'evt-1',
                title: 'Window Event',
                notes: '',
                startsAt: now,
                endsAt: now.add(const Duration(hours: 1)),
                createdAt: now,
                updatedAt: now,
              ),
            ],
            todayEvents: [
              FixedEvent(
                id: 'evt-today',
                title: 'Today Event',
                notes: '',
                startsAt: now.add(const Duration(hours: 2)),
                endsAt: now.add(const Duration(hours: 3)),
                createdAt: now,
                updatedAt: now,
              ),
            ],
            alarmRules: const [
              AlarmRule(
                id: 'alarm-1',
                config: AlarmConfig(),
                updatedAt: '2026-03-15T10:00:00Z',
                taskId: 'task-1',
              ),
            ],
            sessions: [
              WorkSession(
                id: 'sess-1',
                taskId: 'task-1',
                startsAt: now,
                endsAt: now.add(const Duration(minutes: 25)),
                outcome: SessionOutcome.completed,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            availability: const AvailabilityPlan(
              weekly: {
                1: [AvailabilityWindow(540, 1020)],
              },
            ),
            schedulingHistory: [
              SchedulingOperation(
                id: 'op-1',
                type: ScheduleOperationType.move,
                source: ScheduleChangeSource.manual,
                scope: 'day',
                createdAt: now,
                changes: const [],
              ),
            ],
            dependencies: const [
              TaskDependency(taskId: 'task-2', prerequisiteId: 'task-1'),
            ],
            sequences: [
              TaskSequence(
                id: 'seq-1',
                name: 'Release Flow',
                taskIds: const ['task-1', 'task-2'],
                createdAt: now,
                updatedAt: now,
              ),
            ],
            habits: [
              Habit(
                id: 'habit-1',
                title: 'Review PRs',
                notes: 'Daily review',
                kind: HabitKind.binary,
                target: 1.0,
                unit: 'times',
                rule: RecurrenceRule(
                  kind: RecurrenceKind.daily,
                  startDate: '2026-03-01',
                ),
                createdAt: now,
                updatedAt: now,
              ),
            ],
            habitEntries: [
              HabitEntry(
                id: 'he-1',
                habitId: 'habit-1',
                localDate: '2026-03-15',
                value: 1.0,
                notes: 'done',
                createdAt: now,
                updatedAt: now,
              ),
            ],
            habitRestDays: const [
              HabitRestDay(
                id: 'hrd-1',
                habitId: 'habit-1',
                localDate: '2026-03-16',
                notes: 'rest',
              ),
            ],
            goals: [
              Goal(
                id: 'goal-1',
                title: 'Complete Refactor',
                description: 'All milestones',
                target: 9.0,
                unit: 'milestones',
                startDate: '2026-03-01',
                deadlineDate: '2026-03-31',
                createdAt: now,
                updatedAt: now,
                progress: const GoalProgress(
                  manual: 1.0,
                  tasks: 1.0,
                  habits: 1.0,
                ),
              ),
            ],
            goalMilestones: [
              GoalMilestone(
                id: 'gm-1',
                goalId: 'goal-1',
                title: 'M3 Complete',
                threshold: 3.0,
                deadlineDate: '2026-03-20',
                updatedAt: now,
              ),
            ],
            timeEntries: [
              TimeEntry(
                id: 'te-1',
                taskId: 'task-1',
                sessionId: 'sess-1',
                timerRunId: 'timer-1',
                source: TimeEntrySource.timer,
                startsAt: now,
                endsAt: now.add(const Duration(minutes: 25)),
                notes: '',
                updatedAt: now,
              ),
            ],
            activeTimer: TimerRun(
              id: 'timer-1',
              taskId: 'task-1',
              state: TimerState.paused,
              startedAt: now,
              lastSeenAt: now,
              updatedAt: now,
              canControl: true,
            ),
            templates: [
              LifeTemplate(
                id: 'tpl-1',
                name: 'Sprint Task',
                kind: TemplateKind.task,
                payload: const <String, dynamic>{},
                updatedAt: now,
              ),
            ],
            savedViews: [
              SavedView(
                id: 'sv-1',
                name: 'Important',
                filter: const TaskFilter(),
                updatedAt: now,
              ),
            ],
            trashItems: [
              TrashItem(
                kind: TrashKind.task,
                id: 'tr-1',
                name: 'Old Idea',
                deletedAt: now,
                affectedTasks: 1,
              ),
            ],
            archivedTasks: [
              LifeTask(
                id: 'arch-1',
                title: 'Old Archive',
                notes: '',
                status: TaskStatus.completed,
                priority: 0,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            archivedSeries: [
              ArchivedSeries(
                familyId: 'series-1',
                title: 'Weekly Standup',
                archivedAt: now,
                occurrences: 10,
              ),
            ],
            reportTasks: [
              LifeTask(
                id: 'rep-1',
                title: 'Report Task',
                notes: '',
                status: TaskStatus.completed,
                priority: 0,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            iconKeys: const {'task-1': 'star_rounded'},
            taskParents: const {'subtask-1': 'task-1'},
            checklistItems: [
              TaskChecklistItem(
                id: 'ci-1',
                taskId: 'task-1',
                title: 'Sub-check',
                done: false,
                position: 0,
                updatedAt: now,
              ),
            ],
            progressiveAssignments: const {
              'task-1': ProgressiveAssignment(
                taskId: 'task-1',
                title: 'Phase 1',
                stepIndex: 1,
                carryForward: false,
                manual: true,
              ),
            },
            checklistGroups: [
              TaskChecklistGroup(
                id: 'cg-1',
                taskId: 'task-1',
                title: 'Design group',
                position: 0,
                updatedAt: now,
              ),
            ],
          ),
          '2026-03-15',
        );

        // Verify list collections: UnmodifiableListView type and throws UnsupportedError on add/clear
        expect(controller.categories, isA<UnmodifiableListView<Category>>());
        expect(() => controller.categories.clear(), throwsUnsupportedError);
        expect(
          () => controller.categories.add(controller.categories.first),
          throwsUnsupportedError,
        );

        expect(controller.projects, isA<UnmodifiableListView<Project>>());
        expect(() => controller.projects.clear(), throwsUnsupportedError);
        expect(
          () => controller.projects.add(controller.projects.first),
          throwsUnsupportedError,
        );

        expect(controller.tasks, isA<UnmodifiableListView<LifeTask>>());
        expect(() => controller.tasks.clear(), throwsUnsupportedError);
        expect(
          () => controller.tasks.add(controller.tasks.first),
          throwsUnsupportedError,
        );

        expect(controller.events, isA<UnmodifiableListView<FixedEvent>>());
        expect(() => controller.events.clear(), throwsUnsupportedError);
        expect(
          () => controller.events.add(controller.events.first),
          throwsUnsupportedError,
        );

        expect(controller.todayEvents, isA<UnmodifiableListView<FixedEvent>>());
        expect(() => controller.todayEvents.clear(), throwsUnsupportedError);
        expect(
          () => controller.todayEvents.add(controller.todayEvents.first),
          throwsUnsupportedError,
        );

        expect(controller.alarmRules, isA<UnmodifiableListView<AlarmRule>>());
        expect(() => controller.alarmRules.clear(), throwsUnsupportedError);
        expect(
          () => controller.alarmRules.add(controller.alarmRules.first),
          throwsUnsupportedError,
        );

        expect(controller.sessions, isA<UnmodifiableListView<WorkSession>>());
        expect(() => controller.sessions.clear(), throwsUnsupportedError);
        expect(
          () => controller.sessions.add(controller.sessions.first),
          throwsUnsupportedError,
        );

        expect(
          controller.schedulingHistory,
          isA<UnmodifiableListView<SchedulingOperation>>(),
        );
        expect(
          () => controller.schedulingHistory.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => controller.schedulingHistory.add(
            controller.schedulingHistory.first,
          ),
          throwsUnsupportedError,
        );

        expect(
          controller.dependencies,
          isA<UnmodifiableListView<TaskDependency>>(),
        );
        expect(() => controller.dependencies.clear(), throwsUnsupportedError);
        expect(
          () => controller.dependencies.add(controller.dependencies.first),
          throwsUnsupportedError,
        );

        expect(controller.sequences, isA<UnmodifiableListView<TaskSequence>>());
        expect(() => controller.sequences.clear(), throwsUnsupportedError);
        expect(
          () => controller.sequences.add(controller.sequences.first),
          throwsUnsupportedError,
        );

        expect(controller.habits, isA<UnmodifiableListView<Habit>>());
        expect(() => controller.habits.clear(), throwsUnsupportedError);
        expect(
          () => controller.habits.add(controller.habits.first),
          throwsUnsupportedError,
        );

        expect(
          controller.habitEntries,
          isA<UnmodifiableListView<HabitEntry>>(),
        );
        expect(() => controller.habitEntries.clear(), throwsUnsupportedError);
        expect(
          () => controller.habitEntries.add(controller.habitEntries.first),
          throwsUnsupportedError,
        );

        expect(
          controller.habitRestDays,
          isA<UnmodifiableListView<HabitRestDay>>(),
        );
        expect(() => controller.habitRestDays.clear(), throwsUnsupportedError);
        expect(
          () => controller.habitRestDays.add(controller.habitRestDays.first),
          throwsUnsupportedError,
        );

        expect(controller.goals, isA<UnmodifiableListView<Goal>>());
        expect(() => controller.goals.clear(), throwsUnsupportedError);
        expect(
          () => controller.goals.add(controller.goals.first),
          throwsUnsupportedError,
        );

        expect(
          controller.goalMilestones,
          isA<UnmodifiableListView<GoalMilestone>>(),
        );
        expect(() => controller.goalMilestones.clear(), throwsUnsupportedError);
        expect(
          () => controller.goalMilestones.add(controller.goalMilestones.first),
          throwsUnsupportedError,
        );

        expect(controller.timeEntries, isA<UnmodifiableListView<TimeEntry>>());
        expect(() => controller.timeEntries.clear(), throwsUnsupportedError);
        expect(
          () => controller.timeEntries.add(controller.timeEntries.first),
          throwsUnsupportedError,
        );

        expect(controller.templates, isA<UnmodifiableListView<LifeTemplate>>());
        expect(() => controller.templates.clear(), throwsUnsupportedError);
        expect(
          () => controller.templates.add(controller.templates.first),
          throwsUnsupportedError,
        );

        expect(controller.savedViews, isA<UnmodifiableListView<SavedView>>());
        expect(() => controller.savedViews.clear(), throwsUnsupportedError);
        expect(
          () => controller.savedViews.add(controller.savedViews.first),
          throwsUnsupportedError,
        );

        expect(controller.trashItems, isA<UnmodifiableListView<TrashItem>>());
        expect(() => controller.trashItems.clear(), throwsUnsupportedError);
        expect(
          () => controller.trashItems.add(controller.trashItems.first),
          throwsUnsupportedError,
        );

        expect(controller.archivedTasks, isA<UnmodifiableListView<LifeTask>>());
        expect(() => controller.archivedTasks.clear(), throwsUnsupportedError);
        expect(
          () => controller.archivedTasks.add(controller.archivedTasks.first),
          throwsUnsupportedError,
        );

        expect(
          controller.archivedSeries,
          isA<UnmodifiableListView<ArchivedSeries>>(),
        );
        expect(() => controller.archivedSeries.clear(), throwsUnsupportedError);
        expect(
          () => controller.archivedSeries.add(controller.archivedSeries.first),
          throwsUnsupportedError,
        );

        expect(controller.reportTasks, isA<UnmodifiableListView<LifeTask>>());
        expect(() => controller.reportTasks.clear(), throwsUnsupportedError);
        expect(
          () => controller.reportTasks.add(controller.reportTasks.first),
          throwsUnsupportedError,
        );

        expect(
          controller.checklistItems,
          isA<UnmodifiableListView<TaskChecklistItem>>(),
        );
        expect(() => controller.checklistItems.clear(), throwsUnsupportedError);
        expect(
          () => controller.checklistItems.add(controller.checklistItems.first),
          throwsUnsupportedError,
        );

        expect(
          controller.checklistGroups,
          isA<UnmodifiableListView<TaskChecklistGroup>>(),
        );
        expect(
          () => controller.checklistGroups.clear(),
          throwsUnsupportedError,
        );
        expect(
          () =>
              controller.checklistGroups.add(controller.checklistGroups.first),
          throwsUnsupportedError,
        );

        // Verify map collections: UnmodifiableMapView type and throws UnsupportedError on mutation
        expect(controller.iconKeys, isA<UnmodifiableMapView<String, String>>());
        expect(() => controller.iconKeys.clear(), throwsUnsupportedError);
        expect(
          () => controller.iconKeys['new'] = 'val',
          throwsUnsupportedError,
        );

        expect(
          controller.taskParents,
          isA<UnmodifiableMapView<String, String>>(),
        );
        expect(() => controller.taskParents.clear(), throwsUnsupportedError);
        expect(
          () => controller.taskParents['new'] = 'val',
          throwsUnsupportedError,
        );

        expect(
          controller.progressiveAssignments,
          isA<UnmodifiableMapView<String, ProgressiveAssignment>>(),
        );
        expect(
          () => controller.progressiveAssignments.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => controller.progressiveAssignments['new'] =
              controller.progressiveAssignments.values.first,
          throwsUnsupportedError,
        );
      });
    },
  );

  group('ARCH-06: Scoped Riverpod Selector Responsiveness', () {
    testWidgets(
      'scoped selectors isolate rebuilds to only relevant field listeners',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);

        int themeBuildCount = 0;
        int taskCountBuildCount = 0;
        int weekdayBuildCount = 0;

        final widget = ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    themeBuildCount++;
                    final theme = ref.watch(
                      appControllerProvider.select((c) => c.theme),
                    );
                    return Text('Theme: ${theme.name}');
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    taskCountBuildCount++;
                    final count = ref.watch(
                      appControllerProvider.select((c) => c.tasks.length),
                    );
                    return Text('Tasks: $count');
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    weekdayBuildCount++;
                    final firstWeekday = ref.watch(
                      appControllerProvider.select((c) => c.firstWeekday),
                    );
                    return Text('Weekday: $firstWeekday');
                  },
                ),
              ],
            ),
          ),
        );

        await tester.pumpWidget(widget);

        // Initial build: all 3 widgets build once.
        expect(themeBuildCount, equals(1));
        expect(taskCountBuildCount, equals(1));
        expect(weekdayBuildCount, equals(1));
        expect(find.text('Theme: system'), findsOneWidget);
        expect(find.text('Tasks: 0'), findsOneWidget);
        expect(find.text('Weekday: 7'), findsOneWidget);

        // Update tasks only: taskCountBuildCount must increment, others must NOT rebuild.
        final now = DateTime.utc(2026, 3, 15, 10, 0);
        controller.tasks = [
          LifeTask(
            id: 't-scoped-1',
            title: 'Scoped Task',
            notes: '',
            status: TaskStatus.notStarted,
            priority: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ];
        controller.notifyListeners();
        await tester.pump();

        expect(taskCountBuildCount, equals(2));
        expect(
          themeBuildCount,
          equals(1),
          reason: 'Theme consumer must not rebuild on task changes',
        );
        expect(
          weekdayBuildCount,
          equals(1),
          reason: 'Weekday consumer must not rebuild on task changes',
        );
        expect(find.text('Tasks: 1'), findsOneWidget);

        // Update theme only: themeBuildCount must increment, others must NOT rebuild.
        await controller.setTheme(ThemeModePreference.dark);
        await tester.pump();

        expect(themeBuildCount, equals(2));
        expect(
          taskCountBuildCount,
          equals(2),
          reason: 'Task count consumer must not rebuild on theme changes',
        );
        expect(
          weekdayBuildCount,
          equals(1),
          reason: 'Weekday consumer must not rebuild on theme changes',
        );
        expect(find.text('Theme: dark'), findsOneWidget);

        // Update firstWeekday only: weekdayBuildCount must increment, others must NOT rebuild.
        await controller.setFirstWeekday(1);
        await tester.pump();

        expect(weekdayBuildCount, equals(2));
        expect(
          themeBuildCount,
          equals(2),
          reason: 'Theme consumer must not rebuild on weekday changes',
        );
        expect(
          taskCountBuildCount,
          equals(2),
          reason: 'Task count consumer must not rebuild on weekday changes',
        );
        expect(find.text('Weekday: 1'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      },
    );
  });

  group('ARCH-06: Active Timer Rebuild Isolation', () {
    testWidgets(
      '1-second timer ticker rebuilds only the active timer badge without parent workspace rebuild',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);

        final now = DateTime.now();
        final timerRun = TimerRun(
          id: 'timer-run-active',
          taskId: 'task-active-1',
          state: TimerState.running,
          startedAt: now.subtract(const Duration(seconds: 10)),
          lastSeenAt: now.subtract(const Duration(seconds: 10)),
          updatedAt: now,
          canControl: true,
        );

        final testTask = LifeTask(
          id: 'task-active-1',
          title: 'Deep Work Task',
          notes: '',
          status: TaskStatus.inProgress,
          priority: 1,
          createdAt: now,
          updatedAt: now,
        );

        controller.applyRefreshSnapshotForTesting(
          AppRefreshSnapshot(
            categories: const [],
            projects: const [],
            tasks: [testTask],
            events: const [],
            todayEvents: const [],
            alarmRules: const [],
            sessions: const [],
            availability: const AvailabilityPlan(weekly: {}),
            schedulingHistory: const [],
            dependencies: const [],
            sequences: const [],
            habits: const [],
            habitEntries: const [],
            habitRestDays: const [],
            goals: const [],
            goalMilestones: const [],
            timeEntries: [
              TimeEntry(
                id: 'te-active-1',
                taskId: 'task-active-1',
                sessionId: 'sess-active-1',
                timerRunId: 'timer-run-active',
                source: TimeEntrySource.timer,
                startsAt: now.subtract(const Duration(seconds: 10)),
                endsAt: now,
                notes: '',
                updatedAt: now,
              ),
            ],
            activeTimer: timerRun,
            templates: const [],
            savedViews: const [],
            trashItems: const [],
            archivedTasks: const [],
            archivedSeries: const [],
            reportTasks: const [],
            iconKeys: const {},
            taskParents: const {},
            checklistItems: const [],
            checklistGroups: const [],
            progressiveAssignments: const {},
          ),
          '2026-03-15',
        );

        int workspaceParentBuildCount = 0;
        String openedTaskId = '';

        final testWidget = ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  workspaceParentBuildCount++;
                  return Column(
                    children: [
                      Text('Workspace Shell Build: $workspaceParentBuildCount'),
                      WorkspaceActiveTimerBadge(
                        open: (taskId) => openedTaskId = taskId,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpWidget(testWidget);

        // Shell built once initially.
        expect(workspaceParentBuildCount, equals(1));
        expect(find.text('Deep Work Task'), findsOneWidget);
        expect(find.byType(CompactTaskTimer), findsOneWidget);

        // Advance clock by 1 second (periodic ticker tick).
        await tester.pump(const Duration(seconds: 1));

        // Parent workspace shell must NOT have rebuilt!
        expect(
          workspaceParentBuildCount,
          equals(1),
          reason:
              'Workspace shell must not rebuild on 1-second active timer ticks',
        );

        // Advance clock by another 2 seconds.
        await tester.pump(const Duration(seconds: 2));

        // Parent workspace shell STILL must not have rebuilt.
        expect(
          workspaceParentBuildCount,
          equals(1),
          reason: 'Workspace shell must remain isolated from periodic timer rebuilds',
        );

        // Interactivity: tap the timer badge to ensure callback functions correctly.
        await tester.tap(find.text('Deep Work Task'));
        await tester.pump();
        expect(openedTaskId, equals('task-active-1'));

        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      },
    );
  });
}
