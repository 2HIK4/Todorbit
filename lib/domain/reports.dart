import 'models.dart';
import 'habits.dart';
import 'goals.dart';
import 'recurrence.dart';
import 'time_tracking.dart';

class ReportDay {
  const ReportDay({
    required this.date,
    required this.created,
    required this.completed,
    required this.planned,
    required this.work,
  });
  final String date;
  final int created;
  final int completed;
  final int planned;
  final Duration work;
}

class ProjectCompletion {
  const ProjectCompletion(this.projectId, this.completed);
  final String? projectId;
  final int completed;
}

class StatisticsReport {
  const StatisticsReport({
    required this.fromDate,
    required this.throughDate,
    required this.days,
    required this.completed,
    required this.created,
    required this.planned,
    required this.work,
    required this.habitDue,
    required this.habitSuccess,
    required this.habitRecorded,
    required this.currentGoals,
    required this.currentCompletedGoals,
    required this.projects,
  });

  final String fromDate;
  final String throughDate;
  final List<ReportDay> days;
  final int completed;
  final int created;
  final int planned;
  final Duration work;
  final int habitDue;
  final int habitSuccess;
  final int habitRecorded;
  final int currentGoals;
  final int currentCompletedGoals;
  final List<ProjectCompletion> projects;

  static StatisticsReport calculate({
    required Iterable<LifeTask> tasks,
    required Iterable<TimeEntry> timeEntries,
    required Iterable<Habit> habits,
    required Iterable<HabitEntry> habitEntries,
    required Iterable<HabitRestDay> restDays,
    required Iterable<Goal> goals,
    TimerRun? activeTimer,
    required String fromDate,
    required String throughDate,
    required DateTime now,
  }) {
    final span = RecurrenceRule.daysBetween(fromDate, throughDate);
    if (span < 0 || span > 365) {
      throw ArgumentError('Report range must contain 1 to 366 days');
    }
    final taskList = tasks.toList();
    final taskIds = taskList.map((task) => task.id).toSet();
    final created = <String, int>{};
    final completed = <String, int>{};
    final planned = <String, int>{};
    final projects = <String?, int>{};
    bool within(String day) =>
        day.compareTo(fromDate) >= 0 && day.compareTo(throughDate) <= 0;
    for (final task in taskList) {
      final createdDay = localDate(task.createdAt.toLocal());
      if (within(createdDay)) {
        created.update(createdDay, (count) => count + 1, ifAbsent: () => 1);
      }
      final completedAt = task.completedAt;
      if (task.status == TaskStatus.completed && completedAt != null) {
        final completedDay = localDate(completedAt.toLocal());
        if (within(completedDay)) {
          completed.update(
            completedDay,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
          projects.update(
            task.projectId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      final plannedDay = task.scheduledDate;
      if (plannedDay != null && within(plannedDay)) {
        planned.update(plannedDay, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    final confirmedNow = now.toUtc();
    final entries = timeEntries
        .where((entry) => taskIds.contains(entry.taskId))
        .toList();
    final workByDay = <String, Duration>{};
    final days = <ReportDay>[];
    for (var offset = 0; offset <= span; offset++) {
      final date = RecurrenceRule.shiftDate(fromDate, offset);
      final day = DateTime.parse(date);
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      final intervals = <(DateTime, DateTime)>[];
      for (final entry in entries) {
        final rawEnd =
            entry.endsAt ??
            (activeTimer?.id == entry.timerRunId &&
                    activeTimer!.needsReview(now)
                ? activeTimer.lastSeenAt
                : confirmedNow);
        final entryEnd = rawEnd.isAfter(confirmedNow) ? confirmedNow : rawEnd;
        final clippedStart = entry.startsAt.isBefore(start)
            ? start
            : entry.startsAt;
        final clippedEnd = entryEnd.isAfter(end) ? end : entryEnd;
        if (clippedEnd.isAfter(clippedStart)) {
          intervals.add((clippedStart, clippedEnd));
        }
      }
      final work = _union(intervals);
      workByDay[date] = work;
      days.add(
        ReportDay(
          date: date,
          created: created[date] ?? 0,
          completed: completed[date] ?? 0,
          planned: planned[date] ?? 0,
          work: work,
        ),
      );
    }

    final today = localDate(now.toLocal());
    var habitDue = 0;
    var habitSuccess = 0;
    var habitRecorded = 0;
    for (final habit in habits) {
      final stats = HabitStatistics.calculate(
        habit: habit,
        entries: habitEntries,
        restDays: restDays,
        fromDate: fromDate,
        throughDate: throughDate,
        today: today,
      );
      habitDue += stats.due;
      habitSuccess += stats.successful;
      habitRecorded += stats.recorded;
    }
    final currentGoals = goals.where((goal) => !goal.archived).toList();
    return StatisticsReport(
      fromDate: fromDate,
      throughDate: throughDate,
      days: days,
      completed: completed.values.fold(0, (sum, count) => sum + count),
      created: created.values.fold(0, (sum, count) => sum + count),
      planned: planned.values.fold(0, (sum, count) => sum + count),
      work: workByDay.values.fold(
        Duration.zero,
        (sum, duration) => sum + duration,
      ),
      habitDue: habitDue,
      habitSuccess: habitSuccess,
      habitRecorded: habitRecorded,
      currentGoals: currentGoals.length,
      currentCompletedGoals: currentGoals
          .where((goal) => goal.completed)
          .length,
      projects: [
        for (final entry in projects.entries)
          ProjectCompletion(entry.key, entry.value),
      ]..sort((a, b) => b.completed.compareTo(a.completed)),
    );
  }

  static Duration _union(List<(DateTime, DateTime)> intervals) {
    if (intervals.isEmpty) return Duration.zero;
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    var start = intervals.first.$1;
    var end = intervals.first.$2;
    var total = Duration.zero;
    for (final interval in intervals.skip(1)) {
      if (interval.$1.isAfter(end)) {
        total += end.difference(start);
        start = interval.$1;
        end = interval.$2;
      } else if (interval.$2.isAfter(end)) {
        end = interval.$2;
      }
    }
    return total + end.difference(start);
  }
}
