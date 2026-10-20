import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/shared/icon_picker.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  test('all registered icon choices have unique keys and known fallbacks', () {
    expect(builtInIcons.length, greaterThan(20));
    for (final entry in builtInIcons.entries) {
      expect(entry.value.fontFamily, 'MaterialIcons', reason: entry.key);
      expect(entry.value.codePoint, greaterThan(0), reason: entry.key);
      expect(iconForKey(entry.key, Icons.error), entry.value);
    }
    expect(
      iconForKey('retired-icon', Icons.task_alt_outlined),
      Icons.task_alt_outlined,
    );
  });

  testWidgets(
    'task editor keeps unsaved fields while creating category and project',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 850));
      final db = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(db));
      await controller.refresh();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(width: 500, height: 760, child: TaskEditor()),
                ),
              ),
            ),
          ),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Keep this title',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Notes'),
          'Draft notes',
        );
        await tester.ensureVisible(
          find.widgetWithText(DropdownButtonFormField<String?>, 'Category'),
        );
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String?>, 'Category'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('+ New Category').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'category name'),
          'Study',
        );
        await tester.tap(find.text('Create').last);
        await tester.pumpAndSettle();
        expect(controller.categories.single.name, 'Study');
        await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.widgetWithText(TextField, 'Title *')).dy,
          greaterThan(tester.getBottomLeft(find.text('New task')).dy),
        );
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Title *'))
              .controller!
              .text,
          'Keep this title',
        );
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
              .controller!
              .text,
          'Draft notes',
        );
        await tester.ensureVisible(
          find.widgetWithText(DropdownButtonFormField<String?>, 'Project'),
        );
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String?>, 'Project'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('+ New Project').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'project name'),
          'Flutter',
        );
        await tester.tap(find.text('Create').last);
        await tester.pumpAndSettle();
        expect(controller.projects.single.name, 'Flutter');
        await tester.tap(find.text('Create task'));
        await tester.pumpAndSettle();
        expect(controller.tasks.single.title, 'Keep this title');
        expect(controller.tasks.single.notes, 'Draft notes');
        expect(
          controller.tasks.single.categoryId,
          controller.categories.single.id,
        );
        expect(
          controller.tasks.single.projectId,
          controller.projects.single.id,
        );
        expect(controller.tasks.single.scheduledDate, localDate(DateTime.now()));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('existing task title stays below header in narrow editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 560));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final task = await repo.addTask(const TaskDraft(title: 'Existing task'));
    final controller = AppController(repo);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 520,
                child: TaskEditor(task: task),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.widgetWithText(TextField, 'Title *')).dy,
        greaterThan(tester.getBottomLeft(find.text('Task details')).dy),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
