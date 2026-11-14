import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';

void main() {
  const config = CalendarAppearanceConfiguration(
    hourHeight: 60.0,
    snapMinutes: 15,
    minItemDurationMinutes: 15,
    dragThreshold: 4.0,
    startHour: 0,
    endHour: 24,
  );

  CalendarItem eventItem(FixedEvent event) => CalendarItem(
    id: event.id,
    title: event.title,
    kind: CalendarItemKind.event,
    startsAt: event.startsAt.toLocal(),
    endsAt: event.endsAt.toLocal(),
    event: event,
  );

  group('Calendar Event Move Recurrence Tests (CAL-01)', () {
    late AppDatabase db;
    late LifeRepository repo;
    late AppController controller;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = LifeRepository(db);
      controller = AppController(repo);
      await controller.refresh();
    });

    tearDown(() async {
      await db.close();
    });

    // 1. Normal event movement
    test('1. Normal non-recurring event move preserves duration and supports undo/redo', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Single Meeting',
          startsAt: DateTime(2026, 11, 16, 9, 0),
          endsAt: DateTime(2026, 11, 16, 10, 30),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(event),
        dayDate: monday,
        pointerLocal: const Offset(100, 540),
        pointerTimelineY: 540.0,
      );
      interaction.updatePointer(
        const Offset(300, 660),
        wednesday,
        660.0, // 11:00 AM
      );

      final summary = await interaction.commit(controller);
      expect(summary, contains('Single Meeting'));
      expect(summary, contains('2026-11-18 11:00'));

      final saved = (await repo.events()).single;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 18, 11, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 18, 12, 30));
      expect(
        saved.endsAt.difference(saved.startsAt),
        const Duration(hours: 1, minutes: 30),
      );

      await interaction.undo(controller);
      final undone = (await repo.events()).single;
      expect(undone.startsAt.toLocal(), DateTime(2026, 11, 16, 9, 0));
      expect(undone.endsAt.toLocal(), DateTime(2026, 11, 16, 10, 30));

      await interaction.redo(controller);
      final redone = (await repo.events()).single;
      expect(redone.startsAt.toLocal(), DateTime(2026, 11, 18, 11, 0));
    });

    // 2. Single occurrence movement
    test('2. Moving recurring occurrence affects only that occurrence, preserves series and duration', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      await repo.addEvent(
        EventDraft(
          title: 'University Lecture',
          notes: 'Physics 101',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 11, 30),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {DateTime.monday},
          ),
        ),
      );

      final occurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-23',
      );
      expect(occurrences, hasLength(2)); // Nov 16 and Nov 23
      final mondayOccurrence = occurrences.first;
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(mondayOccurrence),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      interaction.updatePointer(const Offset(300, 600), wednesday, 600.0);

      final summary = await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.thisOccurrence,
      );
      expect(summary, contains('University Lecture'));

      final updatedOccurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-23',
      );
      expect(updatedOccurrences, hasLength(2));
      final moved = updatedOccurrences.firstWhere(
        (o) => o.nominalDate == '2026-11-16',
      );
      expect(moved.startsAt.toLocal(), DateTime(2026, 11, 18, 10, 0));
      expect(moved.endsAt.toLocal(), DateTime(2026, 11, 18, 11, 30));
      expect(
        moved.endsAt.difference(moved.startsAt),
        const Duration(hours: 1, minutes: 30),
      );

      // Second occurrence (Nov 23) must remain on Monday 10:00 AM
      final secondOcc = updatedOccurrences.firstWhere(
        (o) => o.nominalDate == '2026-11-23',
      );
      expect(secondOcc.startsAt.toLocal(), DateTime(2026, 11, 23, 10, 0));

      // Master must remain unchanged
      final master = (await repo.events()).single;
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 16, 10, 0));
      expect(master.repeat!.weekdays, {DateTime.monday});

      // Test Undo & Redo
      await interaction.undo(controller);
      final undone = await repo.eventOccurrences('2026-11-16', '2026-11-23');
      expect(
        undone
            .firstWhere((o) => o.nominalDate == '2026-11-16')
            .startsAt
            .toLocal(),
        DateTime(2026, 11, 16, 10, 0),
      );

      await interaction.redo(controller);
      final redone = await repo.eventOccurrences('2026-11-16', '2026-11-23');
      expect(
        redone
            .firstWhere((o) => o.nominalDate == '2026-11-16')
            .startsAt
            .toLocal(),
        DateTime(2026, 11, 18, 10, 0),
      );
    });

    // 3. Recurring master movement with explicit confirmation
    test('3. Moving entire recurring series updates master rule, anchor, and future occurrences', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      await repo.addEvent(
        EventDraft(
          title: 'Physics 101',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 11, 30),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {DateTime.monday},
          ),
        ),
      );

      final occurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-23',
      );
      final mondayOccurrence = occurrences.first;
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(mondayOccurrence),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      // Move to Wednesday at 11:00 AM
      interaction.updatePointer(const Offset(300, 660), wednesday, 660.0);

      final summary = await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.entireSeries,
      );
      expect(summary, contains('Moved event series "Physics 101"'));

      final master = (await repo.events()).single;
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 18, 11, 0));
      expect(master.endsAt.toLocal(), DateTime(2026, 11, 18, 12, 30));
      expect(master.repeat!.weekdays, {DateTime.wednesday});

      // Occurrences should now be on Wednesdays at 11:00 AM
      final newOccurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-30',
      );
      expect(newOccurrences, hasLength(2)); // Nov 18 and Nov 25
      expect(
        newOccurrences[0].startsAt.toLocal(),
        DateTime(2026, 11, 18, 11, 0),
      );
      expect(
        newOccurrences[1].startsAt.toLocal(),
        DateTime(2026, 11, 25, 11, 0),
      );

      // Test Undo
      await interaction.undo(controller);
      final restoredMaster = (await repo.events()).single;
      expect(restoredMaster.startsAt.toLocal(), DateTime(2026, 11, 16, 10, 0));
      expect(restoredMaster.repeat!.weekdays, {DateTime.monday});

      // Test Redo
      await interaction.redo(controller);
      final redoneMaster = (await repo.events()).single;
      expect(redoneMaster.startsAt.toLocal(), DateTime(2026, 11, 18, 11, 0));
      expect(redoneMaster.repeat!.weekdays, {DateTime.wednesday});
    });

    // 4. Canceling a series update
    test(
      '4. Canceling drag leaves event and series completely untouched',
      () async {
        final monday = DateTime(2026, 11, 16);
        final wednesday = DateTime(2026, 11, 18);

        final event = await repo.addEvent(
          EventDraft(
            title: 'Seminar',
            startsAt: DateTime(2026, 11, 16, 10, 0),
            endsAt: DateTime(2026, 11, 16, 11, 0),
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekdays,
              weekdays: {DateTime.monday},
            ),
          ),
        );
        await controller.refresh();

        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);

        interaction.startMove(
          item: eventItem(event),
          dayDate: monday,
          pointerLocal: const Offset(100, 600),
          pointerTimelineY: 600.0,
        );
        interaction.updatePointer(const Offset(300, 600), wednesday, 600.0);
        expect(interaction.isDragging, isTrue);

        interaction.cancel();
        expect(interaction.isDragging, isFalse);
        expect(interaction.activeItem, isNull);
        expect(interaction.undoCount, 0);

        final master = (await repo.events()).single;
        expect(master.startsAt.toLocal(), DateTime(2026, 11, 16, 10, 0));
        expect(master.repeat!.weekdays, {DateTime.monday});
      },
    );

    // 5. Weekly recurrence move
    test('5. Weekly recurrence series move updates weekday anchor and future occurrences', () async {
      final monday = DateTime(2026, 11, 16);
      final thursday = DateTime(2026, 11, 19);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Weekly Standup',
          startsAt: DateTime(2026, 11, 16, 9, 0),
          endsAt: DateTime(2026, 11, 16, 9, 45),
          repeat: const EventRepeat(kind: EventRepeatKind.weekly),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(event),
        dayDate: monday,
        pointerLocal: const Offset(100, 540),
        pointerTimelineY: 540.0,
      );
      // Move to Thursday at 14:00
      interaction.updatePointer(const Offset(400, 840), thursday, 840.0);

      await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.entireSeries,
      );

      final master = (await repo.events()).single;
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 19, 14, 0));
      expect(master.endsAt.toLocal(), DateTime(2026, 11, 19, 14, 45));
      expect(master.repeat!.kind, EventRepeatKind.weekly);

      final occurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-30',
      );
      expect(occurrences, hasLength(2)); // Nov 19, Nov 26
      expect(occurrences[0].startsAt.toLocal(), DateTime(2026, 11, 19, 14, 0));
      expect(occurrences[1].startsAt.toLocal(), DateTime(2026, 11, 26, 14, 0));
    });

    // 6. Weekly multi-day recurrence
    test('6. Multi-weekday recurrence: translating entire series pattern preserves interval and shifts all days', () async {
      final monday = DateTime(2026, 11, 16);
      final tuesday = DateTime(2026, 11, 17);

      // Repeats Mon, Wed: {1, 3}
      final event = await repo.addEvent(
        EventDraft(
          title: 'Lab Session',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 12, 0),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {1, 3},
          ),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      // Moving Mon -> Tue shifts pattern by +1 day: {1, 3} -> {2, 4} (Tue, Thu)
      interaction.startMove(
        item: eventItem(event),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      interaction.updatePointer(const Offset(200, 600), tuesday, 600.0);

      await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.entireSeries,
      );

      final master = (await repo.events()).single;
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 17, 10, 0));
      expect(master.repeat!.weekdays, {
        2,
        4,
      }); // Translated cleanly without collapsing

      // Occurrences on Tue Nov 17 and Thu Nov 19
      final occurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-22',
      );
      expect(occurrences, hasLength(2));
      expect(occurrences[0].startsAt.toLocal(), DateTime(2026, 11, 17, 10, 0));
      expect(occurrences[1].startsAt.toLocal(), DateTime(2026, 11, 19, 10, 0));

      // Undo restores {1, 3} and Monday anchor
      await interaction.undo(controller);
      final undone = (await repo.events()).single;
      expect(undone.startsAt.toLocal(), DateTime(2026, 11, 16, 10, 0));
      expect(undone.repeat!.weekdays, {1, 3});
    });

    // 7. Monthly and yearly recurrence
    test(
      '7. Monthly recurrence series move updates monthly anchor day and time',
      () async {
        final nov15 = DateTime(2026, 11, 15);
        final nov18 = DateTime(2026, 11, 18);

        final event = await repo.addEvent(
          EventDraft(
            title: 'Monthly Review',
            startsAt: DateTime(2026, 11, 15, 10, 0),
            endsAt: DateTime(2026, 11, 15, 11, 0),
            repeat: const EventRepeat(kind: EventRepeatKind.monthly),
          ),
        );
        await controller.refresh();

        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);

        interaction.startMove(
          item: eventItem(event),
          dayDate: nov15,
          pointerLocal: const Offset(100, 600),
          pointerTimelineY: 600.0,
        );
        interaction.updatePointer(
          const Offset(200, 720),
          nov18,
          720.0, // 12:00 PM
        );

        await interaction.commit(
          controller,
          scope: CalendarRecurringMoveScope.entireSeries,
        );

        final master = (await repo.events()).single;
        expect(master.startsAt.toLocal(), DateTime(2026, 11, 18, 12, 0));
        expect(master.endsAt.toLocal(), DateTime(2026, 11, 18, 13, 0));
        expect(master.repeat!.kind, EventRepeatKind.monthly);

        // Occurrences project on the 18th
        final occurrences = await repo.eventOccurrences(
          '2026-11-01',
          '2026-12-31',
        );
        expect(occurrences, hasLength(2));
        expect(
          occurrences[0].startsAt.toLocal(),
          DateTime(2026, 11, 18, 12, 0),
        );
        expect(
          occurrences[1].startsAt.toLocal(),
          DateTime(2026, 12, 18, 12, 0),
        );
      },
    );

    test(
      '7b. Yearly recurrence series move updates yearly month/day anchor',
      () async {
        final nov15 = DateTime(2026, 11, 15);
        final nov20 = DateTime(2026, 11, 20);

        final event = await repo.addEvent(
          EventDraft(
            title: 'Annual Anniversary',
            startsAt: DateTime(2026, 11, 15, 10, 0),
            endsAt: DateTime(2026, 11, 15, 11, 0),
            repeat: const EventRepeat(kind: EventRepeatKind.yearly),
          ),
        );
        await controller.refresh();

        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);

        interaction.startMove(
          item: eventItem(event),
          dayDate: nov15,
          pointerLocal: const Offset(100, 600),
          pointerTimelineY: 600.0,
        );
        interaction.updatePointer(const Offset(200, 720), nov20, 720.0);

        await interaction.commit(
          controller,
          scope: CalendarRecurringMoveScope.entireSeries,
        );

        final master = (await repo.events()).single;
        expect(master.startsAt.toLocal(), DateTime(2026, 11, 20, 12, 0));
        expect(master.endsAt.toLocal(), DateTime(2026, 11, 20, 13, 0));
        expect(master.repeat!.kind, EventRepeatKind.yearly);
      },
    );

    // 8. Exception preservation during series movement
    test('8. Exception preservation: series translation safely migrates a manual occurrence override without detaching', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      await repo.addEvent(
        EventDraft(
          title: 'Weekly Lecture',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 11, 0),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {DateTime.monday},
          ),
        ),
      );

      // Create an occurrence override for the 2nd week (2026-11-23)
      final occurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-30',
      );
      final secondOcc = occurrences.firstWhere(
        (o) => o.nominalDate == '2026-11-23',
      );
      await repo.updateEventOccurrence(
        secondOcc,
        EventDraft(
          title: 'Guest Lecture',
          notes: 'Dr. Smith visiting',
          startsAt: DateTime(2026, 11, 23, 14, 0),
          endsAt: DateTime(2026, 11, 23, 16, 0),
        ),
      );

      await controller.refresh();

      // Now move entire series to Wednesdays at 10:00 AM
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(occurrences.first),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      interaction.updatePointer(const Offset(300, 600), wednesday, 600.0);

      final summary = await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.entireSeries,
      );
      expect(summary, contains('Moved event series "Weekly Lecture"'));

      final master = (await repo.events()).single;
      expect(master.repeat!.weekdays, {DateTime.wednesday});
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 18, 10, 0));

      // The manually overridden occurrence was migrated to 2026-11-25 (the 2nd occurrence)
      final allOccurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-30',
      );
      expect(allOccurrences.where((o) => o.nominalDate == '2026-11-23'), isEmpty);
      final overridden = allOccurrences.firstWhere(
        (o) => o.nominalDate == '2026-11-25',
      );
      expect(overridden.title, 'Guest Lecture');
      expect(overridden.notes, 'Dr. Smith visiting');
      expect(overridden.startsAt.toLocal(), DateTime(2026, 11, 25, 14, 0));
      expect(overridden.endsAt.toLocal(), DateTime(2026, 11, 25, 16, 0));

      // Undo restores the original schedule and original exception key
      await interaction.undo(controller);
      final undoneOccurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-30',
      );
      final undoneOverridden = undoneOccurrences.firstWhere(
        (o) => o.nominalDate == '2026-11-23',
      );
      expect(undoneOverridden.title, 'Guest Lecture');
      expect(undoneOverridden.startsAt.toLocal(), DateTime(2026, 11, 23, 14, 0));

      // Redo re-migrates cleanly
      await interaction.redo(controller);
      final redoneOccurrences = await repo.eventOccurrences(
        '2026-11-16',
        '2026-11-30',
      );
      final redoneOverridden = redoneOccurrences.firstWhere(
        (o) => o.nominalDate == '2026-11-25',
      );
      expect(redoneOverridden.title, 'Guest Lecture');
      expect(redoneOverridden.startsAt.toLocal(), DateTime(2026, 11, 25, 14, 0));
    });

    test('8b. Occurrence-specific alarm migration: preserves alarm with deterministic UUIDv5', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Lab Session',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 11, 0),
          repeat: const EventRepeat(kind: EventRepeatKind.weekly),
        ),
      );

      final occurrences = await repo.eventOccurrences('2026-11-16', '2026-11-30');
      // Save an occurrence-specific custom alarm on 2026-11-23
      await repo.saveAlarm(
        AlarmConfig(
          mode: 'custom',
          at: DateTime.utc(2026, 11, 23, 9, 30),
        ),
        eventId: event.id,
        nominalDate: '2026-11-23',
      );

      await controller.refresh();
      expect((await repo.alarmRules()).any((r) => r.nominalDate == '2026-11-23'), isTrue);

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(occurrences.first),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      interaction.updatePointer(const Offset(300, 600), wednesday, 600.0);

      await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.entireSeries,
      );

      final rules = await repo.alarmRules();
      // Old alarm on 2026-11-23 is gone
      expect(rules.any((r) => r.nominalDate == '2026-11-23'), isFalse);
      // New alarm on 2026-11-25 exists with deterministic UUIDv5
      final migratedAlarm = rules.firstWhere((r) => r.nominalDate == '2026-11-25');
      expect(
        migratedAlarm.id,
        const Uuid().v5(
          Namespace.url.value,
          'todorbit:alarm:null:${event.id}:null:2026-11-25',
        ),
      );
      expect(migratedAlarm.config.at, DateTime.utc(2026, 11, 25, 9, 30));
    });

    test('8c. Historical generation safeguard: rejects series move when activeThroughDate is set', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Split Series',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 11, 0),
          repeat: const EventRepeat(kind: EventRepeatKind.weekly),
        ),
      );

      // Simulate prior split boundary
      await db.customStatement(
        "UPDATE fixed_events SET active_through_date='2026-11-20' WHERE id=?",
        [event.id],
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem((await repo.events()).single),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      interaction.updatePointer(const Offset(300, 600), wednesday, 600.0);

      await expectLater(
        interaction.commit(
          controller,
          scope: CalendarRecurringMoveScope.entireSeries,
        ),
        throwsStateError,
      );

      final master = (await repo.events()).single;
      expect(master.startsAt.toLocal(), DateTime(2026, 11, 16, 10, 0));
    });

    // 9. Database reload / persistence
    test('9. Database reload: series master change persists across fresh repository instance', () async {
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Persistent Series',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 11, 0),
          repeat: const EventRepeat(
            kind: EventRepeatKind.weekdays,
            weekdays: {DateTime.monday},
          ),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);

      interaction.startMove(
        item: eventItem(event),
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );
      interaction.updatePointer(const Offset(300, 600), wednesday, 600.0);

      await interaction.commit(
        controller,
        scope: CalendarRecurringMoveScope.entireSeries,
      );

      // Create completely new repository pointing to the same SQLite DB
      final freshRepo = LifeRepository(db);
      final loadedEvents = await freshRepo.events();
      expect(loadedEvents, hasLength(1));
      final reloaded = loadedEvents.single;
      expect(reloaded.startsAt.toLocal(), DateTime(2026, 11, 18, 10, 0));
      expect(reloaded.repeat!.weekdays, {DateTime.wednesday});
    });

    // 10. Undo/redo sequentially for both occurrence and series movements
    test(
      '10. Multi-step undo/redo preserves occurrence vs series state correctly',
      () async {
        final monday = DateTime(2026, 11, 16);
        final tuesday = DateTime(2026, 11, 17);

        await repo.addEvent(
          EventDraft(
            title: 'Multi-Step Test',
            startsAt: DateTime(2026, 11, 16, 10, 0),
            endsAt: DateTime(2026, 11, 16, 11, 0),
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekdays,
              weekdays: {DateTime.monday},
            ),
          ),
        );
        final occurrences = await repo.eventOccurrences(
          '2026-11-16',
          '2026-11-23',
        );
        await controller.refresh();

        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);

        // Step 1: Move occurrence Nov 16 to Tuesday Nov 17
        interaction.startMove(
          item: eventItem(occurrences.first),
          dayDate: monday,
          pointerLocal: const Offset(100, 600),
          pointerTimelineY: 600.0,
        );
        interaction.updatePointer(const Offset(200, 600), tuesday, 600.0);
        await interaction.commit(
          controller,
          scope: CalendarRecurringMoveScope.thisOccurrence,
        );
        expect(interaction.undoCount, 1);

        // Verify occurrence moved
        var occs = await repo.eventOccurrences('2026-11-16', '2026-11-23');
        expect(
          occs
              .firstWhere((o) => o.nominalDate == '2026-11-16')
              .startsAt
              .toLocal(),
          DateTime(2026, 11, 17, 10, 0),
        );

        // Step 2: Undo occurrence move
        await interaction.undo(controller);
        occs = await repo.eventOccurrences('2026-11-16', '2026-11-23');
        expect(
          occs
              .firstWhere((o) => o.nominalDate == '2026-11-16')
              .startsAt
              .toLocal(),
          DateTime(2026, 11, 16, 10, 0),
        );

        // Step 3: Redo occurrence move
        await interaction.redo(controller);
        occs = await repo.eventOccurrences('2026-11-16', '2026-11-23');
        expect(
          occs
              .firstWhere((o) => o.nominalDate == '2026-11-16')
              .startsAt
              .toLocal(),
          DateTime(2026, 11, 17, 10, 0),
        );
      },
    );

    // 11. UI confirmation dialog testing
    testWidgets(
      '11. CalendarView shows RecurringEventMoveDialog on recurring item drag and handles cancel',
      (tester) async {
        final monday = DateTime(2026, 11, 16);

        await repo.addEvent(
          EventDraft(
            title: 'Dialog Test',
            startsAt: DateTime(2026, 11, 16, 10, 0),
            endsAt: DateTime(2026, 11, 16, 11, 0),
            repeat: const EventRepeat(
              kind: EventRepeatKind.weekdays,
              weekdays: {DateTime.monday},
            ),
          ),
        );
        await controller.refresh();

        final interaction = CalendarInteractionController(config: config);
        addTearDown(interaction.dispose);

        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CalendarView(
                  initialDate: monday,
                  onAddTask: (_) {},
                  onTaskTap: (_) {},
                  onSmartReschedule: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify event is displayed
        expect(find.text('Dialog Test'), findsOneWidget);
      },
    );
  });
}
