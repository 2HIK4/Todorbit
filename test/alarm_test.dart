import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/alarm_plan.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/platform/android/android_surfaces.dart';
import 'package:life_manager/domain/notifications.dart';

void main() {
  test(
    'alarm portable configuration round trips and rejects unsafe settings',
    () {
      final config = AlarmConfig(
        mode: 'custom',
        at: DateTime.utc(2027, 1, 1),
        sound: 'ringtone',
        durationSeconds: 60,
      );
      expect(AlarmConfig.fromJson(config.toJson()).sameAs(config), isTrue);
      for (final change in [
        <String, dynamic>{'durationSeconds': 0},
        {'durationSeconds': 30.0},
        {'minutesBefore': -1},
        {'sound': 'file:///private/device.wav'},
        {'mode': 'custom', 'at': null},
        {'vibrate': 'true'},
      ]) {
        expect(
          () => AlarmConfig.fromJson({...config.toJson(), ...change}),
          throwsFormatException,
        );
      }
    },
  );

  test('planned wall time and advance leave task dates separate', () {
    const alarm = AlarmConfig(
      mode: 'planned',
      localMinute: 600,
      minutesBefore: 30,
    );
    expect(
      alarm.trigger(plannedDay: '2027-01-02'),
      DateTime(2027, 1, 2, 9, 30).toUtc(),
    );
    expect(alarm.trigger(), isNull);
    expect(
      const AlarmConfig(
        mode: 'relative',
        minutesBefore: 15,
      ).trigger(start: DateTime.utc(2027, 1, 2, 10)),
      DateTime.utc(2027, 1, 2, 9, 45),
    );
  });

  group('alarm repository and bounded projection', () {
    late AppDatabase db;
    late LifeRepository repo;
    final now = DateTime.utc(2027, 1, 1, 6);
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LifeRepository(db);
    });
    tearDown(() => db.close());

    test('explicit alarm supersedes the legacy item reminder, including device-off mode', () async {
      final at = now.add(const Duration(hours: 1));
      await repo.addTask(
        TaskDraft(
          title: 'One alert',
          notification: TaskNotification(mode: 'custom', at: at),
          alarm: AlarmConfig(mode: 'custom', at: at),
        ),
      );
      final tasks = await repo.tasks();
      final rules = await repo.alarmRules();
      List<Map<String, Object>> plan(bool enabled) => androidReminderPlan(
        tasks: tasks,
        events: [],
        sessions: [],
        now: now,
        preferences: const MobilePreferences(),
        alarmRules: rules,
        alarmsEnabled: enabled,
      );
      expect(plan(true), hasLength(1));
      expect(plan(true).single['alarm'], true);
      expect(plan(false), isEmpty);
    });

    test('family edit is explicit, reviewed and removes only the selected override', () async {
      await repo.addRecurringTask(
        const TaskDraft(
          title: 'Family',
          scheduledDate: '2027-01-01',
          alarm: AlarmConfig(mode: 'planned', localMinute: 600),
        ),
        RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2027-01-01'),
      );
      await repo.ensureRecurringTasks('2027-01-01', '2027-01-03');
      final tasks = await repo.tasks();
      final task = tasks.first;
      final family = (await repo.alarmRules()).single;
      await repo.saveAlarm(
        AlarmConfig(mode: 'custom', at: now.add(const Duration(hours: 1))),
        taskId: task.id,
      );
      final override = (await repo.alarmRules()).singleWhere(
        (r) => r.taskId == task.id,
      );
      await repo.saveAlarm(const AlarmConfig(), taskId: tasks.last.id);
      await repo.updateTask(
        task,
        TaskDraft(
          title: task.title,
          scheduledDate: task.scheduledDate,
          alarm: const AlarmConfig(mode: 'planned', localMinute: 660),
          alarmForFamily: true,
          alarmReviewRevision: override.updatedAt,
          alarmFamilyReviewRevision: family.updatedAt,
        ),
      );
      final rules = await repo.alarmRules();
      expect(rules.where((r) => r.taskId == task.id), isEmpty);
      expect(
        rules.singleWhere((r) => r.seriesId != null).config.localMinute,
        660,
      );
      expect(
        rules.singleWhere((r) => r.taskId == tasks.last.id).config.enabled,
        isFalse,
      );
    });

    test('Android refresh retains ringing/snoozed receipts but never resurrects deleted plans', () async {
      await repo.addTask(
        TaskDraft(
          title: 'Retained delivery',
          alarm: AlarmConfig(
            mode: 'custom',
            at: now.subtract(const Duration(minutes: 10)),
          ),
        ),
      );
      final tasks = await repo.tasks();
      final rules = await repo.alarmRules();
      final raw = alarmPlan(
        rules: rules,
        tasks: tasks,
        events: [],
        sessions: [],
        now: now,
      ).single;
      final receipt = "${raw['key']}:${raw['occurrenceAt']}";
      List<Map<String, Object>> plan({
        bool retained = false,
        List<LifeTask>? current,
      }) => androidReminderPlan(
        tasks: current ?? tasks,
        sessions: [],
        events: [],
        now: now,
        preferences: const MobilePreferences(),
        alarmRules: rules,
        deliveredReceipts: {receipt},
        retainedAlarmReceipts: retained ? {receipt} : {},
      );
      expect(plan(), isEmpty);
      expect(plan(retained: true), hasLength(1));
      expect(plan(retained: true, current: []), isEmpty);
    });

    test(
      'creation is atomic; repeated saves retain one stable portable identity',
      () async {
        final task = await repo.addTask(
          TaskDraft(
            title: 'Alarm canary',
            alarm: AlarmConfig(
              mode: 'custom',
              at: now.add(const Duration(hours: 1)),
            ),
          ),
        );
        final first = (await repo.alarmRules()).single;
        await repo.saveAlarm(const AlarmConfig(), taskId: task.id);
        final off = (await repo.alarmRules()).single;
        expect(off.id, first.id);
        expect(off.config.enabled, isFalse);
        expect(
          await db
              .customSelect('PRAGMA user_version')
              .getSingle()
              .then((r) => r.data.values.single),
          28,
        );
        expect(
          (await db.customSelect('PRAGMA foreign_key_check').get()),
          isEmpty,
        );
        expect(
          () => repo.addTask(
            TaskDraft(
              title: 'Invalid',
              alarm: const AlarmConfig(sound: 'unsafe'),
            ),
          ),
          throwsFormatException,
        );
        expect((await repo.tasks()).length, 1);
      },
    );

    test(
      'edit/reschedule, completion and deletion remove the old OS plan',
      () async {
        final task = await repo.addTask(
          TaskDraft(
            title: 'Clock',
            alarm: AlarmConfig(
              mode: 'custom',
              at: now.add(const Duration(hours: 1)),
            ),
          ),
        );
        Future<List<Map<String, Object>>> plan() async => alarmPlan(
          rules: await repo.alarmRules(),
          tasks: await repo.tasks(),
          events: [],
          sessions: [],
          now: now,
        );
        final old = (await plan()).single;
        await repo.updateTask(
          task,
          TaskDraft(
            title: 'Clock',
            alarm: AlarmConfig(
              mode: 'custom',
              at: now.add(const Duration(hours: 2)),
            ),
          ),
        );
        expect((await plan()).single['key'], isNot(old['key']));
        await repo.setComplete((await repo.tasks()).single, true);
        expect(await plan(), isEmpty);
        await repo.deleteTask(task.id);
        expect(await plan(), isEmpty);
      },
    );

    test(
      'recurring task rule covers actual instances without changing their IDs',
      () async {
        await repo.addRecurringTask(
          const TaskDraft(
            title: 'Recurring alarm',
            scheduledDate: '2027-01-01',
            alarm: AlarmConfig(mode: 'planned', localMinute: 600),
          ),
          RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2027-01-01'),
        );
        await repo.ensureRecurringTasks('2027-01-01', '2027-01-03');
        final tasks = await repo.tasks();
        final plan = alarmPlan(
          rules: await repo.alarmRules(),
          tasks: tasks,
          events: [],
          sessions: [],
          now: now,
        );
        expect(plan.length, 3);
        expect(plan.map((p) => p['key']).toSet().length, 3);
        expect(tasks.map((t) => t.id).toSet().length, 3);
      },
    );

    test(
      'event start edits and explicit occurrence Off preserve the series rule',
      () async {
        final event = await repo.addEvent(
          EventDraft(
            title: 'Quiz',
            startsAt: now.add(const Duration(hours: 2)),
            endsAt: now.add(const Duration(hours: 3)),
            repeat: const EventRepeat(kind: EventRepeatKind.daily),
            alarm: const AlarmConfig(mode: 'relative', minutesBefore: 30),
          ),
        );
        var events = await repo.eventOccurrences('2027-01-01', '2027-01-02');
        await repo.saveAlarm(
          const AlarmConfig(),
          eventId: event.id,
          nominalDate: events.first.nominalDate!,
        );
        final plan = alarmPlan(
          rules: await repo.alarmRules(),
          tasks: [],
          events: events,
          sessions: [],
          now: now,
        );
        expect(plan.length, 1);
        expect(plan.single['body'], 'Quiz starts in 30 minutes.');
        expect(
          jsonEncode((await repo.alarmRules()).last.config.toJson()),
          isNot(contains('PendingIntent')),
        );
      },
    );
  });
}
