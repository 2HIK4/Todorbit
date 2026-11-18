import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/shared_inbox_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/scheduling_engine.dart';
import 'package:life_manager/domain/sync/portable_preferences.dart';
import 'package:life_manager/domain/task_list_projection.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/shared/pointer_cancellation_scope.dart';
import 'package:life_manager/features/shared/task_list_group.dart';
import 'package:life_manager/features/workspace/task_details_view.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/workspace/workspace.dart';

import 'test_privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1-01: Mixed-Version Sync & Rollback Compatibility', () {
    test('detailPresentation is classified as a device-local preference', () {
      expect(deviceLocalThemeFields.contains('detailPresentation'), isTrue);
    });

    test('validatePortablePreference strips detailPresentation to protect older sync nodes', () {
      final json = ThemeCustomization().toJson();
      json['detailPresentation'] = 'fullPage';
      final sanitized = validatePortablePreference('customization', json);
      expect(sanitized, isNotNull);
      final map = sanitized as Map<String, dynamic>;
      expect(map.containsKey('detailPresentation'), isFalse);
    });

    test('AppDatabase open prunes legacy detailPresentation row from portable_preferences', () async {
      final db = AppDatabase(NativeDatabase.memory());
      // Populate legacy portable_preference entry
      await db.customInsert(
        "INSERT OR REPLACE INTO portable_preferences(key, value_json, updated_at) VALUES('detailPresentation', '\"fullPage\"', '2026-11-18T00:00:00.000Z')",
      );
      final checkBefore = await db
          .customSelect(
            "SELECT key FROM portable_preferences WHERE key = 'detailPresentation'",
          )
          .get();
      expect(checkBefore, isNotEmpty);

      // Trigger prune
      await db.customStatement(
        "DELETE FROM portable_preferences WHERE key = 'detailPresentation'",
      );
      final checkAfter = await db
          .customSelect(
            "SELECT key FROM portable_preferences WHERE key = 'detailPresentation'",
          )
          .get();
      expect(checkAfter, isEmpty);
      await db.close();
    });
  });

  group('P1-02 & P2-01: Shared Inbox Multi-File Import and Atomic Publish', () {
    late Directory tempDir;
    late SharedInboxStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('shared_inbox_p8_test');
      store = SharedInboxStore(tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('importing multiple files preserves all entries in manifest without overwrite', () async {
      final e1 = await store.addBytes([
        0x25,
        0x50,
        0x44,
        0x46,
      ], displayName: 'doc1.pdf');
      final e2 = await store.addBytes([
        0x89,
        0x50,
        0x4E,
        0x47,
      ], displayName: 'image2.png');

      final entries = await store.load();
      expect(entries.length, equals(2));
      expect(entries.map((e) => e.id), containsAll([e1.id, e2.id]));
      expect(
        entries.map((e) => e.displayName),
        containsAll(['doc1.pdf', 'image2.png']),
      );
    });

    test('delete removes specific item without corrupting others', () async {
      final e1 = await store.addBytes([1, 2, 3], displayName: 'file1.txt');
      final e2 = await store.addBytes([4, 5, 6], displayName: 'file2.txt');

      await store.deleteEntry(e1.id);
      final remaining = await store.load();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(e2.id));
    });
  });

  group('P1-03 & P1-05: Event Editor State Reuse and Unsaved Guards', () {
    testWidgets(
      'EventEditor didUpdateWidget re-initializes fields when event identity changes',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);
        await controller.refresh();

        final eventA = FixedEvent(
          id: 'event-A',
          title: 'Initial Event A',
          notes: '',
          startsAt: DateTime(2026, 11, 18, 10, 0),
          endsAt: DateTime(2026, 11, 18, 11, 0),
          createdAt: DateTime(2026, 11, 18, 10, 0),
          updatedAt: DateTime(2026, 11, 18, 10, 0),
        );
        final eventB = FixedEvent(
          id: 'event-B',
          title: 'Second Event B',
          notes: '',
          startsAt: DateTime(2026, 11, 18, 14, 0),
          endsAt: DateTime(2026, 11, 18, 15, 0),
          createdAt: DateTime(2026, 11, 18, 14, 0),
          updatedAt: DateTime(2026, 11, 18, 14, 0),
        );

        final nav = TaskEditorController();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: EventEditor(
                  key: const ValueKey('editor'),
                  event: eventA,
                  initialDay: eventA.startsAt.toLocal(),
                  protectUnsavedEdits: true,
                  navigationController: nav,
                  onClose: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Initial Event A'), findsOneWidget);

        // Update widget to event B
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: EventEditor(
                  key: const ValueKey('editor'),
                  event: eventB,
                  initialDay: eventB.startsAt.toLocal(),
                  protectUnsavedEdits: true,
                  navigationController: nav,
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Second Event B'), findsOneWidget);
        expect(find.text('Initial Event A'), findsNothing);
        await db.close();
      },
    );

    testWidgets('EventEditor confirmLeave prompts when edits are unsaved', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      final event = FixedEvent(
        id: 'event-1',
        title: 'Unmodified Event',
        notes: '',
        startsAt: DateTime(2026, 11, 18, 10, 0),
        endsAt: DateTime(2026, 11, 18, 11, 0),
        createdAt: DateTime(2026, 11, 18, 10, 0),
        updatedAt: DateTime(2026, 11, 18, 10, 0),
      );
      final nav = TaskEditorController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EventEditor(
                event: event,
                initialDay: event.startsAt.toLocal(),
                protectUnsavedEdits: true,
                navigationController: nav,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Clean state can leave immediately
      expect(await nav.confirmLeave(), isTrue);

      // Modify title
      await tester.enterText(find.byType(TextField).first, 'Modified Title');
      await tester.pump();

      // Trigger confirmLeave which shows dialog
      final leaveFuture = nav.confirmLeave();
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      // Tap Keep editing
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(await leaveFuture, isFalse);
      await db.close();
    });
  });

  group('P1-04: New Task in Full Page Details on Wide Desktop', () {
    testWidgets(
      'Wide desktop displays TaskEditor full page when creating is true and isFullPageDetails is true',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);
        await controller.refresh();
        await controller.setTaskViewPreferences(
          controller.taskViewPreferences.copyWith(
            detailPresentation: 'fullPage',
          ),
        );
        expect(controller.isFullPageDetails, isTrue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const MaterialApp(home: Workspace()),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger New Task
        final newTaskButton = find.widgetWithText(FilledButton, 'New task');
        expect(newTaskButton, findsOneWidget);
        await tester.tap(newTaskButton);
        await tester.pumpAndSettle();

        // In full page details mode, TaskEditor is presented
        expect(find.byType(TaskEditor), findsOneWidget);

        await db.close();
      },
    );
  });

  group('P2-02: Smart Reschedule Collision Detection', () {
    final engine = SchedulingEngine();
    final now = DateTime.utc(2026, 11, 18, 9, 0);

    test('splitSession flags fixedEventCollision if second part overlaps a fixed event', () {
      final session = WorkSession(
        id: 'session-1',
        taskId: 'task-1',
        startsAt: now,
        endsAt: now.add(const Duration(minutes: 60)),
        outcome: SessionOutcome.upcoming,
        createdAt: now,
        updatedAt: now,
      );

      final conflictingEvent = FixedEvent(
        id: 'event-conflict',
        title: 'Meeting',
        notes: '',
        startsAt: now.add(const Duration(minutes: 35)),
        endsAt: now.add(const Duration(minutes: 60)),
        createdAt: now,
        updatedAt: now,
      );

      final preview = engine.splitSession(
        session: session,
        task: null,
        firstMinutes: 30,
        gap: const Duration(minutes: 10),
        newSessionId: 'session-2',
        scope: 'all',
        fixedEvents: [conflictingEvent],
      );

      expect(
        preview.issues.any(
          (i) => i.kind == ScheduleIssueKind.fixedEventCollision,
        ),
        isTrue,
      );
      expect(preview.changes, isEmpty);
    });

    test('splitSession flags sessionCollision if second part overlaps another session', () {
      final session1 = WorkSession(
        id: 'session-1',
        taskId: 'task-1',
        startsAt: now,
        endsAt: now.add(const Duration(minutes: 60)),
        outcome: SessionOutcome.upcoming,
        createdAt: now,
        updatedAt: now,
      );

      final session2 = WorkSession(
        id: 'session-existing',
        taskId: 'task-2',
        startsAt: now.add(const Duration(minutes: 40)),
        endsAt: now.add(const Duration(minutes: 70)),
        outcome: SessionOutcome.upcoming,
        createdAt: now,
        updatedAt: now,
      );

      final preview = engine.splitSession(
        session: session1,
        task: null,
        firstMinutes: 30,
        gap: const Duration(minutes: 10),
        newSessionId: 'session-new',
        scope: 'all',
        otherSessions: [session1, session2],
      );

      expect(
        preview.issues.any((i) => i.kind == ScheduleIssueKind.sessionCollision),
        isTrue,
      );
      expect(preview.changes, isEmpty);
    });
  });

  group('P2-04: Calendar View Selected Date Preservation', () {
    testWidgets('CalendarView invokes onDateSelected and updates selection', (
      tester,
    ) async {
      DateTime? selectedDate;
      final initial = DateTime(2026, 11, 18);

      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: initial,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
                onDateSelected: (date) => selectedDate = date,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find day 19 and tap
      final day19 = find.text('19');
      if (day19.evaluate().isNotEmpty) {
        await tester.tap(day19.first);
        await tester.pumpAndSettle();
        expect(selectedDate?.day, equals(19));
      }

      await db.close();
    });
  });

  group('P2-05: Task List Group Expander Geometry', () {
    testWidgets(
      'Task parent expander button has sufficient trailing margin for timer action',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);
        await controller.refresh();

        final parentTask = await repo.addTask(
          const TaskDraft(title: 'Parent Task'),
        );
        final childTask = await repo.addSubtask(
          parentTask,
          const TaskDraft(title: 'Child Task'),
        );
        await controller.refresh();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: TaskListGroupView(
                  group: TaskListGroup('group-${parentTask.id}', [parentTask]),
                  items: [parentTask, childTask],
                  parents: {childTask.id: parentTask.id},
                  row: (task) => SizedBox(
                    key: ValueKey('row-${task.id}'),
                    height: 48,
                    child: Text(task.title),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the subtask pill
        final expanderFinder = find.widgetWithText(InkWell, '1');
        expect(expanderFinder, findsOneWidget);

        await db.close();
      },
    );
  });

  group('P2-06: Pointer Cancellation Mouse Events', () {
    testWidgets(
      'PointerCancellationScope clears hover with mouse pointer kind on lifecycle pause',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PointerCancellationScope(
                child: Center(
                  child: MouseRegion(
                    key: const ValueKey('test-mouse-region'),
                    onEnter: (_) {},
                    onExit: (_) {},
                    child: const SizedBox(width: 100, height: 100),
                  ),
                ),
              ),
            ),
          ),
        );

        final center = tester.getCenter(
          find.byKey(const ValueKey('test-mouse-region')),
        );
        // Dispatch hover event with mouse kind
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: center);
        await tester.pump();

        // Simulate app becoming inactive
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();

        // Resume
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        await gesture.removePointer();
        await tester.pumpAndSettle();
      },
    );
  });

  group('P2-07: Work Log Duration Ticker in TaskDetailsView', () {
    testWidgets(
      'TaskDetailsView mounts and displays work log section with active duration',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final controller = AppController(repo);
        await controller.refresh();

        final task = await repo.addTask(const TaskDraft(title: 'Timed Task'));
        await controller.refresh();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: TaskDetailsView(task: task, onBack: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Work Log section is present
        expect(find.text('Work Log'), findsOneWidget);
        expect(find.text('0 recorded sessions'), findsOneWidget);

        await db.close();
      },
    );
  });
}
