class GoalDraft {
  const GoalDraft({
    required this.title,
    required this.target,
    required this.startDate,
    this.description = '',
    this.unit = '',
    this.deadlineDate,
  });
  final String title;
  final String description;
  final double target;
  final String unit;
  final String startDate;
  final String? deadlineDate;
}

class GoalProgress {
  const GoalProgress({
    required this.manual,
    required this.tasks,
    required this.habits,
  });
  final double manual;
  final double tasks;
  final double habits;
  double get total => manual + tasks + habits;
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.unit,
    required this.startDate,
    required this.deadlineDate,
    required this.createdAt,
    required this.updatedAt,
    required this.progress,
    this.completedAt,
    this.archivedAt,
  });
  final String id;
  final String title;
  final String description;
  final double target;
  final String unit;
  final String startDate;
  final String? deadlineDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;
  final GoalProgress progress;
  bool get completed => completedAt != null;
  bool get archived => archivedAt != null;
  double get fraction => (progress.total / target).clamp(0, 1);
}

class GoalMilestone {
  const GoalMilestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.threshold,
    required this.deadlineDate,
    required this.updatedAt,
    this.completedAt,
  });
  final String id;
  final String goalId;
  final String title;
  final double threshold;
  final String? deadlineDate;
  final DateTime updatedAt;
  final DateTime? completedAt;
}

class GoalProgressEntry {
  const GoalProgressEntry({
    required this.id,
    required this.goalId,
    required this.delta,
    required this.notes,
    required this.createdAt,
  });
  final String id;
  final String goalId;
  final double delta;
  final String notes;
  final DateTime createdAt;
}

class GoalLinkedEvent {
  const GoalLinkedEvent({
    required this.sourceId,
    required this.label,
    required this.localDate,
    required this.units,
  });
  final String sourceId;
  final String label;
  final String localDate;
  final double units;
}

class GoalLinks {
  const GoalLinks({
    required this.taskIds,
    required this.projectIds,
    required this.habitIds,
  });
  final Set<String> taskIds;
  final Set<String> projectIds;
  final Set<String> habitIds;
}
