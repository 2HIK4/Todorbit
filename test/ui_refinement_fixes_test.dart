import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/habits/habits_view.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/app_theme_tokens.dart';
import 'package:life_manager/features/workspace/task_details_view.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets(
    'TaskDetailsView uses theme primary & priority tokens and scrollable manual-time modal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = AppController(LifeRepository(database));
      final task = await controller.repository.addTask(
        const TaskDraft(title: 'Focus Candidate', priority: 3),
      );
      await controller.refresh();

      final theme = buildAppTheme(Brightness.dark, ThemePalette.dark);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                viewInsets: EdgeInsets.only(bottom: 220),
              ),
              child: TaskDetailsView(
                task: task,
                onBack: () {},
                onStartFocus: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure legacy #8B5CF6 purple is not used on Start Focus Session.
      final focusButton = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Start Focus Session'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      final resolvedBg =
          focusButton.style?.backgroundColor?.resolve({}) ??
          theme.colorScheme.primary;
      expect(resolvedBg, isNot(const Color(0xFF8B5CF6)));
      expect(resolvedBg, theme.colorScheme.primary);

      // Priority badge icon uses TodorbitThemeTokens.priorityHigh.
      final badgeIcon = tester.widget<Icon>(find.byIcon(Icons.flag));
      expect(badgeIcon.color, TodorbitThemeTokens.dark().priorityHigh);

      // Expand Work Log and open Add manual work time modal under 220px keyboard inset.
      await tester.scrollUntilVisible(
        find.text('Work Log'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Work Log'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add manual time'));
      await tester.tap(find.text('Add manual time'));
      await tester.pumpAndSettle();
      expect(find.text('Add manual work time'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes (optional)'),
        'Manual review session',
      );
      expect(find.text('Save').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final entries = await controller.repository.timeEntries();
      expect(entries, hasLength(1));
      expect(entries.single.notes, 'Manual review session');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Desktop workspace renders sidebar footer divider and priority token flags on subtasks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = AppController(LifeRepository(database));
      final today = localDate(DateTime.now());
      final parent = await controller.repository.addTask(
        TaskDraft(title: 'Parent work item', scheduledDate: today),
      );
      await controller.repository.addSubtask(
        parent,
        TaskDraft(
          title: 'Urgent child item',
          priority: 3,
          scheduledDate: today,
        ),
      );
      await controller.refresh();

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

      expect(find.byType(Divider), findsWidgets);
      final highFlag = tester.widget<Icon>(find.byIcon(Icons.flag).first);
      expect(highFlag.color, TodorbitThemeTokens.light().priorityHigh);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('HabitsView Clear log confirmation uses error accent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final controller = AppController(LifeRepository(database));
    final habit = await controller.repository.addHabit(
      HabitDraft(
        title: 'Stretch',
        kind: HabitKind.binary,
        rule: RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: localDate(DateTime.now()),
        ),
      ),
    );
    await controller.recordHabitDay(habit, localDate(DateTime.now()), 1);
    await controller.refresh();

    final theme = buildAppTheme(Brightness.light, ThemePalette.light);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(body: HabitsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear log'));
    await tester.pumpAndSettle();
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clear log'),
    );
    expect(
      confirmButton.style?.backgroundColor?.resolve({}),
      theme.colorScheme.error,
    );
  });

  testWidgets(
    'CalendarWeekView overlapping narrow cards show readable start time without range truncation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1050, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = AppController(LifeRepository(database));
      final now = DateTime.now();
      await controller.repository.addEvent(
        EventDraft(
          title: 'Design Sync Alpha',
          startsAt: DateTime(now.year, now.month, now.day, 9, 15),
          endsAt: DateTime(now.year, now.month, now.day, 10, 45),
        ),
      );
      await controller.repository.addEvent(
        EventDraft(
          title: 'Design Sync Beta',
          startsAt: DateTime(now.year, now.month, now.day, 9, 30),
          endsAt: DateTime(now.year, now.month, now.day, 11, 0),
        ),
      );
      await controller.refresh();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark, ThemePalette.dark),
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9:15 AM'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);
      expect(find.textContaining('9:15 AM –'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'Design Sync Alpha, 9:15 AM – 10:45 AM')),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Design Sync Alpha\n9:15 AM – 10:45 AM'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
