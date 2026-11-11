import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/shared/settings_history_scope.dart';

void main() {
  const config = CalendarAppearanceConfiguration(
    hourHeight: 60.0,
    snapMinutes: 15,
    minItemDurationMinutes: 15,
    dragThreshold: 4.0,
    startHour: 0,
    endHour: 24,
  );

  group('Calendar Undo & Redo Integration Tests', () {
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

    test('Move event -> Undo -> Redo restores and reapplies exact times', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Design Review',
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

      final day = DateTime(2026, 11, 10);

      // Move 60px down (+1 hour: 11:00 to 12:30)
      interaction.startMove(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 600),
      );
      interaction.updatePointer(const Offset(10, 660), day);
      final summary = await interaction.commit(controller);
      expect(summary, isNotNull);

      // Verify moved in repository
      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 11);
      expect(current.endsAt.toLocal().hour, 12);
      expect(current.endsAt.toLocal().minute, 30);
      expect(interaction.canUndo, isTrue);
      expect(interaction.canRedo, isFalse);

      // Undo
      final undoSummary = await interaction.undo(controller);
      expect(undoSummary, contains('Undid'));

      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.endsAt.toLocal().hour, 11);
      expect(current.endsAt.toLocal().minute, 30);
      expect(interaction.canUndo, isFalse);
      expect(interaction.canRedo, isTrue);

      // Redo
      final redoSummary = await interaction.redo(controller);
      expect(redoSummary, contains('Redid'));

      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 11);
      expect(current.endsAt.toLocal().hour, 12);
      expect(current.endsAt.toLocal().minute, 30);
      expect(interaction.canUndo, isTrue);
      expect(interaction.canRedo, isFalse);
    });

    test('Resize top edge (start time) -> Undo -> Redo', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Planning Session',
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
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

      // Drag top edge down 30px (+30 mins: start moves from 10:00 to 10:30, end stays 12:00)
      interaction.startResizeTop(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 600),
      );
      interaction.updatePointer(const Offset(10, 630), day);
      await interaction.commit(controller);

      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.startsAt.toLocal().minute, 30);
      expect(current.endsAt.toLocal().hour, 12);
      expect(current.endsAt.toLocal().minute, 0);

      // Undo
      await interaction.undo(controller);
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.startsAt.toLocal().minute, 0);
      expect(current.endsAt.toLocal().hour, 12);

      // Redo
      await interaction.redo(controller);
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 10);
      expect(current.startsAt.toLocal().minute, 30);
      expect(current.endsAt.toLocal().hour, 12);
    });

    test('Resize bottom edge (end time) -> Undo -> Redo on WorkSession', () async {
      final task = await repo.addTask(
        const TaskDraft(
          title: 'Build Feature',
          scheduledDate: '2026-11-10',
          plannedDurationMinutes: 120,
        ),
      );
      final session = await repo.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime(2026, 11, 10, 14, 0),
          endsAt: DateTime(2026, 11, 10, 15, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: session.id,
        title: task.title,
        kind: CalendarItemKind.session,
        session: session,
        task: task,
        startsAt: session.startsAt.toLocal(),
        endsAt: session.endsAt.toLocal(),
      );

      final day = DateTime(2026, 11, 10);

      // Drag bottom edge down 60px (+1 hour: end moves from 15:00 to 16:00, start stays 14:00)
      interaction.startResizeBottom(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 900),
      );
      interaction.updatePointer(const Offset(10, 960), day);
      await interaction.commit(controller);

      var current = (await repo.sessions()).firstWhere((s) => s.id == session.id);
      expect(current.startsAt.toLocal().hour, 14);
      expect(current.endsAt.toLocal().hour, 16);

      // Undo
      await interaction.undo(controller);
      current = (await repo.sessions()).firstWhere((s) => s.id == session.id);
      expect(current.startsAt.toLocal().hour, 14);
      expect(current.endsAt.toLocal().hour, 15);

      // Redo
      await interaction.redo(controller);
      current = (await repo.sessions()).firstWhere((s) => s.id == session.id);
      expect(current.startsAt.toLocal().hour, 14);
      expect(current.endsAt.toLocal().hour, 16);
    });

    test('Month date drag & drop of task preserves deadline date across Undo & Redo', () async {
      final task = await repo.addTask(
        const TaskDraft(
          title: 'Client Proposal',
          scheduledDate: '2026-11-10',
          deadlineDate: '2026-11-30',
          plannedDurationMinutes: 90,
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final item = CalendarItem(
        id: task.id,
        title: task.title,
        kind: CalendarItemKind.task,
        task: task,
      );

      // Move task from Nov 10 to Nov 15
      interaction.startDateDrag(
        item: item,
        originDate: DateTime(2026, 11, 10),
      );
      interaction.updatePointer(
        Offset.zero,
        DateTime(2026, 11, 15),
      );
      await interaction.commit(controller);

      var current = (await repo.tasks()).firstWhere((t) => t.id == task.id);
      expect(current.scheduledDate, '2026-11-15');
      expect(current.deadlineDate, '2026-11-30');

      // Undo
      await interaction.undo(controller);
      current = (await repo.tasks()).firstWhere((t) => t.id == task.id);
      expect(current.scheduledDate, '2026-11-10');
      expect(current.deadlineDate, '2026-11-30');

      // Redo
      await interaction.redo(controller);
      current = (await repo.tasks()).firstWhere((t) => t.id == task.id);
      expect(current.scheduledDate, '2026-11-15');
      expect(current.deadlineDate, '2026-11-30');
    });

    test('Month date drag & drop of event preserves clock time across Undo & Redo', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Team Sync',
          startsAt: DateTime(2026, 11, 10, 15, 30),
          endsAt: DateTime(2026, 11, 10, 16, 30),
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

      // Drop event from Nov 10 to Nov 18
      interaction.startDateDrag(
        item: item,
        originDate: DateTime(2026, 11, 10),
      );
      interaction.updatePointer(
        Offset.zero,
        DateTime(2026, 11, 18),
      );
      await interaction.commit(controller);

      var current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().day, 18);
      expect(current.startsAt.toLocal().hour, 15);
      expect(current.startsAt.toLocal().minute, 30);
      expect(current.endsAt.toLocal().day, 18);
      expect(current.endsAt.toLocal().hour, 16);
      expect(current.endsAt.toLocal().minute, 30);

      // Undo
      await interaction.undo(controller);
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().day, 10);
      expect(current.startsAt.toLocal().hour, 15);
      expect(current.startsAt.toLocal().minute, 30);

      // Redo
      await interaction.redo(controller);
      current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().day, 18);
      expect(current.startsAt.toLocal().hour, 15);
      expect(current.startsAt.toLocal().minute, 30);
    });

    test('Multiple consecutive operations work in correct LIFO order', () async {
      final eventA = await repo.addEvent(
        EventDraft(
          title: 'Event A',
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
      );
      final eventB = await repo.addEvent(
        EventDraft(
          title: 'Event B',
          startsAt: DateTime(2026, 11, 10, 11, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
      );
      final eventC = await repo.addEvent(
        EventDraft(
          title: 'Event C',
          startsAt: DateTime(2026, 11, 10, 13, 0),
          endsAt: DateTime(2026, 11, 10, 14, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final day = DateTime(2026, 11, 10);

      // Operation 1: Move Event A down 60 mins (9 -> 10)
      interaction.startMove(
        item: CalendarItem(
          id: eventA.id,
          title: eventA.title,
          kind: CalendarItemKind.event,
          event: (await repo.events()).firstWhere((e) => e.id == eventA.id),
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 600), day);
      await interaction.commit(controller);

      // Operation 2: Resize bottom of Event B down 60 mins (12 -> 13)
      interaction.startResizeBottom(
        item: CalendarItem(
          id: eventB.id,
          title: eventB.title,
          kind: CalendarItemKind.event,
          event: (await repo.events()).firstWhere((e) => e.id == eventB.id),
          startsAt: DateTime(2026, 11, 10, 11, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 720),
      );
      interaction.updatePointer(const Offset(10, 780), day);
      await interaction.commit(controller);

      // Operation 3: Move Event C down 120 mins (13 -> 15)
      interaction.startMove(
        item: CalendarItem(
          id: eventC.id,
          title: eventC.title,
          kind: CalendarItemKind.event,
          event: (await repo.events()).firstWhere((e) => e.id == eventC.id),
          startsAt: DateTime(2026, 11, 10, 13, 0),
          endsAt: DateTime(2026, 11, 10, 14, 0),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 780),
      );
      interaction.updatePointer(const Offset(10, 900), day);
      await interaction.commit(controller);

      expect(interaction.undoCount, 3);
      expect(interaction.redoCount, 0);

      // Undo 1: reverts C
      await interaction.undo(controller);
      var c = (await repo.events()).firstWhere((e) => e.id == eventC.id);
      expect(c.startsAt.toLocal().hour, 13);
      expect(interaction.undoCount, 2);
      expect(interaction.redoCount, 1);

      // Undo 2: reverts B
      await interaction.undo(controller);
      var b = (await repo.events()).firstWhere((e) => e.id == eventB.id);
      expect(b.endsAt.toLocal().hour, 12);
      expect(interaction.undoCount, 1);
      expect(interaction.redoCount, 2);

      // Undo 3: reverts A
      await interaction.undo(controller);
      var a = (await repo.events()).firstWhere((e) => e.id == eventA.id);
      expect(a.startsAt.toLocal().hour, 9);
      expect(interaction.undoCount, 0);
      expect(interaction.redoCount, 3);

      // Consecutive Redos
      // Redo 1: reapplies A
      await interaction.redo(controller);
      a = (await repo.events()).firstWhere((e) => e.id == eventA.id);
      expect(a.startsAt.toLocal().hour, 10);

      // Redo 2: reapplies B
      await interaction.redo(controller);
      b = (await repo.events()).firstWhere((e) => e.id == eventB.id);
      expect(b.endsAt.toLocal().hour, 13);

      // Redo 3: reapplies C
      await interaction.redo(controller);
      c = (await repo.events()).firstWhere((e) => e.id == eventC.id);
      expect(c.startsAt.toLocal().hour, 15);
      expect(interaction.undoCount, 3);
      expect(interaction.redoCount, 0);
    });

    test('New edit after Undo clears invalidated Redo history', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Initial Event',
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final day = DateTime(2026, 11, 10);

      // Edit 1: move to 10:00
      interaction.startMove(
        item: CalendarItem(
          id: event.id,
          title: event.title,
          kind: CalendarItemKind.event,
          event: event,
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 600), day);
      await interaction.commit(controller);

      // Undo Edit 1
      await interaction.undo(controller);
      expect(interaction.canRedo, isTrue);
      expect(interaction.redoCount, 1);

      // Now perform a fresh new Edit 2: move to 11:00
      interaction.startMove(
        item: CalendarItem(
          id: event.id,
          title: event.title,
          kind: CalendarItemKind.event,
          event: (await repo.events()).firstWhere((e) => e.id == event.id),
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 660), day); // +120px = 11:00
      await interaction.commit(controller);

      // Invalidation verified: Redo stack MUST be cleared
      expect(interaction.canRedo, isFalse);
      expect(interaction.redoCount, 0);
      expect(interaction.undoCount, 1);

      final current = (await repo.events()).firstWhere((e) => e.id == event.id);
      expect(current.startsAt.toLocal().hour, 11);
    });

    test('No-op and cancelled gestures create no history entries', () async {
      final event = await repo.addEvent(
        EventDraft(
          title: 'Unchanged Event',
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 10, 0),
        ),
      );
      await controller.refresh();

      final interaction = CalendarInteractionController(config: config);
      final day = DateTime(2026, 11, 10);
      final item = CalendarItem(
        id: event.id,
        title: event.title,
        kind: CalendarItemKind.event,
        event: event,
        startsAt: DateTime(2026, 11, 10, 9, 0),
        endsAt: DateTime(2026, 11, 10, 10, 0),
      );

      // 1. Gesture cancelled
      interaction.startMove(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 600), day);
      interaction.cancel();

      expect(interaction.canUndo, isFalse);
      expect(interaction.undoCount, 0);

      // 2. No-op drop (returned to origin before drop)
      interaction.startMove(
        item: item,
        dayDate: day,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 542), day); // Below drag threshold, snaps to same time
      final summary = await interaction.commit(controller);

      expect(summary, isNull);
      expect(interaction.canUndo, isFalse);
      expect(interaction.undoCount, 0);
    });

    test('Recurring occurrence Undo and Redo preserve parent recurrence rule', () async {
      final series = await repo.addEvent(
        EventDraft(
          title: 'Morning Huddle',
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 9, 30),
          repeat: const EventRepeat(kind: EventRepeatKind.daily),
        ),
      );

      final occurrences = await repo.eventOccurrences('2026-11-10', '2026-11-12');
      final occNov10 = occurrences.firstWhere((o) => o.nominalDate == '2026-11-10');
      final occNov11 = occurrences.firstWhere((o) => o.nominalDate == '2026-11-11');

      final interaction = CalendarInteractionController(config: config);
      final day = DateTime(2026, 11, 10);

      // Move Nov 10 occurrence from 9:00 to 10:00
      interaction.startMove(
        item: CalendarItem(
          id: occNov10.id,
          title: occNov10.title,
          kind: CalendarItemKind.event,
          event: occNov10,
          startsAt: occNov10.startsAt.toLocal(),
          endsAt: occNov10.endsAt.toLocal(),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 540),
      );
      interaction.updatePointer(const Offset(10, 600), day);
      await interaction.commit(controller);

      // Verify Nov 10 moved, Nov 11 untouched, series intact
      var list = await repo.eventOccurrences('2026-11-10', '2026-11-12');
      expect(list.firstWhere((o) => o.nominalDate == '2026-11-10').startsAt.toLocal().hour, 10);
      expect(list.firstWhere((o) => o.nominalDate == '2026-11-11').startsAt.toLocal().hour, 9);

      var parent = (await repo.events()).firstWhere((e) => e.id == series.id);
      expect(parent.startsAt.toLocal().hour, 9);
      expect(parent.repeat?.kind, EventRepeatKind.daily);

      // Undo occurrence move
      await interaction.undo(controller);
      list = await repo.eventOccurrences('2026-11-10', '2026-11-12');
      expect(list.firstWhere((o) => o.nominalDate == '2026-11-10').startsAt.toLocal().hour, 9);
      expect(list.firstWhere((o) => o.nominalDate == '2026-11-11').startsAt.toLocal().hour, 9);

      parent = (await repo.events()).firstWhere((e) => e.id == series.id);
      expect(parent.startsAt.toLocal().hour, 9);
      expect(parent.repeat?.kind, EventRepeatKind.daily);

      // Redo occurrence move
      await interaction.redo(controller);
      list = await repo.eventOccurrences('2026-11-10', '2026-11-12');
      expect(list.firstWhere((o) => o.nominalDate == '2026-11-10').startsAt.toLocal().hour, 10);
      expect(list.firstWhere((o) => o.nominalDate == '2026-11-11').startsAt.toLocal().hour, 9);

      parent = (await repo.events()).firstWhere((e) => e.id == series.id);
      expect(parent.startsAt.toLocal().hour, 9);
      expect(parent.repeat?.kind, EventRepeatKind.daily);
    });
  });

  group('Keyboard focus & shortcut conflict verification', () {
    testWidgets('SettingsHistoryScope handles Ctrl+Z and Ctrl+Shift+Z when outside text fields', (tester) async {
      int undoCalls = 0;
      int redoCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsHistoryScope(
              undo: () => undoCalls++,
              redo: () => redoCalls++,
              child: const SizedBox(key: ValueKey('outside-box'), width: 100, height: 100),
            ),
          ),
        ),
      );

      // Press Ctrl+Z
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(undoCalls, 1);
      expect(redoCalls, 0);

      // Press Ctrl+Shift+Z
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(undoCalls, 1);
      expect(redoCalls, 1);

      // Press Ctrl+Y
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(undoCalls, 1);
      expect(redoCalls, 2);
    });

    testWidgets('SettingsHistoryScope bypasses shortcuts when EditableText is focused', (tester) async {
      int undoCalls = 0;
      int redoCalls = 0;
      final controller = TextEditingController(text: 'Initial text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsHistoryScope(
              undo: () => undoCalls++,
              redo: () => redoCalls++,
              child: TextField(
                controller: controller,
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Ensure TextField has primary focus on EditableText
      final editing = FocusManager.instance.primaryFocus?.context;
      expect(
        editing != null &&
            (editing.widget is EditableText ||
                editing.findAncestorWidgetOfExactType<EditableText>() != null),
        isTrue,
      );

      // Press Ctrl+Z while text field is focused
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      // Calendar undo should NOT be triggered
      expect(undoCalls, 0, reason: 'Ctrl+Z must be ignored by calendar when text field is focused');

      // Press Ctrl+Shift+Z while text field is focused
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(redoCalls, 0, reason: 'Ctrl+Shift+Z must be ignored by calendar when text field is focused');
    });
  });
}
