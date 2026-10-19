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
import 'package:life_manager/main.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  testWidgets(
    'calendar shows the assigned study activity and editor can change future steps',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final today = localDate(DateTime.now());
      final task = await repo.addRecurringTask(
        TaskDraft(title: 'Programming course', scheduledDate: today),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: today,
          maxOccurrences: 2,
        ),
        progressiveSteps: ['Watch lessons', 'Revise lessons'],
      );
      final controller = AppController(repo);
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
        await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Current step: Watch lessons'),
          findsOneWidget,
        );
        await tester.tap(find.textContaining('Current step: Watch lessons'));
        await tester.pumpAndSettle();
        final editorScroll = find
            .descendant(
              of: find.byType(TaskEditor),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Edit recurring task plan'),
          250,
          scrollable: editorScroll,
        );
        await tester.drag(editorScroll, const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(find.text('Current step: Watch lessons'), findsOneWidget);
        await tester.tap(find.text('Edit recurring task plan'));
        await tester.pumpAndSettle();
        expect(find.text('Recurring task plan'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Ordered activities'),
          'Watch lessons\nPractice project',
        );
        await tester.tap(find.text('Save plan'));
        await tester.pumpAndSettle();
        expect((await repo.progressivePlan(task.id))?.steps, [
          'Watch lessons',
          'Practice project',
        ]);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
