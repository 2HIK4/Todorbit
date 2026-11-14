import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';

void main() {
  group('Calendar Zoom & Mode Transition Animations (CAL-04)', () {
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

    testWidgets('AnimatedSwitcher is present with 200ms easeOutCubic transition', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animatedSwitcherFinder = find.byType(AnimatedSwitcher);
      expect(animatedSwitcherFinder, findsOneWidget);

      final switcher = tester.widget<AnimatedSwitcher>(animatedSwitcherFinder);
      expect(switcher.duration, const Duration(milliseconds: 200));
      expect(switcher.switchInCurve, Curves.easeOutCubic);
      expect(switcher.switchOutCurve, Curves.easeInCubic);
    });

    testWidgets('Reduced motion bypasses animation duration (Duration.zero)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      // Enable reduced motion in customization
      await controller.saveCustomization(
        controller.customization.copyWith(reducedMotion: true),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switcher = tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
      expect(switcher.duration, Duration.zero);
    });

    testWidgets('Mode change smoothly cross-fades between view modes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Week mode
      expect(find.byKey(const ValueKey(CalendarMode.week)), findsOneWidget);

      // Switch to Day mode by tapping "Day"
      await tester.tap(find.text('Day'));
      await tester.pump(); // Start transition

      // During animation, both incoming Day and outgoing Week exist in the stack
      expect(find.byKey(const ValueKey(CalendarMode.day)), findsOneWidget);

      // Settle animation (200ms)
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(CalendarMode.day)), findsOneWidget);
      expect(find.byKey(const ValueKey(CalendarMode.week)), findsNothing);
    });
  });
}
