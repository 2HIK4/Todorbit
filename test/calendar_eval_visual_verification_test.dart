import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
  final testDate = DateTime(2026, 11, 10);

  Future<AppController> createControllerWithSyntheticData(AppDatabase db) async {
    final repo = LifeRepository(db);

    // 1. Morning Standup
    await repo.addEvent(
      EventDraft(
        title: 'Morning Standup',
        startsAt: DateTime(2026, 11, 10, 9, 0),
        endsAt: DateTime(2026, 11, 10, 9, 30),
      ),
    );

    // 2. Overlapping 3-lane collision cluster
    await repo.addEvent(
      EventDraft(
        title: 'Sprint Planning',
        startsAt: DateTime(2026, 11, 10, 10, 0),
        endsAt: DateTime(2026, 11, 10, 11, 30),
      ),
    );
    await repo.addEvent(
      EventDraft(
        title: 'Architecture Review',
        startsAt: DateTime(2026, 11, 10, 10, 30),
        endsAt: DateTime(2026, 11, 10, 12, 0),
      ),
    );
    await repo.addEvent(
      EventDraft(
        title: 'Design Check-in',
        startsAt: DateTime(2026, 11, 10, 10, 45),
        endsAt: DateTime(2026, 11, 10, 11, 15),
      ),
    );

    // 3. Recurring event
    await repo.addEvent(
      EventDraft(
        title: 'Daily Team Sync',
        startsAt: DateTime(2026, 11, 10, 13, 0),
        endsAt: DateTime(2026, 11, 10, 13, 30),
        repeat: const EventRepeat(kind: EventRepeatKind.daily),
      ),
    );

    // 4. Task with planned date and deadline
    final task = await repo.addTask(
      const TaskDraft(
        title: 'Submit Quarterly Report',
        scheduledDate: '2026-11-10',
        deadlineDate: '2026-11-17',
        plannedDurationMinutes: 60,
      ),
    );

    // 5. Work session for the task
    await repo.addSession(
      SessionDraft(
        taskId: task.id,
        startsAt: DateTime(2026, 11, 10, 16, 0),
        endsAt: DateTime(2026, 11, 10, 17, 0),
      ),
    );

    // 6. All-day event
    await repo.addEvent(
      EventDraft(
        title: 'Q4 Strategy Offsite',
        startsAt: DateTime(2026, 11, 10),
        endsAt: DateTime(2026, 11, 11),
        allDay: true,
      ),
    );

    // 7. Untimed task
    await repo.addTask(
      const TaskDraft(
        title: 'Review Pull Request #42',
        scheduledDate: '2026-11-10',
      ),
    );

    final controller = AppController(repo);
    await controller.refresh();
    return controller;
  }

  group('Visual Layout & Rendering Verification', () {
    testWidgets('Day view renders time grid, collision cluster, and untimed items without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final controller = await createControllerWithSyntheticData(db);

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

        // Switch to Day view
        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();

        expect(find.byType(CalendarDayView), findsOneWidget);
        expect(find.byType(TimelineDayColumn), findsOneWidget);

        // Check untimed & all-day header
        expect(find.text('Q4 Strategy Offsite'), findsOneWidget);
        expect(find.textContaining('Review Pull Request #42'), findsOneWidget);

        // Check collision cluster items rendered side-by-side
        expect(find.text('Sprint Planning'), findsOneWidget);
        expect(find.text('Architecture Review'), findsOneWidget);
        expect(find.textContaining('Design Check-in'), findsOneWidget);

        // Check recurring item and work session
        expect(find.textContaining('Daily Team Sync'), findsOneWidget);
        // "Submit Quarterly Report" appears as a planned task chip in header AND as a work session card in timeline
        expect(find.textContaining('Submit Quarterly Report'), findsNWidgets(2));

        // Verify no Flutter render overflow errors
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Week view renders 7 columns and items without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final controller = await createControllerWithSyntheticData(db);

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

        // Switch to Week view
        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();

        expect(find.byType(CalendarWeekView), findsOneWidget);
        expect(find.byType(TimelineDayColumn), findsNWidgets(7));

        // Verify no Flutter render overflow errors
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Month view renders grid without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final controller = await createControllerWithSyntheticData(db);

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

        // Switch to Month view
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();

        expect(find.byType(CalendarMonthView), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Legacy calendar switch toggles cleanly between redesigned and legacy views', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final controller = await createControllerWithSyntheticData(db);

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

        // Switch to Day view
        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDayView), findsOneWidget);

        // Find the legacy toggle button in toolbar
        final legacyToggle = find.byTooltip('Switch to legacy calendar presentation');
        expect(legacyToggle, findsOneWidget);

        // Tap legacy toggle
        await tester.tap(legacyToggle);
        await tester.pumpAndSettle();

        // Redesigned Day view should not be active, tooltip should now say 'Switch to interactive timeline'
        expect(find.byType(CalendarDayView), findsNothing);
        expect(find.byTooltip('Switch to interactive timeline'), findsOneWidget);

        // Tap again to switch back to redesigned interactive calendar
        await tester.tap(find.byTooltip('Switch to interactive timeline'));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDayView), findsOneWidget);

        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Mobile surface renders responsive Day view without overflow', (tester) async {
      // Android standard portrait viewport: 412 x 892
      await tester.binding.setSurfaceSize(const Size(412, 892));
      final db = AppDatabase(NativeDatabase.memory());
      final controller = await createControllerWithSyntheticData(db);

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

        // Switch to Day view
        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();

        expect(find.byType(CalendarDayView), findsOneWidget);
        expect(find.byType(TimelineDayColumn), findsOneWidget);

        // Verify collision cluster and items render cleanly without any RenderFlex overflow
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}
