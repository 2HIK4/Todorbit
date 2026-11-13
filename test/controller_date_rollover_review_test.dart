import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  testWidgets(
    'enabled midnight timer is cancelled when the controller is disposed',
    (tester) async {
      final previous = AppController.enableMidnightTimerInTests;
      AppController.enableMidnightTimerInTests = true;
      addTearDown(() => AppController.enableMidnightTimerInTests = previous);
      final db = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(db));
      await controller.refresh();
      await controller.checkDateRollover();
      controller.dispose();
      await tester.pump(const Duration(days: 2));
      expect(tester.takeException(), isNull);
      await db.close();
    },
  );

  test(
    'rollover reloads Today events outside the browsed calendar window',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(db);
      final controller = AppController(repository);
      addTearDown(() async {
        controller.dispose();
        await db.close();
      });
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final event = await repository.addEvent(
        EventDraft(
          title: 'New day event',
          startsAt: today.add(const Duration(hours: 10)),
          endsAt: today.add(const Duration(hours: 11)),
        ),
      );
      await controller.ensureRecurringMonth(DateTime(now.year, now.month - 6));
      // The old day's narrow Today projection did not include today's event.
      controller.todayEvents = [];
      controller.lastKnownDate = localDate(
        today.subtract(const Duration(days: 1)),
      );
      await Future<void>.sync(controller.checkDateRollover);
      controller.navigate(WorkspaceView.today);
      expect(controller.filteredEvents.map((e) => e.id), contains(event.id));
      expect(controller.lastKnownDate, localDate(today));
    },
  );
}
