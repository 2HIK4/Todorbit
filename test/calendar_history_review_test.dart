import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';

void main() {
  test('session history preserves a later outcome change', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(db);
    final controller = AppController(repository);
    final interaction = CalendarInteractionController();
    addTearDown(() async {
      interaction.dispose();
      controller.dispose();
      await db.close();
    });
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final task = await repository.addTask(
      const TaskDraft(title: 'Session task'),
    );
    final session = await repository.addSession(
      SessionDraft(
        taskId: task.id,
        startsAt: day.add(const Duration(hours: 10)),
        endsAt: day.add(const Duration(hours: 11)),
      ),
    );
    await controller.refresh();
    interaction.startMove(
      item: CalendarItem(
        id: session.id,
        title: task.title,
        kind: CalendarItemKind.session,
        session: session,
        startsAt: session.startsAt.toLocal(),
        endsAt: session.endsAt.toLocal(),
      ),
      dayDate: day,
      pointerLocal: const Offset(10, 600),
    );
    interaction.updatePointer(const Offset(10, 660), day);
    await interaction.commit(controller);
    final moved = controller.sessions.single;
    await controller.updateSession(
      moved,
      SessionDraft(
        taskId: task.id,
        startsAt: moved.startsAt,
        endsAt: moved.endsAt,
        outcome: SessionOutcome.skipped,
      ),
    );
    await interaction.undo(controller);
    expect(controller.sessions.single.outcome, SessionOutcome.skipped);
    expect(controller.sessions.single.startsAt, session.startsAt);
    await interaction.redo(controller);
    expect(controller.sessions.single.outcome, SessionOutcome.skipped);
    expect(controller.sessions.single.startsAt, moved.startsAt);
  });
  for (final recurring in [false, true]) {
    test(
      'event history preserves later metadata (recurring: $recurring)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final repository = LifeRepository(db);
        final controller = AppController(repository);
        final interaction = CalendarInteractionController();
        addTearDown(() async {
          interaction.dispose();
          controller.dispose();
          await db.close();
        });
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        await repository.addEvent(
          EventDraft(
            title: 'Original event',
            startsAt: day.add(const Duration(hours: 10)),
            endsAt: day.add(const Duration(hours: 11)),
            repeat: recurring
                ? const EventRepeat(kind: EventRepeatKind.daily)
                : null,
          ),
        );
        await controller.refresh();
        final event = controller.events.firstWhere(
          (e) => e.startsAt.toLocal().day == day.day,
        );
        interaction.startMove(
          item: CalendarItem(
            id: event.id,
            title: event.title,
            kind: CalendarItemKind.event,
            event: event,
            startsAt: event.startsAt.toLocal(),
            endsAt: event.endsAt.toLocal(),
          ),
          dayDate: day,
          pointerLocal: const Offset(10, 600),
        );
        interaction.updatePointer(const Offset(10, 660), day);
        await interaction.commit(controller);
        final moved = controller.events.firstWhere(
          (e) => e.id == event.id && e.nominalDate == event.nominalDate,
        );
        final draft = EventDraft(
          title: 'Edited event',
          notes: 'Keep event notes',
          startsAt: moved.startsAt,
          endsAt: moved.endsAt,
          repeat: moved.repeat,
        );
        if (recurring) {
          await controller.updateEventOccurrence(moved, draft);
        } else {
          await controller.updateEvent(moved, draft);
        }
        await interaction.undo(controller);
        var saved = controller.events.firstWhere(
          (e) => e.id == event.id && e.nominalDate == event.nominalDate,
        );
        expect(saved.title, 'Edited event');
        expect(saved.notes, 'Keep event notes');
        expect(saved.startsAt, event.startsAt);
        await interaction.redo(controller);
        saved = controller.events.firstWhere(
          (e) => e.id == event.id && e.nominalDate == event.nominalDate,
        );
        expect(saved.title, 'Edited event');
        expect(saved.startsAt, moved.startsAt);
      },
    );
  }
  test('calendar task undo and redo preserve subsequent task edits', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(db);
    final controller = AppController(repository);
    final interaction = CalendarInteractionController();
    addTearDown(() async {
      interaction.dispose();
      controller.dispose();
      await db.close();
    });
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final next = DateTime(now.year, now.month, now.day + 1);
    final task = await repository.addTask(
      TaskDraft(title: 'Original', scheduledDate: localDate(day)),
    );
    await controller.refresh();
    interaction.startDateDrag(
      item: CalendarItem(
        id: task.id,
        title: task.title,
        kind: CalendarItemKind.task,
        task: task,
      ),
      originDate: day,
    );
    interaction.updatePointer(Offset.zero, next);
    await interaction.commit(controller);
    await controller.updateTask(
      controller.tasks.single,
      TaskDraft(
        title: 'Edited after move',
        notes: 'Keep these notes',
        status: TaskStatus.inProgress,
        scheduledDate: localDate(next),
        deadlineDate: localDate(next),
      ),
    );
    await interaction.undo(controller);
    var saved = (await repository.tasks()).single;
    expect(saved.title, 'Edited after move');
    expect(saved.notes, 'Keep these notes');
    expect(saved.status, TaskStatus.inProgress);
    expect(saved.deadlineDate, localDate(next));
    expect(saved.scheduledDate, localDate(day));
    await interaction.redo(controller);
    saved = (await repository.tasks()).single;
    expect(saved.title, 'Edited after move');
    expect(saved.scheduledDate, localDate(next));
  });
}
