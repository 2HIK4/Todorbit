import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/navigation_request.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets(
    'cold activation opens the selected task editor after initialization',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      final task = await repo.addTask(
        const TaskDraft(title: 'Exact widget target'),
      );
      await controller.refresh();
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
        await tester.pumpAndSettle();
        expect(controller.selectedTask?.id, task.id);
        expect(
          tester.widget<TaskEditor>(find.byType(TaskEditor)).task!.id,
          task.id,
        );
        expect(find.text('Scheduled item'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
  testWidgets('cold event activation opens the actual event editor and date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final controller = AppController(repo);
    final day = DateTime(2026, 10, 28);
    final event = await repo.addEvent(
      EventDraft(
        title: 'Exact event',
        startsAt: day.add(const Duration(hours: 12)),
        endsAt: day.add(const Duration(hours: 13)),
      ),
    );
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((_) => controller),
            privacyOverride,
          ],
          child: LifeManagerApp(
            initialNavigation: NavigationRequest(
              kind: 'event',
              id: event.id,
              day: '2026-10-28',
            ).encode(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.view, WorkspaceView.calendar);
      final editor = tester.widget<EventEditor>(find.byType(EventEditor));
      expect(editor.event!.id, event.id);
      expect(editor.initialDay, day);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
