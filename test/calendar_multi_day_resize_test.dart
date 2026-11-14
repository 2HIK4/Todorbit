import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';

void main() {
  const config = CalendarAppearanceConfiguration(
    hourHeight: 60.0,
    snapMinutes: 15,
    minItemDurationMinutes: 15,
    dragThreshold: 4.0,
    startHour: 0,
    endHour: 24,
  );

  group('Calendar Multi-Day Event Resizing Tests (CAL-03)', () {
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

    test('Example A: Extend event bottom handle across midnight into next day (Monday 8 PM to Tuesday 3 AM)', () async {
      final monday = DateTime(2026, 11, 16);
      final tuesday = DateTime(2026, 11, 17);

      // Create single-day event: Monday 8:00 PM (20:00) to 10:00 PM (22:00)
      final created = await repo.addEvent(
        EventDraft(
          title: 'Evening Study',
          startsAt: DateTime(2026, 11, 16, 20, 0),
          endsAt: DateTime(2026, 11, 16, 22, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      // Grab bottom resize handle on Monday at 22:00 (Y = 22 * 60 = 1320)
      interaction.startResizeBottom(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 1320),
        pointerTimelineY: 1320.0,
      );

      // Drag into Tuesday at 3:00 AM (Y = 3 * 60 = 180)
      interaction.updatePointer(const Offset(250, 180), tuesday, 180.0);

      expect(interaction.isDragging, isTrue);
      expect(interaction.proposedStartsAt, DateTime(2026, 11, 16, 20, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 17, 3, 0));

      // Commit resize
      final summary = await interaction.commit(controller);
      expect(summary, contains('Evening Study'));
      expect(summary, contains('2026-11-17 03:00'));

      // Verify persisted state in repository
      final allEvents = await repo.events();
      expect(allEvents, hasLength(1));
      final saved = allEvents.first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 16, 20, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 17, 3, 0));
      expect(saved.endsAt.difference(saved.startsAt), const Duration(hours: 7));

      // Verify layout placements across Monday and Tuesday
      final mondayPlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], monday);
      expect(mondayPlacements, hasLength(1));
      // On Monday, starts at 20:00 (Y = 1200) and extends to midnight (Y = 1440)
      expect(mondayPlacements.first.top, 1200.0);
      expect(mondayPlacements.first.height, 240.0);

      final tuesdayPlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], tuesday);
      expect(tuesdayPlacements, hasLength(1));
      // On Tuesday, continuation starts at midnight (Y = 0) and extends to 03:00 (Y = 180)
      expect(tuesdayPlacements.first.top, 0.0);
      expect(tuesdayPlacements.first.height, 180.0);

      // Verify Undo restores original start/end
      expect(interaction.canUndo, isTrue);
      await interaction.undo(controller);

      final undoneEvents = await repo.events();
      expect(
        undoneEvents.first.startsAt.toLocal(),
        DateTime(2026, 11, 16, 20, 0),
      );
      expect(
        undoneEvents.first.endsAt.toLocal(),
        DateTime(2026, 11, 16, 22, 0),
      );

      // Verify Redo restores multi-day span
      expect(interaction.canRedo, isTrue);
      await interaction.redo(controller);

      final redoneEvents = await repo.events();
      expect(
        redoneEvents.first.startsAt.toLocal(),
        DateTime(2026, 11, 16, 20, 0),
      );
      expect(redoneEvents.first.endsAt.toLocal(), DateTime(2026, 11, 17, 3, 0));
    });

    test('Example B: Extend event across multiple days (Monday 9 AM to Thursday 2 PM)', () async {
      final monday = DateTime(2026, 11, 16);
      final thursday = DateTime(2026, 11, 19);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Hackathon',
          startsAt: DateTime(2026, 11, 16, 9, 0),
          endsAt: DateTime(2026, 11, 16, 11, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      interaction.startResizeBottom(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 660),
        pointerTimelineY: 660.0,
      );

      // Extend bottom endpoint to Thursday 2:00 PM (14:00, Y = 14 * 60 = 840)
      interaction.updatePointer(const Offset(600, 840), thursday, 840.0);

      expect(interaction.proposedStartsAt, DateTime(2026, 11, 16, 9, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 19, 14, 0));

      await interaction.commit(controller);

      final saved = (await repo.events()).first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 16, 9, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 19, 14, 0));

      // Check intermediate day (Tuesday, full day)
      final tuesday = DateTime(2026, 11, 17);
      final tPlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], tuesday);
      expect(tPlacements, hasLength(1));
      expect(tPlacements.first.top, 0.0);
      expect(tPlacements.first.height, 1440.0); // full 24h

      // Check final day (Thursday, 00:00 to 14:00)
      final thPlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], thursday);
      expect(thPlacements, hasLength(1));
      expect(thPlacements.first.top, 0.0);
      expect(thPlacements.first.height, 840.0); // 14h
    });

    test('Example C: Resize top handle backward into previous day (Wednesday 10 AM to Tuesday 6 PM)', () async {
      final wednesday = DateTime(2026, 11, 18);
      final tuesday = DateTime(2026, 11, 17);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Long Workshop',
          startsAt: DateTime(2026, 11, 18, 10, 0),
          endsAt: DateTime(2026, 11, 18, 12, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      // Grab top resize handle on Wednesday at 10:00 (Y = 600)
      interaction.startResizeTop(
        item: item,
        dayDate: wednesday,
        pointerLocal: const Offset(400, 600),
        pointerTimelineY: 600.0,
      );

      // Drag backward to Tuesday 6:00 PM (18:00, Y = 18 * 60 = 1080)
      interaction.updatePointer(const Offset(250, 1080), tuesday, 1080.0);

      expect(interaction.proposedStartsAt, DateTime(2026, 11, 17, 18, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 18, 12, 0));

      await interaction.commit(controller);

      final saved = (await repo.events()).first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 17, 18, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 18, 12, 0));
    });

    test('Minimum duration constraint prevents zero or inverted duration when dragging', () async {
      final monday = DateTime(2026, 11, 16);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Quick Standup',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 10, 30),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      interaction.startResizeBottom(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 630),
        pointerTimelineY: 630.0,
      );

      // Drag upwards past the start time (e.g. to 9:00 AM)
      interaction.updatePointer(const Offset(100, 540), monday, 540.0);

      // End must be clamped to start + minItemDurationMinutes (15 min -> 10:15)
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 16, 10, 15));
      expect(interaction.proposedStartsAt, DateTime(2026, 11, 16, 10, 0));
    });

    test('Scenario A: Forward resize beyond visible week boundary (Sunday 8 PM to Tuesday 3 AM next week)', () async {
      final sunday = DateTime(2026, 11, 15);
      final nextTuesday = DateTime(2026, 11, 17);

      // Event on Sunday 8:00 PM (20:00) to 10:00 PM (22:00)
      final created = await repo.addEvent(
        EventDraft(
          title: 'Sunday Late Study',
          startsAt: DateTime(2026, 11, 15, 20, 0),
          endsAt: DateTime(2026, 11, 15, 22, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      // Grab bottom handle on Sunday at 22:00
      interaction.startResizeBottom(
        item: item,
        dayDate: sunday,
        pointerLocal: const Offset(600, 1320),
        pointerTimelineY: 1320.0,
      );

      // User initiates drag downwards past threshold
      interaction.updatePointer(const Offset(600, 1330), sunday, 1330.0);
      expect(interaction.isDragging, isTrue);

      // Viewport advances to next week: begin navigation preservation
      interaction.beginNavigation();
      expect(interaction.isPreservingGestureOnNavigation, isTrue);

      // Only recognizer teardown is suppressed; explicit cancel must abort.
      interaction.cancelFromRecognizer();
      expect(interaction.isDragging, isTrue);
      expect(interaction.activeItem?.id, created.id);

      // Navigation completes in next frame
      interaction.endNavigation();
      expect(interaction.isPreservingGestureOnNavigation, isFalse);

      // Pointer moves into Tuesday of next week at 3:00 AM (Y = 180)
      interaction.updatePointer(const Offset(200, 180), nextTuesday, 180.0);

      expect(interaction.proposedStartsAt, DateTime(2026, 11, 15, 20, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 17, 3, 0));

      // Commit resize
      final summary = await interaction.commit(controller);
      expect(summary, contains('Sunday Late Study'));
      expect(summary, contains('2026-11-17 03:00'));

      // Verify single underlying SQLite event record
      final allEvents = await repo.events();
      expect(allEvents, hasLength(1));
      final saved = allEvents.first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 15, 20, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 17, 3, 0));
      expect(
        saved.endsAt.difference(saved.startsAt),
        const Duration(hours: 31),
      );

      // Check layout placements across Sunday, intermediate Monday, and Tuesday
      final monday = DateTime(2026, 11, 16);
      final sunPlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], sunday);
      expect(sunPlacements, hasLength(1));
      expect(sunPlacements.first.top, 1200.0);
      expect(sunPlacements.first.height, 240.0); // 20:00 to 24:00

      final monPlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], monday);
      expect(monPlacements, hasLength(1));
      expect(monPlacements.first.top, 0.0);
      expect(monPlacements.first.height, 1440.0); // Full 24 hours

      final tuePlacements = interaction.engine.computePlacements([
        item.copyWithTime(
          startsAt: saved.startsAt.toLocal(),
          endsAt: saved.endsAt.toLocal(),
        ),
      ], nextTuesday);
      expect(tuePlacements, hasLength(1));
      expect(tuePlacements.first.top, 0.0);
      expect(tuePlacements.first.height, 180.0); // 00:00 to 03:00

      // Undo restores original duration in a single step
      await interaction.undo(controller);
      final undone = (await repo.events()).first;
      expect(undone.startsAt.toLocal(), DateTime(2026, 11, 15, 20, 0));
      expect(undone.endsAt.toLocal(), DateTime(2026, 11, 15, 22, 0));

      // Redo restores cross-week span
      await interaction.redo(controller);
      final redone = (await repo.events()).first;
      expect(redone.startsAt.toLocal(), DateTime(2026, 11, 15, 20, 0));
      expect(redone.endsAt.toLocal(), DateTime(2026, 11, 17, 3, 0));
    });

    test('Scenario B: Backward resize beyond visible week boundary (Monday 10 AM to Saturday 6 PM previous week)', () async {
      final monday = DateTime(2026, 11, 16);
      final prevSaturday = DateTime(2026, 11, 14);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Team Sprint Retrospective',
          startsAt: DateTime(2026, 11, 16, 10, 0),
          endsAt: DateTime(2026, 11, 16, 12, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      // Grab top handle on Monday at 10:00 AM (Y = 600)
      interaction.startResizeTop(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 600),
        pointerTimelineY: 600.0,
      );

      // Navigate to previous week
      interaction.beginNavigation();
      interaction.cancelFromRecognizer(); // Recognizer teardown only
      interaction.endNavigation();

      // Drag backward into Saturday of previous week at 6:00 PM (18:00, Y = 1080)
      interaction.updatePointer(const Offset(600, 1080), prevSaturday, 1080.0);

      expect(interaction.proposedStartsAt, DateTime(2026, 11, 14, 18, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 16, 12, 0));

      await interaction.commit(controller);

      final saved = (await repo.events()).first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 14, 18, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 16, 12, 0));
      expect(
        saved.endsAt.difference(saved.startsAt),
        const Duration(hours: 42),
      );

      // Undo restores Monday 10:00 to 12:00
      await interaction.undo(controller);
      final undone = (await repo.events()).first;
      expect(undone.startsAt.toLocal(), DateTime(2026, 11, 16, 10, 0));
      expect(undone.endsAt.toLocal(), DateTime(2026, 11, 16, 12, 0));
    });

    test('Scenario C: Day view extension past midnight into next day (Monday 8 PM to Tuesday 3 AM) without clamping', () async {
      final monday = DateTime(2026, 11, 16);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Night Shift',
          startsAt: DateTime(2026, 11, 16, 20, 0),
          endsAt: DateTime(2026, 11, 16, 22, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      // Grab bottom handle at 22:00 (Y = 1320)
      interaction.startResizeBottom(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 1320),
        pointerTimelineY: 1320.0,
      );

      final tuesday = DateTime(2026, 11, 17);
      // In Day view, drag 3 hours past bottom boundary into Tuesday at 3:00 AM (Y = 180)
      interaction.updatePointer(const Offset(100, 180), tuesday, 180.0);

      // Must not clamp to 11:59 PM; must extend into Tuesday 3:00 AM
      expect(interaction.proposedStartsAt, DateTime(2026, 11, 16, 20, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 17, 3, 0));

      await interaction.commit(controller);

      final saved = (await repo.events()).first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 16, 20, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 17, 3, 0));
    });

    test('Scenario D: Multi-week several-day event extension', () async {
      final friday = DateTime(2026, 11, 13);
      final followingWednesday = DateTime(2026, 11, 18);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Multi-Day Conference',
          startsAt: DateTime(friday.year, friday.month, friday.day, 9, 0),
          endsAt: DateTime(2026, 11, 15, 17, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      interaction.startResizeBottom(
        item: item,
        dayDate: DateTime(2026, 11, 15),
        pointerLocal: const Offset(500, 1020),
        pointerTimelineY: 1020.0,
      );

      // Extend to following Wednesday at 5:00 PM (17:00, Y = 1020)
      interaction.updatePointer(
        const Offset(300, 1020),
        followingWednesday,
        1020.0,
      );

      expect(interaction.proposedStartsAt, DateTime(2026, 11, 13, 9, 0));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 18, 17, 0));

      await interaction.commit(controller);

      final saved = (await repo.events()).first;
      expect(saved.startsAt.toLocal(), DateTime(2026, 11, 13, 9, 0));
      expect(saved.endsAt.toLocal(), DateTime(2026, 11, 18, 17, 0));
      expect(
        saved.endsAt.difference(saved.startsAt),
        const Duration(days: 5, hours: 8),
      );
    });

    test('Scenario E: Cancellation after crossing boundary leaves state completely clean', () async {
      final monday = DateTime(2026, 11, 16);
      final nextTuesday = DateTime(2026, 11, 17);

      final created = await repo.addEvent(
        EventDraft(
          title: 'Cancelled Drag Event',
          startsAt: DateTime(2026, 11, 16, 14, 0),
          endsAt: DateTime(2026, 11, 16, 16, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: created.id,
        title: created.title,
        kind: CalendarItemKind.event,
        startsAt: created.startsAt.toLocal(),
        endsAt: created.endsAt.toLocal(),
        event: created,
      );

      interaction.startResizeBottom(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 960),
        pointerTimelineY: 960.0,
      );

      interaction.updatePointer(const Offset(200, 600), nextTuesday, 600.0);

      expect(interaction.isDragging, isTrue);
      expect(interaction.proposedEndsAt, isNotNull);

      // Cancel gesture (simulates Escape key or cancel() invocation)
      interaction.cancel();

      expect(interaction.isDragging, isFalse);
      expect(interaction.proposedStartsAt, isNull);
      expect(interaction.proposedEndsAt, isNull);
      expect(interaction.activeItem, isNull);

      // Verify zero changes to repository
      final allEvents = await repo.events();
      expect(allEvents, hasLength(1));
      expect(allEvents.first.startsAt.toLocal(), DateTime(2026, 11, 16, 14, 0));
      expect(allEvents.first.endsAt.toLocal(), DateTime(2026, 11, 16, 16, 0));
    });
  });
}
