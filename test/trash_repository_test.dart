import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/trash.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });
  tearDown(() async => database.close());

  test(
    'archive and restore completed task preserve session and completion',
    () async {
      final task = await repository.addTask(
        const TaskDraft(title: 'Completed work'),
      );
      await repository.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime.utc(2026, 10, 18, 8),
          endsAt: DateTime.utc(2026, 10, 18, 9),
        ),
      );
      await repository.setComplete(task, true);
      final completed = (await repository.tasks()).single;
      await repository.archiveTask(completed);
      expect(await repository.tasks(), isEmpty);
      expect(await repository.sessions(), isEmpty);
      final archived = (await repository.archivedTasks()).single;
      expect(archived.completedAt, completed.completedAt);
      await repository.restoreArchivedTask(archived);
      expect(
        (await repository.tasks()).single.completedAt,
        completed.completedAt,
      );
      expect(await repository.sessions(), hasLength(1));
      await expectLater(
        repository.restoreArchivedTask(archived),
        throwsStateError,
      );
    },
  );

  test(
    'project and category Trash hide descendants and restore in order',
    () async {
      final category = await repository.addCategory('Research');
      final project = await repository.addProject(category.id, 'Paper');
      final task = await repository.addTask(
        TaskDraft(
          title: 'Draft',
          categoryId: category.id,
          projectId: project.id,
        ),
      );
      await repository.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime.utc(2026, 10, 18, 8),
          endsAt: DateTime.utc(2026, 10, 18, 9),
        ),
      );
      await repository.deleteProject(project.id);
      expect(await repository.tasks(), isEmpty);
      expect(await repository.sessions(), isEmpty);
      await repository.deleteCategory(category.id);
      final items = await repository.trash();
      final projectItem = items.singleWhere((i) => i.kind == TrashKind.project);
      final categoryItem = items.singleWhere(
        (i) => i.kind == TrashKind.category,
      );
      expect(projectItem.affectedTasks, 1);
      await expectLater(
        repository.restoreTrashItem(projectItem),
        throwsStateError,
      );
      await repository.restoreTrashItem(categoryItem);
      expect(await repository.tasks(), isEmpty);
      await repository.restoreTrashItem(projectItem);
      expect((await repository.tasks()).single.id, task.id);
      expect(await repository.sessions(), hasLength(1));
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'individual deletion retains dependencies and rejects stale restore',
    () async {
      final prerequisite = await repository.addTask(
        const TaskDraft(title: 'First'),
      );
      final dependent = await repository.addTask(
        const TaskDraft(title: 'Second'),
      );
      await repository.setPrerequisites(dependent, {prerequisite.id});
      await repository.deleteTask(prerequisite.id);
      expect((await repository.dependencies()), isEmpty);
      final item = (await repository.trash()).single;
      await expectLater(repository.permanentlyDelete(item), throwsStateError);
      expect(await repository.trash(), hasLength(1));
      await repository.restoreTrashItem(item);
      expect(
        (await repository.dependencies()).single.prerequisiteId,
        prerequisite.id,
      );
      await expectLater(repository.restoreTrashItem(item), throwsStateError);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'expiry does not purge on startup; explicit purge retains tombstone',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Unlinked'));
      await repository.deleteTask(task.id);
      await database.customUpdate(
        "UPDATE tasks SET deleted_at='2026-01-01T00:00:00.000Z' WHERE id=?",
        variables: [Variable.withString(task.id)],
      );
      final item = (await repository.trash()).single;
      expect(item.retentionEndsAt.isBefore(DateTime.utc(2026, 3)), isTrue);
      expect(await repository.trash(), hasLength(1));
      await repository.permanentlyDelete(item);
      expect(await repository.trash(), isEmpty);
      final tombstone = await database
          .customSelect('SELECT entity_id,deleted_at FROM deletion_tombstones')
          .getSingle();
      expect(tombstone.read<String>('entity_id'), task.id);
      expect(
        tombstone.read<String>('deleted_at'),
        item.deletedAt.toUtc().toIso8601String(),
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'deleted recurrence occurrence does not regenerate and restores identity',
    () async {
      final task = await repository.addRecurringTask(
        const TaskDraft(title: 'Repeat', scheduledDate: '2026-10-18'),
        RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2026-10-18'),
      );
      await repository.deleteTask(task.id);
      await repository.ensureRecurringTasks('2026-10-18', '2026-10-19');
      expect((await repository.tasks()).where((t) => t.id == task.id), isEmpty);
      expect((await repository.tasks()).length, 1);
      await repository.restoreTrashItem((await repository.trash()).single);
      expect((await repository.tasks()).map((t) => t.id), contains(task.id));
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'events and sessions enter Trash without losing their records',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Parent'));
      final event = await repository.addEvent(
        EventDraft(
          title: 'Appointment',
          startsAt: DateTime.utc(2026, 10, 19, 9),
          endsAt: DateTime.utc(2026, 10, 19, 10),
        ),
      );
      final session = await repository.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime.utc(2026, 10, 19, 11),
          endsAt: DateTime.utc(2026, 10, 19, 12),
        ),
      );
      await repository.deleteEvent(event.id);
      await repository.deleteSession(session.id);
      expect(await repository.events(), isEmpty);
      expect(await repository.sessions(), isEmpty);
      final items = await repository.trash();
      final eventItem = items.singleWhere((i) => i.kind == TrashKind.event);
      final sessionItem = items.singleWhere((i) => i.kind == TrashKind.session);
      await repository.deleteTask(task.id);
      await expectLater(
        repository.restoreTrashItem(sessionItem),
        throwsStateError,
      );
      await repository.restoreTrashItem(eventItem);
      await repository.restoreTrashItem(
        (await repository.trash()).singleWhere((i) => i.kind == TrashKind.task),
      );
      await repository.restoreTrashItem(sessionItem);
      expect((await repository.events()).single.id, event.id);
      expect((await repository.sessions()).single.id, session.id);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'whole recurring series archives and trashes without regenerating',
    () async {
      final first = await repository.addRecurringTask(
        const TaskDraft(title: 'Series', scheduledDate: '2026-10-18'),
        RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2026-10-18'),
      );
      await repository.ensureRecurringTasks('2026-10-18', '2026-10-19');
      final ids = (await repository.tasks()).map((task) => task.id).toSet();
      await repository.archiveSeries(first);
      await repository.ensureRecurringTasks('2026-10-18', '2026-10-21');
      expect(await repository.tasks(), isEmpty);
      final archived = (await repository.archivedSeries()).single;
      expect(archived.occurrences, 2);
      await repository.restoreArchivedSeries(archived);
      expect((await repository.tasks()).map((task) => task.id).toSet(), ids);
      await repository.deleteSeries(first);
      await repository.ensureRecurringTasks('2026-10-18', '2026-10-21');
      expect(await repository.tasks(), isEmpty);
      final trash = (await repository.trash()).single;
      expect(trash.kind, TrashKind.series);
      await expectLater(repository.permanentlyDelete(trash), throwsStateError);
      await repository.restoreTrashItem(trash);
      expect((await repository.tasks()).map((task) => task.id).toSet(), ids);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'explicit purge of a series requires each occurrence to be resolved',
    () async {
      final first = await repository.addRecurringTask(
        const TaskDraft(title: 'Short series', scheduledDate: '2026-10-18'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-18',
          maxOccurrences: 2,
        ),
      );
      await repository.ensureRecurringTasks('2026-10-18', '2026-10-19');
      final ids = (await repository.tasks()).map((task) => task.id).toList();
      await repository.deleteSeries(first);
      final seriesItem = (await repository.trash()).single;
      await expectLater(
        repository.permanentlyDelete(seriesItem),
        throwsStateError,
      );
      for (final id in ids) {
        await repository.deleteTask(id);
        final item = (await repository.trash()).singleWhere(
          (value) => value.kind == TrashKind.task && value.id == id,
        );
        await repository.permanentlyDelete(item);
      }
      await repository.permanentlyDelete(seriesItem);
      expect(await repository.trash(), isEmpty);
      final tombstones = await database
          .customSelect('SELECT entity_kind FROM deletion_tombstones')
          .get();
      expect(
        tombstones.where((r) => r.read<String>('entity_kind') == 'task'),
        hasLength(2),
      );
      expect(
        tombstones.where((r) => r.read<String>('entity_kind') == 'occurrence'),
        hasLength(2),
      );
      expect(
        tombstones.where((r) => r.read<String>('entity_kind') == 'series'),
        hasLength(1),
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test('v12 disposable file migrates to v13 without losing a task', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life-trash-v12-');
    final file = File('${directory.path}/legacy.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(first)
          .addTask(const TaskDraft(title: 'Before upgrade'));
      await first.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP INDEX tasks_deleted_at');
        raw.execute('DROP INDEX projects_deleted_at');
        raw.execute('DROP INDEX categories_deleted_at');
        raw.execute('DROP INDEX tasks_archived_at');
        raw.execute('DROP INDEX fixed_events_deleted_at');
        raw.execute('DROP INDEX work_sessions_deleted_at');
        raw.execute('DROP INDEX recurrence_series_deleted_at');
        raw.execute('DROP INDEX recurrence_series_archived_at');
        raw.execute('DROP TABLE deletion_tombstones');
        raw.execute('ALTER TABLE tasks DROP COLUMN archived_at');
        raw.execute('ALTER TABLE tasks DROP COLUMN deleted_at');
        raw.execute('ALTER TABLE projects DROP COLUMN deleted_at');
        raw.execute('ALTER TABLE categories DROP COLUMN deleted_at');
        raw.execute('ALTER TABLE fixed_events DROP COLUMN deleted_at');
        raw.execute('ALTER TABLE work_sessions DROP COLUMN deleted_at');
        raw.execute('ALTER TABLE recurrence_series DROP COLUMN archived_at');
        raw.execute('ALTER TABLE recurrence_series DROP COLUMN deleted_at');
        raw.execute('PRAGMA user_version=12');
      } finally {
        raw.close();
      }
      final migrated = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(migrated);
        expect((await repo.tasks()).single.id, task.id);
        await repo.deleteTask(task.id);
        expect((await repo.trash()).single.id, task.id);
        expect(
          await migrated.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await migrated.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
