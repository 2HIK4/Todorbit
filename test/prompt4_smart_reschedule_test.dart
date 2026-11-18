import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/scheduling_models.dart';
import 'package:life_manager/domain/series_edit.dart';
import 'package:life_manager/features/scheduling/schedule_preview_details.dart';
import 'package:life_manager/features/scheduling/smart_reschedule.dart';

import 'test_privacy.dart';
import 'support/uiux_review_capture.dart';

import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/shared/app_theme.dart';

class GatedController extends AppController {
  GatedController(super.repository);
  Completer<void>? previewGate;
  Completer<void>? applyGate;
  int previewCalls = 0;
  Object? previewFailure;
  int applyCalls = 0;

  @override
  Future<List<SeriesScheduleCollision>> scheduleSeriesCollisions(
    SchedulingPreview preview,
  ) async {
    previewCalls++;
    await previewGate?.future;
    if (previewFailure != null) throw previewFailure!;
    return super.scheduleSeriesCollisions(preview);
  }

  @override
  Future<String> applySchedulingPreview(
    SchedulingPreview preview, {
    Map<String, SeriesCollisionChoice> seriesChoices = const {},
    List<SeriesScheduleCollision> expectedSeriesCollisions = const [],
  }) async {
    applyCalls++;
    await applyGate?.future;
    return super.applySchedulingPreview(
      preview,
      seriesChoices: seriesChoices,
      expectedSeriesCollisions: expectedSeriesCollisions,
    );
  }
}

void main() {
  setUpAll(() async {
    if (Platform.environment['UIUX_CAPTURE_DIR'] != null) {
      await loadReviewFonts();
    }
  });
  late AppDatabase db;
  late LifeRepository repo;
  late GatedController controller;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LifeRepository(db);
    controller = GatedController(repo);
  });
  tearDown(() async {
    await db.close();
  });

  Future<String> snapshot() async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return jsonEncode({
      for (final row in names)
        row.read<String>('name'):
            (await db
                    .customSelect('SELECT * FROM "${row.read<String>('name')}"')
                    .get())
                .map((row) => row.data)
                .toList(),
    });
  }

  Future<void> open(
    WidgetTester tester,
    List<String> ids, {
    Size size = const Size(1280, 900),
    double scale = 1,
    Brightness brightness = Brightness.light,
    List<String> sessionIds = const [],
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    });
    await controller.refresh();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          privacyOverride,
        ],
        child: RepaintBoundary(
          key: reviewCaptureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(
              brightness,
              brightness == Brightness.dark
                  ? ThemePalette.dark
                  : ThemePalette.light,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => SmartRescheduleDialog(
                      scope: 'Prompt 4',
                      taskIds: ids,
                      sessionIds: sessionIds,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    if (find.text('Generate preview').evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Generate preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate preview'));
    await tester.pumpAndSettle();
  }

  Finder getApply() => find.widgetWithText(FilledButton, 'Apply');
  SchedulingPreview proposal(WidgetTester tester) => tester
      .widget<SchedulePreviewDetails>(find.byType(SchedulePreviewDetails))
      .preview;

  testWidgets(
    'aa and 1 form a hierarchy with independent selection and stable collapse',
    (tester) async {
      final parent = await repo.addTask(
        const TaskDraft(title: 'aa', scheduledDate: '2026-10-19'),
      );
      final child = await repo.addSubtask(
        parent,
        const TaskDraft(title: '1', scheduledDate: '2026-10-20'),
      );
      final sibling = await repo.addSubtask(
        parent,
        const TaskDraft(title: '2', scheduledDate: '2026-10-21'),
      );
      final other = await repo.addTask(
        const TaskDraft(title: 'Other parent', scheduledDate: '2026-10-21'),
      );
      await repo.addSubtask(other, const TaskDraft(title: 'Other child'));
      await open(tester, [parent.id, child.id, sibling.id, other.id]);
      expect(find.text('2 subtasks'), findsOneWidget);
      final parentRow = find.byKey(ValueKey('schedule-task:${parent.id}'));
      final childRow = find.byKey(ValueKey('schedule-task:${child.id}'));
      expect(
        tester.getTopLeft(childRow).dx,
        greaterThan(tester.getTopLeft(parentRow).dx),
      );
      await tester.tap(parentRow);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(childRow).value, isTrue);
      await tester.tap(find.text('2 subtasks'));
      await tester.pumpAndSettle();
      expect(childRow.hitTestable(), findsNothing);
      await generate(tester);
      expect(
        proposal(tester).changes.map((change) => change.targetId).toSet(),
        {child.id, sibling.id, other.id},
      );
      expect(await repo.taskParents(), containsPair(child.id, parent.id));
    },
  );

  testWidgets(
    'child-only scope shows parent context without authorizing parent changes',
    (tester) async {
      final parent = await repo.addTask(const TaskDraft(title: 'aa'));
      final child = await repo.addSubtask(parent, const TaskDraft(title: '1'));
      await open(tester, [child.id]);
      expect(find.text('aa'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(ValueKey('schedule-task:${parent.id}')),
            )
            .onChanged,
        isNull,
      );
      await generate(tester);
      expect(proposal(tester).changes.single.targetId, child.id);
    },
  );

  testWidgets(
    'OS quiz 15 occurrences default to one collapsed series and independent identities',
    (tester) async {
      await repo.addRecurringTask(
        const TaskDraft(title: 'OS quiz', scheduledDate: '2026-10-19'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 15,
        ),
      );
      await repo.ensureRecurringTasks('2026-10-19', '2026-11-02');
      final tasks = await repo.tasks();
      expect(tasks, hasLength(15));
      await open(tester, tasks.map((task) => task.id).toList());
      expect(find.text('OS quiz · Recurring series'), findsOneWidget);
      expect(find.textContaining('15 occurrences in scope'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('OS quiz · Recurring series'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(15));
      await tester.ensureVisible(
        find.byKey(ValueKey('schedule-task:${tasks.first.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('schedule-task:${tasks.first.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(ValueKey('schedule-task:${tasks[1].id}')),
            )
            .value,
        isTrue,
      );
      await generate(tester);
      expect(proposal(tester).changes, hasLength(14));
      expect(find.text('Keep all occurrences'), findsOneWidget);
      expect(
        proposal(tester).changes
            .any((change) => change.targetId == tasks.first.id),
        isFalse,
      );
    },
  );

  testWidgets(
    '14 already-planned collisions grouped once with no Combine action and cancellable review',
    (tester) async {
      final today = localDate(DateTime.now());
      final start = localDate(DateTime.now().add(const Duration(days: 1)));
      await repo.addRecurringTask(
        TaskDraft(title: 'OS quiz', scheduledDate: start),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: start,
          maxOccurrences: 15,
        ),
      );
      await repo.ensureRecurringTasks(
        start,
        localDate(DateTime.now().add(const Duration(days: 15))),
      );
      final tasks = await repo.tasks();
      for (final task in tasks.skip(1)) {
        await repo.updateTask(
          task,
          TaskDraft(title: task.title, scheduledDate: today),
        );
      }
      await open(tester, [tasks.first.id]);
      final before = await snapshot();
      await generate(tester);
      expect(
        find.textContaining('1 moving occurrence collides'),
        findsOneWidget,
      );
      expect(
        find.textContaining('14 other occurrences already planned'),
        findsOneWidget,
      );
      expect(find.text('Keep all occurrences'), findsOneWidget);
      await captureReview(tester, 'collision-summary');
      expect(find.text('Combine unavailable'), findsNothing);
      expect(
        find.byType(DropdownMenuItem<SeriesCollisionChoice>),
        findsNothing,
      );
      expect(tester.widget<FilledButton>(getApply()).onPressed, isNull);
      expect(await snapshot(), before);
      await tester.tap(find.text('Keep all occurrences'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(getApply()).onPressed, isNotNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await snapshot(), before);
    },
  );

  testWidgets(
    'leave collisions unchanged clears preview and preserves occurrence status',
    (tester) async {
      final today = localDate(DateTime.now());
      final first = await repo.addRecurringTask(
        TaskDraft(title: 'OS quiz', scheduledDate: today),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: today,
          maxOccurrences: 2,
        ),
      );
      await repo.ensureRecurringTasks(
        today,
        localDate(DateTime.now().add(const Duration(days: 1))),
      );
      final second = (await repo.tasks()).firstWhere(
        (task) => task.id != first.id,
      );
      await open(tester, [second.id]);
      final before = await snapshot();
      await generate(tester);
      await tester.tap(find.text('Leave moving occurrences unchanged'));
      await tester.pumpAndSettle();
      expect(find.byType(SchedulePreviewDetails), findsNothing);
      expect(tester.widget<FilledButton>(getApply()).onPressed, isNull);
      expect(await snapshot(), before);
    },
  );

  testWidgets(
    'input changes invalidate a preview and no-date or same-day results explain Apply',
    (tester) async {
      final task = await repo.addTask(const TaskDraft(title: 'No date'));
      await open(tester, [task.id]);
      await generate(tester);
      expect(proposal(tester).changes, hasLength(1));
      await tester.ensureVisible(find.text('Move').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shift').last);
      await tester.pumpAndSettle();
      expect(find.byType(SchedulePreviewDetails), findsNothing);
      await generate(tester);
      expect(
        find.textContaining('has no planned date to shift'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(getApply()).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pumpAndSettle();
      expect(find.byType(SchedulePreviewDetails), findsNothing);
      expect(await repo.schedulingHistory(), isEmpty);
    },
  );

  testWidgets(
    'rapid preview and Apply invoke one write and preserve protected records through undo',
    (tester) async {
      final parent = await repo.addTask(
        const TaskDraft(
          title: 'aa',
          scheduledDate: '2026-10-19',
          alarm: AlarmConfig(mode: 'planned', localMinute: 600),
        ),
      );
      final child = await repo.addSubtask(
        parent,
        const TaskDraft(title: '1', scheduledDate: '2026-10-20'),
      );
      await repo.addSession(
        SessionDraft(
          taskId: child.id,
          startsAt: DateTime.utc(2026, 10, 20, 9),
          endsAt: DateTime.utc(2026, 10, 20, 10),
        ),
      );
      await open(tester, [child.id]);
      final links = await repo.taskParents();
      final sessions = (await repo.sessions())
          .map(
            (session) =>
                [session.id, session.startsAt, session.endsAt].toString(),
          )
          .toList();
      controller.previewGate = Completer<void>();
      final generateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Generate preview'),
      );
      generateButton.onPressed!();
      generateButton.onPressed!();
      await tester.pump();
      expect(controller.previewCalls, 1);
      controller.previewGate!.complete();
      await tester.pumpAndSettle();
      controller.applyGate = Completer<void>();
      final applyButton = tester.widget<FilledButton>(getApply());
      applyButton.onPressed!();
      applyButton.onPressed!();
      await tester.pump();
      expect(controller.applyCalls, 1);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      controller.applyGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SmartRescheduleDialog), findsNothing);
      final history = await repo.schedulingHistory();
      expect(history, hasLength(1));
      expect(history.single.changes.single.targetId, child.id);
      expect(
        (await repo.tasks())
            .firstWhere((task) => task.id == parent.id)
            .revision,
        parent.revision,
      );
      final undo = await repo.previewRestore(history.single.id, undo: true);
      await repo.applySchedulingPreview(undo);
      expect(
        (await repo.tasks())
            .firstWhere((task) => task.id == child.id)
            .scheduledDate,
        child.scheduledDate,
      );
      expect(await repo.taskParents(), links);
      expect(
        (await repo.sessions())
            .map(
              (session) =>
                  [session.id, session.startsAt, session.endsAt].toString(),
            )
            .toList(),
        sessions,
      );
    },
  );

  testWidgets(
    'completed occurrences exceptions history and alarms survive Apply and undo',
    (tester) async {
      final first = await repo.addRecurringTask(
        const TaskDraft(
          title: 'OS quiz',
          scheduledDate: '2026-10-19',
          alarm: AlarmConfig(mode: 'planned', localMinute: 600),
        ),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 4,
        ),
      );
      await repo.ensureRecurringTasks('2026-10-19', '2026-10-22');
      await repo.addManualTime(
        first.id,
        DateTime.utc(2026, 10, 19, 9),
        DateTime.utc(2026, 10, 19, 10),
        'Completed quiz work',
      );
      expect(await repo.alarmRules(), isNotEmpty);
      expect(await repo.timeEntries(), hasLength(1));
      await repo.setComplete(first, true);
      var tasks = await repo.tasks();
      final edited = tasks.firstWhere(
        (task) => task.nominalDate == '2026-10-20',
      );
      await repo.updateTask(
        edited,
        const TaskDraft(
          title: 'Edited quiz exception',
          notes: 'Preserve',
          scheduledDate: '2026-10-20',
        ),
      );
      final skipped = tasks.firstWhere(
        (task) => task.nominalDate == '2026-10-21',
      );
      await repo.skipRecurringOccurrence(skipped);
      tasks = await repo.tasks();
      final moving = tasks.firstWhere(
        (task) => task.nominalDate == '2026-10-22',
      );
      final protectedTasks = {
        for (final task in tasks.where((task) => task.id != moving.id))
          task.id: task.revision,
      };
      Future<String> preserved() async => jsonEncode({
        for (final table in [
          'recurrence_series',
          'alarm_rules',
          'series_edit_history',
          'time_entries',
        ])
          table: (await db.customSelect('SELECT * FROM $table').get())
              .map((row) => row.data)
              .toList(),
      });
      final before = await preserved();
      await open(tester, [first.id, moving.id]);
      await generate(tester);
      expect(proposal(tester).changes.map((change) => change.targetId), [
        moving.id,
      ]);
      await tester.ensureVisible(
        find.text('I reviewed the warnings and want to apply these changes.'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('I reviewed the warnings and want to apply these changes.'),
      );
      await tester.pumpAndSettle();
      await tester.tap(getApply());
      await tester.pumpAndSettle();
      expect(await preserved(), before);
      tasks = await repo.tasks();
      expect({
        for (final task in tasks.where((task) => task.id != moving.id))
          task.id: task.revision,
      }, protectedTasks);
      final moved = tasks.firstWhere((task) => task.id == moving.id);
      expect(moved.nominalDate, moving.nominalDate);
      expect(moved.recurrenceSeriesId, moving.recurrenceSeriesId);
      expect(moved.recurrenceFamilyId, moving.recurrenceFamilyId);
      final history = await repo.schedulingHistory();
      await repo.applySchedulingPreview(
        await repo.previewRestore(history.single.id, undo: true),
      );
      expect(
        (await repo.tasks())
            .firstWhere((task) => task.id == moving.id)
            .scheduledDate,
        moving.scheduledDate,
      );
      expect(await preserved(), before);
    },
  );

  testWidgets('locked item cannot disappear from the blocking preview', (
    tester,
  ) async {
    final locked = await repo.addTask(
      const TaskDraft(title: 'Protected', schedulingLocked: true),
    );
    final eligible = await repo.addTask(const TaskDraft(title: 'Eligible'));
    await open(tester, [locked.id, eligible.id]);
    await generate(tester);
    expect(proposal(tester).changes, hasLength(1));
    expect(find.textContaining('protected from scheduling'), findsOneWidget);
    expect(tester.widget<FilledButton>(getApply()).onPressed, isNull);
    expect(await repo.schedulingHistory(), isEmpty);
  });

  testWidgets('same-day move explains the empty preview without writing', (
    tester,
  ) async {
    final task = await repo.addTask(
      TaskDraft(
        title: 'Already today',
        scheduledDate: localDate(DateTime.now()),
      ),
    );
    await open(tester, [task.id]);
    await generate(tester);
    expect(proposal(tester).changes, isEmpty);
    expect(
      find.textContaining('No eligible scheduling changes. Adjust'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(getApply()).onPressed, isNull);
    expect(await repo.schedulingHistory(), isEmpty);
  });

  testWidgets(
    'duplicate scoped task IDs produce exactly one authorized change',
    (tester) async {
      final task = await repo.addTask(
        const TaskDraft(title: 'One task', scheduledDate: '2026-10-19'),
      );
      await open(tester, [task.id, task.id]);
      await generate(tester);
      expect(proposal(tester).changes, hasLength(1));
      await tester.tap(getApply());
      await tester.pumpAndSettle();
      expect((await repo.schedulingHistory()).single.changes, hasLength(1));
    },
  );

  testWidgets(
    'failed preview and in-flight cancellation never write and permit retry',
    (tester) async {
      final task = await repo.addTask(
        const TaskDraft(title: 'Non-mutating preview'),
      );
      await open(tester, [task.id]);
      final before = await snapshot();
      controller.previewFailure = StateError('Read interrupted');
      await generate(tester);
      expect(
        find.textContaining('Preview could not be generated'),
        findsOneWidget,
      );
      expect(await snapshot(), before);
      controller.previewFailure = null;
      controller.previewGate = Completer<void>();
      await tester.tap(find.text('Generate preview'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      controller.previewGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SmartRescheduleDialog), findsNothing);
      expect(await snapshot(), before);
    },
  );

  testWidgets(
    'session preview input invalidation preserves task date and duration through Apply and undo',
    (tester) async {
      final task = await repo.addRecurringTask(
        const TaskDraft(title: 'OS quiz', scheduledDate: '2026-10-19'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 1,
        ),
      );
      final session = await repo.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime.utc(2026, 10, 19, 9),
          endsAt: DateTime.utc(2026, 10, 19, 11),
        ),
      );
      await open(tester, [], sessionIds: [session.id]);
      await generate(tester);
      expect(proposal(tester).changes.single.targetId, session.id);
      expect(
        find.textContaining('1 session · 1 recurring series'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pumpAndSettle();
      expect(find.byType(SchedulePreviewDetails), findsNothing);
      expect((await repo.sessions()).single.startsAt, session.startsAt);
      await generate(tester);
      await tester.tap(getApply());
      await tester.pumpAndSettle();
      expect((await repo.tasks()).single.scheduledDate, task.scheduledDate);
      final moved = (await repo.sessions()).single;
      expect(moved.endsAt.difference(moved.startsAt), const Duration(hours: 2));
      final history = await repo.schedulingHistory();
      await repo.applySchedulingPreview(
        await repo.previewRestore(history.single.id, undo: true),
      );
      final restored = (await repo.sessions()).single;
      expect(restored.startsAt, session.startsAt);
      expect(restored.endsAt, session.endsAt);
    },
  );

  test(
    'Smart Reschedule repository rejects unsupported Combine atomically',
    () async {
      final first = await repo.addRecurringTask(
        const TaskDraft(title: 'OS quiz', scheduledDate: '2026-10-19'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-10-19',
          maxOccurrences: 2,
        ),
      );
      await repo.ensureRecurringTasks('2026-10-19', '2026-10-20');
      final preview = SchedulingPreview(
        operation: ScheduleOperationType.move,
        scope: 'Prompt 4',
        changes: [
          ScheduleChange(
            targetKind: ScheduleTargetKind.task,
            targetId: first.id,
            expectedUpdatedAt: first.updatedAt,
            beforeDate: first.scheduledDate,
            afterDate: '2026-10-20',
          ),
        ],
        issues: const [],
        createdAt: DateTime.now().toUtc(),
      );
      final collisions = await repo.scheduleSeriesCollisions(preview);
      final before = await snapshot();
      await expectLater(
        repo.applySchedulingPreview(
          preview,
          expectedSeriesCollisions: collisions,
          seriesChoices: {first.id: SeriesCollisionChoice.combine},
        ),
        throwsStateError,
      );
      expect(await snapshot(), before);
    },
  );

  for (final exception in ['none', 'cancelled', 'moved out', 'moved in']) {
    test(
      'Apply projects recurring event collisions with exception $exception',
      () async {
        final day = DateTime(2026, 11, 18);
        final origin = DateTime(day.year, day.month, day.day, 8);
        final proposed = DateTime(day.year, day.month, day.day, 14);
        final task = await repo.addTask(
          const TaskDraft(title: 'Keep session identity'),
        );
        final session = await repo.addSession(
          SessionDraft(
            taskId: task.id,
            startsAt: origin,
            endsAt: origin.add(const Duration(hours: 1)),
          ),
        );
        final preview = SchedulingPreview(
          operation: ScheduleOperationType.move,
          scope: 'recurring collision',
          changes: [
            ScheduleChange(
              targetKind: ScheduleTargetKind.session,
              targetId: session.id,
              expectedUpdatedAt: session.updatedAt,
              beforeStartsAt: session.startsAt,
              beforeEndsAt: session.endsAt,
              afterStartsAt: proposed,
              afterEndsAt: proposed.add(const Duration(hours: 1)),
            ),
          ],
          issues: const [],
          createdAt: DateTime.now(),
        );

        // A current event series appears after Preview, with a master well
        // outside the proposed interval.
        final templateStart = proposed.subtract(const Duration(days: 14));
        await repo.addEvent(
          EventDraft(
            title: 'Recurring meeting',
            startsAt: templateStart,
            endsAt: templateStart.add(const Duration(hours: 1)),
            repeat: const EventRepeat(kind: EventRepeatKind.daily),
          ),
        );
        final nominalDay = exception == 'moved in'
            ? localDate(templateStart)
            : localDate(day);
        final occurrence = (await repo.eventOccurrences(
          nominalDay,
          nominalDay,
        )).single;
        if (exception == 'cancelled' || exception == 'moved in') {
          final sameDay = (await repo.eventOccurrences(
            localDate(day),
            localDate(day),
          )).single;
          await repo.setEventOccurrenceCancelled(sameDay, true);
        }
        if (exception.startsWith('moved')) {
          final moved = exception == 'moved in'
              ? proposed
              : proposed.add(const Duration(hours: 1));
          await repo.updateEventOccurrence(
            occurrence,
            EventDraft(
              title: occurrence.title,
              startsAt: moved,
              endsAt: moved.add(const Duration(hours: 1)),
            ),
          );
        }

        final before = await snapshot();
        final eventRows = await repo.db
            .customSelect(
              'SELECT * FROM event_occurrence_changes ORDER BY nominal_date',
            )
            .get();
        if (exception == 'none' || exception == 'moved in') {
          await expectLater(
            repo.applySchedulingPreview(preview),
            throwsA(isA<StaleSchedulePreviewException>()),
          );
          expect(await snapshot(), before);
        } else {
          final operation = await repo.applySchedulingPreview(preview);
          expect((await repo.sessions()).single.startsAt, proposed.toUtc());
          final undo = await repo.previewRestore(operation, undo: true);
          await repo.applySchedulingPreview(undo);
          final restored = (await repo.sessions()).single;
          expect(restored.id, session.id);
          expect(restored.taskId, task.id);
          expect(restored.startsAt, session.startsAt);
          expect(restored.endsAt, session.endsAt);
        }
        expect(
          (await repo.db
                  .customSelect(
                    'SELECT * FROM event_occurrence_changes ORDER BY nominal_date',
                  )
                  .get())
              .map((row) => row.data),
          eventRows.map((row) => row.data),
        );
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('narrow 320dp 2x $brightness review has no overflow', (
      tester,
    ) async {
      final parent = await repo.addTask(
        const TaskDraft(title: 'aa long task name'),
      );
      final child = await repo.addSubtask(
        parent,
        const TaskDraft(title: '1 long subtask name'),
      );
      await open(
        tester,
        [parent.id, child.id],
        size: const Size(320, 740),
        scale: 2,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await generate(tester);
      expect(tester.takeException(), isNull);
      expect(getApply().hitTestable(), findsOneWidget);
      await captureReview(tester, 'narrow-${brightness.name}');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repo.schedulingHistory(), isEmpty);
    });
  }
}
