import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'selected weekdays stop at the semester end without materialized rows',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(database);
      try {
        await repo.addEvent(
          EventDraft(
            title: 'Database Systems',
            location: 'Room 204',
            startsAt: DateTime(2026, 10, 18, 9),
            endsAt: DateTime(2026, 10, 18, 10),
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekdays,
              weekdays: {DateTime.sunday, DateTime.tuesday},
              untilDate: '2027-01-21',
            ),
          ),
        );
        final october = await repo.eventOccurrences('2026-10-18', '2026-10-31');
        expect(october.map((event) => event.nominalDate), [
          '2026-10-18',
          '2026-10-20',
          '2026-10-25',
          '2026-10-27',
        ]);
        expect(october.every((event) => event.location == 'Room 204'), isTrue);
        final january = await repo.eventOccurrences('2027-01-17', '2027-01-27');
        expect(january.map((event) => event.nominalDate), [
          '2027-01-17',
          '2027-01-19',
        ]);
        final rows = await database
            .customSelect('SELECT COUNT(*) AS n FROM fixed_events')
            .getSingle();
        expect(rows.read<int>('n'), 1);
      } finally {
        await database.close();
      }
    },
  );

  test('a cancelled lecture and changed occurrence survive restart', () async {
    final root = await Directory.systemTemp.createTemp('event-exceptions-');
    final file = File('${root.path}${Platform.pathSeparator}test.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      final repo = LifeRepository(first);
      await repo.addEvent(
        EventDraft(
          title: 'Lecture',
          startsAt: DateTime(2026, 10, 18, 9),
          endsAt: DateTime(2026, 10, 18, 10),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {DateTime.sunday, DateTime.tuesday},
          ),
        ),
      );
      final upcoming = await repo.eventOccurrences('2026-10-18', '2026-10-27');
      await repo.setEventOccurrenceCancelled(upcoming[1], true);
      await repo.updateEventOccurrence(
        upcoming[2],
        EventDraft(
          title: 'Guest lecture',
          startsAt: DateTime(2026, 10, 25, 11),
          endsAt: DateTime(2026, 10, 25, 12),
        ),
      );
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      final reopened = LifeRepository(second);
      final projected = await reopened.eventOccurrences(
        '2026-10-18',
        '2026-10-27',
      );
      expect(projected[1].cancelled, isTrue);
      expect(projected[2].title, 'Guest lecture');
      expect(projected[3].title, 'Lecture');
      await reopened.setEventOccurrenceCancelled(projected[1], false);
      expect(
        (await reopened.eventOccurrences(
          '2026-10-20',
          '2026-10-20',
        )).single.cancelled,
        isFalse,
      );
      await second.close();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'future rule edit preserves earlier lectures and moves future overrides',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(database);
      try {
        await repo.addEvent(
          EventDraft(
            title: 'Old lecture',
            startsAt: DateTime(2026, 10, 18, 9),
            endsAt: DateTime(2026, 10, 18, 10),
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekdays,
              weekdays: {DateTime.sunday, DateTime.tuesday},
            ),
          ),
        );
        final before = await repo.eventOccurrences('2026-10-18', '2026-11-03');
        await repo.updateEventOccurrence(
          before[4],
          EventDraft(
            title: 'Special lecture',
            startsAt: DateTime(2026, 11, 1, 9),
            endsAt: DateTime(2026, 11, 1, 10),
          ),
        );
        await repo.splitEventSeries(
          before[2],
          '2026-10-25',
          EventDraft(
            title: 'New lecture',
            startsAt: DateTime(2026, 10, 25, 11),
            endsAt: DateTime(2026, 10, 25, 12),
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekdays,
              weekdays: {DateTime.tuesday},
            ),
          ),
        );
        final after = await repo.eventOccurrences('2026-10-18', '2026-11-03');
        expect(after.map((event) => event.title), [
          'Old lecture',
          'Old lecture',
          'New lecture',
          'Special lecture',
          'New lecture',
        ]);
        expect(after[0].startsAt.toLocal().hour, 9);
        expect(after[2].startsAt.toLocal().hour, 11);
      } finally {
        await database.close();
      }
    },
  );

  test(
    'calendar content preference persists independently of SQLite',
    () async {
      final root = await Directory.systemTemp.createTemp('calendar-filter-');
      try {
        final store = CalendarPreferenceStore(
          File('${root.path}/calendar.json'),
        );
        expect(await store.load(), CalendarContent.both);
        await store.save(CalendarContent.eventsOnly);
        expect(
          await CalendarPreferenceStore(store.file).load(),
          CalendarContent.eventsOnly,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('v15 event migration preserves existing event IDs and notes', () async {
    final root = await Directory.systemTemp.createTemp('event-v15-');
    final file = File('${root.path}${Platform.pathSeparator}test.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      final original = await LifeRepository(first).addEvent(
        EventDraft(
          title: 'Existing event',
          notes: 'Keep these notes',
          startsAt: DateTime(2026, 10, 18, 9),
          endsAt: DateTime(2026, 10, 18, 10),
        ),
      );
      await first.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE event_occurrence_changes');
      raw.execute('ALTER TABLE fixed_events DROP COLUMN recurrence_until');
      raw.execute('PRAGMA user_version=15');
      raw.close();
      final migrated = AppDatabase(NativeDatabase(file));
      final repo = LifeRepository(migrated);
      final event = (await repo.events()).single;
      expect(event.id, original.id);
      expect(event.notes, 'Keep these notes');
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        AppDatabase.currentSchemaVersion,
      );
      expect(
        await migrated.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await migrated.close();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('ending a series keeps past dates and removes future dates', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(database);
    try {
      await repo.addEvent(
        EventDraft(
          title: 'Course',
          startsAt: DateTime(2026, 10, 18, 9),
          endsAt: DateTime(2026, 10, 18, 10),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {DateTime.sunday, DateTime.tuesday},
          ),
        ),
      );
      final dates = await repo.eventOccurrences('2026-10-18', '2026-10-27');
      await repo.endEventSeries(dates[2]);
      final remaining = await repo.eventOccurrences('2026-10-18', '2026-10-27');
      expect(remaining.map((event) => event.nominalDate), [
        '2026-10-18',
        '2026-10-20',
      ]);
    } finally {
      await database.close();
    }
  });
}
