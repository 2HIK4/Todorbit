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

  group('Calendar Safety and Persistence Verification', () {
    test('dragging scheduled task preserves deadline date', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      try {
        final task = await repo.addTask(
          const TaskDraft(
            title: 'Critical Report',
            scheduledDate: '2026-11-10',
            deadlineDate: '2026-11-20',
            plannedDurationMinutes: 120,
          ),
        );
        expect(task.scheduledDate, '2026-11-10');
        expect(task.deadlineDate, '2026-11-20');

        final interaction = CalendarInteractionController(config: config);
        final calendarItem = CalendarItem(
          id: task.id,
          title: task.title,
          kind: CalendarItemKind.task,
          task: task,
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        );

        final day = DateTime(2026, 11, 10);
        final targetDay = DateTime(2026, 11, 12);

        // Start move and move pointer beyond dragThreshold
        interaction.startMove(
          item: calendarItem,
          dayDate: day,
          pointerLocal: const Offset(10, 540),
        );
        interaction.updatePointer(const Offset(10, 560), targetDay);

        expect(interaction.isDragging, isTrue);

        final summary = await interaction.commit(controller);
        expect(summary, isNotNull);

        // Fetch task from repository
        final updatedTasks = await repo.tasks();
        final updated = updatedTasks.firstWhere((t) => t.id == task.id);

        expect(updated.scheduledDate, '2026-11-12');
        expect(updated.deadlineDate, '2026-11-20',
            reason: 'Task deadline date MUST remain untouched when dragging scheduled work');

        // Test Undo
        final undoSummary = await interaction.undo(controller);
        expect(undoSummary, isNotNull);

        final revertedTasks = await repo.tasks();
        final reverted = revertedTasks.firstWhere((t) => t.id == task.id);
        expect(reverted.scheduledDate, '2026-11-10');
        expect(reverted.deadlineDate, '2026-11-20');
      } finally {
        await db.close();
      }
    });

    test('dragging work session preserves parent task deadline date', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      try {
        final task = await repo.addTask(
          const TaskDraft(
            title: 'Feature Work',
            scheduledDate: '2026-11-10',
            deadlineDate: '2026-11-25',
            plannedDurationMinutes: 60,
          ),
        );

        final session = await repo.addSession(
          SessionDraft(
            taskId: task.id,
            startsAt: DateTime(2026, 11, 10, 14, 0),
            endsAt: DateTime(2026, 11, 10, 15, 0),
          ),
        );

        final interaction = CalendarInteractionController(config: config);
        final calendarItem = CalendarItem(
          id: session.id,
          title: task.title,
          kind: CalendarItemKind.session,
          session: session,
          task: task,
          startsAt: session.startsAt.toLocal(),
          endsAt: session.endsAt.toLocal(),
        );

        final day = DateTime(2026, 11, 10);
        // Move session 2 hours down (120px at 60px/hr)
        interaction.startMove(
          item: calendarItem,
          dayDate: day,
          pointerLocal: const Offset(10, 840), // 14:00 is 840px
        );
        interaction.updatePointer(const Offset(10, 960), day); // 16:00 is 960px

        expect(interaction.isDragging, isTrue);

        final summary = await interaction.commit(controller);
        expect(summary, isNotNull);

        // Verify session time changed
        final sessions = await repo.sessions();
        final updatedSession = sessions.firstWhere((s) => s.id == session.id);
        expect(updatedSession.startsAt.toLocal().hour, 16);
        expect(updatedSession.endsAt.toLocal().hour, 17);

        // Verify task deadline remains strictly untouched
        final tasks = await repo.tasks();
        final updatedTask = tasks.firstWhere((t) => t.id == task.id);
        expect(updatedTask.deadlineDate, '2026-11-25');
      } finally {
        await db.close();
      }
    });

    test('editing recurring occurrence updates only that occurrence without altering series', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      try {
        // Create daily recurring event starting Nov 10
        final series = await repo.addEvent(
          EventDraft(
            title: 'Daily Standup',
            startsAt: DateTime(2026, 11, 10, 9, 0),
            endsAt: DateTime(2026, 11, 10, 9, 30),
            repeat: const EventRepeat(kind: EventRepeatKind.daily),
          ),
        );

        // Retrieve occurrences for Nov 10 and Nov 11
        final occurrences = await repo.eventOccurrences('2026-11-10', '2026-11-12');
        final occNov10 = occurrences.firstWhere((o) => o.nominalDate == '2026-11-10');
        final occNov11 = occurrences.firstWhere((o) => o.nominalDate == '2026-11-11');

        expect(occNov10.nominalDate, '2026-11-10');
        expect(occNov11.nominalDate, '2026-11-11');

        // Move only the Nov 10 occurrence down by 60 min (60px)
        final interaction = CalendarInteractionController(config: config);
        final calendarItem = CalendarItem(
          id: occNov10.id,
          title: occNov10.title,
          kind: CalendarItemKind.event,
          event: occNov10,
          startsAt: occNov10.startsAt.toLocal(),
          endsAt: occNov10.endsAt.toLocal(),
        );

        final day = DateTime(2026, 11, 10);
        interaction.startMove(
          item: calendarItem,
          dayDate: day,
          pointerLocal: const Offset(10, 540), // 9:00 is 540px
        );
        interaction.updatePointer(const Offset(10, 600), day); // +60px = 10:00

        expect(interaction.isDragging, isTrue);

        final summary = await interaction.commit(controller);
        expect(summary, isNotNull);

        // Fetch events and occurrences after commit
        final storedEvents = await repo.events();
        final parentEvent = storedEvents.firstWhere((e) => e.id == series.id);

        // Series definition must remain untouched (startsAt 9:00, daily repeat)
        expect(parentEvent.startsAt.toLocal().hour, 9,
            reason: 'Recurring parent series startsAt must not be modified');
        expect(parentEvent.repeat?.kind, EventRepeatKind.daily,
            reason: 'Series recurrence rule must remain daily');

        final recheckedOccurrences = await repo.eventOccurrences('2026-11-10', '2026-11-12');
        final updatedNov10 = recheckedOccurrences.firstWhere((o) => o.nominalDate == '2026-11-10');
        final untouchedNov11 = recheckedOccurrences.firstWhere((o) => o.nominalDate == '2026-11-11');

        // Nov 10 occurrence is now at 10:00 local
        expect(updatedNov10.startsAt.toLocal().hour, 10);
        expect(updatedNov10.endsAt.toLocal().hour, 10);
        expect(updatedNov10.endsAt.toLocal().minute, 30);

        // Nov 11 occurrence remains at 9:00 local!
        expect(untouchedNov11.startsAt.toLocal().hour, 9,
            reason: 'Other occurrences in the series must NOT be shifted');
        expect(untouchedNov11.endsAt.toLocal().hour, 9);
        expect(untouchedNov11.endsAt.toLocal().minute, 30);
      } finally {
        await db.close();
      }
    });
  });
}
