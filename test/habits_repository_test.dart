import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late LifeRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });
  tearDown(() async => database.close());

  HabitDraft daily({HabitKind kind = HabitKind.binary, double? target}) =>
      HabitDraft(
        title: 'Read',
        kind: kind,
        target: target,
        unit: kind == HabitKind.binary ? '' : 'pages',
        rule: RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2020-10-19',
        ),
      );

  test(
    'habit entries and rest days produce real progress without task backlog',
    () async {
      final habit = await repository.addHabit(daily());
      await repository.recordHabitDay(habit, '2020-10-19', 1);
      await repository.addHabitRestDay(habit, '2020-10-20');
      var stats = HabitStatistics.calculate(
        habit: habit,
        entries: await repository.habitEntries(),
        restDays: await repository.habitRestDays(),
        fromDate: '2020-10-19',
        throughDate: '2020-10-21',
        today: '2020-10-21',
      );
      expect(stats.due, 1);
      expect(stats.successful, 1);
      expect(stats.streak, 1);
      await repository.recordHabitDay(habit, '2020-10-21', 1);
      stats = HabitStatistics.calculate(
        habit: habit,
        entries: await repository.habitEntries(),
        restDays: await repository.habitRestDays(),
        fromDate: '2020-10-19',
        throughDate: '2020-10-21',
        today: '2020-10-21',
      );
      expect(stats.due, 2);
      expect(stats.successful, 2);
      expect(stats.completionRate, 1);
      expect(stats.streak, 2);
      expect(await repository.tasks(), isEmpty);
    },
  );

  test(
    'minimum and maximum targets use recorded values and allow correction',
    () async {
      final minimum = await repository.addHabit(
        daily(kind: HabitKind.minimum, target: 20),
      );
      final maximum = await repository.addHabit(
        HabitDraft(
          title: 'Screen time',
          kind: HabitKind.maximum,
          target: 3,
          unit: 'hours',
          rule: RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2020-10-19',
          ),
        ),
      );
      await repository.recordHabitDay(minimum, '2020-10-19', 12);
      await repository.recordHabitDay(maximum, '2020-10-19', 2.5);
      expect(
        minimum.succeeds(
          (await repository.habitEntries(habitId: minimum.id)).single.value,
        ),
        isFalse,
      );
      expect(
        maximum.succeeds(
          (await repository.habitEntries(habitId: maximum.id)).single.value,
        ),
        isTrue,
      );
      final old = (await repository.habitEntries(habitId: minimum.id)).single;
      await repository.recordHabitDay(
        minimum,
        '2020-10-19',
        24,
        previous: old,
        notes: 'Corrected count',
      );
      await expectLater(
        repository.recordHabitDay(minimum, '2020-10-19', 25, previous: old),
        throwsStateError,
      );
      expect(
        (await repository.habitEntries(habitId: minimum.id)).single.value,
        24,
      );
      expect(
        (await database
                .customSelect(
                  'SELECT COUNT(*) AS n FROM habit_entry_history WHERE habit_id=?',
                  variables: [Variable.withString(minimum.id)],
                )
                .getSingle())
            .read<int>('n'),
        2,
      );
    },
  );

  test(
    'rest days reject recorded values and historical clearing is audited',
    () async {
      final habit = await repository.addHabit(daily());
      await repository.recordHabitDay(habit, '2020-10-19', 0);
      await expectLater(
        repository.addHabitRestDay(habit, '2020-10-19'),
        throwsStateError,
      );
      final entry = (await repository.habitEntries()).single;
      await repository.clearHabitDay(entry);
      await repository.addHabitRestDay(habit, '2020-10-19');
      expect(await repository.habitEntries(), isEmpty);
      expect(await repository.habitRestDays(), hasLength(1));
    },
  );

  test('selected weekdays and rest preserve a measured streak', () async {
    final habit = await repository.addHabit(
      HabitDraft(
        title: 'Exercise',
        kind: HabitKind.binary,
        rule: RecurrenceRule(
          kind: RecurrenceKind.weekdays,
          startDate: '2020-10-19',
          weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        ),
      ),
    );
    await repository.recordHabitDay(habit, '2020-10-19', 1);
    await repository.addHabitRestDay(habit, '2020-10-21');
    await repository.recordHabitDay(habit, '2020-10-23', 1);
    final stats = HabitStatistics.calculate(
      habit: habit,
      entries: await repository.habitEntries(),
      restDays: await repository.habitRestDays(),
      fromDate: '2020-10-19',
      throughDate: '2020-10-25',
      today: '2020-10-25',
    );
    expect(stats.due, 2);
    expect(stats.successful, 2);
    expect(stats.streak, 2);
  });

  test(
    'rule edits and archive preserve logs but reject stale logging',
    () async {
      final old = await repository.addHabit(daily());
      await repository.recordHabitDay(old, '2020-10-19', 1);
      await repository.updateHabit(
        old,
        HabitDraft(
          title: 'Read weekly',
          kind: HabitKind.binary,
          rule: RecurrenceRule(
            kind: RecurrenceKind.weekly,
            startDate: '2020-10-19',
          ),
        ),
      );
      await expectLater(
        repository.recordHabitDay(old, '2020-10-20', 1),
        throwsStateError,
      );
      expect(await repository.habitEntries(), hasLength(1));
      final current = (await repository.habits()).single;
      await repository.setHabitArchived(current, true);
      expect(await repository.habits(), isEmpty);
      expect(await repository.habits(includeArchived: true), hasLength(1));
      await expectLater(
        repository.recordHabitDay(current, '2020-10-26', 1),
        throwsStateError,
      );
    },
  );

  test('v7 migration adds habits without changing recurrence data', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('life-habits-v7-');
    final file = File('${directory.path}/legacy.sqlite');
    try {
      final initial = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(initial).addRecurringTask(
        const TaskDraft(title: 'Legacy', scheduledDate: '2020-10-19'),
        RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2020-10-19'),
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
        raw.execute('PRAGMA user_version = 7');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      late String habitId;
      try {
        final repo = LifeRepository(upgraded);
        expect((await repo.tasks()).single.id, task.id);
        expect(await repo.habits(), isEmpty);
        final habit = await repo.addHabit(daily());
        habitId = habit.id;
        await repo.recordHabitDay(habit, '2020-10-19', 1);
      } finally {
        await upgraded.close();
      }
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(reopened);
        expect((await repo.habits()).single.id, habitId);
        expect((await repo.habitEntries()).single.value, 1);
        expect((await repo.tasks()).single.id, task.id);
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
