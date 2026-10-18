import 'models.dart';
import 'recurrence.dart';

enum ScheduledFilter { any, today, nextSevenDays, future, unscheduled }

enum DeadlineFilter { any, overdue, nextSevenDays, noDeadline }

class TaskFilter {
  const TaskFilter({
    this.text = '',
    this.statuses = const {},
    this.categoryId,
    this.projectId,
    this.minimumPriority = 0,
    this.scheduled = ScheduledFilter.any,
    this.deadline = DeadlineFilter.any,
    this.recurringOnly = false,
    this.blockedOnly = false,
  });
  final String text;
  final Set<TaskStatus> statuses;
  final String? categoryId;
  final String? projectId;
  final int minimumPriority;
  final ScheduledFilter scheduled;
  final DeadlineFilter deadline;
  final bool recurringOnly;
  final bool blockedOnly;

  bool matches(
    LifeTask task,
    DateTime now, {
    required Map<String, Category> categories,
    required Map<String, Project> projects,
    required Set<String> blockedTaskIds,
  }) {
    if (statuses.isNotEmpty && !statuses.contains(task.status)) return false;
    if (categoryId != null && task.categoryId != categoryId) return false;
    if (projectId != null && task.projectId != projectId) return false;
    if (task.priority < minimumPriority) return false;
    if (recurringOnly && task.recurrenceSeriesId == null) return false;
    if (blockedOnly && !blockedTaskIds.contains(task.id)) return false;
    final needle = text.trim().toLowerCase();
    if (needle.isNotEmpty) {
      final searchable = [
        task.title,
        task.notes,
        categories[task.categoryId]?.name ?? '',
        projects[task.projectId]?.name ?? '',
      ].join(' ').toLowerCase();
      if (!searchable.contains(needle)) return false;
    }
    final today = localDate(now);
    final nextWeek = RecurrenceRule.shiftDate(today, 7);
    switch (scheduled) {
      case ScheduledFilter.any:
        break;
      case ScheduledFilter.today:
        if (task.scheduledDate != today) return false;
      case ScheduledFilter.nextSevenDays:
        if (task.scheduledDate == null ||
            task.scheduledDate!.compareTo(today) < 0 ||
            task.scheduledDate!.compareTo(nextWeek) > 0) {
          return false;
        }
      case ScheduledFilter.future:
        if (task.scheduledDate == null ||
            task.scheduledDate!.compareTo(today) <= 0) {
          return false;
        }
      case ScheduledFilter.unscheduled:
        if (task.scheduledDate != null) return false;
    }
    switch (deadline) {
      case DeadlineFilter.any:
        break;
      case DeadlineFilter.overdue:
        if (task.deadlineDate == null ||
            task.deadlineDate!.compareTo(today) >= 0 ||
            !task.isOpen) {
          return false;
        }
      case DeadlineFilter.nextSevenDays:
        if (task.deadlineDate == null ||
            task.deadlineDate!.compareTo(today) < 0 ||
            task.deadlineDate!.compareTo(nextWeek) > 0 ||
            !task.isOpen) {
          return false;
        }
      case DeadlineFilter.noDeadline:
        if (task.deadlineDate != null) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'text': text.trim(),
    'statuses': statuses.map((item) => item.name).toList(),
    'category_id': categoryId,
    'project_id': projectId,
    'minimum_priority': minimumPriority,
    'scheduled': scheduled.name,
    'deadline': deadline.name,
    'recurring_only': recurringOnly,
    'blocked_only': blockedOnly,
  };

  factory TaskFilter.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw StateError('Unsupported saved view format');
    return TaskFilter(
      text: json['text'] as String,
      statuses: (json['statuses'] as List)
          .map((item) => TaskStatus.values.byName(item as String))
          .toSet(),
      categoryId: json['category_id'] as String?,
      projectId: json['project_id'] as String?,
      minimumPriority: json['minimum_priority'] as int,
      scheduled: ScheduledFilter.values.byName(json['scheduled'] as String),
      deadline: DeadlineFilter.values.byName(json['deadline'] as String),
      recurringOnly: json['recurring_only'] as bool,
      blockedOnly: json['blocked_only'] as bool,
    );
  }
}

class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.filter,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final TaskFilter filter;
  final DateTime updatedAt;
}
