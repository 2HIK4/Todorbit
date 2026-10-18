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

void main() {
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
      await tester.ensureVisible(checklist);
      await tester.enterText(checklist, 'Watch lesson 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        (await repository.checklistItems()).single.title,
        'Watch lesson 1',
      );
      final addSubtask = find.text('Add subtask');
      await tester.ensureVisible(addSubtask);
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
