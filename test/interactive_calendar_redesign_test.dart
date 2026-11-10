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
import 'package:life_manager/features/calendar/calendar_day_view.dart';
import 'package:life_manager/features/calendar/calendar_month_view.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/calendar_week_view.dart';
import 'package:life_manager/features/calendar/timeline_grid.dart';

import 'test_privacy.dart';

void main() {
  testWidgets('day view positions timed events at accurate time and duration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime(2026, 11, 10);
    // 11:00 to 12:30 (90 minutes)
    final start = DateTime(today.year, today.month, today.day, 11, 0);
    final end = DateTime(today.year, today.month, today.day, 12, 30);

    await repo.addEvent(
      EventDraft(
        title: 'Strategy Meeting',
        startsAt: start,
        endsAt: end,
      ),
    );

    final controller = AppController(repo);
    await controller.refresh();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: today,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Day mode
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDayView), findsOneWidget);
      expect(find.byType(TimelineDayColumn), findsOneWidget);
      expect(find.text('Strategy Meeting'), findsOneWidget);
      expect(find.textContaining('11:00 – 12:30'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('day view keeps untimed and all-day items in untimed header', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime(2026, 11, 10);

    await repo.addEvent(
      EventDraft(
        title: 'Public Holiday',
        startsAt: DateTime(today.year, today.month, today.day),
        endsAt: DateTime(today.year, today.month, today.day + 1),
        allDay: true,
      ),
    );
    await repo.addTask(
      TaskDraft(
        title: 'Submit Tax Forms',
        scheduledDate: localDate(today),
      ),
    );

    final controller = AppController(repo);
    await controller.refresh();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: today,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      expect(find.textContaining('All-day & Planned (2)'), findsOneWidget);
      expect(find.text('Public Holiday'), findsOneWidget);
      expect(find.text('Plan · Submit Tax Forms'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('month view right-click context menu offers Show Day and Show Week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime(2026, 11, 10);

    final controller = AppController(repo);
    await controller.refresh();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: today,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Month view
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      // Right-click a month cell
      final cellFinder = find.text('15').first;
      await tester.tap(cellFinder, buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Add Event'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget);
      expect(find.text('Add Work Session'), findsOneWidget);
      expect(find.text('Show Day'), findsOneWidget);
      expect(find.text('Show Week'), findsOneWidget);

      // Tap 'Show Day'
      await tester.tap(find.text('Show Day'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDayView), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('keyboard shortcuts switch calendar views and jump to today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime(2026, 11, 10);

    final controller = AppController(repo);
    await controller.refresh();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: today,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus calendar and press Ctrl+1 -> Day
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, platform: 'windows');
      // With control held:
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDayView), findsOneWidget);

      // Press Ctrl+3 -> Month
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(CalendarMonthView), findsOneWidget);

      // Press Ctrl+2 -> Week
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(CalendarWeekView), findsOneWidget);

      // Press T -> Today
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('legacy calendar toggle button switches between interactive and legacy view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime(2026, 11, 10);

    final controller = AppController(repo);
    await controller.refresh();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: today,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default interactive Week view is rendered
      expect(find.byType(CalendarWeekView), findsOneWidget);

      // Tap legacy toggle icon button
      final toggleBtn = find.byTooltip('Switch to legacy calendar presentation');
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Now legacy view is rendered (CalendarWeekView is not rendered)
      expect(find.byType(CalendarWeekView), findsNothing);
      expect(find.byTooltip('Switch to interactive timeline'), findsOneWidget);

      // Tap again to switch back
      await tester.tap(find.byTooltip('Switch to interactive timeline'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarWeekView), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
