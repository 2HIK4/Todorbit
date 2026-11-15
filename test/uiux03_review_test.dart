import 'package:life_manager/domain/focus_session.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/domain/trash.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/migration_gate.dart';
import 'package:life_manager/data/sync_schema.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'schema 28 upgrade is gated, preserves rows and is idempotent',
    () async {
      final root = await Directory.systemTemp.createTemp('uiux03-migrate-');
      final file = File('${root.path}/life.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(db)
          .addTask(const TaskDraft(title: 'Preserve'));
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE task_resource_subtasks');
      raw.execute('PRAGMA user_version=28');
      raw.close();
      try {
        expect(await MigrationGate.olderSchema(file), 28);
        for (var i = 0; i < 2; i++) {
          db = AppDatabase(NativeDatabase(file));
          expect((await LifeRepository(db).tasks()).single.id, task.id);
          expect(
            await db.customSelect('SELECT * FROM task_resource_subtasks').get(),
            isEmpty,
          );
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .data
                .values
                .single,
            29,
          );
          await db.close();
        }
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test('resource assignments participate in portable sync', () {
    expect(portableSyncTables, contains('task_resource_subtasks'));
  });
  test(
    'category and project visibility is stored as portable preferences',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(db));
      try {
        await controller.toggleCategoryStandardVisibility('category');
        await controller.toggleProjectStandardVisibility('project');
        final values = await controller.repository.portablePreferences();
        expect(values['hiddenStandardCategories'], ['category']);
        expect(values['hiddenStandardProjects'], ['project']);
        final other = AppController(controller.repository);
        await other.applyPortablePreferences();
        expect(other.isCategoryShownInStandardViews('category'), isFalse);
        expect(other.isProjectShownInStandardViews('project'), isFalse);
        other.dispose();
      } finally {
        controller.dispose();
        await db.close();
      }
    },
  );
  test(
    'bounded work caps at deadline; breaks never enter the work ledger',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final task = await repo.addTask(const TaskDraft(title: 'Intervals'));
      final c = AppController(repo);
      await c.refresh();
      await c.startFocusTask(task);
      final start = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      await db.customStatement('UPDATE time_entries SET starts_at=?', [
        start.toIso8601String(),
      ]);
      await c.refresh();
      var elapsed = Duration.zero;
      final session = FocusSession(elapsed: () => elapsed)
        ..mode = FocusMode.pomodoro;
      session.workMinutes = 1;
      session.reset();
      c.focusSessions[task.id] = session;
      try {
        await c.toggleFocus(task.id);
        elapsed += const Duration(minutes: 1);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        expect(c.timerError, isNull);
        expect(c.activeTimer!.state, TimerState.paused);
        expect(session.phase, PomodoroPhase.shortBreak);
        final entry = (await repo.timeEntries()).single;
        expect(entry.durationAt(DateTime.now()), const Duration(minutes: 1));
        await c.toggleFocus(task.id);
        elapsed += const Duration(minutes: 5);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        expect(session.phase, PomodoroPhase.work);
        expect(session.running, isFalse);
        expect(c.activeTimer!.state, TimerState.paused);
        expect(await repo.timeEntries(), hasLength(1));
      } finally {
        c.dispose();
        await db.close();
      }
    },
  );
  test(
    'short restart requires review and checkpoint stop excludes offline time',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final task = await repo.addTask(const TaskDraft(title: 'Restart'));
      await repo.startTimer(task.id);
      final before = (await repo.activeTimerRun())!;
      final c = AppController(repo);
      try {
        await c.refresh();
        expect(c.activeTimer!.needsReview(DateTime.now()), isTrue);
        await expectLater(c.pauseTimer(), throwsStateError);
        await c.stopRecoveredTimerAtCheckpoint();
        expect((await repo.timeEntries()).single.endsAt, before.lastSeenAt);
        expect(c.activeTimer, isNull);
      } finally {
        c.dispose();
        await db.close();
      }
    },
  );
  test('bulk archive deletion rejects restored rows and rolls back earlier deletions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    try {
      final a = await repo.addTask(const TaskDraft(title: 'A'));
      final b = await repo.addTask(const TaskDraft(title: 'B'));
      await repo.archiveTask(a);
      await repo.archiveTask(b);
      final archived = await repo.archivedTasks();
      await repo.restoreArchivedTask(archived.firstWhere((t) => t.id == b.id));
      await expectLater(
        repo.deleteArchivedSelection([], [
          archived.firstWhere((t) => t.id == a.id),
          archived.firstWhere((t) => t.id == b.id),
        ]),
        throwsStateError,
      );
      expect((await repo.archivedTasks()).single.id, a.id);
      expect(await repo.trash(), isEmpty);
      await repo.deleteArchivedSelection([], [
        archived.firstWhere((t) => t.id == a.id),
      ]);
      expect((await repo.trash()).single.id, a.id);
      // A linked work entry blocks purge and rolls back a preceding eligible purge.
      final simple = await repo.addTask(const TaskDraft(title: 'Purgeable'));
      await repo.moveToTrash(TrashKind.task, simple.id);
      final blocked = await repo.addTask(const TaskDraft(title: 'Blocked'));
      final end = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      await repo.addManualTime(
        blocked.id,
        end.subtract(const Duration(minutes: 1)),
        end,
        '',
      );
      await repo.moveToTrash(TrashKind.task, blocked.id);
      final items = await repo.trash();
      await expectLater(
        repo.purgeTrashSelection([
          items.firstWhere((i) => i.id == simple.id),
          items.firstWhere((i) => i.id == blocked.id),
        ]),
        throwsStateError,
      );
      expect(
        (await repo.trash()).map((i) => i.id),
        containsAll([simple.id, blocked.id]),
      );
    } finally {
      await db.close();
    }
  });
  test('countdown completion caps recorded work and remains stopped', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final task = await repo.addTask(const TaskDraft(title: 'Countdown'));
    final c = AppController(repo);
    await c.refresh();
    await c.startFocusTask(task);
    final start = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
    await db.customStatement('UPDATE time_entries SET starts_at=?', [
      start.toIso8601String(),
    ]);
    await c.refresh();
    var elapsed = Duration.zero;
    final session = FocusSession(elapsed: () => elapsed)
      ..mode = FocusMode.countdown;
    session.seconds = 1;
    c.focusSessions[task.id] = session;
    try {
      await c.toggleFocus(task.id);
      elapsed += const Duration(seconds: 1);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(c.timerError, isNull);
      expect(c.activeTimer!.state, TimerState.paused);
      expect(session.remaining, Duration.zero);
      expect(session.running, isFalse);
      expect(
        (await repo.timeEntries()).single.durationAt(DateTime.now()),
        const Duration(seconds: 1),
      );
    } finally {
      c.dispose();
      await db.close();
    }
  });
}
