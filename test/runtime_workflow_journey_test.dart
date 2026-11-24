// runtime_workflow_journey_test.dart
// Native Windows runtime automation journey test exercising application readiness,
// synthetic task creation, editing, scheduling, completion, calendar interactions,
// application restart, and persistence verification in an isolated profile.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/data/profile_paths.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'support/profile_journey_environment.dart';

void main() {
  if (!isolatedProfileJourneys) {
    test(
      'requires explicitly isolated child environment',
      () {},
      skip: 'Run via dev runtime windows or tools/dev/test-profile-journeys.ps1 with disposable APPDATA/LOCALAPPDATA.',
    );
    return;
  }

  final profile = ProfilePaths.activeDirectory();
  final databaseFile = File('${profile.path}/life_manager.sqlite');

  Future<void> cleanDirectory() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (await profile.exists()) await profile.delete(recursive: true);
        return;
      } on FileSystemException catch (e) {
        if (e.osError?.errorCode != 32 || attempt == 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  setUp(() async {
    await cleanDirectory();
    await profile.create(recursive: true);
  });

  tearDown(() async {
    await cleanDirectory();
  });

  test('Runtime journey: task lifecycle, scheduling, completion, and restart persistence', () async {
    final now = DateTime.now().toUtc();
    final tomorrowStr = localDate(now.add(const Duration(days: 1)));
    final deadlineStr = localDate(now.add(const Duration(days: 2)));
    final nextWeekStr = localDate(now.add(const Duration(days: 7)));

    // 1. First execution phase: Startup & initial database creation
    AppDatabase? db = AppDatabase(NativeDatabase(databaseFile));
    LifeRepository repo = LifeRepository(db);

    // 2. Synthetic task creation
    final createdTask = await repo.addTask(
      TaskDraft(
        title: 'Verify Native Windows Runtime Workflow',
        notes: 'Synthetic task created during automated runtime verification',
        priority: 2,
        status: TaskStatus.notStarted,
        scheduledDate: tomorrowStr,
        deadlineDate: deadlineStr,
      ),
    );
    expect(await databaseFile.exists(), isTrue, reason: 'Database file must exist after first write operation');
    expect(createdTask.id, isNotEmpty);
    expect(createdTask.title, equals('Verify Native Windows Runtime Workflow'));
    expect(createdTask.priority, equals(2));

    // 3. Task editing & scheduling update
    await repo.updateTask(
      createdTask,
      TaskDraft(
        title: 'Updated Native Windows Runtime Workflow',
        notes: 'Added progress update notes to synthetic task',
        priority: createdTask.priority,
        status: TaskStatus.inProgress,
        scheduledDate: nextWeekStr,
        deadlineDate: deadlineStr,
      ),
    );

    final tasksAfterEdit = await repo.tasks();
    final editedTask = tasksAfterEdit.firstWhere((t) => t.id == createdTask.id);
    expect(editedTask.title, equals('Updated Native Windows Runtime Workflow'));
    expect(editedTask.notes, contains('Added progress update notes'));
    expect(editedTask.status, equals(TaskStatus.inProgress));

    // 4. Task completion
    await repo.updateTask(
      editedTask,
      TaskDraft(
        title: editedTask.title,
        notes: editedTask.notes,
        priority: editedTask.priority,
        status: TaskStatus.completed,
      ),
    );

    final tasksAfterCompletion = await repo.tasks();
    final completedTask = tasksAfterCompletion.firstWhere((t) => t.id == createdTask.id);
    expect(completedTask.status, equals(TaskStatus.completed));
    expect(completedTask.completedAt, isNotNull);

    // 5. Calendar event creation & scheduling
    final createdEvent = await repo.addEvent(
      EventDraft(
        title: 'Sprint Planning Sync',
        location: 'Virtual Conference',
        startsAt: now.add(const Duration(hours: 2)),
        endsAt: now.add(const Duration(hours: 3)),
      ),
    );
    expect(createdEvent.id, isNotEmpty);
    expect(createdEvent.title, equals('Sprint Planning Sync'));

    // 6. Graceful application shutdown simulation
    await db.close();
    db = null;

    // 7. Restart verification: Re-open SQLite directly in read-only mode to verify physical persistence
    final verifySqlite = sqlite.sqlite3.open(
      databaseFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      final taskRows = verifySqlite.select(
        'SELECT id, title, status, notes FROM tasks WHERE id = ?',
        [completedTask.id],
      );
      expect(taskRows.length, equals(1), reason: 'Completed task must persist across restart');
      final row = taskRows.first;
      expect(row['title'], equals('Updated Native Windows Runtime Workflow'));
      expect(row['status'], equals('completed'));
      expect(row['notes'], contains('Added progress update notes'));

      final eventRows = verifySqlite.select(
        'SELECT id, title, location FROM fixed_events WHERE id = ?',
        [createdEvent.id],
      );
      expect(eventRows.length, equals(1), reason: 'Calendar event must persist across restart');
      expect(eventRows.first['title'], equals('Sprint Planning Sync'));
      expect(eventRows.first['location'], equals('Virtual Conference'));
    } finally {
      verifySqlite.dispose();
    }

    // 8. Second session restart: Initialize fresh Flutter database connection
    final restartedDb = AppDatabase(NativeDatabase(databaseFile));
    final restartedRepo = LifeRepository(restartedDb);
    try {
      final allTasks = await restartedRepo.tasks();
      final loadedTask = allTasks.firstWhere((t) => t.id == completedTask.id);
      expect(loadedTask.status, equals(TaskStatus.completed));
      expect(loadedTask.title, equals('Updated Native Windows Runtime Workflow'));
    } finally {
      await restartedDb.close();
    }
  });
}
