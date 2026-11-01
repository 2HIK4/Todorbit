import 'causal_record.dart';

import 'dart:convert';

const _coupledFields = <String, List<Set<String>>>{
  'tasks': [
    {'status', 'completed_at', 'scheduled_date', 'remaining_work_minutes'},
    {'planned_duration_minutes', 'remaining_work_minutes'},
    {'category_id', 'project_id'},
  ],
  'fixed_events': [
    {
      'starts_at',
      'ends_at',
      'recurrence_kind',
      'recurrence_interval',
      'recurrence_weekdays',
      'recurrence_until',
      'active_from_date',
      'active_through_date',
    },
  ],
  'recurrence_series': [
    {
      'kind',
      'interval',
      'weekdays',
      'start_date',
      'end_date',
      'max_occurrences',
      'title',
      'notes',
      'priority',
      'category_id',
      'project_id',
      'deadline_offset_days',
      'planned_duration_minutes',
      'remaining_work_minutes',
      'scheduling_locked',
      'active_from_date',
      'active_through_date',
      'family_id',
    },
  ],
  'recurrence_occurrences': [
    {
      'task_id',
      'series_id',
      'ordinal',
      'nominal_date',
      'disposition',
      'is_edited',
      'is_rescheduled',
    },
  ],
  'task_resources': [
    {'kind', 'target', 'content', 'sha256', 'byte_size', 'original_name'},
  ],
  'work_sessions': [
    {'task_id', 'starts_at', 'ends_at', 'outcome', 'actual_started_at'},
  ],
  'timer_runs': [
    {
      'task_id',
      'state',
      'started_at',
      'last_seen_at',
      'stopped_at',
      'owner_device_id',
    },
  ],
  'time_entries': [
    {'task_id', 'session_id', 'starts_at', 'ends_at', 'source', 'timer_run_id'},
  ],
  'progressive_plan_assignments': [
    {'step_index', 'title', 'carry_forward', 'manual'},
  ],
  'progressive_plan_steps': [
    {'family_id', 'position', 'title'},
  ],
};

// Modification timestamps are display/CAS metadata, not user-value winners.
// Their maximum is deterministic; independent edits still merge and divergent
// user fields still require a decision regardless of clock skew.
SyncRecordReview reviewPortableRecord(
  String entity,
  Iterable<SyncRevision> history,
) {
  final revisions = history.toList();
  final fields = {for (final revision in revisions) ...?revision.value?.keys};
  final graph = CausalRecord(
    coupledFields: [
      for (final group in _coupledFields[entity] ?? const <Set<String>>[])
        if (group.intersection(fields).length > 1) group.intersection(fields),
    ],
  );
  for (final revision in revisions) {
    graph.accept(
      SyncRevision(
        id: revision.id,
        device: revision.device,
        sequence: revision.sequence,
        parents: revision.parents,
        observed: revision.observed,
        visible: revision.visible,
        intent: revision.intent,
        value: revision.value == null
            ? null
            : ({...revision.value!}..remove('updated_at')),
      ),
    );
  }
  final review = graph.review();
  final originals = {for (final revision in revisions) revision.id: revision};
  final heads = [for (final id in review.heads) originals[id]!];
  Object? canonical(Object? value) => switch (value) {
    Map() => {
      for (final key in value.keys.cast<String>().toList()..sort())
        key: canonical(value[key]),
    },
    List() => value.map(canonical).toList(),
    _ => value,
  };
  if (heads.length > 1 &&
      heads.any(
        (r) =>
            r.value?['deleted_at'] != null || r.value?['archived_at'] != null,
      ) &&
      heads
              .map(
                (r) => jsonEncode(
                  canonical(
                    r.value == null
                        ? null
                        : ({...r.value!}..remove('updated_at')),
                  ),
                ),
              )
              .toSet()
              .length >
          1) {
    return SyncRecordReview(
      heads: review.heads,
      merged: null,
      conflicts: [
        SyncConflict(
          SyncConflict.record,
          null,
          Map.unmodifiable({for (final head in heads) head.id: head.value}),
          basePresent: false,
        ),
      ],
    );
  }
  final conflicts = [
    for (final conflict in review.conflicts)
      if (conflict.field == SyncConflict.record)
        SyncConflict(
          conflict.field,
          conflict.base,
          Map.unmodifiable({
            for (final id in conflict.candidates.keys) id: originals[id]!.value,
          }),
          basePresent: conflict.basePresent,
          absentCandidates: conflict.absentCandidates,
        )
      else
        conflict,
  ];
  if (review.merged == null) {
    return SyncRecordReview(
      heads: review.heads,
      merged: null,
      conflicts: conflicts,
    );
  }
  DateTime? modification;
  for (final revision in revisions.where(
    (revision) => review.heads.contains(revision.id),
  )) {
    final value = revision.value;
    if (value == null || !value.containsKey('updated_at')) continue;
    final raw = value['updated_at'];
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null || !parsed.isUtc) {
      throw const FormatException(
        'Portable modification timestamp must be UTC',
      );
    }
    if (modification == null || parsed.isAfter(modification)) {
      modification = parsed;
    }
  }
  return SyncRecordReview(
    heads: review.heads,
    merged: {
      ...review.merged!,
      if (modification != null)
        'updated_at': modification.toUtc().toIso8601String(),
    },
    conflicts: conflicts,
  );
}
