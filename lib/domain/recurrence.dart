import 'models.dart';

enum RecurrenceKind {
  daily,
  weekly,
  weekdays,
  monthly,
  yearly,
  afterCompletion,
}

class RecurrenceSlot {
  const RecurrenceSlot(this.nominalDate, this.ordinal);
  final String nominalDate;
  final int ordinal;
}

/// A date-only rule. Calendar arithmetic uses UTC civil dates so a daylight
/// saving transition cannot shift a nominal occurrence into another day.
class RecurrenceRule {
  RecurrenceRule({
    required this.kind,
    required this.startDate,
    this.interval = 1,
    Set<int> weekdays = const {},
    this.endDate,
    this.maxOccurrences,
  }) : weekdays = Set.unmodifiable(weekdays) {
    _parseDate(startDate);
    if (interval < 1) {
      throw ArgumentError('Recurrence interval must be positive');
    }
    if (endDate != null &&
        _parseDate(endDate!).isBefore(_parseDate(startDate))) {
      throw ArgumentError('Recurrence end is before its start');
    }
    if (maxOccurrences != null && maxOccurrences! < 1) {
      throw ArgumentError('Recurrence count must be positive');
    }
    if (kind == RecurrenceKind.weekdays) {
      if (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7)) {
        throw ArgumentError('Select at least one valid weekday');
      }
      if (!weekdays.contains(_parseDate(startDate).weekday)) {
        throw ArgumentError('The first planned day must be selected');
      }
    } else if (weekdays.isNotEmpty) {
      throw ArgumentError('Weekdays apply only to selected-weekday rules');
    }
  }

  final RecurrenceKind kind;
  final String startDate;
  final int interval;
  final Set<int> weekdays;
  final String? endDate;
  final int? maxOccurrences;

  List<RecurrenceSlot> between(String fromDate, String throughDate) {
    final start = _parseDate(startDate);
    final from = _parseDate(fromDate);
    final through = _parseDate(throughDate);
    if (through.isBefore(from) || kind == RecurrenceKind.afterCompletion) {
      return const [];
    }
    final cap = endDate == null
        ? through
        : (_parseDate(endDate!).isBefore(through)
              ? _parseDate(endDate!)
              : through);
    if (cap.isBefore(start)) {
      return const [];
    }
    final earliest = from.isAfter(start) ? from : start;
    final result = <RecurrenceSlot>[];
    void add(DateTime day, int ordinal) {
      if (day.isBefore(earliest) || day.isAfter(cap)) {
        return;
      }
      if (maxOccurrences != null && ordinal >= maxOccurrences!) {
        return;
      }
      result.add(RecurrenceSlot(localDate(day), ordinal));
    }

    switch (kind) {
      case RecurrenceKind.daily:
        final first = (_daysBetween(start, earliest) / interval).ceil();
        for (var ordinal = first; ; ordinal++) {
          final day = start.add(Duration(days: ordinal * interval));
          if (day.isAfter(cap) ||
              (maxOccurrences != null && ordinal >= maxOccurrences!)) {
            break;
          }
          add(day, ordinal);
        }
      case RecurrenceKind.weekly:
        final first = (_daysBetween(start, earliest) / (7 * interval)).ceil();
        for (var ordinal = first; ; ordinal++) {
          final day = start.add(Duration(days: ordinal * 7 * interval));
          if (day.isAfter(cap) ||
              (maxOccurrences != null && ordinal >= maxOccurrences!)) {
            break;
          }
          add(day, ordinal);
        }
      case RecurrenceKind.weekdays:
        final sorted = weekdays.toList()..sort();
        final monday = start.subtract(Duration(days: start.weekday - 1));
        final firstWeekDays = sorted
            .where((day) => day >= start.weekday)
            .toList();
        final firstActiveWeek =
            (_daysBetween(monday, earliest) / (7 * interval)).floor();
        for (
          var weekIndex = firstActiveWeek < 0 ? 0 : firstActiveWeek;
          ;
          weekIndex++
        ) {
          final week = monday.add(Duration(days: weekIndex * interval * 7));
          if (week.isAfter(cap) ||
              (maxOccurrences != null &&
                  (weekIndex == 0
                          ? 0
                          : firstWeekDays.length +
                                (weekIndex - 1) * sorted.length) >=
                      maxOccurrences!)) {
            break;
          }
          final activeDays = weekIndex == 0 ? firstWeekDays : sorted;
          for (var index = 0; index < activeDays.length; index++) {
            final day = week.add(Duration(days: activeDays[index] - 1));
            final ordinal = weekIndex == 0
                ? index
                : firstWeekDays.length +
                      (weekIndex - 1) * sorted.length +
                      index;
            add(day, ordinal);
          }
        }
      case RecurrenceKind.monthly:
        final monthDelta =
            (earliest.year - start.year) * 12 + earliest.month - start.month;
        var ordinal = monthDelta < 0 ? 0 : monthDelta ~/ interval;
        for (; ; ordinal++) {
          final day = _monthAt(start, ordinal * interval);
          if (day.isAfter(cap) ||
              (maxOccurrences != null && ordinal >= maxOccurrences!)) {
            break;
          }
          add(day, ordinal);
        }
      case RecurrenceKind.yearly:
        var ordinal = earliest.year <= start.year
            ? 0
            : (earliest.year - start.year) ~/ interval;
        for (; ; ordinal++) {
          final year = start.year + ordinal * interval;
          final day = _clampedDate(year, start.month, start.day);
          if (day.isAfter(cap) ||
              (maxOccurrences != null && ordinal >= maxOccurrences!)) {
            break;
          }
          add(day, ordinal);
        }
      case RecurrenceKind.afterCompletion:
        break;
    }
    return result;
  }

  String nextAfterCompletion(String completionLocalDate) {
    if (kind != RecurrenceKind.afterCompletion) {
      throw StateError('This is not a completion-based recurrence');
    }
    final completed = _parseDate(completionLocalDate);
    return localDate(completed.add(Duration(days: interval)));
  }

  static String shiftDate(String value, int days) =>
      localDate(_parseDate(value).add(Duration(days: days)));

  static int daysBetween(String from, String to) =>
      _daysBetween(_parseDate(from), _parseDate(to));

  static DateTime _parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw ArgumentError('Invalid local date: $value');
    }
    final day = DateTime.utc(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
    if (localDate(day) != value) {
      throw ArgumentError('Invalid local date: $value');
    }
    return day;
  }

  static int _daysBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays;

  static DateTime _monthAt(DateTime start, int months) {
    final first = DateTime.utc(start.year, start.month + months);
    return _clampedDate(first.year, first.month, start.day);
  }

  static DateTime _clampedDate(int year, int month, int day) {
    final last = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(year, month, day > last ? last : day);
  }
}
