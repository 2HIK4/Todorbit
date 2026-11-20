import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/shared/app_modal_shell.dart';
import 'package:life_manager/features/shared/app_spacing.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/app_theme_tokens.dart';
import 'package:life_manager/features/shared/settings_section.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  group('TaskEditor UI Consistency Pilot', () {
    late AppDatabase database;
    late AppController controller;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      controller = AppController(LifeRepository(database));
      await controller.refresh();
      container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    Widget buildTestHarness({
      required Widget child,
      Size size = const Size(600, 900),
      Brightness brightness = Brightness.light,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(
            brightness,
            brightness == Brightness.dark
                ? ThemePalette.dark
                : ThemePalette.light,
          ),
          home: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('TodorbitThemeTokens are registered and accessible via Theme.of', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: Builder(
            builder: (context) {
              final tokens = Theme.of(context).extension<TodorbitThemeTokens>();
              expect(tokens, isNotNull);
              expect(tokens!.priorityHigh, isNotNull);
              expect(tokens.priorityLow, isNotNull);
              expect(tokens.statusCompleted, isNotNull);
              expect(tokens.statusInProgress, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Empty title produces in-place errorText on TextField and clears when text entered', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: const TaskEditor(),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byKey(const ValueKey('task-title-field'));
      expect(titleFinder, findsOneWidget);

      // Verify no error initially
      TextField titleWidget = tester.widget(titleFinder);
      expect(titleWidget.decoration?.errorText, isNull);

      // Attempt to save with empty title
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      // In-place validation error is displayed directly on the field
      titleWidget = tester.widget(titleFinder);
      expect(titleWidget.decoration?.errorText, 'Enter a task title.');

      // Entering text immediately clears the in-place error
      await tester.enterText(titleFinder, 'My Valid Task Title');
      await tester.pumpAndSettle();

      titleWidget = tester.widget(titleFinder);
      expect(titleWidget.decoration?.errorText, isNull);
    });

    testWidgets('AppModalShell constrains modal dialog width and height responsively', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          size: const Size(1000, 800),
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showAppModal<void>(
                  context: context,
                  builder: (ctx) => const Text('Modal Content'),
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byType(AppModalShell), findsOneWidget);
      expect(find.text('Modal Content'), findsOneWidget);

      final sizedBoxFinder = find.descendant(
        of: find.byType(AppModalShell),
        matching: find.byType(SizedBox),
      ).first;
      final modalBox = tester.renderObject<RenderBox>(sizedBoxFinder);
      expect(modalBox.size.width, lessThanOrEqualTo(AppLayout.dialogDefaultWidth + 1));
      expect(modalBox.size.height, lessThanOrEqualTo(AppLayout.dialogDefaultHeight + 1));
    });

    testWidgets('TaskEditor sections use structured SettingsSection cards', (tester) async {
      final task = await controller.repository.addTask(
        const TaskDraft(title: 'Existing Task with Details'),
      );
      await controller.refresh();

      await tester.pumpWidget(
        buildTestHarness(
          child: TaskEditor(task: task),
        ),
      );
      await tester.pumpAndSettle();

      // Structured sections are unified with SettingsSection
      expect(find.byType(SettingsSection), findsWidgets);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Status and priority'), 200, scrollable: scrollable);
      expect(find.text('Status and priority'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Estimates and schedule protection'), 200, scrollable: scrollable);
      expect(find.text('Estimates and schedule protection'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Prerequisites'), 200, scrollable: scrollable);
      expect(find.text('Prerequisites'), findsOneWidget);
    });
  });
}
