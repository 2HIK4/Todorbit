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
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
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
