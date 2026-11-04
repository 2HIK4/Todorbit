import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/goals/goal_dialogs.dart';
import 'package:life_manager/features/habits/habit_editor.dart';
import 'package:life_manager/features/shared/numeric_entry_dialog.dart';

class _FailingLinksController extends AppController {
  _FailingLinksController(super.repository);
  bool fail = true;

  @override
  Future<GoalLinks> goalLinks(String goalId) {
    if (fail) throw StateError('Synthetic read unavailable');
    return super.goalLinks(goalId);
  }
}

void main() {
  late AppDatabase database;
  late LifeRepository repository;
  late AppController controller;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
    controller = AppController(repository);
    await controller.refresh();
  });
  tearDown(() async => database.close());

  Future<void> open(
    WidgetTester tester,
    Widget dialog, {
    Size size = const Size(1000, 800),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showDialog<void>(context: context, builder: (_) => dialog),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final goal in [true, false]) {
    testWidgets('${goal ? 'goal' : 'habit'} draft survives Escape and Cancel', (
      tester,
    ) async {
      await open(
        tester,
        goal ? const GoalEditorDialog() : const HabitEditorDialog(),
      );
      final title = find.byKey(
        ValueKey(goal ? 'goal-editor-title' : 'habit-editor-title'),
      );
      await tester.enterText(title, 'Long synthetic draft محفوظ');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Long synthetic draft محفوظ',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(
        find.byType(goal ? GoalEditorDialog : HabitEditorDialog),
        findsNothing,
      );
      expect(await repository.goals(), isEmpty);
      expect(await repository.habits(), isEmpty);
    });
  }

  testWidgets('failed link loading cannot erase existing links and can retry', (
    tester,
  ) async {
    final task = await repository.addTask(
      const TaskDraft(title: 'Keep this relationship'),
    );
    final goal = await repository.addGoal(
      const GoalDraft(title: 'Linked goal', target: 5, startDate: '2026-01-01'),
    );
    await repository.setGoalLinks(
      goal,
      GoalLinks(taskIds: {task.id}, projectIds: {}, habitIds: {}),
    );
    final failing = _FailingLinksController(repository);
    controller = failing;
    await controller.refresh();
    await open(
      tester,
      GoalLinksDialog(goal: (await repository.goals()).single),
    );
    final save = find.widgetWithText(FilledButton, 'Save links');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect((await repository.goalLinks(goal.id)).taskIds, {task.id});
    failing.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect((await repository.goalLinks(goal.id)).taskIds, {task.id});
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect((await repository.goalLinks(goal.id)).taskIds, isEmpty);
  });

  testWidgets(
    'linked progress remains operable at 200 percent in short landscape',
    (tester) async {
      await repository.addTask(
        TaskDraft(title: List.filled(7, 'Long linked task').join(' ')),
      );
      final goal = await repository.addGoal(
        const GoalDraft(title: 'Goal', target: 3, startDate: '2026-01-01'),
      );
      await controller.refresh();
      await open(
        tester,
        GoalLinksDialog(goal: goal),
        size: const Size(640, 360),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(Checkbox), 140);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save links'));
      await tester.tap(find.text('Save links'));
      await tester.pumpAndSettle();
      expect((await repository.goalLinks(goal.id)).taskIds, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'numeric entry validates inline and retains a failed save for retry',
    (tester) async {
      var fail = true;
      double? stored;
      await open(
        tester,
        NumericEntryDialog(
          title: 'Log synthetic progress',
          label: 'Actual value',
          submitLabel: 'Save log',
          validate: (value) => value == null || !value.isFinite || value < 0
              ? 'Enter a nonnegative number.'
              : null,
          save: (value, notes) async {
            if (fail) throw StateError('Synthetic write unavailable');
            stored = value;
          },
        ),
        size: const Size(390, 844),
        scale: 2,
      );
      await tester.enterText(find.byType(TextFormField).first, 'NaN');
      await tester.tap(find.text('Save log'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a nonnegative number.'), findsOneWidget);
      expect(stored, isNull);
      await tester.enterText(find.byType(TextFormField).first, '3.5');
      await tester.tap(find.text('Save log'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Entry was not saved:'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '3.5',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      fail = false;
      await tester.tap(find.text('Save log'));
      await tester.pumpAndSettle();
      expect(stored, 3.5);
      expect(find.byType(NumericEntryDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'milestone validation and Back preserve draft before successful save',
    (tester) async {
      final goal = await repository.addGoal(
        const GoalDraft(title: 'Goal', target: 10, startDate: '2026-01-01'),
      );
      await open(
        tester,
        GoalMilestoneDialog(goal: goal),
        size: const Size(390, 844),
        scale: 2,
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Long milestone محفوظ',
      );
      await tester.enterText(find.byType(TextFormField).last, '11');
      await tester.tap(find.text('Add milestone'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a positive threshold within the goal target.'),
        findsOneWidget,
      );
      expect(await repository.goalMilestones(), isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '5');
      await tester.tap(find.text('Add milestone'));
      await tester.pumpAndSettle();
      final saved = (await repository.goalMilestones()).single;
      expect(saved.goalId, goal.id);
      expect(saved.title, 'Long milestone محفوظ');
      expect(saved.threshold, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('numeric save rejects repeat activation and Back while pending', (
    tester,
  ) async {
    final finish = Completer<void>();
    var writes = 0;
    await open(
      tester,
      NumericEntryDialog(
        title: 'Progress',
        label: 'Value',
        submitLabel: 'Save entry',
        validate: (value) => value == null ? 'Enter a number.' : null,
        save: (value, notes) async {
          writes++;
          await finish.future;
        },
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('numeric-entry-value')),
      '2',
    );
    await tester.pumpAndSettle();
    final submit = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save entry'))
        .onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(writes, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(NumericEntryDialog), findsOneWidget);
    expect(find.text('Discard unsaved changes?'), findsNothing);
    finish.complete();
    await tester.pumpAndSettle();
    expect(find.byType(NumericEntryDialog), findsNothing);
  });
}
