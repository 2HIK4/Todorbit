enum TaskStatus {
  notStarted,
  inProgress,
  waiting,
  onHold,
  completed,
  cancelled,
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  final String id;
  final String name;
  final DateTime createdAt;
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

class FixedEvent {
  const FixedEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final String notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class EventDraft {
  const EventDraft({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.notes = '',
  });
  final String title;
  final String notes;
  final DateTime startsAt;
  final DateTime endsAt;
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
    this.categoryId,
    this.projectId,
    this.scheduledDate,
    this.deadlineDate,
    this.completedAt,
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
  final DateTime? completedAt;

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
  });

  final String title;
  final String notes;
  final TaskStatus status;
  final int priority;
  final String? categoryId;
  final String? projectId;
  final String? scheduledDate;
  final String? deadlineDate;
}

String localDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
