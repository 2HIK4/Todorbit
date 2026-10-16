import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });

  tearDown(() async => database.close());

  test('task lifecycle persists through queries', () async {
    final category = await repository.addCategory('University');
    final project = await repository.addProject(category.id, 'Thesis');
    final task = await repository.addTask(
      TaskDraft(
        title: '  Draft outline  ',
        categoryId: category.id,
        projectId: project.id,
        scheduledDate: '2026-10-16',
        deadlineDate: '2026-10-20',
      ),
    );
    expect(task.title, 'Draft outline');
    expect(task.scheduledDate, '2026-10-16');
    expect(task.deadlineDate, '2026-10-20');
    expect(task.status, TaskStatus.notStarted);

    await repository.setComplete(task, true);
    final completed = (await repository.tasks()).single;
    expect(completed.status, TaskStatus.completed);
    expect(completed.completedAt, isNotNull);

    await repository.setComplete(completed, false);
    final reopened = (await repository.tasks()).single;
    expect(reopened.status, TaskStatus.notStarted);
    expect(reopened.completedAt, isNull);

    await repository.updateTask(
      reopened,
      TaskDraft(
        title: 'Write first draft',
        notes: 'Chapter one',
        categoryId: category.id,
        projectId: project.id,
        deadlineDate: '2026-10-20',
        priority: 3,
      ),
    );
    final edited = (await repository.tasks()).single;
    expect(edited.title, 'Write first draft');
    expect(edited.notes, 'Chapter one');
    expect(edited.scheduledDate, isNull);
    expect(edited.deadlineDate, '2026-10-20');

    await repository.deleteTask(edited.id);
    expect(await repository.tasks(), isEmpty);
  });

  test('rejects invalid project/category association', () async {
    final first = await repository.addCategory('Personal');
    final second = await repository.addCategory('Work');
    final project = await repository.addProject(first.id, 'Home');
    await expectLater(
      repository.addTask(
        TaskDraft(
          title: 'Bad association',
          categoryId: second.id,
          projectId: project.id,
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.tasks(), isEmpty);
  });

  test('task survives database close and reopen', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'life_manager_test_',
    );
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    try {
      await LifeRepository(first)
          .addTask(const TaskDraft(title: 'Persistent task'));
      await first.close();
      final second = AppDatabase(NativeDatabase(file));
      try {
        final tasks = await LifeRepository(second).tasks();
        expect(tasks.single.title, 'Persistent task');
      } finally {
        await second.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('fixed events can be created, edited, and deleted', () async {
    final start = DateTime.utc(2026, 10, 16, 8);
    final event = await repository.addEvent(
      EventDraft(
        title: 'Lecture',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 2)),
      ),
    );
    expect((await repository.events()).single.title, 'Lecture');
    expect((await repository.events()).single.startsAt, start);
    await repository.updateEvent(
      event,
      EventDraft(
        title: 'Lab',
        startsAt: start.add(const Duration(days: 1)),
        endsAt: start.add(const Duration(days: 1, hours: 2)),
      ),
    );
    expect((await repository.events()).single.title, 'Lab');
    await repository.deleteEvent(event.id);
    expect(await repository.events(), isEmpty);
  });

  test('schema migration preserves v1 tasks', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'life_manager_migration_',
    );
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, notes TEXT NOT NULL,
        status TEXT NOT NULL, priority INTEGER NOT NULL, category_id TEXT,
        project_id TEXT, scheduled_date TEXT, deadline_date TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, completed_at TEXT
      )
    ''');
    legacy.execute('''
      INSERT INTO tasks VALUES(
        'legacy-id','Keep me','','notStarted',0,NULL,NULL,NULL,NULL,
        '2026-10-16T00:00:00.000Z','2026-10-16T00:00:00.000Z',NULL
      )
    ''');
    legacy.execute('PRAGMA user_version = 1');
    legacy.close();
    final migrated = AppDatabase(NativeDatabase(file));
    try {
      expect((await LifeRepository(migrated).tasks()).single.title, 'Keep me');
      expect(await LifeRepository(migrated).events(), isEmpty);
      await LifeRepository(migrated).addEvent(
        EventDraft(
          title: 'After migration',
          startsAt: DateTime.utc(2026, 10, 17),
          endsAt: DateTime.utc(2026, 10, 17, 1),
        ),
      );
      expect(
        (await LifeRepository(migrated).events()).single.title,
        'After migration',
      );
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
    }
  });
}
