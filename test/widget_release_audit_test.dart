import 'dart:async';

import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/notifications.dart';
import 'package:life_manager/domain/navigation_request.dart';
import 'package:life_manager/main.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

class GatedController extends AppController {
  GatedController(super.repository);
  Completer<void>? gate;
  @override
  Future<void> refresh() async {
    await gate?.future;
    await super.refresh();
  }
}

void main() {
  testWidgets(
    'navigation rechecks editing after asynchronous startup refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final task = await repo.addTask(
        const TaskDraft(title: 'Navigation target'),
      );
      final controller = GatedController(repo);
      await controller.refresh();
      final gate = Completer<void>();
      controller.gate = gate;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((_) => controller),
              privacyOverride,
            ],
            child: LifeManagerApp(
              initialNavigation: NavigationRequest(
                kind: 'task',
                id: task.id,
              ).encode(),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('New task'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('task-title-field')),
          'Keep this new draft',
        );
        gate.complete();
        controller.gate = null;
        await tester.pumpAndSettle();
        expect(controller.selectedTask, isNull);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('task-title-field')))
              .controller!
              .text,
          'Keep this new draft',
        );
        expect(
          find.text(
            'Widget item waiting. Finish the current editor or dialog to open it.',
          ),
          findsOneWidget,
        );
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  for (final mode in ['custom', 'session']) {
    testWidgets('unchanged $mode reminder does not block editing an old task', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final reminder = TaskNotification(
        mode: mode,
        at: mode == 'custom' ? DateTime.utc(2020) : null,
      );
      final task = await repo.addTask(
        TaskDraft(title: 'Existing task', notification: reminder),
      );
      final controller = AppController(repo);
      await controller.refresh();
      var saved = false;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((_) => controller)],
            child: MaterialApp(
              home: Scaffold(
                body: TaskEditor(task: task, onSaved: () => saved = true),
              ),
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey('task-title-field')),
          'Edited without rescheduling reminder',
        );
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(saved, true);
        expect(
          (await repo.tasks()).single.title,
          'Edited without rescheduling reminder',
        );
        expect(
          (await repo.tasks()).single.notification.toJson(),
          reminder.toJson(),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  }
}
