import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/main.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  testWidgets('draft subtask dialog closes without a disposed spelling field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 500, height: 1100, child: TaskEditor()),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add subtask'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title').last,
        'Research and write the project summary',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Research and write the project summary'),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('task details add a checklist item and a real subtask', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final parent = await repository.addTask(const TaskDraft(title: 'Course'));
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
      await tester.tap(find.widgetWithText(ListTile, 'All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Course'));
      await tester.pumpAndSettle();
      final checklist = find.widgetWithText(TextField, 'New checklist item');
      final editorScroll = find
          .descendant(
            of: find.byType(TaskEditor),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(checklist, 180, scrollable: editorScroll);
      await tester.enterText(checklist, 'Watch lesson 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        (await repository.checklistItems()).single.title,
        'Watch lesson 1',
      );
      final addSubtask = find.text('Add subtask');
      await tester.scrollUntilVisible(
        addSubtask,
        180,
        scrollable: editorScroll,
      );
      await tester.tap(addSubtask);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *').last,
        'Build project',
      );
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      final children = await repository.taskParents();
      expect(children.values, contains(parent.id));
      expect((await repository.tasks()), hasLength(2));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
