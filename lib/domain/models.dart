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
