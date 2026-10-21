import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  testWidgets(
    'scheduled day and deadline adapt and planned day can be cleared',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final controller = AppController(repository);
      await controller.refresh();
      try {
        for (final width in [740.0, 380.0]) {
          await tester.binding.setSurfaceSize(Size(width, 700));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith((ref) => controller),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: width,
                    height: 640,
                    child: const TaskEditor(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final planned = tester.getTopLeft(find.text('Scheduled day'));
          final deadline = tester.getTopLeft(find.text('Deadline').first);
          if (width > 600) {
            expect((planned.dy - deadline.dy).abs(), lessThan(3));
          } else {
            expect(deadline.dy, greaterThan(planned.dy));
          }
          expect(find.byTooltip('Clear Scheduled day'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byTooltip('Clear Scheduled day'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Clear Scheduled day'), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Unscheduled from editor',
        );
        await tester.tap(find.text('Create task'));
        await tester.pumpAndSettle();
        final tasks = await repository.tasks();
        expect(tasks.single.scheduledDate, isNull);
        expect(tasks.single.deadlineDate, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
