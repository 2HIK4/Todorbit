import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/workspace/task_resources_section.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/calendar/session_editor.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';
import 'package:life_manager/features/support/support_button.dart';
import 'package:life_manager/features/habits/habits_view.dart';
import 'package:life_manager/features/habits/habit_editor.dart';
import 'package:life_manager/features/goals/goals_view.dart';
import 'package:life_manager/features/goals/goal_dialogs.dart';
import 'package:life_manager/features/reports/reports_view.dart';
import 'package:life_manager/features/templates/templates_dialog.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';
import 'package:life_manager/features/workspace/sequence_dialog.dart';
import 'package:life_manager/features/workspace/trash_dialog.dart';
import 'package:life_manager/features/scheduling/smart_reschedule.dart';
import 'package:life_manager/features/time_tracking/time_tracking_dialog.dart';
import 'package:life_manager/features/settings/theme_dialog.dart';
import 'package:life_manager/features/settings/task_view_settings_dialog.dart';
import 'package:life_manager/features/settings/sidebar_order_dialog.dart';
import 'package:life_manager/features/settings/hotkeys_dialog.dart';
import 'package:life_manager/features/settings/notification_dialog.dart';
import 'package:life_manager/features/settings/privacy_dialog.dart';
import 'package:life_manager/features/settings/settings_transfer_dialog.dart';
import 'package:life_manager/features/settings/backups_cloud_page.dart';
import 'package:life_manager/features/settings/restore_confirmation_dialog.dart';
import 'package:life_manager/features/settings/software_updates_page.dart';
import 'package:life_manager/features/settings/android_software_updates_page.dart';
import 'package:life_manager/features/contributors/contributors_view.dart';
import 'package:life_manager/platform/android/android_update_service.dart';

import 'test_privacy.dart';
import 'widget_settings_page_test.dart' show FixtureCompanion;
import 'software_updates_page_test.dart' show MemoryUpdateStore;

Future<void> capture(WidgetTester tester, String name) async {
  final output = Platform.environment['AUDIT_CAPTURE_DIR'];
  if (output == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('secondary-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  late AppDatabase database;
  late AppController controller;
  late LifeTask task;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    task = await controller.repository.addTask(
      TaskDraft(title: 'Synthetic task for audit'),
    );
    await controller.refresh();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/window_theme'),
          (call) async => call.method == 'getVersion' ? '1.0.19' : null,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/window_theme'),
          null,
        );
    await database.close();
  });

  final surfaces = <String, Widget Function()>{
    'S02-S03-task-editor': () => TaskEditor(task: task),
    'S04-resources': () => SingleChildScrollView(
      child: TaskResourcesSection(
        taskId: task.id,
        repository: controller.repository,
      ),
    ),
    'S06-event-editor': () =>
        EventEditor(initialDay: DateTime(2026, 11, 4), onClose: () {}),
    'S07-session-editor': () => SessionEditor(
      initialDay: DateTime(2026, 11, 4),
      initialTaskId: task.id,
      onClose: () {},
    ),
    'S09-mobile-calendar': () => MobileCalendar(
      openTask: (_) {},
      addTask: (_) {},
      initialDay: DateTime(2026, 11, 4),
    ),
    'S39-support': () => SupportDialog(
      open: () async => throw StateError('Synthetic browser failure'),
    ),
    'S05-sequences': () => const SequenceDialog(),
    'S11-search': () => const AdvancedSearchDialog(),
    'S12-templates': () => const TemplatesDialog(),
    'S13-reschedule': () =>
        SmartRescheduleDialog(scope: 'audit', taskIds: [task.id]),
    'S13-availability': () => const AvailabilityDialog(),
    'S13-history': () => const ScheduleHistoryDialog(),
    'S14-habits': () => const HabitsView(),
    'S14-habit-editor': () => const HabitEditorDialog(),
    'S15-goals': () => const GoalsView(),
    'S15-goal-editor': () => const GoalEditorDialog(),
    'S16-focus': () => TimeTrackingDialog(taskId: task.id),
    'S17-reports': () => const ReportsView(),
    'S18-archive-trash': () => const ArchiveTrashDialog(),
    'S20-theme': () => const ThemeDialog(),
    'S21-task-preferences': () => const TaskViewSettingsDialog(),
    'S21-sidebar': () => const SidebarOrderDialog(),
    'S22-hotkeys': () => const HotkeysDialog(),
    'S23-notifications': () => NotificationDialog(service: FixtureCompanion()),
    'S24-privacy': () => const PrivacyDialog(),
    'S26-S27-backups': () =>
        const SingleChildScrollView(child: BackupsCloudPage()),
    'S26-restore-confirmation': () => const RestoreConfirmationDialog(
      backupLabel: 'Synthetic snapshot',
      summary: 'Synthetic profile, no restore will be performed.',
      localWarning: 'Current records would be replaced.',
      details: 'Synthetic recovery details',
    ),
    'S32-transfer': () => const SettingsTransferDialog(),
    'S33-windows-updates': () => SingleChildScrollView(
      child: SoftwareUpdatesPage(
        nativeWidget: FixtureCompanion(),
        preferenceStore: MemoryUpdateStore(),
      ),
    ),
    'S34-android-updates': () => AndroidSoftwareUpdatesPage(
      store: MemoryUpdateStore(),
      loadDevice: () async => const AndroidUpdateDevice(
        versionName: '1.0.19',
        versionCode: 34,
        sdk: 36,
        abis: ['x86_64'],
        distribution: 'github',
      ),
    ),
    'S39-contributors': () => const ContributorsView(),
  };
  for (final surface in surfaces.entries) {
    testWidgets('${surface.key} compact enlarged state retains usable layout', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
      if (fontFile.existsSync()) {
        final font = FontLoader('Roboto');
        font.addFont(
          Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
        );
        await font.load();
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: RepaintBoundary(
            key: const ValueKey('secondary-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(
                Brightness.dark,
                ThemePalette.dark,
                android: true,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          {
                            'S02-S03-task-editor',
                            'S04-resources',
                            'S06-event-editor',
                            'S07-session-editor',
                            'S09-mobile-calendar',
                            'S14-habits',
                            'S15-goals',
                            'S17-reports',
                            'S26-S27-backups',
                            'S33-windows-updates',
                            'S34-android-updates',
                            'S39-contributors',
                          }.contains(surface.key)
                          ? Scaffold(body: surface.value())
                          : surface.value(),
                    ),
                    child: const Text('Inspect surface'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inspect surface'));
      await tester.pumpAndSettle();
      await capture(tester, surface.key);
      expect(tester.takeException(), isNull);
      expect(find.byType(ModalBarrier), findsWidgets);
      if (surface.key == 'S06-event-editor' ||
          surface.key == 'S07-session-editor') {
        for (final end in ['start', 'end']) {
          final date = find.byKey(
            ValueKey(
              '${surface.key == 'S06-event-editor' ? 'event' : 'session'}-$end-date',
            ),
          );
          await tester.scrollUntilVisible(
            date,
            160,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          final label = tester.renderObject<RenderParagraph>(
            find.descendant(of: date, matching: find.byType(Text)),
          );
          expect(
            label.size.width,
            greaterThanOrEqualTo(
              label.getMaxIntrinsicWidth(double.infinity) - 0.01,
            ),
            reason: 'A date must remain one readable value.',
          );
        }
        await capture(tester, '${surface.key}-dates');
      } else if (surface.key == 'S21-sidebar' || surface.key == 'S13-history') {
        final label = tester.renderObject<RenderParagraph>(
          find.text(
            surface.key == 'S21-sidebar' ? 'Today' : 'Schedule history',
          ),
        );
        expect(
          label.size.width,
          greaterThanOrEqualTo(
            label.getMinIntrinsicWidth(double.infinity) - 0.01,
          ),
          reason: 'Names should retain whole words beside their controls.',
        );
        if (surface.key == 'S21-sidebar') {
          final before = List.of(controller.sidebarOrder);
          final down = find.byTooltip('Move Today down');
          await tester.ensureVisible(down);
          await tester.pumpAndSettle();
          await tester.tap(down);
          await tester.pumpAndSettle();
          expect(controller.sidebarOrder.take(2), [before[1], before[0]]);
        } else {
          await tester.tap(find.byTooltip('Close schedule history'));
          await tester.pumpAndSettle();
          expect(find.byType(ScheduleHistoryDialog), findsNothing);
        }
      } else if (surface.key == 'S17-reports') {
        final metric = tester.renderObject<RenderParagraph>(
          find.text('Completed tasks'),
        );
        expect(
          metric.size.width,
          greaterThanOrEqualTo(
            metric.getMinIntrinsicWidth(double.infinity) - 0.01,
          ),
          reason: 'Metric labels should not split a word while the row has unused space.',
        );
        final period = tester.renderObject<RenderParagraph>(
          find.text('Last 30 days'),
        );
        expect(
          period.size.width,
          greaterThanOrEqualTo(
            period.getMaxIntrinsicWidth(double.infinity) - 0.01,
          ),
          reason: 'The selected report range should remain identifiable.',
        );
        await tester.tap(find.text('Last 30 days'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MenuItemButton, 'Last 7 days'));
        await tester.pumpAndSettle();
        expect(find.text('Last 7 days'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Daily activity'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final day = tester.renderObject<RenderParagraph>(
          find.text(localDate(DateTime.now())),
        );
        expect(
          day.size.width,
          greaterThanOrEqualTo(
            day.getMaxIntrinsicWidth(double.infinity) - 0.01,
          ),
        );
      } else if (surface.key == 'S16-focus') {
        final clock = tester.renderObject<RenderParagraph>(
          find.text('00:00:00'),
        );
        expect(
          clock.size.width,
          greaterThanOrEqualTo(
            clock.getMaxIntrinsicWidth(double.infinity) - 0.01,
          ),
          reason: 'The clock must remain one readable time value.',
        );
        await tester.scrollUntilVisible(
          find.text('Start focus stopwatch'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start focus stopwatch'));
        await tester.pumpAndSettle();
        expect(
          (await controller.repository.activeTimerRun())?.state.name,
          'running',
        );
        await tester.ensureVisible(find.text('Pause'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();
        expect(
          (await controller.repository.activeTimerRun())?.state.name,
          'paused',
        );
      } else if (surface.key == 'S39-support') {
        await tester.scrollUntilVisible(
          find.text('Buy Me a Coffee'),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Buy Me a Coffee'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Could not open your browser.'),
          findsOneWidget,
        );
        expect(find.byType(SupportDialog), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Buy Me a Coffee'),
              )
              .onPressed,
          isNotNull,
        );
      } else if (surface.key == 'S13-reschedule') {
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(find.text('Apply').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('Generate preview'));
        await tester.tap(find.text('Generate preview'));
        await tester.pumpAndSettle();
        expect(
          (await controller.repository.tasks()).single.scheduledDate,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(SmartRescheduleDialog), findsNothing);
        expect(
          (await controller.repository.tasks()).single.scheduledDate,
          isNull,
        );
      } else if (surface.key == 'S13-availability') {
        final monday = find.byWidgetPredicate(
          (widget) =>
              widget is Checkbox && widget.semanticLabel == 'Enable Monday',
        );
        await tester.scrollUntilVisible(
          monday,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(monday);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(monday).value, isTrue);
        expect(find.text('Save').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(controller.availability.weekly[1]?.single.startMinute, 9 * 60);
        expect(controller.availability.weekly[1]?.single.endMinute, 17 * 60);
        expect(find.byType(AvailabilityDialog), findsNothing);
      } else if (surface.key == 'S21-task-preferences') {
        final keepCompleted = find.widgetWithText(
          SwitchListTile,
          'Keep completed tasks visible',
        );
        final before = controller.taskViewPreferences.keepCompletedVisible;
        await tester.ensureVisible(keepCompleted);
        await tester.tap(keepCompleted);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(controller.taskViewPreferences.keepCompletedVisible, !before);
        await tester.tap(find.byTooltip('Undo setting (Ctrl+Z)'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(controller.taskViewPreferences.keepCompletedVisible, before);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskViewSettingsDialog), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
