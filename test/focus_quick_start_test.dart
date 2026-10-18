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
  testWidgets('task row starts work and a focus timer without completion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 850));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final task = await repository.addTask(const TaskDraft(title: 'Study now'));
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
      await tester.tap(find.byTooltip('Start task or focus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Task'));
      await tester.pumpAndSettle();
      expect((await repository.tasks()).single.status, TaskStatus.inProgress);
      expect(await repository.timeEntries(taskId: task.id), isEmpty);

      await tester.tap(find.byTooltip('Work or focus actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Focus Session'));
      await tester.pumpAndSettle();
      expect((await repository.activeTimerRun())?.taskId, task.id);
      expect(find.text('Current focus session'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(await repository.activeTimerRun(), isNull);
      expect((await repository.tasks()).single.status, TaskStatus.inProgress);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
