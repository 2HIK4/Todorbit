enum TimerState { running, paused, stopped }

enum TimeEntrySource { manual, timer }

class TimerRun {
  const TimerRun({
    required this.id,
    required this.taskId,
    required this.state,
    required this.startedAt,
    required this.lastSeenAt,
    required this.updatedAt,
    this.stoppedAt,
  });
  final String id;
  final String? taskId;
  final TimerState state;
  final DateTime startedAt;
  final DateTime lastSeenAt;
  final DateTime updatedAt;
  final DateTime? stoppedAt;
  bool get active => state != TimerState.stopped;
  bool needsReview(DateTime now) =>
      state == TimerState.running &&
      now.toUtc().difference(lastSeenAt).inSeconds > 120;

  TimerRun withLastSeen(DateTime value) => TimerRun(
    id: id,
    taskId: taskId,
    state: state,
    startedAt: startedAt,
    lastSeenAt: value.toUtc(),
    updatedAt: updatedAt,
    stoppedAt: stoppedAt,
  );
}

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.taskId,
    required this.sessionId,
    required this.timerRunId,
    required this.source,
    required this.startsAt,
    required this.endsAt,
    required this.notes,
    required this.updatedAt,
  });
  final String id;
  final String? taskId;
  final String? sessionId;
  final String? timerRunId;
  final TimeEntrySource source;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String notes;
  final DateTime updatedAt;
  Duration durationAt(DateTime now) =>
      (endsAt ?? now.toUtc()).difference(startsAt);

  static Duration distinctDuration(Iterable<TimeEntry> entries, DateTime now) {
    final intervals =
        entries
            .map((entry) => (entry.startsAt, entry.endsAt ?? now.toUtc()))
            .where((pair) => pair.$2.isAfter(pair.$1))
            .toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));
    Duration total = Duration.zero;
    DateTime? start;
    DateTime? end;
    for (final interval in intervals) {
      if (start == null) {
        start = interval.$1;
        end = interval.$2;
      } else if (interval.$1.isAfter(end!)) {
        total += end.difference(start);
        start = interval.$1;
        end = interval.$2;
      } else if (interval.$2.isAfter(end)) {
        end = interval.$2;
      }
    }
    if (start != null) total += end!.difference(start);
    return total;
  }
}
