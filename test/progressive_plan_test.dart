import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/series_edit.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  String day(int offset) =>
      RecurrenceRule.shiftDate(localDate(DateTime.now()), offset);

  test(
    'successive occurrences keep stable study steps after restart',
    () async {
      final root = await Directory.systemTemp.createTemp('life-plan-');
      final file = File('${root.path}${Platform.pathSeparator}plan.sqlite');
      try {
        final db = AppDatabase(NativeDatabase(file));
        final repo = LifeRepository(db);
        final first = await repo.addRecurringTask(
          TaskDraft(title: 'Study', scheduledDate: day(1)),
          RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: day(1),
            maxOccurrences: 4,
          ),
          progressiveSteps: ['Watch', 'Revise', 'Practice'],
        );
        await repo.ensureRecurringTasks(day(1), day(4));
        final assignments = await repo.progressiveAssignments();
        final tasks = await repo.tasks();
        expect(
          [
            for (final offset in [1, 2, 3, 4])
              assignments[tasks
                      .singleWhere((t) => t.nominalDate == day(offset))
                      .id]
                  ?.title,
          ],
          ['Watch', 'Revise', 'Practice', null],
        );
        expect((await repo.progressivePlan(first.id))?.repeatAtEnd, false);
        await db.close();

        final reopened = AppDatabase(NativeDatabase(file));
        final again = LifeRepository(reopened);
        await again.ensureRecurringTasks(day(1), day(4));
        expect(
          (await again.progressiveAssignments())[first.id]?.title,
          'Watch',
        );
        expect((await again.tasks()).length, 4);
        await reopened.close();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('skipping can carry or continue without completing the task', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    try {
      await repo.addRecurringTask(
        TaskDraft(title: 'Study', scheduledDate: day(1)),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: day(1),
          maxOccurrences: 4,
        ),
        progressiveSteps: ['Watch', 'Revise', 'Practice'],
      );
      await repo.ensureRecurringTasks(day(1), day(4));
      final tasks = await repo.tasks();
      final first = tasks.singleWhere((t) => t.nominalDate == day(1));
      final second = tasks.singleWhere((t) => t.nominalDate == day(2));
      await repo.skipRecurringOccurrence(first, carryPlan: true);
      var assignments = await repo.progressiveAssignments();
      expect(assignments[second.id]?.title, 'Watch');
      await repo.skipRecurringOccurrence(second, carryPlan: false);
      assignments = await repo.progressiveAssignments();
      expect(
        assignments[tasks.singleWhere((t) => t.nominalDate == day(3)).id]
            ?.title,
        'Revise',
      );
      expect(
        (await repo.tasks()).where((t) => t.status == TaskStatus.completed),
        isEmpty,
      );
    } finally {
      await db.close();
    }
  });

  test(
    'future edits and manual assignment preserve historical snapshots',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      try {
        final first = await repo.addRecurringTask(
          TaskDraft(title: 'Study', scheduledDate: day(-1)),
          RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: day(-1),
            maxOccurrences: 4,
          ),
          progressiveSteps: ['Old watch', 'Old revise', 'Old practice'],
        );
        await repo.ensureRecurringTasks(day(-1), day(2));
        final tasks = await repo.tasks();
        final future = tasks.singleWhere((t) => t.nominalDate == day(2));
        await repo.reassignProgressiveStep(future.id, 0);
        await repo.configureProgressivePlan(first.id, [
          'New watch',
          'New revise',
          'New practice',
        ], repeatAtEnd: true);
        final assignments = await repo.progressiveAssignments();
        expect(assignments[first.id]?.title, 'Old watch');
        expect(
          assignments[tasks.singleWhere((t) => t.nominalDate == day(0)).id]
              ?.title,
          'New revise',
        );
        expect(assignments[future.id]?.title, 'Old watch');
        expect(assignments[future.id]?.manual, true);
      } finally {
        await db.close();
      }
    },
  );

  test('recurrence split keeps historical plan assignment', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    try {
      final first = await repo.addRecurringTask(
        TaskDraft(title: 'Study', scheduledDate: day(-1)),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: day(-1),
          maxOccurrences: 5,
        ),
        progressiveSteps: ['A', 'B', 'C', 'D', 'E'],
      );
      await repo.ensureRecurringTasks(day(-1), day(3));
      final tasks = await repo.tasks();
      final selected = tasks.singleWhere((t) => t.nominalDate == day(0));
      final preview = await repo.previewSeriesEdit(
        selected: selected,
        scope: SeriesEditScope.thisAndFuture,
        draft: TaskDraft(title: 'Study', scheduledDate: day(0)),
        rule: RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: day(0),
          interval: 2,
          maxOccurrences: 3,
        ),
      );
      await repo.applySeriesEdit(preview, {
        for (final collision in preview.collisions)
          collision.nominalDate: SeriesCollisionChoice.combine,
      });
      await repo.ensureRecurringTasks(day(-1), day(4));
      final after = await repo.tasks();
      final assignments = await repo.progressiveAssignments();
      expect(assignments[first.id]?.title, 'A');
      expect(assignments[selected.id]?.title, 'B');
      expect(
        assignments[after.singleWhere((t) => t.nominalDate == day(2)).id]
            ?.title,
        'C',
      );
    } finally {
      await db.close();
    }
  });

  test('schema v18 upgrades without altering existing tasks', () async {
    final root = await Directory.systemTemp.createTemp('life-plan-v18-');
    final file = File('${root.path}${Platform.pathSeparator}legacy.sqlite');
    try {
      final before = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(before)
          .addTask(const TaskDraft(title: 'Existing work'));
      await before.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE progressive_plan_assignments');
        raw.execute('DROP TABLE progressive_plan_steps');
        raw.execute('DROP TABLE progressive_plans');
        raw.execute('DROP TABLE event_reminder_deliveries');
        raw.execute('PRAGMA user_version=18');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        expect((await LifeRepository(upgraded).tasks()).single.id, task.id);
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          AppDatabase.currentSchemaVersion,
        );
        expect(
          (await upgraded
              .customSelect(
                "SELECT name FROM sqlite_master WHERE name='progressive_plans'",
              )
              .get()),
          hasLength(1),
        );
        expect(
          (await upgraded.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      } finally {
        await upgraded.close();
      }
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('schema v19 reminder migration preserves events and plans', () async {
    final root = await Directory.systemTemp.createTemp('life-reminder-v19-');
    final file = File('${root.path}${Platform.pathSeparator}legacy.sqlite');
    try {
      final before = AppDatabase(NativeDatabase(file));
      final repo = LifeRepository(before);
      final event = await repo.addEvent(
        EventDraft(
          title: 'Lecture',
          startsAt: DateTime(2026, 10, 20, 9),
          endsAt: DateTime(2026, 10, 20, 10),
          reminderMinutes: 15,
        ),
      );
      final task = await repo.addRecurringTask(
        TaskDraft(title: 'Study', scheduledDate: day(1)),
        RecurrenceRule(kind: RecurrenceKind.daily, startDate: day(1)),
        progressiveSteps: ['Watch'],
      );
      await before.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE event_reminder_deliveries');
        raw.execute('PRAGMA user_version=19');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final reopened = LifeRepository(upgraded);
        expect((await reopened.events()).single.id, event.id);
        expect((await reopened.events()).single.reminderMinutes, 15);
        expect((await reopened.progressivePlan(task.id))?.steps, ['Watch']);
        expect(
          (await upgraded.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      } finally {
        await upgraded.close();
      }
    } finally {
      await root.delete(recursive: true);
    }
  });
}
