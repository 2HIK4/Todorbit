import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/features/time_tracking/focus_workspace.dart';

void main() {
  testWidgets('selecting bounded mode pauses recorded work until Start', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final task = await repo.addTask(const TaskDraft(title: 'Focus test'));
    final c = AppController(repo);
    await c.refresh();
    await c.startFocusTask(task);
    await tester.binding.setSurfaceSize(const Size(900, 900));
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => c)],
          child: MaterialApp(
            home: FocusWorkspace(taskId: task.id, onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Countdown'));
      await tester.pumpAndSettle();
      expect(c.activeTimer?.state, TimerState.paused);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(c.activeTimer?.state, TimerState.running);
      await tester.tap(find.byTooltip('Reset timer'));
      await tester.pumpAndSettle();
      expect(c.activeTimer?.state, TimerState.paused);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
  testWidgets('interrupted Focus exposes checkpoint recovery', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final task = await repo.addTask(const TaskDraft(title: 'Interrupted'));
    await repo.startTimer(task.id);
    await db.customStatement(
      "UPDATE timer_runs SET last_seen_at='2020-01-01T00:00:00.000Z'",
    );
    final c = AppController(repo);
    await c.refresh();
    await tester.binding.setSurfaceSize(const Size(900, 900));
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => c)],
          child: MaterialApp(
            home: FocusWorkspace(taskId: task.id, onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Timer needs review.'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
