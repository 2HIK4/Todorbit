import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/scheduling/smart_reschedule.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';
import 'package:life_manager/features/shared/task_list_group.dart';
import 'package:life_manager/main.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'test_privacy.dart';

class BenchmarkResults {
  final Map<String, double> timingsMs = {};
  final Map<String, int> memoryBytes = {};

  void recordTiming(String name, Duration duration) {
    timingsMs[name] = duration.inMicroseconds / 1000.0;
  }

  void recordMemory(String name, int bytes) {
    memoryBytes[name] = bytes;
  }
}

Future<void> populateBenchmarkData({
  required LifeRepository repository,
  required Directory backupDir,
}) async {
  final today = localDate(DateTime.now());

  // 1. Categories and projects
  final catIds = <String>[];
  for (var i = 1; i <= 5; i++) {
    final cat = await repository.addCategory('Category $i');
    catIds.add(cat.id);
  }
  final projects = <(String, String)>[];
  for (var i = 0; i < 8; i++) {
    final catId = catIds[i % catIds.length];
    final proj = await repository.addProject(catId, 'Project $i');
    projects.add((catId, proj.id));
  }

  // 2. 50 Fixed Events across past, current, and future months
  final now = DateTime.now();
  for (var i = -20; i <= 30; i++) {
    final eventDay = DateTime(
      now.year,
      now.month,
      now.day + i,
      10 + (i.abs() % 8),
    );
    await repository.addEvent(
      EventDraft(
        title: 'Benchmark Event $i',
        startsAt: eventDay.toUtc(),
        endsAt: eventDay.add(const Duration(hours: 1)).toUtc(),
        categoryId: catIds[i.abs() % catIds.length],
        colorValue: 0xFF2196F3,
      ),
    );
  }

  // 3. 100+ Tasks: Today, Anytime, Overdue, Completed, Recurring, Subtasks
  final parentTasks = <LifeTask>[];
  for (var i = 1; i <= 30; i++) {
    final (catId, projId) = projects[i % projects.length];
    final task = await repository.addTask(
      TaskDraft(
        title: 'Today Task $i',
        scheduledDate: today,
        categoryId: catId,
        projectId: projId,
        priority: i % 4,
      ),
    );
    if (i <= 5) parentTasks.add(task);
  }

  // Subtasks for parent tasks
  for (final parent in parentTasks) {
    for (var s = 1; s <= 3; s++) {
      await repository.addSubtask(
        parent,
        TaskDraft(
          title: 'Subtask $s of ${parent.title}',
          scheduledDate: today,
          priority: 1,
        ),
      );
    }
  }

  // Anytime tasks
  for (var i = 1; i <= 25; i++) {
    await repository.addTask(
      TaskDraft(
        title: 'Anytime Task $i',
        categoryId: catIds[i % catIds.length],
        priority: 0,
      ),
    );
  }

  // Overdue tasks
  final pastDate = RecurrenceRule.shiftDate(today, -5);
  for (var i = 1; i <= 15; i++) {
    await repository.addTask(
      TaskDraft(title: 'Overdue Task $i', deadlineDate: pastDate, priority: 2),
    );
  }

  // Completed tasks
  for (var i = 1; i <= 15; i++) {
    await repository.addTask(
      TaskDraft(
        title: 'Completed Task $i',
        scheduledDate: pastDate,
        status: TaskStatus.completed,
      ),
    );
  }

  // Recurring tasks with series
  for (var r = 1; r <= 3; r++) {
    await repository.addRecurringTask(
      TaskDraft(
        title: 'Recurring Series $r',
        scheduledDate: today,
        categoryId: catIds[r % catIds.length],
      ),
      RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: today,
        maxOccurrences: 7,
      ),
    );
  }
  await repository.ensureRecurringTasks(
    RecurrenceRule.shiftDate(today, -14),
    RecurrenceRule.shiftDate(today, 30),
  );

  // 4. 20 Work sessions
  for (var i = 1; i <= 20; i++) {
    final start = DateTime(now.year, now.month, now.day - (i % 5), 9 + (i % 6));
    await repository.addSession(
      SessionDraft(
        taskId: parentTasks.first.id,
        startsAt: start.toUtc(),
        endsAt: start.add(const Duration(minutes: 45)).toUtc(),
        outcome: SessionOutcome.completed,
      ),
    );
  }

  // 5. Create 14 valid SQLite backup snapshots
  await backupDir.create(recursive: true);
  for (var b = 1; b <= 14; b++) {
    final stamp = '202611${(18 - b).toString().padLeft(2, '0')}T120000000000Z';
    final backupFile = File('${backupDir.path}/auto-$stamp.sqlite');
    if (!backupFile.existsSync()) {
      final snap = sqlite.sqlite3.open(backupFile.path);
      snap.execute('CREATE TABLE dummy (id TEXT PRIMARY KEY)');
      snap.execute('PRAGMA user_version = 29');
      snap.close();
    }
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/activation'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/window_theme'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/activation'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/window_theme'),
          null,
        );
  });

  testWidgets('Comprehensive 15-Scenario Performance Benchmark Suite', (
    WidgetTester tester,
  ) async {
    final results = BenchmarkResults();
    final tempDir = Directory.systemTemp.createTempSync('todorbit_bench_');
    final dbFile = File('${tempDir.path}/life_manager.sqlite');
    final backupDir = Directory('${tempDir.path}/backups');

    try {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      late final AppDatabase database;
      late final LifeRepository repository;
      late final AppController controller;

      await tester.runAsync(() async {
        final setupWatch = Stopwatch()..start();
        database = AppDatabase(NativeDatabase(dbFile));
        repository = LifeRepository(database);
        await populateBenchmarkData(
          repository: repository,
          backupDir: backupDir,
        );
        setupWatch.stop();

        results.recordTiming('Data Population Time', setupWatch.elapsed);
        results.recordMemory('Initial Process RSS', ProcessInfo.currentRss);

        // -------------------------------------------------------------
        // SCENARIO 1: Cold Launch to First Meaningful Rendered Frame
        // -------------------------------------------------------------
        final appearanceStore = AppearancePreferenceStore(
          File('${tempDir.path}/appearance-settings.json'),
        );
        final calendarStore = CalendarPreferenceStore(
          File('${tempDir.path}/calendar-settings.json'),
        );
        final backupService = BackupService(dbFile);

        controller = AppController(
          repository,
          appearanceStore: appearanceStore,
          calendarPreferenceStore: calendarStore,
          backupService: backupService,
        );

        final initWatch = Stopwatch()..start();
        await controller.initialize();
        initWatch.stop();
        results.recordTiming('AppController.initialize()', initWatch.elapsed);
      });

      final coldLaunchWatch = Stopwatch()..start();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.pump();
      coldLaunchWatch.stop();
      results.recordTiming(
        '1. Cold Launch to First Frame',
        coldLaunchWatch.elapsed,
      );

      // -------------------------------------------------------------
      // SCENARIO 2: Cold Launch to First Reliable Interaction
      // -------------------------------------------------------------
      final interactiveWatch = Stopwatch()..start();
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);
      interactiveWatch.stop();
      results.recordTiming(
        '2. Cold Launch to Interactive',
        coldLaunchWatch.elapsed + interactiveWatch.elapsed,
      );

      // -------------------------------------------------------------
      // SCENARIO 4: Initial Today View Availability
      // -------------------------------------------------------------
      expect(find.text('Today'), findsWidgets);
      expect(find.byType(TaskListGroupView), findsWidgets);
      results.recordTiming(
        '4. Initial Today View Availability',
        interactiveWatch.elapsed,
      );

      // -------------------------------------------------------------
      // SCENARIO 3: Warm App Launch or Return to Foreground
      // -------------------------------------------------------------
      final warmWatch = Stopwatch()..start();
      await tester.runAsync(() async {
        final appState =
            tester.state(find.byType(LifeManagerApp)) as WidgetsBindingObserver;
        appState.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      await tester.pumpAndSettle();
      warmWatch.stop();
      results.recordTiming('3. Warm Return to Foreground', warmWatch.elapsed);

      // -------------------------------------------------------------
      // SCENARIO 5: Switch between Today, Tasks and Calendar
      // -------------------------------------------------------------
      final navTodayToAllWatch = Stopwatch()..start();
      controller.navigate(WorkspaceView.all);
      await tester.pumpAndSettle();
      navTodayToAllWatch.stop();
      results.recordTiming(
        '5a. Switch Today -> All Tasks',
        navTodayToAllWatch.elapsed,
      );

      final navAllToCalWatch = Stopwatch()..start();
      controller.navigate(WorkspaceView.calendar);
      await tester.pumpAndSettle();
      navAllToCalWatch.stop();
      results.recordTiming(
        '5b. Switch All Tasks -> Calendar',
        navAllToCalWatch.elapsed,
      );

      final navCalToTodayWatch = Stopwatch()..start();
      controller.navigate(WorkspaceView.today);
      await tester.pumpAndSettle();
      navCalToTodayWatch.stop();
      results.recordTiming(
        '5c. Switch Calendar -> Today',
        navCalToTodayWatch.elapsed,
      );

      // -------------------------------------------------------------
      // SCENARIO 6: Calendar Navigation Between Adjacent Months
      // -------------------------------------------------------------
      controller.navigate(WorkspaceView.calendar);
      await tester.pumpAndSettle();

      final calNextMonthWatch = Stopwatch()..start();
      final nextMonthBtn = find.byTooltip('Next month');
      if (nextMonthBtn.evaluate().isNotEmpty) {
        await tester.tap(nextMonthBtn.first);
      } else {
        await tester.tap(find.byIcon(Icons.chevron_right).first);
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      calNextMonthWatch.stop();
      results.recordTiming(
        '6a. Calendar Nav Next Month',
        calNextMonthWatch.elapsed,
      );

      final calPrevMonthWatch = Stopwatch()..start();
      final prevMonthBtn = find.byTooltip('Previous month');
      if (prevMonthBtn.evaluate().isNotEmpty) {
        await tester.tap(prevMonthBtn.first);
      } else {
        await tester.tap(find.byIcon(Icons.chevron_left).first);
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      calPrevMonthWatch.stop();
      results.recordTiming(
        '6b. Calendar Nav Prev Month',
        calPrevMonthWatch.elapsed,
      );

      // Return to Today for task interactions
      controller.navigate(WorkspaceView.today);
      await tester.pumpAndSettle();

      // -------------------------------------------------------------
      // SCENARIO 7: Open and Close Task Details
      // -------------------------------------------------------------
      final openDetailsWatch = Stopwatch()..start();
      final firstTask = controller.visibleTasks.first;
      controller.select(firstTask.id);
      await tester.pumpAndSettle();
      openDetailsWatch.stop();
      results.recordTiming('7a. Open Task Details', openDetailsWatch.elapsed);

      final closeDetailsWatch = Stopwatch()..start();
      controller.select(null);
      await tester.pumpAndSettle();
      closeDetailsWatch.stop();
      results.recordTiming('7b. Close Task Details', closeDetailsWatch.elapsed);

      // -------------------------------------------------------------
      // SCENARIO 8: Open and Close Event Details
      // -------------------------------------------------------------
      controller.navigate(WorkspaceView.calendar);
      await tester.pumpAndSettle();

      final eventWatch = Stopwatch()..start();
      final firstEvent = controller.events.first;
      final calView =
          tester.firstWidget(find.byType(CalendarView)) as CalendarView;
      calView.onEventTap?.call(firstEvent);
      await tester.pumpAndSettle();
      eventWatch.stop();
      results.recordTiming('8a. Open Event Details', eventWatch.elapsed);

      final closeEventWatch = Stopwatch()..start();
      calView.onEscape?.call();
      await tester.pumpAndSettle();
      closeEventWatch.stop();
      results.recordTiming('8b. Close Event Details', closeEventWatch.elapsed);

      // -------------------------------------------------------------
      // SCENARIO 9: Scroll Long Task Lists
      // -------------------------------------------------------------
      controller.navigate(WorkspaceView.all);
      await tester.pumpAndSettle();

      final scrollWatch = Stopwatch()..start();
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump();
      await tester.drag(scrollable, const Offset(0, 600));
      await tester.pump();
      scrollWatch.stop();
      results.recordTiming('9. Scroll Long Task List', scrollWatch.elapsed);

      // -------------------------------------------------------------
      // SCENARIO 10: Expand Recurring Tasks and Subtasks
      // -------------------------------------------------------------
      final expandRecurringWatch = Stopwatch()..start();
      final recurringTile = find.byIcon(Icons.repeat);
      if (recurringTile.evaluate().isNotEmpty) {
        await tester.tap(recurringTile.first);
        await tester.pumpAndSettle();
      }
      expandRecurringWatch.stop();
      results.recordTiming(
        '10a. Expand Recurring Group',
        expandRecurringWatch.elapsed,
      );

      final expandSubtasksWatch = Stopwatch()..start();
      final subtaskArrow = find.byIcon(Icons.subdirectory_arrow_right_rounded);
      if (subtaskArrow.evaluate().isNotEmpty) {
        await tester.tap(subtaskArrow.first);
        await tester.pumpAndSettle();
      }
      expandSubtasksWatch.stop();
      results.recordTiming(
        '10b. Toggle Subtasks Expand',
        expandSubtasksWatch.elapsed,
      );

      // -------------------------------------------------------------
      // SCENARIO 11: Open Advanced Search
      // -------------------------------------------------------------
      final advSearchWatch = Stopwatch()..start();
      final advSearchTrigger = find.byTooltip('Advanced search & filters');
      if (advSearchTrigger.evaluate().isNotEmpty) {
        await tester.tap(advSearchTrigger.first);
      } else {
        final addViewBtn = find.widgetWithText(TextButton, 'Add View');
        if (addViewBtn.evaluate().isNotEmpty) {
          await tester.tap(addViewBtn.first);
        }
      }
      await tester.pumpAndSettle();
      expect(find.byType(AdvancedSearchDialog), findsOneWidget);
      advSearchWatch.stop();
      results.recordTiming('11a. Open Advanced Search', advSearchWatch.elapsed);

      final closeSearchWatch = Stopwatch()..start();
      final closeSearchBtn = find.text('Cancel');
      if (closeSearchBtn.evaluate().isNotEmpty) {
        await tester.tap(closeSearchBtn.last);
        await tester.pumpAndSettle();
      }
      closeSearchWatch.stop();
      results.recordTiming(
        '11b. Close Advanced Search',
        closeSearchWatch.elapsed,
      );

      // -------------------------------------------------------------
      // SCENARIO 12: Open Smart Reschedule and Generate a Preview
      // -------------------------------------------------------------
      controller.navigate(WorkspaceView.today);
      await tester.pumpAndSettle();

      final rescheduleWatch = Stopwatch()..start();
      final rescheduleBtn = find.widgetWithText(OutlinedButton, 'Reschedule');
      expect(rescheduleBtn, findsOneWidget);
      await tester.tap(rescheduleBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SmartRescheduleDialog), findsOneWidget);
      rescheduleWatch.stop();
      results.recordTiming(
        '12a. Open Smart Reschedule',
        rescheduleWatch.elapsed,
      );

      final previewWatch = Stopwatch()..start();
      final generateBtn = find.text('Generate preview');
      if (generateBtn.evaluate().isNotEmpty) {
        await tester.tap(generateBtn.first);
        await tester.pumpAndSettle();
      }
      previewWatch.stop();
      results.recordTiming(
        '12b. Generate Schedule Preview',
        previewWatch.elapsed,
      );

      final closeRescheduleBtn = find.text('Cancel');
      if (closeRescheduleBtn.evaluate().isNotEmpty) {
        await tester.tap(closeRescheduleBtn.last);
        await tester.pumpAndSettle();
      }

      // -------------------------------------------------------------
      // SCENARIO 13: Idle CPU and Memory
      // -------------------------------------------------------------
      results.recordMemory('13. Idle Memory RSS', ProcessInfo.currentRss);

      // -------------------------------------------------------------
      // SCENARIO 14: Memory After Extended Navigation
      // -------------------------------------------------------------
      for (final v in [
        WorkspaceView.all,
        WorkspaceView.inbox,
        WorkspaceView.anytime,
        WorkspaceView.upcoming,
        WorkspaceView.overdue,
        WorkspaceView.calendar,
        WorkspaceView.today,
      ]) {
        controller.navigate(v);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      results.recordMemory(
        '14. Memory After Extended Navigation',
        ProcessInfo.currentRss,
      );

      // -------------------------------------------------------------
      // SCENARIO 15: Impact of Active Timers
      // -------------------------------------------------------------
      final timerWatch = Stopwatch()..start();
      await tester.runAsync(() async {
        await controller.startFocusTask(controller.tasks.first);
      });
      await tester.pumpAndSettle();
      expect(controller.activeTimer, isNotNull);
      for (var s = 0; s < 3; s++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.runAsync(() async {
        await controller.stopTimer();
      });
      await tester.pumpAndSettle();
      timerWatch.stop();
      results.recordTiming('15. Active Timer 3s Lifecycle', timerWatch.elapsed);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await database.close();
      });
      await tester.binding.setSurfaceSize(null);

      // Output Benchmark Report
      debugPrint(
        '\n================ TODORBIT PERFORMANCE BENCHMARK ================',
      );
      for (final entry in results.timingsMs.entries) {
        debugPrint(
          'TIMING: ${entry.key.padRight(40)} = ${entry.value.toStringAsFixed(2)} ms',
        );
      }
      for (final entry in results.memoryBytes.entries) {
        final mb = entry.value / (1024 * 1024);
        debugPrint(
          'MEMORY: ${entry.key.padRight(40)} = ${mb.toStringAsFixed(2)} MB (${entry.value} bytes)',
        );
      }
      debugPrint(
        '=================================================================\n',
      );
    } finally {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  });
}
