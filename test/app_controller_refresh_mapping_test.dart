import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
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

class _FailingRepository extends LifeRepository {
  _FailingRepository(super.db);

  @override
  Future<List<Category>> categories() {
    throw StateError('Simulated database failure during categories fetch');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppRefreshSnapshot and AppController refresh mapping tests', () {
    late AppDatabase db;
    late LifeRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = LifeRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'AppController maps all 29 fields identically from AppRefreshSnapshot',
      () async {
        final controller = AppController(repository);
        addTearDown(controller.dispose);

        final now = DateTime.utc(2026, 3, 15, 10, 0);

        final snapshot = AppRefreshSnapshot(
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
              title: 'Implement ARCH-05',
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
        );

        // Verify controller initial state
        expect(controller.loading, isTrue);

        // Apply snapshot
        controller.applyRefreshSnapshotForTesting(snapshot, '2026-03-15');

        // Verify all 29 fields are mapped identically
        expect(controller.categories, equals(snapshot.categories));
        expect(controller.projects, equals(snapshot.projects));
        expect(controller.tasks, equals(snapshot.tasks));
        expect(controller.events, equals(snapshot.events));
        expect(controller.todayEvents, equals(snapshot.todayEvents));
        expect(controller.alarmRules, equals(snapshot.alarmRules));
        expect(controller.sessions, equals(snapshot.sessions));
        expect(controller.availability, equals(snapshot.availability));
        expect(
          controller.schedulingHistory,
          equals(snapshot.schedulingHistory),
        );
        expect(controller.dependencies, equals(snapshot.dependencies));
        expect(controller.sequences, equals(snapshot.sequences));
        expect(controller.habits, equals(snapshot.habits));
        expect(controller.habitEntries, equals(snapshot.habitEntries));
        expect(controller.habitRestDays, equals(snapshot.habitRestDays));
        expect(controller.goals, equals(snapshot.goals));
        expect(controller.goalMilestones, equals(snapshot.goalMilestones));
        expect(controller.timeEntries, equals(snapshot.timeEntries));
        expect(controller.activeTimer, equals(snapshot.activeTimer));
        expect(controller.templates, equals(snapshot.templates));
        expect(controller.savedViews, equals(snapshot.savedViews));
        expect(controller.trashItems, equals(snapshot.trashItems));
        expect(controller.archivedTasks, equals(snapshot.archivedTasks));
        expect(controller.archivedSeries, equals(snapshot.archivedSeries));
        expect(controller.reportTasks, equals(snapshot.reportTasks));
        expect(controller.iconKeys, equals(snapshot.iconKeys));
        expect(controller.taskParents, equals(snapshot.taskParents));
        expect(controller.checklistItems, equals(snapshot.checklistItems));
        expect(
          controller.progressiveAssignments,
          equals(snapshot.progressiveAssignments),
        );
        expect(controller.checklistGroups, equals(snapshot.checklistGroups));

        // Verify loading and date bookkeeping
        expect(controller.loading, isFalse);
        expect(controller.lastKnownDate, equals('2026-03-15'));
      },
    );

    test('interrupted running timer is marked for recovery on initial load and subsequent loads', () async {
      final controller = AppController(repository);
      addTearDown(controller.dispose);

      final now = DateTime.utc(2026, 3, 15, 10, 0);

      AppRefreshSnapshot createSnapshotWithTimer(TimerRun? timer) {
        return AppRefreshSnapshot(
          categories: const [],
          projects: const [],
          tasks: const [],
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
          timeEntries: const [],
          activeTimer: timer,
          templates: const [],
          savedViews: const [],
          trashItems: const [],
          archivedTasks: const [],
          archivedSeries: const [],
          reportTasks: const [],
          iconKeys: const {},
          taskParents: const {},
          checklistItems: const [],
          progressiveAssignments: const {},
          checklistGroups: const [],
        );
      }

      // Initial load with a running, controllable timer that did not yet have recoveryRequired
      final runningTimer = TimerRun(
        id: 'timer-running-1',
        taskId: 'task-1',
        state: TimerState.running,
        startedAt: now,
        lastSeenAt: now,
        updatedAt: now,
        canControl: true,
        recoveryRequired: false,
      );

      controller.applyRefreshSnapshotForTesting(
        createSnapshotWithTimer(runningTimer),
        '2026-03-15',
      );

      // The interrupted timer recovery logic should flag recoveryRequired: true
      expect(controller.activeTimer, isNotNull);
      expect(controller.activeTimer!.id, equals('timer-running-1'));
      expect(controller.activeTimer!.recoveryRequired, isTrue);

      // On a subsequent refresh with the same timer id, recoveryRequired remains true
      final nextSnapshotTimer = TimerRun(
        id: 'timer-running-1',
        taskId: 'task-1',
        state: TimerState.running,
        startedAt: now,
        lastSeenAt: now.add(const Duration(seconds: 10)),
        updatedAt: now.add(const Duration(seconds: 10)),
        canControl: true,
        recoveryRequired: false,
      );
      controller.applyRefreshSnapshotForTesting(
        createSnapshotWithTimer(nextSnapshotTimer),
        '2026-03-15',
      );
      expect(controller.activeTimer!.recoveryRequired, isTrue);

      // A different timer created later should not be marked for recovery
      final newTimer = TimerRun(
        id: 'timer-new-2',
        taskId: 'task-2',
        state: TimerState.running,
        startedAt: now.add(const Duration(minutes: 5)),
        lastSeenAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
        canControl: true,
        recoveryRequired: false,
      );
      controller.applyRefreshSnapshotForTesting(
        createSnapshotWithTimer(newTimer),
        '2026-03-15',
      );
      expect(controller.activeTimer!.id, equals('timer-new-2'));
      expect(controller.activeTimer!.recoveryRequired, isFalse);
    });

    test('AppRefreshSnapshot.load reuses windowEvents future when today is in event window', () async {
      final snapshot = await AppRefreshSnapshot.load(
        repository,
        eventWindowFrom: '2026-03-01',
        eventWindowThrough: '2026-03-31',
        today: '2026-03-15',
      );

      // When today is within [eventWindowFrom, eventWindowThrough], todayEvents is aliased to events
      expect(identical(snapshot.events, snapshot.todayEvents), isTrue);
    });

    test('AppRefreshSnapshot.load loads independent todayEvents when today is outside window', () async {
      final snapshot = await AppRefreshSnapshot.load(
        repository,
        eventWindowFrom: '2026-03-01',
        eventWindowThrough: '2026-03-10',
        today: '2026-03-15',
      );

      // When today is outside [eventWindowFrom, eventWindowThrough], todayEvents is queried separately
      expect(identical(snapshot.events, snapshot.todayEvents), isFalse);
    });

    test(
      'refresh error bubbles without state corruption when repository throws',
      () async {
        final failingRepo = _FailingRepository(db);
        final controller = AppController(failingRepo);
        addTearDown(controller.dispose);

        // Pre-condition: controller has default initial state
        expect(controller.loading, isTrue);
        expect(controller.categories, isEmpty);
        expect(controller.stateRevision, equals(0));

        // Calling refresh() must bubble the StateError from FailingRepository
        expect(
          () => controller.refresh(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Simulated database failure'),
            ),
          ),
        );

        // Post-condition: controller state was NOT mutated or corrupted
        expect(controller.loading, isTrue);
        expect(controller.categories, isEmpty);
        expect(controller.stateRevision, equals(0));
        expect(controller.lastKnownDate, isNull);
      },
    );
  });
}
