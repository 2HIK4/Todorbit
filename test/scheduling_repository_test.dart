import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/scheduling_engine.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });

  tearDown(() async => database.close());

  Future<LifeTask> addTask(String title, String date) => repository.addTask(
    TaskDraft(title: title, scheduledDate: date, deadlineDate: '2026-12-31'),
  );

  test(
    'preview does not mutate; apply persists atomically with history',
    () async {
      final first = await addTask('First', '2026-10-19');
      final second = await addTask('Second', '2026-10-20');
      final preview = const SchedulingEngine().shiftTasks(
        selected: [first, second],
        days: 3,
        scope: 'project:test',
      );

      expect((await repository.tasks()).map((task) => task.scheduledDate), [
        '2026-10-19',
        '2026-10-20',
      ]);
      await repository.applySchedulingPreview(preview);

      final tasks = await repository.tasks();
      expect(tasks.map((task) => task.scheduledDate), [
        '2026-10-22',
        '2026-10-23',
      ]);
      final history = await repository.schedulingHistory();
      expect(history.single.type, ScheduleOperationType.shift);
      expect(history.single.source, ScheduleChangeSource.smartReschedule);
      expect(history.single.changes, hasLength(2));
    },
  );

  test('stale preview rejects the whole bulk apply', () async {
    final first = await addTask('First', '2026-10-19');
    final second = await addTask('Second', '2026-10-20');
    final preview = const SchedulingEngine().shiftTasks(
      selected: [first, second],
      days: 3,
      scope: 'test',
    );
    await repository.updateTask(
      second,
      const TaskDraft(
        title: 'Second',
        scheduledDate: '2026-11-01',
        deadlineDate: '2026-12-31',
      ),
    );

    await expectLater(
      repository.applySchedulingPreview(preview),
      throwsA(isA<StaleSchedulePreviewException>()),
    );
    final byTitle = {
      for (final task in await repository.tasks()) task.title: task,
    };
    expect(byTitle['First']!.scheduledDate, '2026-10-19');
    expect(byTitle['Second']!.scheduledDate, '2026-11-01');
  });

  test(
    'restore protects a later manual scheduling change by default',
    () async {
      final first = await addTask('First', '2026-10-19');
      final second = await addTask('Second', '2026-10-20');
      final operationId = await repository.applySchedulingPreview(
        const SchedulingEngine().shiftTasks(
          selected: [first, second],
          days: 3,
          scope: 'test',
        ),
      );
      final shifted = {
        for (final task in await repository.tasks()) task.title: task,
      };
      await repository.updateTask(
        shifted['Second']!,
        const TaskDraft(
          title: 'Second',
          scheduledDate: '2026-11-05',
          deadlineDate: '2026-12-31',
        ),
      );

      final restore = await repository.previewRestore(operationId);
      expect(restore.changes.map((change) => change.targetId), [first.id]);
      expect(restore.issues.single.kind, ScheduleIssueKind.stale);
      await repository.applySchedulingPreview(restore);

      final restored = {
        for (final task in await repository.tasks()) task.title: task,
      };
      expect(restored['First']!.scheduledDate, '2026-10-19');
      expect(restored['Second']!.scheduledDate, '2026-11-05');
      expect(
        (await repository.schedulingHistory()).first.type,
        ScheduleOperationType.restorePrevious,
      );
    },
  );

  test(
    'undo and restore original create new history without erasing old entries',
    () async {
      final original = await addTask('Task', '2026-10-19');
      final firstId = await repository.applySchedulingPreview(
        const SchedulingEngine().shiftTasks(
          selected: [original],
          days: 2,
          scope: 'test',
        ),
      );
      final shifted = (await repository.tasks()).single;
      final secondId = await repository.applySchedulingPreview(
        const SchedulingEngine().shiftTasks(
          selected: [shifted],
          days: 2,
          scope: 'test',
        ),
      );

      final originalPreview = await repository.previewRestore(
        secondId,
        original: true,
      );
      expect(originalPreview.changes.single.afterDate, '2026-10-19');
      await repository.applySchedulingPreview(originalPreview);
      expect((await repository.tasks()).single.scheduledDate, '2026-10-19');
      expect(await repository.schedulingHistory(), hasLength(3));

      final firstUndo = await repository.previewRestore(firstId, undo: true);
      expect(firstUndo.changes, isEmpty);
      expect(firstUndo.issues.single.kind, ScheduleIssueKind.stale);
    },
  );

  test(
    'split persists a second session and undo removes only that session',
    () async {
      final task = await addTask('Deep work', '2026-10-19');
      final session = await repository.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime.utc(2026, 10, 19, 9),
          endsAt: DateTime.utc(2026, 10, 19, 11),
        ),
      );
      final operationId = await repository.applySchedulingPreview(
        const SchedulingEngine().splitSession(
          session: session,
          task: null,
          firstMinutes: 45,
          newSessionId: 'stable-new-session',
          scope: 'task:test',
        ),
      );
      expect(await repository.sessions(), hasLength(2));

      final undo = await repository.previewRestore(operationId, undo: true);
      expect(undo.changes, hasLength(2));
      await repository.applySchedulingPreview(undo);
      final sessions = await repository.sessions();
      expect(sessions, hasLength(1));
      expect(sessions.single.id, session.id);
      expect(sessions.single.endsAt, DateTime.utc(2026, 10, 19, 11));
    },
  );

  test(
    'availability windows and closed exceptions persist after restart',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('life_schedule_');
      final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
      try {
        final first = AppDatabase(NativeDatabase(file));
        await LifeRepository(first).saveAvailability(
          const AvailabilityPlan(
            weekly: {
              DateTime.monday: [AvailabilityWindow(600, 900)],
            },
            exceptions: {'2026-10-19': []},
          ),
        );
        await first.close();
        final second = AppDatabase(NativeDatabase(file));
        final loaded = await LifeRepository(second).availability();
        expect(loaded.weekly[DateTime.monday]!.single.startMinute, 600);
        expect(loaded.exceptions['2026-10-19'], isEmpty);
        await second.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('schema v3 migrates without losing tasks or sessions', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'life_v3_schedule_',
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
      CREATE TABLE work_sessions (
        id TEXT PRIMARY KEY, task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        starts_at TEXT NOT NULL, ends_at TEXT NOT NULL, outcome TEXT NOT NULL,
        actual_started_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    legacy.execute('''
      INSERT INTO tasks VALUES(
        'task','Preserved','','notStarted',0,NULL,NULL,'2026-10-19',NULL,
        '2026-10-01T00:00:00.000Z','2026-10-01T00:00:00.000Z',NULL
      )
    ''');
    legacy.execute('''
      INSERT INTO work_sessions VALUES(
        'session','task','2026-10-19T09:00:00.000Z','2026-10-19T10:00:00.000Z',
        'upcoming',NULL,'2026-10-01T00:00:00.000Z','2026-10-01T00:00:00.000Z'
      )
    ''');
    legacy.execute('PRAGMA user_version = 3');
    legacy.close();
    try {
      final migrated = AppDatabase(NativeDatabase(file));
      try {
        final migratedRepository = LifeRepository(migrated);
        expect((await migratedRepository.tasks()).single.title, 'Preserved');
        expect((await migratedRepository.sessions()).single.id, 'session');
        expect(
          (await migratedRepository.tasks()).single.schedulingLocked,
          isFalse,
        );
        await migratedRepository.saveAvailability(
          const AvailabilityPlan(
            weekly: {
              DateTime.monday: [AvailabilityWindow(540, 600)],
            },
          ),
        );
        expect((await migratedRepository.availability()).weekly, isNotEmpty);
      } finally {
        await migrated.close();
      }
    } finally {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          await directory.delete(recursive: true);
          break;
        } on FileSystemException {
          if (attempt == 9) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  });

  test('applied schedule and history survive a database restart', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life_restart_');
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    try {
      final firstDatabase = AppDatabase(NativeDatabase(file));
      final firstRepository = LifeRepository(firstDatabase);
      final task = await firstRepository.addTask(
        const TaskDraft(title: 'Restart task', scheduledDate: '2026-10-19'),
      );
      await firstRepository.applySchedulingPreview(
        const SchedulingEngine().shiftTasks(
          selected: [task],
          days: 1,
          scope: 'test',
        ),
      );
      await firstDatabase.close();

      final secondDatabase = AppDatabase(NativeDatabase(file));
      final secondRepository = LifeRepository(secondDatabase);
      expect(
        (await secondRepository.tasks()).single.scheduledDate,
        '2026-10-20',
      );
      expect(
        (await secondRepository.schedulingHistory()).single.type,
        ScheduleOperationType.shift,
      );
      await secondDatabase.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
