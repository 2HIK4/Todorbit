import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/series_edit.dart';
import 'package:life_manager/domain/scheduling_models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });
  tearDown(() async => database.close());

  Future<List<LifeTask>> dailyWeek() async {
    await repository.addRecurringTask(
      const TaskDraft(title: 'Review', scheduledDate: '2026-10-19'),
      RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-10-19',
        maxOccurrences: 7,
      ),
    );
    await repository.ensureRecurringTasks('2026-10-19', '2026-10-25');
    return repository.tasks();
  }

  LifeTask on(List<LifeTask> tasks, String date) =>
      tasks.singleWhere((task) => task.nominalDate == date);

  test('v6 recurrence rows migrate into a versioned family', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life-series-v6-');
    final file = File('${directory.path}/legacy.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      await LifeRepository(initial).addRecurringTask(
        const TaskDraft(title: 'Legacy', scheduledDate: '2026-10-19'),
        RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2026-10-19'),
      );
      await initial.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE goal_habit_links');
        raw.execute('DROP TABLE goal_project_links');
        raw.execute('DROP TABLE goal_task_links');
        raw.execute('DROP TABLE goal_progress_entries');
        raw.execute('DROP TABLE goal_milestones');
        raw.execute('DROP TABLE goals');
        raw.execute('DROP TABLE habit_entry_history');
        raw.execute('DROP TABLE habit_rest_days');
        raw.execute('DROP TABLE habit_entries');
        raw.execute('DROP TABLE habits');
        raw.execute('DROP TABLE series_edit_history');
        raw.execute('DROP TABLE recurrence_collision_history');
        raw.execute('DROP INDEX recurrence_series_family');
        raw.execute(
          'ALTER TABLE recurrence_series DROP COLUMN active_through_date',
        );
        raw.execute(
          'ALTER TABLE recurrence_series DROP COLUMN active_from_date',
        );
        raw.execute('ALTER TABLE recurrence_series DROP COLUMN family_id');
        raw.execute('PRAGMA user_version = 6');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final task = (await LifeRepository(upgraded).tasks()).single;
        final preview = await LifeRepository(upgraded).previewSeriesEdit(
          selected: task,
          scope: SeriesEditScope.thisAndFuture,
          draft: const TaskDraft(title: 'Updated', scheduledDate: '2026-10-19'),
          rule: RecurrenceRule(
            kind: RecurrenceKind.weekly,
            startDate: '2026-10-19',
          ),
        );
        expect(preview.familyId, task.recurrenceSeriesId);
      } finally {
        await upgraded.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('this and future preserves history and linked work', () async {
    final before = await dailyWeek();
    await repository.setComplete(on(before, '2026-10-19'), true);
    final linked = on(before, '2026-10-22');
    await repository.addSession(
      SessionDraft(
        taskId: linked.id,
        startsAt: DateTime.utc(2026, 10, 22, 9),
        endsAt: DateTime.utc(2026, 10, 22, 10),
      ),
    );
    final selected = on(before, '2026-10-21');
    final preview = await repository.previewSeriesEdit(
      selected: selected,
      scope: SeriesEditScope.thisAndFuture,
      draft: const TaskDraft(title: 'New review', scheduledDate: '2026-10-21'),
      rule: RecurrenceRule(
        kind: RecurrenceKind.weekdays,
        startDate: '2026-10-21',
        weekdays: {DateTime.wednesday, DateTime.friday},
        maxOccurrences: 4,
      ),
    );
    expect(preview.effectiveDate, '2026-10-21');
    expect(
      preview.impacts.singleWhere((item) => item.taskId == linked.id).kind,
      SeriesImpactKind.preserve,
    );
    expect(preview.collisions.map((item) => item.nominalDate), [
      '2026-10-21',
      '2026-10-23',
    ]);
    await repository.applySeriesEdit(preview, {
      for (final collision in preview.collisions)
        collision.nominalDate: SeriesCollisionChoice.combine,
    });
    await repository.ensureRecurringTasks('2026-10-19', '2026-10-31');
    final after = await repository.tasks();
    expect(on(after, '2026-10-19').status, TaskStatus.completed);
    expect(on(after, '2026-10-19').id, on(before, '2026-10-19').id);
    expect(on(after, '2026-10-21').id, selected.id);
    expect(on(after, '2026-10-21').title, 'New review');
    expect(after.singleWhere((task) => task.id == linked.id).title, 'Review');
    expect((await repository.sessions()).single.taskId, linked.id);
    expect(
      after.any((task) => task.id == on(before, '2026-10-24').id),
      isFalse,
    );
    expect(after.any((task) => task.nominalDate == '2026-10-28'), isTrue);
  });

  test('this and future rejects an old count anchor', () async {
    final before = await dailyWeek();
    await expectLater(
      repository.previewSeriesEdit(
        selected: on(before, '2026-10-21'),
        scope: SeriesEditScope.thisAndFuture,
        draft: const TaskDraft(title: 'Changed', scheduledDate: '2026-10-21'),
        rule: RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 3,
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'series preview finds a rescheduled exception on its planned day',
    () async {
      final before = await dailyWeek();
      final moved = on(before, '2026-10-22');
      await repository.updateTask(
        moved,
        const TaskDraft(title: 'Review', scheduledDate: '2026-10-30'),
      );
      final preview = await repository.previewSeriesEdit(
        selected: on(before, '2026-10-21'),
        scope: SeriesEditScope.thisAndFuture,
        draft: const TaskDraft(title: 'Changed', scheduledDate: '2026-10-21'),
        rule: RecurrenceRule(
          kind: RecurrenceKind.weekly,
          startDate: '2026-10-23',
        ),
      );
      final collision = preview.collisions.singleWhere(
        (item) => item.nominalDate == '2026-10-30',
      );
      expect(collision.existingTaskIds, [moved.id]);
      expect(collision.canCombine, isFalse);
      await expectLater(
        repository.applySeriesEdit(preview, {
          '2026-10-23': SeriesCollisionChoice.combine,
        }),
        throwsArgumentError,
      );
      await repository.applySeriesEdit(preview, {
        '2026-10-23': SeriesCollisionChoice.combine,
        '2026-10-30': SeriesCollisionChoice.skipNew,
      });
      final after = await repository.tasks();
      expect(
        after.singleWhere((item) => item.id == moved.id).scheduledDate,
        '2026-10-30',
      );
      expect(
        after.where((item) => item.scheduledDate == '2026-10-30'),
        hasLength(1),
      );
    },
  );

  test(
    'Smart Reschedule collision requires a reviewed skip or keep choice',
    () async {
      final before = await dailyWeek();
      final moved = on(before, '2026-10-19');
      final existing = on(before, '2026-10-20');
      final proposal = SchedulingPreview(
        operation: ScheduleOperationType.move,
        scope: 'test',
        changes: [
          ScheduleChange(
            targetKind: ScheduleTargetKind.task,
            targetId: moved.id,
            expectedUpdatedAt: moved.updatedAt,
            beforeDate: moved.scheduledDate,
            afterDate: '2026-10-20',
          ),
        ],
        issues: const [],
        createdAt: DateTime.now().toUtc(),
      );
      final collisions = await repository.scheduleSeriesCollisions(proposal);
      expect(collisions.single.existingTaskIds, [existing.id]);
      await expectLater(
        repository.applySchedulingPreview(proposal),
        throwsStateError,
      );
      await repository.applySchedulingPreview(
        proposal,
        expectedSeriesCollisions: collisions,
        seriesChoices: {moved.id: SeriesCollisionChoice.skipNew},
      );
      final after = await repository.tasks();
      expect(
        after.singleWhere((item) => item.id == moved.id).status,
        TaskStatus.cancelled,
      );
      expect(
        after.singleWhere((item) => item.id == existing.id).scheduledDate,
        '2026-10-20',
      );
      expect(
        (await database
                .customSelect('SELECT choice FROM recurrence_collision_history')
                .getSingle())
            .read<String>('choice'),
        'skipNew',
      );
    },
  );

  test(
    'Smart Reschedule keep both preserves both occurrence identities',
    () async {
      final before = await dailyWeek();
      final moved = on(before, '2026-10-19');
      final existing = on(before, '2026-10-20');
      final proposal = SchedulingPreview(
        operation: ScheduleOperationType.move,
        scope: 'test',
        changes: [
          ScheduleChange(
            targetKind: ScheduleTargetKind.task,
            targetId: moved.id,
            expectedUpdatedAt: moved.updatedAt,
            beforeDate: moved.scheduledDate,
            afterDate: '2026-10-20',
          ),
        ],
        issues: const [],
        createdAt: DateTime.now().toUtc(),
      );
      final collisions = await repository.scheduleSeriesCollisions(proposal);
      await repository.applySchedulingPreview(
        proposal,
        expectedSeriesCollisions: collisions,
        seriesChoices: {moved.id: SeriesCollisionChoice.keepBoth},
      );
      final after = await repository.tasks();
      expect(
        after.where((item) => item.scheduledDate == '2026-10-20'),
        hasLength(2),
      );
      expect(
        after.singleWhere((item) => item.id == moved.id).nominalDate,
        '2026-10-19',
      );
      expect(
        after.singleWhere((item) => item.id == existing.id).nominalDate,
        '2026-10-20',
      );
    },
  );

  test(
    'collision choices keep, skip, and combine without duplicate IDs',
    () async {
      final before = await dailyWeek();
      final selected = on(before, '2026-10-19');
      final preview = await repository.previewSeriesEdit(
        selected: selected,
        scope: SeriesEditScope.thisAndFuture,
        draft: const TaskDraft(title: 'Changed', scheduledDate: '2026-10-19'),
        rule: RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 3,
        ),
      );
      await repository.applySeriesEdit(preview, {
        '2026-10-19': SeriesCollisionChoice.keepBoth,
        '2026-10-20': SeriesCollisionChoice.skipNew,
        '2026-10-21': SeriesCollisionChoice.combine,
      });
      final after = await repository.tasks();
      expect(
        after.where((task) => task.nominalDate == '2026-10-19'),
        hasLength(2),
      );
      expect(
        after.where((task) => task.nominalDate == '2026-10-20'),
        hasLength(1),
      );
      expect(on(after, '2026-10-21').id, on(before, '2026-10-21').id);
      final rows = await database
          .customSelect(
            "SELECT task_id,disposition FROM recurrence_occurrences WHERE nominal_date='2026-10-20'",
          )
          .get();
      expect(rows, hasLength(2));
      expect(
        rows.where((row) => row.read<String?>('task_id') == null),
        hasLength(1),
      );
      await repository.ensureRecurringTasks('2026-10-19', '2026-10-21');
      expect(await repository.tasks(), hasLength(after.length));
    },
  );

  test('stale preview rejects every change', () async {
    final before = await dailyWeek();
    final selected = on(before, '2026-10-21');
    final preview = await repository.previewSeriesEdit(
      selected: selected,
      scope: SeriesEditScope.thisAndFuture,
      draft: const TaskDraft(title: 'Changed', scheduledDate: '2026-10-21'),
      rule: RecurrenceRule(
        kind: RecurrenceKind.weekly,
        startDate: '2026-10-21',
      ),
    );
    await repository.updateTask(
      on(before, '2026-10-23'),
      const TaskDraft(title: 'Individual edit', scheduledDate: '2026-10-23'),
    );
    await expectLater(
      repository.applySeriesEdit(preview, {
        '2026-10-21': SeriesCollisionChoice.combine,
      }),
      throwsStateError,
    );
    expect(
      (await database
              .customSelect('SELECT COUNT(*) AS n FROM recurrence_series')
              .getSingle())
          .read<int>('n'),
      1,
    );
    expect((await repository.tasks()).length, before.length);
  });

  test('a second linked session invalidates a reviewed series edit', () async {
    final before = await dailyWeek();
    final linked = on(before, '2026-10-22');
    await repository.addSession(
      SessionDraft(
        taskId: linked.id,
        startsAt: DateTime.utc(2026, 10, 22, 9),
        endsAt: DateTime.utc(2026, 10, 22, 10),
      ),
    );
    final selected = on(before, '2026-10-21');
    final preview = await repository.previewSeriesEdit(
      selected: selected,
      scope: SeriesEditScope.thisAndFuture,
      draft: const TaskDraft(title: 'Changed', scheduledDate: '2026-10-21'),
      rule: RecurrenceRule(
        kind: RecurrenceKind.weekly,
        startDate: '2026-10-21',
      ),
    );
    await repository.addSession(
      SessionDraft(
        taskId: linked.id,
        startsAt: DateTime.utc(2026, 10, 22, 11),
        endsAt: DateTime.utc(2026, 10, 22, 12),
      ),
    );
    await expectLater(
      repository.applySeriesEdit(preview, {
        '2026-10-21': SeriesCollisionChoice.combine,
      }),
      throwsStateError,
    );
  });

  test('entire series changes pending rule while preserving completed and edited history', () async {
    final before = await dailyWeek();
    await repository.setComplete(on(before, '2026-10-19'), true);
    await repository.updateTask(
      on(before, '2026-10-22'),
      const TaskDraft(title: 'Hand edited', scheduledDate: '2026-10-22'),
    );
    final category = await repository.addCategory('Learning');
    final selected = on(before, '2026-10-25');
    final preview = await repository.previewSeriesEdit(
      selected: selected,
      scope: SeriesEditScope.entireSeries,
      draft: TaskDraft(
        title: 'New routine',
        categoryId: category.id,
        scheduledDate: '2026-10-20',
      ),
      rule: RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-10-20',
        interval: 2,
        maxOccurrences: 3,
      ),
    );
    expect(preview.effectiveDate, '2026-10-20');
    expect(
      preview.collisions
          .singleWhere((c) => c.nominalDate == '2026-10-22')
          .canCombine,
      isFalse,
    );
    await repository.applySeriesEdit(preview, {
      '2026-10-20': SeriesCollisionChoice.combine,
      '2026-10-22': SeriesCollisionChoice.skipNew,
      '2026-10-24': SeriesCollisionChoice.combine,
    });
    final audit = await database
        .customSelect('SELECT details_json FROM series_edit_history')
        .getSingle();
    expect(audit.read<String>('details_json'), contains('skip_new'));
    final after = await repository.tasks();
    expect(on(after, '2026-10-19').status, TaskStatus.completed);
    expect(on(after, '2026-10-19').categoryId, isNull);
    expect(on(after, '2026-10-20').categoryId, category.id);
    expect(
      after.singleWhere((task) => task.id == on(before, '2026-10-22').id).title,
      'Hand edited',
    );
    expect(
      after.where((task) => task.nominalDate == '2026-10-22'),
      hasLength(1),
    );
    expect(
      after.any((task) => task.id == on(before, '2026-10-23').id),
      isFalse,
    );
  });
}
