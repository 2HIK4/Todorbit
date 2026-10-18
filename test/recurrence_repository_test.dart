import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
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

  test('fixed occurrences have stable IDs and independent edits', () async {
    final first = await repository.addRecurringTask(
      const TaskDraft(title: 'Study', scheduledDate: '2026-10-17'),
      RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-10-17',
        maxOccurrences: 3,
      ),
    );
    expect(first.nominalDate, '2026-10-17');
    await repository.ensureRecurringTasks('2026-10-17', '2026-10-31');
    var tasks = await repository.tasks();
    expect(tasks.map((task) => task.nominalDate).toSet(), {
      '2026-10-17',
      '2026-10-18',
      '2026-10-19',
    });
    final ids = {for (final task in tasks) task.nominalDate: task.id};
    await repository.updateTask(
      first,
      const TaskDraft(title: 'Long study', scheduledDate: '2026-10-20'),
    );
    await repository.ensureRecurringTasks('2026-10-17', '2026-10-31');
    tasks = await repository.tasks();
    expect(tasks, hasLength(3));
    expect({for (final task in tasks) task.nominalDate: task.id}, ids);
    expect(tasks.firstWhere((task) => task.id == first.id).title, 'Long study');
    final edited = tasks.firstWhere((task) => task.id == first.id);
    expect(edited.recurrenceEdited, isTrue);
    expect(edited.recurrenceRescheduled, isTrue);
    expect(
      tasks.firstWhere((task) => task.nominalDate == '2026-10-18').title,
      'Study',
    );
    final second = tasks.firstWhere((task) => task.nominalDate == '2026-10-18');
    await repository.skipRecurringOccurrence(second);
    await repository.ensureRecurringTasks('2026-10-17', '2026-10-31');
    tasks = await repository.tasks();
    expect(tasks, hasLength(3));
    final skipped = tasks.firstWhere((task) => task.id == second.id);
    expect(skipped.status, TaskStatus.cancelled);
    expect(skipped.recurrenceDisposition, 'skipped');
  });

  test(
    'completion recurrence advances once from actual local completion',
    () async {
      final today = localDate(DateTime.now());
      final first = await repository.addRecurringTask(
        TaskDraft(title: 'Check supplies', scheduledDate: today),
        RecurrenceRule(
          kind: RecurrenceKind.afterCompletion,
          startDate: today,
          interval: 3,
          maxOccurrences: 2,
        ),
      );
      await repository.setComplete(first, true);
      var tasks = await repository.tasks();
      expect(tasks, hasLength(2));
      final next = tasks.singleWhere(
        (task) => task.status != TaskStatus.completed,
      );
      expect(next.recurrenceOrdinal, 1);
      expect(next.scheduledDate, RecurrenceRule.shiftDate(today, 3));
      await expectLater(repository.setComplete(first, true), throwsStateError);
      expect(await repository.tasks(), hasLength(2));
      await expectLater(
        repository.setComplete(
          tasks.singleWhere((task) => task.status == TaskStatus.completed),
          false,
        ),
        throwsStateError,
      );
      await repository.setComplete(next, true);
      tasks = await repository.tasks();
      expect(tasks, hasLength(2));
      expect(
        tasks.every((task) => task.status == TaskStatus.completed),
        isTrue,
      );
    },
  );

  test(
    'Smart Reschedule moves one occurrence without changing its rule',
    () async {
      final first = await repository.addRecurringTask(
        const TaskDraft(title: 'Practice', scheduledDate: '2026-10-17'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-17',
          maxOccurrences: 3,
        ),
      );
      final preview = const SchedulingEngine().shiftTasks(
        selected: [first],
        days: 3,
        scope: 'recurrence:test',
      );
      await repository.applySchedulingPreview(preview);
      await repository.ensureRecurringTasks('2026-10-17', '2026-10-31');
      final tasks = await repository.tasks();
      expect(tasks, hasLength(3));
      final moved = tasks.singleWhere((task) => task.id == first.id);
      expect(moved.nominalDate, '2026-10-17');
      expect(moved.scheduledDate, '2026-10-20');
      expect(moved.recurrenceRescheduled, isTrue);
      expect(tasks.map((task) => task.nominalDate).toSet(), {
        '2026-10-17',
        '2026-10-18',
        '2026-10-19',
      });
    },
  );

  test('skipped completion series resumes only on an explicit day', () async {
    final today = localDate(DateTime.now());
    final first = await repository.addRecurringTask(
      TaskDraft(title: 'Review', scheduledDate: today),
      RecurrenceRule(
        kind: RecurrenceKind.afterCompletion,
        startDate: today,
        interval: 3,
        maxOccurrences: 3,
      ),
    );
    await repository.skipRecurringOccurrence(first);
    var tasks = await repository.tasks();
    expect(tasks, hasLength(1));
    final skipped = tasks.single;
    expect(skipped.recurrenceDisposition, 'skipped');
    final chosen = RecurrenceRule.shiftDate(today, 2);
    final resumed = await repository.resumeCompletionSeries(skipped, chosen);
    expect(resumed.recurrenceOrdinal, 1);
    expect(resumed.scheduledDate, chosen);
    await expectLater(
      repository.resumeCompletionSeries(skipped, chosen),
      throwsStateError,
    );
    await repository.setComplete(resumed, true);
    tasks = await repository.tasks();
    expect(tasks, hasLength(3));
    expect(
      tasks.singleWhere((task) => task.recurrenceOrdinal == 2).scheduledDate,
      RecurrenceRule.shiftDate(today, 3),
    );
  });

  test('v5 migration preserves tasks and adds recurrence tables', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life_recurrence_');
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      final oldTask = await LifeRepository(first).addTask(
        const TaskDraft(title: 'Preserve', scheduledDate: '2026-10-17'),
      );
      await first.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TRIGGER recurrence_task_schedule_updated');
      raw.execute('DROP TRIGGER recurrence_task_content_updated');
      raw.execute('DROP TRIGGER recurrence_task_cancelled');
      raw.execute('DROP TABLE series_edit_history');
      raw.execute('DROP TABLE recurrence_collision_history');
      raw.execute('DROP TABLE recurrence_occurrences');
      raw.execute('DROP TABLE recurrence_series');
      raw.execute('PRAGMA user_version = 5');
      raw.close();
      final migrated = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(migrated);
        expect((await repo.tasks()).single.id, oldTask.id);
        await repo.addRecurringTask(
          const TaskDraft(title: 'Repeat', scheduledDate: '2026-10-17'),
          RecurrenceRule(kind: RecurrenceKind.weekly, startDate: '2026-10-17'),
        );
        expect(await repo.tasks(), hasLength(2));
      } finally {
        await migrated.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('occurrence IDs, completion, and skip survive restart', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life_series_');
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    try {
      final firstDatabase = AppDatabase(NativeDatabase(file));
      final firstRepository = LifeRepository(firstDatabase);
      final first = await firstRepository.addRecurringTask(
        const TaskDraft(title: 'Review', scheduledDate: '2026-10-17'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-17',
          maxOccurrences: 3,
        ),
      );
      await firstRepository.ensureRecurringTasks('2026-10-17', '2026-10-19');
      final before = await firstRepository.tasks();
      final ids = {for (final task in before) task.nominalDate: task.id};
      await firstRepository.setComplete(first, true);
      await firstRepository.skipRecurringOccurrence(
        before.singleWhere((task) => task.nominalDate == '2026-10-18'),
      );
      await firstDatabase.close();

      final reopened = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(reopened);
        await repo.ensureRecurringTasks('2026-10-17', '2026-10-19');
        final after = await repo.tasks();
        expect(after, hasLength(3));
        expect({for (final task in after) task.nominalDate: task.id}, ids);
        expect(
          after.singleWhere((task) => task.nominalDate == '2026-10-17').status,
          TaskStatus.completed,
        );
        expect(
          after
              .singleWhere((task) => task.nominalDate == '2026-10-18')
              .recurrenceDisposition,
          'skipped',
        );
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
