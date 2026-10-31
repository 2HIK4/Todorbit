part of 'life_repository.dart';

class _SeriesOccurrence {
  _SeriesOccurrence(this.row);
  final QueryRow row;

  String get id => row.read<String>('id');
  String get seriesId => row.read<String>('series_id');
  int get ordinal => row.read<int>('ordinal');
  String get date => row.read<String>('nominal_date');
  String? get scheduledDate => row.read<String?>('task_scheduled_date');
  String? get taskId => row.read<String?>('task_id');
  String? get taskUpdatedAt => row.read<String?>('task_updated_at');
  String get updatedAt => row.read<String>('updated_at');
  String? get status => row.read<String?>('task_status');
  bool get edited => row.read<int>('is_edited') == 1;
  bool get rescheduled => row.read<int>('is_rescheduled') == 1;
  String get disposition => row.read<String>('disposition');
  bool get hasLinks => row.read<int>('has_links') == 1;
  bool get protected =>
      taskId == null ||
      status != TaskStatus.notStarted.name ||
      disposition != 'active' ||
      edited ||
      rescheduled ||
      hasLinks;
}

class _SeriesEditState {
  _SeriesEditState(this.series, this.occurrences, this.source, this.linkStamps);
  final List<QueryRow> series;
  final List<_SeriesOccurrence> occurrences;
  final _SeriesOccurrence source;
  final List<String> linkStamps;

  String get familyId => series.first.read<String>('family_id');

  String get snapshot => jsonEncode([
    for (final row in series)
      [
        row.read<String>('id'),
        row.read<String>('updated_at'),
        row.read<String>('active_from_date'),
        row.read<String?>('active_through_date'),
      ],
    for (final item in occurrences)
      [
        item.id,
        item.seriesId,
        item.ordinal,
        item.date,
        item.scheduledDate,
        item.updatedAt,
        item.taskId,
        item.taskUpdatedAt,
        item.status,
        item.disposition,
        item.edited,
        item.rescheduled,
        item.hasLinks,
      ],
    linkStamps,
  ]);
}

Map<String, RecurrenceSlot> _desiredSeriesSlots(
  RecurrenceRule rule,
  String effective,
  String through,
  List<_SeriesOccurrence> existing,
) {
  final desired = <String, RecurrenceSlot>{};
  if (rule.kind == RecurrenceKind.afterCompletion) {
    desired[effective] = RecurrenceSlot(effective, 0);
  } else {
    for (final slot in rule.between(effective, through)) {
      desired[slot.nominalDate] = slot;
    }
    for (final old in existing) {
      for (final date in [old.date, old.scheduledDate]) {
        if (date == null ||
            date.compareTo(through) <= 0 ||
            date.compareTo(effective) < 0) {
          continue;
        }
        final match = rule.between(date, date).firstOrNull;
        if (match != null) desired[date] = match;
      }
    }
  }
  return desired;
}

Map<String, List<_SeriesOccurrence>> _seriesCollisionsByDate(
  List<_SeriesOccurrence> occurrences,
  String effective,
) {
  final byDate = <String, List<_SeriesOccurrence>>{};
  for (final item in occurrences) {
    if (item.date.compareTo(effective) >= 0) {
      byDate.putIfAbsent(item.date, () => []).add(item);
    }
    final scheduled = item.scheduledDate;
    if (scheduled != null &&
        scheduled != item.date &&
        scheduled.compareTo(effective) >= 0) {
      byDate.putIfAbsent(scheduled, () => []).add(item);
    }
  }
  return byDate;
}

extension SeriesEditRepository on LifeRepository {
  Future<RecurrenceDefinition> recurrenceDefinition(String taskId) async {
    final row = await db
        .customSelect(
          '''SELECT s.* FROM recurrence_occurrences o
        JOIN recurrence_series s ON s.id=o.series_id
        WHERE o.task_id=?''',
          variables: [Variable.withString(taskId)],
        )
        .getSingleOrNull();
    if (row == null) throw ArgumentError('Task is not recurring');
    final rule = _ruleFromSeries(row);
    final effective = row.read<String>('active_from_date');
    final offset = row.read<int?>('deadline_offset_days');
    return RecurrenceDefinition(
      rule: rule,
      template: TaskDraft(
        title: row.read<String>('title'),
        notes: row.read<String>('notes'),
        priority: row.read<int>('priority'),
        categoryId: row.read<String?>('category_id'),
        projectId: row.read<String?>('project_id'),
        scheduledDate: effective,
        deadlineDate: offset == null
            ? null
            : RecurrenceRule.shiftDate(effective, offset),
        plannedDurationMinutes: row.read<int?>('planned_duration_minutes'),
        remainingWorkMinutes: row.read<int?>('remaining_work_minutes'),
        schedulingLocked: row.read<int>('scheduling_locked') == 1,
      ),
    );
  }

  Future<_SeriesEditState> _readSeriesEditState(String taskId) async {
    final sourceRow = await db
        .customSelect(
          '''SELECT s.family_id FROM recurrence_occurrences o
        JOIN recurrence_series s ON s.id=o.series_id WHERE o.task_id=?''',
          variables: [Variable.withString(taskId)],
        )
        .getSingleOrNull();
    if (sourceRow == null) throw ArgumentError('Task is not recurring');
    final familyId = sourceRow.read<String>('family_id');
    final series = await db
        .customSelect(
          '''SELECT * FROM recurrence_series WHERE family_id=?
        ORDER BY active_from_date,id''',
          variables: [Variable.withString(familyId)],
        )
        .get();
    final rows = await db
        .customSelect(
          '''SELECT o.*,t.status AS task_status,
          t.scheduled_date AS task_scheduled_date,
          t.updated_at AS task_updated_at,
          (EXISTS(SELECT 1 FROM work_sessions w WHERE w.task_id=t.id) OR
           EXISTS(SELECT 1 FROM task_dependencies d
             WHERE d.task_id=t.id OR d.prerequisite_id=t.id) OR
           EXISTS(SELECT 1 FROM sequence_tasks q WHERE q.task_id=t.id) OR
           EXISTS(SELECT 1 FROM scheduling_changes c
             WHERE c.target_kind='task' AND c.target_id=t.id) OR
           EXISTS(SELECT 1 FROM progressive_plan_assignments a
             WHERE a.occurrence_id=o.id AND (a.manual=1 OR
               a.carry_forward=1 OR o.nominal_date < ?))) AS has_links
        FROM recurrence_occurrences o
        JOIN recurrence_series s ON s.id=o.series_id
        LEFT JOIN tasks t ON t.id=o.task_id
        WHERE s.family_id=? ORDER BY o.nominal_date,o.id''',
          variables: [
            Variable.withString(localDate(DateTime.now())),
            Variable.withString(familyId),
          ],
        )
        .get();
    final occurrences = rows.map(_SeriesOccurrence.new).toList();
    final source = occurrences
        .where((item) => item.taskId == taskId)
        .firstOrNull;
    if (source == null) throw StateError('The selected occurrence disappeared');
    final linkStamps = <String>[];
    for (final query in [
      '''SELECT 'session|' || w.id || '|' || w.updated_at AS stamp
      FROM work_sessions w JOIN recurrence_occurrences o ON o.task_id=w.task_id
      JOIN recurrence_series s ON s.id=o.series_id WHERE s.family_id=?''',
      '''SELECT 'dependency|' || d.task_id || '|' || d.prerequisite_id ||
        '|' || d.created_at AS stamp FROM task_dependencies d
      JOIN recurrence_occurrences o ON o.task_id=d.task_id OR
        o.task_id=d.prerequisite_id
      JOIN recurrence_series s ON s.id=o.series_id WHERE s.family_id=?''',
      '''SELECT 'sequence|' || q.sequence_id || '|' || q.task_id ||
        '|' || q.position AS stamp FROM sequence_tasks q
      JOIN recurrence_occurrences o ON o.task_id=q.task_id
      JOIN recurrence_series s ON s.id=o.series_id WHERE s.family_id=?''',
      '''SELECT 'schedule|' || c.id AS stamp FROM scheduling_changes c
      JOIN recurrence_occurrences o ON o.task_id=c.target_id
      JOIN recurrence_series s ON s.id=o.series_id
      WHERE c.target_kind='task' AND s.family_id=?''',
      '''SELECT 'plan|' || family_id || '|' || updated_at AS stamp
      FROM progressive_plans WHERE family_id=?''',
    ]) {
      final stamps = await db
          .customSelect(query, variables: [Variable.withString(familyId)])
          .get();
      linkStamps.addAll(stamps.map((row) => row.read<String>('stamp')));
    }
    linkStamps.sort();
    return _SeriesEditState(series, occurrences, source, linkStamps);
  }

  Future<SeriesEditPreview> previewSeriesEdit({
    required LifeTask selected,
    required SeriesEditScope scope,
    required TaskDraft draft,
    required RecurrenceRule rule,
    String? windowThrough,
  }) async {
    _validate(draft);
    if (draft.status != TaskStatus.notStarted) {
      throw ArgumentError('Series templates must start as pending tasks');
    }
    await _checkAssignment(draft.categoryId, draft.projectId);
    final state = await _readSeriesEditState(selected.id);
    if (state.source.taskUpdatedAt !=
        selected.updatedAt.toUtc().toIso8601String()) {
      throw StateError('The selected occurrence changed elsewhere');
    }
    final effective = scope == SeriesEditScope.thisAndFuture
        ? state.source.date
        : state.occurrences
                  .where(
                    (item) =>
                        item.status != null &&
                        item.status != TaskStatus.completed.name &&
                        item.status != TaskStatus.cancelled.name,
                  )
                  .map((item) => item.date)
                  .fold<String?>(
                    null,
                    (earliest, date) =>
                        earliest == null || date.compareTo(earliest) < 0
                        ? date
                        : earliest,
                  ) ??
              state.source.date;
    if (scope == SeriesEditScope.thisAndFuture &&
        rule.startDate.compareTo(effective) < 0) {
      throw ArgumentError(
        'Set the new rule anchor on or after the selected occurrence',
      );
    }
    if (rule.kind == RecurrenceKind.afterCompletion &&
        rule.startDate != effective) {
      throw ArgumentError(
        'Completion-based rules must start at the edit boundary',
      );
    }
    final through = windowThrough ?? RecurrenceRule.shiftDate(effective, 30);
    final span = RecurrenceRule.daysBetween(effective, through);
    if (span < 0 || span > 93) {
      throw ArgumentError('Preview window must be at most 94 days');
    }
    final desired = _desiredSeriesSlots(
      rule,
      effective,
      through,
      state.occurrences,
    );
    final future = state.occurrences
        .where((item) => item.date.compareTo(effective) >= 0)
        .toList();
    final byDate = _seriesCollisionsByDate(state.occurrences, effective);
    final impacts = <SeriesEditImpact>[];
    for (final item in future) {
      impacts.add(
        SeriesEditImpact(
          nominalDate: item.date,
          taskId: item.taskId,
          kind: item.protected
              ? SeriesImpactKind.preserve
              : desired.containsKey(item.date)
              ? SeriesImpactKind.collision
              : SeriesImpactKind.exclude,
          reason: item.protected
              ? 'Completed, changed, skipped, or linked work is preserved'
              : desired.containsKey(item.date)
              ? 'This day also occurs under the new rule'
              : 'Unmodified generated occurrence is outside the new rule',
        ),
      );
    }
    final collisions = <SeriesCollision>[];
    for (final slot in desired.values) {
      final old = byDate[slot.nominalDate] ?? const <_SeriesOccurrence>[];
      if (old.isEmpty) {
        impacts.add(
          SeriesEditImpact(
            nominalDate: slot.nominalDate,
            kind: SeriesImpactKind.create,
            reason: 'New rule schedules an occurrence',
          ),
        );
      } else {
        collisions.add(
          SeriesCollision(
            nominalDate: slot.nominalDate,
            existingTaskIds: [
              for (final item in old)
                if (item.taskId != null) item.taskId!,
            ],
            canCombine: old.length == 1 && !old.single.protected,
          ),
        );
      }
    }
    impacts.sort((a, b) => a.nominalDate.compareTo(b.nominalDate));
    collisions.sort((a, b) => a.nominalDate.compareTo(b.nominalDate));
    return SeriesEditPreview(
      sourceTaskId: selected.id,
      familyId: state.familyId,
      scope: scope,
      effectiveDate: effective,
      windowThrough: through,
      draft: draft,
      rule: rule,
      impacts: impacts,
      collisions: collisions,
      snapshot: state.snapshot,
    );
  }

  Future<String> applySeriesEdit(
    SeriesEditPreview preview,
    Map<String, SeriesCollisionChoice> choices,
  ) async {
    return db.transaction(() async {
      final selected = (await tasks())
          .where((task) => task.id == preview.sourceTaskId)
          .firstOrNull;
      if (selected == null) {
        throw StateError('The selected occurrence no longer exists');
      }
      final refreshed = await previewSeriesEdit(
        selected: selected,
        scope: preview.scope,
        draft: preview.draft,
        rule: preview.rule,
        windowThrough: preview.windowThrough,
      );
      if (refreshed.snapshot != preview.snapshot ||
          refreshed.effectiveDate != preview.effectiveDate ||
          refreshed.familyId != preview.familyId) {
        throw StateError('The series changed after preview. Review it again.');
      }
      for (final collision in preview.collisions) {
        final choice = choices[collision.nominalDate];
        if (choice == null ||
            (choice == SeriesCollisionChoice.combine &&
                !collision.canCombine)) {
          throw ArgumentError('Choose a valid resolution for every collision');
        }
      }
      final state = await _readSeriesEditState(preview.sourceTaskId);
      final desired = _desiredSeriesSlots(
        preview.rule,
        preview.effectiveDate,
        preview.windowThrough,
        state.occurrences,
      );
      final oldByDate = _seriesCollisionsByDate(
        state.occurrences,
        preview.effectiveDate,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      final priorDay = RecurrenceRule.shiftDate(preview.effectiveDate, -1);
      for (final segment in state.series) {
        final activeFrom = segment.read<String>('active_from_date');
        final activeThrough = segment.read<String?>('active_through_date');
        if (activeThrough != null &&
            activeThrough.compareTo(preview.effectiveDate) < 0) {
          continue;
        }
        final limit = activeFrom.compareTo(preview.effectiveDate) > 0
            ? RecurrenceRule.shiftDate(activeFrom, -1)
            : priorDay;
        await db.customUpdate(
          '''UPDATE recurrence_series SET active_through_date=?,updated_at=?
            WHERE id=?''',
          variables: [
            Variable.withString(limit),
            Variable.withString(now),
            Variable.withString(segment.read<String>('id')),
          ],
        );
      }
      final seriesId = _uuid.v4();
      final offset = preview.draft.deadlineDate == null
          ? null
          : RecurrenceRule.daysBetween(
              preview.effectiveDate,
              preview.draft.deadlineDate!,
            );
      await db.customInsert(
        '''INSERT INTO recurrence_series(
          id,family_id,active_from_date,kind,start_date,interval,weekdays,
          end_date,max_occurrences,title,notes,priority,category_id,project_id,
          deadline_offset_days,planned_duration_minutes,remaining_work_minutes,
          scheduling_locked,created_at,updated_at)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
        variables: [
          Variable.withString(seriesId),
          Variable.withString(preview.familyId),
          Variable.withString(preview.effectiveDate),
          Variable.withString(preview.rule.kind.name),
          Variable.withString(preview.rule.startDate),
          Variable.withInt(preview.rule.interval),
          Variable.withString(
            (preview.rule.weekdays.toList()..sort()).join(','),
          ),
          Variable<String>(preview.rule.endDate),
          Variable<int>(preview.rule.maxOccurrences),
          Variable.withString(preview.draft.title.trim()),
          Variable.withString(preview.draft.notes),
          Variable.withInt(preview.draft.priority),
          Variable<String>(preview.draft.categoryId),
          Variable<String>(preview.draft.projectId),
          Variable<int>(offset),
          Variable<int>(preview.draft.plannedDurationMinutes),
          Variable<int>(preview.draft.remainingWorkMinutes),
          Variable.withInt(preview.draft.schedulingLocked ? 1 : 0),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      final newSeries = await db
          .customSelect(
            'SELECT * FROM recurrence_series WHERE id=?',
            variables: [Variable.withString(seriesId)],
          )
          .getSingle();
      final actions = <Map<String, Object?>>[];

      for (final old in state.occurrences.where(
        (item) =>
            item.date.compareTo(preview.effectiveDate) >= 0 &&
            !item.protected &&
            !desired.containsKey(item.date),
      )) {
        await db.customUpdate(
          'DELETE FROM recurrence_occurrences WHERE id=?',
          variables: [Variable.withString(old.id)],
        );
        await db.customUpdate(
          'DELETE FROM tasks WHERE id=?',
          variables: [Variable.withString(old.taskId!)],
        );
        actions.add({
          'date': old.date,
          'action': 'remove_unmodified',
          'task_id': old.taskId,
          'occurrence_id': old.id,
        });
      }
      final slots = desired.values.toList()
        ..sort((a, b) => a.nominalDate.compareTo(b.nominalDate));
      for (final slot in slots) {
        final old = oldByDate[slot.nominalDate] ?? const <_SeriesOccurrence>[];
        final choice = choices[slot.nominalDate];
        if (old.isEmpty || choice == SeriesCollisionChoice.keepBoth) {
          await _insertOccurrence(newSeries, slot);
          actions.add({
            'date': slot.nominalDate,
            'action': old.isEmpty ? 'create' : 'keep_both',
            'existing_task_ids': [for (final item in old) item.taskId],
          });
        } else if (choice == SeriesCollisionChoice.skipNew) {
          await db.customInsert(
            '''INSERT INTO recurrence_occurrences(
              id,series_id,ordinal,nominal_date,task_id,disposition,
              created_at,updated_at) VALUES(?,?,?,?,NULL,'skipped',?,?)''',
            variables: [
              Variable.withString(_uuid.v4()),
              Variable.withString(seriesId),
              Variable.withInt(slot.ordinal),
              Variable.withString(slot.nominalDate),
              Variable.withString(now),
              Variable.withString(now),
            ],
          );
          actions.add({
            'date': slot.nominalDate,
            'action': 'skip_new',
            'existing_task_ids': [for (final item in old) item.taskId],
          });
        } else if (choice == SeriesCollisionChoice.combine) {
          final item = old.single;
          if (item.protected) {
            throw StateError('A changed occurrence cannot be combined');
          }
          final deadline = offset == null
              ? null
              : RecurrenceRule.shiftDate(slot.nominalDate, offset);
          final taskRevision = await _nextStoredTaskRevision(item.taskId!);
          await db.customUpdate(
            '''UPDATE tasks SET title=?,notes=?,priority=?,category_id=?,
              project_id=?,deadline_date=?,planned_duration_minutes=?,
              remaining_work_minutes=?,scheduling_locked=?,updated_at=?
              WHERE id=?''',
            variables: [
              Variable.withString(preview.draft.title.trim()),
              Variable.withString(preview.draft.notes),
              Variable.withInt(preview.draft.priority),
              Variable<String>(preview.draft.categoryId),
              Variable<String>(preview.draft.projectId),
              Variable<String>(deadline),
              Variable<int>(preview.draft.plannedDurationMinutes),
              Variable<int>(preview.draft.remainingWorkMinutes),
              Variable.withInt(preview.draft.schedulingLocked ? 1 : 0),
              Variable.withString(taskRevision.toIso8601String()),
              Variable.withString(item.taskId!),
            ],
          );
          await db.customUpdate(
            '''UPDATE recurrence_occurrences SET series_id=?,ordinal=?,
              is_edited=0,is_rescheduled=0,updated_at=? WHERE id=?''',
            variables: [
              Variable.withString(seriesId),
              Variable.withInt(slot.ordinal),
              Variable.withString(now),
              Variable.withString(item.id),
            ],
          );
          actions.add({
            'date': slot.nominalDate,
            'action': 'combine',
            'task_id': item.taskId,
            'occurrence_id': item.id,
          });
        }
      }
      await _refreshProgressiveAssignments(preview.familyId);
      await db.customInsert(
        '''INSERT INTO series_edit_history(id,family_id,source_task_id,
          new_series_id,scope,effective_date,details_json,created_at)
          VALUES(?,?,?,?,?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(preview.familyId),
          Variable.withString(preview.sourceTaskId),
          Variable.withString(seriesId),
          Variable.withString(preview.scope.name),
          Variable.withString(preview.effectiveDate),
          Variable.withString(
            jsonEncode({
              'replaced_series_ids': [
                for (final segment in state.series) segment.read<String>('id'),
              ],
              'actions': actions,
            }),
          ),
          Variable.withString(now),
        ],
      );
      return seriesId;
    });
  }
}
