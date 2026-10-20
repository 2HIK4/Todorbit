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
        final dialogScroll = find
            .descendant(
              of: find.byType(SeriesEditorDialog),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Combine compatible'),
          200,
          scrollable: dialogScroll,
        );
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
      await tester.tap(find.textContaining('Scheduled day:').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Does not repeat'));
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
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Estimates and schedule protection'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Planned minutes'),
        220,
        scrollable: find.byType(Scrollable).last,
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
          'Search tasks, categories, and projects',
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
          'Search tasks, categories, and projects',
        ),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
