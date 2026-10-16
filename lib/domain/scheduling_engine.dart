import 'models.dart';

/// Local clock minutes from midnight. Windows are half-open [start, end).
class AvailabilityWindow {
  const AvailabilityWindow(this.startMinute, this.endMinute)
    : assert(startMinute >= 0 && startMinute < endMinute && endMinute <= 1440);

  final int startMinute;
  final int endMinute;
}

class AvailabilityPlan {
  const AvailabilityPlan({required this.weekly, this.exceptions = const {}});

  /// DateTime weekday (Monday = 1) to permitted local-time windows.
  final Map<int, List<AvailabilityWindow>> weekly;

  /// A date override; an empty list means unavailable all day.
  final Map<String, List<AvailabilityWindow>> exceptions;

  List<AvailabilityWindow> windowsFor(DateTime localDay) {
    final windows =
        exceptions[localDate(localDay)] ?? weekly[localDay.weekday] ?? const [];
    return [...windows]..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  }

  static const standard = AvailabilityPlan(
    weekly: {
      1: [AvailabilityWindow(9 * 60, 17 * 60)],
      2: [AvailabilityWindow(9 * 60, 17 * 60)],
      3: [AvailabilityWindow(9 * 60, 17 * 60)],
      4: [AvailabilityWindow(9 * 60, 17 * 60)],
      5: [AvailabilityWindow(9 * 60, 17 * 60)],
    },
  );
}

class ProposedSessionMove {
  const ProposedSessionMove({
    required this.session,
    required this.startsAt,
    required this.endsAt,
  });
  final WorkSession session;
  final DateTime startsAt;
  final DateTime endsAt;
}

enum ScheduleIssueKind { noAvailability, deadlineWarning, invalidDuration }

class ScheduleIssue {
  const ScheduleIssue(this.kind, this.sessionId, this.message);
  final ScheduleIssueKind kind;
  final String sessionId;
  final String message;

  bool get isHard => kind != ScheduleIssueKind.deadlineWarning;
}

class SchedulingPreview {
  const SchedulingPreview({required this.moves, required this.issues});
  final List<ProposedSessionMove> moves;
  final List<ScheduleIssue> issues;
  bool get canApply => issues.every((issue) => !issue.isHard);
}

class SchedulingEngine {
  const SchedulingEngine();

  /// Finds sequential slots for the selected sessions without mutating data.
  /// Existing nonselected sessions and fixed events are treated as protected.
  SchedulingPreview repack({
    required List<WorkSession> selected,
    required List<WorkSession> otherSessions,
    required List<FixedEvent> fixedEvents,
    required Map<String, LifeTask> tasksById,
    required AvailabilityPlan availability,
    required DateTime earliest,
    Duration buffer = Duration.zero,
    int horizonDays = 90,
  }) {
    if (buffer.isNegative) throw ArgumentError('Buffer cannot be negative');
    if (horizonDays < 1) throw ArgumentError('Horizon must be positive');
    final ordered = [...selected]
      ..sort((a, b) {
        final byStart = a.startsAt.compareTo(b.startsAt);
        return byStart == 0 ? a.id.compareTo(b.id) : byStart;
      });
    final blocked = <_Interval>[
      ...fixedEvents.map((event) => _Interval(event.startsAt, event.endsAt)),
      ...otherSessions.map(
        (session) => _Interval(session.startsAt, session.endsAt),
      ),
    ];
    final moves = <ProposedSessionMove>[];
    final issues = <ScheduleIssue>[];
    var cursor = earliest.toLocal();
    final lastDay = DateTime(
      cursor.year,
      cursor.month,
      cursor.day + horizonDays,
    );

    for (final session in ordered) {
      final length = session.endsAt.difference(session.startsAt);
      if (length < const Duration(minutes: 15)) {
        issues.add(
          ScheduleIssue(
            ScheduleIssueKind.invalidDuration,
            session.id,
            'Session is shorter than the 15-minute suggested minimum.',
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
            ScheduleIssueKind.noAvailability,
            session.id,
            'No free availability within $horizonDays days.',
          ),
        );
        continue;
      }
      moves.add(
        ProposedSessionMove(
          session: session,
          startsAt: slot.start.toUtc(),
          endsAt: slot.end.toUtc(),
        ),
      );
      blocked.add(slot);
      cursor = slot.end.toLocal().add(buffer);

      final deadline = tasksById[session.taskId]?.deadlineDate;
      if (deadline != null) {
        final parsed = DateTime.tryParse(deadline);
        if (parsed != null) {
          final dueEnd = DateTime(parsed.year, parsed.month, parsed.day + 1);
          if (slot.end.toLocal().isAfter(dueEnd)) {
            issues.add(
              ScheduleIssue(
                ScheduleIssueKind.deadlineWarning,
                session.id,
                'Proposed work ends after the task deadline ($deadline).',
              ),
            );
          }
        }
      }
    }
    return SchedulingPreview(moves: moves, issues: issues);
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
          final collision = blocked
              .where(
                (occupied) =>
                    candidate.isBefore(occupied.end.add(buffer)) &&
                    end.isAfter(occupied.start.subtract(buffer)),
              )
              .fold<_Interval?>(
                null,
                (earliest, occupied) =>
                    earliest == null || occupied.end.isBefore(earliest.end)
                    ? occupied
                    : earliest,
              );
          if (collision == null) return _Interval(candidate, end);
          final next = collision.end.add(buffer);
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
