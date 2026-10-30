import 'package:life_manager/features/shared/anchored_select_field.dart';

import 'test_privacy.dart';

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
  testWidgets('overlapping calendar events show a conflict indicator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 9);
    await repository.addEvent(
      EventDraft(
        title: 'Lecture',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
      ),
    );
    await repository.addEvent(
      EventDraft(
        title: 'Seminar',
        startsAt: start.add(const Duration(minutes: 30)),
        endsAt: start.add(const Duration(hours: 2)),
      ),
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
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Overlaps 1 other event or work session'),
        findsNWidgets(2),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('calendar content filter changes visible day entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final today = DateTime.now();
    await repository.addTask(
      TaskDraft(title: 'Filtered task', scheduledDate: localDate(today)),
    );
    await repository.addEvent(
      EventDraft(
        title: 'Filtered event',
        startsAt: DateTime(today.year, today.month, today.day, 9),
        endsAt: DateTime(today.year, today.month, today.day, 10),
      ),
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
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Filtered event'), findsOneWidget);
      expect(find.textContaining('Plan · Filtered task'), findsOneWidget);
      await tester.tap(find.text('Events only'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Filtered event'), findsOneWidget);
      expect(find.textContaining('Plan · Filtered task'), findsNothing);
      await tester.tap(find.text('Tasks only'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Filtered event'), findsNothing);
      expect(find.textContaining('Plan · Filtered task'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('calendar creates a fixed event and planned session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    await repository.addTask(const TaskDraft(title: 'Study'));
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
      await tester.tap(find.byType(AnchoredSelectField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save session'));
      await tester.pumpAndSettle();
      expect(
        (await repository.sessions()).single.outcome,
        SessionOutcome.upcoming,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
