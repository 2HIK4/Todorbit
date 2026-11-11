import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_day_view.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_month_view.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/calendar_week_view.dart';

void main() {
  const config = CalendarAppearanceConfiguration(
    hourHeight: 60.0,
    snapMinutes: 15,
    minItemDurationMinutes: 15,
    dragThreshold: 4.0,
    startHour: 0,
    endHour: 24,
    autoScrollMargin: 48.0,
    autoScrollSpeed: 12.0,
  );

  group('Calendar Interaction & UI Regression Tests', () {
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

    testWidgets('A. Dragging Day-view event does NOT cause unexpected scrolling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      final testDay = DateTime(2026, 11, 10);
      final event = await repo.addEvent(
        EventDraft(
          title: 'Planning Session',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 30),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarDayView(
              dayDate: testDay,
              items: [item],
              config: config,
              interactionController: interaction,
              onItemTap: (_) {},
              onSlotSecondaryTap: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(CalendarDayView),
          matching: find.byType(SingleChildScrollView),
        ).first,
      );
      final scroller = scrollable.controller!;
      final initialOffset = scroller.offset;

      // Find the event block
      final eventFinder = find.text('Planning Session');
      expect(eventFinder, findsOneWidget);

      // Start drag in center of event and move downward within viewport
      final eventCenter = tester.getCenter(eventFinder);
      final gesture = await tester.startGesture(eventCenter);
      await tester.pump(const Duration(milliseconds: 50));

      // Drag down by 60px (well within the viewport, not near bottom edge)
      await gesture.moveTo(eventCenter + const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 50));

      // Verify that scroll position has NOT jumped unexpectedly
      expect(scroller.offset, equals(initialOffset));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    test('B. Top-edge and bottom-edge resize preserve opposite boundaries', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Deep Work',
          startsAt: DateTime(2026, 11, 10, 14, 0),
          endsAt: DateTime(2026, 11, 10, 16, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      final day = DateTime(2026, 11, 10);

      // Top resize: move start from 14:00 to 14:30 (+30 min => +30px)
      interaction.startResizeTop(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 840),
        pointerTimelineY: 840,
      );
      interaction.updatePointer(
        const Offset(10, 870),
        day,
        870,
      );
      expect(interaction.proposedStartsAt!.hour, 14);
      expect(interaction.proposedStartsAt!.minute, 30);
      expect(interaction.proposedEndsAt!.hour, 16);
      expect(interaction.proposedEndsAt!.minute, 0);

      await interaction.commit(controller);

      var updated = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(updated.startsAt.toLocal().hour, 14);
      expect(updated.startsAt.toLocal().minute, 30);
      expect(updated.endsAt.toLocal().hour, 16);
      expect(updated.endsAt.toLocal().minute, 0);

      // Bottom resize: move end from 16:00 to 17:00 (+60 min => +60px)
      final updatedItem = CalendarItem(
        id: updated.id,
        title: updated.title,
        kind: CalendarItemKind.event,
        event: updated,
        startsAt: updated.startsAt.toLocal(),
        endsAt: updated.endsAt.toLocal(),
      );
      interaction.startResizeBottom(
        item: updatedItem,
        dayDate: day,
        pointerLocal: const Offset(10, 960),
        pointerTimelineY: 960,
      );
      interaction.updatePointer(
        const Offset(10, 1020),
        day,
        1020,
      );
      expect(interaction.proposedStartsAt!.hour, 14);
      expect(interaction.proposedStartsAt!.minute, 30);
      expect(interaction.proposedEndsAt!.hour, 17);
      expect(interaction.proposedEndsAt!.minute, 0);

      await interaction.commit(controller);
      updated = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(updated.startsAt.toLocal().hour, 14);
      expect(updated.startsAt.toLocal().minute, 30);
      expect(updated.endsAt.toLocal().hour, 17);
      expect(updated.endsAt.toLocal().minute, 0);
    });

    test('C. Cross-day move in Week view commits to target day and supports Undo/Redo', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Team Standup',
          startsAt: DateTime(2026, 11, 9, 9, 0), // Monday
          endsAt: DateTime(2026, 11, 9, 10, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      final monday = DateTime(2026, 11, 9);
      final wednesday = DateTime(2026, 11, 11);

      // Start move on Monday
      interaction.startMove(
        item: item,
        dayDate: monday,
        pointerLocal: const Offset(100, 540),
        pointerTimelineY: 540,
      );

      // Drag diagonally to Wednesday at 11:00 (+2 hours => +120px)
      interaction.updatePointer(
        const Offset(350, 660),
        wednesday,
        660,
      );

      expect(interaction.proposedDayDate, equals(wednesday));
      expect(interaction.proposedStartsAt!.year, 2026);
      expect(interaction.proposedStartsAt!.month, 11);
      expect(interaction.proposedStartsAt!.day, 11);
      expect(interaction.proposedStartsAt!.hour, 11);
      expect(interaction.proposedEndsAt!.hour, 12);

      // Commit
      final summary = await interaction.commit(controller);
      expect(summary, contains('Moved "Team Standup" to 2026-11-11 11:00'));

      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().day, 11);
      expect(current.startsAt.toLocal().hour, 11);

      // Undo
      final undoSummary = await interaction.undo(controller);
      expect(undoSummary, contains('Undid'));
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().day, 9);
      expect(current.startsAt.toLocal().hour, 9);

      // Redo
      final redoSummary = await interaction.redo(controller);
      expect(redoSummary, contains('Redid'));
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().day, 11);
      expect(current.startsAt.toLocal().hour, 11);
    });

    testWidgets('D. Month view card drag hitboxes work at 10%, 25%, 50%, 75%, and 90% of card width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final nov10 = DateTime(2026, 11, 10);
      final nov15 = DateTime(2026, 11, 15);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Review Deliverables',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
      );
      await controller.refresh();

      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      CalendarItem? droppedItem;
      DateTime? droppedTarget;

      Widget buildMonthView() {
        return MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: CalendarMonthView(
              selectedDate: nov10,
              firstWeekday: 1,
              itemsByDay: {nov10: [item]},
              config: config,
              onItemTap: (_) {},
              onDayTap: (_) {},
              onItemDroppedOnDate: (dItem, target) {
                droppedItem = dItem;
                droppedTarget = target;
              },
              onShowDay: (_) {},
              onShowWeek: (_) {},
              onAddEvent: (_) {},
              onAddTask: (_) {},
              onAddSession: (_) {},
            ),
          ),
        );
      }

      final fractions = [0.10, 0.25, 0.50, 0.75, 0.90];

      for (final fraction in fractions) {
        droppedItem = null;
        droppedTarget = null;

        await tester.pumpWidget(buildMonthView());
        await tester.pumpAndSettle();

        final cardFinder = find.byType(Draggable<CalendarItem>);
        expect(cardFinder, findsOneWidget);

        final cardRect = tester.getRect(cardFinder);
        final startPos = Offset(cardRect.left + (cardRect.width * fraction), cardRect.top + (cardRect.height * 0.5));

        // Drag from test position to another date cell (Nov 15)
        final targetCellFinder = find.text('15');
        expect(targetCellFinder, findsOneWidget);
        final targetCenter = tester.getCenter(targetCellFinder);

        final gesture = await tester.startGesture(startPos);
        await tester.pump(const Duration(milliseconds: 30));
        await gesture.moveTo(targetCenter);
        await tester.pump(const Duration(milliseconds: 30));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          droppedItem?.id,
          equals(item.id),
          reason: 'Drag started at fraction $fraction should drop successfully.',
        );
        expect(
          droppedTarget?.day,
          equals(nov15.day),
          reason: 'Target should be Nov 15 when drag initiated at fraction $fraction.',
        );
      }
    });

    testWidgets('E. Ctrl + Mouse Wheel zoom switches modes without scrolling timeline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: testDate,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially in Week mode
      expect(find.byType(CalendarWeekView), findsOneWidget);

      final weekView = tester.widget<CalendarWeekView>(find.byType(CalendarWeekView));
      expect(weekView, isNotNull);

      // Perform Ctrl + Wheel scroll down (scrollDelta.dy > 0 -> Zoom OUT to Month)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final center = tester.getCenter(find.byType(CalendarWeekView));

      final scrollEvent = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 150),
      );
      tester.binding.handlePointerEvent(scrollEvent);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Assert it zoomed OUT to Month view
      expect(find.byType(CalendarMonthView), findsOneWidget);
    });

    testWidgets('F. Toolbar Undo/Redo buttons react dynamically to history changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: testDate,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Undo button initially disabled
      final undoBtnFinder = find.widgetWithIcon(IconButton, Icons.undo);
      expect(undoBtnFinder, findsOneWidget);
      final undoBtn = tester.widget<IconButton>(undoBtnFinder);
      expect(undoBtn.onPressed, isNull);

      // Redo button initially disabled
      final redoBtnFinder = find.widgetWithIcon(IconButton, Icons.redo);
      expect(redoBtnFinder, findsOneWidget);
      final redoBtn = tester.widget<IconButton>(redoBtnFinder);
      expect(redoBtn.onPressed, isNull);
    });

    testWidgets('G. Month view card readability dimensions match comfortable density', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final nov10 = DateTime(2026, 11, 10);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Design Review',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
      );
      await controller.refresh();

      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarMonthView(
              selectedDate: nov10,
              firstWeekday: 1,
              itemsByDay: {nov10: [item]},
              config: config,
              onItemTap: (_) {},
              onDayTap: (_) {},
              onItemDroppedOnDate: (_, _) {},
              onShowDay: (_) {},
              onShowWeek: (_) {},
              onAddEvent: (_) {},
              onAddTask: (_) {},
              onAddSession: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Design Review'));
      expect(textWidget.style?.fontSize, greaterThanOrEqualTo(11.0));

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.event_outlined));
      expect(iconWidget.size, greaterThanOrEqualTo(12.0));
    });

    testWidgets('H. Android Month-view uses LongPressDraggable so touch scrolling does not conflict with dragging', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      final nov10 = DateTime(2026, 11, 10);
      final nov15 = DateTime(2026, 11, 15);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Mobile Task',
          startsAt: DateTime(2026, 11, 10, 14, 0),
          endsAt: DateTime(2026, 11, 10, 15, 0),
        ),
      );
      await controller.refresh();

      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      CalendarItem? droppedItem;
      DateTime? droppedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: CalendarMonthView(
              selectedDate: nov10,
              firstWeekday: 1,
              itemsByDay: {nov10: [item]},
              config: config,
              onItemTap: (_) {},
              onDayTap: (_) {},
              onItemDroppedOnDate: (dItem, target) {
                droppedItem = dItem;
                droppedTarget = target;
              },
              onShowDay: (_) {},
              onShowWeek: (_) {},
              onAddEvent: (_) {},
              onAddTask: (_) {},
              onAddSession: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On Android, items must be wrapped in LongPressDraggable to protect touch scrolling
      expect(find.byType(LongPressDraggable<CalendarItem>), findsOneWidget);
      expect(find.byType(Draggable<CalendarItem>), findsNothing);

      // Fast touch flick (less than 250ms long press) does NOT initiate drag drop
      final cardRect = tester.getRect(find.byType(LongPressDraggable<CalendarItem>));
      final startPos = cardRect.center;
      final targetCenter = tester.getCenter(find.text('15'));

      final flick = await tester.startGesture(startPos);
      await tester.pump(const Duration(milliseconds: 50));
      await flick.moveTo(targetCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await flick.up();
      await tester.pumpAndSettle();

      expect(droppedItem, isNull, reason: 'Fast touch swipe must not drag card on Android');

      // Intentional long-press (>250ms) triggers drag and successfully drops
      final dragGesture = await tester.startGesture(startPos);
      await tester.pump(const Duration(milliseconds: 300)); // Surpass 250ms delay
      await dragGesture.moveTo(targetCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await dragGesture.up();
      await tester.pumpAndSettle();

      expect(droppedItem?.title, equals('Mobile Task'));
      expect(droppedTarget, equals(nov15));
    });

    test('I. Event moves strictly preserve scheduled duration across all scenarios', () async {
      final testDay = DateTime(2026, 11, 10);
      final nextDay = DateTime(2026, 11, 11);

      // 1. Normal same-day event move (90 minutes)
      final normalEvent = await repo.addEvent(
        EventDraft(
          title: 'Design Review',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 30), // 90 min
        ),
      );
      await controller.refresh();
      final interaction = CalendarInteractionController(config: config);
      final normalItem = CalendarItem(
        id: normalEvent.id,
        title: normalEvent.title,
        kind: CalendarItemKind.event,
        event: normalEvent,
        startsAt: normalEvent.startsAt.toLocal(),
        endsAt: normalEvent.endsAt.toLocal(),
      );

      interaction.startMove(
        item: normalItem,
        dayDate: testDay,
        pointerLocal: const Offset(10, 600),
        pointerTimelineY: 600, // 10:00
      );
      interaction.updatePointer(const Offset(10, 840), testDay, 840); // 14:00
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 10, 14, 0)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 10, 15, 30)));
      expect(interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!), equals(const Duration(minutes: 90)));
      await interaction.commit(controller);
      await controller.refresh();
      var persisted = (await repo.events()).firstWhere((e) => e.id == normalEvent.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 10, 14, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 10, 15, 30)));

      // 2. Overnight event move (starts at night, ends in morning, 6 hours)
      final overnightEvent = await repo.addEvent(
        EventDraft(
          title: 'Night Shift Hackathon',
          startsAt: DateTime(2026, 11, 10, 20, 0),
          endsAt: DateTime(2026, 11, 11, 2, 0), // 6 hours
        ),
      );
      await controller.refresh();
      final overnightItem = CalendarItem(
        id: overnightEvent.id,
        title: overnightEvent.title,
        kind: CalendarItemKind.event,
        event: overnightEvent,
        startsAt: overnightEvent.startsAt.toLocal(),
        endsAt: overnightEvent.endsAt.toLocal(),
      );

      interaction.startMove(
        item: overnightItem,
        dayDate: testDay,
        pointerLocal: const Offset(10, 1200),
        pointerTimelineY: 1200, // 20:00
      );
      // Move to 23:00 near end of day column
      interaction.updatePointer(const Offset(10, 1380), testDay, 1380); // 23:00
      // Invariant: start is 23:00, end is 05:00 next day (NOT clamped to 23:59 or shifted backward to 17:59!)
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 10, 23, 0)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 11, 5, 0)));
      expect(interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!), equals(const Duration(hours: 6)));
      await interaction.commit(controller);
      await controller.refresh();
      persisted = (await repo.events()).firstWhere((e) => e.id == overnightEvent.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 10, 23, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 11, 5, 0)));

      // 3. Multi-day event lasting over 24 hours (26 hours)
      final multiDay26 = await repo.addEvent(
        EventDraft(
          title: 'Release Sprint',
          startsAt: DateTime(2026, 11, 10, 0, 0),
          endsAt: DateTime(2026, 11, 11, 2, 0), // 26 hours
        ),
      );
      await controller.refresh();
      final multiDayItem26 = CalendarItem(
        id: multiDay26.id,
        title: multiDay26.title,
        kind: CalendarItemKind.event,
        event: multiDay26,
        startsAt: multiDay26.startsAt.toLocal(),
        endsAt: multiDay26.endsAt.toLocal(),
      );

      interaction.startMove(
        item: multiDayItem26,
        dayDate: testDay,
        pointerLocal: const Offset(10, 0),
        pointerTimelineY: 0,
      );
      interaction.updatePointer(const Offset(10, 840), testDay, 840); // 14:00
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 10, 14, 0)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 11, 16, 0)));
      expect(interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!), equals(const Duration(hours: 26)));
      await interaction.commit(controller);
      await controller.refresh();
      persisted = (await repo.events()).firstWhere((e) => e.id == multiDay26.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 10, 14, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 11, 16, 0)));

      // 4. 48-hour event move
      final event48 = await repo.addEvent(
        EventDraft(
          title: 'Weekend Conference',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 12, 10, 0), // 48 hours
        ),
      );
      await controller.refresh();
      final item48 = CalendarItem(
        id: event48.id,
        title: event48.title,
        kind: CalendarItemKind.event,
        event: event48,
        startsAt: event48.startsAt.toLocal(),
        endsAt: event48.endsAt.toLocal(),
      );

      interaction.startMove(
        item: item48,
        dayDate: testDay,
        pointerLocal: const Offset(10, 600),
        pointerTimelineY: 600, // 10:00
      );
      interaction.updatePointer(const Offset(10, 720), testDay, 720); // 12:00
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 10, 12, 0)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 12, 12, 0)));
      expect(interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!), equals(const Duration(hours: 48)));
      await interaction.commit(controller);
      await controller.refresh();
      persisted = (await repo.events()).firstWhere((e) => e.id == event48.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 10, 12, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 12, 12, 0)));

      // 5. Cross-day Week move
      final movedItem48 = CalendarItem(
        id: persisted.id,
        title: persisted.title,
        kind: CalendarItemKind.event,
        event: persisted,
        startsAt: persisted.startsAt.toLocal(),
        endsAt: persisted.endsAt.toLocal(),
      );
      interaction.startMove(
        item: movedItem48,
        dayDate: testDay,
        pointerLocal: const Offset(100, 720),
        pointerTimelineY: 720,
      );
      // Drag horizontally to nextDay column (Nov 11) at 10:00 (600px)
      interaction.updatePointer(const Offset(250, 600), nextDay, 600);
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 11, 10, 0)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 13, 10, 0)));
      expect(interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!), equals(const Duration(hours: 48)));
      await interaction.commit(controller);
      await controller.refresh();
      persisted = (await repo.events()).firstWhere((e) => e.id == event48.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 11, 10, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 13, 10, 0)));

      // 6. Undo/Redo after moving a multi-day event
      expect(interaction.canUndo, isTrue);
      await interaction.undo(controller);
      await controller.refresh();
      persisted = (await repo.events()).firstWhere((e) => e.id == event48.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 10, 12, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 12, 12, 0)));

      expect(interaction.canRedo, isTrue);
      await interaction.redo(controller);
      await controller.refresh();
      persisted = (await repo.events()).firstWhere((e) => e.id == event48.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 11, 10, 0)));
      expect(persisted.endsAt.toLocal(), equals(DateTime(2026, 11, 13, 10, 0)));

      // 7. Recurring occurrence move preserves duration
      final recurring = await repo.addEvent(
        EventDraft(
          title: 'Daily Standup',
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 30), // 90 min
          repeat: const EventRepeat(kind: EventRepeatKind.daily),
        ),
      );
      await controller.refresh();
      final recurringOccurrence = CalendarItem(
        id: '${recurring.id}:2026-11-10',
        title: recurring.title,
        kind: CalendarItemKind.event,
        event: FixedEvent(
          id: recurring.id,
          title: recurring.title,
          notes: recurring.notes,
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 30),
          createdAt: recurring.createdAt,
          updatedAt: recurring.updatedAt,
          nominalDate: '2026-11-10',
        ),
        startsAt: DateTime(2026, 11, 10, 9, 0),
        endsAt: DateTime(2026, 11, 10, 10, 30),
      );

      interaction.startMove(
        item: recurringOccurrence,
        dayDate: testDay,
        pointerLocal: const Offset(10, 540),
        pointerTimelineY: 540,
      );
      interaction.updatePointer(const Offset(10, 900), testDay, 900); // 15:00
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 10, 15, 0)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 10, 16, 30)));
      expect(interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!), equals(const Duration(minutes: 90)));
      await interaction.commit(controller);
      await controller.refresh();

      // 8. Cancellation without database writes
      interaction.startMove(
        item: normalItem,
        dayDate: testDay,
        pointerLocal: const Offset(10, 840),
        pointerTimelineY: 840,
      );
      interaction.updatePointer(const Offset(10, 1020), testDay, 1020); // 17:00
      expect(interaction.isDragging, isTrue);
      interaction.cancel();
      expect(interaction.isDragging, isFalse);
      expect(interaction.gestureKind, equals(CalendarGestureKind.none));
      final commitResult = await interaction.commit(controller);
      expect(commitResult, isNull);
      persisted = (await repo.events()).firstWhere((e) => e.id == normalEvent.id);
      expect(persisted.startsAt.toLocal(), equals(DateTime(2026, 11, 10, 14, 0)), reason: 'Cancelled drag must not commit');

      // 9. ResizeEnd within column still clamps to maxEnd (23:59)
      final lateEvent = await repo.addEvent(
        EventDraft(
          title: 'Late Night Call',
          startsAt: DateTime(2026, 11, 10, 23, 50),
          endsAt: DateTime(2026, 11, 10, 23, 55),
        ),
      );
      final lateItem = CalendarItem(
        id: lateEvent.id,
        title: lateEvent.title,
        kind: CalendarItemKind.event,
        event: lateEvent,
        startsAt: lateEvent.startsAt.toLocal(),
        endsAt: lateEvent.endsAt.toLocal(),
      );

      interaction.startResizeBottom(
        item: lateItem,
        dayDate: testDay,
        pointerLocal: const Offset(10, 1430),
        pointerTimelineY: 1430,
      );
      interaction.updatePointer(const Offset(10, 1500), testDay, 1500);
      expect(interaction.proposedStartsAt, equals(DateTime(2026, 11, 10, 23, 50)));
      expect(interaction.proposedEndsAt, equals(DateTime(2026, 11, 10, 23, 59)));
    });

    testWidgets('J. Top-edge auto-scroll buffer allows pointer to overshoot slightly into header and cancellation resets state', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      final testDay = DateTime(2026, 11, 10);
      final event = await repo.addEvent(
        EventDraft(
          title: 'Scrum Sync',
          startsAt: DateTime(2026, 11, 10, 14, 0),
          endsAt: DateTime(2026, 11, 10, 15, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarDayView(
              dayDate: testDay,
              items: [item],
              config: config,
              interactionController: interaction,
              onItemTap: (_) {},
              onSlotSecondaryTap: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(CalendarDayView),
          matching: find.byType(SingleChildScrollView),
        ).first,
      );
      final scroller = scrollable.controller!;

      // Scroll timeline down so scroller is at offset 600
      scroller.jumpTo(600);
      await tester.pumpAndSettle();
      expect(scroller.offset, equals(600));

      final eventFinder = find.text('Scrum Sync');
      expect(eventFinder, findsOneWidget);

      final eventCenter = tester.getCenter(eventFinder);
      final gesture = await tester.startGesture(eventCenter, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));

      // Move slightly to pass dragThreshold (4px)
      await gesture.moveTo(eventCenter - const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 50));

      // Drag pointer to 20px below top of viewport (well within 48px auto-scroll margin)
      final viewportTop = tester.getTopLeft(find.byType(SingleChildScrollView).first).dy;
      await gesture.moveTo(Offset(eventCenter.dx, viewportTop + 20));
      await tester.pump(const Duration(milliseconds: 150));

      // Auto-scrolling up should have reduced the scroll offset
      expect(scroller.offset, lessThan(600));

      // Now move pointer 5px ABOVE the viewport top (-5px, within the -10px tolerance)
      final offsetBeforeOvershoot = scroller.offset;
      await gesture.moveTo(Offset(eventCenter.dx, viewportTop - 5));
      await tester.pump(const Duration(milliseconds: 150));

      // Auto-scroll continues even with slight -5px overshoot into header area
      expect(scroller.offset, lessThanOrEqualTo(offsetBeforeOvershoot));

      // Releasing / cancelling resets interaction state cleanly
      await gesture.up();
      interaction.cancel();
      await tester.pumpAndSettle();

      expect(interaction.gestureKind, equals(CalendarGestureKind.none));
      expect(interaction.isDragging, isFalse);
      expect(interaction.isDragging, isFalse);
    });

    testWidgets('K. Timeline item semantics and rich month view tooltips provide accessible context', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      final today = DateUtils.dateOnly(DateTime.now());
      final event = await repo.addEvent(
        EventDraft(
          title: 'Quarterly Planning',
          startsAt: DateTime(today.year, today.month, today.day, 10, 0),
          endsAt: DateTime(today.year, today.month, today.day, 11, 30),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: event.startsAt.toLocal(),
        endsAt: event.endsAt.toLocal(),
      );

      // 1. Verify Day View Semantics and Resize Tooltips
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarDayView(
              dayDate: today,
              items: [item],
              config: config,
              interactionController: interaction,
              onItemTap: (_) {},
              onSlotSecondaryTap: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Semantics node must expose title and formatted time range
      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('Quarterly Planning, 10:00 – 11:30'),
      );
      expect(semanticsFinder, findsOneWidget);

      // Tooltips for resize handles and current-time line
      expect(find.byTooltip('Drag to adjust start time'), findsOneWidget);
      expect(find.byTooltip('Drag to adjust end time'), findsOneWidget);
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      expect(find.byTooltip('Current time ($timeStr)'), findsOneWidget);

      // 2. Verify Month View Rich Tooltip
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarMonthView(
              selectedDate: today,
              firstWeekday: 1,
              itemsByDay: {today: [item]},
              config: config,
              onItemTap: (_) {},
              onDayTap: (_) {},
              onItemDroppedOnDate: (_, _) {},
              onShowDay: (_) {},
              onShowWeek: (_) {},
              onAddEvent: (_) {},
              onAddTask: (_) {},
              onAddSession: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tooltip must format title and time range in Month view
      final monthTooltipFinder = find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message != null &&
            w.message!.contains('Quarterly Planning\n10:00 – 11:30'),
      );
      expect(monthTooltipFinder, findsOneWidget);
    });
  });
}
