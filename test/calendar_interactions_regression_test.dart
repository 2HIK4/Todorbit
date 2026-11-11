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
  });
}
