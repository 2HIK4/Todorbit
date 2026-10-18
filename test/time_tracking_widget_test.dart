import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/features/time_tracking/time_tracking_dialog.dart';

void main() {
  testWidgets('actual work dialog starts, pauses, and logs manual work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final task = await repository.addTask(const TaskDraft(title: 'Write'));
    final controller = AppController(repository);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(body: TimeTrackingDialog(taskId: task.id)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start timer'));
      await tester.pumpAndSettle();
      expect((await repository.activeTimerRun())?.state, TimerState.running);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect((await repository.activeTimerRun())?.state, TimerState.paused);
      await tester.tap(find.text('Add manual time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save work log'));
      await tester.pumpAndSettle();
      expect((await repository.timeEntries(taskId: task.id)), hasLength(2));
      expect(find.textContaining('overlaps counted once'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
