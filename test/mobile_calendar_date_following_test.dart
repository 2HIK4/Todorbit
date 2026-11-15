import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/shared/app_theme.dart';

import 'support/uiux_review_capture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AppController controller;
  late ProviderContainer reviewContainer;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit-cal-test-');
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    await controller.refresh();
    reviewContainer = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
    );
    await loadReviewFonts();
  });

  tearDown(() async {
    reviewContainer.dispose();
    await database.close();
    await tempDir.delete(recursive: true);
  });

  Widget buildCalendarTestApp({
    DateTime? initialDay,
    DateTime Function()? clock,
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) {
    return UncontrolledProviderScope(
      container: reviewContainer,
      child: RepaintBoundary(
        key: reviewCaptureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en', 'US'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          theme: buildAppTheme(
            brightness,
            brightness == Brightness.dark
                ? ThemePalette.dark
                : ThemePalette.light,
            android: true,
          ),
          home: Scaffold(
            body: MobileCalendar(
              initialDay: initialDay,
              clock: clock ?? DateTime.now,
              openTask: (_) {},
              addTask: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Calendar review display configurations', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 15, 12);
    await controller.repository.addEvent(
      EventDraft(
        title: 'Plan the week with the team',
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
      ),
    );
    await controller.refresh();
    for (final config in reviewDisplayConfigurations) {
      tester.view.physicalSize = config.size;
      await tester.pumpWidget(
        buildCalendarTestApp(
          clock: () => now,
          scale: config.scale,
          brightness: config.brightness,
        ),
      );
      await tester.pumpAndSettle();
      final id =
          '${config.size.width.toInt()}x${config.size.height.toInt()}-${config.scale}-${config.brightness.name}';
      await captureReview(tester, 'normal-calendar-$id');
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      await captureReview(tester, 'selected-calendar-$id');
      expect(find.text('Back to today').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Follow Today advances at foreground midnight and on resume', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 15, 23, 59, 59);
    await tester.pumpWidget(buildCalendarTestApp(clock: () => now));
    await tester.pumpAndSettle();
    now = DateTime(2026, 11, 16);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Today · Monday, November 16, 2026'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 18);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Today · Wednesday, November 18, 2026'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Manual browsing survives midnight and resume, Today restores following',
    (tester) async {
      var now = DateTime(2026, 11, 15, 23, 59, 59);
      await tester.pumpWidget(
        buildCalendarTestApp(
          clock: () => now,
          initialDay: DateTime(2026, 11, 10),
        ),
      );
      await tester.pumpAndSettle();
      now = DateTime(2026, 11, 16);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Tuesday, November 10, 2026'), findsOneWidget);
      await tester.tap(find.text('Back to today'));
      await tester.pumpAndSettle();
      expect(find.text('Today · Monday, November 16, 2026'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Calendar reflows and selected/pressed cards stay rounded', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 15, 12);
    await controller.repository.addEvent(
      EventDraft(
        title: 'Planning a long project with the team',
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
      ),
    );
    await controller.refresh();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (width, scale) in [(320.0, 1.0), (390.0, 1.0), (320.0, 2.0)]) {
      tester.view.physicalSize = Size(width, 850);
      await tester.pumpWidget(
        buildCalendarTestApp(clock: () => now, scale: scale),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureReview(tester, 'calendar-${width.toInt()}-$scale');
      for (final label in ['Day', 'Week', 'Month']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          ),
          hasLength(1),
          reason: '$label must not break inside a word at $width/$scale',
        );
      }
      await tester.scrollUntilVisible(
        find.text('Planning a long project with the team'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      final press = await tester.startGesture(
        tester.getCenter(find.text('Planning a long project with the team')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await captureReview(tester, 'calendar-pressed-${width.toInt()}-$scale');
      await press.cancel();
      await tester.pumpAndSettle();
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      if (scale > 1) {
        expect(
          tester.getSize(find.text('Monday, November 16, 2026')).width,
          greaterThanOrEqualTo(width - 32),
        );
      }
      await captureReview(tester, 'calendar-selected-${width.toInt()}-$scale');
      await tester.tap(find.byTooltip('Today'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Date picker selection survives resume instead of following Today',
    (tester) async {
      var now = DateTime(2026, 11, 15);
      await tester.pumpWidget(buildCalendarTestApp(clock: () => now));
      await tester.pumpAndSettle();
      await tester.tap(find.text('November 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 11, 16);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Friday, November 20, 2026'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Calendar empty guidance has readable text contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCalendarTestApp(clock: () => DateTime(2026, 11, 15)),
    );
    await tester.pumpAndSettle();
    final helper = find.text(
      'Use the action buttons above to schedule an event or task.',
    );
    final foreground = tester
        .widget<Text>(helper)
        .style!
        .color!
        .computeLuminance();
    final background = Theme.of(tester.element(helper)).scaffoldBackgroundColor
        .computeLuminance();
    final ratio = foreground > background
        ? (foreground + .05) / (background + .05)
        : (background + .05) / (foreground + .05);
    expect(ratio, greaterThanOrEqualTo(4.5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'MobileCalendar follows Today and distinguishes Today from Selected day',
    (tester) async {
      final now = DateUtils.dateOnly(DateTime.now());
      await tester.pumpWidget(buildCalendarTestApp());
      await tester.pumpAndSettle();

      // Verify Today is selected initially
      expect(find.text('${now.day}'), findsAtLeastNWidgets(1));

      // Tap "Next" or move forward
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Since we moved to next month, "Back to today" should be visible
      expect(find.text('Back to today'), findsOneWidget);

      // Tap "Back to today"
      await tester.tap(find.text('Back to today'));
      await tester.pumpAndSettle();

      // Should return to today
      expect(find.text('Back to today'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Cards inside MobileCalendar have antiAlias clipBehavior', (
    tester,
  ) async {
    final now = DateTime.now();
    await controller.repository.addEvent(
      EventDraft(
        title: 'Clipped Event',
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
      ),
    );
    await controller.refresh();

    await tester.pumpWidget(buildCalendarTestApp());
    await tester.pumpAndSettle();

    final cardFinder = find.byType(Card);
    expect(cardFinder, findsAtLeastNWidgets(1));
    for (final element in tester.widgetList<Card>(cardFinder)) {
      expect(element.clipBehavior, Clip.antiAlias);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Bottom nav navigation to calendar clears stale deep-linked day',
    (tester) async {
      final pastDay = '2026-11-01';
      final link = 'todorbit://calendar?day=$pastDay';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            theme: buildAppTheme(
              Brightness.light,
              ThemePalette.light,
              android: true,
            ),
            home: MobileWorkspace(
              initialLink: link,
              preferenceStore: MobilePreferenceStore(
                File('${tempDir.path}/mobile.json'),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      // Deep link opened calendar to past day
      expect(controller.view, WorkspaceView.calendar);

      // Navigate to Tasks tab via bottom navigation
      final tasksNav = find.text('Today');
      if (tasksNav.evaluate().isNotEmpty) {
        await tester.tap(tasksNav.first);
        await tester.pumpAndSettle();
        expect(controller.view, WorkspaceView.today);
      }

      // Now navigate back to Calendar via bottom nav
      final calendarNav = find.text('Calendar');
      expect(calendarNav, findsOneWidget);
      await tester.tap(calendarNav);
      await tester.pumpAndSettle();

      // The calendar should now open with Today selected, not the stale pastDay
      final now = DateUtils.dateOnly(DateTime.now());
      final currentMonthYear = MaterialLocalizations.of(
        tester.element(find.byType(MobileCalendar)),
      ).formatMonthYear(now);
      expect(find.text(currentMonthYear), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
