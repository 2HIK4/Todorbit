import 'models.dart';
import 'recurrence.dart';

enum ScheduledFilter { any, today, nextSevenDays, future, unscheduled }

enum DeadlineFilter { any, overdue, nextSevenDays, noDeadline }

enum SavedViewSort { scheduled, priority, title, created }

class TaskFilter {
  const TaskFilter({
    this.text = '',
    this.statuses = const {},
    this.categoryId,
    this.projectId,
    this.categoryIds = const {},
    this.projectIds = const {},
    this.priorities = const {},
    this.minimumPriority = 0,
    this.scheduled = ScheduledFilter.any,
    this.deadline = DeadlineFilter.any,
    this.recurringOnly = false,
    this.nonRecurringOnly = false,
    this.fromDate,
    this.throughDate,
    this.blockedOnly = false,
    this.sort = SavedViewSort.scheduled,
    this.iconKey,
  });
  final String text;
  final Set<TaskStatus> statuses;
  final String? categoryId;
  final String? projectId;
  final Set<String> categoryIds;
  final Set<String> projectIds;
  final Set<int> priorities;
  final int minimumPriority;
  final ScheduledFilter scheduled;
  final DeadlineFilter deadline;
  final bool recurringOnly;
  final bool nonRecurringOnly;
  final String? fromDate, throughDate;
  final String? iconKey;

  bool get isActive =>
      text.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      categoryIds.isNotEmpty ||
      categoryId != null ||
      projectIds.isNotEmpty ||
      projectId != null ||
      priorities.isNotEmpty ||
      minimumPriority > 0 ||
      scheduled != ScheduledFilter.any ||
      deadline != DeadlineFilter.any ||
      recurringOnly ||
      nonRecurringOnly ||
      blockedOnly ||
      fromDate != null ||
      throughDate != null;

  TaskFilter change(Map<String, dynamic> changes) =>
      TaskFilter.fromJson({...toJson(), ...changes});

  bool matchesEvent(
    FixedEvent event, {
    Map<String, Category> categories = const {},
    Map<String, Project> projects = const {},
  }) {
    final effectiveCategoryIds = categoryIds.isNotEmpty
        ? categoryIds
        : (categoryId != null ? {categoryId!} : const <String>{});
    if (effectiveCategoryIds.isNotEmpty &&
        (event.categoryId == null ||
            !effectiveCategoryIds.contains(event.categoryId))) {
      return false;
    }
    final effectiveProjectIds = projectIds.isNotEmpty
        ? projectIds
        : (projectId != null ? {projectId!} : const <String>{});
    if (effectiveProjectIds.isNotEmpty &&
        (event.projectId == null ||
            !effectiveProjectIds.contains(event.projectId))) {
      return false;
    }
    return (!recurringOnly || event.repeat != null) &&
        (!nonRecurringOnly || event.repeat == null) &&
        (fromDate == null ||
            event.endsAt.toLocal().isAfter(DateTime.parse(fromDate!))) &&
        (throughDate == null ||
            event.startsAt.toLocal().isBefore(
              DateTime.parse(RecurrenceRule.shiftDate(throughDate!, 1)),
            )) &&
        (text.trim().isEmpty ||
            '${event.title} ${event.notes} ${categories[event.categoryId]?.name ?? ''} ${projects[event.projectId]?.name ?? ''}'
                .toLowerCase()
                .contains(text.trim().toLowerCase()));
  }
  final bool blockedOnly;
  final SavedViewSort sort;

  bool matches(
    LifeTask task,
    DateTime now, {
    required Map<String, Category> categories,
    required Map<String, Project> projects,
    required Set<String> blockedTaskIds,
  }) {
    if (statuses.isNotEmpty && !statuses.contains(task.status)) return false;

    final effectiveCategoryIds = categoryIds.isNotEmpty
        ? categoryIds
        : (categoryId != null ? {categoryId!} : const <String>{});
    if (effectiveCategoryIds.isNotEmpty &&
        (task.categoryId == null ||
            !effectiveCategoryIds.contains(task.categoryId))) {
      return false;
    }

    final effectiveProjectIds = projectIds.isNotEmpty
        ? projectIds
        : (projectId != null ? {projectId!} : const <String>{});
    if (effectiveProjectIds.isNotEmpty &&
        (task.projectId == null ||
            !effectiveProjectIds.contains(task.projectId))) {
      return false;
    }

    if (priorities.isNotEmpty) {
      if (!priorities.contains(task.priority)) return false;
    } else if (task.priority < minimumPriority) {
      return false;
    }
    if (recurringOnly && task.recurrenceSeriesId == null) return false;
    if (nonRecurringOnly && task.recurrenceSeriesId != null) return false;
    if (fromDate != null &&
        (task.scheduledDate == null ||
            task.scheduledDate!.compareTo(fromDate!) < 0)) {
      return false;
    }
    if (throughDate != null &&
        (task.scheduledDate == null ||
            task.scheduledDate!.compareTo(throughDate!) > 0)) {
      return false;
    }
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
    'category_ids': categoryIds.toList(),
    'project_ids': projectIds.toList(),
    'priorities': priorities.toList(),
    'minimum_priority': minimumPriority,
    'scheduled': scheduled.name,
    'deadline': deadline.name,
    'recurring_only': recurringOnly,
    'non_recurring_only': nonRecurringOnly,
    'from_date': fromDate,
    'through_date': throughDate,
    'blocked_only': blockedOnly,
    'sort': sort.name,
    if (iconKey != null) 'icon_key': iconKey,
  };

  factory TaskFilter.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw StateError('Unsupported saved view format');
    for (final field in ['from_date', 'through_date']) {
      final value = json[field];
      if (value != null &&
          (value is! String ||
              DateTime.tryParse(value) == null ||
              localDate(DateTime.parse(value)) != value)) {
        throw const FormatException('Invalid filter date');
      }
    }
    if (json['from_date'] != null &&
        json['through_date'] != null &&
        (json['from_date'] as String).compareTo(
              json['through_date'] as String,
            ) >
            0) {
      throw const FormatException('Filter end must follow start');
    }

    final legacyCatId = json['category_id'] as String?;
    final legacyProjId = json['project_id'] as String?;
    final catIds = (json['category_ids'] as List?)?.cast<String>().toSet() ??
        (legacyCatId != null ? {legacyCatId} : const <String>{});
    final projIds = (json['project_ids'] as List?)?.cast<String>().toSet() ??
        (legacyProjId != null ? {legacyProjId} : const <String>{});
    final legacyMinPriority = (json['minimum_priority'] as int?) ?? 0;
    final priorities = (json['priorities'] as List?)?.cast<int>().toSet() ??
        (legacyMinPriority > 0
            ? {for (var i = legacyMinPriority; i <= 3; i++) i}
            : const <int>{});

    return TaskFilter(
      text: json['text'] as String,
      statuses: (json['statuses'] as List)
          .map((item) => TaskStatus.values.byName(item as String))
          .toSet(),
      categoryId: legacyCatId,
      projectId: legacyProjId,
      categoryIds: catIds,
      projectIds: projIds,
      priorities: priorities,
      minimumPriority: legacyMinPriority,
      scheduled: ScheduledFilter.values.byName(json['scheduled'] as String),
      deadline: DeadlineFilter.values.byName(json['deadline'] as String),
      recurringOnly: json['recurring_only'] as bool,
      nonRecurringOnly: json['non_recurring_only'] == true,
      fromDate: json['from_date'] as String?,
      throughDate: json['through_date'] as String?,
      blockedOnly: json['blocked_only'] as bool,
      sort: SavedViewSort.values.byName(
        json['sort'] as String? ?? SavedViewSort.scheduled.name,
      ),
      iconKey: json['icon_key'] as String?,
    );
  }
}

class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.filter,
    required this.updatedAt,
    this.iconKey,
  });
  final String id;
  final String name;
  final TaskFilter filter;
  final DateTime updatedAt;
  final String? iconKey;

  SavedView copyWith({
    String? name,
    TaskFilter? filter,
    DateTime? updatedAt,
    String? iconKey,
  }) => SavedView(
    id: id,
    name: name ?? this.name,
    filter: filter ?? this.filter,
    updatedAt: updatedAt ?? this.updatedAt,
    iconKey: iconKey ?? this.iconKey,
  );
}
