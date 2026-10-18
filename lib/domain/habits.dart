import 'models.dart' show localDate;
import 'recurrence.dart';

enum HabitKind { binary, minimum, maximum }

class HabitDraft {
  const HabitDraft({
    required this.title,
    required this.kind,
    required this.rule,
    this.notes = '',
    this.target,
    this.unit = '',
  });

  final String title;
  final String notes;
  final HabitKind kind;
  final double? target;
  final String unit;
  final RecurrenceRule rule;
}

class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.notes,
    required this.kind,
    required this.target,
    required this.unit,
    required this.rule,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String notes;
  final HabitKind kind;
  final double? target;
  final String unit;
  final RecurrenceRule rule;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool succeeds(double value) => switch (kind) {
    HabitKind.binary => value == 1,
    HabitKind.minimum => value >= target!,
    HabitKind.maximum => value <= target!,
  };

  bool scheduledOn(String date) => rule.between(date, date).isNotEmpty;
}

class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.localDate,
    required this.value,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String habitId;
  final String localDate;
  final double value;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class HabitRestDay {
  const HabitRestDay({
    required this.id,
    required this.habitId,
    required this.localDate,
    required this.notes,
  });

  final String id;
  final String habitId;
  final String localDate;
  final String notes;
}

class HabitStatistics {
  const HabitStatistics({
    required this.due,
    required this.successful,
    required this.recorded,
    required this.streak,
  });

  final int due;
  final int successful;
  final int recorded;
  final int streak;
  double get completionRate => due == 0 ? 0 : successful / due;

  static HabitStatistics calculate({
    required Habit habit,
    required Iterable<HabitEntry> entries,
    required Iterable<HabitRestDay> restDays,
    required String fromDate,
    required String throughDate,
    required String today,
  }) {
    final entryByDate = {
      for (final entry in entries.where((item) => item.habitId == habit.id))
        entry.localDate: entry,
    };
    final restDates = {
      for (final rest in restDays.where((item) => item.habitId == habit.id))
        rest.localDate,
    };
    final archiveDay = habit.archivedAt == null
        ? null
        : localDate(habit.archivedAt!.toLocal());
    var cap = throughDate.compareTo(today) > 0 ? today : throughDate;
    if (archiveDay != null && cap.compareTo(archiveDay) > 0) {
      cap = archiveDay;
    }
    final slots = cap.compareTo(fromDate) < 0
        ? <RecurrenceSlot>[]
        : habit.rule.between(fromDate, cap);
    var due = 0;
    var successful = 0;
    var recorded = 0;
    for (final slot in slots) {
      final day = slot.nominalDate;
      if (restDates.contains(day)) continue;
      final entry = entryByDate[day];
      if ((day == today || day == archiveDay) && entry == null) continue;
      due++;
      if (entry != null) {
        recorded++;
        if (habit.succeeds(entry.value)) successful++;
      }
    }
    final all = habit.rule.between(habit.rule.startDate, cap).reversed;
    var streak = 0;
    for (final slot in all) {
      final day = slot.nominalDate;
      if (restDates.contains(day)) continue;
      final entry = entryByDate[day];
      if ((day == today || day == archiveDay) && entry == null) continue;
      if (entry == null || !habit.succeeds(entry.value)) break;
      streak++;
    }
    return HabitStatistics(
      due: due,
      successful: successful,
      recorded: recorded,
      streak: streak,
    );
  }
}
