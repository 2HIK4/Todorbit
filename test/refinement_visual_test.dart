import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/workspace/workspace.dart';

import 'support/refinement_fixture.dart';
import 'support/uiux_review_capture.dart';
import 'test_privacy.dart';

void main() {
  testWidgets(
    'refinement renders populated workspace and large text calendar',
    (tester) async {
      const activation = MethodChannel('life_manager/activation');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(activation, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(activation, null));
      final capturing = Platform.environment['UIUX_CAPTURE_DIR'] != null;
      if (capturing) {
        await loadReviewFonts();
      }
      final database = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(database);
      final controller = AppController(repo);
      final temporary = Directory.systemTemp.createTempSync(
        'todorbit-refinement-',
      );
      addTearDown(() async => temporary.delete(recursive: true));
      addTearDown(database.close);
      await tester.runAsync(() async {
        final now = DateTime.now();
        await seedRefinementRows(repo, DateTime(now.year, now.month, now.day));
        await controller.refresh();
      });

      Future<void> render(
        ThemePalette palette, {
        required String name,
        required Size size,
        Brightness brightness = Brightness.dark,
        bool android = false,
        double scale = 1,
      }) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: RepaintBoundary(
              key: reviewCaptureKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(brightness, palette, android: android),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: android
                    ? MobileWorkspace(
                        preferenceStore: _CalendarPreferences(
                          File('${temporary.path}/mobile.json'),
                        ),
                      )
                    : const Workspace(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureReview(tester, name);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const desktop = Size(1920, 1080);
      controller.navigate(WorkspaceView.upcoming);
      const graphite = ThemePalette.dark;
      await render(
        graphite.withColor('accent', const Color(0xFFB4ABEE)),
        name: 'graphite-violet-upcoming',
        size: desktop,
      );
      await render(
        graphite.withColor('accent', const Color(0xFFDBB27A)),
        name: 'graphite-amber-upcoming',
        size: desktop,
      );

      if (capturing) {
        for (final (label, palette) in [
          (
            'graphite-neutral-silver',
            graphite.withColor('accent', const Color(0xFFC8CDD2)),
          ),
          (
            'graphite-sage',
            graphite.withColor('accent', const Color(0xFFB0C3AB)),
          ),
          ('beta27-teal', ThemePalette.beta27Dark),
        ]) {
          await render(palette, name: '$label-upcoming', size: desktop);
        }
      }

      final context = tester.element(find.byType(Scaffold).first);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final label = MaterialLocalizations.of(context).formatFullDate(tomorrow);
      expect(find.text(label), findsOneWidget);
      controller.setSort(TaskSort.title);
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      controller.setSort(TaskSort.schedule);
      await render(
        ThemePalette.light,
        brightness: Brightness.light,
        name: 'upcoming-light',
        size: desktop,
      );
      await render(
        ThemePalette.dark,
        name: 'upcoming-narrow',
        size: const Size(800, 740),
        scale: 1.5,
      );

      if (capturing) {
        final category = controller.categories.single;
        final project = controller.projects.first;
        for (final (label, view, id) in [
          ('today', WorkspaceView.today, null),
          ('inbox', WorkspaceView.inbox, null),
          ('category', WorkspaceView.category, category.id),
          ('project', WorkspaceView.project, project.id),
        ]) {
          controller.navigate(view, id: id);
          await render(
            ThemePalette.dark,
            name: 'desktop-$label-dark',
            size: desktop,
          );
        }
        controller.navigate(WorkspaceView.calendar);
        await render(
          ThemePalette.light,
          name: 'android-calendar-393-100-light',
          size: const Size(393, 852),
          brightness: Brightness.light,
          android: true,
        );
      }

      controller.navigate(WorkspaceView.calendar);
      await render(
        ThemePalette.dark,
        name: 'android-calendar-320-150',
        size: const Size(320, 740),
        scale: 1.5,
        android: true,
      );
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MobileCalendar), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Month'))
            .selected,
        isTrue,
      );
      await captureReview(tester, 'android-calendar-month-320-150');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _CalendarPreferences extends MobilePreferenceStore {
  _CalendarPreferences(super.file);

  @override
  Future<MobilePreferences> load() async =>
      const MobilePreferences(start: WorkspaceView.calendar);
}
