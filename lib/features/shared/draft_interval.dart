// Calculates an end when moving a whole draft interval. Callers keep explicitly
// edited ends fixed; this assistance never changes a persisted record.
DateTime endAfterMovingStart({
  required DateTime start,
  required DateTime end,
  required DateTime nextStart,
  bool allDay = false,
}) {
  if (allDay) {
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return DateTime(
      nextStart.year,
      nextStart.month,
      nextStart.day + (days > 0 ? days : 1),
    );
  }
  final duration = end.difference(start);
  return nextStart.add(
    duration > Duration.zero ? duration : const Duration(hours: 1),
  );
}
