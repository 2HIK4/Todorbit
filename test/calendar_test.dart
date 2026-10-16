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
  testWidgets('calendar creates a fixed event and planned session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    await repository.addTask(const TaskDraft(title: 'Study'));
    final controller = AppController(repository);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const LifeManagerApp(),
        ),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Seminar',
      );
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect((await repository.events()).single.title, 'Seminar');
      await tester.tap(find.text('Work session'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save session'));
      await tester.pumpAndSettle();
      expect((await repository.sessions()).single.outcome, SessionOutcome.upcoming);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
