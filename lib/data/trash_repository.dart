part of 'life_repository.dart';

extension TrashRepository on LifeRepository {
  static const _tables = <TrashKind, String>{
    TrashKind.task: 'tasks',
    TrashKind.project: 'projects',
    TrashKind.category: 'categories',
    TrashKind.event: 'fixed_events',
    TrashKind.session: 'work_sessions',
  };

  Future<List<TrashItem>> trash() async {
    final result = <TrashItem>[];
    for (final kind in TrashKind.values) {
      if (kind == TrashKind.series) {
        final seriesRows = await db.customSelect('''
          SELECT family_id AS id, MAX(title) AS label,
            MIN(deleted_at) AS deleted_at,
            (SELECT COUNT(*) FROM recurrence_occurrences o
              JOIN recurrence_series v ON v.id=o.series_id
              WHERE v.family_id=s.family_id) AS n
          FROM recurrence_series s WHERE deleted_at IS NOT NULL
          GROUP BY family_id
        ''').get();
        for (final row in seriesRows) {
          result.add(
            TrashItem(
              kind: kind,
              id: row.read<String>('id'),
              name: row.read<String>('label'),
              deletedAt: DateTime.parse(row.read<String>('deleted_at')),
              affectedTasks: row.read<int>('n'),
            ),
          );
        }
        continue;
      }
      final table = _tables[kind]!;
      final title = switch (kind) {
        TrashKind.task || TrashKind.event => 'title',
        TrashKind.session => 'starts_at',
        _ => 'name',
      };
      final rows = await db
          .customSelect(
            'SELECT id,$title AS label,deleted_at FROM $table WHERE deleted_at IS NOT NULL ORDER BY deleted_at DESC',
          )
          .get();
      for (final row in rows) {
        final id = row.read<String>('id');
        final count = kind != TrashKind.project && kind != TrashKind.category
            ? 0
            : (await db
                      .customSelect(
                        kind == TrashKind.project
                            ? 'SELECT COUNT(*) AS n FROM tasks WHERE project_id=? AND deleted_at IS NULL'
                            : 'SELECT COUNT(*) AS n FROM tasks WHERE category_id=? AND deleted_at IS NULL',
                        variables: [Variable.withString(id)],
                      )
                      .getSingle())
                  .read<int>('n');
        result.add(
          TrashItem(
            kind: kind,
            id: id,
            name: row.read<String>('label'),
            deletedAt: DateTime.parse(row.read<String>('deleted_at')),
            affectedTasks: count,
          ),
        );
      }
    }
    result.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return result;
  }

  Future<List<LifeTask>> archivedTasks() async {
    final rows = await db.customSelect('''
      SELECT t.*, o.series_id AS recurrence_series_id,
        o.ordinal AS recurrence_ordinal, o.nominal_date,
        o.disposition AS recurrence_disposition,
        o.is_edited AS recurrence_edited,
        o.is_rescheduled AS recurrence_rescheduled,
        s.kind AS recurrence_kind
      FROM tasks t LEFT JOIN recurrence_occurrences o ON o.task_id=t.id
      LEFT JOIN recurrence_series s ON s.id=o.series_id
      WHERE t.archived_at IS NOT NULL AND t.deleted_at IS NULL
      ORDER BY t.archived_at DESC
    ''').get();
    return rows.map(_taskFromRow).toList();
  }

  Future<List<ArchivedSeries>> archivedSeries() async {
    final rows = await db.customSelect('''
      SELECT family_id, MAX(title) AS title, MIN(archived_at) AS archived_at,
        (SELECT COUNT(*) FROM recurrence_occurrences o
          JOIN recurrence_series v ON v.id=o.series_id
          WHERE v.family_id=s.family_id) AS n
      FROM recurrence_series s
      WHERE archived_at IS NOT NULL AND deleted_at IS NULL
      GROUP BY family_id ORDER BY archived_at DESC
    ''').get();
    return [
      for (final row in rows)
        ArchivedSeries(
          familyId: row.read<String>('family_id'),
          title: row.read<String>('title'),
          archivedAt: DateTime.parse(row.read<String>('archived_at')),
          occurrences: row.read<int>('n'),
        ),
    ];
  }

  Future<String> _familyForTask(LifeTask task) async {
    if (task.recurrenceSeriesId == null) {
      throw ArgumentError('Task is not a recurring occurrence');
    }
    final row = await db
        .customSelect(
          '''
      SELECT s.family_id FROM recurrence_occurrences o
      JOIN recurrence_series s ON s.id=o.series_id
      JOIN tasks t ON t.id=o.task_id
      WHERE t.id=? AND t.updated_at=? AND t.deleted_at IS NULL
        AND s.deleted_at IS NULL AND s.archived_at IS NULL
    ''',
          variables: [
            Variable.withString(task.id),
            Variable.withString(task.updatedAt.toUtc().toIso8601String()),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Recurring task changed or is unavailable');
    }
    return row.read<String>('family_id');
  }

  Future<void> _requireNoFamilyTimer(String familyId) async {
    final active = await db
        .customSelect(
          '''
      SELECT 1 FROM timer_runs r JOIN recurrence_occurrences o ON o.task_id=r.task_id
      JOIN recurrence_series s ON s.id=o.series_id
      WHERE s.family_id=? AND r.state!='stopped' LIMIT 1
    ''',
          variables: [Variable.withString(familyId)],
        )
        .getSingleOrNull();
    if (active != null) throw StateError('Stop timers in this series first');
  }

  Future<void> archiveSeries(LifeTask task) async {
    await db.transaction(() async {
      final familyId = await _familyForTask(task);
      await _requireNoFamilyTimer(familyId);
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customUpdate(
        '''
        UPDATE recurrence_series SET archived_at=?,updated_at=?
        WHERE family_id=? AND archived_at IS NULL AND deleted_at IS NULL
      ''',
        variables: [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(familyId),
        ],
      );
    });
  }

  Future<void> restoreArchivedSeries(ArchivedSeries series) async {
    await db.transaction(() async {
      await _requireSeriesParents(series.familyId);
      final changed = await db.customUpdate(
        '''
        UPDATE recurrence_series SET archived_at=NULL,updated_at=?
        WHERE family_id=? AND archived_at=? AND deleted_at IS NULL
      ''',
        variables: [
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(series.familyId),
          Variable.withString(series.archivedAt.toUtc().toIso8601String()),
        ],
      );
      if (changed == 0) throw StateError('Archived series changed');
    });
  }

  Future<void> deleteSeries(LifeTask task) async {
    await db.transaction(() async {
      final familyId = await _familyForTask(task);
      await _requireNoFamilyTimer(familyId);
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customUpdate(
        '''
        UPDATE recurrence_series SET deleted_at=?,updated_at=?
        WHERE family_id=? AND deleted_at IS NULL
      ''',
        variables: [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(familyId),
        ],
      );
    });
  }

  Future<void> archiveTask(LifeTask task) async {
    await db.transaction(() async {
      await _requireActiveTask(task.id);
      await _requireNoActiveTimerForTask(task.id);
      final now = DateTime.now().toUtc().toIso8601String();
      final changed = await db.customUpdate(
        '''
        UPDATE tasks SET archived_at=?,updated_at=?
        WHERE id=? AND updated_at=? AND deleted_at IS NULL
          AND archived_at IS NULL AND
          (category_id IS NULL OR EXISTS
            (SELECT 1 FROM categories WHERE categories.id=tasks.category_id AND categories.deleted_at IS NULL)) AND
          (project_id IS NULL OR EXISTS
            (SELECT 1 FROM projects WHERE projects.id=tasks.project_id AND projects.deleted_at IS NULL))
      ''',
        variables: [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(task.id),
          Variable.withString(task.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (changed != 1) throw StateError('Task changed or is unavailable');
    });
  }

  Future<void> restoreArchivedTask(LifeTask task) async {
    await db.transaction(() async {
      await _requireAvailableParents('tasks', task.id);
      final changed = await db.customUpdate(
        '''
        UPDATE tasks SET archived_at=NULL,updated_at=?
        WHERE id=? AND updated_at=? AND archived_at IS NOT NULL
          AND deleted_at IS NULL
      ''',
        variables: [
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(task.id),
          Variable.withString(task.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (changed != 1) throw StateError('Archived task changed');
    });
  }

  Future<void> moveToTrash(TrashKind kind, String id) async {
    final table = _tables[kind]!;
    await db.transaction(() async {
      if (kind == TrashKind.task) {
        await _requireNoActiveTimerForTask(id);
      } else if (kind == TrashKind.project || kind == TrashKind.category) {
        final where = kind == TrashKind.project
            ? 't.project_id=?'
            : 't.category_id=?';
        final active = await db
            .customSelect(
              '''
          SELECT 1 FROM timer_runs r JOIN tasks t ON t.id=r.task_id
          WHERE $where AND r.state!='stopped' LIMIT 1
        ''',
              variables: [Variable.withString(id)],
            )
            .getSingleOrNull();
        if (active != null) {
          throw StateError('Stop timers in this ${kind.name} first');
        }
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final changed = await db.customUpdate(
        'UPDATE $table SET deleted_at=?,updated_at=? WHERE id=? AND deleted_at IS NULL',
        variables: [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(id),
        ],
      );
      if (changed != 1) {
        throw StateError('${kind.name} changed or is already in Trash');
      }
    });
  }

  Future<void> restoreTrashItem(TrashItem item) async {
    if (item.kind == TrashKind.series) {
      await db.transaction(() async {
        await _requireSeriesParents(item.id);
        final changed = await db.customUpdate(
          '''
          UPDATE recurrence_series SET deleted_at=NULL,updated_at=?
          WHERE family_id=? AND deleted_at=?
        ''',
          variables: [
            Variable.withString(DateTime.now().toUtc().toIso8601String()),
            Variable.withString(item.id),
            Variable.withString(item.deletedAt.toUtc().toIso8601String()),
          ],
        );
        if (changed == 0) {
          throw StateError('Trash item changed; refresh and try again');
        }
      });
      return;
    }
    final table = _tables[item.kind]!;
    await db.transaction(() async {
      if (item.kind == TrashKind.task || item.kind == TrashKind.project) {
        await _requireAvailableParents(table, item.id);
      } else if (item.kind == TrashKind.session) {
        final row = await db
            .customSelect(
              'SELECT task_id FROM work_sessions WHERE id=?',
              variables: [Variable.withString(item.id)],
            )
            .getSingleOrNull();
        if (row == null) throw StateError('Session no longer exists');
        final taskId = row.read<String>('task_id');
        final task = await db
            .customSelect(
              'SELECT 1 FROM tasks WHERE id=? AND deleted_at IS NULL AND archived_at IS NULL',
              variables: [Variable.withString(taskId)],
            )
            .getSingleOrNull();
        if (task == null) throw StateError('Restore the parent task first');
        await _requireAvailableParents('tasks', taskId);
      }
      final changed = await db.customUpdate(
        '''
        UPDATE $table SET deleted_at=NULL,updated_at=?
        WHERE id=? AND deleted_at=?
      ''',
        variables: [
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(item.id),
          Variable.withString(item.deletedAt.toUtc().toIso8601String()),
        ],
      );
      if (changed != 1) {
        throw StateError('Trash item changed; refresh and try again');
      }
    });
  }

  Future<void> permanentlyDelete(TrashItem item) async {
    if (item.kind == TrashKind.series) {
      await db.transaction(() async {
        final linked = await db
            .customSelect(
              '''
          SELECT 1 FROM recurrence_series s WHERE s.family_id=? AND (
            EXISTS(SELECT 1 FROM recurrence_occurrences o
              WHERE o.series_id=s.id AND o.task_id IS NOT NULL) OR
            EXISTS(SELECT 1 FROM series_edit_history h WHERE h.family_id=s.family_id)
          ) LIMIT 1
        ''',
              variables: [Variable.withString(item.id)],
            )
            .getSingleOrNull();
        if (linked != null) {
          throw StateError(
            'Series still has task or edit history. Resolve the linked occurrences first.',
          );
        }
        final deletedAt = item.deletedAt.toUtc().toIso8601String();
        final occurrenceRows = await db
            .customSelect(
              '''
          SELECT o.id FROM recurrence_occurrences o
          JOIN recurrence_series s ON s.id=o.series_id
          WHERE s.family_id=?
        ''',
              variables: [Variable.withString(item.id)],
            )
            .get();
        for (final row in occurrenceRows) {
          await _recordPurge(
            TrashItem(
              kind: TrashKind.series,
              id: row.read<String>('id'),
              name: '',
              deletedAt: item.deletedAt,
              affectedTasks: 0,
            ),
            deletedAt,
            entityKind: 'occurrence',
          );
        }
        final changed = await db.customUpdate(
          '''
          DELETE FROM recurrence_series WHERE family_id=? AND deleted_at=?
        ''',
          variables: [
            Variable.withString(item.id),
            Variable.withString(deletedAt),
          ],
        );
        if (changed == 0) {
          throw StateError('Trash item changed; refresh and try again');
        }
        await _recordPurge(item, deletedAt);
      });
      return;
    }
    final table = _tables[item.kind]!;
    await db.transaction(() async {
      final blockers = switch (item.kind) {
        TrashKind.task => <String>[
          'work_sessions:task_id',
          'task_dependencies:task_id',
          'task_dependencies:prerequisite_id',
          'sequence_tasks:task_id',
          'goal_task_links:task_id',
          'timer_runs:task_id',
          'time_entries:task_id',
          'scheduling_changes:target_id',
          'series_edit_history:source_task_id',
          'recurrence_collision_history:moved_task_id',
        ],
        TrashKind.project => <String>[
          'tasks:project_id',
          'recurrence_series:project_id',
          'goal_project_links:project_id',
        ],
        TrashKind.category => <String>[
          'tasks:category_id',
          'projects:category_id',
          'recurrence_series:category_id',
        ],
        TrashKind.event => <String>[],
        TrashKind.session => <String>[
          'time_entries:session_id',
          'scheduling_changes:target_id',
        ],
        TrashKind.series => throw StateError('Series purge handled separately'),
      };
      for (final blocker in blockers) {
        final parts = blocker.split(':');
        final found = await db
            .customSelect(
              'SELECT 1 FROM ${parts[0]} WHERE ${parts[1]}=? LIMIT 1',
              variables: [Variable.withString(item.id)],
            )
            .getSingleOrNull();
        if (found != null) {
          throw StateError(
            'Permanent deletion is blocked by linked ${parts[0]}. Restore this item to resolve its relationships.',
          );
        }
      }
      final deletedAt = item.deletedAt.toUtc().toIso8601String();
      final changed = await db.customUpdate(
        'DELETE FROM $table WHERE id=? AND deleted_at=?',
        variables: [
          Variable.withString(item.id),
          Variable.withString(deletedAt),
        ],
      );
      if (changed != 1) {
        throw StateError('Trash item changed; refresh and try again');
      }
      await _recordPurge(item, deletedAt);
    });
  }

  Future<void> _recordPurge(
    TrashItem item,
    String deletedAt, {
    String? entityKind,
  }) async {
    await db.customInsert(
      '''
        INSERT INTO deletion_tombstones(id,entity_kind,entity_id,deleted_at,purged_at)
        VALUES(?,?,?,?,?)
      ''',
      variables: [
        Variable.withString(_uuid.v4()),
        Variable.withString(entityKind ?? item.kind.name),
        Variable.withString(item.id),
        Variable.withString(deletedAt),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
      ],
    );
  }

  Future<void> _requireSeriesParents(String familyId) async {
    final rows = await db
        .customSelect(
          'SELECT id FROM recurrence_series WHERE family_id=?',
          variables: [Variable.withString(familyId)],
        )
        .get();
    if (rows.isEmpty) throw StateError('Series no longer exists');
    for (final row in rows) {
      await _requireAvailableParents(
        'recurrence_series',
        row.read<String>('id'),
      );
    }
  }

  Future<void> _requireNoActiveTimerForTask(String id) async {
    final active = await db
        .customSelect(
          "SELECT 1 FROM timer_runs WHERE task_id=? AND state!='stopped' LIMIT 1",
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (active != null) throw StateError('Stop the task timer first');
  }

  Future<void> _requireAvailableParents(String table, String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM $table WHERE id=?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Item no longer exists');
    final categoryId = row.read<String?>('category_id');
    if (categoryId != null) {
      final category = await db
          .customSelect(
            'SELECT 1 FROM categories WHERE id=? AND deleted_at IS NULL',
            variables: [Variable.withString(categoryId)],
          )
          .getSingleOrNull();
      if (category == null) {
        throw StateError('Restore the parent category first');
      }
    }
    if (table == 'tasks' || table == 'recurrence_series') {
      final projectId = row.read<String?>('project_id');
      if (projectId != null) {
        final project = await db
            .customSelect(
              'SELECT 1 FROM projects WHERE id=? AND deleted_at IS NULL',
              variables: [Variable.withString(projectId)],
            )
            .getSingleOrNull();
        if (project == null) {
          throw StateError('Restore the parent project first');
        }
      }
    }
    if (table == 'tasks') {
      final series = await db
          .customSelect(
            '''
        SELECT 1 FROM recurrence_occurrences o
        JOIN recurrence_series s ON s.id=o.series_id
        WHERE o.task_id=? AND (s.deleted_at IS NOT NULL OR s.archived_at IS NOT NULL)
      ''',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if (series != null) throw StateError('Restore the parent series first');
    }
  }
}
