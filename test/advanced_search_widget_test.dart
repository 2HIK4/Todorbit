import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';

void main() {
  testWidgets('advanced filters preview results and save a live view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 850));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    await repository.addTask(const TaskDraft(title: 'Write chapter'));
    await repository.addTask(const TaskDraft(title: 'Pay invoice'));
    final controller = AppController(repository);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AdvancedSearchDialog(),
                  ),
                  child: const Text('Open search'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Words in title, notes, category, or project',
        ),
        'chapter',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 matching tasks'), findsOneWidget);
      await tester.tap(find.text('Save as view'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'View name'),
        'Writing',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save view'));
      await tester.pumpAndSettle();
      expect(controller.savedViews.single.name, 'Writing');
      expect(controller.view, WorkspaceView.saved);
      expect(controller.visibleTasks.single.title, 'Write chapter');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
