import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/task_composition.dart';
import 'package:life_manager/domain/task_resources.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ARCH-07: Repository Encapsulation & Composite Operations', () {
    late AppDatabase db;
    late LifeRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = LifeRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addSubtaskWithComposition creates parent-child link, checklist groups/items, and draft resources atomically',
      () async {
        final parent = await repo.addTask(
          const TaskDraft(title: 'Parent Task', scheduledDate: '2026-11-20'),
        );

        final child = await repo.addSubtaskWithComposition(
          parent,
          const TaskDraft(title: 'Child Task', scheduledDate: '2026-11-20'),
          groups: [
            DraftChecklistGroup('Group 1', ['Item 1.1', 'Item 1.2']),
          ],
          resources: const [
            DraftTaskResource(
              TaskResourceKind.url,
              'https://example.com/subtask',
              'Subtask Resource',
            ),
          ],
        );

        expect(child.title, 'Child Task');

        // Verify parent link
        final parentLinks = await repo.taskParents();
        expect(parentLinks[child.id], parent.id);

        // Verify checklist groups and items
        final allGroups = await repo.checklistGroups();
        final childGroups = allGroups.where((g) => g.taskId == child.id).toList();
        expect(childGroups.length, 1);
        expect(childGroups.first.title, 'Group 1');

        final items = (await repo.checklistItems()).where((i) => i.taskId == child.id).toList();
        expect(items.length, 2);
        expect(items.map((i) => i.title), containsAll(['Item 1.1', 'Item 1.2']));
        expect(items.every((i) => i.groupId == childGroups.first.id), isTrue);

        // Verify draft resources
        final resources = await repo.taskResources(child.id);
        expect(resources.length, 1);
        expect(resources.first.kind, TaskResourceKind.url);
        expect(resources.first.target, 'https://example.com/subtask');
        expect(resources.first.label, 'Subtask Resource');
      },
    );

    test(
      'addTaskWithComposition creates task, checklist, subtasks, groups, and draft resources atomically',
      () async {
        final root = await repo.addTaskWithComposition(
          const TaskDraft(title: 'Root Composition Task', scheduledDate: '2026-11-20'),
          ['Root Check 1', 'Root Check 2'],
          [const TaskDraft(title: 'Child Subtask Draft', scheduledDate: '2026-11-20')],
          groups: [
            DraftChecklistGroup('Group Alpha', ['Alpha 1']),
          ],
          resources: const [
            DraftTaskResource(
              TaskResourceKind.url,
              'https://example.com/root',
              'Root Resource',
            ),
          ],
        );

        expect(root.title, 'Root Composition Task');

        // Verify subtask and parent link
        final parentLinks = await repo.taskParents();
        final allTasks = await repo.tasks();
        final child = allTasks.singleWhere((t) => t.id != root.id);
        expect(child.title, 'Child Subtask Draft');
        expect(parentLinks[child.id], root.id);

        // Verify checklist items (both root-level and group-level)
        final items = (await repo.checklistItems()).where((i) => i.taskId == root.id).toList();
        expect(items.length, 3);
        final rootItems = items.where((i) => i.groupId == null).toList();
        expect(rootItems.map((i) => i.title), containsAll(['Root Check 1', 'Root Check 2']));

        // Verify group
        final groups = (await repo.checklistGroups()).where((g) => g.taskId == root.id).toList();
        expect(groups.length, 1);
        expect(groups.first.title, 'Group Alpha');
        final groupItems = items.where((i) => i.groupId == groups.first.id).toList();
        expect(groupItems.length, 1);
        expect(groupItems.first.title, 'Alpha 1');

        // Verify resources
        final resources = await repo.taskResources(root.id);
        expect(resources.length, 1);
        expect(resources.first.target, 'https://example.com/root');
        expect(resources.first.label, 'Root Resource');
      },
    );

    test(
      'addRecurringTaskWithComposition creates recurring series, groups, items, subtasks, and resources atomically',
      () async {
        final recurring = await repo.addRecurringTaskWithComposition(
          const TaskDraft(title: 'Recurring Template Task', scheduledDate: '2026-11-20'),
          RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2026-11-20',
            interval: 1,
          ),
          progressiveSteps: ['Step Alpha', 'Step Beta'],
          repeatPlanAtEnd: false,
          groups: [
            DraftChecklistGroup('Daily Routines', ['Morning Check', 'Evening Check']),
          ],
          checklist: ['Standard Check'],
          subtasks: [
            const TaskDraft(title: 'Recurring Subtask', scheduledDate: '2026-11-20'),
          ],
          resources: const [
            DraftTaskResource(
              TaskResourceKind.url,
              'https://example.com/daily',
              'Daily Guide',
            ),
          ],
        );

        expect(recurring.title, 'Recurring Template Task');
        expect(recurring.recurrenceSeriesId, isNotNull);

        // Verify subtask linkage
        final parentLinks = await repo.taskParents();
        final allTasks = await repo.tasks();
        final subtask = allTasks.singleWhere((t) => t.id != recurring.id);
        expect(subtask.title, 'Recurring Subtask');
        expect(parentLinks[subtask.id], recurring.id);

        // Verify groups and items
        final groups = (await repo.checklistGroups()).where((g) => g.taskId == recurring.id).toList();
        expect(groups.length, 1);
        expect(groups.first.title, 'Daily Routines');

        final items = (await repo.checklistItems()).where((i) => i.taskId == recurring.id).toList();
        expect(items.length, 3);
        final rootItems = items.where((i) => i.groupId == null).toList();
        expect(rootItems.map((i) => i.title), containsAll(['Standard Check']));

        // Verify resources
        final resources = await repo.taskResources(recurring.id);
        expect(resources.length, 1);
        expect(resources.first.target, 'https://example.com/daily');
        expect(resources.first.label, 'Daily Guide');

        // Verify progressive plan
        final plan = await repo.progressivePlan(recurring.id);
        expect(plan, isNotNull);
        expect(plan!.steps, ['Step Alpha', 'Step Beta']);
        expect(plan.repeatAtEnd, isFalse);
      },
    );

    test('addGoalWithComposition creates goal and links atomically', () async {
      final category = await repo.addCategory('Health Category');
      final project = await repo.addProject(category.id, 'Fitness Project');
      final task = await repo.addTask(
        TaskDraft(
          title: 'Weekly 5k Run',
          categoryId: category.id,
          projectId: project.id,
          scheduledDate: '2026-11-20',
        ),
      );
      final habit = await repo.addHabit(
        HabitDraft(
          title: 'Daily Water Intake',
          kind: HabitKind.binary,
          rule: RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2026-11-20',
            interval: 1,
          ),
        ),
      );

      final links = GoalLinks(
        habitIds: {habit.id},
        taskIds: {task.id},
        projectIds: {project.id},
      );

      final goal = await repo.addGoalWithComposition(
        const GoalDraft(
          title: 'Reach 100km Run Total',
          description: 'Yearly marathon training goal',
          target: 100.0,
          unit: 'km',
          startDate: '2026-11-20',
        ),
        links: links,
      );

      expect(goal.title, 'Reach 100km Run Total');
      expect(goal.target, 100.0);
      expect(goal.unit, 'km');

      // Verify persisted goal links
      final persistedLinks = await repo.goalLinks(goal.id);
      expect(persistedLinks.habitIds, {habit.id});
      expect(persistedLinks.taskIds, {task.id});
      expect(persistedLinks.projectIds, {project.id});
    });

    group('Transaction rollback on failure', () {
      test('addSubtaskWithComposition rolls back completely when child creation fails', () async {
        final parent = await repo.addTask(
          const TaskDraft(title: 'Parent Task', scheduledDate: '2026-11-20'),
        );
        final initialTasks = await repo.tasks();
        final initialParents = await repo.taskParents();

        // Invalid child draft: empty title triggers ArgumentError
        await expectLater(
          repo.addSubtaskWithComposition(
            parent,
            const TaskDraft(title: '   ', scheduledDate: '2026-11-20'),
            groups: [
              DraftChecklistGroup('Group 1', ['Item 1']),
            ],
          ),
          throwsArgumentError,
        );

        // Verify atomic rollback: no child task, no parent link, no checklist groups
        final currentTasks = await repo.tasks();
        expect(currentTasks.map((t) => t.id), initialTasks.map((t) => t.id));
        expect(await repo.taskParents(), equals(initialParents));
        expect(await repo.checklistGroups(), isEmpty);
      });

      test('addSubtaskWithComposition rolls back when checklist item insertion fails', () async {
        final parent = await repo.addTask(
          const TaskDraft(title: 'Parent Task', scheduledDate: '2026-11-20'),
        );
        final initialTasks = await repo.tasks();

        // An empty checklist item title inside a group triggers ArgumentError during group population
        await expectLater(
          repo.addSubtaskWithComposition(
            parent,
            const TaskDraft(title: 'Valid Child Title', scheduledDate: '2026-11-20'),
            groups: [
              DraftChecklistGroup('Group 1', ['Valid Item', '   ']),
            ],
          ),
          throwsArgumentError,
        );

        // Verify atomic rollback: child task was NOT persisted
        final currentTasks = await repo.tasks();
        expect(currentTasks.map((t) => t.id), initialTasks.map((t) => t.id));
        expect(await repo.taskParents(), isEmpty);
        expect(await repo.checklistGroups(), isEmpty);
      });

      test('addTaskWithComposition rolls back completely when subtask validation fails', () async {
        final initialTasks = await repo.tasks();

        // Root task is valid, but child task has empty title
        await expectLater(
          repo.addTaskWithComposition(
            const TaskDraft(title: 'Valid Root Title', scheduledDate: '2026-11-20'),
            ['Valid Check'],
            [const TaskDraft(title: '   ', scheduledDate: '2026-11-20')],
            groups: [
              DraftChecklistGroup('Group 1', ['Item 1']),
            ],
          ),
          throwsArgumentError,
        );

        // Verify atomic rollback: neither root task nor child task was persisted
        final currentTasks = await repo.tasks();
        expect(currentTasks.map((t) => t.id), initialTasks.map((t) => t.id));
        expect(await repo.taskParents(), isEmpty);
        expect(await repo.checklistGroups(), isEmpty);
      });

      test('addRecurringTaskWithComposition rolls back completely when subtask is invalid', () async {
        final initialTasks = await repo.tasks();

        // Recurrence rule and draft are valid, but subtask has empty title
        await expectLater(
          repo.addRecurringTaskWithComposition(
            const TaskDraft(title: 'Valid Recurring Title', scheduledDate: '2026-11-20'),
            RecurrenceRule(
              kind: RecurrenceKind.daily,
              startDate: '2026-11-20',
              interval: 1,
            ),
            subtasks: [
              const TaskDraft(title: '   ', scheduledDate: '2026-11-20'),
            ],
          ),
          throwsArgumentError,
        );

        // Verify atomic rollback: no recurrence series, no tasks, no occurrences
        final currentTasks = await repo.tasks();
        expect(currentTasks.map((t) => t.id), initialTasks.map((t) => t.id));
        expect((await repo.tasks()).where((t) => t.recurrenceSeriesId != null), isEmpty);
      });

      test('addGoalWithComposition rolls back when linked habit does not exist', () async {
        final initialGoals = await repo.goals();

        const invalidLinks = GoalLinks(
          habitIds: {'non-existent-habit-id-00000000-0000'},
          taskIds: {},
          projectIds: {},
        );

        await expectLater(
          repo.addGoalWithComposition(
            const GoalDraft(
              title: 'Goal with Broken Link',
              target: 50.0,
              unit: 'points',
              startDate: '2026-11-20',
            ),
            links: invalidLinks,
          ),
          throwsArgumentError,
        );

        // Verify atomic rollback: goal was NOT persisted
        final currentGoals = await repo.goals();
        expect(currentGoals.map((g) => g.id), initialGoals.map((g) => g.id));
      });
    });

    test('LifeRepository.close() cleanly releases database resources', () async {
      final localDb = AppDatabase(NativeDatabase.memory());
      final localRepo = LifeRepository(localDb);

      // Verify repository can perform operations before close
      final cat = await localRepo.addCategory('Active Category');
      expect(cat.name, 'Active Category');

      // Close repository
      await localRepo.close();

      // Verify database is closed: subsequent operations throw
      expect(
        () async => await localRepo.addCategory('After Close Category'),
        throwsA(anything),
      );
    });

    test(
      'Encapsulation boundary test: no UI or orchestration code calls .db.transaction or .db.close()',
      () {
        final libDir = Directory('lib');
        final scanDirs = [
          Directory('${libDir.path}/app'),
          Directory('${libDir.path}/features'),
        ];

        final violations = <String>[];

        for (final dir in scanDirs) {
          if (!dir.existsSync()) continue;
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is File && entity.path.endsWith('.dart')) {
              final content = entity.readAsStringSync();
              final lines = content.split('\n');
              for (var i = 0; i < lines.length; i++) {
                final line = lines[i];
                if (line.contains('.db.transaction') || line.contains('.db.close')) {
                  violations.add('${entity.path}:${i + 1}: $line');
                }
              }
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Found forbidden direct database access (.db.transaction or .db.close) in presentation/app layers:\n'
              '${violations.join('\n')}',
        );
      },
    );
  });
}
