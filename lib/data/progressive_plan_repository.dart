part of 'life_repository.dart';

extension ProgressivePlanRepository on LifeRepository {
  Future<ProgressivePlan?> progressivePlan(String taskId) async {
    final family = await _progressiveFamily(taskId);
    if (family == null) return null;
    final plan = await db
        .customSelect(
          'SELECT * FROM progressive_plans WHERE family_id=?',
          variables: [Variable.withString(family)],
        )
        .getSingleOrNull();
    if (plan == null) return null;
    final steps = await db
        .customSelect(
          'SELECT title FROM progressive_plan_steps WHERE family_id=? ORDER BY position',
          variables: [Variable.withString(family)],
        )
        .get();
    return ProgressivePlan(
      familyId: family,
      steps: [for (final row in steps) row.read<String>('title')],
      repeatAtEnd: plan.read<String>('end_action') == 'repeat',
    );
  }

  Future<String?> _progressiveFamily(String taskId) async {
    final row = await db
        .customSelect(
          '''
      SELECT s.family_id FROM recurrence_occurrences o
      JOIN recurrence_series s ON s.id=o.series_id WHERE o.task_id=?''',
          variables: [Variable.withString(taskId)],
        )
        .getSingleOrNull();
    return row?.read<String>('family_id');
  }

  Future<void> configureProgressivePlan(
    String taskId,
    List<String> titles, {
    required bool repeatAtEnd,
  }) async {
    final steps = titles.map((s) => s.trim()).toList();
    if (steps.isEmpty || steps.any((s) => s.isEmpty)) {
      throw ArgumentError('Add at least one nonempty plan step');
    }
    final family = await _progressiveFamily(taskId);
    if (family == null) throw StateError('A recurring task is required');
    final kind = await db
        .customSelect(
          '''SELECT s.kind FROM recurrence_occurrences o
      JOIN recurrence_series s ON s.id=o.series_id WHERE o.task_id=?''',
          variables: [Variable.withString(taskId)],
        )
        .getSingle();
    if (kind.read<String>('kind') == RecurrenceKind.afterCompletion.name) {
      throw StateError('Study plans require a scheduled recurrence');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await _writeProgressivePlan(family, steps, repeatAtEnd, now);
      await _refreshProgressiveAssignments(family);
    });
  }

  Future<void> _writeProgressivePlan(
    String family,
    List<String> steps,
    bool repeatAtEnd,
    String now,
  ) async {
    await db.customInsert(
      '''INSERT INTO progressive_plans(family_id,end_action,updated_at)
        VALUES(?,?,?) ON CONFLICT(family_id) DO UPDATE SET
        end_action=excluded.end_action,updated_at=excluded.updated_at''',
      variables: [
        Variable.withString(family),
        Variable.withString(repeatAtEnd ? 'repeat' : 'finish'),
        Variable.withString(now),
      ],
    );
    await db.customUpdate(
      'DELETE FROM progressive_plan_steps WHERE family_id=?',
      variables: [Variable.withString(family)],
    );
    for (var i = 0; i < steps.length; i++) {
      await db.customInsert(
        '''INSERT INTO progressive_plan_steps
          (id,family_id,position,title) VALUES(?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(family),
          Variable.withInt(i),
          Variable.withString(steps[i]),
        ],
      );
    }
  }

  Future<Map<String, ProgressiveAssignment>> progressiveAssignments() async {
    final rows = await db.customSelect('''SELECT o.task_id, a.*
      FROM progressive_plan_assignments a
      JOIN recurrence_occurrences o ON o.id=a.occurrence_id
      WHERE o.task_id IS NOT NULL''').get();
    return {
      for (final row in rows)
        row.read<String>('task_id'): ProgressiveAssignment(
          taskId: row.read<String>('task_id'),
          title: row.read<String?>('title'),
          stepIndex: row.read<int?>('step_index'),
          carryForward: row.read<int>('carry_forward') == 1,
          manual: row.read<int>('manual') == 1,
        ),
    };
  }

  Future<void> reassignProgressiveStep(String taskId, int stepIndex) async {
    final plan = await progressivePlan(taskId);
    if (plan == null || stepIndex < 0 || stepIndex >= plan.steps.length) {
      throw ArgumentError('Choose a current plan step');
    }
    await db.transaction(() async {
      final row = await db
          .customSelect(
            'SELECT id FROM recurrence_occurrences WHERE task_id=?',
            variables: [Variable.withString(taskId)],
          )
          .getSingle();
      final id = row.read<String>('id');
      await db.customInsert(
        '''INSERT INTO progressive_plan_assignments
        (occurrence_id,step_index,title,manual,updated_at) VALUES(?,?,?,1,?)
        ON CONFLICT(occurrence_id) DO UPDATE SET step_index=excluded.step_index,
        title=excluded.title,manual=1,updated_at=excluded.updated_at''',
        variables: [
          Variable.withString(id),
          Variable.withInt(stepIndex),
          Variable.withString(plan.steps[stepIndex]),
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
        ],
      );
    });
  }

  Future<void> setProgressiveCarry(String taskId, bool carry) async {
    final family = await _progressiveFamily(taskId);
    if (family == null || await progressivePlan(taskId) == null) {
      throw StateError('This occurrence has no study plan');
    }
    await db.transaction(() async {
      final row = await db
          .customSelect(
            'SELECT id FROM recurrence_occurrences WHERE task_id=?',
            variables: [Variable.withString(taskId)],
          )
          .getSingle();
      await _syncProgressiveAssignment(
        row.read<String>('id'),
        forceFuture: false,
      );
      await db.customUpdate(
        '''UPDATE progressive_plan_assignments
        SET carry_forward=?,updated_at=? WHERE occurrence_id=?''',
        variables: [
          Variable.withInt(carry ? 1 : 0),
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(row.read<String>('id')),
        ],
      );
      await _refreshProgressiveAssignments(family);
    });
  }

  Future<void> _refreshProgressiveAssignments(String family) async {
    final rows = await db
        .customSelect(
          '''SELECT o.id FROM recurrence_occurrences o
      JOIN recurrence_series s ON s.id=o.series_id
      WHERE s.family_id=? AND o.task_id IS NOT NULL
      ORDER BY o.nominal_date,o.id''',
          variables: [Variable.withString(family)],
        )
        .get();
    for (final row in rows) {
      await _syncProgressiveAssignment(
        row.read<String>('id'),
        forceFuture: true,
      );
    }
  }

  Future<void> _syncProgressiveAssignment(
    String occurrenceId, {
    required bool forceFuture,
  }) async {
    final occurrence = await db
        .customSelect(
          '''SELECT o.nominal_date,o.series_id,
      o.task_id,s.family_id,t.status FROM recurrence_occurrences o
      JOIN recurrence_series s ON s.id=o.series_id
      JOIN tasks t ON t.id=o.task_id WHERE o.id=?''',
          variables: [Variable.withString(occurrenceId)],
        )
        .getSingleOrNull();
    if (occurrence == null) return;
    final family = occurrence.read<String>('family_id');
    final plan = await db
        .customSelect(
          'SELECT end_action FROM progressive_plans WHERE family_id=?',
          variables: [Variable.withString(family)],
        )
        .getSingleOrNull();
    if (plan == null) return;
    final existing = await db
        .customSelect(
          'SELECT manual FROM progressive_plan_assignments WHERE occurrence_id=?',
          variables: [Variable.withString(occurrenceId)],
        )
        .getSingleOrNull();
    final date = occurrence.read<String>('nominal_date');
    final today = localDate(DateTime.now());
    if (existing != null &&
        (!forceFuture ||
            date.compareTo(today) < 0 ||
            existing.read<int>('manual') == 1 ||
            occurrence.read<String>('status') != TaskStatus.notStarted.name)) {
      return;
    }
    final steps = await db
        .customSelect(
          '''SELECT title FROM progressive_plan_steps
      WHERE family_id=? ORDER BY position''',
          variables: [Variable.withString(family)],
        )
        .get();
    if (steps.isEmpty) return;
    var index = await _progressiveOrdinal(family, date);
    final carried = await db
        .customSelect(
          '''SELECT COUNT(*) AS count_value
      FROM progressive_plan_assignments a
      JOIN recurrence_occurrences o ON o.id=a.occurrence_id
      JOIN recurrence_series s ON s.id=o.series_id
      WHERE s.family_id=? AND o.nominal_date<? AND a.carry_forward=1''',
          variables: [Variable.withString(family), Variable.withString(date)],
        )
        .getSingle();
    index -= carried.read<int>('count_value');
    if (index < 0) index = 0;
    final stepIndex = plan.read<String>('end_action') == 'repeat'
        ? index % steps.length
        : (index < steps.length ? index : null);
    final title = stepIndex == null
        ? null
        : steps[stepIndex].read<String>('title');
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      '''INSERT INTO progressive_plan_assignments
      (occurrence_id,step_index,title,updated_at) VALUES(?,?,?,?)
      ON CONFLICT(occurrence_id) DO UPDATE SET
      step_index=excluded.step_index,title=excluded.title,
      updated_at=excluded.updated_at''',
      variables: [
        Variable.withString(occurrenceId),
        Variable<int>(stepIndex),
        Variable<String>(title),
        Variable.withString(now),
      ],
    );
  }

  Future<int> _progressiveOrdinal(String family, String date) async {
    final generations = await db
        .customSelect(
          '''SELECT * FROM recurrence_series
      WHERE family_id=? AND active_from_date<=? ORDER BY active_from_date,id''',
          variables: [Variable.withString(family), Variable.withString(date)],
        )
        .get();
    var count = 0;
    final preceding = RecurrenceRule.shiftDate(date, -1);
    for (final series in generations) {
      final from = series.read<String>('active_from_date');
      final through = series.read<String?>('active_through_date');
      final upper = through != null && through.compareTo(preceding) < 0
          ? through
          : preceding;
      if (from.compareTo(upper) <= 0) {
        count += _ruleFromSeries(series).between(from, upper).length;
      }
    }
    return count;
  }
}
