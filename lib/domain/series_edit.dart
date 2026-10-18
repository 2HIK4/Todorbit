import 'models.dart';
import 'recurrence.dart';

enum SeriesEditScope { thisAndFuture, entireSeries }

enum SeriesCollisionChoice { keepBoth, skipNew, combine }

enum SeriesImpactKind { preserve, exclude, create, collision }

class SeriesEditImpact {
  const SeriesEditImpact({
    required this.nominalDate,
    required this.kind,
    this.taskId,
    required this.reason,
  });

  final String nominalDate;
  final SeriesImpactKind kind;
  final String? taskId;
  final String reason;
}

class SeriesCollision {
  const SeriesCollision({
    required this.nominalDate,
    required this.existingTaskIds,
    required this.canCombine,
  });

  final String nominalDate;
  final List<String> existingTaskIds;
  final bool canCombine;
}

class SeriesScheduleCollision {
  const SeriesScheduleCollision({
    required this.movedTaskId,
    required this.plannedDate,
    required this.existingTaskIds,
    required this.canSkipMoved,
  });

  final String movedTaskId;
  final String plannedDate;
  final List<String> existingTaskIds;
  final bool canSkipMoved;
}

/// A reviewed, non-writing proposal. Apply re-reads the complete snapshot in
/// one transaction; any changed task, link, or series version rejects it.
class SeriesEditPreview {
  const SeriesEditPreview({
    required this.sourceTaskId,
    required this.familyId,
    required this.scope,
    required this.effectiveDate,
    required this.windowThrough,
    required this.draft,
    required this.rule,
    required this.impacts,
    required this.collisions,
    required this.snapshot,
  });

  final String sourceTaskId;
  final String familyId;
  final SeriesEditScope scope;
  final String effectiveDate;
  final String windowThrough;
  final TaskDraft draft;
  final RecurrenceRule rule;
  final List<SeriesEditImpact> impacts;
  final List<SeriesCollision> collisions;
  final String snapshot;
}

class RecurrenceDefinition {
  const RecurrenceDefinition({required this.rule, required this.template});
  final RecurrenceRule rule;
  final TaskDraft template;
}
