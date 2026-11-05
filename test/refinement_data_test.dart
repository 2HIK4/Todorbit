import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_schema.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/saved_views.dart';
import 'package:life_manager/domain/task_composition.dart';
import 'package:life_manager/domain/task_list_projection.dart';
import 'package:life_manager/domain/task_resources.dart';

void main() {
  test('Today events survive browsing a distant calendar month', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LifeRepository(db);
    final controller = AppController(repo);
    addTearDown(controller.dispose);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 9);
    final event = await repo.addEvent(
      EventDraft(
        title: 'Today appointment',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
      ),
    );
    await controller.initialize();
    expect(controller.filteredEvents.map((e) => e.id), contains(event.id));
    controller.navigate(WorkspaceView.calendar);
    await controller.ensureRecurringMonth(DateTime(now.year + 2, now.month));
    expect(controller.events.map((e) => e.id), isNot(contains(event.id)));
    controller.navigate(WorkspaceView.today);
    expect(controller.filteredEvents.map((e) => e.id), contains(event.id));
  });

  test(
    'event project survives occurrence exceptions, series split and clearing',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LifeRepository(db);
      final category = await repo.addCategory('University');
      final project = await repo.addProject(category.id, 'Course');
      final template = await repo.addEvent(
        EventDraft(
          title: 'Lecture',
          startsAt: DateTime(2026, 11, 5, 9),
          endsAt: DateTime(2026, 11, 5, 10),
          categoryId: category.id,
          projectId: project.id,
          repeat: const EventRepeat(kind: EventRepeatKind.daily),
        ),
      );
      expect(template.projectId, project.id);
      var occurrences = await repo.eventOccurrences('2026-11-05', '2026-11-07');
      expect(occurrences.map((e) => e.projectId), everyElement(project.id));
      await repo.updateEventOccurrence(
        occurrences[1],
        EventDraft(
          title: 'Independent lecture',
          startsAt: occurrences[1].startsAt,
          endsAt: occurrences[1].endsAt,
          categoryId: category.id,
        ),
      );
      occurrences = await repo.eventOccurrences('2026-11-05', '2026-11-07');
      expect(occurrences[1].projectId, isNull);
      expect(occurrences[0].projectId, project.id);
      final split = await repo.splitEventSeries(
        occurrences[2],
        '2026-11-07',
        EventDraft(
          title: 'Future lecture',
          startsAt: occurrences[2].startsAt,
          endsAt: occurrences[2].endsAt,
          categoryId: category.id,
          projectId: project.id,
          repeat: const EventRepeat(kind: EventRepeatKind.daily),
        ),
      );
      expect(split.projectId, project.id);
      await expectLater(
        repo.addEvent(
          EventDraft(
            title: 'Invalid assignment',
            startsAt: DateTime(2026, 11, 5, 9),
            endsAt: DateTime(2026, 11, 5, 10),
            projectId: project.id,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test('draft resources and named checklists commit atomically or preserve the draft', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-resource-draft-',
    );
    addTearDown(() => root.delete(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LifeRepository(db);
    final c = AppController(repo);
    addTearDown(c.dispose);
    final file = File('${root.path}/notes.txt');
    await file.writeAsString('Synthetic attachment');
    await c.addTaskWithComposition(
      const TaskDraft(title: 'With resources'),
      const [],
      const [],
      groups: [
        DraftChecklistGroup('Pack', ['Book', 'Pen']),
        DraftChecklistGroup('Review', ['Notes']),
      ],
      resources: [
        DraftTaskResource(TaskResourceKind.managed, file.path, 'Notes'),
        const DraftTaskResource(
          TaskResourceKind.url,
          'https://example.com',
          'Reference',
        ),
      ],
    );
    final task = (await repo.tasks()).single;
    expect(
      (await repo.taskResources(task.id)).map((r) => r.label),
      containsAll(['Notes', 'Reference']),
    );
    final groups = await repo.checklistGroups();
    expect(groups.map((g) => g.title), ['Pack', 'Review']);
    final items = await repo.checklistItems();
    expect(items.where((i) => i.groupId == groups.first.id), hasLength(2));
    await repo.moveChecklistItem(items[1], -1);
    expect(
      (await repo.checklistItems())
          .where((i) => i.groupId == groups.first.id)
          .first
          .title,
      'Pen',
    );
    await repo.addChecklistItem(task.id, 'New edit', groupId: groups.first.id);
    await expectLater(
      repo.removeChecklistGroup(
        groups.first,
        items.where((i) => i.groupId == groups.first.id).toList(),
      ),
      throwsStateError,
    );
    expect(await repo.checklistGroups(), hasLength(2));
    await expectLater(
      c.addTaskWithComposition(
        const TaskDraft(title: 'Rollback'),
        const ['Item'],
        const [],
        groups: [
          DraftChecklistGroup('Group', ['Item']),
        ],
        resources: [
          DraftTaskResource(
            TaskResourceKind.managed,
            '${root.path}/missing.txt',
            'Missing',
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect((await repo.tasks()).map((t) => t.title), ['With resources']);
    expect(await repo.checklistGroups(), hasLength(2));
    expect(await file.readAsString(), 'Synthetic attachment');
    await expectLater(
      repo.addChecklistItem(task.id, 'Wrong group', groupId: 'missing'),
      throwsStateError,
    );
  });

  test('schema 26 upgrades without rewriting paired immutable journal facts', () async {
    final root = await Directory.systemTemp.createTemp('todorbit-v26-upgrade-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/legacy.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();
    // Synthetic downgrade only. No existing content or real profile is opened.
    final triggers = await db
        .customSelect(
          "SELECT name FROM sqlite_schema WHERE type='trigger' AND name GLOB 'sync_capture_*'",
        )
        .get();
    for (final trigger in triggers) {
      await db.customStatement(
        'DROP TRIGGER "${trigger.read<String>('name')}"',
      );
    }
    await db.customStatement('DROP INDEX events_project');
    await db.customStatement('ALTER TABLE fixed_events DROP COLUMN project_id');
    await db.customStatement('ALTER TABLE task_checklist DROP COLUMN group_id');
    await installSyncCaptureTriggers(db, causal: true, visibility: true);
    await db.customStatement('DROP TABLE task_checklist_groups');
    await db.customStatement('PRAGMA user_version=26');
    await db.customStatement(
      "UPDATE sync_capture_context SET workspace_id='8b41595f-3258-40e7-8499-856772bf5fb8',account_id='fixture',device_id='df0293d3-c369-4db8-a998-0ae0b076397d',capture_enabled=1 WHERE id=1",
    );
    await db.customStatement(
      "INSERT INTO fixed_events(id,title,notes,starts_at,ends_at,created_at,updated_at) VALUES('event','Legacy lecture','','2026-11-05T09:00:00.000Z','2026-11-05T10:00:00.000Z','2026-11-05T00:00:00.000Z','2026-11-05T00:00:00.000Z')",
    );
    final before =
        (await db
                .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
                .get())
            .map((r) => r.data)
            .toList();
    expect(before, isNotEmpty);
    await db.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final repo = LifeRepository(upgraded);
    expect((await repo.events()).single.projectId, isNull);
    expect(
      (await upgraded
              .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
              .get())
          .map((r) => r.data)
          .toList(),
      before,
    );
    expect(
      (await upgraded
              .customSelect('SELECT capture_enabled FROM sync_capture_context')
              .getSingle())
          .read<int>('capture_enabled'),
      1,
    );
    final category = await repo.addCategory('Category');
    final project = await repo.addProject(category.id, 'Project');
    final event = (await repo.events()).single;
    await repo.updateEvent(
      event,
      EventDraft(
        title: event.title,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        categoryId: category.id,
        projectId: project.id,
      ),
    );
    expect((await repo.events()).single.projectId, project.id);
    expect(
      await upgraded.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });

  test(
    'combined filters and list projection retain independent identities',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LifeRepository(db);
      final c = AppController(repo);
      addTearDown(c.dispose);
      final parent = await repo.addTask(const TaskDraft(title: 'Parent'));
      final child = await repo.addSubtask(
        parent,
        const TaskDraft(
          title: 'Child',
          priority: 3,
          scheduledDate: '2026-11-05',
        ),
      );
      await c.refresh();
      c.navigate(WorkspaceView.all);
      c.setFilter(
        const TaskFilter(
          minimumPriority: 3,
          fromDate: '2026-11-05',
          throughDate: '2026-11-05',
        ),
      );
      expect(c.visibleTasks.map((t) => t.id), [child.id]);
      expect(
        projectTaskList(
          c.visibleTasks,
          c.taskParents,
          groupRecurrence: true,
        ).single.tasks.single.id,
        child.id,
      );
      c.navigate(WorkspaceView.today);
      expect(c.activeFilter.isActive, isFalse);
      c.navigate(WorkspaceView.all);
      expect(c.activeFilter.minimumPriority, 3);
      expect(
        TaskFilter.fromJson(c.activeFilter.toJson()).fromDate,
        '2026-11-05',
      );
    },
  );

  test(
    'device navigation state survives restart without changing custom colors',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-navigation-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = AppearancePreferenceStore(
        File('${root.path}/appearance.json'),
      );
      await store.saveNavigationState({
        'hidden': ['habits', 'custom-id'],
        'customOrder': ['custom-id'],
        'categoriesExpanded': true,
      });
      final restored = await AppearancePreferenceStore(store.file)
          .loadNavigationState();
      expect(restored['hidden'], ['habits', 'custom-id']);
      expect(restored['categoriesExpanded'], true);
    },
  );
  test(
    'recurrence groups retain closed occurrences and never merge equal titles',
    () {
      LifeTask task(
        String id, {
        String? series,
        TaskStatus status = TaskStatus.notStarted,
      }) => LifeTask(
        id: id,
        title: 'Same title',
        notes: '',
        status: status,
        priority: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        recurrenceSeriesId: series,
      );
      final open = task('open', series: 'series-a');
      final completed = task(
        'done',
        series: 'series-a',
        status: TaskStatus.completed,
      );
      final skipped = task(
        'skipped',
        series: 'series-a',
        status: TaskStatus.cancelled,
      );
      final unrelated = task('other', series: 'series-b');
      final groups = projectTaskList(
        [open, unrelated, task('plain')],
        {},
        groupRecurrence: true,
        relatedOccurrences: [open, completed, skipped, unrelated],
      );
      expect(groups, hasLength(3));
      expect(groups.first.tasks.map((t) => t.id), ['open', 'done', 'skipped']);
      expect(groups[1].tasks.single.id, 'other');
      expect(groups.last.recurring, isFalse);
      expect(
        projectTaskList(
          [completed],
          {},
          groupRecurrence: true,
        ).single.tasks.single.status,
        TaskStatus.completed,
      );
    },
  );
  test('event text filters include assignment names and closed status filters work in Inbox', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LifeRepository(db), c = AppController(LifeRepository(db));
    addTearDown(c.dispose);
    final category = await repo.addCategory('University');
    final project = await repo.addProject(category.id, 'Thesis');
    await repo.addEvent(
      EventDraft(
        title: 'Review',
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 1)),
        categoryId: category.id,
        projectId: project.id,
      ),
    );
    final task = await repo.addTask(const TaskDraft(title: 'Completed Inbox'));
    await repo.setComplete(task, true);
    await c.refresh();
    c.navigate(WorkspaceView.calendar);
    c.setFilter(const TaskFilter(text: 'Thesis'));
    expect(c.filteredEvents.single.title, 'Review');
    c.navigate(WorkspaceView.inbox);
    c.setFilter(const TaskFilter(statuses: {TaskStatus.completed}));
    expect(c.visibleTasks.single.id, task.id);
  });
  test('event occurrence clearing and legacy category overrides never inherit an incompatible project', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LifeRepository(db);
    final category = await repo.addCategory('University');
    final other = await repo.addCategory('Personal');
    final project = await repo.addProject(category.id, 'Thesis');
    final template = await repo.addEvent(
      EventDraft(
        title: 'Lecture',
        startsAt: DateTime(2026, 11, 5, 9),
        endsAt: DateTime(2026, 11, 5, 10),
        categoryId: category.id,
        projectId: project.id,
        colorValue: 0xff123456,
        iconName: 'school',
        reminderMinutes: 15,
        repeat: const EventRepeat(kind: EventRepeatKind.daily),
      ),
    );
    var rows = await repo.eventOccurrences('2026-11-05', '2026-11-07');
    await repo.updateEventOccurrence(
      rows[1],
      EventDraft(
        title: 'Unassigned occurrence',
        startsAt: rows[1].startsAt,
        endsAt: rows[1].endsAt,
      ),
    );
    await repo.updateEventOccurrence(
      rows[2],
      EventDraft(
        title: 'Legacy personal occurrence',
        startsAt: rows[2].startsAt,
        endsAt: rows[2].endsAt,
        categoryId: other.id,
      ),
    );
    final payload =
        (await db
                .customSelect(
                  'SELECT payload_json FROM event_occurrence_changes WHERE event_id=? AND nominal_date=?',
                  variables: [
                    Variable.withString(template.id),
                    Variable.withString('2026-11-07'),
                  ],
                )
                .getSingle())
            .read<String>('payload_json');
    final legacy = jsonDecode(payload) as Map<String, dynamic>
      ..remove('projectId')
      ..remove('colorValue')
      ..remove('iconName')
      ..remove('reminderMinutes');
    await db.customStatement(
      'UPDATE event_occurrence_changes SET payload_json=? WHERE event_id=? AND nominal_date=?',
      [jsonEncode(legacy), template.id, '2026-11-07'],
    );
    rows = await repo.eventOccurrences('2026-11-05', '2026-11-07');
    expect(rows[1].categoryId, isNull);
    expect(rows[1].projectId, isNull);
    expect(rows[1].colorValue, isNull);
    expect(rows[1].iconName, isNull);
    expect(rows[1].reminderMinutes, isNull);
    expect(rows[2].categoryId, other.id);
    expect(rows[2].projectId, isNull);
    expect(rows[2].colorValue, 0xff123456);
    expect(rows[2].iconName, 'school');
    expect(rows[2].reminderMinutes, 15);
    expect(rows[0].projectId, project.id);
  });
}
