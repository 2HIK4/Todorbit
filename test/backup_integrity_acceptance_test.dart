import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Compare every column of every populated product table, including UUIDs,
// timestamps, references, attachment bytes and historical rows. Sync-local
// bookkeeping is deliberately changed/quarantined by restore and is separate.
Map<String, Object?> productRows(File file) {
  final db = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    expect(db.select('PRAGMA quick_check').single.values.single, 'ok');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    final tables = db
        .select(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .map((row) => row['name'] as String)
        .where(
          (name) =>
              !name.startsWith('sqlite_') &&
              !name.startsWith('sync_') &&
              name != 'backup_widget_personalization',
        );
    return {
      for (final table in tables)
        table:
            db
                .select('SELECT * FROM "$table"')
                .map(
                  (row) => {
                    for (final column in row.keys)
                      column: row[column] is List<int>
                          ? base64Encode(row[column] as List<int>)
                          : row[column],
                  },
                )
                .map(jsonEncode)
                .toList()
              ..sort(),
    };
  } finally {
    db.close();
  }
}

void main() {
  test('representative snapshot restores exact records and links after reopen without duplicates', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-batch4-restore-',
    );
    final file = File('${root.path}/profile/life_manager.sqlite');
    await file.parent.create();
    var database = AppDatabase(NativeDatabase(file));
    try {
      final repo = LifeRepository(database);
      await repo.savePortablePreferences({'theme': 'dark', 'firstWeekday': 7});
      final category = await repo.addCategory('Research علوم');
      final project = await repo.addProject(
        category.id,
        'Long synthetic research project',
      );
      final parent = await repo.addTask(
        TaskDraft(
          title: 'Parent task',
          notes: 'Important original metadata',
          categoryId: category.id,
          projectId: project.id,
          scheduledDate: '2026-10-01',
          deadlineDate: '2026-11-30',
        ),
      );
      final child = await repo.addSubtask(
        parent,
        const TaskDraft(title: 'Child task'),
      );
      await repo.addChecklistItem(parent.id, 'Check references');
      await repo.setPrerequisites(child, {parent.id});
      await repo.addEvent(
        EventDraft(
          title: 'Research review',
          startsAt: DateTime.utc(2026, 10, 1, 9),
          endsAt: DateTime.utc(2026, 10, 1, 10),
          categoryId: category.id,
        ),
      );
      final session = await repo.addSession(
        SessionDraft(
          taskId: parent.id,
          startsAt: DateTime.utc(2026, 10, 1, 11),
          endsAt: DateTime.utc(2026, 10, 1, 12),
        ),
      );
      await repo.addManualTime(
        parent.id,
        session.startsAt,
        session.endsAt,
        'Actual work',
        sessionId: session.id,
      );
      final habit = await repo.addHabit(
        HabitDraft(
          title: 'Read daily',
          kind: HabitKind.binary,
          rule: RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2026-10-01',
          ),
        ),
      );
      await repo.recordHabitDay(habit, '2026-10-01', 1, notes: 'First log');
      final entry = (await repo.habitEntries()).single;
      await repo.recordHabitDay(
        habit,
        '2026-10-01',
        0,
        previous: entry,
        notes: 'Correction',
      );
      await repo.addHabitRestDay(habit, '2026-10-02');
      var goal = await repo.addGoal(
        const GoalDraft(
          title: 'Research goal',
          target: 10,
          description: 'Preserve all related records',
          startDate: '2026-10-01',
          unit: 'steps',
        ),
      );
      await repo.setGoalLinks(
        goal,
        GoalLinks(
          taskIds: {parent.id},
          projectIds: {project.id},
          habitIds: {habit.id},
        ),
      );
      goal = (await repo.goals()).single;
      await repo.addGoalMilestone(goal, 'Read sources', 3, '2026-11-10');
      await repo.addGoalMilestone(goal, 'Write summary', 7, null);
      await repo.addGoalProgress(goal, 2, 'Initial work');
      await repo.saveTaskTemplate(parent, 'Research template');
      final external = File('${root.path}/Original résumé علوم.txt');
      await external.writeAsString(
        'Original external content remains independent',
      );
      await repo.attachManagedFile(parent.id, external);
      await repo.addExternalResource(
        parent.id,
        TaskResourceKind.externalFile,
        external.path,
      );
      await repo.addExternalResource(
        parent.id,
        TaskResourceKind.externalFolder,
        root.path,
      );
      await repo.addExternalResource(
        parent.id,
        TaskResourceKind.url,
        'https://example.invalid/research',
        label: 'Research link',
      );
      final settings = File('${file.parent.path}/device-only-fixture.json');
      await settings.writeAsString('{"device":"original"}');
      final service = BackupService(file);
      final snapshot = await service.createBackup(BackupKind.manual);
      final expected = productRows(snapshot.file);
      expect((expected['tasks'] as List), hasLength(2));
      expect((expected['goal_milestones'] as List), hasLength(2));
      expect((expected['task_resources'] as List), hasLength(4));
      expect((expected['habit_entry_history'] as List), hasLength(2));
      final exported = await service.exportTo(
        File('${root.path}/export.sqlite'),
      );
      expect(productRows(exported), expected);
      final imported = await service.importSnapshot(
        exported,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await service.scheduleRestore(
        imported,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await service.cancelScheduledRestore();
      expect(await service.pendingRestoreName(), isNull);
      expect(productRows(file), expected);
      await repo.addTask(
        const TaskDraft(title: 'Recoverable change after snapshot'),
      );
      final changed = productRows(file);
      await settings.writeAsString('{"device":"changed"}');
      await external.writeAsString('External contents changed outside the app');
      await service.scheduleRestore(
        imported,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await database.close();
      await service.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      database = AppDatabase(NativeDatabase(file));
      final reopened = LifeRepository(database);
      expect((await reopened.tasks()).map((task) => task.id).toSet(), {
        parent.id,
        child.id,
      });
      expect(productRows(file), expected);
      expect(await reopened.taskParents(), {child.id: parent.id});
      expect((await reopened.goalLinks(goal.id)).taskIds, {parent.id});
      expect((await reopened.goals()).single.progress.manual, 2);
      expect((await reopened.templates()).single.name, 'Research template');
      expect(await reopened.portablePreferences(), {
        'theme': 'dark',
        'firstWeekday': 7,
      });
      expect(await settings.readAsString(), '{"device":"changed"}');
      expect(
        await external.readAsString(),
        'External contents changed outside the app',
      );
      final rollback = (await service.list()).singleWhere(
        (record) => record.kind == BackupKind.beforeRestore,
      );
      expect(productRows(rollback.file), changed);
      await service.markRestoreOpened();
      expect(await service.pendingRestoreName(), isNull);
      expect(await service.restoreStatus(), contains('opened successfully'));
      // A subsequent launch is idempotent and does not create another snapshot.
      await database.close();
      expect(
        await service.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        ),
        isNull,
      );
      database = AppDatabase(NativeDatabase(file));
      expect(await LifeRepository(database).tasks(), hasLength(2));
      expect(productRows(file), expected);
      expect(
        (await service.list()).where(
          (record) => record.kind == BackupKind.beforeRestore,
        ),
        hasLength(1),
      );
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  });
}
