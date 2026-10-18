import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/time_tracking.dart';
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
    'Start Task changes status without recording time; Focus starts one timer',
    () async {
      final first = await repository.addTask(const TaskDraft(title: 'Study'));
      final second = await repository.addTask(const TaskDraft(title: 'Read'));
      await repository.setTaskWorking(first, true);
      expect(
        (await repository.tasks()).firstWhere((t) => t.id == first.id).status,
        TaskStatus.inProgress,
      );
      expect(await repository.timeEntries(), isEmpty);
      final refreshed = (await repository.tasks()).firstWhere(
        (t) => t.id == first.id,
      );
      await repository.startFocusTask(refreshed);
      expect((await repository.activeTimerRun())?.taskId, first.id);
      await expectLater(repository.startFocusTask(second), throwsStateError);
      expect(
        (await repository.tasks()).firstWhere((t) => t.id == second.id).status,
        TaskStatus.notStarted,
      );
      await repository.stopTimer((await repository.activeTimerRun())!);
      expect(
        (await repository.tasks()).firstWhere((t) => t.id == first.id).status,
        TaskStatus.inProgress,
      );
      await repository.setTaskWorking(
        (await repository.tasks()).firstWhere((t) => t.id == first.id),
        false,
      );
      expect(
        (await repository.tasks()).firstWhere((t) => t.id == first.id).status,
        TaskStatus.onHold,
      );
    },
  );

  test('sub-minute work and clock formatting retain seconds', () async {
    final task = await repository.addTask(const TaskDraft(title: 'Short work'));
    await repository.addManualTime(
      task.id,
      DateTime.utc(2020, 10, 19, 9),
      DateTime.utc(2020, 10, 19, 9, 0, 42),
      '',
    );
    final entry = (await repository.timeEntries()).single;
    expect(entry.durationAt(DateTime.now()).inSeconds, 42);
    expect(formatWorkClock(entry.durationAt(DateTime.now())), '00:00:42');
  });

  test(
    'timer pause, resume, and stop preserve distinct actual intervals',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Write'));
      var run = await repository.startTimer(task.id);
      expect(run.state, TimerState.running);
      await expectLater(repository.startTimer(task.id), throwsStateError);
      expect(
        (await repository.timeEntries(taskId: task.id)).single.endsAt,
        isNull,
      );
      await repository.pauseTimer(run);
      run = (await repository.activeTimerRun())!;
      expect(run.state, TimerState.paused);
      expect(
        (await repository.timeEntries(taskId: task.id)).single.endsAt,
        isNotNull,
      );
      await repository.resumeTimer(run);
      run = (await repository.activeTimerRun())!;
      expect(run.state, TimerState.running);
      expect(await repository.timeEntries(taskId: task.id), hasLength(2));
      await repository.stopTimer(run);
      expect(await repository.activeTimerRun(), isNull);
      expect(
        (await repository.timeEntries(taskId: task.id))
            .every((item) => item.endsAt != null),
        isTrue,
      );
      expect((await repository.tasks()).single.status, TaskStatus.notStarted);
    },
  );

  test(
    'recovered running timer requires an explicit elapsed-time choice',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Study'));
      await repository.startTimer(task.id);
      await database.customUpdate(
        'UPDATE timer_runs SET last_seen_at=?',
        variables: [Variable.withString('2020-10-19T10:00:00Z')],
      );
      final recovered = (await repository.activeTimerRun())!;
      expect(recovered.needsReview(DateTime.now()), isTrue);
      await expectLater(repository.pauseTimer(recovered), throwsStateError);
      await repository.stopRecoveredTimerAtCheckpoint(recovered);
      expect(await repository.activeTimerRun(), isNull);
      final entry = (await repository.timeEntries()).single;
      expect(entry.endsAt, entry.startsAt);
    },
  );

  test(
    'manual actual work can be corrected without changing planned sessions',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Read'));
      final session = await repository.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime.utc(2020, 10, 19, 9),
          endsAt: DateTime.utc(2020, 10, 19, 10),
        ),
      );
      await repository.addManualTime(
        task.id,
        DateTime.utc(2020, 10, 19, 9),
        DateTime.utc(2020, 10, 19, 9, 30),
        'First half',
        sessionId: session.id,
      );
      final first = (await repository.timeEntries()).single;
      expect(first.sessionId, session.id);
      expect(first.durationAt(DateTime.now()).inMinutes, 30);
      await repository.updateManualTime(
        first,
        DateTime.utc(2020, 10, 19, 9),
        DateTime.utc(2020, 10, 19, 9, 45),
        'Corrected',
      );
      await expectLater(
        repository.updateManualTime(
          first,
          DateTime.utc(2020, 10, 19, 9),
          DateTime.utc(2020, 10, 19, 10),
          'Stale',
        ),
        throwsStateError,
      );
      final corrected = (await repository.timeEntries()).single;
      expect(corrected.durationAt(DateTime.now()).inMinutes, 45);
      expect(
        (await repository.sessions()).single.outcome,
        SessionOutcome.upcoming,
      );
      await repository.clearManualTime(corrected);
      expect(await repository.timeEntries(), isEmpty);
      expect(
        (await database
                .customSelect('SELECT COUNT(*) AS n FROM time_entry_history')
                .getSingle())
            .read<int>('n'),
        2,
      );
    },
  );

  test(
    'overlapping work logs count once and future work is rejected',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Work'));
      await repository.addManualTime(
        task.id,
        DateTime.utc(2020, 10, 19, 9),
        DateTime.utc(2020, 10, 19, 10),
        '',
      );
      await repository.addManualTime(
        task.id,
        DateTime.utc(2020, 10, 19, 9, 30),
        DateTime.utc(2020, 10, 19, 10, 30),
        '',
      );
      expect(
        TimeEntry.distinctDuration(
          await repository.timeEntries(),
          DateTime.now(),
        ).inMinutes,
        90,
      );
      await expectLater(
        repository.addManualTime(
          task.id,
          DateTime.now().add(const Duration(hours: 1)),
          DateTime.now().add(const Duration(hours: 2)),
          '',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'v9 migrates to time tracking while retaining goals and habits',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('life-time-v9-');
      final file = File('${directory.path}/legacy.sqlite');
      try {
        final initial = AppDatabase(NativeDatabase(file));
        final task = await LifeRepository(initial)
            .addTask(const TaskDraft(title: 'Keep'));
        await initial.close();
        final raw = sqlite.sqlite3.open(file.path);
        try {
          raw.execute('DROP TABLE time_entry_history');
          raw.execute('DROP TABLE time_entries');
          raw.execute('DROP TABLE timer_runs');
          raw.execute('PRAGMA user_version = 9');
        } finally {
          raw.close();
        }
        final upgraded = AppDatabase(NativeDatabase(file));
        try {
          final repo = LifeRepository(upgraded);
          expect((await repo.tasks()).single.id, task.id);
          expect(await repo.timeEntries(), isEmpty);
          expect((await repo.startTimer(task.id)).taskId, task.id);
        } finally {
          await upgraded.close();
        }
        final reopened = AppDatabase(NativeDatabase(file));
        try {
          expect(
            (await LifeRepository(reopened).activeTimerRun())?.taskId,
            task.id,
          );
        } finally {
          await reopened.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
