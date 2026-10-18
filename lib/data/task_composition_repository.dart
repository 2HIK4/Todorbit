part of 'life_repository.dart';

extension TaskCompositionRepository on LifeRepository {
  Future<Map<String, String>> taskParents() async {
    final rows = await db
        .customSelect('SELECT child_id,parent_id FROM task_parent_links')
        .get();
    return {
      for (final row in rows)
        row.read<String>('child_id'): row.read<String>('parent_id'),
    };
  }

  Future<LifeTask> addSubtask(LifeTask parent, TaskDraft draft) async {
    if (!parent.isOpen) throw StateError('Closed parent cannot add subtasks');
    late LifeTask child;
    await db.transaction(() async {
      final row = await db
          .customSelect(
            '''SELECT 1 FROM tasks WHERE id=?
        AND updated_at=? AND deleted_at IS NULL AND archived_at IS NULL''',
            variables: [
              Variable.withString(parent.id),
              Variable.withString(parent.updatedAt.toUtc().toIso8601String()),
            ],
          )
          .getSingleOrNull();
      if (row == null) throw StateError('Parent task changed');
      final ancestor = await db
          .customSelect(
            '''SELECT 1 FROM task_parent_links
        WHERE child_id=?''',
            variables: [Variable.withString(parent.id)],
          )
          .getSingleOrNull();
      if (ancestor != null) {
        throw StateError('Only one level of subtasks is supported');
      }
      child = await addTask(draft);
      await db.customInsert(
        '''INSERT INTO task_parent_links(child_id,parent_id)
        VALUES(?,?)''',
        variables: [
          Variable.withString(child.id),
          Variable.withString(parent.id),
        ],
      );
    });
    return child;
  }

  Future<List<TaskChecklistItem>> checklistItems() async {
    final rows = await db.customSelect('''SELECT * FROM task_checklist
      ORDER BY task_id,position,created_at''').get();
    return [
      for (final row in rows)
        TaskChecklistItem(
          id: row.read<String>('id'),
          taskId: row.read<String>('task_id'),
          title: row.read<String>('title'),
          done: row.read<int>('is_done') == 1,
          position: row.read<int>('position'),
          updatedAt: DateTime.parse(row.read<String>('updated_at')),
        ),
    ];
  }

  Future<void> addChecklistItem(String taskId, String title) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty) throw ArgumentError('Checklist title is required');
    await db.transaction(() async {
      final existing = await db
          .customSelect(
            '''SELECT 1 FROM tasks WHERE id=?
        AND deleted_at IS NULL''',
            variables: [Variable.withString(taskId)],
          )
          .getSingleOrNull();
      if (existing == null) throw StateError('Task is unavailable');
      final position =
          (await db
                  .customSelect(
                    '''SELECT
        COALESCE(MAX(position),-1)+1 AS next FROM task_checklist WHERE task_id=?''',
                    variables: [Variable.withString(taskId)],
                  )
                  .getSingle())
              .read<int>('next');
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customInsert(
        '''INSERT INTO task_checklist
        (id,task_id,title,is_done,position,created_at,updated_at)
        VALUES(?,?,?,0,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(taskId),
          Variable.withString(cleaned),
          Variable.withInt(position),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
  }

  Future<void> updateChecklistItem(
    TaskChecklistItem item, {
    String? title,
    bool? done,
  }) async {
    final cleaned = title?.trim();
    if (cleaned != null && cleaned.isEmpty) {
      throw ArgumentError('Checklist title is required');
    }
    final changed = await db.customUpdate(
      '''UPDATE task_checklist
      SET title=?,is_done=?,updated_at=? WHERE id=? AND updated_at=?''',
      variables: [
        Variable.withString(cleaned ?? item.title),
        Variable.withInt((done ?? item.done) ? 1 : 0),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(item.id),
        Variable.withString(item.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (changed != 1) throw StateError('Checklist item changed');
  }

  Future<void> removeChecklistItem(TaskChecklistItem item) async {
    final changed = await db.customUpdate(
      '''DELETE FROM task_checklist
      WHERE id=? AND updated_at=?''',
      variables: [
        Variable.withString(item.id),
        Variable.withString(item.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (changed != 1) throw StateError('Checklist item changed');
  }

  Future<void> moveChecklistItem(TaskChecklistItem item, int direction) async {
    if (direction != -1 && direction != 1) throw ArgumentError('Bad direction');
    await db.transaction(() async {
      final rows = await db
          .customSelect(
            '''SELECT id,updated_at FROM
        task_checklist WHERE task_id=? ORDER BY position,created_at''',
            variables: [Variable.withString(item.taskId)],
          )
          .get();
      final index = rows.indexWhere((row) => row.read<String>('id') == item.id);
      final otherIndex = index + direction;
      if (index < 0 ||
          otherIndex < 0 ||
          otherIndex >= rows.length ||
          rows[index].read<String>('updated_at') !=
              item.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Checklist order changed');
      }
      final ids = rows.map((row) => row.read<String>('id')).toList();
      final swapped = ids[index];
      ids[index] = ids[otherIndex];
      ids[otherIndex] = swapped;
      final now = DateTime.now().toUtc().toIso8601String();
      for (var position = 0; position < ids.length; position++) {
        await db.customUpdate(
          '''UPDATE task_checklist SET position=?,
          updated_at=? WHERE id=?''',
          variables: [
            Variable.withInt(position),
            Variable.withString(now),
            Variable.withString(ids[position]),
          ],
        );
      }
    });
  }
}
