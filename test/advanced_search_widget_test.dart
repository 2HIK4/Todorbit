import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/saved_views.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';

void main() {
  testWidgets(
    'create saved view with zero matches, cancel, and restore focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(920, 760));
      final database = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(database));
      final triggerFocus = FocusNode();
      await controller.refresh();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    autofocus: true,
                    focusNode: triggerFocus,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const AdvancedSearchDialog(creatingSavedView: true),
                    ),
                    child: const Text('New saved view'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('New saved view'));
        await tester.pumpAndSettle();
        expect(find.text('Create Custom View'), findsNWidgets(2));
        expect(find.text('0 matching tasks'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'View name *'),
          'Empty plan',
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(controller.savedViews, isEmpty);
        expect(find.text('New saved view'), findsOneWidget);
        expect(triggerFocus.hasFocus, isTrue);
        await tester.tap(find.text('New saved view'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'View name *'),
          'Empty plan',
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Create Custom View'),
        );
        await tester.pumpAndSettle();
        expect(controller.savedViews.single.name, 'Empty plan');
        expect(controller.view, WorkspaceView.saved);
        expect(controller.visibleTasks, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        triggerFocus.dispose();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('Reset clears inherited filters and keeps the custom view icon', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = LifeRepository(database);
    await repository.addTask(
      const TaskDraft(title: 'Existing task', scheduledDate: '2089-12-31'),
    );
    final saved = await repository.addSavedView(
      'Future plan',
      const TaskFilter(
        fromDate: '2090-01-01',
        throughDate: '2090-01-07',
        nonRecurringOnly: true,
        iconKey: 'star',
      ),
    );
    final controller = AppController(repository);
    await controller.refresh();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AdvancedSearchDialog(savedView: saved),
                ),
                child: const Text('Edit saved view'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit saved view'));
    await tester.pumpAndSettle();
    expect(find.text('0 matching tasks'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('1 matching tasks'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
    expect(controller.savedViews.single.filter.fromDate, '2090-01-01');
    await tester.tap(find.widgetWithText(FilledButton, 'Update Custom View'));
    await tester.pumpAndSettle();
    final updated = controller.savedViews.single.filter;
    expect(updated.isActive, isFalse);
    expect(updated.iconKey, 'star');
    expect(tester.takeException(), isNull);
  });

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
        find.widgetWithText(TextField, 'Search tasks'),
        'chapter',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 matching tasks'), findsOneWidget);
      await tester.tap(find.text('Save as Custom View'));
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
