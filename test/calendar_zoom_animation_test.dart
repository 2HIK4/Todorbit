import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/calendar/calendar_day_view.dart';
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

    for (final reducedMotion in [false, true]) {
      testWidgets(
        'mode changes use one canvas and zoom honors reduced motion=$reducedMotion',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1200, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await controller.saveCustomization(
            controller.customization.copyWith(reducedMotion: reducedMotion),
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

          expect(find.byKey(const ValueKey(CalendarMode.week)), findsOneWidget);
          await tester.tap(find.text('Day'));
          await tester.pump();
          expect(find.byKey(const ValueKey(CalendarMode.day)), findsOneWidget);
          expect(find.byKey(const ValueKey(CalendarMode.week)), findsNothing);

          double height() => tester
              .widget<CalendarDayView>(find.byType(CalendarDayView))
              .config
              .hourHeight;
          final before = height();
          await tester.tap(find.byTooltip('Zoom in time slots'));
          await tester.pump();
          final first = height();
          await tester.pumpAndSettle();
          expect(height(), greaterThan(before));
          expect(first, reducedMotion ? height() : before);
        },
      );
    }
  });
}
