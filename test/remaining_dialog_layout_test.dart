import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/goals/goal_dialogs.dart';
import 'package:life_manager/features/habits/habit_editor.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';

void main() {
  testWidgets('new and edit Habit and Goal forms keep controls reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 600));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final controller = AppController(repo);
    final habit = await repo.addHabit(
      HabitDraft(
        title: 'Audit habit',
        kind: HabitKind.binary,
        rule: RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-23',
        ),
      ),
    );
    final goal = await repo.addGoal(
      const GoalDraft(title: 'Audit goal', target: 12, startDate: '2026-10-23'),
    );
    await controller.refresh();
    Future<void> show(Widget dialog) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(body: Center(child: dialog)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    try {
      for (final item in <Habit?>[null, habit]) {
        await show(HabitEditorDialog(key: ValueKey(item?.id), habit: item));
        final list = find.byKey(const ValueKey('habit-editor-form-list'));
        final title = find.byKey(const ValueKey('habit-editor-title'));
        expect(
          tester.getRect(title).right,
          lessThan(tester.getRect(list).right - 8),
        );
        await tester.scrollUntilVisible(
          find.text('End day: None'),
          100,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('End day: None')).bottom,
          lessThan(tester.getRect(list).bottom),
        );
        expect(tester.takeException(), isNull);
      }
      for (final item in <Goal?>[null, goal]) {
        await show(GoalEditorDialog(key: ValueKey(item?.id), goal: item));
        final list = find.byKey(const ValueKey('goal-editor-form-list'));
        final title = find.byKey(const ValueKey('goal-editor-title'));
        expect(
          tester.getRect(title).right,
          lessThan(tester.getRect(list).right - 8),
        );
        await tester.scrollUntilVisible(
          find.textContaining('Deadline:'),
          100,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.textContaining('Deadline:')).bottom,
          lessThan(tester.getRect(list).bottom),
        );
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('Advanced Search select fields reserve floating-label gaps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    final db = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(db));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const Scaffold(body: Center(child: AdvancedSearchDialog())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final category = find.widgetWithText(
        AnchoredSelectField<String?>,
        'Any category',
      );
      final priority = find.widgetWithText(
        AnchoredSelectField<int>,
        'Any priority',
      );
      expect(
        tester.getRect(priority).top - tester.getRect(category).bottom,
        greaterThanOrEqualTo(10),
      );
      await tester.binding.setSurfaceSize(const Size(430, 620));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sort results by'),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('advanced-search-form-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
