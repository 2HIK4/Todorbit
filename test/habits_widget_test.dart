import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('Habits view creates and corrects a daily Yes/No log', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
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
      await tester.tap(find.widgetWithText(ListTile, 'Habits'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('About this view'));
      await tester.pumpAndSettle();
      expect(find.textContaining('rest days without counting a miss'), findsOneWidget);
      await tester.tap(find.byTooltip('About this view'));
      await tester.pumpAndSettle();
      expect(
        find.text('No habits yet. Create one to track daily progress.'),
        findsOneWidget,
      );
      await tester.tap(find.text('New habit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Drink water',
      );
      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();
      expect(find.text('Drink water'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect((await repository.habitEntries()).single.value, 1);
      expect(find.textContaining('Target met'), findsOneWidget);
      await tester.tap(find.text('Not done'));
      await tester.pumpAndSettle();
      expect((await repository.habitEntries()).single.value, 0);
      expect(find.textContaining('Target missed'), findsOneWidget);
      expect(
        (await database
                .customSelect('SELECT COUNT(*) AS n FROM habit_entry_history')
                .getSingle())
            .read<int>('n'),
        2,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
