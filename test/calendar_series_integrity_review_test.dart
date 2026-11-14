import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';

void main() {
  late AppDatabase db;
  late LifeRepository repo;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    await repo.events();
  });
  tearDown(() => db.close());

  Future<void> capture() => db.customStatement(
    '''UPDATE sync_capture_context
    SET capture_enabled=1,workspace_id='review',account_id='synthetic',device_id='review' WHERE id=1''',
  );
  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table ORDER BY 1,2').get())
          .map((r) => Map<String, Object?>.from(r.data))
          .toList();
  Future<String> snapshot() async => jsonEncode([
    await rows('fixed_events'),
    await rows('event_occurrence_changes'),
    await rows('alarm_rules'),
    await rows('sync_journal'),
  ]);
  Future<FixedEvent> weekly() => repo.addEvent(
    EventDraft(
      title: 'Synthetic series',
      startsAt: DateTime(2026, 11, 16, 10),
      endsAt: DateTime(2026, 11, 16, 11),
      repeat: const EventRepeat(kind: EventRepeatKind.weekly),
    ),
  );
  EventDraft shifted(FixedEvent e, int days) => EventDraft(
    title: e.title,
    startsAt: e.startsAt.add(Duration(days: days)),
    endsAt: e.endsAt.add(Duration(days: days)),
    repeat: e.repeat,
  );

  test('ordinal inverse covers intervals, partial weeks, month ends and leap years', () {
    for (final kind in RecurrenceKind.values.where(
      (k) => k != RecurrenceKind.afterCompletion,
    )) {
      for (final interval in [1, 2, 3]) {
        for (final start in ['2024-01-31', '2024-02-29']) {
          final day = DateTime.parse(start).weekday;
          final rule = RecurrenceRule(
            kind: kind,
            startDate: start,
            interval: interval,
            weekdays: kind == RecurrenceKind.weekdays ? {1, day, 7} : {},
            endDate: '2032-12-31',
          );
          final slots = rule.between(start, '2032-12-31');
          expect(slots.map((s) => s.nominalDate).toSet().length, slots.length);
          for (final slot in slots) {
            expect(
              rule.slotDateAtOrdinal(slot.ordinal),
              slot.nominalDate,
              reason: '$kind $interval $start ordinal ${slot.ordinal}',
            );
          }
        }
      }
    }
  });

  for (final kind in [EventRepeatKind.monthly, EventRepeatKind.yearly]) {
    test(
      'finite $kind move cannot silently drop an unmodified final slot',
      () async {
        final monthly = kind == EventRepeatKind.monthly;
        final start = monthly
            ? DateTime(2026, 1, 31, 10)
            : DateTime(2024, 2, 29, 10);
        final e = await repo.addEvent(
          EventDraft(
            title: 'Finite',
            startsAt: start,
            endsAt: start.add(const Duration(hours: 1)),
            repeat: EventRepeat(
              kind: kind,
              untilDate: monthly ? '2026-04-30' : '2025-02-28',
            ),
          ),
        );
        await capture();
        final draft = EventDraft(
          title: e.title,
          startsAt: start.subtract(const Duration(days: 1)),
          endsAt: start
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 1)),
          repeat: e.repeat!.copyWith(
            untilDate: monthly ? '2026-04-29' : '2025-02-27',
          ),
        );
        final before = await snapshot();
        expect(await repo.calendarSeriesMoveProblem(e, draft), isNotNull);
        await expectLater(repo.moveCalendarSeries(e, draft), throwsStateError);
        expect(await snapshot(), before);
      },
    );
  }

  for (final kind in [EventRepeatKind.monthly, EventRepeatKind.yearly]) {
    test(
      '$kind clamped exception and custom alarm map reversibly by ordinal',
      () async {
        final monthly = kind == EventRepeatKind.monthly;
        final start = monthly
            ? DateTime(2024, 1, 31, 10)
            : DateTime(2024, 2, 29, 10);
        final target = monthly
            ? DateTime(2024, 2, 1, 10)
            : DateTime(2024, 3, 1, 10);
        final nominal = monthly ? '2024-02-29' : '2025-02-28';
        final nextNominal = monthly ? '2024-03-01' : '2025-03-01';
        final day = DateTime.parse(nominal);
        final e = await repo.addEvent(
          EventDraft(
            title: 'Clamp',
            startsAt: start,
            endsAt: start.add(const Duration(hours: 1)),
            repeat: EventRepeat(kind: kind),
          ),
        );
        final occurrence = (await repo.eventOccurrences(
          nominal,
          nominal,
        )).single;
        await repo.updateEventOccurrence(
          occurrence,
          EventDraft(
            title: 'Keep title',
            startsAt: DateTime(day.year, day.month, day.day, 14),
            endsAt: DateTime(day.year, day.month, day.day, 16),
          ),
        );
        await repo.saveAlarm(
          AlarmConfig(
            mode: 'custom',
            at: DateTime(day.year, day.month, day.day, 13).toUtc(),
          ),
          eventId: e.id,
          nominalDate: nominal,
        );
        final original = await rows('event_occurrence_changes');
        final originalAlarm = await rows('alarm_rules');
        await repo.moveCalendarSeries(
          e,
          EventDraft(
            title: e.title,
            startsAt: target,
            endsAt: target.add(const Duration(hours: 1)),
            repeat: e.repeat,
          ),
        );
        final result = (await repo.eventOccurrences(
          nextNominal,
          nextNominal,
        )).single;
        expect(result.title, 'Keep title');
        expect(result.startsAt.toLocal().hour, 14);
        expect(
          result.endsAt.difference(result.startsAt),
          const Duration(hours: 2),
        );
        expect((await repo.alarmRules()).single.nominalDate, nextNominal);
        expect(
          localDate((await repo.alarmRules()).single.config.at!.toLocal()),
          nextNominal,
        );
        await repo.moveCalendarSeries(
          (await repo.events()).single,
          EventDraft(
            title: e.title,
            startsAt: e.startsAt,
            endsAt: e.endsAt,
            repeat: e.repeat,
          ),
        );
        final reverted = await rows('event_occurrence_changes');
        final revertedAlarm = await rows('alarm_rules');
        for (final table in [
          original,
          originalAlarm,
          reverted,
          revertedAlarm,
        ]) {
          for (final row in table) {
            row.remove('updated_at');
          }
        }
        expect(reverted, original);
        expect(revertedAlarm, originalAlarm);
      },
    );
  }

  test('series migration preserves archived and deleted alarm state', () async {
    final e = await weekly();
    await repo.saveAlarm(
      AlarmConfig(mode: 'custom', at: DateTime.utc(2026, 11, 23, 6)),
      eventId: e.id,
      nominalDate: '2026-11-23',
    );
    await db.customStatement(
      "UPDATE alarm_rules SET deleted_at='2026-11-01T00:00:00.000Z',archived_at='2026-11-02T00:00:00.000Z'",
    );
    await repo.moveCalendarSeries(e, shifted(e, 2));
    final alarm = (await rows('alarm_rules')).single;
    expect(alarm['nominal_date'], '2026-11-25');
    expect(alarm['deleted_at'], '2026-11-01T00:00:00.000Z');
    expect(alarm['archived_at'], '2026-11-02T00:00:00.000Z');
    expect(await repo.alarmRules(), isEmpty);
  });

  test(
    'overlapping keys migrate cancellation override and alarms through history',
    () async {
      final e = await weekly();
      final slots = await repo.eventOccurrences('2026-11-16', '2026-11-30');
      await repo.setEventOccurrenceCancelled(slots[1], true);
      await repo.updateEventOccurrence(
        slots[2],
        EventDraft(
          title: 'Custom',
          notes: 'Keep',
          startsAt: DateTime(2026, 11, 30, 14),
          endsAt: DateTime(2026, 11, 30, 16),
        ),
      );
      await repo.saveAlarm(
        AlarmConfig(mode: 'custom', at: DateTime.utc(2026, 11, 30, 10)),
        eventId: e.id,
        nominalDate: '2026-11-30',
      );
      final originalChanges = await rows('event_occurrence_changes');
      final originalAlarms = await rows('alarm_rules');
      final app = AppController(repo);
      final interaction = CalendarInteractionController();
      addTearDown(interaction.dispose);
      addTearDown(app.dispose);
      await app.refresh();
      await capture();
      interaction.startMove(
        item: CalendarItem(
          id: e.id,
          title: e.title,
          kind: CalendarItemKind.event,
          event: slots.first,
          startsAt: slots.first.startsAt.toLocal(),
          endsAt: slots.first.endsAt.toLocal(),
        ),
        dayDate: DateTime(2026, 11, 16),
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600,
      );
      interaction.updatePointer(
        const Offset(200, 600),
        DateTime(2026, 11, 23),
        600,
      );
      await interaction.commit(
        app,
        scope: CalendarRecurringMoveScope.entireSeries,
      );
      final changes = await rows('event_occurrence_changes');
      expect(changes.map((r) => r['nominal_date']), [
        '2026-11-30',
        '2026-12-07',
      ]);
      expect(changes.first['cancelled'], 1);
      final payload = jsonDecode(changes.last['payload_json'] as String) as Map;
      expect(
        DateTime.parse(payload['startsAt'] as String).toLocal(),
        DateTime(2026, 12, 7, 14),
      );
      final journal = await rows('sync_journal');
      expect(
        journal.length,
        7,
      ); // master + two exception delete/insert + alarm delete/insert
      expect(journal.map((r) => r['mutation_group_id']).toSet().length, 1);
      expect(journal.where((r) => r['after_json'] == null).length, 3);
      final groups = await rows('sync_mutation_groups');
      expect(groups.single['complete'], 1);
      await interaction.undo(app);
      List<Map<String, Object?>> withoutRevision(
        List<Map<String, Object?>> value,
      ) => value.map((r) => {...r}..remove('updated_at')).toList();
      expect(
        withoutRevision(await rows('event_occurrence_changes')),
        withoutRevision(originalChanges),
      );
      expect(
        withoutRevision(await rows('alarm_rules')),
        withoutRevision(originalAlarms),
      );
      await interaction.redo(app);
      expect(
        withoutRevision(await rows('event_occurrence_changes')),
        withoutRevision(changes),
      );
      expect(interaction.undoCount, 1);
    },
  );

  test(
    'moving from a timed override translates the master by gesture delta',
    () async {
      await weekly();
      final second = (await repo.eventOccurrences(
        '2026-11-23',
        '2026-11-23',
      )).single;
      await repo.updateEventOccurrence(
        second,
        EventDraft(
          title: 'Afternoon override',
          startsAt: DateTime(2026, 11, 23, 14),
          endsAt: DateTime(2026, 11, 23, 16),
        ),
      );
      final edited = (await repo.eventOccurrences(
        '2026-11-23',
        '2026-11-23',
      )).single;
      final app = AppController(repo);
      final interaction = CalendarInteractionController();
      addTearDown(interaction.dispose);
      addTearDown(app.dispose);
      await app.refresh();
      interaction.startMove(
        item: CalendarItem(
          id: edited.id,
          title: edited.title,
          kind: CalendarItemKind.event,
          event: edited,
          startsAt: edited.startsAt.toLocal(),
          endsAt: edited.endsAt.toLocal(),
        ),
        dayDate: DateTime(2026, 11, 23),
        pointerLocal: const Offset(100, 840),
        pointerTimelineY: 840,
      );
      interaction.updatePointer(
        const Offset(200, 840),
        DateTime(2026, 11, 24),
        840,
      );
      await interaction.commit(
        app,
        scope: CalendarRecurringMoveScope.entireSeries,
      );
      final master = (await repo.events()).single;
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 17, 10));
      expect(master.endsAt.toLocal(), DateTime(2026, 11, 17, 11));
      final migrated = (await repo.eventOccurrences(
        '2026-11-24',
        '2026-11-24',
      )).single;
      expect(migrated.startsAt.toLocal(), DateTime(2026, 11, 24, 14));
      expect(migrated.endsAt.toLocal(), DateTime(2026, 11, 24, 16));
    },
  );

  test(
    'failure after master and exception writes rolls back rows and journal',
    () async {
      final e = await weekly();
      final occurrence = (await repo.eventOccurrences(
        '2026-11-23',
        '2026-11-23',
      )).single;
      await repo.setEventOccurrenceCancelled(occurrence, true);
      await repo.saveAlarm(
        const AlarmConfig(mode: 'relative', minutesBefore: 10),
        eventId: e.id,
        nominalDate: '2026-11-23',
      );
      await capture();
      await db.customStatement(
        '''CREATE TRIGGER review_abort BEFORE INSERT ON alarm_rules
      BEGIN SELECT RAISE(ABORT,'review forced rollback'); END''',
      );
      final before = await snapshot();
      await expectLater(
        repo.moveCalendarSeries(e, shifted(e, 2)),
        throwsA(
          predicate(
            (error) => error.toString().contains('review forced rollback'),
          ),
        ),
      );
      expect(await snapshot(), before);
      expect(await rows('sync_mutation_groups'), isEmpty);
    },
  );

  test(
    'orphaned exception, truncated alarm and stale master reject atomically',
    () async {
      final e = await weekly();
      await db.customStatement(
        '''INSERT INTO event_occurrence_changes
      (event_id,nominal_date,cancelled,created_at,updated_at) VALUES(?,'2026-11-24',1,'a','a')''',
        [e.id],
      );
      await capture();
      final before = await snapshot();
      await expectLater(
        repo.moveCalendarSeries(e, shifted(e, 2)),
        throwsStateError,
      );
      expect(await snapshot(), before);
      await db.customStatement('DELETE FROM event_occurrence_changes');
      await repo.saveAlarm(
        const AlarmConfig(mode: 'relative'),
        eventId: e.id,
        nominalDate: '2026-11-30',
      );
      final draft = shifted(e, 2);
      await expectLater(
        repo.moveCalendarSeries(
          e,
          EventDraft(
            title: draft.title,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekly,
              untilDate: '2026-11-25',
            ),
          ),
        ),
        throwsStateError,
      );
      await repo.updateEvent(
        e,
        EventDraft(
          title: 'Other edit',
          startsAt: e.startsAt,
          endsAt: e.endsAt,
          repeat: e.repeat,
        ),
      );
      final staleBefore = await snapshot();
      await expectLater(repo.moveCalendarSeries(e, draft), throwsStateError);
      expect(await snapshot(), staleBefore);
    },
  );
}
