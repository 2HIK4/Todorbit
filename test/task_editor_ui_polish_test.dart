import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/shared/alarm_field.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/settings_section.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

import 'support/uiux_review_capture.dart';

void main() {
  late AppDatabase database;
  late AppController controller;
  late ProviderContainer reviewContainer;

  setUp(() async {
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
  });

  Widget buildTestHost(
    Widget child, {
    Size size = const Size(400, 800),
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
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Alarm and task review display configurations', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final category = await controller.repository.addCategory(
      'Personal projects',
    );
    final task = await controller.repository.addRecurringTask(
      TaskDraft(
        title: 'Prepare the weekly plan',
        categoryId: category.id,
        scheduledDate: '2026-11-15',
        alarm: const AlarmConfig(mode: 'planned'),
      ),
      RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2026-11-15'),
    );
    await controller.refresh();
    for (final config in reviewDisplayConfigurations) {
      tester.view.physicalSize = config.size;
      final id =
          '${config.size.width.toInt()}x${config.size.height.toInt()}-${config.scale}-${config.brightness.name}';
      await tester.pumpWidget(
        buildTestHost(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AlarmField(
              value: const AlarmConfig(mode: 'planned'),
              recurring: true,
              onChanged: (_) {},
            ),
          ),
          size: config.size,
          scale: config.scale,
          brightness: config.brightness,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sound and options'));
      await tester.tap(find.text('Sound and options'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('System sound'));
      await tester.pumpAndSettle();
      await captureReview(tester, 'normal-alarm-$id');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        buildTestHost(
          TaskEditor(task: task, onSaved: () {}, onCancel: () {}),
          size: config.size,
          scale: config.scale,
          brightness: config.brightness,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Organization'));
      await tester.pumpAndSettle();
      await captureReview(tester, 'normal-task-$id');
      expect(find.text('Save changes').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('AlarmField controls have generous spacing and clear microcopy', (
    tester,
  ) async {
    AlarmConfig alarm = const AlarmConfig(
      mode: 'planned',
      minutesBefore: 15,
      sound: 'alarm',
      durationSeconds: 30,
    );

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (width, scale) in [(320.0, 1.0), (390.0, 1.0), (320.0, 2.0)]) {
      tester.view.physicalSize = Size(width, 850);
      await tester.pumpWidget(
        buildTestHost(
          StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: AlarmField(
                  value: alarm,
                  recurring: true,
                  onChanged: (next) => setState(() => alarm = next),
                ),
              );
            },
          ),
          size: Size(width, 850),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();

      // Verify fields rendered with clearance
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Advance'), findsOneWidget);

      // Expand Sound and options
      if (find.text('System sound').hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(find.text('Sound and options'));
        await tester.tap(find.text('Sound and options'));
      }
      await tester.pumpAndSettle();

      expect(find.text('System sound'), findsOneWidget);
      expect(find.text('Stop sound after'), findsOneWidget);
      expect(find.text('Vibrate on Android'), findsOneWidget);
      final sound = find
          .ancestor(
            of: find.text('System sound'),
            matching: find.byType(InputDecorator),
          )
          .first;
      final duration = find
          .ancestor(
            of: find.text('Stop sound after'),
            matching: find.byType(InputDecorator),
          )
          .first;
      expect(
        tester.getRect(duration).top - tester.getRect(sound).bottom,
        greaterThanOrEqualTo(12),
      );
      await tester.ensureVisible(find.text('System sound'));
      await captureReview(tester, 'alarm-expanded-${width.toInt()}-$scale');
      await tester.tap(sound);
      await tester.pumpAndSettle();
      expect(find.text('Notification').hitTestable(), findsOneWidget);
      await captureReview(tester, 'alarm-menu-${width.toInt()}-$scale');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await captureReview(tester, 'alarm-focused-${width.toInt()}-$scale');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'TaskEditor Organization section adapts responsively and recurring occurrence is cleanly grouped',
    (tester) async {
      final now = DateTime.now();
      final category = await controller.repository.addCategory(
        'A long category name for planning',
      );
      final project = await controller.repository.addProject(
        category.id,
        'A long project name with several words',
      );
      final recurringTask = await controller.repository.addRecurringTask(
        TaskDraft(
          title: 'Water plants',
          scheduledDate: localDate(now),
          categoryId: category.id,
          projectId: project.id,
          alarm: const AlarmConfig(mode: 'planned'),
        ),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: localDate(now),
          interval: 1,
        ),
      );
      await controller.refresh();

      // Resize the same draft across layout/text breakpoints.
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestHost(
          TaskEditor(
            task: recurringTask,
            protectUnsavedEdits: true,
            onSaved: () {},
            onCancel: () {},
          ),
          size: const Size(420, 900),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Unsaved title survives resize',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      for (final (width, scale) in [(420.0, 1.0), (320.0, 1.0), (390.0, 2.0)]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          buildTestHost(
            TaskEditor(
              task: recurringTask,
              protectUnsavedEdits: true,
              onSaved: () {},
              onCancel: () {},
            ),
            size: Size(width, 900),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('Unsaved title survives resize'), findsOneWidget);
        await tester.ensureVisible(find.text('Organization'));
        await tester.pumpAndSettle();
        final categoryField = find
            .ancestor(
              of: find.text('Category'),
              matching: find.byType(AnchoredSelectField<String?>),
            )
            .first;
        final projectField = find
            .ancestor(
              of: find.text('Project'),
              matching: find.byType(AnchoredSelectField<String?>),
            )
            .first;
        if (width < 400 || scale > 1) {
          expect(
            tester.getTopLeft(projectField).dy,
            greaterThan(tester.getBottomLeft(categoryField).dy),
          );
        }
        await captureReview(
          tester,
          'task-organization-${width.toInt()}-$scale',
        );
        expect(tester.takeException(), isNull);
      }

      // Organization section exists
      expect(
        find.widgetWithText(SettingsSection, 'Organization'),
        findsOneWidget,
      );

      // Recurring occurrence section is structured
      expect(
        find.widgetWithText(SettingsSection, 'Recurring occurrence'),
        findsOneWidget,
      );
      expect(find.text('Edit series'), findsOneWidget);
      expect(find.text('Edit plan'), findsOneWidget);
      expect(find.text('Skip occurrence'), findsOneWidget);

      // Verify non-redundant descriptions for Resources and Checklist
      await tester.scrollUntilVisible(
        find.text('Checklist and subtask edits save immediately.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Files and links save immediately.'),
        findsOneWidget,
      );
      expect(
        find.text('Checklist and subtask edits save immediately.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Resources'));
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Checklist and subtasks'));
      await tester.tap(find.text('Checklist and subtasks'));
      await tester.pumpAndSettle();
      await captureReview(tester, 'task-resources-checklist-large');
      await tester.scrollUntilVisible(
        find.text('Use as series alarm').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use as series alarm'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Use as series alarm'),
            )
            .value,
        isTrue,
      );
      await captureReview(tester, 'task-series-alarm-large');
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Save changes').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Planned work sessions')).dy,
        lessThan(
          tester
              .getTopLeft(find.widgetWithText(FilledButton, 'Save changes'))
              .dy,
        ),
      );
      await captureReview(tester, 'task-footer-large');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
