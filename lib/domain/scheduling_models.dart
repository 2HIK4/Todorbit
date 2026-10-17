import 'models.dart';

enum ScheduleOperationType {
  move,
  shift,
  push,
  pull,
  swap,
  reorder,
  repack,
  split,
  restorePrevious,
  restoreOriginal,
  undo,
}

enum ScheduleTargetKind { task, session }

enum ScheduleChangeSource { manual, smartReschedule }

enum ScheduleIssueSeverity { warning, hard }

enum ScheduleIssueKind {
  noAvailability,
  deadlineViolation,
  invalidDuration,
  fixedEventCollision,
  sessionCollision,
  locked,
  completed,
  stale,
  insufficientCapacity,
  invalidSelection,
}

class AvailabilityWindow {
  const AvailabilityWindow(this.startMinute, this.endMinute)
    : assert(startMinute >= 0 && startMinute < endMinute && endMinute <= 1440);

  final int startMinute;
  final int endMinute;
}

class AvailabilityPlan {
  const AvailabilityPlan({required this.weekly, this.exceptions = const {}});

  final Map<int, List<AvailabilityWindow>> weekly;
  final Map<String, List<AvailabilityWindow>> exceptions;

  bool get isEmpty =>
      weekly.values.every((value) => value.isEmpty) &&
      exceptions.values.every((value) => value.isEmpty);

  List<AvailabilityWindow> windowsFor(DateTime localDay) {
    final windows =
        exceptions[localDate(localDay)] ?? weekly[localDay.weekday] ?? const [];
    return [...windows]..sort((a, b) => a.startMinute.compareTo(b.startMinute));
  }
}

class ScheduleIssue {
  const ScheduleIssue({
    required this.kind,
    required this.message,
    this.targetId,
    this.severity = ScheduleIssueSeverity.hard,
  });

  final ScheduleIssueKind kind;
  final ScheduleIssueSeverity severity;
  final String? targetId;
  final String message;
  bool get isHard => severity == ScheduleIssueSeverity.hard;
}

class ScheduleChange {
  const ScheduleChange({
    required this.targetKind,
    required this.targetId,
    required this.expectedUpdatedAt,
    this.beforeDate,
    this.afterDate,
    this.beforeStartsAt,
    this.beforeEndsAt,
    this.afterStartsAt,
    this.afterEndsAt,
    this.createSessionId,
    this.taskId,
    this.deleteSession = false,
  });

  final ScheduleTargetKind targetKind;
  final String targetId;
  final DateTime expectedUpdatedAt;
  final String? beforeDate;
  final String? afterDate;
  final DateTime? beforeStartsAt;
  final DateTime? beforeEndsAt;
  final DateTime? afterStartsAt;
  final DateTime? afterEndsAt;

  /// Non-null only for a split-generated session that does not exist yet.
  final String? createSessionId;
  final String? taskId;
  final bool deleteSession;

  bool get createsSession => createSessionId != null;
}

class SchedulingPreview {
  const SchedulingPreview({
    required this.operation,
    required this.scope,
    required this.changes,
    required this.issues,
    required this.createdAt,
  });

  final ScheduleOperationType operation;
  final String scope;
  final List<ScheduleChange> changes;
  final List<ScheduleIssue> issues;
  final DateTime createdAt;
  bool get canApply =>
      changes.isNotEmpty && issues.every((issue) => !issue.isHard);

  SchedulingPreview including(Set<String> targetIds) => SchedulingPreview(
    operation: operation,
    scope: scope,
    changes: changes
        .where((change) => targetIds.contains(change.targetId))
        .toList(),
    issues: issues
        .where(
          (issue) =>
              issue.targetId == null || targetIds.contains(issue.targetId),
        )
        .toList(),
    createdAt: createdAt,
  );
}

class SchedulingOperation {
  const SchedulingOperation({
    required this.id,
    required this.type,
    required this.source,
    required this.scope,
    required this.createdAt,
    required this.changes,
    this.revertsOperationId,
  });

  final String id;
  final ScheduleOperationType type;
  final ScheduleChangeSource source;
  final String scope;
  final DateTime createdAt;
  final List<ScheduleHistoryChange> changes;
  final String? revertsOperationId;
}

class ScheduleHistoryChange {
  const ScheduleHistoryChange({
    required this.targetKind,
    required this.targetId,
    this.beforeDate,
    this.afterDate,
    this.beforeStartsAt,
    this.beforeEndsAt,
    this.afterStartsAt,
    this.afterEndsAt,
    this.beforeUpdatedAt,
    this.afterUpdatedAt,
  });

  final ScheduleTargetKind targetKind;
  final String targetId;
  final String? beforeDate;
  final String? afterDate;
  final DateTime? beforeStartsAt;
  final DateTime? beforeEndsAt;
  final DateTime? afterStartsAt;
  final DateTime? afterEndsAt;
  final DateTime? beforeUpdatedAt;
  final DateTime? afterUpdatedAt;
}

class StaleSchedulePreviewException implements Exception {
  const StaleSchedulePreviewException(this.targetIds);
  final List<String> targetIds;

  @override
  String toString() =>
      'Schedule changed since preview for: ${targetIds.join(', ')}. Generate a new preview.';
}
