import 'models.dart';
import 'scheduling_models.dart';

export 'scheduling_models.dart';

class SchedulingEngine {
  const SchedulingEngine();

  SchedulingPreview moveTasks({
    required List<LifeTask> selected,
    required DateTime targetDay,
    required String scope,
  }) => _taskDatePreview(
    operation: ScheduleOperationType.move,
    selected: selected,
    scope: scope,
    transform: (_) => localDate(targetDay),
  );

  SchedulingPreview shiftTasks({
    required List<LifeTask> selected,
    required int days,
    required String scope,
    ScheduleOperationType operation = ScheduleOperationType.shift,
  }) => _taskDatePreview(
    operation: operation,
    selected: selected,
    scope: scope,
    transform: (task) {
      final value = task.scheduledDate;
      if (value == null) return null;
      final day = DateTime.parse(value);
      return localDate(DateTime(day.year, day.month, day.day + days));
    },
  );

  SchedulingPreview reorderTasks({
    required List<LifeTask> ordered,
    required DateTime firstDay,
    required String scope,
    int spacingDays = 1,
  }) {
    var index = 0;
    return _taskDatePreview(
      operation: ScheduleOperationType.reorder,
      selected: ordered,
      scope: scope,
      transform: (_) => localDate(
        DateTime(
          firstDay.year,
          firstDay.month,
          firstDay.day + index++ * spacingDays,
        ),
      ),
    );
  }

  SchedulingPreview swapTasks({
    required LifeTask first,
    required LifeTask second,
    required String scope,
  }) {
    final issues = <ScheduleIssue>[];
    _taskEligibility(first, issues);
    _taskEligibility(second, issues);
    if (first.scheduledDate == null || second.scheduledDate == null) {
      issues.add(
        const ScheduleIssue(
          kind: ScheduleIssueKind.invalidSelection,
          message: 'Both tasks need a planned date before they can be swapped.',
        ),
      );
    }
    if (first.scheduledDate == second.scheduledDate) {
      issues.add(
        const ScheduleIssue(
          kind: ScheduleIssueKind.invalidSelection,
          severity: ScheduleIssueSeverity.warning,
          message: 'The selected tasks already have the same planned date.',
        ),
      );
    }
    final changes = issues.any((issue) => issue.isHard)
        ? <ScheduleChange>[]
        : first.scheduledDate == second.scheduledDate
        ? <ScheduleChange>[]
        : [
            _taskChange(first, second.scheduledDate),
            _taskChange(second, first.scheduledDate),
          ];
    return _preview(ScheduleOperationType.swap, scope, changes, issues);
  }

  SchedulingPreview _taskDatePreview({
    required ScheduleOperationType operation,
    required List<LifeTask> selected,
    required String scope,
    required String? Function(LifeTask task) transform,
  }) {
    final issues = <ScheduleIssue>[];
    final changes = <ScheduleChange>[];
    for (final task in selected) {
      if (!_taskEligibility(task, issues)) continue;
      final next = transform(task);
      if (next == null) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.invalidSelection,
            targetId: task.id,
            message: '“${task.title}” has no planned date to shift.',
          ),
        );
        continue;
      }
      if (next == task.scheduledDate) continue;
      changes.add(_taskChange(task, next));
      if (task.deadlineDate != null && next.compareTo(task.deadlineDate!) > 0) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.deadlineViolation,
            severity: ScheduleIssueSeverity.warning,
            targetId: task.id,
            message: '“${task.title}” would be planned after its deadline.',
          ),
        );
      }
    }
    return _preview(operation, scope, changes, issues);
  }

  bool _taskEligibility(LifeTask task, List<ScheduleIssue> issues) {
    if (!task.isOpen) {
      issues.add(
        ScheduleIssue(
          kind: ScheduleIssueKind.completed,
          severity: ScheduleIssueSeverity.warning,
          targetId: task.id,
          message:
              '“${task.title}” is complete or cancelled and will not move.',
        ),
      );
      return false;
    }
    if (task.schedulingLocked) {
      issues.add(
        ScheduleIssue(
          kind: ScheduleIssueKind.locked,
          targetId: task.id,
          message: '“${task.title}” is protected from scheduling changes.',
        ),
      );
      return false;
    }
    return true;
  }

  ScheduleChange _taskChange(LifeTask task, String? next) => ScheduleChange(
    targetKind: ScheduleTargetKind.task,
    targetId: task.id,
    expectedUpdatedAt: task.updatedAt,
    beforeDate: task.scheduledDate,
    afterDate: next,
  );

  SchedulingPreview shiftSessions({
    required List<WorkSession> selected,
    required List<WorkSession> otherSessions,
    required List<FixedEvent> fixedEvents,
    required Map<String, LifeTask> tasksById,
    required int days,
    required String scope,
    ScheduleOperationType operation = ScheduleOperationType.shift,
    bool allowOverlap = false,
  }) {
    final changes = <ScheduleChange>[];
    final issues = <ScheduleIssue>[];
    for (final session in selected) {
      final task = tasksById[session.taskId];
      if (!_sessionEligibility(session, task, issues)) continue;
      final localStart = session.startsAt.toLocal();
      final nextStart = DateTime(
        localStart.year,
        localStart.month,
        localStart.day + days,
        localStart.hour,
        localStart.minute,
        localStart.second,
      );
      final nextEnd = nextStart.add(
        session.endsAt.difference(session.startsAt),
      );
      _addCollisionIssues(
        session.id,
        nextStart,
        nextEnd,
        otherSessions,
        fixedEvents,
        issues,
        warningsOnly: allowOverlap,
      );
      _deadlineIssue(session, task, nextEnd, issues);
      if (nextStart.toUtc() != session.startsAt ||
          nextEnd.toUtc() != session.endsAt) {
        changes.add(_sessionChange(session, nextStart, nextEnd));
      }
    }
    return _preview(operation, scope, changes, issues);
  }

  SchedulingPreview moveSessions({
    required List<WorkSession> selected,
    required List<WorkSession> otherSessions,
    required List<FixedEvent> fixedEvents,
    required Map<String, LifeTask> tasksById,
    required DateTime firstStart,
    required String scope,
    Duration buffer = Duration.zero,
    bool allowOverlap = false,
  }) {
    if (buffer.isNegative) throw ArgumentError('Buffer cannot be negative');
    final ordered = [...selected]..sort(_compareSessions);
    final changes = <ScheduleChange>[];
    final issues = <ScheduleIssue>[];
    var cursor = firstStart.toLocal();
    for (final session in ordered) {
      final task = tasksById[session.taskId];
      if (!_sessionEligibility(session, task, issues)) continue;
      final end = cursor.add(session.endsAt.difference(session.startsAt));
      _addCollisionIssues(
        session.id,
        cursor,
        end,
        otherSessions,
        fixedEvents,
        issues,
        warningsOnly: allowOverlap,
      );
      _deadlineIssue(session, task, end, issues);
      if (cursor.toUtc() != session.startsAt || end.toUtc() != session.endsAt) {
        changes.add(_sessionChange(session, cursor, end));
      }
      cursor = end.add(buffer);
    }
    return _preview(ScheduleOperationType.move, scope, changes, issues);
  }

  SchedulingPreview swapSessions({
    required WorkSession first,
    required WorkSession second,
    required Map<String, LifeTask> tasksById,
    required String scope,
  }) {
    final issues = <ScheduleIssue>[];
    if (!_sessionEligibility(first, tasksById[first.taskId], issues) ||
        !_sessionEligibility(second, tasksById[second.taskId], issues)) {
      return _preview(ScheduleOperationType.swap, scope, const [], issues);
    }
    final firstStart = second.startsAt.toLocal();
    final secondStart = first.startsAt.toLocal();
    final changes =
        [
              _sessionChange(
                first,
                firstStart,
                firstStart.add(first.endsAt.difference(first.startsAt)),
              ),
              _sessionChange(
                second,
                secondStart,
                secondStart.add(second.endsAt.difference(second.startsAt)),
              ),
            ]
            .where(
              (change) =>
                  change.beforeStartsAt != change.afterStartsAt ||
                  change.beforeEndsAt != change.afterEndsAt,
            )
            .toList();
    return _preview(ScheduleOperationType.swap, scope, changes, issues);
  }

  SchedulingPreview splitSession({
    required WorkSession session,
    required LifeTask? task,
    required int firstMinutes,
    required String newSessionId,
    required String scope,
    Duration gap = Duration.zero,
  }) {
    final issues = <ScheduleIssue>[];
    if (!_sessionEligibility(session, task, issues)) {
      return _preview(ScheduleOperationType.split, scope, const [], issues);
    }
    final secondMinutes =
        session.endsAt.difference(session.startsAt).inMinutes - firstMinutes;
    if (firstMinutes < 15 || secondMinutes < 15 || gap.isNegative) {
      issues.add(
        const ScheduleIssue(
          kind: ScheduleIssueKind.invalidDuration,
          message: 'Each split session must be at least 15 minutes.',
        ),
      );
      return _preview(ScheduleOperationType.split, scope, const [], issues);
    }
    final originalStart = session.startsAt.toLocal();
    final firstEnd = originalStart.add(Duration(minutes: firstMinutes));
    final secondStart = firstEnd.add(gap);
    final secondEnd = secondStart.add(Duration(minutes: secondMinutes));
    return _preview(ScheduleOperationType.split, scope, [
      _sessionChange(session, originalStart, firstEnd),
      ScheduleChange(
        targetKind: ScheduleTargetKind.session,
        targetId: newSessionId,
        createSessionId: newSessionId,
        taskId: session.taskId,
        expectedUpdatedAt: session.updatedAt,
        afterStartsAt: secondStart.toUtc(),
        afterEndsAt: secondEnd.toUtc(),
      ),
    ], issues);
  }

  SchedulingPreview repack({
    required List<WorkSession> selected,
    required List<WorkSession> otherSessions,
    required List<FixedEvent> fixedEvents,
    required Map<String, LifeTask> tasksById,
    required AvailabilityPlan availability,
    required DateTime earliest,
    String scope = 'sessions',
    Duration buffer = Duration.zero,
    int horizonDays = 90,
  }) {
    if (buffer.isNegative) throw ArgumentError('Buffer cannot be negative');
    if (horizonDays < 1) throw ArgumentError('Horizon must be positive');
    final ordered = [...selected]..sort(_compareSessions);
    final blocked = <_Interval>[
      ...fixedEvents.map((event) => _Interval(event.startsAt, event.endsAt)),
      ...otherSessions.map(
        (session) => _Interval(session.startsAt, session.endsAt),
      ),
    ];
    final changes = <ScheduleChange>[];
    final issues = <ScheduleIssue>[];
    var cursor = earliest.toLocal();
    final lastDay = DateTime(
      cursor.year,
      cursor.month,
      cursor.day + horizonDays,
    );
    if (availability.weekly.isEmpty && availability.exceptions.isEmpty) {
      issues.add(
        const ScheduleIssue(
          kind: ScheduleIssueKind.noAvailability,
          message:
              'No availability is configured. Add a window before repacking.',
        ),
      );
      return _preview(ScheduleOperationType.repack, scope, changes, issues);
    }
    for (final session in ordered) {
      final task = tasksById[session.taskId];
      if (!_sessionEligibility(session, task, issues)) continue;
      final length = session.endsAt.difference(session.startsAt);
      if (length < const Duration(minutes: 15)) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.invalidDuration,
            targetId: session.id,
            message: 'Session is shorter than the 15-minute minimum.',
          ),
        );
        continue;
      }
      final slot = _findSlot(
        from: cursor,
        length: length,
        blocked: blocked,
        availability: availability,
        buffer: buffer,
        lastDay: lastDay,
      );
      if (slot == null) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.insufficientCapacity,
            targetId: session.id,
            message: 'No free availability within $horizonDays days.',
          ),
        );
        continue;
      }
      if (slot.start.toUtc() != session.startsAt ||
          slot.end.toUtc() != session.endsAt) {
        changes.add(_sessionChange(session, slot.start, slot.end));
      }
      blocked.add(slot);
      cursor = slot.end.toLocal().add(buffer);
      _deadlineIssue(session, task, slot.end.toLocal(), issues);
    }
    return _preview(ScheduleOperationType.repack, scope, changes, issues);
  }

  bool _sessionEligibility(
    WorkSession session,
    LifeTask? task,
    List<ScheduleIssue> issues,
  ) {
    if (session.outcome == SessionOutcome.completed ||
        session.outcome == SessionOutcome.inProgress) {
      issues.add(
        ScheduleIssue(
          kind: ScheduleIssueKind.completed,
          severity: ScheduleIssueSeverity.warning,
          targetId: session.id,
          message: 'Started or completed work session will not be rescheduled.',
        ),
      );
      return false;
    }
    if (task != null && !task.isOpen) {
      issues.add(
        ScheduleIssue(
          kind: ScheduleIssueKind.completed,
          severity: ScheduleIssueSeverity.warning,
          targetId: session.id,
          message: 'The parent task is complete or cancelled.',
        ),
      );
      return false;
    }
    if (task?.schedulingLocked ?? false) {
      issues.add(
        ScheduleIssue(
          kind: ScheduleIssueKind.locked,
          targetId: session.id,
          message: 'The parent task is protected from scheduling changes.',
        ),
      );
      return false;
    }
    return true;
  }

  ScheduleChange _sessionChange(
    WorkSession session,
    DateTime start,
    DateTime end,
  ) => ScheduleChange(
    targetKind: ScheduleTargetKind.session,
    targetId: session.id,
    expectedUpdatedAt: session.updatedAt,
    beforeStartsAt: session.startsAt,
    beforeEndsAt: session.endsAt,
    afterStartsAt: start.toUtc(),
    afterEndsAt: end.toUtc(),
  );

  void _deadlineIssue(
    WorkSession session,
    LifeTask? task,
    DateTime localEnd,
    List<ScheduleIssue> issues,
  ) {
    final deadline = task?.deadlineDate;
    if (deadline == null) return;
    final parsed = DateTime.tryParse(deadline);
    if (parsed == null) return;
    if (localEnd.isAfter(DateTime(parsed.year, parsed.month, parsed.day + 1))) {
      issues.add(
        ScheduleIssue(
          kind: ScheduleIssueKind.deadlineViolation,
          severity: ScheduleIssueSeverity.warning,
          targetId: session.id,
          message: 'Proposed work ends after the task deadline ($deadline).',
        ),
      );
    }
  }

  void _addCollisionIssues(
    String sessionId,
    DateTime start,
    DateTime end,
    List<WorkSession> sessions,
    List<FixedEvent> events,
    List<ScheduleIssue> issues, {
    required bool warningsOnly,
  }) {
    final severity = warningsOnly
        ? ScheduleIssueSeverity.warning
        : ScheduleIssueSeverity.hard;
    for (final event in events) {
      if (_overlaps(start.toUtc(), end.toUtc(), event.startsAt, event.endsAt)) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.fixedEventCollision,
            severity: severity,
            targetId: sessionId,
            message: 'Proposed time overlaps the fixed event “${event.title}”.',
          ),
        );
      }
    }
    for (final other in sessions) {
      if (_overlaps(start.toUtc(), end.toUtc(), other.startsAt, other.endsAt)) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.sessionCollision,
            severity: severity,
            targetId: sessionId,
            message: 'Proposed time overlaps another planned work session.',
          ),
        );
      }
    }
  }

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) => aStart.isBefore(bEnd) && aEnd.isAfter(bStart);

  SchedulingPreview _preview(
    ScheduleOperationType operation,
    String scope,
    List<ScheduleChange> changes,
    List<ScheduleIssue> issues,
  ) => SchedulingPreview(
    operation: operation,
    scope: scope,
    changes: changes,
    issues: issues,
    createdAt: DateTime.now().toUtc(),
  );

  int _compareSessions(WorkSession a, WorkSession b) {
    final byStart = a.startsAt.compareTo(b.startsAt);
    return byStart == 0 ? a.id.compareTo(b.id) : byStart;
  }

  _Interval? _findSlot({
    required DateTime from,
    required Duration length,
    required List<_Interval> blocked,
    required AvailabilityPlan availability,
    required Duration buffer,
    required DateTime lastDay,
  }) {
    var date = DateTime(from.year, from.month, from.day);
    while (date.isBefore(lastDay)) {
      for (final window in availability.windowsFor(date)) {
        final windowStart = _atMinute(date, window.startMinute);
        final windowEnd = _atMinute(date, window.endMinute);
        var candidate = from.isAfter(windowStart) ? from : windowStart;
        while (!candidate.add(length).isAfter(windowEnd)) {
          final end = candidate.add(length);
          _Interval? collision;
          for (final occupied in blocked) {
            if (candidate.isBefore(occupied.end.toLocal().add(buffer)) &&
                end.isAfter(occupied.start.toLocal().subtract(buffer)) &&
                (collision == null || occupied.end.isBefore(collision.end))) {
              collision = occupied;
            }
          }
          if (collision == null) return _Interval(candidate, end);
          final next = collision.end.toLocal().add(buffer);
          candidate = next.isAfter(candidate)
              ? next
              : candidate.add(const Duration(minutes: 1));
        }
      }
      date = DateTime(date.year, date.month, date.day + 1);
      from = date;
    }
    return null;
  }

  DateTime _atMinute(DateTime day, int minute) =>
      DateTime(day.year, day.month, day.day, minute ~/ 60, minute % 60);
}

class _Interval {
  const _Interval(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
