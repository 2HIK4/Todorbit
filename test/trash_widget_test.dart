import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/workspace/trash_dialog.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('Archive and Trash dialog restores real records', (tester) async {
    await tester.binding.setSurfaceSize(const Size(960, 720));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    try {
      final archived = await repository.addTask(
        const TaskDraft(title: 'Archived work'),
      );
      final deleted = await repository.addTask(
        const TaskDraft(title: 'Deleted work'),
      );
      await repository.archiveTask(archived);
      await repository.deleteTask(deleted.id);
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
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ArchiveTrashDialog(),
                  ),
                  child: const Text('Open Archive and Trash'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Archive and Trash'));
      await tester.pumpAndSettle();
      expect(find.text('Archived work'), findsOneWidget);
      await tester.tap(find.text('Restore').first);
      await tester.pumpAndSettle();
      expect(
        (await repository.tasks()).map((task) => task.id),
        contains(archived.id),
      );
      await tester.tap(find.text('Trash').last);
      await tester.pumpAndSettle();
      expect(find.text('Deleted work'), findsOneWidget);
      await tester.tap(find.text('Restore').last);
      await tester.pumpAndSettle();
      expect(
        (await repository.tasks()).map((task) => task.id),
        contains(deleted.id),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('task menu archives an entire recurring series and restores it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    try {
      final task = await repository.addRecurringTask(
        const TaskDraft(title: 'One day routine', scheduledDate: '2026-10-18'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-18',
          maxOccurrences: 1,
        ),
      );
      await controller.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.tap(find.text('All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Task actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive entire series'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive series'));
      await tester.pumpAndSettle();
      expect(await repository.tasks(), isEmpty);
      await tester.tap(find.byTooltip('Archive and Trash'));
      await tester.pumpAndSettle();
      expect(find.text('One day routine'), findsOneWidget);
      await tester.tap(find.text('Restore').first);
      await tester.pumpAndSettle();
      expect((await repository.tasks()).single.id, task.id);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
