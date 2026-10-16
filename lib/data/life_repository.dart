import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
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
        INSERT INTO tasks(id,title,notes,status,priority,category_id,project_id,scheduled_date,deadline_date,created_at,updated_at,completed_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
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

  Future<void> updateTask(LifeTask previous, TaskDraft draft) async {
    _validate(draft);
    final now = DateTime.now().toUtc();
    final completed = draft.status == TaskStatus.completed
        ? (previous.completedAt ?? now)
        : null;
    await db.transaction(() async {
      await _checkAssignment(draft.categoryId, draft.projectId);
      await db.customUpdate(
        '''
        UPDATE tasks SET title=?,notes=?,status=?,priority=?,category_id=?,project_id=?,scheduled_date=?,deadline_date=?,updated_at=?,completed_at=?
        WHERE id=?
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
          Variable.withString(previous.id),
        ],
      );
    });
  }

  Future<void> setComplete(LifeTask task, bool complete) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customUpdate(
      'UPDATE tasks SET status=?,completed_at=?,updated_at=? WHERE id=?',
      variables: [
        Variable.withString(
          complete ? TaskStatus.completed.name : TaskStatus.notStarted.name,
        ),
        Variable<String>(complete ? now : null),
        Variable.withString(now),
        Variable.withString(task.id),
      ],
    );
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
  ];

  void _validate(TaskDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('Task title is required');
    }
    if (draft.priority < 0 || draft.priority > 3) {
      throw ArgumentError('Invalid priority');
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
}
