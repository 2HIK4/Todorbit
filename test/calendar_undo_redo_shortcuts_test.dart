import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';

void main() {
  group('Calendar Undo/Redo Shortcuts & Notification Dismissal Tests', () {
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

    testWidgets('1. Ctrl+Z and Ctrl+Shift+Z undo and redo after calendar event move', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Design Review',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
      );
      await controller.refresh();

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

      final state = tester.state(find.byType(CalendarView)) as dynamic;
      final focusNode = state.calendarFocusNode as FocusNode;
      expect(focusNode.hasFocus, isTrue, reason: 'CalendarView requests focus upon mounting');

      // Move event +1 hour (10:00-11:00 -> 11:00-12:00)
      final interaction = state.interactionController;
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: (await repo.events()).firstWhere((e) => e.id == event.id),
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 11, 0),
      );
      interaction.startMove(
        item: item,
        dayDate: testDate,
        pointerLocal: const Offset(10, 600),
      );
      interaction.updatePointer(const Offset(10, 660), testDate);
      await state.handleInteractionFinished();
      await tester.pump();

      // Verify event moved in repository
      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 11);
      expect(current.endsAt.toLocal().hour, 12);
      expect(focusNode.hasFocus, isTrue, reason: 'Focus retained after calendar interaction commit');

      // Press Ctrl+Z
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Verify event reverted to 10:00-11:00
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.endsAt.toLocal().hour, 11);

      // Press Ctrl+Shift+Z (Redo)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Verify event reapplied to 11:00-12:00
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 11);
      expect(current.endsAt.toLocal().hour, 12);

      // Press Ctrl+Z again
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);

      // Press Ctrl+Y (Alternate Redo)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 11);
    });

    testWidgets('2. Ctrl+Z undoes top-edge and bottom-edge calendar event resizes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Planning Session',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
      );
      await controller.refresh();

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

      final state = tester.state(find.byType(CalendarView)) as dynamic;
      final focusNode = state.calendarFocusNode as FocusNode;
      final interaction = state.interactionController;

      // Resize top edge down by 30 mins (start moves to 10:30, end stays 12:00)
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: (await repo.events()).firstWhere((e) => e.id == event.id),
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 12, 0),
      );
      interaction.startResizeTop(
        item: item,
        dayDate: testDate,
        pointerLocal: const Offset(10, 600),
      );
      interaction.updatePointer(const Offset(10, 630), testDate);
      await state.handleInteractionFinished();
      await tester.pump();

      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.startsAt.toLocal().minute, 30);
      expect(focusNode.hasFocus, isTrue);

      // Undo top edge resize with Ctrl+Z
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.startsAt.toLocal().minute, 0);

      // Resize bottom edge down by 60 mins (end moves to 13:00, start stays 10:00)
      interaction.startResizeBottom(
        item: CalendarItem(
          id: event.id,
          title: event.title,
          kind: CalendarItemKind.event,
          event: current,
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
        dayDate: testDate,
        pointerLocal: const Offset(10, 720),
      );
      interaction.updatePointer(const Offset(10, 780), testDate);
      await state.handleInteractionFinished();
      await tester.pump();

      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.endsAt.toLocal().hour, 13);

      // Undo bottom edge resize with Ctrl+Z
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.endsAt.toLocal().hour, 12);
    });

    testWidgets('3. Correct focus behavior: EditableText retains platform undo and bypasses calendar undo', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Initial Event',
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
      );
      await controller.refresh();

      final textController = TextEditingController(text: 'Initial text');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextField(
                    key: const ValueKey('test-text-field'),
                    controller: textController,
                  ),
                  Expanded(
                    child: CalendarView(
                      initialDate: testDate,
                      onTaskTap: (_) {},
                      onSmartReschedule: () {},
                      onAddTask: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(CalendarView)) as dynamic;
      final interaction = state.interactionController;

      // Move event to create an undoable calendar change
      interaction.startMove(
        item: CalendarItem(
          id: event.id,
          title: event.title,
          kind: CalendarItemKind.event,
          event: event,
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
        dayDate: testDate,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 600), testDate);
      await state.handleInteractionFinished();
      await tester.pump();

      expect(interaction.canUndo, isTrue);

      // Now focus the TextField
      await tester.tap(find.byKey(const ValueKey('test-text-field')));
      await tester.pumpAndSettle();

      final editing = FocusManager.instance.primaryFocus?.context;
      expect(
        editing != null &&
            (editing.widget is EditableText ||
                editing.findAncestorWidgetOfExactType<EditableText>() != null),
        isTrue,
        reason: 'EditableText has primary focus',
      );

      // Send Ctrl+Z while EditableText is focused
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Calendar change must NOT have been reverted
      expect(interaction.canUndo, isTrue, reason: 'Calendar undo is bypassed when an EditableText is focused');
      final current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10, reason: 'Event remains at moved time');
    });

    testWidgets('4. Toolbar Undo/Redo buttons work independently and react dynamically to history changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Toolbar Test Event',
          startsAt: DateTime(2026, 11, 10, 14, 0),
          endsAt: DateTime(2026, 11, 10, 15, 0),
        ),
      );
      await controller.refresh();

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

      final undoBtnFinder = find.widgetWithIcon(IconButton, Icons.undo);
      final redoBtnFinder = find.widgetWithIcon(IconButton, Icons.redo);

      // Initially both buttons are disabled
      expect(tester.widget<IconButton>(undoBtnFinder).onPressed, isNull);
      expect(tester.widget<IconButton>(redoBtnFinder).onPressed, isNull);

      final state = tester.state(find.byType(CalendarView)) as dynamic;
      final interaction = state.interactionController;

      // Move event
      interaction.startMove(
        item: CalendarItem(
          id: event.id,
          title: event.title,
          kind: CalendarItemKind.event,
          event: event,
          startsAt: DateTime(2026, 11, 10, 14, 0),
          endsAt: DateTime(2026, 11, 10, 15, 0),
        ),
        dayDate: testDate,
        pointerLocal: const Offset(10, 840),
      );
      interaction.updatePointer(const Offset(10, 900), testDate);
      await state.handleInteractionFinished();
      await tester.pump();

      // Undo enabled, Redo disabled
      expect(tester.widget<IconButton>(undoBtnFinder).onPressed, isNotNull);
      expect(tester.widget<IconButton>(redoBtnFinder).onPressed, isNull);

      // Tap Undo toolbar button
      await tester.tap(undoBtnFinder);
      await tester.pump();

      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 14);

      // Undo disabled, Redo enabled
      expect(tester.widget<IconButton>(undoBtnFinder).onPressed, isNull);
      expect(tester.widget<IconButton>(redoBtnFinder).onPressed, isNotNull);

      // Tap Redo toolbar button
      await tester.tap(redoBtnFinder);
      await tester.pump();

      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 15);

      // Undo enabled, Redo disabled
      expect(tester.widget<IconButton>(undoBtnFinder).onPressed, isNotNull);
      expect(tester.widget<IconButton>(redoBtnFinder).onPressed, isNull);
    });

    testWidgets('5. Calendar edit notification auto-dismisses after 4 seconds (persist: false)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      final event = await repo.addEvent(
        EventDraft(
          title: 'Notification Test Event',
          startsAt: DateTime(2026, 11, 10, 8, 0),
          endsAt: DateTime(2026, 11, 10, 9, 0),
        ),
      );
      await controller.refresh();

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

      final state = tester.state(find.byType(CalendarView)) as dynamic;
      final interaction = state.interactionController;

      // Move event
      interaction.startMove(
        item: CalendarItem(
          id: event.id,
          title: event.title,
          kind: CalendarItemKind.event,
          event: event,
          startsAt: DateTime(2026, 11, 10, 8, 0),
          endsAt: DateTime(2026, 11, 10, 9, 0),
        ),
        dayDate: testDate,
        pointerLocal: const Offset(10, 480),
      );
      interaction.updatePointer(const Offset(10, 540), testDate);
      await state.handleInteractionFinished();
      await tester.pump(); // Starts entrance animation
      await tester.pump(const Duration(milliseconds: 300)); // Finishes entrance animation

      // SnackBar is shown with action
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Verify SnackBar persist is false
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.persist, isFalse, reason: 'persist must be explicitly false so timeout auto-dismisses the notification');

      // Advance clock by 4 seconds (duration)
      await tester.pump(const Duration(seconds: 4));
      // Finish exit animation
      await tester.pumpAndSettle();

      // SnackBar must now be completely dismissed
      expect(find.byType(SnackBar), findsNothing, reason: 'Notification auto-dismisses after 4 seconds');
    });

    testWidgets('6. Repeated rapid edits cleanly replace previous notification without stacking', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final testDate = DateTime(2026, 11, 10);

      final event1 = await repo.addEvent(
        EventDraft(
          title: 'Event Alpha',
          startsAt: DateTime(2026, 11, 10, 8, 0),
          endsAt: DateTime(2026, 11, 10, 9, 0),
        ),
      );
      final event2 = await repo.addEvent(
        EventDraft(
          title: 'Event Beta',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
      );
      await controller.refresh();

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

      final state = tester.state(find.byType(CalendarView)) as dynamic;
      final interaction = state.interactionController;

      // Edit 1: Move Event Alpha
      interaction.startMove(
        item: CalendarItem(
          id: event1.id,
          title: event1.title,
          kind: CalendarItemKind.event,
          event: event1,
          startsAt: DateTime(2026, 11, 10, 8, 0),
          endsAt: DateTime(2026, 11, 10, 9, 0),
        ),
        dayDate: testDate,
        pointerLocal: const Offset(10, 480),
      );
      interaction.updatePointer(const Offset(10, 540), testDate);
      await state.handleInteractionFinished();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.textContaining('Event Alpha')), findsOneWidget);

      // Edit 2: Rapidly move Event Beta (within 500ms)
      interaction.startMove(
        item: CalendarItem(
          id: event2.id,
          title: event2.title,
          kind: CalendarItemKind.event,
          event: event2,
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
        dayDate: testDate,
        pointerLocal: const Offset(10, 600),
      );
      interaction.updatePointer(const Offset(10, 660), testDate);
      await state.handleInteractionFinished();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Exactly ONE SnackBar is displayed, showing Event Beta and replacing Event Alpha
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.textContaining('Event Beta')), findsOneWidget);
      expect(find.descendant(of: find.byType(SnackBar), matching: find.textContaining('Event Alpha')), findsNothing);

      // Advance clock by 4 seconds and settle exit animation
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
