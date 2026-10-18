part of 'life_repository.dart';

extension TemplateRepository on LifeRepository {
  Future<List<LifeTemplate>> templates() async {
    final rows = await db
        .customSelect('SELECT * FROM templates ORDER BY name COLLATE NOCASE')
        .get();
    return rows.map(_templateFromRow).toList();
  }

  LifeTemplate _templateFromRow(QueryRow row) => LifeTemplate(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    kind: TemplateKind.values.byName(row.read<String>('kind')),
    payload: (jsonDecode(row.read<String>('payload_json')) as Map)
        .cast<String, dynamic>(),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
  );

  Map<String, dynamic> _taskRecipe(TaskDraft draft, String? anchor) => {
    'title': draft.title,
    'notes': draft.notes,
    'priority': draft.priority,
    'planned_minutes': draft.plannedDurationMinutes,
    'remaining_minutes': draft.remainingWorkMinutes,
    'locked': draft.schedulingLocked,
    'scheduled_offset': draft.scheduledDate == null || anchor == null
        ? null
        : RecurrenceRule.daysBetween(anchor, draft.scheduledDate!),
    'deadline_offset': draft.deadlineDate == null || anchor == null
        ? null
        : RecurrenceRule.daysBetween(anchor, draft.deadlineDate!),
  };

  TaskDraft _recipeDraft(
    Map<String, dynamic> recipe,
    String anchor,
    String? categoryId,
    String? projectId,
  ) => TaskDraft(
    title: recipe['title'] as String,
    notes: recipe['notes'] as String,
    priority: recipe['priority'] as int,
    categoryId: categoryId,
    projectId: projectId,
    scheduledDate: recipe['scheduled_offset'] == null
        ? null
        : RecurrenceRule.shiftDate(anchor, recipe['scheduled_offset'] as int),
    deadlineDate: recipe['deadline_offset'] == null
        ? null
        : RecurrenceRule.shiftDate(anchor, recipe['deadline_offset'] as int),
    plannedDurationMinutes: recipe['planned_minutes'] as int?,
    remainingWorkMinutes: recipe['remaining_minutes'] as int?,
    schedulingLocked: recipe['locked'] as bool,
  );

  Future<LifeTemplate> _insertTemplate(
    String name,
    TemplateKind kind,
    Map<String, dynamic> payload,
  ) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Template name is required');
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      'INSERT INTO templates(id,name,kind,payload_json,created_at,updated_at) VALUES(?,?,?,?,?,?)',
      variables: [
        Variable.withString(id),
        Variable.withString(cleaned),
        Variable.withString(kind.name),
        Variable.withString(jsonEncode(payload)),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await templates()).firstWhere((item) => item.id == id);
  }

  Future<LifeTemplate> saveTaskTemplate(LifeTask source, String name) async {
    return db.transaction(() async {
      final current = (await tasks())
          .where((item) => item.id == source.id)
          .firstOrNull;
      if (current == null || current.updatedAt != source.updatedAt) {
        throw StateError('Task changed. Refresh before saving a template.');
      }
      if (source.recurrenceSeriesId == null) {
        final draft = TaskDraft(
          title: current.title,
          notes: current.notes,
          priority: current.priority,
          scheduledDate: current.scheduledDate,
          deadlineDate: current.deadlineDate,
          plannedDurationMinutes: current.plannedDurationMinutes,
          remainingWorkMinutes: current.remainingWorkMinutes,
          schedulingLocked: current.schedulingLocked,
        );
        final anchor = draft.scheduledDate ?? draft.deadlineDate;
        return _insertTemplate(name, TemplateKind.task, {
          'version': 1,
          'task': _taskRecipe(draft, anchor),
        });
      }
      final definition = await recurrenceDefinition(source.id);
      final rule = definition.rule;
      return _insertTemplate(name, TemplateKind.routine, {
        'version': 1,
        'task': _taskRecipe(definition.template, rule.startDate),
        'rule': {
          'kind': rule.kind.name,
          'interval': rule.interval,
          'weekdays': rule.weekdays.toList()..sort(),
          'end_offset': rule.endDate == null
              ? null
              : RecurrenceRule.daysBetween(rule.startDate, rule.endDate!),
          'max_occurrences': rule.maxOccurrences,
        },
      });
    });
  }

  Future<LifeTemplate> saveProjectTemplate(Project project, String name) async {
    return db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT name,category_id FROM projects WHERE id=?',
            variables: [Variable.withString(project.id)],
          )
          .getSingleOrNull();
      if (current == null) throw StateError('Project no longer exists');
      if (current.read<String>('name') != project.name ||
          current.read<String>('category_id') != project.categoryId) {
        throw StateError('Project changed. Refresh before saving a template.');
      }
      final members = (await tasks())
          .where((item) => item.projectId == project.id)
          .toList();
      if (members.any((item) => item.recurrenceSeriesId != null)) {
        throw StateError(
          'Save recurring project tasks as routine templates first',
        );
      }
      final days = [
        for (final task in members)
          if (task.scheduledDate != null) task.scheduledDate!,
        for (final task in members)
          if (task.deadlineDate != null) task.deadlineDate!,
      ]..sort();
      final anchor = days.firstOrNull;
      final ids = members.map((item) => item.id).toSet();
      final links = (await dependencies())
          .where(
            (link) =>
                ids.contains(link.taskId) && ids.contains(link.prerequisiteId),
          )
          .toList();
      final externalLinkCount = (await dependencies())
          .where(
            (link) =>
                ids.contains(link.taskId) != ids.contains(link.prerequisiteId),
          )
          .length;
      return _insertTemplate(name, TemplateKind.project, {
        'version': 1,
        'project_name': project.name,
        'tasks': [
          for (final task in members)
            {
              'source_id': task.id,
              ..._taskRecipe(
                TaskDraft(
                  title: task.title,
                  notes: task.notes,
                  priority: task.priority,
                  scheduledDate: task.scheduledDate,
                  deadlineDate: task.deadlineDate,
                  plannedDurationMinutes: task.plannedDurationMinutes,
                  remainingWorkMinutes: task.remainingWorkMinutes,
                  schedulingLocked: task.schedulingLocked,
                ),
                anchor,
              ),
            },
        ],
        'dependencies': [
          for (final link in links) [link.taskId, link.prerequisiteId],
        ],
        'external_link_count': externalLinkCount,
      });
    });
  }

  Future<void> deleteTemplate(LifeTemplate previous) async {
    final count = await db.customUpdate(
      'DELETE FROM templates WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Template changed. Refresh first.');
  }

  /// Creates new IDs and no completion/history records. The selected day is
  /// the template's date anchor; internal project links are remapped.
  Future<String> instantiateTemplate(
    LifeTemplate previous, {
    required String anchorDay,
    String? categoryId,
    String? projectId,
    String? projectName,
  }) async {
    RecurrenceRule.daysBetween(anchorDay, anchorDay);
    return db.transaction(() async {
      final row = await db
          .customSelect(
            'SELECT * FROM templates WHERE id=? AND updated_at=?',
            variables: [
              Variable.withString(previous.id),
              Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
            ],
          )
          .getSingleOrNull();
      if (row == null) throw StateError('Template changed. Refresh first.');
      final template = _templateFromRow(row);
      if (template.payload['version'] != 1) {
        throw StateError('Unsupported template format');
      }
      if (template.kind == TemplateKind.project) {
        if (categoryId == null || projectId != null) {
          throw ArgumentError('Choose a category for the new project');
        }
        final cleaned =
            (projectName ?? template.payload['project_name'] as String).trim();
        final createdProject = await addProject(categoryId, cleaned);
        final idMap = <String, String>{};
        for (final raw in template.payload['tasks'] as List) {
          final recipe = (raw as Map).cast<String, dynamic>();
          final draft = _recipeDraft(
            recipe,
            anchorDay,
            categoryId,
            createdProject.id,
          );
          final createdTask = await addTask(draft);
          idMap[recipe['source_id'] as String] = createdTask.id;
        }
        final now = DateTime.now().toUtc().toIso8601String();
        for (final raw in template.payload['dependencies'] as List) {
          final link = raw as List;
          final task = idMap[link[0] as String];
          final prerequisite = idMap[link[1] as String];
          if (task == null || prerequisite == null) {
            throw StateError('Template dependency has a missing task');
          }
          await db.customInsert(
            'INSERT INTO task_dependencies(task_id,prerequisite_id,created_at) VALUES(?,?,?)',
            variables: [
              Variable.withString(task),
              Variable.withString(prerequisite),
              Variable.withString(now),
            ],
          );
        }
        return createdProject.id;
      }
      await _checkAssignment(categoryId, projectId);
      final recipe = (template.payload['task'] as Map).cast<String, dynamic>();
      var draft = _recipeDraft(recipe, anchorDay, categoryId, projectId);
      if (template.kind == TemplateKind.task) return (await addTask(draft)).id;
      final ruleData = (template.payload['rule'] as Map)
          .cast<String, dynamic>();
      final rule = RecurrenceRule(
        kind: RecurrenceKind.values.byName(ruleData['kind'] as String),
        startDate: anchorDay,
        interval: ruleData['interval'] as int,
        weekdays: (ruleData['weekdays'] as List).cast<int>().toSet(),
        endDate: ruleData['end_offset'] == null
            ? null
            : RecurrenceRule.shiftDate(
                anchorDay,
                ruleData['end_offset'] as int,
              ),
        maxOccurrences: ruleData['max_occurrences'] as int?,
      );
      draft = TaskDraft(
        title: draft.title,
        notes: draft.notes,
        priority: draft.priority,
        categoryId: categoryId,
        projectId: projectId,
        scheduledDate: anchorDay,
        deadlineDate: draft.deadlineDate,
        plannedDurationMinutes: draft.plannedDurationMinutes,
        remainingWorkMinutes: draft.remainingWorkMinutes,
        schedulingLocked: draft.schedulingLocked,
      );
      return (await addRecurringTask(draft, rule)).id;
    });
  }
}
