import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/reports.dart';
import 'package:life_manager/domain/time_tracking.dart';

void main() {
  LifeTask task(
    String id,
    DateTime created,
    DateTime? completed, {
    String? projectId,
  }) => LifeTask(
    id: id,
    title: id,
    notes: '',
    status: completed == null ? TaskStatus.notStarted : TaskStatus.completed,
    priority: 0,
    createdAt: created.toUtc(),
    updatedAt: created.toUtc(),
    completedAt: completed?.toUtc(),
    projectId: projectId,
    scheduledDate: '2026-10-17',
  );

  TimeEntry entry(String id, String taskId, DateTime start, DateTime end) =>
      TimeEntry(
        id: id,
        taskId: taskId,
        sessionId: null,
        timerRunId: null,
        source: TimeEntrySource.manual,
        startsAt: start.toUtc(),
        endsAt: end.toUtc(),
        notes: '',
        updatedAt: end.toUtc(),
      );

  test(
    'report counts stored completion and merges overlaps across local days',
    () {
      final created = DateTime(2026, 10, 17, 10);
      final completed = DateTime(2026, 10, 18, 8);
      final report = StatisticsReport.calculate(
        tasks: [task('a', created, completed, projectId: 'p')],
        timeEntries: [
          entry(
            'one',
            'a',
            DateTime(2026, 10, 17, 23, 30),
            DateTime(2026, 10, 18, 0, 30),
          ),
          entry('two', 'a', DateTime(2026, 10, 18), DateTime(2026, 10, 18, 1)),
          entry(
            'trash',
            'hidden',
            DateTime(2026, 10, 18, 2),
            DateTime(2026, 10, 18, 3),
          ),
        ],
        habits: [
          Habit(
            id: 'h',
            title: 'Habit',
            notes: '',
            kind: HabitKind.binary,
            target: null,
            unit: '',
            rule: RecurrenceRule(
              kind: RecurrenceKind.daily,
              startDate: '2026-10-17',
            ),
            createdAt: created,
            updatedAt: created,
          ),
        ],
        habitEntries: [
          HabitEntry(
            id: 'e',
            habitId: 'h',
            localDate: '2026-10-17',
            value: 1,
            notes: '',
            createdAt: created,
            updatedAt: created,
          ),
        ],
        restDays: const [],
        goals: const [],
        fromDate: '2026-10-17',
        throughDate: '2026-10-18',
        now: DateTime(2026, 10, 18, 12),
      );
      expect(report.created, 1);
      expect(report.completed, 1);
      expect(report.planned, 1);
      expect(report.days.first.work, const Duration(minutes: 30));
      expect(report.days.last.work, const Duration(hours: 1));
      expect(report.work, const Duration(minutes: 90));
      expect(report.habitDue, 1);
      expect(report.habitSuccess, 1);
      expect(report.projects.single.projectId, 'p');
    },
  );

  test(
    'report excludes trashed descendants and includes archived history',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      try {
        final category = await repository.addCategory('Category');
        final project = await repository.addProject(category.id, 'Project');
        final archived = await repository.addTask(
          TaskDraft(
            title: 'Archived',
            categoryId: category.id,
            projectId: project.id,
          ),
        );
        final deleted = await repository.addTask(
          const TaskDraft(title: 'Deleted'),
        );
        await repository.archiveTask(archived);
        await repository.deleteTask(deleted.id);
        expect((await repository.reportTasks()).map((task) => task.id), [
          archived.id,
        ]);
        await repository.deleteProject(project.id);
        expect(await repository.reportTasks(), isEmpty);
        await repository.restoreTrashItem(
          (await repository.trash()).singleWhere(
            (item) => item.id == project.id,
          ),
        );
        expect((await repository.reportTasks()).single.id, archived.id);
      } finally {
        await database.close();
      }
    },
  );

  test('unreviewed timer time stops at its last confirmed checkpoint', () {
    final started = DateTime(2026, 10, 18, 8).toUtc();
    final checkpoint = DateTime(2026, 10, 18, 8, 10).toUtc();
    final report = StatisticsReport.calculate(
      tasks: [task('a', DateTime(2026, 10, 18, 7), null)],
      timeEntries: [
        TimeEntry(
          id: 'open',
          taskId: 'a',
          sessionId: null,
          timerRunId: 'timer',
          source: TimeEntrySource.timer,
          startsAt: started,
          endsAt: null,
          notes: '',
          updatedAt: checkpoint,
        ),
      ],
      activeTimer: TimerRun(
        id: 'timer',
        taskId: 'a',
        state: TimerState.running,
        startedAt: started,
        lastSeenAt: checkpoint,
        updatedAt: checkpoint,
      ),
      habits: const [],
      habitEntries: const [],
      restDays: const [],
      goals: const [],
      fromDate: '2026-10-18',
      throughDate: '2026-10-18',
      now: DateTime(2026, 10, 18, 9),
    );
    expect(report.work, const Duration(minutes: 10));
  });

  test('report rejects reversed and unbounded date ranges', () {
    StatisticsReport calculate(String from, String through) =>
        StatisticsReport.calculate(
          tasks: const [],
          timeEntries: const [],
          habits: const [],
          habitEntries: const [],
          restDays: const [],
          goals: const [],
          fromDate: from,
          throughDate: through,
          now: DateTime(2026, 10, 18),
        );
    expect(() => calculate('2026-10-19', '2026-10-18'), throwsArgumentError);
    expect(() => calculate('2025-01-01', '2026-10-18'), throwsArgumentError);
  });
}
