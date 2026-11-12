import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/workspace/series_editor.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('view information opens and closes from its icon', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
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
      final info = find.byKey(const ValueKey('view-info-button'));
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.textContaining('Tasks planned for today'), findsOneWidget);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.textContaining('Tasks planned for today'), findsNothing);
      await tester.tap(info);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tasks planned for today'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
    'series editor previews collisions before changing shared fields',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final controller = AppController(repository);
      try {
        final selected = await repository.addRecurringTask(
          const TaskDraft(title: 'Original', scheduledDate: '2026-10-19'),
          RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2026-10-19',
            maxOccurrences: 3,
          ),
        );
        await repository.ensureRecurringTasks('2026-10-19', '2026-10-21');
        await controller.refresh();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => SeriesEditorDialog(selected: selected),
                    ),
                    child: const Text('Open series editor'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open series editor'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Shared title'),
          'Revised',
        );
        await tester.tap(find.text('Generate preview'));
        await tester.pumpAndSettle();
        final dialogList = find.descendant(
          of: find.byType(SeriesEditorDialog),
          matching: find.byType(ListView),
        );
        await tester.scrollUntilVisible(
          find.text('Combine compatible'),
          200,
          scrollable: find
              .descendant(of: dialogList, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('collisions'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Apply series edit'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Combine compatible'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply series edit'));
        await tester.pumpAndSettle();
        expect(
          (await repository.tasks())
              .where((task) => task.id == selected.id)
              .single
              .title,
          'Revised',
        );
        expect(
          (await database
                  .customSelect('SELECT COUNT(*) AS n FROM series_edit_history')
                  .getSingle())
              .read<int>('n'),
          1,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('creates a recurring task from the task editor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
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
          child: const LifeManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Daily reading',
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      final editorScroll = find
          .descendant(
            of: find.byType(TaskEditor),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Does not repeat'),
        200,
        scrollable: editorScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Does not repeat').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      final tasks = await repository.tasks();
      expect(
        tasks.where((task) => task.recurrenceSeriesId != null),
        isNotEmpty,
      );
      expect(
        tasks.where((task) => task.title == 'Daily reading').length,
        greaterThan(1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('creates a task from the Today workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
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
      expect(find.text('Today'), findsWidgets);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Read chapter',
      );
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      expect(find.text('Read chapter'), findsWidgets);
      expect(
        (await LifeRepository(database).tasks()).single.title,
        'Read chapter',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('invalid duration is rejected instead of silently cleared', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
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
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title *'), 'Read');
      await tester.scrollUntilVisible(
        find.text('Estimates and schedule protection'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(TaskEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Estimates and schedule protection'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Planned minutes'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(TaskEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Planned minutes'),
        'abc',
      );
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      expect(await LifeRepository(database).tasks(), isEmpty);
      expect(find.textContaining('Planned minutes must be'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('narrow editor keeps unsaved fields after saving prerequisites', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final prerequisite = await repository.addTask(
      const TaskDraft(title: 'Prerequisite'),
    );
    final dependent = await repository.addTask(
      const TaskDraft(title: 'Dependent'),
    );
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
      await tester.tap(find.text('Dependent').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Edited dependent',
      );
      await tester.scrollUntilVisible(
        find.text('Prerequisites'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(TaskEditor),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Prerequisites').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Prerequisites'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Prerequisite').last),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prerequisite').last);
      await Scrollable.ensureVisible(
        tester.element(find.text('Save prerequisites')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save prerequisites'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        (await repository.tasks())
            .firstWhere((task) => task.id == dependent.id)
            .title,
        'Edited dependent',
      );
      expect(
        (await repository.dependencies()).single.prerequisiteId,
        prerequisite.id,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('Quick Search finds task notes and opens the real task', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final task = await repository.addTask(
      const TaskDraft(title: 'Read stars', notes: 'astronomy chapter'),
    );
    final controller = AppController(repository);
    await controller.refresh();
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
      await tester.tap(find.byTooltip('Quick Search (Ctrl+K)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Search tasks, events, categories, and projects',
        ),
        'astronomy',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read stars').last);
      await tester.pumpAndSettle();
      expect(controller.view, WorkspaceView.all);
      expect(controller.selectedTaskId, task.id);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(
          TextField,
          'Search tasks, events, categories, and projects',
        ),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
    'TaskEditor saves via Ctrl+S / Ctrl+Enter and closes cleanly via Escape',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
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
            child: const LifeManagerApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open new task editor
        await tester.tap(find.text('New task'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);

        // Verify date row and save button tooltips
        expect(find.byTooltip('Change Scheduled day'), findsOneWidget);
        expect(find.byTooltip('Set Deadline'), findsOneWidget);
        expect(
          find.byTooltip('Create task (Ctrl+S, Ctrl+Enter)'),
          findsOneWidget,
        );

        // Enter title and save with Ctrl+S
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Shortcut Task 1',
        );
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        // Task is persisted and selected task details view is open
        final tasksAfterCtrlS = await repository.tasks();
        expect(
          tasksAfterCtrlS.any((t) => t.title == 'Shortcut Task 1'),
          isTrue,
        );
        expect(find.text('Task details'), findsOneWidget);
        expect(
          find.byTooltip('Save changes (Ctrl+S, Ctrl+Enter)'),
          findsOneWidget,
        );

        // Escape closes the selected task editor pane
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsNothing);

        // 2. Open another task and save via Ctrl+Enter
        await tester.tap(find.text('New task'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Shortcut Task 2',
        );
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        final tasksAfterCtrlEnter = await repository.tasks();
        expect(
          tasksAfterCtrlEnter.any((t) => t.title == 'Shortcut Task 2'),
          isTrue,
        );
        expect(find.text('Task details'), findsOneWidget);

        // Escape closes the editor pane again
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
