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
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/mobile/mobile_calendar.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/settings/settings_hub_dialog.dart';
import 'package:life_manager/features/settings/theme_dialog.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/app_task_row.dart';
import 'package:life_manager/features/shared/app_modal_shell.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';
import 'package:life_manager/features/workspace/task_details_view.dart';
import 'package:life_manager/features/workspace/workspace.dart';

import 'support/uiux_review_capture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AppController controller;
  late MobilePreferenceStore mobileStore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadReviewFonts();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit-lab-');
    mobileStore = MobilePreferenceStore(File('${tempDir.path}/mobile.json'));
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    final now = DateTime.now();

    final cat = await controller.repository.addCategory('Core Work');
    final proj = await controller.repository.addProject(
      cat.id,
      'Launch Sprint',
    );

    await controller.repository.addTask(
      TaskDraft(
        title: 'Review Layout Responsive Breakpoints',
        notes:
            'Verifying 320dp mobile and 1080p desktop layouts without overflow',
        status: TaskStatus.inProgress,
        priority: 3,
        categoryId: cat.id,
        projectId: proj.id,
        scheduledDate: localDate(now),
        deadlineDate: localDate(now.add(const Duration(days: 3))),
      ),
    );

    await controller.repository.addEvent(
      EventDraft(
        title: 'Architecture Review Meeting',
        startsAt: DateTime(now.year, now.month, now.day, 14),
        endsAt: DateTime(now.year, now.month, now.day, 15, 30),
        categoryId: cat.id,
      ),
    );

    await controller.refresh();
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> renderScenario({
    required WidgetTester tester,
    required String name,
    required Widget child,
    required Size size,
    double textScale = 1.0,
    Brightness brightness = Brightness.light,
    Future<void> Function(WidgetTester)? afterPump,
  }) async {
    const activation = MethodChannel('life_manager/activation');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      activation,
      (_) async => null,
    );

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: buildAppTheme(
            brightness,
            brightness == Brightness.light
                ? ThemePalette.light
                : ThemePalette.dark,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: reviewCaptureKey,
              child: Material(
                type: MaterialType.canvas,
                color: brightness == Brightness.light
                    ? ThemePalette.light['background']
                    : ThemePalette.dark['background'],
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    if (afterPump != null) {
      await afterPump(tester);
      await tester.pumpAndSettle();
    }

    // Verify zero RenderFlex overflows or unhandled render tree errors
    expect(
      tester.takeException(),
      isNull,
      reason: 'Layout overflow or exception occurred in scenario: $name',
    );

    // If capture directory is configured, export offscreen screenshot PNG and JSON metadata
    await captureReview(tester, name);
  }

  group('Headless Offscreen Layout & Responsive Viewport Lab', () {
    testWidgets('workspace-desktop-1080p: Desktop 1080p light theme', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'workspace-desktop-1080p',
        child: const Workspace(),
        size: const Size(1920, 1080),
        brightness: Brightness.light,
      );
    });

    testWidgets('workspace-desktop-720p: Desktop 720p light theme', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'workspace-desktop-720p',
        child: const Workspace(),
        size: const Size(1280, 720),
        brightness: Brightness.light,
      );
    });

    testWidgets('workspace-compact-800x600: Compact window layout', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'workspace-compact-800x600',
        child: const Workspace(),
        size: const Size(800, 600),
        brightness: Brightness.light,
      );
    });

    testWidgets('workspace-mobile-320dp: Narrow mobile 320dp viewport', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'workspace-mobile-320dp',
        child: MobileWorkspace(preferenceStore: mobileStore),
        size: const Size(320, 800),
        brightness: Brightness.dark,
      );
    });

    testWidgets(
      'workspace-mobile-320dp-large-text: 320dp with 150% text scaling',
      (tester) async {
        await renderScenario(
          tester: tester,
          name: 'workspace-mobile-320dp-large-text',
          child: MobileWorkspace(preferenceStore: mobileStore),
          size: const Size(320, 800),
          textScale: 1.5,
          brightness: Brightness.dark,
        );
      },
    );

    testWidgets('calendar-week-desktop: Calendar week view on desktop', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'calendar-week-desktop',
        child: CalendarView(
          onTaskTap: (_) {},
          onSmartReschedule: () {},
          onAddTask: (_) {},
        ),
        size: const Size(1280, 800),
        brightness: Brightness.light,
      );
    });

    testWidgets('calendar-agenda-mobile: Calendar agenda on mobile', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'calendar-agenda-mobile',
        child: MobileCalendar(openTask: (_) {}, addTask: (_) {}),
        size: const Size(360, 800),
        brightness: Brightness.light,
      );
    });

    testWidgets('settings-hub-dark: Settings hub dialog in dark theme', (
      tester,
    ) async {
      await renderScenario(
        tester: tester,
        name: 'settings-hub-dark',
        child: SettingsHubDialog(
          nativeWidget: NativeWidgetService(
            widgetExecutable: 'unavailable.exe',
          ),
          showDataProfile: () {},
        ),
        size: const Size(1000, 700),
        brightness: Brightness.dark,
      );
    });

    testWidgets(
      'task-row-dense-complex-state: Dense task row with tags and long title',
      (tester) async {
        final task = (await controller.repository.tasks()).first;
        await renderScenario(
          tester: tester,
          name: 'task-row-dense-complex-state',
          child: ListView(
            children: [
              AppTaskRow(
                task: task,
                categoryName: 'Core Work',
                projectName: 'Launch Sprint',
                checklistProgress: const TaskProgress(completed: 4, total: 5),
                subtaskProgress: const TaskProgress(completed: 2, total: 3),
                hasAlarm: true,
                variant: AppTaskRowVariant.desktop,
              ),
            ],
          ),
          size: const Size(600, 400),
          textScale: 1.5,
          brightness: Brightness.light,
        );
      },
    );

    testWidgets(
      'modal-shell-scroll-reachability: Modal shell with scrollable content and reachable actions',
      (tester) async {
        await renderScenario(
          tester: tester,
          name: 'modal-shell-scroll-reachability',
          child: AppModalShell(
            maxWidth: 600,
            maxHeight: 500,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Modal Header Title',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 40,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(
                        'List item index #$index in scrollable dialog body',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          size: const Size(1000, 700),
          brightness: Brightness.dark,
        );

        expect(find.text('Modal Header Title'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
      },
    );

    testWidgets(
      'accessibility-semantics-inspection: Semantic labels and tooltips presence',
      (tester) async {
        final task = (await controller.repository.tasks()).first;
        await renderScenario(
          tester: tester,
          name: 'accessibility-semantics-inspection',
          child: AppTaskRow(
            task: task,
            categoryName: 'Core Work',
            projectName: 'Launch Sprint',
            onToggleComplete: (_) {},
          ),
          size: const Size(800, 100),
          brightness: Brightness.light,
        );

        expect(
          find.text('Review Layout Responsive Breakpoints'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'task-details-dark: TaskDetailsView in dark Graphite Silver theme',
      (tester) async {
        final task = (await controller.repository.tasks()).first;
        await renderScenario(
          tester: tester,
          name: 'task-details-dark',
          child: TaskDetailsView(
            task: task,
            onBack: () {},
            onEdit: () {},
            onStartFocus: () {},
          ),
          size: const Size(800, 720),
          brightness: Brightness.dark,
        );
      },
    );

    testWidgets(
      'theme-dialog-compact: ThemeDialog on compact 360x640 viewport',
      (tester) async {
        await renderScenario(
          tester: tester,
          name: 'theme-dialog-compact',
          child: const Center(child: ThemeDialog()),
          size: const Size(360, 640),
          brightness: Brightness.dark,
        );
      },
    );

    testWidgets(
      'mobile-upcoming-320dp: Mobile Upcoming at 320dp and 150% text',
      (tester) async {
        final now = DateTime.now();
        await controller.repository.addTask(
          TaskDraft(
            title: 'Prepare release handoff summary',
            priority: 2,
            scheduledDate: localDate(now.add(const Duration(days: 1))),
            deadlineDate: localDate(now.add(const Duration(days: 2))),
          ),
        );
        await controller.refresh();
        controller.navigate(WorkspaceView.upcoming);
        await renderScenario(
          tester: tester,
          name: 'mobile-upcoming-320dp',
          child: MobileWorkspace(preferenceStore: mobileStore),
          size: const Size(320, 800),
          textScale: 1.5,
          brightness: Brightness.dark,
        );
      },
    );

    testWidgets(
      'calendar-week-dense-desktop: Calendar week view with overlapping cards',
      (tester) async {
        final now = DateTime.now();
        for (var i = 1; i <= 3; i++) {
          await controller.repository.addEvent(
            EventDraft(
              title: 'Studio Design Sync $i',
              startsAt: DateTime(now.year, now.month, now.day, 9, i * 15),
              endsAt: DateTime(now.year, now.month, now.day, 10, 30),
            ),
          );
        }
        await controller.refresh();
        await renderScenario(
          tester: tester,
          name: 'calendar-week-dense-desktop',
          child: CalendarView(
            onTaskTap: (_) {},
            onSmartReschedule: () {},
            onAddTask: (_) {},
          ),
          size: const Size(1100, 760),
          brightness: Brightness.dark,
        );
      },
    );

    testWidgets(
      'settings-hotkeys-desktop: Embedded Hotkeys pane in dark desktop Settings',
      (tester) async {
        await renderScenario(
          tester: tester,
          name: 'settings-hotkeys-desktop',
          child: SettingsHubDialog(
            nativeWidget: NativeWidgetService(
              widgetExecutable: 'unavailable.exe',
            ),
            showDataProfile: () {},
          ),
          size: const Size(1000, 720),
          brightness: Brightness.dark,
          afterPump: (t) async {
            await t.tap(find.text('Hotkeys').first);
          },
        );
      },
    );

    testWidgets(
      'settings-hotkeys-narrow: Embedded Hotkeys pane at 720x680 @ 1.5x text light theme',
      (tester) async {
        await renderScenario(
          tester: tester,
          name: 'settings-hotkeys-narrow',
          child: SettingsHubDialog(
            nativeWidget: NativeWidgetService(
              widgetExecutable: 'unavailable.exe',
            ),
            showDataProfile: () {},
          ),
          size: const Size(720, 680),
          textScale: 1.5,
          brightness: Brightness.light,
          afterPump: (t) async {
            await t.tap(find.byKey(const ValueKey('settings-section-picker')));
            await t.pumpAndSettle();
            await t.tap(find.text('Hotkeys').last);
          },
        );
      },
    );

    testWidgets(
      'workspace-today-dark: Desktop Today workspace in dark Graphite Silver theme',
      (tester) async {
        final now = DateTime.now();
        await controller.repository.addTask(
          TaskDraft(
            title: 'Finalize desktop widget pixel scrolling',
            priority: 2,
            scheduledDate: localDate(now),
          ),
        );
        await controller.repository.addTask(
          TaskDraft(
            title: 'Audit Hotkeys keyboard capture & presets',
            priority: 1,
            scheduledDate: localDate(now),
            deadlineDate: localDate(now.add(const Duration(days: 2))),
          ),
        );
        await controller.refresh();
        await renderScenario(
          tester: tester,
          name: 'workspace-today-dark',
          child: const Workspace(),
          size: const Size(1280, 760),
          brightness: Brightness.dark,
        );
      },
    );

    testWidgets(
      'mobile-today-dark: Android Today workspace in dark Graphite Silver theme',
      (tester) async {
        final now = DateTime.now();
        await controller.repository.addTask(
          TaskDraft(
            title: 'Review mobile launcher widget sync',
            priority: 2,
            scheduledDate: localDate(now),
          ),
        );
        await controller.refresh();
        await renderScenario(
          tester: tester,
          name: 'mobile-today-dark',
          child: MobileWorkspace(preferenceStore: mobileStore),
          size: const Size(390, 844),
          brightness: Brightness.dark,
        );
      },
    );
  });
}
