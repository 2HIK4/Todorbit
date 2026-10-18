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
import 'package:life_manager/features/scheduling/smart_reschedule.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('Smart Reschedule asks before same-series date collision', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    try {
      final selected = await repository.addRecurringTask(
        const TaskDraft(title: 'Review', scheduledDate: '2026-10-19'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 2,
        ),
      );
      await repository.ensureRecurringTasks('2026-10-19', '2026-10-20');
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
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => SmartRescheduleDialog(
                      scope: 'test',
                      taskIds: [selected.id],
                    ),
                  ),
                  child: const Text('Open scheduler'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open scheduler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shift').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate preview'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Recurring collision on 2026-10-20'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.textContaining('Recurring collision on 2026-10-20'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep both occurrences').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(
        (await repository.tasks()).where(
          (item) => item.scheduledDate == '2026-10-20',
        ),
        hasLength(2),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('Smart Reschedule preview is non-mutating and Apply persists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    await repository.addTask(
      const TaskDraft(title: 'Plan chapter', scheduledDate: '2026-10-19'),
    );
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
      await tester.tap(find.widgetWithText(ListTile, 'All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reschedule'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Reschedule'), findsOneWidget);

      await tester.tap(find.text('Move').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shift').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate preview'));
      await tester.pumpAndSettle();

      expect((await repository.tasks()).single.scheduledDate, '2026-10-19');
      expect(find.textContaining('2026-10-19'), findsWidgets);
      expect(find.textContaining('2026-10-20'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect((await repository.tasks()).single.scheduledDate, '2026-10-20');
      expect(
        (await repository.schedulingHistory()).single.changes,
        hasLength(1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
