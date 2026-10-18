part of 'life_repository.dart';

extension GoalRepository on LifeRepository {
  Future<GoalProgress> _goalProgress(String goalId, String startDate) async {
    final manualRow = await db
        .customSelect(
          'SELECT COALESCE(SUM(delta),0.0) AS amount FROM goal_progress_entries WHERE goal_id=?',
          variables: [Variable.withString(goalId)],
        )
        .getSingle();
    final taskRows = await db
        .customSelect(
          '''
      SELECT t.id,t.completed_at,COALESCE(d.units,p.units) AS units
      FROM tasks t
      LEFT JOIN goal_task_links d ON d.task_id=t.id AND d.goal_id=?
      LEFT JOIN goal_project_links p ON p.project_id=t.project_id AND p.goal_id=?
      WHERE t.status='completed' AND t.completed_at IS NOT NULL
        AND (d.goal_id IS NOT NULL OR p.goal_id IS NOT NULL)
    ''',
          variables: [Variable.withString(goalId), Variable.withString(goalId)],
        )
        .get();
    var taskAmount = 0.0;
    for (final row in taskRows) {
      final completedDay = localDate(
        DateTime.parse(row.read<String>('completed_at')).toLocal(),
      );
      if (completedDay.compareTo(startDate) >= 0) {
        taskAmount += row.read<double>('units');
      }
    }
    final habitRow = await db
        .customSelect(
          '''
      SELECT COALESCE(SUM(l.units),0.0) AS amount
      FROM goal_habit_links l JOIN habit_entries e ON e.habit_id=l.habit_id
      WHERE l.goal_id=? AND e.local_date>=? AND e.value=1
    ''',
          variables: [
            Variable.withString(goalId),
            Variable.withString(startDate),
          ],
        )
        .getSingle();
    return GoalProgress(
      manual: manualRow.read<double>('amount'),
      tasks: taskAmount,
      habits: habitRow.read<double>('amount'),
    );
  }

  Future<List<Goal>> goals({bool includeArchived = true}) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM goals ${includeArchived ? '' : 'WHERE archived_at IS NULL'} ORDER BY created_at DESC,id',
        )
        .get();
    final goals = <Goal>[];
    for (final row in rows) {
      final id = row.read<String>('id');
      goals.add(
        Goal(
          id: id,
          title: row.read<String>('title'),
          description: row.read<String>('description'),
          target: row.read<double>('target'),
          unit: row.read<String>('unit'),
          startDate: row.read<String>('start_date'),
          deadlineDate: row.read<String?>('deadline_date'),
          createdAt: DateTime.parse(row.read<String>('created_at')),
          updatedAt: DateTime.parse(row.read<String>('updated_at')),
          completedAt: row.read<String?>('completed_at') == null
              ? null
              : DateTime.parse(row.read<String>('completed_at')),
          archivedAt: row.read<String?>('archived_at') == null
              ? null
              : DateTime.parse(row.read<String>('archived_at')),
          progress: await _goalProgress(id, row.read<String>('start_date')),
        ),
      );
    }
    return goals;
  }

  Future<List<GoalMilestone>> goalMilestones() async {
    final rows = await db
        .customSelect('SELECT * FROM goal_milestones ORDER BY threshold,id')
        .get();
    return [
      for (final row in rows)
        GoalMilestone(
          id: row.read<String>('id'),
          goalId: row.read<String>('goal_id'),
          title: row.read<String>('title'),
          threshold: row.read<double>('threshold'),
          deadlineDate: row.read<String?>('deadline_date'),
          completedAt: row.read<String?>('completed_at') == null
              ? null
              : DateTime.parse(row.read<String>('completed_at')),
          updatedAt: DateTime.parse(row.read<String>('updated_at')),
        ),
    ];
  }

  Future<List<GoalProgressEntry>> goalProgressHistory(String goalId) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM goal_progress_entries WHERE goal_id=? ORDER BY created_at DESC,id',
          variables: [Variable.withString(goalId)],
        )
        .get();
    return [
      for (final row in rows)
        GoalProgressEntry(
          id: row.read<String>('id'),
          goalId: row.read<String>('goal_id'),
          delta: row.read<double>('delta'),
          notes: row.read<String>('notes'),
          createdAt: DateTime.parse(row.read<String>('created_at')),
        ),
    ];
  }

  Future<List<GoalLinkedEvent>> goalLinkedEvents(Goal goal) async {
    final result = <GoalLinkedEvent>[];
    final taskRows = await db
        .customSelect(
          '''
      SELECT t.id,t.title,t.completed_at,COALESCE(d.units,p.units) AS units
      FROM tasks t
      LEFT JOIN goal_task_links d ON d.task_id=t.id AND d.goal_id=?
      LEFT JOIN goal_project_links p ON p.project_id=t.project_id AND p.goal_id=?
      WHERE t.status='completed' AND t.completed_at IS NOT NULL
        AND (d.goal_id IS NOT NULL OR p.goal_id IS NOT NULL)
    ''',
          variables: [
            Variable.withString(goal.id),
            Variable.withString(goal.id),
          ],
        )
        .get();
    for (final row in taskRows) {
      final date = localDate(
        DateTime.parse(row.read<String>('completed_at')).toLocal(),
      );
      if (date.compareTo(goal.startDate) < 0) continue;
      result.add(
        GoalLinkedEvent(
          sourceId: row.read<String>('id'),
          label: 'Task: ${row.read<String>('title')}',
          localDate: date,
          units: row.read<double>('units'),
        ),
      );
    }
    final habitRows = await db
        .customSelect(
          '''
      SELECT e.id,e.local_date,h.title,l.units
      FROM goal_habit_links l JOIN habit_entries e ON e.habit_id=l.habit_id
      JOIN habits h ON h.id=l.habit_id
      WHERE l.goal_id=? AND e.local_date>=? AND e.value=1
    ''',
          variables: [
            Variable.withString(goal.id),
            Variable.withString(goal.startDate),
          ],
        )
        .get();
    for (final row in habitRows) {
      result.add(
        GoalLinkedEvent(
          sourceId: row.read<String>('id'),
          label: 'Habit: ${row.read<String>('title')}',
          localDate: row.read<String>('local_date'),
          units: row.read<double>('units'),
        ),
      );
    }
    result.sort((a, b) => b.localDate.compareTo(a.localDate));
    return result;
  }

  Future<GoalLinks> goalLinks(String goalId) async {
    Future<Set<String>> ids(String table, String column) async {
      final rows = await db
          .customSelect(
            'SELECT $column FROM $table WHERE goal_id=?',
            variables: [Variable.withString(goalId)],
          )
          .get();
      return rows.map((row) => row.read<String>(column)).toSet();
    }

    return GoalLinks(
      taskIds: await ids('goal_task_links', 'task_id'),
      projectIds: await ids('goal_project_links', 'project_id'),
      habitIds: await ids('goal_habit_links', 'habit_id'),
    );
  }

  void _validateGoal(GoalDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('Goal title is required');
    }
    if (!draft.target.isFinite || draft.target <= 0) {
      throw ArgumentError('Goal target must be positive');
    }
    RecurrenceRule.daysBetween(draft.startDate, draft.startDate);
    if (draft.deadlineDate != null &&
        RecurrenceRule.daysBetween(draft.startDate, draft.deadlineDate!) < 0) {
      throw ArgumentError('Deadline must follow the goal start');
    }
  }

  List<Variable> _goalValues(GoalDraft draft) => [
    Variable.withString(draft.title.trim()),
    Variable.withString(draft.description),
    Variable.withReal(draft.target),
    Variable.withString(draft.unit.trim()),
    Variable.withString(draft.startDate),
    Variable<String>(draft.deadlineDate),
  ];

  Future<Goal> addGoal(GoalDraft draft) async {
    _validateGoal(draft);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      '''INSERT INTO goals(id,title,description,target,unit,start_date,
        deadline_date,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)''',
      variables: [
        Variable.withString(id),
        ..._goalValues(draft),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await goals()).singleWhere((goal) => goal.id == id);
  }

  Future<void> updateGoal(Goal previous, GoalDraft draft) async {
    _validateGoal(draft);
    await db.transaction(() async {
      final milestone = await db
          .customSelect(
            'SELECT MAX(threshold) AS highest FROM goal_milestones WHERE goal_id=?',
            variables: [Variable.withString(previous.id)],
          )
          .getSingle();
      final highest = milestone.read<double?>('highest');
      if (highest != null && draft.target < highest) {
        throw ArgumentError(
          'Goal target cannot fall below an existing milestone',
        );
      }
      final count = await db.customUpdate(
        '''UPDATE goals SET title=?,description=?,target=?,unit=?,start_date=?,
        deadline_date=?,updated_at=? WHERE id=? AND updated_at=?
        AND archived_at IS NULL''',
        variables: [
          ..._goalValues(draft),
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(previous.id),
          Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (count != 1) {
        throw StateError('Goal changed. Reopen it before editing.');
      }
    });
  }

  Future<void> setGoalCompleted(Goal previous, bool completed) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await db.customUpdate(
      '''UPDATE goals SET completed_at=?,updated_at=?
        WHERE id=? AND updated_at=? AND archived_at IS NULL''',
      variables: [
        Variable<String>(completed ? now : null),
        Variable.withString(now),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Goal changed. Reopen it first.');
  }

  Future<void> setGoalArchived(Goal previous, bool archived) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await db.customUpdate(
      'UPDATE goals SET archived_at=?,updated_at=? WHERE id=? AND updated_at=?',
      variables: [
        Variable<String>(archived ? now : null),
        Variable.withString(now),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Goal changed. Reopen it first.');
  }

  Future<void> addGoalProgress(Goal goal, double delta, String notes) async {
    if (!delta.isFinite || delta == 0) {
      throw ArgumentError('Enter a nonzero adjustment');
    }
    await db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT updated_at FROM goals WHERE id=? AND archived_at IS NULL',
            variables: [Variable.withString(goal.id)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') !=
              goal.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Goal changed. Reopen it first.');
      }
      final row = await db
          .customSelect(
            'SELECT COALESCE(SUM(delta),0.0) AS amount FROM goal_progress_entries WHERE goal_id=?',
            variables: [Variable.withString(goal.id)],
          )
          .getSingle();
      if (row.read<double>('amount') + delta < 0) {
        throw ArgumentError('Manual progress cannot become negative');
      }
      await db.customInsert(
        '''INSERT INTO goal_progress_entries(id,goal_id,delta,notes,created_at)
          VALUES(?,?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(goal.id),
          Variable.withReal(delta),
          Variable.withString(notes),
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
        ],
      );
    });
  }

  Future<void> addGoalMilestone(
    Goal goal,
    String title,
    double threshold,
    String? deadlineDate,
  ) async {
    if (title.trim().isEmpty ||
        !threshold.isFinite ||
        threshold <= 0 ||
        threshold > goal.target) {
      throw ArgumentError(
        'Milestone needs a title and threshold within the goal target',
      );
    }
    if (deadlineDate != null) {
      RecurrenceRule.daysBetween(deadlineDate, deadlineDate);
    }
    await db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT updated_at FROM goals WHERE id=? AND archived_at IS NULL',
            variables: [Variable.withString(goal.id)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') !=
              goal.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Goal changed. Reopen it first.');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customInsert(
        '''INSERT INTO goal_milestones(id,goal_id,title,threshold,
          deadline_date,created_at,updated_at) VALUES(?,?,?,?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(goal.id),
          Variable.withString(title.trim()),
          Variable.withReal(threshold),
          Variable<String>(deadlineDate),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
  }

  Future<void> setGoalMilestoneCompleted(
    GoalMilestone milestone,
    bool completed,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await db.customUpdate(
      '''UPDATE goal_milestones SET completed_at=?,updated_at=?
        WHERE id=? AND updated_at=? AND goal_id IN
        (SELECT id FROM goals WHERE archived_at IS NULL)''',
      variables: [
        Variable<String>(completed ? now : null),
        Variable.withString(now),
        Variable.withString(milestone.id),
        Variable.withString(milestone.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Milestone changed. Reopen it first.');
  }

  Future<void> updateGoalMilestone(
    Goal goal,
    GoalMilestone previous,
    String title,
    double threshold,
    String? deadlineDate,
  ) async {
    if (previous.goalId != goal.id ||
        title.trim().isEmpty ||
        !threshold.isFinite ||
        threshold <= 0 ||
        threshold > goal.target) {
      throw ArgumentError('Milestone needs a valid title and threshold');
    }
    if (deadlineDate != null) {
      RecurrenceRule.daysBetween(deadlineDate, deadlineDate);
    }
    final count = await db.customUpdate(
      '''UPDATE goal_milestones SET title=?,threshold=?,deadline_date=?,
        updated_at=? WHERE id=? AND updated_at=? AND goal_id IN
        (SELECT id FROM goals WHERE archived_at IS NULL)''',
      variables: [
        Variable.withString(title.trim()),
        Variable.withReal(threshold),
        Variable<String>(deadlineDate),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Milestone changed. Reopen it first.');
  }

  Future<void> setGoalLinks(Goal previous, GoalLinks links) async {
    await db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT updated_at FROM goals WHERE id=? AND archived_at IS NULL',
            variables: [Variable.withString(previous.id)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') !=
              previous.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Goal changed. Reopen it first.');
      }
      for (final id in links.habitIds) {
        final row = await db
            .customSelect(
              "SELECT 1 FROM habits WHERE id=? AND kind='binary'",
              variables: [Variable.withString(id)],
            )
            .getSingleOrNull();
        if (row == null) {
          throw ArgumentError('Only Yes/No habits can link to goals');
        }
      }
      for (final pair in [
        ('task', links.taskIds),
        ('project', links.projectIds),
        ('habit', links.habitIds),
      ]) {
        final kind = pair.$1;
        final ids = pair.$2;
        final table = kind == 'task'
            ? 'tasks'
            : kind == 'project'
            ? 'projects'
            : 'habits';
        for (final id in ids) {
          final exists = await db
              .customSelect(
                'SELECT 1 FROM $table WHERE id=?',
                variables: [Variable.withString(id)],
              )
              .getSingleOrNull();
          if (exists == null) {
            throw StateError('A linked $kind changed or was deleted');
          }
        }
        await db.customUpdate(
          'DELETE FROM goal_${kind}_links WHERE goal_id=?',
          variables: [Variable.withString(previous.id)],
        );
        for (final id in ids) {
          await db.customInsert(
            'INSERT INTO goal_${kind}_links(goal_id,${kind}_id,units) VALUES(?,?,1.0)',
            variables: [
              Variable.withString(previous.id),
              Variable.withString(id),
            ],
          );
        }
      }
      await db.customUpdate(
        'UPDATE goals SET updated_at=? WHERE id=?',
        variables: [
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(previous.id),
        ],
      );
    });
  }
}
