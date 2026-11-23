import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/shared/app_task_row.dart';
import 'package:life_manager/features/shared/app_theme_tokens.dart';

void main() {
  LifeTask createTask({
    String id = 'task-1',
    String title = 'Sample Task Title',
    String notes = '',
    TaskStatus status = TaskStatus.notStarted,
    int priority = 0,
    String? scheduledDate,
    String? deadlineDate,
  }) {
    return LifeTask(
      id: id,
      title: title,
      notes: notes,
      status: status,
      priority: priority,
      scheduledDate: scheduledDate,
      deadlineDate: deadlineDate,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  Widget buildHarness({
    required Widget child,
    Brightness brightness = Brightness.light,
    double textScaleFactor = 1.0,
    Size size = const Size(800, 600),
  }) {
    final tokens = brightness == Brightness.dark
        ? TodorbitThemeTokens.dark()
        : TodorbitThemeTokens.light();
    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        extensions: [tokens],
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('AppTaskRow Desktop Variant', () {
    testWidgets('renders desktop row with title, checkbox, and minHeight 52', (
      tester,
    ) async {
      final task = createTask(title: 'Review PR #42');
      bool? toggled;
      bool tapped = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.desktop,
            onTap: () => tapped = true,
            onToggleComplete: (val) => toggled = val,
          ),
        ),
      );

      expect(find.text('Review PR #42'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(find.byType(AppTaskRow));
      expect(renderBox.size.height, greaterThanOrEqualTo(52.0));

      // Tap checkbox toggles completion
      await tester.tap(find.byType(Checkbox));
      expect(toggled, isTrue);

      // Tap row triggers onTap
      await tester.tap(find.text('Review PR #42'));
      expect(tapped, isTrue);
    });

    testWidgets('displays plan date, due date, subtasks, checklist, and priority', (
      tester,
    ) async {
      final today = localDate(DateTime.now());
      final task = createTask(
        title: 'Complete feature',
        priority: 3,
        scheduledDate: today,
        deadlineDate: today,
      );

      await tester.pumpWidget(
        buildHarness(
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.desktop,
            subtaskProgress: const TaskProgress(completed: 2, total: 4),
            checklistProgress: const TaskProgress(completed: 1, total: 3),
            unmetPrerequisitesCount: 2,
            unmetPrerequisitesSummary: 'Waiting for Task A, Task B',
          ),
        ),
      );

        final localizedDay = const DefaultMaterialLocalizations()
            .formatShortDate(DateTime.parse(today));
        expect(find.text('Planned $localizedDay'), findsOneWidget);
        expect(find.text('Due $localizedDay'), findsOneWidget);
        expect(find.text('Subtasks 2/4'), findsOneWidget);
        expect(find.text('Checklist 1/3'), findsOneWidget);
        expect(find.text('Blocked by 2'), findsOneWidget);
        expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      },
    );

    testWidgets('highlights overdue tasks with error styling on desktop', (
      tester,
    ) async {
      final yesterday = localDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final task = createTask(
        title: 'Overdue desktop task',
        deadlineDate: yesterday,
      );

      await tester.pumpWidget(
        buildHarness(
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.desktop,
          ),
        ),
      );

      final localizedDay = const DefaultMaterialLocalizations().formatShortDate(
        DateTime.parse(yesterday),
      );
      final dueTextFinder = find.text('Due $localizedDay');
      expect(dueTextFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(dueTextFinder);
      expect(
        textWidget.style?.color,
        ThemeData.light().colorScheme.error,
      );
    });

    testWidgets('renders completed state with lineThrough decoration', (
      tester,
    ) async {
      final task = createTask(
        title: 'Done task',
        status: TaskStatus.completed,
      );

      await tester.pumpWidget(
        buildHarness(
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.desktop,
          ),
        ),
      );

      final titleFinder = find.text('Done task');
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('AppTaskRow Mobile Variant', () {
    testWidgets('renders mobile row with ListTile, minHeight 56, and subtitle', (
      tester,
    ) async {
      final task = createTask(
        title: 'Mobile task',
        priority: 2,
        status: TaskStatus.inProgress,
      );
      bool longPressed = false;

      await tester.pumpWidget(
        buildHarness(
          size: const Size(360, 640),
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.mobile,
            categoryName: 'Work',
            projectName: 'Todorbit',
            onLongPress: () => longPressed = true,
          ),
        ),
      );

      expect(find.text('Mobile task'), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(find.byType(AppTaskRow));
      expect(renderBox.size.height, greaterThanOrEqualTo(56.0));

      // Subtitle contains priority, status, category, project separated by ·
      expect(find.textContaining('Priority 2'), findsOneWidget);
      expect(find.textContaining('In progress'), findsOneWidget);
      expect(find.textContaining('Work'), findsOneWidget);
      expect(find.textContaining('Todorbit'), findsOneWidget);

      // Long press triggers onLongPress
      await tester.longPress(find.text('Mobile task'));
      expect(longPressed, isTrue);
    });

    testWidgets('mobile highlights overdue with warning amber icon and error text', (
      tester,
    ) async {
      final yesterday = localDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final task = createTask(
        title: 'Overdue mobile task',
        deadlineDate: yesterday,
      );

      await tester.pumpWidget(
        buildHarness(
          size: const Size(360, 640),
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.mobile,
          ),
        ),
      );

      // Warning amber icon with Overdue semantic label
      final warningFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.warning_amber_rounded &&
            w.semanticLabel == 'Overdue',
      );
      expect(warningFinder, findsOneWidget);

      // Overdue text in subtitle
      expect(find.textContaining('Overdue · Due'), findsOneWidget);
    });

    testWidgets('adapts cleanly to narrow widths and 1.5x text scaling without overflow', (
      tester,
    ) async {
      final task = createTask(
        title:
            'A very long task title that would definitely wrap onto multiple lines and test overflow safety in narrow layout mode',
        priority: 3,
        deadlineDate: localDate(DateTime.now()),
      );

      await tester.pumpWidget(
        buildHarness(
          size: const Size(320, 480),
          textScaleFactor: 1.5,
          child: AppTaskRow(
            task: task,
            variant: AppTaskRowVariant.mobile,
            categoryName: 'Personal Projects',
            hasAlarm: true,
            trailingActions: const Icon(Icons.more_vert),
          ),
        ),
      );

        expect(tester.takeException(), isNull);
        final title = find.textContaining('A very long task title');
        expect(tester.widget<Text>(title).maxLines, 4);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );
  });
}
