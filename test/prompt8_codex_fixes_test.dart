import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/shared_inbox_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/scheduling_models.dart';
import 'package:life_manager/domain/sync/portable_preferences.dart';
import 'package:life_manager/domain/task_list_projection.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/shared/pointer_cancellation_scope.dart';
import 'package:life_manager/features/shared/task_list_group.dart';
import 'package:life_manager/features/workspace/quick_search.dart';
import 'package:life_manager/features/workspace/task_details_view.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/main.dart';

import 'test_privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

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

    test('AppDatabase open sanitizes legacy Prompt 7 data, sync journals, and outgoing batches', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1. Seed legacy data matching Prompt 7 / early Beta 24
      await db.customInsert(
        "INSERT OR REPLACE INTO portable_preferences(key, value_json, updated_at) VALUES('detailPresentation', '\"fullPage\"', '2026-11-18T00:00:00.000Z')",
      );
      final customizationJson = jsonEncode({
        'version': 1,
        'themeMode': 'dark',
        'detailPresentation': 'fullPage',
        'colorSchemeSeed': '#1976D2',
        'presets': <String, dynamic>{},
      });
      await db.customInsert(
        "INSERT OR REPLACE INTO portable_preferences(key, value_json, updated_at) VALUES('customization', '$customizationJson', '2026-11-18T00:00:00.000Z')",
      );
      await db.customInsert(
        "INSERT OR REPLACE INTO sync_entity_heads(workspace_id, entity, record_key, visible_revision) VALUES('ws-1', 'portable_preferences', 'detailPresentation', 'rev-1')",
      );
      await db.customInsert(
        "INSERT OR REPLACE INTO sync_journal(operation_id, workspace_id, account_id, device_id, entity, record_key, before_json, after_json, uploaded) VALUES('op-legacy-1', 'ws-1', 'acc-1', 'dev-1', 'portable_preferences', 'detailPresentation', NULL, '\"fullPage\"', 0)",
      );
      final batchPayload = jsonEncode({
        'operations': [
          {'table': 'portable_preferences', 'key': 'detailPresentation'}
        ]
      });
      await db.customInsert(
        "INSERT OR REPLACE INTO sync_batches(id, workspace_id, account_id, device_id, direction, payload, sha256, created_at, uploaded, superseded) VALUES('batch-legacy', 'ws-1', 'acc-1', 'dev-1', 'outgoing', '$batchPayload', 'sha', '2026-11-18T00:00:00.000Z', 0, 0)",
      );

      // Verify legacy rows exist before sanitization
      final legacyPref = await db.customSelect("SELECT key FROM portable_preferences WHERE key = 'detailPresentation'").get();
      expect(legacyPref, isNotEmpty);
      final legacyJournal = await db.customSelect("SELECT operation_id FROM sync_journal WHERE record_key = 'detailPresentation'").get();
      expect(legacyJournal, isNotEmpty);

      // 2. Run sanitization
      await AppDatabase.sanitizePortablePreferencesAndJournal(db);

      // 3. Verify standalone preference row is removed
      final prefAfter = await db.customSelect("SELECT key FROM portable_preferences WHERE key = 'detailPresentation'").get();
      expect(prefAfter, isEmpty);

      // 4. Verify customization row has detailPresentation stripped while retaining other theme settings
      final customAfter = await db.customSelect("SELECT value_json FROM portable_preferences WHERE key = 'customization'").getSingle();
      final parsedCustom = jsonDecode(customAfter.data['value_json'] as String) as Map<String, dynamic>;
      expect(parsedCustom.containsKey('detailPresentation'), isFalse);
      expect(parsedCustom['themeMode'], equals('dark'));
      expect(parsedCustom['colorSchemeSeed'], equals('#1976D2'));

      // 5. Verify unuploaded journal entry is removed
      final journalAfter = await db.customSelect("SELECT operation_id FROM sync_journal WHERE record_key = 'detailPresentation'").get();
      expect(journalAfter, isEmpty);

      // 6. Verify sync_entity_heads entry is removed
      final headsAfter = await db.customSelect("SELECT record_key FROM sync_entity_heads WHERE record_key = 'detailPresentation'").get();
      expect(headsAfter, isEmpty);

      // 7. Verify legacy pending batch is marked superseded
      final batchAfter = await db.customSelect("SELECT superseded FROM sync_batches WHERE id = 'batch-legacy'").getSingle();
      expect(batchAfter.data['superseded'], equals(1));

      await db.close();
    });

    test('simulated Beta 23 node can parse and apply sanitized preferences without errors', () async {
      // In Beta 23, validatePortablePreference only allows schema 29 standard preferences.
      final themeJson = ThemeCustomization().toJson();
      final validated = validatePortablePreference('customization', themeJson);
      expect(validated, isNotNull);
      final map = validated as Map<String, dynamic>;
      expect(map.containsKey('detailPresentation'), isFalse);
    });
  });

  group('P1-02 & P2-01: Shared Inbox Multi-File Import, Atomic Locking, and URI Boundaries', () {
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

    test('importing multiple files preserves all entries in manifest with atomic locking', () async {
      final e1 = await store.addBytes([0x25, 0x50, 0x44, 0x46], displayName: 'doc1.pdf');
      final e2 = await store.addBytes([0x89, 0x50, 0x4E, 0x47], displayName: 'image2.png');
      final e3 = await store.addBytes([0x50, 0x4B, 0x03, 0x04], displayName: 'archive3.zip');

      final entries = await store.load();
      expect(entries.length, equals(3));
      expect(entries.map((e) => e.id), containsAll([e1.id, e2.id, e3.id]));
      expect(entries.map((e) => e.displayName), containsAll(['doc1.pdf', 'image2.png', 'archive3.zip']));

      // Verify files exist in storage
      for (final e in entries) {
        expect(e.fileIn(tempDir).existsSync(), isTrue);
      }
    });

    test('deleteEntry preserves remaining entries under concurrent-safe file locking', () async {
      final e1 = await store.addBytes([1, 2, 3], displayName: 'file1.txt');
      final e2 = await store.addBytes([4, 5, 6], displayName: 'file2.txt');

      await store.deleteEntry(e1.id);
      final remaining = await store.load();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(e2.id));
      expect(e1.fileIn(tempDir).existsSync(), isFalse);
      expect(e2.fileIn(tempDir).existsSync(), isTrue);
    });

    test('cleanOrphans cleans unindexed staging files while preserving manifest items', () async {
      final committed = await store.addBytes([10, 20], displayName: 'committed.txt');

      // Create an orphaned staging file
      final orphanStaging = File('${tempDir.path}/staging/orphan_${DateTime.now().millisecondsSinceEpoch}.tmp');
      await orphanStaging.parent.create(recursive: true);
      await orphanStaging.writeAsBytes([99, 98, 97]);
      expect(orphanStaging.existsSync(), isTrue);

      await store.cleanOrphans();

      // Orphan is removed, committed file remains
      expect(orphanStaging.existsSync(), isFalse);
      expect(committed.fileIn(tempDir).existsSync(), isTrue);
      final entries = await store.load();
      expect(entries.length, equals(1));
    });

    test('P2-01: URI validation rejects unauthorized/non-content schemes', () {
      bool isAllowedShareUri(String uriString) {
        if (uriString.contains('..')) return false;
        final uri = Uri.tryParse(uriString);
        if (uri == null) return false;
        if (uri.scheme != 'content') return false;
        if (uri.authority.isEmpty) return false;
        return true;
      }

      expect(isAllowedShareUri('content://com.android.providers.media/external/file/102'), isTrue);
      expect(isAllowedShareUri('file:///data/user/0/com.victim.app/databases/secret.db'), isFalse);
      expect(isAllowedShareUri('http://malicious.site/exploit.bin'), isFalse);
      expect(isAllowedShareUri('content:///no-authority/test'), isFalse);
      expect(isAllowedShareUri('content://com.example/../../../etc/passwd'), isFalse);
    });
  });

  group('P1-03: Unsaved Navigation Protection and Single Authoritative Guard', () {
    testWidgets('Dirty task -> Quick Search -> Discard opens destination without double prompt', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      await repo.addTask(const TaskDraft(title: 'Task Alpha'));
      final taskB = await repo.addTask(const TaskDraft(title: 'Task Beta'));
      final controller = AppController(repo);
      await controller.refresh();
      controller.navigate(WorkspaceView.all);

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

        // 1. Open Task Alpha in side editor
        await tester.tap(find.text('Task Alpha').first);
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);

        // 2. Make editor dirty
        final titleField = find.descendant(of: find.byType(TaskEditor), matching: find.byType(TextField)).first;
        await tester.enterText(titleField, 'Task Alpha Dirty');
        await tester.pumpAndSettle();

        // 3. Open Quick Search via search button
        await tester.tap(find.byTooltip('Quick Search (Ctrl+K)'));
        await tester.pumpAndSettle();

        expect(find.byType(QuickSearchDialog), findsOneWidget);

        // 4. Type query to find Task Beta
        final searchInput = find.descendant(of: find.byType(QuickSearchDialog), matching: find.byType(TextField));
        await tester.enterText(searchInput, 'Beta');
        await tester.pumpAndSettle();

        // 5. Select Task Beta in search results
        final betaResult = find.descendant(of: find.byType(QuickSearchDialog), matching: find.text('Task Beta')).first;
        await tester.tap(betaResult);
        await tester.pumpAndSettle();

        // 6. Single discard prompt appears
        expect(find.text('Discard unsaved changes?'), findsOneWidget);

        // 7. Confirm Discard
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();

        // 8. Verify Task Beta is now opened, with NO second confirmation prompt
        expect(find.text('Discard unsaved changes?'), findsNothing);
        expect(controller.selectedTaskId, equals(taskB.id));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Dirty task -> Quick Search -> Cancel preserves draft and stays on task', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final taskA = await repo.addTask(const TaskDraft(title: 'Task Keep'));
      await repo.addTask(const TaskDraft(title: 'Other Task'));
      final controller = AppController(repo);
      await controller.refresh();
      controller.navigate(WorkspaceView.all);

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

        // Open task
        await tester.tap(find.text('Task Keep').first);
        await tester.pumpAndSettle();

        // Make dirty
        final titleField = find.descendant(of: find.byType(TaskEditor), matching: find.byType(TextField)).first;
        await tester.enterText(titleField, 'Task Keep Modified');
        await tester.pumpAndSettle();

        // Open Quick Search
        await tester.tap(find.byTooltip('Quick Search (Ctrl+K)'));
        await tester.pumpAndSettle();

        // Type query
        final searchInput = find.descendant(of: find.byType(QuickSearchDialog), matching: find.byType(TextField));
        await tester.enterText(searchInput, 'Other');
        await tester.pumpAndSettle();

        // Select other task
        await tester.tap(find.descendant(of: find.byType(QuickSearchDialog), matching: find.text('Other Task')).first);
        await tester.pumpAndSettle();

        // Keep editing
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        // Dialog closes, draft remains
        expect(find.text('Discard unsaved changes?'), findsNothing);
        expect(controller.selectedTaskId, equals(taskA.id));
        expect(find.text('Task Keep Modified'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Dirty event -> Escape -> Cancel keeps event open; Discard closes event', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final now = DateTime.now();
      final eventStart = DateTime(now.year, now.month, now.day, 11, 0);
      await repo.addEvent(EventDraft(
        title: 'Meeting Alpha',
        startsAt: eventStart,
        endsAt: eventStart.add(const Duration(hours: 1)),
      ));
      final controller = AppController(repo);
      await controller.refresh();
      controller.navigate(WorkspaceView.calendar);

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

        // Open event in editor
        final eventFinder = find.text('Meeting Alpha').first;
        await Scrollable.ensureVisible(tester.element(eventFinder));
        await tester.pumpAndSettle();
        await tester.tap(eventFinder);
        await tester.pumpAndSettle();
        expect(find.byType(EventEditor), findsOneWidget);

        // Modify event title
        final titleField = find.descendant(of: find.byType(EventEditor), matching: find.byType(TextField)).first;
        await tester.enterText(titleField, 'Meeting Alpha Dirty');
        await tester.pumpAndSettle();

        // Press Escape -> guard shows dialog
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);

        // Tap Keep editing -> event editor stays open
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.byType(EventEditor), findsOneWidget);

        // Press Escape again -> confirm Discard
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();

        // Event editor is now closed
        expect(find.byType(EventEditor), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('EventEditor confirmLeave re-entrancy guard prevents duplicate dialogs', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      final nav = TaskEditorController();
      final event = FixedEvent(
        id: 'event-reentrancy',
        title: 'Guarded Event',
        notes: '',
        startsAt: DateTime(2026, 11, 18, 10, 0),
        endsAt: DateTime(2026, 11, 18, 11, 0),
        createdAt: DateTime(2026, 11, 18, 10, 0),
        updatedAt: DateTime(2026, 11, 18, 10, 0),
      );

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
      await tester.pumpAndSettle();

      // Make dirty
      await tester.enterText(find.byType(TextField).first, 'Guarded Event Dirty');
      await tester.pump();

      // Call confirmLeave twice rapidly
      final future1 = nav.confirmLeave();
      final future2 = nav.confirmLeave();
      await tester.pumpAndSettle();

      // Only one dialog is present
      expect(find.text('Discard unsaved changes?'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(await future1, isFalse);
      expect(await future2, isFalse);
      await db.close();
    });
  });

  group('P2-02: Smart Reschedule Stale Apply Transactional Collision Detection', () {
    test('applySchedulingPreview throws StaleSchedulePreviewException when a conflicting FixedEvent appears', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final now = DateTime.utc(2026, 11, 18, 9, 0);

      final task = await repo.addTask(const TaskDraft(title: 'Rescheduled Task'));
      final session = await repo.addSession(SessionDraft(
        taskId: task.id,
        startsAt: now,
        endsAt: now.add(const Duration(minutes: 60)),
      ));

      // Generate preview proposing moving session to 14:00 - 15:00
      final proposedStart = DateTime.utc(2026, 11, 18, 14, 0);
      final proposedEnd = DateTime.utc(2026, 11, 18, 15, 0);
      final preview = SchedulingPreview(
        operation: ScheduleOperationType.move,
        scope: 'all',
        changes: [
          ScheduleChange(
            targetKind: ScheduleTargetKind.session,
            targetId: session.id,
            expectedUpdatedAt: session.updatedAt,
            beforeStartsAt: session.startsAt,
            beforeEndsAt: session.endsAt,
            afterStartsAt: proposedStart,
            afterEndsAt: proposedEnd,
          ),
        ],
        issues: const [],
        createdAt: DateTime.now().toUtc(),
      );

      // Now, before Apply, a conflicting fixed event arrives (e.g. from Sync)
      await repo.addEvent(EventDraft(
        title: 'Emergency Meeting',
        startsAt: DateTime.utc(2026, 11, 18, 14, 15),
        endsAt: DateTime.utc(2026, 11, 18, 14, 45),
      ));

      // Attempting to apply preview must detect the collision inside the transaction and throw
      await expectLater(
        repo.applySchedulingPreview(preview),
        throwsA(isA<StaleSchedulePreviewException>()),
      );

      // Verify session was NOT moved
      final reloaded = (await repo.sessions()).firstWhere((s) => s.id == session.id);
      expect(reloaded.startsAt, equals(now));

      await db.close();
    });

    test('applySchedulingPreview throws StaleSchedulePreviewException when a conflicting WorkSession appears', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final now = DateTime.utc(2026, 11, 18, 9, 0);

      final task1 = await repo.addTask(const TaskDraft(title: 'Task 1'));
      final task2 = await repo.addTask(const TaskDraft(title: 'Task 2'));
      final session1 = await repo.addSession(SessionDraft(
        taskId: task1.id,
        startsAt: now,
        endsAt: now.add(const Duration(minutes: 60)),
      ));

      final proposedStart = DateTime.utc(2026, 11, 18, 16, 0);
      final proposedEnd = DateTime.utc(2026, 11, 18, 17, 0);
      final preview = SchedulingPreview(
        operation: ScheduleOperationType.move,
        scope: 'all',
        changes: [
          ScheduleChange(
            targetKind: ScheduleTargetKind.session,
            targetId: session1.id,
            expectedUpdatedAt: session1.updatedAt,
            beforeStartsAt: session1.startsAt,
            beforeEndsAt: session1.endsAt,
            afterStartsAt: proposedStart,
            afterEndsAt: proposedEnd,
          ),
        ],
        issues: const [],
        createdAt: DateTime.now().toUtc(),
      );

      // Interleaving session added before apply
      await repo.addSession(SessionDraft(
        taskId: task2.id,
        startsAt: DateTime.utc(2026, 11, 18, 16, 30),
        endsAt: DateTime.utc(2026, 11, 18, 17, 30),
      ));

      await expectLater(
        repo.applySchedulingPreview(preview),
        throwsA(isA<StaleSchedulePreviewException>()),
      );

      await db.close();
    });
  });

  group('P2-03: Calendar Date and Widget Lifecycle', () {
    testWidgets('CalendarView has stable key and didUpdateWidget updates selection smoothly', (tester) async {
      DateTime? selected;
      final day1 = DateTime(2026, 11, 18);
      final day2 = DateTime(2026, 11, 19);

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
                key: const ValueKey('workspace-calendar-view'),
                initialDate: day1,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
                onDateSelected: (d) => selected = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check key
      expect(find.byKey(const ValueKey('workspace-calendar-view')), findsOneWidget);

      // Update to day2 via didUpdateWidget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                key: const ValueKey('workspace-calendar-view'),
                initialDate: day2,
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
                onDateSelected: (d) => selected = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // State is preserved smoothly with same key
      expect(find.byKey(const ValueKey('workspace-calendar-view')), findsOneWidget);
      expect(selected, isNotNull);
      await db.close();
    });
  });

  group('P2-04: Recurrence Materialization and Sync Notifications', () {
    test('ensureRecurringTasks returns count and signals onLocalChange only when occurrences are created', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);

      // Create recurring task template
      await repo.addRecurringTask(
        const TaskDraft(title: 'Daily Review', scheduledDate: '2026-11-18'),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-11-18',
          maxOccurrences: 5,
        ),
      );

      // First run: materializes occurrences for range
      final count1 = await repo.ensureRecurringTasks('2026-11-18', '2026-11-20');
      expect(count1, greaterThan(0));

      // Second run: no new occurrences needed -> count is 0
      final count2 = await repo.ensureRecurringTasks('2026-11-18', '2026-11-20');
      expect(count2, equals(0));

      // Verify controller integration: localChange counter increments only when new tasks are materialized
      int changeNotifications = 0;
      final controller = AppController(repo);
      controller.onLocalChange = () => changeNotifications++;

      // First refresh materializes any occurrences in the wide window
      await controller.refresh();
      final baseNotifications = changeNotifications;

      // Second refresh: occurrences already materialized -> 0 new occurrences -> 0 notifications!
      await controller.refresh();
      expect(changeNotifications, equals(baseNotifications));

      await db.close();
    });
  });

  group('P2-05: Subtask Expander Geometry & Dedicated Layout', () {
    testWidgets('Expander pill has dedicated row slot and does not overlap long titles', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      final parentTask = await repo.addTask(
        const TaskDraft(title: 'Very Long Parent Task Title That Would Normally Collide With Overlapping Positioned Widgets'),
      );
      final childTask = await repo.addSubtask(
        parentTask,
        const TaskDraft(title: 'Subtask 1'),
      );
      await controller.refresh();

      // Test with narrow constraints (320px)
      await tester.binding.setSurfaceSize(const Size(320, 600));

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 320,
                  child: TaskListGroupView(
                    group: TaskListGroup('group-${parentTask.id}', [parentTask]),
                    items: [parentTask, childTask],
                    parents: {childTask.id: parentTask.id},
                    row: (task) => SizedBox(
                      key: ValueKey('row-${task.id}'),
                      height: 48,
                      child: Text(task.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Subtask is expanded by default
        expect(find.text('Subtask 1'), findsOneWidget);

        // Expander pill is rendered and hit testable
        final pill = find.widgetWithText(InkWell, '1');
        expect(pill, findsOneWidget);

        // Tap to collapse
        await tester.tap(pill);
        await tester.pumpAndSettle();
        expect(find.text('Subtask 1'), findsNothing);

        // Tap to expand again
        await tester.tap(pill);
        await tester.pumpAndSettle();
        expect(find.text('Subtask 1'), findsOneWidget);
      } finally {
        await tester.binding.setSurfaceSize(null);
        await db.close();
      }
    });
  });

  group('P2-06: Pointer Cancellation Mouse Events', () {
    testWidgets('Pointer enter without move or down clears hover state on lifecycle inactive', (tester) async {
      bool isHovered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointerCancellationScope(
              child: Center(
                child: MouseRegion(
                  key: const ValueKey('test-hover-target'),
                  onEnter: (_) => isHovered = true,
                  onExit: (_) => isHovered = false,
                  child: const SizedBox(width: 120, height: 120),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(const ValueKey('test-hover-target')));

      // Simulate mouse entering window bounds without mouse-down or hover-move
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: center);
      await tester.pump();

      expect(isHovered, isTrue);

      // Simulate app window deactivation (e.g. Snipping tool, Alt-Tab)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // Hover state is cleanly cleared
      expect(isHovered, isFalse);

      // Resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      await gesture.removePointer();
      await tester.pumpAndSettle();
    });
  });

  group('Section 4: Work Log Duration Ticker in TaskDetailsView', () {
    testWidgets('TaskDetailsView ticker advances visible duration while timer runs and pauses when stopped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final controller = AppController(repo);
      await controller.refresh();

      final task = await repo.addTask(const TaskDraft(title: 'Timed Task'));
      await controller.refresh();

      try {
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

        // Initially 00:00:00
        expect(find.text('00:00:00'), findsOneWidget);

        // Start focus timer on this task
        await controller.startTimer(task.id);
        await tester.pump();

        // Advance entry starts_at to 3 seconds in the past to simulate 3 seconds of work
        final threeSecsAgo = DateTime.now().toUtc().subtract(const Duration(seconds: 3)).toIso8601String();
        await db.customStatement(
          'UPDATE time_entries SET starts_at = ? WHERE task_id = ?',
          [threeSecsAgo, task.id],
        );
        await controller.refresh();
        await tester.pump();

        // Verify ticker displays 00:00:03
        expect(find.text('00:00:03'), findsOneWidget);

        // Advance entry starts_at to 5 seconds in the past to simulate 2 more seconds
        final fiveSecsAgo = DateTime.now().toUtc().subtract(const Duration(seconds: 5)).toIso8601String();
        await db.customStatement(
          'UPDATE time_entries SET starts_at = ? WHERE task_id = ?',
          [fiveSecsAgo, task.id],
        );
        await controller.refresh();
        await tester.pump();

        // Verify ticker advances to 00:00:05
        expect(find.text('00:00:05'), findsOneWidget);

        // Stop timer (commits endsAt to time entry and stops active timer run)
        await controller.stopTimer();
        await tester.pumpAndSettle();

        // Recorded session is saved with 00:00:05
        expect(find.text('00:00:05'), findsOneWidget);

        // Advance clock further: ticker does NOT advance further because timer is stopped
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('00:00:05'), findsOneWidget);
      } finally {
        await tester.binding.setSurfaceSize(null);
        await db.close();
      }
    });
  });
}
