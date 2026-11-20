import 'dart:async';

import '../data/life_repository.dart';
import '../domain/alarms.dart';
import '../domain/goals.dart';
import '../domain/habits.dart';
import '../domain/models.dart';
import '../domain/progressive_plan.dart';
import '../domain/task_composition.dart';
import '../domain/saved_views.dart';
import '../domain/scheduling_models.dart';
import '../domain/templates.dart';
import '../domain/time_tracking.dart';
import '../domain/trash.dart';

/// Strongly-typed snapshot of all domain entities and operational data
/// loaded concurrently during [AppController.refresh].
class AppRefreshSnapshot {
  const AppRefreshSnapshot({
    required this.categories,
    required this.projects,
    required this.tasks,
    required this.events,
    required this.todayEvents,
    required this.alarmRules,
    required this.sessions,
    required this.availability,
    required this.schedulingHistory,
    required this.dependencies,
    required this.sequences,
    required this.habits,
    required this.habitEntries,
    required this.habitRestDays,
    required this.goals,
    required this.goalMilestones,
    required this.timeEntries,
    required this.activeTimer,
    required this.templates,
    required this.savedViews,
    required this.trashItems,
    required this.archivedTasks,
    required this.archivedSeries,
    required this.reportTasks,
    required this.iconKeys,
    required this.taskParents,
    required this.checklistItems,
    required this.progressiveAssignments,
    required this.checklistGroups,
  });

  final List<Category> categories;
  final List<Project> projects;
  final List<LifeTask> tasks;
  final List<FixedEvent> events;
  final List<FixedEvent> todayEvents;
  final List<AlarmRule> alarmRules;
  final List<WorkSession> sessions;
  final AvailabilityPlan availability;
  final List<SchedulingOperation> schedulingHistory;
  final List<TaskDependency> dependencies;
  final List<TaskSequence> sequences;
  final List<Habit> habits;
  final List<HabitEntry> habitEntries;
  final List<HabitRestDay> habitRestDays;
  final List<Goal> goals;
  final List<GoalMilestone> goalMilestones;
  final List<TimeEntry> timeEntries;
  final TimerRun? activeTimer;
  final List<LifeTemplate> templates;
  final List<SavedView> savedViews;
  final List<TrashItem> trashItems;
  final List<LifeTask> archivedTasks;
  final List<ArchivedSeries> archivedSeries;
  final List<LifeTask> reportTasks;
  final Map<String, String> iconKeys;
  final Map<String, String> taskParents;
  final List<TaskChecklistItem> checklistItems;
  final Map<String, ProgressiveAssignment> progressiveAssignments;
  final List<TaskChecklistGroup> checklistGroups;

  /// Loads all 29 typed queries concurrently via [Future.wait].
  ///
  /// Preserves the aliasing optimization for [todayEvents] when [today] falls
  /// within `[eventWindowFrom, eventWindowThrough]`.
  static Future<AppRefreshSnapshot> load(
    LifeRepository repository, {
    required String eventWindowFrom,
    required String eventWindowThrough,
    required String today,
  }) async {
    final windowEventsFuture = repository.eventOccurrences(
      eventWindowFrom,
      eventWindowThrough,
    );
    final todayEventsFuture =
        today.compareTo(eventWindowFrom) >= 0 &&
            today.compareTo(eventWindowThrough) <= 0
        ? windowEventsFuture
        : repository.eventOccurrences(today, today);

    final categoriesFuture = repository.categories();
    final projectsFuture = repository.projects();
    final tasksFuture = repository.tasks();
    final sessionsFuture = repository.sessions();
    final availabilityFuture = repository.availability();
    final schedulingHistoryFuture = repository.schedulingHistory();
    final dependenciesFuture = repository.dependencies();
    final sequencesFuture = repository.sequences();
    final habitsFuture = repository.habits(includeArchived: true);
    final habitEntriesFuture = repository.habitEntries();
    final habitRestDaysFuture = repository.habitRestDays();
    final goalsFuture = repository.goals();
    final goalMilestonesFuture = repository.goalMilestones();
    final timeEntriesFuture = repository.timeEntries();
    final activeTimerFuture = repository.activeTimerRun();
    final templatesFuture = repository.templates();
    final savedViewsFuture = repository.savedViews();
    final trashFuture = repository.trash();
    final archivedTasksFuture = repository.archivedTasks();
    final archivedSeriesFuture = repository.archivedSeries();
    final reportTasksFuture = repository.reportTasks();
    final iconKeysFuture = repository.entityIcons();
    final taskParentsFuture = repository.taskParents();
    final checklistItemsFuture = repository.checklistItems();
    final progressiveAssignmentsFuture = repository.progressiveAssignments();
    final checklistGroupsFuture = repository.checklistGroups();
    final alarmRulesFuture = repository.alarmRules();

    await Future.wait<Object?>([
      categoriesFuture,
      projectsFuture,
      tasksFuture,
      windowEventsFuture,
      sessionsFuture,
      availabilityFuture,
      schedulingHistoryFuture,
      dependenciesFuture,
      sequencesFuture,
      habitsFuture,
      habitEntriesFuture,
      habitRestDaysFuture,
      goalsFuture,
      goalMilestonesFuture,
      timeEntriesFuture,
      activeTimerFuture,
      templatesFuture,
      savedViewsFuture,
      trashFuture,
      archivedTasksFuture,
      archivedSeriesFuture,
      reportTasksFuture,
      iconKeysFuture,
      taskParentsFuture,
      checklistItemsFuture,
      progressiveAssignmentsFuture,
      checklistGroupsFuture,
      todayEventsFuture,
      alarmRulesFuture,
    ]);

    return AppRefreshSnapshot(
      categories: await categoriesFuture,
      projects: await projectsFuture,
      tasks: await tasksFuture,
      events: await windowEventsFuture,
      todayEvents: await todayEventsFuture,
      alarmRules: await alarmRulesFuture,
      sessions: await sessionsFuture,
      availability: await availabilityFuture,
      schedulingHistory: await schedulingHistoryFuture,
      dependencies: await dependenciesFuture,
      sequences: await sequencesFuture,
      habits: await habitsFuture,
      habitEntries: await habitEntriesFuture,
      habitRestDays: await habitRestDaysFuture,
      goals: await goalsFuture,
      goalMilestones: await goalMilestonesFuture,
      timeEntries: await timeEntriesFuture,
      activeTimer: await activeTimerFuture,
      templates: await templatesFuture,
      savedViews: await savedViewsFuture,
      trashItems: await trashFuture,
      archivedTasks: await archivedTasksFuture,
      archivedSeries: await archivedSeriesFuture,
      reportTasks: await reportTasksFuture,
      iconKeys: await iconKeysFuture,
      taskParents: await taskParentsFuture,
      checklistItems: await checklistItemsFuture,
      progressiveAssignments: await progressiveAssignmentsFuture,
      checklistGroups: await checklistGroupsFuture,
    );
  }
}
