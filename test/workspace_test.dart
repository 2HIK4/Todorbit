import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('creates a task from the Today workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
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
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const LifeManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title *'), 'Read');
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
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
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
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
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
        find.widgetWithText(TextField, 'Search tasks, categories, and projects'),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
