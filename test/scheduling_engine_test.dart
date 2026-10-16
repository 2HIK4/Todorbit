import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/scheduling_engine.dart';

void main() {
  final monday = DateTime(2026, 10, 19, 9);

  LifeTask task(String id, {String? deadline}) => LifeTask(
    id: id,
    title: id,
    notes: '',
    status: TaskStatus.notStarted,
    priority: 0,
    deadlineDate: deadline,
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
      availability: AvailabilityPlan.standard,
      earliest: monday,
    );
    expect(preview.canApply, isTrue);
    expect(preview.moves.map((move) => move.session.id), ['one', 'two']);
    expect(preview.moves[0].startsAt.toLocal().hour, 11);
    expect(preview.moves[1].startsAt.toLocal().hour, 12);
    expect(first.startsAt.toLocal().hour, 9); // preview is non-mutating
  });

  test('date exception overrides weekly availability', () {
    final preview = const SchedulingEngine().repack(
      selected: [session('one', 'task', monday, const Duration(hours: 1))],
      otherSessions: const [],
      fixedEvents: const [],
      tasksById: {'task': task('task')},
      availability: AvailabilityPlan(
        weekly: AvailabilityPlan.standard.weekly,
        exceptions: {
          '2026-10-19': [AvailabilityWindow(13 * 60, 15 * 60)],
        },
      ),
      earliest: monday,
    );
    expect(preview.moves.single.startsAt.toLocal().hour, 13);
  });

  test('no slot gives hard explanation; deadline gives warning', () {
    final selected = [session('one', 'task', monday, const Duration(hours: 1))];
    final noSlot = const SchedulingEngine().repack(
      selected: selected,
      otherSessions: const [],
      fixedEvents: const [],
      tasksById: {'task': task('task')},
      availability: const AvailabilityPlan(weekly: {}),
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
      availability: AvailabilityPlan.standard,
      earliest: monday,
    );
    expect(late.canApply, isTrue);
    expect(late.issues.single.kind, ScheduleIssueKind.deadlineWarning);
  });
}
