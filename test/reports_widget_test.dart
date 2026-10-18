import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/reports/reports_view.dart';

void main() {
  testWidgets('reports show persisted completion and change date span', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1150, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    try {
      final task = await repository.addTask(
        const TaskDraft(title: 'Report task'),
      );
      await repository.setComplete(task, true);
      await controller.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: ReportsView())),
        ),
      );
      expect(find.text('Statistics and reports'), findsOneWidget);
      expect(find.text('Completed tasks'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      await tester.tap(find.text('Last 30 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 7 days').last);
      await tester.pumpAndSettle();
      expect(find.text('Last 7 days'), findsOneWidget);
      expect((await repository.tasks()).single.id, task.id);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
