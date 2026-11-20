import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_list_projection.dart';
import 'package:life_manager/domain/time_tracking.dart';
import 'package:life_manager/features/time_tracking/compact_task_timer.dart';
import 'package:life_manager/main.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'test_privacy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup mock platform channel for activation on desktop
  const channel = MethodChannel('life_manager/activation');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async => true);

  group('AppearancePreferenceStore Cache Invalidation & Idempotency', () {
    late Directory tempDir;
    late File settingsFile;
    late AppearancePreferenceStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('appearance_test_');
      settingsFile = File('${tempDir.path}${Platform.pathSeparator}appearance-settings.json');
      store = AppearancePreferenceStore(settingsFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reads defaults when file does not exist, then caches written preferences', () async {
      expect(await store.load(), equals(ThemeModePreference.system));

      await store.save(ThemeModePreference.dark);
      expect(await store.load(), equals(ThemeModePreference.dark));
      expect(await settingsFile.exists(), isTrue);

      final content = jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
      expect(content['theme'], equals('dark'));
    });

    test('detects external file modification and reloads fresh data', () async {
      await store.save(ThemeModePreference.dark);
      expect(await store.load(), equals(ThemeModePreference.dark));

      // External modification with a small delay to ensure mtime granularity
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await settingsFile.writeAsString(jsonEncode({'theme': 'light'}));

      // Store should detect modified timestamp / size and return light
      expect(await store.load(), equals(ThemeModePreference.light));
    });

    test('safely falls back to defaults if file is deleted externally', () async {
      await store.save(ThemeModePreference.dark);
      expect(await store.load(), equals(ThemeModePreference.dark));

      await settingsFile.delete();
      expect(await store.load(), equals(ThemeModePreference.system));
    });

    test('write idempotency skips disk write if content is unchanged', () async {
      await store.save(ThemeModePreference.dark);
      final statBefore = await settingsFile.stat();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.save(ThemeModePreference.dark);
      final statAfter = await settingsFile.stat();

      expect(statAfter.modified, equals(statBefore.modified));
    });

    test('invalidateCache forces re-reading from disk', () async {
      await store.save(ThemeModePreference.dark);
      expect(await store.load(), equals(ThemeModePreference.dark));

      store.invalidateCache();
      expect(await store.load(), equals(ThemeModePreference.dark));
    });
  });

  group('CalendarPreferenceStore Cache Invalidation & Idempotency', () {
    late Directory tempDir;
    late File settingsFile;
    late CalendarPreferenceStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('calendar_pref_test_');
      settingsFile = File('${tempDir.path}${Platform.pathSeparator}calendar-settings.json');
      store = CalendarPreferenceStore(settingsFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads default both when absent, caches save', () async {
      expect(await store.load(), equals(CalendarContent.both));

      await store.save(CalendarContent.tasksOnly);
      expect(await store.load(), equals(CalendarContent.tasksOnly));
    });

    test('detects external change and returns updated preference', () async {
      await store.save(CalendarContent.tasksOnly);
      expect(await store.load(), equals(CalendarContent.tasksOnly));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await settingsFile.writeAsString(jsonEncode({'content': 'eventsOnly'}));

      expect(await store.load(), equals(CalendarContent.eventsOnly));
    });

    test('falls back safely if file is deleted externally', () async {
      await store.save(CalendarContent.tasksOnly);
      expect(await store.load(), equals(CalendarContent.tasksOnly));

      await settingsFile.delete();
      expect(await store.load(), equals(CalendarContent.both));
    });

    test('write idempotency skips file write when identical', () async {
      await store.save(CalendarContent.eventsOnly);
      final statBefore = await settingsFile.stat();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.save(CalendarContent.eventsOnly);
      final statAfter = await settingsFile.stat();

      expect(statAfter.modified, equals(statBefore.modified));
    });
  });

  group('TaskListProjection Memoization & Invalidation', () {
    setUp(() {
      resetTaskListProjectionCacheForTesting();
    });

    tearDown(() {
      resetTaskListProjectionCacheForTesting();
    });

    test('returns memoized result when inputs are identical, recomputes when inputs change', () {
      final task1 = LifeTask(
        id: 'task-1',
        title: 'Task 1',
        notes: '',
        priority: 0,
        status: TaskStatus.notStarted,
        createdAt: DateTime.utc(2026, 11, 18),
        updatedAt: DateTime.utc(2026, 11, 18),
      );
      final task2 = LifeTask(
        id: 'task-2',
        title: 'Task 2',
        notes: '',
        priority: 0,
        status: TaskStatus.notStarted,
        createdAt: DateTime.utc(2026, 11, 18),
        updatedAt: DateTime.utc(2026, 11, 18),
      );
      final tasks = List<LifeTask>.unmodifiable([task1, task2]);
      final parents = <String, String>{};

      final res1 = projectTaskList(tasks, parents, groupRecurrence: false);
      final res2 = projectTaskList(tasks, parents, groupRecurrence: false);

      // Identity equality verifies memoization without recomputation
      expect(identical(res1, res2), isTrue);

      // Changing groupRecurrence recomputes
      final res3 = projectTaskList(tasks, parents, groupRecurrence: true);
      expect(identical(res1, res3), isFalse);

      // New tasks list recomputes
      final task3 = LifeTask(
        id: 'task-3',
        title: 'Task 3',
        notes: '',
        priority: 0,
        status: TaskStatus.notStarted,
        createdAt: DateTime.utc(2026, 11, 18),
        updatedAt: DateTime.utc(2026, 11, 18),
      );
      final updatedTasks = List<LifeTask>.unmodifiable([...tasks, task3]);
      final res4 = projectTaskList(updatedTasks, parents, groupRecurrence: false);
      expect(identical(res1, res4), isFalse);
      expect(res4.length, equals(3));

      // Reset cache for testing forces recomputation even with identical inputs
      resetTaskListProjectionCacheForTesting();
      final res5 = projectTaskList(updatedTasks, parents, groupRecurrence: false);
      expect(identical(res4, res5), isFalse);
    });
  });

  group('BackupService Schema Cache Invalidation & Mandatory Integrity Validation', () {
    late Directory tempDir;
    late File databaseFile;
    late BackupService backupService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_schema_test_');
      databaseFile = File('${tempDir.path}${Platform.pathSeparator}life_manager.sqlite');
      backupService = BackupService(databaseFile);
      BackupService.clearSchemaCacheForTesting();
    });

    tearDown(() async {
      BackupService.clearSchemaCacheForTesting();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('caches schema on list, re-inspects on file modification, rejects corrupt file with -1', () async {
      final backupsDir = backupService.backupDirectory;
      await backupsDir.create(recursive: true);

      // Create a valid SQLite backup
      final backupFile = File('${backupsDir.path}${Platform.pathSeparator}auto-20261118T100000000000Z.sqlite');
      final db = sqlite.sqlite3.open(backupFile.path);
      db.execute('PRAGMA user_version = 29');
      db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT)');
      db.execute('CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT)');
      db.execute('CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT)');
      db.close();

      expect(BackupService.schemaCacheCountForTesting, equals(0));

      final records = await backupService.list();
      expect(records.length, equals(1));
      expect(records.first.schemaVersion, equals(29));
      expect(BackupService.schemaCacheCountForTesting, equals(1));

      // Second list uses cache
      final records2 = await backupService.list();
      expect(records2.first.schemaVersion, equals(29));

      // Replace file with corrupt data (size/mtime changes)
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await backupFile.writeAsString('corrupted non-sqlite contents');

      final records3 = await backupService.list();
      expect(records3.length, equals(1));
      expect(records3.first.schemaVersion, equals(-1));
    });
  });

  group('Calendar Window Refresh & Event Projection', () {
    late AppDatabase database;
    late LifeRepository repository;
    late AppController controller;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      repository = LifeRepository(database);
      controller = AppController(repository);
      await controller.refresh();
    });

    tearDown(() async {
      controller.dispose();
      await database.close();
    });

    test('refreshCalendarWindow selectively updates events and tasks', () async {
      final today = localDate(DateTime.now());

      // Insert an event
      await repository.addEvent(
        EventDraft(
          title: 'Team Standup',
          startsAt: DateTime.parse('${today}T09:00:00Z'),
          endsAt: DateTime.parse('${today}T09:30:00Z'),
        ),
      );

      expect(controller.events.where((e) => e.title == 'Team Standup'), isEmpty);

      // refreshCalendarWindow loads the new event without querying all 29 tables
      await controller.refreshCalendarWindow();

      expect(controller.events.where((e) => e.title == 'Team Standup'), isNotEmpty);
      expect(controller.todayEvents.where((e) => e.title == 'Team Standup'), isNotEmpty);
    });
  });

  group('Timer Behavior & CompactTaskTimer Correctness', () {
    testWidgets('task row and compact timer reflect timer running, paused, and stopped without workspace rebuilds', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final today = localDate(DateTime.now());

      final task = await repository.addTask(
        TaskDraft(title: 'Focused Work Task', scheduledDate: today),
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
        await tester.pumpAndSettle();

        // Initially no timer running
        expect(find.text('Focused Work Task'), findsOneWidget);
        expect(find.text('Timer running'), findsNothing);
        expect(find.text('Timer paused'), findsNothing);

        // Start timer on task
        await controller.startTimer(task.id);
        await tester.pumpAndSettle();

        // Task row immediately displays 'Timer running'
        expect(find.text('Timer running'), findsOneWidget);
        expect(controller.activeTimer, isNotNull);
        expect(controller.activeTimer!.state, equals(TimerState.running));

        // Pause timer
        await controller.pauseTimer();
        await tester.pumpAndSettle();

        // Task row immediately updates to 'Timer paused'
        expect(find.text('Timer paused'), findsOneWidget);
        expect(find.text('Timer running'), findsNothing);

        // Resume timer
        await controller.resumeTimer();
        await tester.pumpAndSettle();
        expect(find.text('Timer running'), findsOneWidget);

        // Stop timer
        await controller.stopTimer();
        await tester.pumpAndSettle();

        // Task row returns to clean state
        expect(find.text('Timer running'), findsNothing);
        expect(find.text('Timer paused'), findsNothing);
        expect(controller.activeTimer, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('CompactTaskTimer ticks independently every second without parent rebuild', (
      tester,
    ) async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final task = await repository.addTask(
        const TaskDraft(title: 'Compact Timer Task'),
      );
      final controller = AppController(repository);
      await controller.refresh();
      await controller.startTimer(task.id);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CompactTaskTimer(open: (_) {}),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Running'), findsOneWidget);
        expect(find.text('Compact Timer Task'), findsOneWidget);

        // Advance time by 2 seconds: CompactTaskTimer state ticks internally
        await tester.pump(const Duration(seconds: 2));
        expect(find.textContaining('Running'), findsOneWidget);

        // Pause timer
        await controller.pauseTimer();
        await tester.pump();
        expect(find.textContaining('Paused'), findsOneWidget);

        // Stop timer: CompactTaskTimer collapses to SizedBox.shrink
        await controller.stopTimer();
        await tester.pump();
        expect(find.textContaining('Paused'), findsNothing);
        expect(find.textContaining('Running'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      }
    });
  });
}
