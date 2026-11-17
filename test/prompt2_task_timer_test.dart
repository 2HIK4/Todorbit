import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/domain/focus_session.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/time_tracking/task_timer_intent.dart';
import 'package:life_manager/features/time_tracking/compact_task_timer.dart';
import 'package:life_manager/features/time_tracking/time_tracking_dialog.dart';
import 'package:life_manager/features/workspace/task_composition_section.dart';
import 'package:life_manager/features/workspace/planned_session_delete.dart';

void main() {
  late AppDatabase db;
  late LifeRepository repo;
  late AppController c;
  late LifeTask first, second;
  var providerOwnsController = false;
  setUp(() async {
    providerOwnsController = false;
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    first = await repo.addTask(const TaskDraft(title: 'First'));
    second = await repo.addTask(const TaskDraft(title: 'Second'));
    c = AppController(repo);
    await c.refresh();
  });
  tearDown(() async {
    if (!providerOwnsController) c.dispose();
    await db.close();
  });

  test('concurrent starts reuse running and paused identity without duplicate intervals', () async {
    final runs = await Future.wait(
      List.generate(8, (_) => repo.startTimer(first.id)),
    );
    expect(runs.map((run) => run.id).toSet(), hasLength(1));
    expect(await repo.timeEntries(), hasLength(1));
    await repo.pauseTimer(runs.first);
    final paused = await repo.startTimer(first.id);
    expect(paused.id, runs.first.id);
    expect(paused.state, TimerState.paused);
    expect(await repo.timeEntries(), hasLength(1));
    await repo.stopTimer(paused);
    final next = await repo.startTimer(first.id);
    expect(next.id, isNot(paused.id));
    expect(
      (await repo.tasks()).firstWhere((t) => t.id == first.id).status,
      TaskStatus.notStarted,
    );
  });

  test('atomic switch preserves intervals, task status and plans; stale switch rolls back', () async {
    final plan = await repo.addSession(
      SessionDraft(
        taskId: first.id,
        startsAt: DateTime.utc(2030),
        endsAt: DateTime.utc(2030, 1, 1, 1),
      ),
    );
    final original = await repo.startTimer(first.id);
    await repo.pauseTimer(original);
    await expectLater(
      repo.switchTaskTimer(original, second.id),
      throwsStateError,
    );
    expect((await repo.activeTimerRun())!.taskId, first.id);
    final switched = await repo.switchTaskTimer(
      (await repo.activeTimerRun())!,
      second.id,
    );
    expect(switched!.taskId, second.id);
    expect((await repo.timeEntries(taskId: first.id)).single.endsAt, isNotNull);
    expect((await repo.sessions()).single.id, plan.id);
    expect(
      (await repo.tasks()).every((t) => t.status == TaskStatus.notStarted),
      isTrue,
    );
    await expectLater(
      repo.switchTaskTimer(switched, 'missing'),
      throwsStateError,
    );
    expect((await repo.activeTimerRun())!.id, switched.id);
    expect((await repo.timeEntries(taskId: second.id)).single.endsAt, isNull);
  });

  test('countdown entry starts selected flow, reopening does not toggle; refresh clears stale focus', () async {
    await c.changeFocusPhase(first.id, mode: FocusMode.countdown);
    await Future.wait(List.generate(6, (_) => c.enterTaskTimer(first.id)));
    expect(c.focusSessionFor(first.id).running, isTrue);
    final id = c.activeTimer!.id;
    await c.enterTaskTimer(first.id);
    expect(c.activeTimer!.id, id);
    expect(c.activeTimer!.state, TimerState.running);
    expect(
      c.tasks.firstWhere((t) => t.id == first.id).status,
      TaskStatus.notStarted,
    );
    await repo.stopTimer(c.activeTimer!);
    await c.refresh();
    expect(c.focusSessionFor(first.id).running, isFalse);
    expect(c.activeTimer, isNull);
  });

  test('planned deletion rejects changed/completed sessions and keeps actual work and task', () async {
    final plan = await repo.addSession(
      SessionDraft(
        taskId: first.id,
        startsAt: DateTime.utc(2020),
        endsAt: DateTime.utc(2020, 1, 1, 1),
      ),
    );
    await repo.addManualTime(
      first.id,
      DateTime.utc(2020),
      DateTime.utc(2020, 1, 1, 0, 20),
      'Actual',
    );
    await repo.deletePlannedSession(plan);
    expect(await repo.sessions(), isEmpty);
    expect((await repo.timeEntries()).single.notes, 'Actual');
    expect(await repo.tasks(), hasLength(2));
    await repo.restoreTrashItem((await repo.trash()).single);
    final restored = (await repo.sessions()).single;
    await repo.updateSession(
      restored,
      SessionDraft(
        taskId: first.id,
        startsAt: restored.startsAt,
        endsAt: restored.endsAt,
        outcome: SessionOutcome.completed,
      ),
    );
    await expectLater(repo.deletePlannedSession(restored), throwsStateError);
    await expectLater(
      repo.deletePlannedSession((await repo.sessions()).single),
      throwsStateError,
    );
    expect((await repo.sessions()).single.outcome, SessionOutcome.completed);
  });

  Future<void> mount(WidgetTester tester, Widget child) {
    providerOwnsController = true;
    return tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (_, ref, _) {
                ref.read(appControllerProvider);
                return child;
              },
            ),
          ),
        ),
      ),
    );
  }

  test('checklist group reorder and stale removal preserve item history and parent counts', () async {
    final a = await repo.addChecklistGroup(first.id, 'A');
    final b = await repo.addChecklistGroup(first.id, 'B');
    await repo.addChecklistItem(first.id, 'Done step', groupId: a.id);
    final before = (await repo.checklistItems()).single;
    await repo.updateChecklistItem(before, done: true);
    await expectLater(repo.removeChecklistGroup(a, [before]), throwsStateError);
    expect((await repo.checklistItems()).single.done, isTrue);
    await repo.moveChecklistGroup(b, -1);
    expect((await repo.checklistGroups()).map((g) => g.title), ['B', 'A']);
    final currentA = (await repo.checklistGroups()).last;
    await repo.renameChecklistGroup(currentA, 'Renamed');
    expect((await repo.checklistItems()).single.id, before.id);
    expect((await repo.checklistItems()).single.done, isTrue);
    await repo.removeChecklistGroup(
      (await repo.checklistGroups()).last,
      await repo.checklistItems(),
    );
    expect((await repo.checklistGroups()).single.id, b.id);
    expect(await repo.checklistItems(), isEmpty);
    expect(await repo.taskParents(), isEmpty);
    expect(await repo.tasks(), hasLength(2));
  });

  test('switch to a Pomodoro break creates no actual work interval', () async {
    await c.enterTaskTimer(first.id);
    final session = c.focusSessionFor(second.id)
      ..mode = FocusMode.pomodoro
      ..phase = PomodoroPhase.shortBreak;
    session.reset();
    await c.switchTaskTimer(c.activeTimer!, second.id);
    expect(c.activeTimer, isNull);
    expect(session.running, isTrue);
    expect(await repo.timeEntries(taskId: second.id), isEmpty);
    expect((await repo.timeEntries(taskId: first.id)).single.endsAt, isNotNull);
  });

  void widgetCase(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  widgetCase(
    'intent coalesces rapid taps, reopens paused session, and cancellation preserves another timer',
    (tester) async {
      final opened = <String>[];
      await mount(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              FilledButton(
                onPressed: () =>
                    openTaskTimer(context, c, first.id, open: opened.add),
                child: const Text('First'),
              ),
              FilledButton(
                onPressed: () =>
                    openTaskTimer(context, c, second.id, open: opened.add),
                child: const Text('Second'),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('First'));
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(opened, [first.id]);
      final id = c.activeTimer!.id;
      await c.pauseTimer();
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(c.activeTimer!.id, id);
      expect(c.activeTimer!.state, TimerState.paused);
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('A task timer is already active'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.activeTimer!.id, id);
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop and switch'));
      await tester.pumpAndSettle();
      expect(c.activeTimer!.taskId, second.id);
      expect(opened.last, second.id);
      expect(await repo.timeEntries(), hasLength(2));
    },
  );

  widgetCase(
    'compact timer at 280dp supports quick pause resume and clears on stop',
    (tester) async {
      await c.enterTaskTimer(first.id);
      await tester.binding.setSurfaceSize(const Size(280, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final opened = <String>[];
      await mount(tester, CompactTaskTimer(open: opened.add));
      await tester.tap(find.byTooltip('Pause timer'));
      await tester.pumpAndSettle();
      expect(c.activeTimer!.state, TimerState.paused);
      await tester.tap(find.text('First'));
      expect(opened, [first.id]);
      await tester.tap(find.byTooltip('Resume timer'));
      await tester.pumpAndSettle();
      expect(c.activeTimer!.state, TimerState.running);
      await tester.tap(find.byTooltip('Timer controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  widgetCase(
    'child explains nesting limit and keeps editable checklist groups',
    (tester) async {
      final child = await repo.addSubtask(
        first,
        const TaskDraft(title: 'Child'),
      );
      await c.refresh();
      await mount(
        tester,
        SingleChildScrollView(
          child: TaskCompositionSection(task: child, onAddSubtask: null),
        ),
      );
      expect(
        find.textContaining('Subtasks support one level only'),
        findsOneWidget,
      );
      expect(find.text('Add subtask'), findsNothing);
      await tester.tap(find.text('New checklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Steps');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect((await repo.checklistGroups()).single.taskId, child.id);
      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Step one');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        (await repo.checklistItems()).single.groupId,
        (await repo.checklistGroups()).single.id,
      );
      await tester.tap(find.byTooltip('Checklist actions: Steps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Renamed');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect((await repo.checklistGroups()).single.title, 'Renamed');
      await tester.tap(find.byTooltip('Checklist item actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repo.checklistItems(), hasLength(1));
      await tester.tap(find.byTooltip('Checklist actions: Renamed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(await repo.checklistGroups(), isEmpty);
      expect(await repo.checklistItems(), isEmpty);
      expect(await repo.taskParents(), {child.id: first.id});
    },
  );

  widgetCase(
    'planned session row confirms deletion and preserves recorded work',
    (tester) async {
      final plan = await repo.addSession(
        SessionDraft(
          taskId: first.id,
          startsAt: DateTime.utc(2030),
          endsAt: DateTime.utc(2030, 1, 1, 1),
        ),
      );
      await c.enterTaskTimer(first.id);
      await mount(tester, PlannedSessionDelete(session: plan));
      await tester.tap(find.byTooltip('Delete planned session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repo.sessions(), hasLength(1));
      await tester.tap(find.byTooltip('Delete planned session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await repo.sessions(), isEmpty);
      expect(await repo.timeEntries(), hasLength(1));
      expect(c.activeTimer!.taskId, first.id);
    },
  );

  widgetCase(
    'Android shell keeps details on cancelled timer switch and opens existing run',
    (tester) async {
      c.navigate(WorkspaceView.all);
      await c.enterTaskTimer(first.id);
      final runId = c.activeTimer!.id;
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(
        tester,
        MobileWorkspace(
          preferenceStore: MobilePreferenceStore(
            File('unused-prompt2-mobile.json'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second').first);
      await tester.pumpAndSettle();
      expect(find.text('Task Details'), findsOneWidget);
      await tester.tap(find.text('Start Focus Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Task Details'), findsOneWidget);
      expect(c.activeTimer!.id, runId);
      await tester.tap(find.text('Start Focus Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open existing timer'));
      await tester.pumpAndSettle();
      expect(find.text('Stopwatch'), findsOneWidget);
      expect(c.activeTimer!.id, runId);
      expect(await repo.timeEntries(), hasLength(1));
    },
  );

  widgetCase(
    'actual work dialog opens the other existing timer without new intervals',
    (tester) async {
      await c.enterTaskTimer(first.id);
      final runId = c.activeTimer!.id;
      await mount(tester, TimeTrackingDialog(taskId: second.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start task timer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open existing timer'));
      await tester.pumpAndSettle();
      expect(find.text('Focus: First'), findsOneWidget);
      expect(c.activeTimer!.id, runId);
      expect(await repo.timeEntries(), hasLength(1));
    },
  );

  test(
    'paused timer survives actual database close/reopen with same ledger',
    () async {
      final dir = await Directory.systemTemp.createTemp('todorbit-prompt2-');
      final file = File('${dir.path}/timer.sqlite');
      var local = AppDatabase(NativeDatabase(file));
      try {
        var repository = LifeRepository(local);
        final task = await repository.addTask(
          const TaskDraft(title: 'Persisted'),
        );
        final run = await repository.startTimer(task.id);
        await repository.pauseTimer(run);
        await local.close();
        local = AppDatabase(NativeDatabase(file));
        repository = LifeRepository(local);
        final recovered = await repository.startTimer(task.id);
        expect(recovered.id, run.id);
        expect(recovered.state, TimerState.paused);
        expect(await repository.timeEntries(), hasLength(1));
      } finally {
        await local.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
