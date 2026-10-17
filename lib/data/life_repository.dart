import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/scheduling_models.dart';
import 'app_database.dart';

class LifeRepository {
  LifeRepository(this.db);
  final AppDatabase db;
  final _uuid = const Uuid();

  Future<List<Category>> categories() async {
    final rows = await db
        .customSelect('SELECT * FROM categories ORDER BY name COLLATE NOCASE')
        .get();
    return rows
        .map(
          (r) => Category(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            createdAt: DateTime.parse(r.read<String>('created_at')),
          ),
        )
        .toList();
  }

  Future<List<Project>> projects() async {
    final rows = await db
        .customSelect('SELECT * FROM projects ORDER BY name COLLATE NOCASE')
        .get();
    return rows
        .map(
          (r) => Project(
            id: r.read<String>('id'),
            categoryId: r.read<String>('category_id'),
            name: r.read<String>('name'),
            createdAt: DateTime.parse(r.read<String>('created_at')),
          ),
        )
        .toList();
  }

  Future<List<LifeTask>> tasks() async {
    final rows = await db
        .customSelect(
          'SELECT * FROM tasks ORDER BY priority DESC, scheduled_date ASC, created_at DESC',
        )
        .get();
    return rows.map(_taskFromRow).toList();
  }

  Future<List<TaskDependency>> dependencies() async {
    final rows = await db
        .customSelect(
          'SELECT task_id, prerequisite_id FROM task_dependencies ORDER BY task_id, prerequisite_id',
        )
        .get();
    return rows
        .map(
          (row) => TaskDependency(
            taskId: row.read<String>('task_id'),
            prerequisiteId: row.read<String>('prerequisite_id'),
          ),
        )
        .toList();
  }

  /// Replaces one task's prerequisites atomically; a rejected cycle leaves the
  /// previous links intact.
  Future<void> setPrerequisites(
    LifeTask previous,
    Set<String> prerequisiteIds,
  ) async {
    final taskId = previous.id;
    if (prerequisiteIds.contains(taskId)) {
      throw ArgumentError('A task cannot depend on itself');
    }
    await db.transaction(() async {
      final existing = await db
          .customSelect(
            'SELECT updated_at FROM tasks WHERE id=?',
            variables: [Variable.withString(taskId)],
          )
          .getSingleOrNull();
      if (existing == null ||
          existing.read<String>('updated_at') !=
              previous.updatedAt.toUtc().toIso8601String()) {
        throw StateError(
          'This task changed elsewhere. Reopen it before editing prerequisites.',
        );
      }
      await db.customUpdate(
        'DELETE FROM task_dependencies WHERE task_id=?',
        variables: [Variable.withString(taskId)],
      );
      final now = DateTime.now().toUtc().toIso8601String();
      for (final prerequisiteId in prerequisiteIds) {
        final prerequisite = await db
            .customSelect(
              'SELECT id FROM tasks WHERE id=?',
              variables: [Variable.withString(prerequisiteId)],
            )
            .getSingleOrNull();
        if (prerequisite == null) {
          throw ArgumentError('Prerequisite does not exist');
        }
        final cycle = await db
            .customSelect(
              '''
          WITH RECURSIVE ancestors(id) AS (
            SELECT prerequisite_id FROM task_dependencies WHERE task_id=?
            UNION
            SELECT d.prerequisite_id FROM task_dependencies d
            JOIN ancestors a ON d.task_id=a.id
          ) SELECT 1 FROM ancestors WHERE id=? LIMIT 1
        ''',
              variables: [
                Variable.withString(prerequisiteId),
                Variable.withString(taskId),
              ],
            )
            .getSingleOrNull();
        if (cycle != null) {
          throw ArgumentError('Dependency would create a cycle');
        }
        await db.customInsert(
          '''
          INSERT INTO task_dependencies(task_id,prerequisite_id,created_at)
          VALUES(?,?,?)
        ''',
          variables: [
            Variable.withString(taskId),
            Variable.withString(prerequisiteId),
            Variable.withString(now),
          ],
        );
      }
      await db.customUpdate(
        'UPDATE tasks SET updated_at=? WHERE id=?',
        variables: [Variable.withString(now), Variable.withString(taskId)],
      );
    });
  }

  Future<List<TaskSequence>> sequences() async {
    final rows = await db
        .customSelect(
          'SELECT * FROM task_sequences ORDER BY name COLLATE NOCASE, id',
        )
        .get();
    final memberships = await db
        .customSelect(
          'SELECT sequence_id,task_id FROM sequence_tasks ORDER BY sequence_id,position',
        )
        .get();
    final taskIdsBySequence = <String, List<String>>{};
    for (final row in memberships) {
      taskIdsBySequence
          .putIfAbsent(row.read<String>('sequence_id'), () => [])
          .add(row.read<String>('task_id'));
    }
    return rows
        .map(
          (row) => TaskSequence(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            taskIds: taskIdsBySequence[row.read<String>('id')] ?? const [],
            createdAt: DateTime.parse(row.read<String>('created_at')),
            updatedAt: DateTime.parse(row.read<String>('updated_at')),
          ),
        )
        .toList();
  }

  Future<TaskSequence> addSequence(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Sequence name is required');
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      'INSERT INTO task_sequences(id,name,created_at,updated_at) VALUES(?,?,?,?)',
      variables: [
        Variable.withString(id),
        Variable.withString(cleaned),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await sequences()).firstWhere((sequence) => sequence.id == id);
  }

  Future<void> renameSequence(TaskSequence previous, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Sequence name is required');
    final count = await db.customUpdate(
      '''
      UPDATE task_sequences SET name=?,updated_at=? WHERE id=? AND updated_at=?
    ''',
      variables: [
        Variable.withString(cleaned),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Sequence changed elsewhere. Reopen it.');
  }

  Future<void> deleteSequence(TaskSequence previous) async {
    final deleted = await db.customUpdate(
      'DELETE FROM task_sequences WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (deleted != 1) {
      throw StateError('Sequence changed elsewhere. Reopen it.');
    }
  }

  Future<void> setSequenceTasks(
    TaskSequence previous,
    List<String> taskIds,
  ) async {
    if (taskIds.length != taskIds.toSet().length) {
      throw ArgumentError('A task may appear only once in a sequence');
    }
    await db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT updated_at FROM task_sequences WHERE id=?',
            variables: [Variable.withString(previous.id)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') !=
              previous.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Sequence changed elsewhere. Reopen it.');
      }
      await db.customUpdate(
        'DELETE FROM sequence_tasks WHERE sequence_id=?',
        variables: [Variable.withString(previous.id)],
      );
      for (var position = 0; position < taskIds.length; position++) {
        await db.customInsert(
          '''
          INSERT INTO sequence_tasks(sequence_id,task_id,position) VALUES(?,?,?)
        ''',
          variables: [
            Variable.withString(previous.id),
            Variable.withString(taskIds[position]),
            Variable.withInt(position),
          ],
        );
      }
      await db.customUpdate(
        'UPDATE task_sequences SET updated_at=? WHERE id=?',
        variables: [
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
          Variable.withString(previous.id),
        ],
      );
    });
  }

  Future<List<FixedEvent>> events() async {
    final rows = await db
        .customSelect('SELECT * FROM fixed_events ORDER BY starts_at')
        .get();
    return rows
        .map(
          (r) => FixedEvent(
            id: r.read<String>('id'),
            title: r.read<String>('title'),
            notes: r.read<String>('notes'),
            startsAt: DateTime.parse(r.read<String>('starts_at')),
            endsAt: DateTime.parse(r.read<String>('ends_at')),
            createdAt: DateTime.parse(r.read<String>('created_at')),
            updatedAt: DateTime.parse(r.read<String>('updated_at')),
          ),
        )
        .toList();
  }

  Future<FixedEvent> addEvent(EventDraft draft) async {
    _validateEvent(draft);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      '''
      INSERT INTO fixed_events(id,title,notes,starts_at,ends_at,created_at,updated_at)
      VALUES(?,?,?,?,?,?,?)
    ''',
      variables: [
        Variable.withString(id),
        Variable.withString(draft.title.trim()),
        Variable.withString(draft.notes),
        Variable.withString(draft.startsAt.toUtc().toIso8601String()),
        Variable.withString(draft.endsAt.toUtc().toIso8601String()),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await events()).firstWhere((event) => event.id == id);
  }

  Future<void> updateEvent(FixedEvent previous, EventDraft draft) async {
    _validateEvent(draft);
    await db.customUpdate(
      '''
      UPDATE fixed_events SET title=?,notes=?,starts_at=?,ends_at=?,updated_at=?
      WHERE id=?
    ''',
      variables: [
        Variable.withString(draft.title.trim()),
        Variable.withString(draft.notes),
        Variable.withString(draft.startsAt.toUtc().toIso8601String()),
        Variable.withString(draft.endsAt.toUtc().toIso8601String()),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(previous.id),
      ],
    );
  }

  Future<void> deleteEvent(String id) async {
    await db.customUpdate(
      'DELETE FROM fixed_events WHERE id=?',
      variables: [Variable.withString(id)],
    );
  }

  Future<List<WorkSession>> sessions() async {
    final rows = await db
        .customSelect('SELECT * FROM work_sessions ORDER BY starts_at')
        .get();
    return rows
        .map(
          (r) => WorkSession(
            id: r.read<String>('id'),
            taskId: r.read<String>('task_id'),
            startsAt: DateTime.parse(r.read<String>('starts_at')),
            endsAt: DateTime.parse(r.read<String>('ends_at')),
            outcome: SessionOutcome.values.byName(r.read<String>('outcome')),
            actualStartedAt: _parseNullable(
              r.read<String?>('actual_started_at'),
            ),
            createdAt: DateTime.parse(r.read<String>('created_at')),
            updatedAt: DateTime.parse(r.read<String>('updated_at')),
          ),
        )
        .toList();
  }

  Future<WorkSession> addSession(SessionDraft draft) async {
    _validateSession(draft);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      '''
      INSERT INTO work_sessions(id,task_id,starts_at,ends_at,outcome,actual_started_at,created_at,updated_at)
      VALUES(?,?,?,?,?,?,?,?)
    ''',
      variables: [
        Variable.withString(id),
        Variable.withString(draft.taskId),
        Variable.withString(draft.startsAt.toUtc().toIso8601String()),
        Variable.withString(draft.endsAt.toUtc().toIso8601String()),
        Variable.withString(draft.outcome.name),
        Variable<String>(
          draft.outcome == SessionOutcome.inProgress ? now : null,
        ),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await sessions()).firstWhere((session) => session.id == id);
  }

  Future<void> updateSession(WorkSession previous, SessionDraft draft) async {
    _validateSession(draft);
    final now = DateTime.now().toUtc().toIso8601String();
    final actualStart =
        previous.actualStartedAt?.toUtc().toIso8601String() ??
        (draft.outcome == SessionOutcome.inProgress ? now : null);
    await db.transaction(() async {
      final updated = await db.customUpdate(
        '''
      UPDATE work_sessions SET task_id=?,starts_at=?,ends_at=?,outcome=?,actual_started_at=?,updated_at=?
      WHERE id=? AND updated_at=?
    ''',
        variables: [
          Variable.withString(draft.taskId),
          Variable.withString(draft.startsAt.toUtc().toIso8601String()),
          Variable.withString(draft.endsAt.toUtc().toIso8601String()),
          Variable.withString(draft.outcome.name),
          Variable<String>(actualStart),
          Variable.withString(now),
          Variable.withString(previous.id),
          Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (updated != 1) {
        throw StateError(
          'This work session changed elsewhere. Reopen it before saving.',
        );
      }
      final nextStart = draft.startsAt.toUtc();
      final nextEnd = draft.endsAt.toUtc();
      if (previous.startsAt != nextStart || previous.endsAt != nextEnd) {
        await _recordOperation(
          type: ScheduleOperationType.move,
          source: ScheduleChangeSource.manual,
          scope: 'session:${previous.id}',
          changes: [
            ScheduleHistoryChange(
              targetKind: ScheduleTargetKind.session,
              targetId: previous.id,
              beforeStartsAt: previous.startsAt,
              beforeEndsAt: previous.endsAt,
              afterStartsAt: nextStart,
              afterEndsAt: nextEnd,
              beforeUpdatedAt: previous.updatedAt,
              afterUpdatedAt: DateTime.parse(now),
            ),
          ],
        );
      }
    });
  }

  Future<void> deleteSession(String id) async {
    await db.customUpdate(
      'DELETE FROM work_sessions WHERE id=?',
      variables: [Variable.withString(id)],
    );
  }

  void _validateSession(SessionDraft draft) {
    if (!draft.endsAt.isAfter(draft.startsAt)) {
      throw ArgumentError('Session end must be after its start');
    }
  }

  void _validateEvent(EventDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('Event title is required');
    }
    if (!draft.endsAt.isAfter(draft.startsAt)) {
      throw ArgumentError('Event end must be after its start');
    }
  }

  LifeTask _taskFromRow(QueryRow r) => LifeTask(
    id: r.read<String>('id'),
    title: r.read<String>('title'),
    notes: r.read<String>('notes'),
    status: TaskStatus.values.byName(r.read<String>('status')),
    priority: r.read<int>('priority'),
    categoryId: r.read<String?>('category_id'),
    projectId: r.read<String?>('project_id'),
    scheduledDate: r.read<String?>('scheduled_date'),
    deadlineDate: r.read<String?>('deadline_date'),
    createdAt: DateTime.parse(r.read<String>('created_at')),
    updatedAt: DateTime.parse(r.read<String>('updated_at')),
    completedAt: _parseNullable(r.read<String?>('completed_at')),
    plannedDurationMinutes: r.read<int?>('planned_duration_minutes'),
    remainingWorkMinutes: r.read<int?>('remaining_work_minutes'),
    schedulingLocked: r.read<int>('scheduling_locked') == 1,
  );

  DateTime? _parseNullable(String? value) =>
      value == null ? null : DateTime.parse(value);

  Future<Category> addCategory(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Category name is required');
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await db.customInsert(
      'INSERT INTO categories(id,name,created_at,updated_at) VALUES(?,?,?,?)',
      variables: [
        Variable.withString(id),
        Variable.withString(cleaned),
        Variable.withString(now.toIso8601String()),
        Variable.withString(now.toIso8601String()),
      ],
    );
    return Category(id: id, name: cleaned, createdAt: now);
  }

  Future<void> renameCategory(String id, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Category name is required');
    await db.customUpdate(
      'UPDATE categories SET name=?, updated_at=? WHERE id=?',
      variables: [
        Variable.withString(cleaned),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(id),
      ],
    );
  }

  Future<Project> addProject(String categoryId, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Project name is required');
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await db.customInsert(
      'INSERT INTO projects(id,category_id,name,created_at,updated_at) VALUES(?,?,?,?,?)',
      variables: [
        Variable.withString(id),
        Variable.withString(categoryId),
        Variable.withString(cleaned),
        Variable.withString(now.toIso8601String()),
        Variable.withString(now.toIso8601String()),
      ],
    );
    return Project(
      id: id,
      categoryId: categoryId,
      name: cleaned,
      createdAt: now,
    );
  }

  Future<void> renameProject(String id, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Project name is required');
    await db.customUpdate(
      'UPDATE projects SET name=?, updated_at=? WHERE id=?',
      variables: [
        Variable.withString(cleaned),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(id),
      ],
    );
  }

  Future<LifeTask> addTask(TaskDraft draft) async {
    _validate(draft);
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await db.transaction(() async {
      await _checkAssignment(draft.categoryId, draft.projectId);
      await db.customInsert(
        '''
        INSERT INTO tasks(id,title,notes,status,priority,category_id,project_id,scheduled_date,deadline_date,created_at,updated_at,completed_at,planned_duration_minutes,remaining_work_minutes,scheduling_locked)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ''',
        variables: _taskValues(
          id,
          draft,
          now,
          now,
          draft.status == TaskStatus.completed ? now : null,
        ),
      );
    });
    return (await tasks()).firstWhere((task) => task.id == id);
  }

  Future<void> updateTask(
    LifeTask previous,
    TaskDraft draft, {
    Set<String> reviewedPrerequisiteIds = const {},
  }) async {
    _validate(draft);
    final now = DateTime.now().toUtc();
    final completed = draft.status == TaskStatus.completed
        ? (previous.completedAt ?? now)
        : null;
    await db.transaction(() async {
      await _checkAssignment(draft.categoryId, draft.projectId);
      if (draft.scheduledDate != null &&
          draft.scheduledDate != previous.scheduledDate) {
        final prerequisites = await db
            .customSelect(
              '''
          SELECT p.id,p.status,p.scheduled_date FROM task_dependencies d
          JOIN tasks p ON p.id=d.prerequisite_id WHERE d.task_id=?
        ''',
              variables: [Variable.withString(previous.id)],
            )
            .get();
        for (final prerequisite in prerequisites) {
          final day = prerequisite.read<String?>('scheduled_date');
          if (prerequisite.read<String>('status') ==
                  TaskStatus.completed.name ||
              (day != null && draft.scheduledDate!.compareTo(day) > 0)) {
            continue;
          }
          if (!reviewedPrerequisiteIds.contains(
            prerequisite.read<String>('id'),
          )) {
            throw StateError(
              'Prerequisites changed. Review the planned date again.',
            );
          }
        }
      }
      final updated = await db.customUpdate(
        '''
        UPDATE tasks SET title=?,notes=?,status=?,priority=?,category_id=?,project_id=?,scheduled_date=?,deadline_date=?,updated_at=?,completed_at=?,planned_duration_minutes=?,remaining_work_minutes=?,scheduling_locked=?
        WHERE id=? AND updated_at=?
      ''',
        variables: [
          Variable.withString(draft.title.trim()),
          Variable.withString(draft.notes),
          Variable.withString(draft.status.name),
          Variable.withInt(draft.priority),
          Variable<String>(draft.categoryId),
          Variable<String>(draft.projectId),
          Variable<String>(draft.scheduledDate),
          Variable<String>(draft.deadlineDate),
          Variable.withString(now.toIso8601String()),
          Variable<String>(completed?.toIso8601String()),
          Variable<int>(draft.plannedDurationMinutes),
          Variable<int>(draft.remainingWorkMinutes),
          Variable.withInt(draft.schedulingLocked ? 1 : 0),
          Variable.withString(previous.id),
          Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (updated != 1) {
        throw StateError(
          'This task changed elsewhere. Reopen it before saving.',
        );
      }
      if (previous.scheduledDate != draft.scheduledDate) {
        await _recordOperation(
          type: ScheduleOperationType.move,
          source: ScheduleChangeSource.manual,
          scope: 'task:${previous.id}',
          changes: [
            ScheduleHistoryChange(
              targetKind: ScheduleTargetKind.task,
              targetId: previous.id,
              beforeDate: previous.scheduledDate,
              afterDate: draft.scheduledDate,
              beforeUpdatedAt: previous.updatedAt,
              afterUpdatedAt: now,
            ),
          ],
        );
      }
    });
  }

  Future<void> setComplete(LifeTask task, bool complete) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await db.customUpdate(
      'UPDATE tasks SET status=?,completed_at=?,updated_at=? WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(
          complete ? TaskStatus.completed.name : TaskStatus.notStarted.name,
        ),
        Variable<String>(complete ? now : null),
        Variable.withString(now),
        Variable.withString(task.id),
        Variable.withString(task.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (updated != 1) {
      throw StateError(
        'This task changed elsewhere. Reopen it before changing completion.',
      );
    }
  }

  Future<void> deleteTask(String id) async {
    await db.customUpdate(
      'DELETE FROM tasks WHERE id=?',
      variables: [Variable.withString(id)],
    );
  }

  Future<void> deleteProject(String id) async {
    await db.customUpdate(
      'DELETE FROM projects WHERE id=?',
      variables: [Variable.withString(id)],
    );
  }

  Future<void> deleteCategory(String id) async {
    await db.customUpdate(
      'DELETE FROM categories WHERE id=?',
      variables: [Variable.withString(id)],
    );
  }

  List<Variable> _taskValues(
    String id,
    TaskDraft draft,
    DateTime created,
    DateTime updated,
    DateTime? completed,
  ) => [
    Variable.withString(id),
    Variable.withString(draft.title.trim()),
    Variable.withString(draft.notes),
    Variable.withString(draft.status.name),
    Variable.withInt(draft.priority),
    Variable<String>(draft.categoryId),
    Variable<String>(draft.projectId),
    Variable<String>(draft.scheduledDate),
    Variable<String>(draft.deadlineDate),
    Variable.withString(created.toIso8601String()),
    Variable.withString(updated.toIso8601String()),
    Variable<String>(completed?.toIso8601String()),
    Variable<int>(draft.plannedDurationMinutes),
    Variable<int>(draft.remainingWorkMinutes),
    Variable.withInt(draft.schedulingLocked ? 1 : 0),
  ];

  void _validate(TaskDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('Task title is required');
    }
    if (draft.priority < 0 || draft.priority > 3) {
      throw ArgumentError('Invalid priority');
    }
    if (draft.plannedDurationMinutes != null &&
        draft.plannedDurationMinutes! <= 0) {
      throw ArgumentError('Planned duration must be positive');
    }
    if (draft.remainingWorkMinutes != null && draft.remainingWorkMinutes! < 0) {
      throw ArgumentError('Remaining work cannot be negative');
    }
    for (final date in [draft.scheduledDate, draft.deadlineDate]) {
      if (date != null && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        throw ArgumentError('Invalid date');
      }
    }
  }

  Future<void> _checkAssignment(String? categoryId, String? projectId) async {
    if (projectId == null) return;
    final rows = await db
        .customSelect(
          'SELECT category_id FROM projects WHERE id=?',
          variables: [Variable.withString(projectId)],
        )
        .get();
    if (rows.isEmpty || rows.single.read<String>('category_id') != categoryId) {
      throw ArgumentError('Project must belong to selected category');
    }
  }

  Future<AvailabilityPlan> availability() async {
    final weeklyRows = await db
        .customSelect(
          'SELECT weekday,start_minute,end_minute FROM availability_windows ORDER BY weekday,start_minute',
        )
        .get();
    final exceptionRows = await db
        .customSelect(
          'SELECT local_date,start_minute,end_minute FROM availability_exceptions ORDER BY local_date,start_minute',
        )
        .get();
    final weekly = <int, List<AvailabilityWindow>>{};
    for (final row in weeklyRows) {
      weekly
          .putIfAbsent(row.read<int>('weekday'), () => [])
          .add(
            AvailabilityWindow(
              row.read<int>('start_minute'),
              row.read<int>('end_minute'),
            ),
          );
    }
    final exceptions = <String, List<AvailabilityWindow>>{};
    for (final row in exceptionRows) {
      final date = row.read<String>('local_date');
      final start = row.read<int?>('start_minute');
      final end = row.read<int?>('end_minute');
      final windows = exceptions.putIfAbsent(date, () => []);
      if (start != null && end != null) {
        windows.add(AvailabilityWindow(start, end));
      }
    }
    return AvailabilityPlan(weekly: weekly, exceptions: exceptions);
  }

  Future<void> saveAvailability(AvailabilityPlan plan) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await db.customUpdate('DELETE FROM availability_windows');
      await db.customUpdate('DELETE FROM availability_exceptions');
      for (final entry in plan.weekly.entries) {
        for (final window in entry.value) {
          await db.customInsert(
            'INSERT INTO availability_windows(id,weekday,start_minute,end_minute,created_at,updated_at) VALUES(?,?,?,?,?,?)',
            variables: [
              Variable.withString(_uuid.v4()),
              Variable.withInt(entry.key),
              Variable.withInt(window.startMinute),
              Variable.withInt(window.endMinute),
              Variable.withString(now),
              Variable.withString(now),
            ],
          );
        }
      }
      for (final entry in plan.exceptions.entries) {
        if (entry.value.isEmpty) {
          await db.customInsert(
            'INSERT INTO availability_exceptions(id,local_date,start_minute,end_minute,created_at,updated_at) VALUES(?,?,NULL,NULL,?,?)',
            variables: [
              Variable.withString(_uuid.v4()),
              Variable.withString(entry.key),
              Variable.withString(now),
              Variable.withString(now),
            ],
          );
        } else {
          for (final window in entry.value) {
            await db.customInsert(
              'INSERT INTO availability_exceptions(id,local_date,start_minute,end_minute,created_at,updated_at) VALUES(?,?,?,?,?,?)',
              variables: [
                Variable.withString(_uuid.v4()),
                Variable.withString(entry.key),
                Variable.withInt(window.startMinute),
                Variable.withInt(window.endMinute),
                Variable.withString(now),
                Variable.withString(now),
              ],
            );
          }
        }
      }
    });
  }

  Future<String> applySchedulingPreview(SchedulingPreview preview) async {
    if (!preview.canApply) {
      throw StateError('The scheduling preview contains hard conflicts');
    }
    final operationId = _uuid.v4();
    await db.transaction(() async {
      final stale = <String>[];
      for (final change in preview.changes) {
        if (change.createsSession) {
          final duplicate = await db
              .customSelect(
                'SELECT id FROM work_sessions WHERE id=?',
                variables: [Variable.withString(change.targetId)],
              )
              .get();
          if (duplicate.isNotEmpty) stale.add(change.targetId);
          continue;
        }
        final table = change.targetKind == ScheduleTargetKind.task
            ? 'tasks'
            : 'work_sessions';
        final row = await db
            .customSelect(
              'SELECT * FROM $table WHERE id=?',
              variables: [Variable.withString(change.targetId)],
            )
            .getSingleOrNull();
        if (row == null ||
            DateTime.parse(row.read<String>('updated_at')) !=
                change.expectedUpdatedAt ||
            !_scheduleMatches(row, change)) {
          stale.add(change.targetId);
        }
      }
      if (stale.isNotEmpty) throw StaleSchedulePreviewException(stale);

      final proposedTaskDays = <String, String?>{
        for (final change in preview.changes)
          if (change.targetKind == ScheduleTargetKind.task)
            change.targetId: change.afterDate,
      };
      for (final change in preview.changes) {
        final taskId = change.targetKind == ScheduleTargetKind.task
            ? change.targetId
            : change.taskId ??
                  (await db
                          .customSelect(
                            'SELECT task_id FROM work_sessions WHERE id=?',
                            variables: [Variable.withString(change.targetId)],
                          )
                          .getSingleOrNull())
                      ?.read<String>('task_id');
        final proposedDay = change.targetKind == ScheduleTargetKind.task
            ? change.afterDate
            : change.afterStartsAt == null
            ? null
            : localDate(change.afterStartsAt!.toLocal());
        if (taskId == null || proposedDay == null) continue;
        final prerequisites = await db
            .customSelect(
              '''
          SELECT p.id,p.status,p.scheduled_date FROM task_dependencies d
          JOIN tasks p ON p.id=d.prerequisite_id WHERE d.task_id=?
        ''',
              variables: [Variable.withString(taskId)],
            )
            .get();
        for (final prerequisite in prerequisites) {
          final prerequisiteId = prerequisite.read<String>('id');
          final prerequisiteDay = proposedTaskDays.containsKey(prerequisiteId)
              ? proposedTaskDays[prerequisiteId]
              : prerequisite.read<String?>('scheduled_date');
          if (prerequisite.read<String>('status') ==
                  TaskStatus.completed.name ||
              (prerequisiteDay != null &&
                  proposedDay.compareTo(prerequisiteDay) > 0)) {
            continue;
          }
          final reviewed = preview.issues.any(
            (issue) =>
                issue.kind == ScheduleIssueKind.dependencyOrder &&
                issue.targetId == change.targetId &&
                issue.relatedId == prerequisiteId,
          );
          if (!reviewed) throw StaleSchedulePreviewException([change.targetId]);
        }
      }

      final now = DateTime.now().toUtc();
      final history = <ScheduleHistoryChange>[];
      for (final change in preview.changes) {
        if (change.targetKind == ScheduleTargetKind.task) {
          await db.customUpdate(
            'UPDATE tasks SET scheduled_date=?,updated_at=? WHERE id=?',
            variables: [
              Variable<String>(change.afterDate),
              Variable.withString(now.toIso8601String()),
              Variable.withString(change.targetId),
            ],
          );
        } else if (change.createsSession) {
          await db.customInsert(
            '''
            INSERT INTO work_sessions(id,task_id,starts_at,ends_at,outcome,actual_started_at,created_at,updated_at)
            VALUES(?,?,?,?,'upcoming',NULL,?,?)
          ''',
            variables: [
              Variable.withString(change.targetId),
              Variable.withString(change.taskId!),
              Variable.withString(
                change.afterStartsAt!.toUtc().toIso8601String(),
              ),
              Variable.withString(
                change.afterEndsAt!.toUtc().toIso8601String(),
              ),
              Variable.withString(now.toIso8601String()),
              Variable.withString(now.toIso8601String()),
            ],
          );
        } else if (change.deleteSession) {
          await db.customUpdate(
            'DELETE FROM work_sessions WHERE id=?',
            variables: [Variable.withString(change.targetId)],
          );
        } else {
          await db.customUpdate(
            'UPDATE work_sessions SET starts_at=?,ends_at=?,updated_at=? WHERE id=?',
            variables: [
              Variable.withString(
                change.afterStartsAt!.toUtc().toIso8601String(),
              ),
              Variable.withString(
                change.afterEndsAt!.toUtc().toIso8601String(),
              ),
              Variable.withString(now.toIso8601String()),
              Variable.withString(change.targetId),
            ],
          );
        }
        history.add(
          ScheduleHistoryChange(
            targetKind: change.targetKind,
            targetId: change.targetId,
            beforeDate: change.beforeDate,
            afterDate: change.afterDate,
            beforeStartsAt: change.beforeStartsAt,
            beforeEndsAt: change.beforeEndsAt,
            afterStartsAt: change.afterStartsAt,
            afterEndsAt: change.afterEndsAt,
            beforeUpdatedAt: change.createsSession
                ? null
                : change.expectedUpdatedAt,
            afterUpdatedAt: now,
          ),
        );
      }
      await _recordOperation(
        id: operationId,
        type: preview.operation,
        source: ScheduleChangeSource.smartReschedule,
        scope: preview.scope,
        changes: history,
        revertsOperationId:
            preview.operation == ScheduleOperationType.undo ||
                preview.operation == ScheduleOperationType.restorePrevious ||
                preview.operation == ScheduleOperationType.restoreOriginal
            ? preview.scope.split(':').last
            : null,
      );
    });
    return operationId;
  }

  bool _scheduleMatches(QueryRow row, ScheduleChange change) {
    if (change.targetKind == ScheduleTargetKind.task) {
      return row.read<String?>('scheduled_date') == change.beforeDate;
    }
    return DateTime.parse(row.read<String>('starts_at')) ==
            change.beforeStartsAt &&
        DateTime.parse(row.read<String>('ends_at')) == change.beforeEndsAt;
  }

  Future<List<SchedulingOperation>> schedulingHistory({int limit = 50}) async {
    final operationRows = await db
        .customSelect(
          'SELECT * FROM scheduling_operations ORDER BY created_at DESC LIMIT ?',
          variables: [Variable.withInt(limit)],
        )
        .get();
    final result = <SchedulingOperation>[];
    for (final operation in operationRows) {
      final id = operation.read<String>('id');
      final rows = await db
          .customSelect(
            'SELECT * FROM scheduling_changes WHERE operation_id=? ORDER BY rowid',
            variables: [Variable.withString(id)],
          )
          .get();
      result.add(
        SchedulingOperation(
          id: id,
          type: ScheduleOperationType.values.byName(
            operation.read<String>('operation_type'),
          ),
          source: ScheduleChangeSource.values.byName(
            operation.read<String>('source'),
          ),
          scope: operation.read<String>('scope'),
          createdAt: DateTime.parse(operation.read<String>('created_at')),
          revertsOperationId: operation.read<String?>('reverts_operation_id'),
          changes: rows.map(_historyChangeFromRow).toList(),
        ),
      );
    }
    return result;
  }

  ScheduleHistoryChange _historyChangeFromRow(QueryRow row) =>
      ScheduleHistoryChange(
        targetKind: ScheduleTargetKind.values.byName(
          row.read<String>('target_kind'),
        ),
        targetId: row.read<String>('target_id'),
        beforeDate: row.read<String?>('before_date'),
        afterDate: row.read<String?>('after_date'),
        beforeStartsAt: _parseNullable(row.read<String?>('before_starts_at')),
        beforeEndsAt: _parseNullable(row.read<String?>('before_ends_at')),
        afterStartsAt: _parseNullable(row.read<String?>('after_starts_at')),
        afterEndsAt: _parseNullable(row.read<String?>('after_ends_at')),
        beforeUpdatedAt: _parseNullable(row.read<String?>('before_updated_at')),
        afterUpdatedAt: _parseNullable(row.read<String?>('after_updated_at')),
      );

  Future<SchedulingPreview> previewRestore(
    String operationId, {
    bool original = false,
    bool undo = false,
  }) async {
    final operations = await schedulingHistory(limit: 500);
    final selected = operations
        .where((item) => item.id == operationId)
        .firstOrNull;
    if (selected == null) throw ArgumentError('Scheduling operation not found');
    final issues = <ScheduleIssue>[];
    final changes = <ScheduleChange>[];
    for (final historical in selected.changes) {
      final current = await _currentSchedule(
        historical.targetKind,
        historical.targetId,
      );
      if (current == null) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.stale,
            severity: ScheduleIssueSeverity.warning,
            targetId: historical.targetId,
            message: 'Item no longer exists and cannot be restored.',
          ),
        );
        continue;
      }
      if (!current.eligible) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.completed,
            severity: ScheduleIssueSeverity.warning,
            targetId: historical.targetId,
            message: 'Completed, started, cancelled, or protected work is preserved.',
          ),
        );
        continue;
      }
      if (!_currentMatchesAfter(current, historical)) {
        issues.add(
          ScheduleIssue(
            kind: ScheduleIssueKind.stale,
            severity: ScheduleIssueSeverity.warning,
            targetId: historical.targetId,
            message: 'Later scheduling changes are protected for this item.',
          ),
        );
        continue;
      }
      var desired = historical;
      if (original) {
        final chronological = operations.reversed
            .expand((item) => item.changes)
            .where(
              (change) =>
                  change.targetKind == historical.targetKind &&
                  change.targetId == historical.targetId,
            );
        if (chronological.isNotEmpty) desired = chronological.first;
      }
      changes.add(
        ScheduleChange(
          targetKind: historical.targetKind,
          targetId: historical.targetId,
          expectedUpdatedAt: current.updatedAt,
          beforeDate: current.date,
          afterDate: desired.beforeDate,
          beforeStartsAt: current.startsAt,
          beforeEndsAt: current.endsAt,
          afterStartsAt: desired.beforeStartsAt,
          afterEndsAt: desired.beforeEndsAt,
          deleteSession:
              historical.targetKind == ScheduleTargetKind.session &&
              desired.beforeStartsAt == null &&
              desired.beforeEndsAt == null,
        ),
      );
    }
    return SchedulingPreview(
      operation: undo
          ? ScheduleOperationType.undo
          : original
          ? ScheduleOperationType.restoreOriginal
          : ScheduleOperationType.restorePrevious,
      scope: '${undo ? 'undo' : 'restore'}:$operationId',
      changes: changes,
      issues: issues,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<_CurrentSchedule?> _currentSchedule(
    ScheduleTargetKind kind,
    String id,
  ) async {
    final table = kind == ScheduleTargetKind.task ? 'tasks' : 'work_sessions';
    final row = await db
        .customSelect(
          'SELECT * FROM $table WHERE id=?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return _CurrentSchedule(
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
      eligible: kind == ScheduleTargetKind.task
          ? row.read<String>('status') != TaskStatus.completed.name &&
                row.read<String>('status') != TaskStatus.cancelled.name &&
                row.read<int>('scheduling_locked') == 0
          : row.read<String>('outcome') != SessionOutcome.completed.name &&
                row.read<String>('outcome') != SessionOutcome.inProgress.name,
      date: kind == ScheduleTargetKind.task
          ? row.read<String?>('scheduled_date')
          : null,
      startsAt: kind == ScheduleTargetKind.session
          ? DateTime.parse(row.read<String>('starts_at'))
          : null,
      endsAt: kind == ScheduleTargetKind.session
          ? DateTime.parse(row.read<String>('ends_at'))
          : null,
    );
  }

  bool _currentMatchesAfter(
    _CurrentSchedule current,
    ScheduleHistoryChange history,
  ) => history.targetKind == ScheduleTargetKind.task
      ? current.date == history.afterDate
      : current.startsAt == history.afterStartsAt &&
            current.endsAt == history.afterEndsAt;

  Future<String> _recordOperation({
    String? id,
    required ScheduleOperationType type,
    required ScheduleChangeSource source,
    required String scope,
    required List<ScheduleHistoryChange> changes,
    String? revertsOperationId,
  }) async {
    final operationId = id ?? _uuid.v4();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      'INSERT INTO scheduling_operations(id,operation_type,source,scope,created_at,reverts_operation_id) VALUES(?,?,?,?,?,?)',
      variables: [
        Variable.withString(operationId),
        Variable.withString(type.name),
        Variable.withString(source.name),
        Variable.withString(scope),
        Variable.withString(createdAt),
        Variable<String>(revertsOperationId),
      ],
    );
    for (final change in changes) {
      await db.customInsert(
        '''
        INSERT INTO scheduling_changes(
          id,operation_id,target_kind,target_id,before_date,after_date,
          before_starts_at,before_ends_at,after_starts_at,after_ends_at,
          before_updated_at,after_updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
      ''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(operationId),
          Variable.withString(change.targetKind.name),
          Variable.withString(change.targetId),
          Variable<String>(change.beforeDate),
          Variable<String>(change.afterDate),
          Variable<String>(change.beforeStartsAt?.toUtc().toIso8601String()),
          Variable<String>(change.beforeEndsAt?.toUtc().toIso8601String()),
          Variable<String>(change.afterStartsAt?.toUtc().toIso8601String()),
          Variable<String>(change.afterEndsAt?.toUtc().toIso8601String()),
          Variable<String>(change.beforeUpdatedAt?.toUtc().toIso8601String()),
          Variable<String>(change.afterUpdatedAt?.toUtc().toIso8601String()),
        ],
      );
    }
    return operationId;
  }
}

class _CurrentSchedule {
  const _CurrentSchedule({
    required this.updatedAt,
    required this.eligible,
    this.date,
    this.startsAt,
    this.endsAt,
  });
  final DateTime updatedAt;
  final bool eligible;
  final String? date;
  final DateTime? startsAt;
  final DateTime? endsAt;
}
