import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';

void main() {
  testWidgets(
    'failed toolbar history shows an actionable error and retains history',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(db);
      final controller = AppController(repository);
      addTearDown(db.close);
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final event = await repository.addEvent(
        EventDraft(
          title: 'Removed event',
          startsAt: day.add(const Duration(hours: 10)),
          endsAt: day.add(const Duration(hours: 11)),
        ),
      );
      await controller.refresh();
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: day,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(CalendarView));
      final dynamic interaction = state.interactionController;
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
      await state.handleInteractionFinished();
      await controller.deleteEvent(event.id);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Could not undo'), findsOneWidget);
      expect(interaction.undoCount, 1);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.persist, isTrue);
      expect(snack.showCloseIcon, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
