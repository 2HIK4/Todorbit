import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';

import 'test_privacy.dart';

void main() {
  group('P2-03: Calendar Date and Widget Lifecycle', () {
    testWidgets(
      'mounted Calendar defers a date while dragging and loads the requested recurrence window',
      (tester) async {
        DateTime? selected;
        final now = DateTime.now();
        final day1 = DateTime(now.year, now.month, 18);
        final day2 = DateTime(now.year, now.month + 6, 19);

        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);
        await repo.addRecurringTask(
          TaskDraft(
            title: 'Future recurring task',
            scheduledDate: localDate(day2),
          ),
          RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: localDate(day2),
            maxOccurrences: 2,
          ),
        );
        await repo.addEvent(
          EventDraft(
            title: 'Future recurring event',
            startsAt: day2
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 9)),
            endsAt: day2
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 10)),
            repeat: const EventRepeat(kind: EventRepeatKind.daily),
          ),
        );
        await controller.refresh();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CalendarView(
                  key: const ValueKey('workspace-calendar-view'),
                  initialDate: day1,
                  onTaskTap: (_) {},
                  onSmartReschedule: () {},
                  onAddTask: (_) {},
                  onDateSelected: (d) => selected = d,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check key
        expect(
          find.byKey(const ValueKey('workspace-calendar-view')),
          findsOneWidget,
        );

        final CalendarInteractionController interaction =
            (tester.state(
                  find.byType(CalendarView),
                ) as dynamic).interactionController
                as CalendarInteractionController;
        const dragged = CalendarItem(
          id: 'drag-fixture',
          title: 'Active drag',
          kind: CalendarItemKind.task,
        );
        interaction.startDateDrag(item: dragged, originDate: day1);
        await tester.pump();

        // Deliver a new date to the existing widget while its drag is active.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CalendarView(
                  key: const ValueKey('workspace-calendar-view'),
                  initialDate: day2,
                  onTaskTap: (_) {},
                  onSmartReschedule: () {},
                  onAddTask: (_) {},
                  onDateSelected: (d) => selected = d,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(selected, day1);
        expect(interaction.activeItem, same(dragged));
        expect(interaction.isDragging, isTrue);
        interaction.cancel();
        await tester.pumpAndSettle();

        // Resolve the queued date on the same Calendar and interaction owner.
        expect(
          find.byKey(const ValueKey('workspace-calendar-view')),
          findsOneWidget,
        );
        expect(selected, day2);
        expect(
          controller.eventWindowFrom,
          localDate(DateTime(day2.year, day2.month - 1)),
        );
        expect(
          controller.events.any(
            (event) => event.nominalDate == localDate(day2),
          ),
          isTrue,
        );
        expect(
          controller.tasks.any(
            (task) =>
                task.title == 'Future recurring task' &&
                task.nominalDate ==
                    localDate(day2.add(const Duration(days: 1))),
          ),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      },
    );
  });

  test(
    'ordinary task and event commits signal Sync and read refresh does not',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = AppController(LifeRepository(db));
      addTearDown(controller.dispose);
      var signals = 0;
      controller.onLocalChange = () => signals++;
      await controller.addTask(const TaskDraft(title: 'Original task'));
      expect(signals, 1);
      await controller.updateTask(
        controller.tasks.single,
        const TaskDraft(title: 'Edited task'),
      );
      expect(signals, 2);
      final day = DateTime.now().add(const Duration(hours: 1));
      await controller.addEvent(
        EventDraft(
          title: 'Original event',
          startsAt: day,
          endsAt: day.add(const Duration(hours: 1)),
        ),
      );
      expect(signals, 3);
      await controller.updateEvent(
        controller.events.single,
        EventDraft(
          title: 'Edited event',
          startsAt: day,
          endsAt: day.add(const Duration(hours: 1)),
        ),
      );
      expect(signals, 4);
      await controller.refresh();
      await controller.ensureRecurringMonth(day);
      expect(signals, 4);
    },
  );
}
