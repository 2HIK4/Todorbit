import 'notifications.dart';

enum TaskStatus {
  notStarted,
  inProgress,
  waiting,
  onHold,
  completed,
  cancelled,
}

enum CalendarContent { both, eventsOnly, tasksOnly }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.createdAt,
    this.eventColor,
  });
  final String id;
  final String name;
  final DateTime createdAt;
  final int? eventColor;
}

class Project {
  const Project({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.createdAt,
  });
  final String id;
  final String categoryId;
  final String name;
  final DateTime createdAt;
}

class TaskSequence {
  const TaskSequence({
    required this.id,
    required this.name,
    required this.taskIds,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final List<String> taskIds;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TaskDependency {
  const TaskDependency({required this.taskId, required this.prerequisiteId});
  final String taskId;
  final String prerequisiteId;
}

class FixedEvent {
  const FixedEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.updatedAt,
    this.location = '',
    this.allDay = false,
    this.categoryId,
    this.colorValue,
    this.iconName,
    this.reminderMinutes,
    this.repeat,
    this.nominalDate,
    this.cancelled = false,
    this.activeFromDate,
    this.activeThroughDate,
    this.seriesFamilyId,
    this.details = const [],
  });
  final String id;
  final String title;
  final String notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String location;
  final bool allDay;
  final String? categoryId;
  final int? colorValue;
  final String? iconName;
  final int? reminderMinutes;
  final EventRepeat? repeat;

  /// Original local day of a projected recurring occurrence.
  final String? nominalDate;
  final bool cancelled;
  final String? activeFromDate;
  final String? activeThroughDate;
  final String? seriesFamilyId;
  final List<EventDetail> details;
}

class EventDetail {
  const EventDetail({
    required this.typeId,
    required this.label,
    required this.value,
  });
  final String typeId;
  final String label;
  final String value;

  Map<String, String> toJson() => {
    'typeId': typeId,
    'label': label,
    'value': value,
  };

  factory EventDetail.fromJson(Object? source) {
    if (source case {
      'typeId': String typeId,
      'label': String label,
      'value': String value,
    }) {
      return EventDetail(typeId: typeId, label: label, value: value);
    }
    throw const FormatException('Invalid event detail');
  }
}

class EventDetailType {
  const EventDetailType({required this.id, required this.name});
  final String id;
  final String name;
}

enum EventRepeatKind { daily, weekly, weekdays, monthly, yearly }

class EventRepeat {
  const EventRepeat({
    required this.kind,
    this.interval = 1,
    this.weekdays = const {},
    this.untilDate,
  });
  final EventRepeatKind kind;
  final int interval;
  final Set<int> weekdays;
  final String? untilDate;
}

class EventDraft {
  const EventDraft({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.notes = '',
    this.location = '',
    this.allDay = false,
    this.categoryId,
    this.colorValue,
    this.iconName,
    this.reminderMinutes,
    this.repeat,
    this.details = const [],
  });
  final String title;
  final String notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final String location;
  final bool allDay;
  final String? categoryId;
  final int? colorValue;
  final String? iconName;
  final int? reminderMinutes;
  final EventRepeat? repeat;
  final List<EventDetail> details;
}

enum SessionOutcome {
  upcoming,
  inProgress,
  completed,
  partial,
  missed,
  skipped,
}

class WorkSession {
  const WorkSession({
    required this.id,
    required this.taskId,
    required this.startsAt,
    required this.endsAt,
    required this.outcome,
    required this.createdAt,
    required this.updatedAt,
    this.actualStartedAt,
  });
  final String id;
  final String taskId;
  final DateTime startsAt;
  final DateTime endsAt;
  final SessionOutcome outcome;
  final DateTime? actualStartedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get needsConfirmation =>
      outcome == SessionOutcome.upcoming && endsAt.isBefore(DateTime.now());
  bool get lateStart =>
      outcome == SessionOutcome.upcoming &&
      actualStartedAt == null &&
      startsAt.isBefore(DateTime.now()) &&
      !needsConfirmation;
}

class SessionDraft {
  const SessionDraft({
    required this.taskId,
    required this.startsAt,
    required this.endsAt,
    this.outcome = SessionOutcome.upcoming,
  });
  final String taskId;
  final DateTime startsAt;
  final DateTime endsAt;
  final SessionOutcome outcome;
}

class LifeTask {
  const LifeTask({
    required this.id,
    required this.title,
    required this.notes,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.storedRevision,
    this.categoryId,
    this.projectId,
    this.scheduledDate,
    this.deadlineDate,
    this.completedAt,
    this.plannedDurationMinutes,
    this.remainingWorkMinutes,
    this.schedulingLocked = false,
    this.recurrenceSeriesId,
    this.recurrenceOrdinal,
    this.nominalDate,
    this.recurrenceDisposition,
    this.recurrenceEdited = false,
    this.recurrenceRescheduled = false,
    this.recurrenceKindName,
    this.notification = const TaskNotification(),
  });

  final String id;
  final String title;
  final String notes;
  final TaskStatus status;
  final int priority;
  final String? categoryId;
  final String? projectId;
  final String? scheduledDate;
  final String? deadlineDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Preserve the exact SQLite token (including legacy native fractional format).
  final String? storedRevision;
  String get revision => storedRevision ?? updatedAt.toUtc().toIso8601String();
  final DateTime? completedAt;
  final int? plannedDurationMinutes;
  final int? remainingWorkMinutes;
  final bool schedulingLocked;
  final String? recurrenceSeriesId;
  final int? recurrenceOrdinal;
  final String? nominalDate;
  final String? recurrenceDisposition;
  final bool recurrenceEdited;
  final bool recurrenceRescheduled;
  final String? recurrenceKindName;
  final TaskNotification notification;

  bool get isOpen =>
      status != TaskStatus.completed && status != TaskStatus.cancelled;
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    this.notes = '',
    this.status = TaskStatus.notStarted,
    this.priority = 0,
    this.categoryId,
    this.projectId,
    this.scheduledDate,
    this.deadlineDate,
    this.plannedDurationMinutes,
    this.remainingWorkMinutes,
    this.schedulingLocked = false,
    this.notification,
  });

  final String title;
  final String notes;
  final TaskStatus status;
  final int priority;
  final String? categoryId;
  final String? projectId;
  final String? scheduledDate;
  final String? deadlineDate;
  final int? plannedDurationMinutes;
  final int? remainingWorkMinutes;
  final bool schedulingLocked;
  final TaskNotification? notification;
}

String localDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
