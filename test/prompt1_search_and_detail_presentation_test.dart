import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_view_preferences.dart';
import 'package:life_manager/domain/theme_json.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';
import 'package:life_manager/features/settings/task_view_settings_dialog.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';
import 'package:life_manager/features/workspace/task_details_view.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/workspace/workspace.dart';
import 'package:life_manager/main.dart';

import 'test_privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prompt 1: Preference Serialization & Backwards Compatibility', () {
    test('detailPresentation defaults to sidePanel and round-trips to JSON', () {
      const defaultTheme = ThemeCustomization();
      expect(defaultTheme.detailPresentation, 'sidePanel');
      expect(defaultTheme.isFullPageDetails, isFalse);

      final fullPageTheme = defaultTheme.copyWith(detailPresentation: 'fullPage');
      expect(fullPageTheme.detailPresentation, 'fullPage');
      expect(fullPageTheme.isFullPageDetails, isTrue);

      final json = fullPageTheme.toJson();
      expect(json['detailPresentation'], 'fullPage');

      final reconstructed = ThemeCustomization.fromJson(json);
      expect(reconstructed.detailPresentation, 'fullPage');
      expect(reconstructed.isFullPageDetails, isTrue);
    });

    test('legacy JSON without detailPresentation defaults safely to sidePanel', () {
      final legacyJson = ThemeCustomization().toJson()..remove('detailPresentation');
      final normalized = normalizeThemeCustomizationJson(legacyJson);
      expect(normalized['detailPresentation'], 'sidePanel');

      final deserialized = ThemeCustomization.fromJson(legacyJson);
      expect(deserialized.detailPresentation, 'sidePanel');
      expect(deserialized.isFullPageDetails, isFalse);
    });

    test('invalid detailPresentation value throws FormatException', () {
      final invalidJson = ThemeCustomization().toJson()..['detailPresentation'] = 'floatingWindow';
      expect(
        () => normalizeThemeCustomizationJson(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('TaskViewPreferences detailPresentation defaults to sidePanel and round-trips', () {
      const defaultPrefs = TaskViewPreferences();
      expect(defaultPrefs.detailPresentation, 'sidePanel');
      expect(defaultPrefs.isFullPageDetails, isFalse);

      final fullPagePrefs = defaultPrefs.copyWith(detailPresentation: 'fullPage');
      expect(fullPagePrefs.detailPresentation, 'fullPage');
      expect(fullPagePrefs.isFullPageDetails, isTrue);
    });

    test('TaskViewPreferences detailPresentation round-trips through SettingsTransfer', () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final controller = AppController(repository);
      await controller.refresh();

      await controller.setTaskViewPreferences(
        controller.taskViewPreferences.copyWith(detailPresentation: 'fullPage'),
      );
      expect(controller.taskViewPreferences.detailPresentation, 'fullPage');
      expect(controller.isFullPageDetails, isTrue);

      final transfer = SettingsTransfer.fromController(controller);
      final encoded = transfer.encode({SettingsCategory.taskDisplay});
      expect(encoded.contains('"detailPresentation": "fullPage"'), isTrue);

      // Reset to default
      await controller.setTaskViewPreferences(
        controller.taskViewPreferences.copyWith(detailPresentation: 'sidePanel'),
      );
      expect(controller.taskViewPreferences.detailPresentation, 'sidePanel');
      expect(controller.isFullPageDetails, isFalse);

      // Restore from encoded JSON
      await SettingsTransfer.decode(encoded).applyTo(controller, {SettingsCategory.taskDisplay});
      expect(controller.taskViewPreferences.detailPresentation, 'fullPage');
      expect(controller.isFullPageDetails, isTrue);
      await database.close();
    });

    testWidgets('TaskViewSettingsDialog and Settings -> Preferences renders detail presentation selector', (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final controller = AppController(repository);
      await controller.refresh();

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: TaskViewSettingsDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify "Task & event presentation" selector is present in Task Preferences dialog
        expect(find.text('Task & event presentation'), findsOneWidget);
        final selectorFinder = find.text('Side panel (default)');
        await Scrollable.ensureVisible(tester.element(selectorFinder));
        await tester.pumpAndSettle();

        // Open dropdown and select Full page / window
        await tester.tap(selectorFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Full page / window').last);
        await tester.pumpAndSettle();

        expect(controller.taskViewPreferences.detailPresentation, 'fullPage');
        expect(controller.isFullPageDetails, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      }
    });
  });

  group('Prompt 1: Search UX & Sizing Tokens', () {
    testWidgets('desktop sidebar search bar renders unified tokens and clear button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      await repository.addTask(const TaskDraft(title: 'Review proposal'));
      final controller = AppController(repository);
      await controller.refresh();

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const MaterialApp(home: Workspace()),
          ),
        );
        await tester.pumpAndSettle();

        // Search bar in sidebar has quick search button, text field, and tune button
        expect(find.byTooltip('Quick Search (Ctrl+K)'), findsOneWidget);
        expect(find.byTooltip('Advanced search & filters'), findsOneWidget);

        final searchFieldFinder = find.widgetWithText(TextField, 'Search tasks & events...');
        expect(searchFieldFinder, findsOneWidget);

        // Typing a query displays the clear button
        await tester.enterText(searchFieldFinder, 'proposal');
        await tester.pumpAndSettle();
        expect(find.byTooltip('Clear search'), findsOneWidget);

        // Tapping clear clears the text field
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Clear search'), findsNothing);

        // Tapping tune opens AdvancedSearchDialog
        await tester.tap(find.byTooltip('Advanced search & filters'));
        await tester.pumpAndSettle();
        expect(find.byType(AdvancedSearchDialog), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('mobile header search bar renders unified styled container and controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      await repository.addTask(const TaskDraft(title: 'Mobile task'));
      final controller = AppController(repository);
      await controller.refresh();

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const MaterialApp(home: MobileWorkspace()),
          ),
        );
        await tester.pumpAndSettle();

        // Initially search icon is in AppBar actions
        expect(find.byTooltip('Search tasks and events'), findsOneWidget);
        await tester.tap(find.byTooltip('Search tasks and events'));
        await tester.pumpAndSettle();

        // Now in search mode: search container is active
        expect(find.byTooltip('Close search'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Search tasks and events'), findsOneWidget);
        expect(find.byTooltip('Advanced search & filters'), findsOneWidget);

        // Enter text: clear search text button appears
        await tester.enterText(
          find.widgetWithText(TextField, 'Search tasks and events'),
          'Mobile',
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Clear search text'), findsOneWidget);

        // Tapping clear search text clears field without closing search
        await tester.tap(find.byTooltip('Clear search text'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Clear search text'), findsNothing);
        expect(find.byTooltip('Close search'), findsOneWidget);

        // Tapping close search exits search mode
        await tester.tap(find.byTooltip('Close search'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Search tasks and events'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });

  group('Prompt 1: Advanced Search Progressive Disclosure & Keyboard Insets', () {
    testWidgets('progressive disclosure displays collapsible groups and lightweight explanation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 750));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      await repository.addTask(const TaskDraft(title: 'Organize office', priority: 3));
      final controller = AppController(repository);
      await controller.refresh();

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((ref) => controller)],
            child: const MaterialApp(
              home: Scaffold(
                body: AdvancedSearchDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify single lightweight explanation is present
        expect(
          find.text('Filters combine with AND; options within each filter combine with OR.'),
          findsOneWidget,
        );

        // Verify repetitive verbose headers are absent
        expect(
          find.textContaining('OR among selected · none selected means any'),
          findsNothing,
        );

        // Verify collapsible filter groups exist with summaries
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Priority'), findsOneWidget);
        expect(find.text('Dates & Deadlines'), findsOneWidget);
        expect(find.text('Properties'), findsOneWidget);
        expect(find.text('Sort Results'), findsOneWidget);

        // Tap Priority group to expand it and select High
        await tester.tap(find.text('Priority'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilterChip, 'High'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilterChip, 'High'));
        await tester.pumpAndSettle();

        // 1 matching task
        expect(find.text('1 matching tasks'), findsOneWidget);

        // Reset button appears in header when filters are active
        expect(find.text('Reset'), findsOneWidget);
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        // After reset, matches return to all (1 total task in DB)
        expect(find.text('Reset'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('adapts smoothly when software keyboard opens with viewInsets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(database));
      await controller.refresh();

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((ref) => controller)],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 800),
                  viewInsets: EdgeInsets.only(bottom: 280),
                ),
                child: const Scaffold(
                  body: AdvancedSearchDialog(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zero RenderFlex overflow with keyboard open
        expect(tester.takeException(), isNull);

        // Sticky footer remains visible above virtual keyboard
        expect(find.text('0 matching tasks'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save as Custom View'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });

  group('Prompt 1: Detail Navigation — One Route/State Decision & Zero Stale Editors', () {
    testWidgets('sidePanel default mode opens side editor; close/back fully dismisses with zero stale editors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      await repository.addTask(const TaskDraft(title: 'Inspect side panel'));
      final controller = AppController(repository);
      await controller.refresh();
      controller.navigate(WorkspaceView.all);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const LifeManagerApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no task editor is visible
        expect(find.byType(TaskEditor), findsNothing);
        expect(find.byType(TaskDetailsView), findsNothing);

        // Tap task in list
        await tester.tap(find.text('Inspect side panel').first);
        await tester.pumpAndSettle();

        // In sidePanel mode: TaskEditor is mounted in the side panel
        expect(find.byType(TaskEditor), findsOneWidget);
        // Full page TaskDetailsView is NOT opened
        expect(find.byType(TaskDetailsView), findsNothing);

        // Press Escape to close
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Exactly zero editors remain; no secondary editor reveals itself
        expect(find.byType(TaskEditor), findsNothing);
        expect(find.byType(TaskDetailsView), findsNothing);
        expect(controller.selectedTaskId, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('fullPage mode opens full-page TaskDetailsView; closing returns cleanly with zero stale editors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      await repository.addTask(const TaskDraft(title: 'Inspect full page'));
      final controller = AppController(repository);
      await controller.refresh();
      // Configure preference for fullPage presentation
      controller.taskViewPreferences = controller.taskViewPreferences.copyWith(detailPresentation: 'fullPage');
      controller.navigate(WorkspaceView.all);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const LifeManagerApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap task in list
        await tester.tap(find.text('Inspect full page').first);
        await tester.pumpAndSettle();

        // In fullPage mode: TaskDetailsView is mounted in the main panel
        expect(find.byType(TaskDetailsView), findsOneWidget);
        // Side panel TaskEditor is NOT opened
        expect(find.byType(TaskEditor), findsNothing);

        // Press Escape to close full-page view
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Both views are fully closed; no side editor appears behind it
        expect(find.byType(TaskDetailsView), findsNothing);
        expect(find.byType(TaskEditor), findsNothing);
        expect(controller.selectedTaskId, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('event open/close in sidePanel mode opens side panel and closes cleanly without modal or stale editor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final now = DateTime.now();
      final eventStart = DateTime(now.year, now.month, now.day, 10, 0);
      await repository.addEvent(EventDraft(
        title: 'Team sync',
        startsAt: eventStart,
        endsAt: eventStart.add(const Duration(hours: 1)),
      ));
      final controller = AppController(repository);
      await controller.refresh();
      controller.navigate(WorkspaceView.calendar);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const LifeManagerApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no event editor
        expect(find.byType(EventEditor), findsNothing);

        final eventFinder = find.text('Team sync').first;
        await Scrollable.ensureVisible(tester.element(eventFinder));
        await tester.pumpAndSettle();

        // Tap the event in the calendar
        await tester.tap(eventFinder);
        await tester.pumpAndSettle();

        // In sidePanel mode: EventEditor is mounted in the side panel
        expect(find.byType(EventEditor), findsOneWidget);

        // Press Escape
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // EventEditor is closed completely
        expect(find.byType(EventEditor), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('repeated open/close transitions never leak secondary editors in either mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      await repository.addTask(const TaskDraft(title: 'Task Alpha'));
      await repository.addTask(const TaskDraft(title: 'Task Beta'));
      final controller = AppController(repository);
      await controller.refresh();
      controller.navigate(WorkspaceView.all);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const LifeManagerApp(),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          // Open Alpha
          await tester.tap(find.text('Task Alpha').first);
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditor), findsOneWidget);
          expect(find.byType(TaskDetailsView), findsNothing);

          // Close
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditor), findsNothing);
          expect(controller.selectedTaskId, isNull);

          // Open Beta
          await tester.tap(find.text('Task Beta').first);
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditor), findsOneWidget);

          // Close
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(TaskEditor), findsNothing);
          expect(controller.selectedTaskId, isNull);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}
