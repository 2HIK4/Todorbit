import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('task row starts timer directly without changing task status', (
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
      await tester.tap(find.byTooltip('Start task timer'));
      await tester.pumpAndSettle();
      expect((await repository.tasks()).single.status, TaskStatus.notStarted);
      expect((await repository.activeTimerRun())?.taskId, task.id);
      expect(find.text('Stopwatch'), findsOneWidget);
      expect(find.byTooltip('Return to tasks'), findsOneWidget);
      await tester.tap(find.byTooltip('Return to tasks'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open task timer'), findsOneWidget);
      expect(find.byTooltip('Timer controls'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Timer controls'), findsOneWidget);
      await tester.tap(find.byTooltip('Timer controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause').last);
      await tester.pumpAndSettle();
      expect((await repository.activeTimerRun())?.state, TimerState.paused);
      expect(find.textContaining('Paused'), findsWidgets);
      await tester.tap(find.byTooltip('Timer controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume').last);
      await tester.pumpAndSettle();
      expect((await repository.activeTimerRun())?.state, TimerState.running);
      await tester.tap(find.byTooltip('Timer controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop').last);
      await tester.pumpAndSettle();
      expect(await repository.activeTimerRun(), isNull);
      expect((await repository.tasks()).single.status, TaskStatus.notStarted);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
