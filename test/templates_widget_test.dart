import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/templates/templates_dialog.dart';

void main() {
  testWidgets('saved task template can be applied from the manager', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final source = await repository.addTask(const TaskDraft(title: 'Write'));
    await repository.saveTaskTemplate(source, 'Writing setup');
    final controller = AppController(repository);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: TemplatesDialog())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Writing setup'), findsOneWidget);
      await tester.tap(find.text('Writing setup'));
      await tester.pumpAndSettle();
      expect(find.text('Apply Writing setup'), findsOneWidget);
      await tester.tap(find.text('Create from template'));
      await tester.pumpAndSettle();
      expect((await repository.tasks()), hasLength(2));
      expect(controller.selectedTaskId, isNot(source.id));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('project template asks for category before creating', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final category = await repository.addCategory('Work');
    final source = await repository.addProject(category.id, 'Plan');
    await repository.addTask(
      TaskDraft(title: 'Step', categoryId: category.id, projectId: source.id),
    );
    await repository.saveProjectTemplate(source, 'Plan recipe');
    final controller = AppController(repository);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: TemplatesDialog())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan recipe'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create from template'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('template-category:null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New project name *'),
        'Plan again',
      );
      await tester.tap(find.text('Create from template'));
      await tester.pumpAndSettle();
      final copy = (await repository.projects()).singleWhere(
        (project) => project.name == 'Plan again',
      );
      expect(
        (await repository.tasks()).where((task) => task.projectId == copy.id),
        hasLength(1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
