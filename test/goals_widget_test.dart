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
  testWidgets('Goals view creates a goal and records manual progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
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
      await tester.tap(find.widgetWithText(ListTile, 'Goals'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('About this view'));
      await tester.pumpAndSettle();
      expect(find.textContaining('milestones and a deadline'), findsOneWidget);
      await tester.tap(find.byTooltip('About this view'));
      await tester.pumpAndSettle();
      expect(
        find.text('No goals yet. Create one to track progress.'),
        findsOneWidget,
      );
      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Finish book',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Target *'), '10');
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();
      expect(find.text('Finish book'), findsOneWidget);
      await tester.tap(find.text('Adjust progress'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Adjustment (units)'),
        '3',
      );
      await tester.tap(find.text('Save adjustment'));
      await tester.pumpAndSettle();
      expect((await repository.goals()).single.progress.manual, 3);
      expect(find.textContaining('3.0 / 10.0'), findsOneWidget);
      await tester.tap(find.text('Add milestone'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Halfway',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Progress threshold (max 10.0)'),
        '5',
      );
      await tester.tap(find.text('Add milestone').last);
      await tester.pumpAndSettle();
      expect((await repository.goalMilestones()).single.title, 'Halfway');
      expect(find.text('Halfway'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit milestone'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Progress threshold (max 10.0)'),
        '6',
      );
      await tester.tap(find.text('Save milestone'));
      await tester.pumpAndSettle();
      expect((await repository.goalMilestones()).single.threshold, 6);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('linked task completion updates a goal once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 850));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final task = await repository.addTask(const TaskDraft(title: 'Write'));
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
      await tester.tap(find.widgetWithText(ListTile, 'Goals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New goal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Write goal',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Target *'), '2');
      await tester.tap(find.text('Create goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link work'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Write'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save links'));
      await tester.pumpAndSettle();
      await repository.setComplete(task, true);
      await controller.refresh();
      await tester.pumpAndSettle();
      expect((await repository.goals()).single.progress.tasks, 1);
      expect(find.textContaining('tasks 1.0'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
