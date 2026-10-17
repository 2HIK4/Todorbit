import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/scheduling_engine.dart';

void main() {
  final monday = DateTime(2026, 10, 19, 9);
  const workWeek = AvailabilityPlan(
    weekly: {
      1: [AvailabilityWindow(9 * 60, 17 * 60)],
      2: [AvailabilityWindow(9 * 60, 17 * 60)],
      3: [AvailabilityWindow(9 * 60, 17 * 60)],
      4: [AvailabilityWindow(9 * 60, 17 * 60)],
      5: [AvailabilityWindow(9 * 60, 17 * 60)],
    },
  );

  LifeTask task(
    String id, {
    String? scheduled = '2026-10-19',
    String? deadline,
    TaskStatus status = TaskStatus.notStarted,
    bool locked = false,
  }) => LifeTask(
    id: id,
    title: id,
    notes: '',
    status: status,
    priority: 0,
    scheduledDate: scheduled,
    deadlineDate: deadline,
    schedulingLocked: locked,
    createdAt: monday.toUtc(),
    updatedAt: monday.toUtc(),
  );

  WorkSession session(
    String id,
    String taskId,
    DateTime start,
    Duration length,
  ) => WorkSession(
    id: id,
    taskId: taskId,
    startsAt: start.toUtc(),
    endsAt: start.add(length).toUtc(),
    outcome: SessionOutcome.upcoming,
    createdAt: monday.toUtc(),
    updatedAt: monday.toUtc(),
  );

  FixedEvent event(DateTime start, Duration length) => FixedEvent(
    id: 'event',
    title: 'Lecture',
    notes: '',
    startsAt: start.toUtc(),
    endsAt: start.add(length).toUtc(),
    createdAt: monday.toUtc(),
    updatedAt: monday.toUtc(),
  );

  test('move and backward shift preserve date-only tasks and deadlines', () {
    final original = task('task', deadline: '2026-10-20');
    final moved = const SchedulingEngine().moveTasks(
      selected: [original],
      targetDay: DateTime(2026, 10, 22, 15),
      scope: 'test',
    );
    expect(moved.changes.single.afterDate, '2026-10-22');
    expect(moved.issues.single.kind, ScheduleIssueKind.deadlineViolation);
    expect(original.deadlineDate, '2026-10-20');

    final shifted = const SchedulingEngine().shiftTasks(
      selected: [original],
      days: -2,
      scope: 'test',
    );
    expect(shifted.changes.single.afterDate, '2026-10-17');
    expect(original.scheduledDate, '2026-10-19');
  });

  test('completed tasks are preserved and locked tasks are hard conflicts', () {
    final preview = const SchedulingEngine().shiftTasks(
      selected: [
        task('done', status: TaskStatus.completed),
        task('locked', locked: true),
      ],
      days: 1,
      scope: 'test',
    );
    expect(preview.changes, isEmpty);
    expect(preview.issues.map((issue) => issue.kind), [
      ScheduleIssueKind.completed,
      ScheduleIssueKind.locked,
    ]);
    expect(preview.canApply, isFalse);
  });

  test('repack avoids protected event and other session', () {
    final first = session('one', 'task', monday, const Duration(hours: 1));
    final second = session(
      'two',
      'task',
      monday.add(const Duration(hours: 2)),
      const Duration(hours: 1),
    );
    final preview = const SchedulingEngine().repack(
      selected: [second, first],
      otherSessions: [
        session(
          'other',
          'other-task',
          monday.add(const Duration(hours: 1)),
          const Duration(hours: 1),
        ),
      ],
      fixedEvents: [event(monday, const Duration(hours: 1))],
      tasksById: {'task': task('task')},
      availability: workWeek,
      earliest: monday,
    );
    expect(preview.canApply, isTrue);
    expect(preview.changes.map((change) => change.targetId), ['one', 'two']);
    expect(preview.changes[0].afterStartsAt!.toLocal().hour, 11);
    expect(preview.changes[1].afterStartsAt!.toLocal().hour, 12);
    expect(first.startsAt.toLocal().hour, 9);
  });

  test('date exception overrides weekly availability', () {
    final preview = const SchedulingEngine().repack(
      selected: [session('one', 'task', monday, const Duration(hours: 1))],
      otherSessions: const [],
      fixedEvents: const [],
      tasksById: {'task': task('task')},
      availability: AvailabilityPlan(
        weekly: workWeek.weekly,
        exceptions: {
          '2026-10-19': [AvailabilityWindow(13 * 60, 15 * 60)],
        },
      ),
      earliest: monday,
    );
    expect(preview.changes.single.afterStartsAt!.toLocal().hour, 13);
  });

  test('no availability is hard; deadline overrun is a warning', () {
    final selected = [session('one', 'task', monday, const Duration(hours: 1))];
    final noSlot = const SchedulingEngine().repack(
      selected: selected,
      otherSessions: const [],
      fixedEvents: const [],
      tasksById: {},
      availability: AvailabilityPlan(weekly: {}),
      earliest: monday,
      horizonDays: 2,
    );
    expect(noSlot.canApply, isFalse);
    expect(noSlot.issues.single.kind, ScheduleIssueKind.noAvailability);

    final late = const SchedulingEngine().repack(
      selected: selected,
      otherSessions: const [],
      fixedEvents: const [],
      tasksById: {'task': task('task', deadline: '2026-10-18')},
      availability: workWeek,
      earliest: monday.add(const Duration(hours: 1)),
    );
    expect(late.canApply, isTrue);
    expect(late.issues.single.kind, ScheduleIssueKind.deadlineViolation);
  });

  test('move reports fixed-event collision as a hard conflict', () {
    final value = session('one', 'task', monday, const Duration(hours: 1));
    final preview = const SchedulingEngine().moveSessions(
      selected: [value],
      otherSessions: [],
      fixedEvents: [],
      tasksById: {},
      firstStart: monday.add(const Duration(hours: 1)),
      scope: 'test',
    );
    expect(preview.canApply, isTrue);

    final conflict = const SchedulingEngine().moveSessions(
      selected: [value],
      otherSessions: [],
      fixedEvents: [event(monday, const Duration(hours: 2))],
      tasksById: {},
      firstStart: monday.add(const Duration(minutes: 30)),
      scope: 'test',
    );
    expect(conflict.canApply, isFalse);
    expect(conflict.issues.single.kind, ScheduleIssueKind.fixedEventCollision);
  });

  test('buffer separates repacked sessions', () {
    final preview = const SchedulingEngine().repack(
      selected: [
        session('one', 'task', monday, const Duration(minutes: 30)),
        session('two', 'task', monday, const Duration(minutes: 30)),
      ],
      otherSessions: [],
      fixedEvents: [],
      tasksById: {},
      availability: workWeek,
      earliest: monday,
      buffer: const Duration(minutes: 15),
    );
    expect(preview.changes, hasLength(1));
    expect(preview.changes.single.targetId, 'two');
    expect(
      preview.changes.single.afterStartsAt!.toLocal(),
      monday.add(const Duration(minutes: 45)),
    );
  });

  test('split creates two sessions without creating a task', () {
    final original = session('one', 'task', monday, const Duration(hours: 2));
    final preview = const SchedulingEngine().splitSession(
      session: original,
      task: null,
      firstMinutes: 45,
      newSessionId: 'new-session',
      scope: 'test',
    );
    expect(preview.canApply, isTrue);
    expect(preview.changes, hasLength(2));
    expect(preview.changes.last.createsSession, isTrue);
    expect(preview.changes.last.taskId, 'task');
  });

  test('calendar-day shift preserves a cross-midnight local session', () {
    final start = DateTime(2026, 10, 19, 23, 30);
    final original = session('late', 'task', start, const Duration(hours: 2));
    final preview = const SchedulingEngine().shiftSessions(
      selected: [original],
      otherSessions: [],
      fixedEvents: [],
      tasksById: {},
      days: 1,
      scope: 'test',
    );
    final changed = preview.changes.single;
    expect(changed.afterStartsAt!.toLocal().day, 20);
    expect(changed.afterStartsAt!.toLocal().hour, 23);
    expect(changed.afterEndsAt!.toLocal().day, 21);
    expect(
      changed.afterEndsAt!.difference(changed.afterStartsAt!),
      const Duration(hours: 2),
    );
  });
}
