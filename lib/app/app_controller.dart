import '../domain/task_resources.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/legacy.dart';

import '../data/life_repository.dart';
import '../data/widget_configuration_store.dart';
import '../data/app_database.dart';
import '../data/appearance_preference_store.dart';
import '../data/calendar_preference_store.dart';
import '../data/backup_service.dart';
import '../domain/models.dart';
import '../domain/recurrence.dart';
import '../domain/series_edit.dart';
import '../domain/habits.dart';
import '../domain/goals.dart';
import '../domain/time_tracking.dart';
import '../domain/task_composition.dart';
import '../domain/progressive_plan.dart';
import '../domain/templates.dart';
import '../domain/saved_views.dart';
import '../domain/appearance.dart';
import '../domain/task_view_preferences.dart';
import '../domain/sync/portable_preferences.dart';
import '../domain/hotkeys.dart';
import '../domain/scheduling_models.dart';
import '../domain/trash.dart';
import '../domain/reports.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  throw StateError('AppController must be provided by the application');
});

enum WorkspaceView {
  today,
  anytime,
  all,
  inbox,
  upcoming,
  overdue,
  waiting,
  completed,
  calendar,
  habits,
  goals,
  reports,
  contributors,
  saved,
  category,
  project,
}

enum TaskSort { schedule, priority, title, created }

class AppController extends ChangeNotifier {
  AppController(
    this.repository, {
    this.appearanceStore,
    this.calendarPreferenceStore,
    this.backupService,
    this.widgetStore,
  });
  final LifeRepository repository;
  final AppearancePreferenceStore? appearanceStore;
  final CalendarPreferenceStore? calendarPreferenceStore;
  final BackupService? backupService;
  final WidgetConfigurationStore? widgetStore;
  String? backupError;
  VoidCallback? onLocalChange;

  List<Category> categories = [];
  List<Project> projects = [];
  List<LifeTask> tasks = [];
  List<FixedEvent> events = [];
  List<FixedEvent> todayEvents = [];
  Map<String, String> iconKeys = {};
  Map<String, String> taskParents = {};
  List<TaskChecklistItem> checklistItems = [];
  List<TaskChecklistGroup> checklistGroups = [];
  Map<String, ProgressiveAssignment> progressiveAssignments = {};
  String? _eventWindowFrom;
  String? _eventWindowThrough;
  String get eventWindowFrom =>
      _eventWindowFrom ??
      RecurrenceRule.shiftDate(localDate(DateTime.now()), -30);
  String get eventWindowThrough =>
      _eventWindowThrough ??
      RecurrenceRule.shiftDate(localDate(DateTime.now()), 90);
  String get eventWindowLabel => '$eventWindowFrom to $eventWindowThrough';
  List<WorkSession> sessions = [];
  List<TaskDependency> dependencies = [];
  List<TaskSequence> sequences = [];
  List<Habit> habits = [];
  List<HabitEntry> habitEntries = [];
  List<HabitRestDay> habitRestDays = [];
  List<Goal> goals = [];
  List<GoalMilestone> goalMilestones = [];
  List<TimeEntry> timeEntries = [];
  List<LifeTemplate> templates = [];
  List<SavedView> savedViews = [];
  List<TrashItem> trashItems = [];
  List<LifeTask> archivedTasks = [];
  List<ArchivedSeries> archivedSeries = [];
  List<LifeTask> reportTasks = [];
  TimerRun? activeTimer;
  String? timerError;
  Timer? _timerHeartbeat;
  bool _heartbeatBusy = false;
  AvailabilityPlan availability = const AvailabilityPlan(weekly: {});
  List<SchedulingOperation> schedulingHistory = [];
  WorkspaceView view = WorkspaceView.today;
  TaskSort sort = TaskSort.schedule;
  String? scopeId;
  String? selectedTaskId;
  ThemeModePreference theme = ThemeModePreference.system;
  ThemeCustomization customization = const ThemeCustomization();
  TaskViewPreferences taskViewPreferences = const TaskViewPreferences();
  HotkeyPreferences hotkeys = HotkeyPreferences();
  CalendarContent calendarContent = CalendarContent.both;
  int firstWeekday = 7;
  String? lastCalendarMode;
  static const defaultSidebarOrder = <WorkspaceView>[
    WorkspaceView.today,
    WorkspaceView.all,
    WorkspaceView.inbox,
    WorkspaceView.anytime,
    WorkspaceView.calendar,
    WorkspaceView.habits,
    WorkspaceView.goals,
    WorkspaceView.upcoming,
    WorkspaceView.overdue,
    WorkspaceView.waiting,
    WorkspaceView.completed,
  ];
  List<WorkspaceView> sidebarOrder = List.of(defaultSidebarOrder);
  Set<String> hiddenNavigation = {};
  List<String> customNavigationOrder = [];
  bool categoriesExpanded = false;
  List<SavedView> get orderedSavedViews {
    final byId = {for (final view in savedViews) view.id: view};
    return [
      for (final id in customNavigationOrder)
        if (byId.containsKey(id)) byId.remove(id)!,
      ...byId.values,
    ];
  }

  Future<void> setNavigationState({
    Set<String>? hidden,
    List<String>? customOrder,
    bool? expanded,
  }) async {
    final nextHidden = hidden ?? hiddenNavigation;
    final nextOrder = customOrder ?? customNavigationOrder;
    final nextExpanded = expanded ?? categoriesExpanded;
    await appearanceStore?.saveNavigationState({
      'hidden': nextHidden.toList(),
      'customOrder': nextOrder,
      'categoriesExpanded': nextExpanded,
    });
    hiddenNavigation = Set.of(nextHidden);
    customNavigationOrder = List.of(nextOrder);
    categoriesExpanded = nextExpanded;
    notifyListeners();
  }

  bool loading = true;

  LifeTask? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId) return task;
    }
    return null;
  }

  Future<void> refresh() async {
    final today = localDate(DateTime.now());
    await repository.ensureRecurringTasks(
      RecurrenceRule.shiftDate(today, -14),
      RecurrenceRule.shiftDate(today, 30),
    );
    final windowEvents = repository.eventOccurrences(
      eventWindowFrom,
      eventWindowThrough,
    );
    final todayEventsLoad =
        today.compareTo(eventWindowFrom) >= 0 &&
            today.compareTo(eventWindowThrough) <= 0
        ? windowEvents
        : repository.eventOccurrences(today, today);
    final result = await Future.wait<Object?>([
      repository.categories(),
      repository.projects(),
      repository.tasks(),
      windowEvents,
      repository.sessions(),
      repository.availability(),
      repository.schedulingHistory(),
      repository.dependencies(),
      repository.sequences(),
      repository.habits(includeArchived: true),
      repository.habitEntries(),
      repository.habitRestDays(),
      repository.goals(),
      repository.goalMilestones(),
      repository.timeEntries(),
      repository.activeTimerRun(),
      repository.templates(),
      repository.savedViews(),
      repository.trash(),
      repository.archivedTasks(),
      repository.archivedSeries(),
      repository.reportTasks(),
      repository.entityIcons(),
      repository.taskParents(),
      repository.checklistItems(),
      repository.progressiveAssignments(),
      repository.checklistGroups(),
      todayEventsLoad,
    ]);
    categories = result[0] as List<Category>;
    projects = result[1] as List<Project>;
    tasks = result[2] as List<LifeTask>;
    events = result[3] as List<FixedEvent>;
    todayEvents = result[27] as List<FixedEvent>;
    sessions = result[4] as List<WorkSession>;
    availability = result[5] as AvailabilityPlan;
    schedulingHistory = result[6] as List<SchedulingOperation>;
    dependencies = result[7] as List<TaskDependency>;
    sequences = result[8] as List<TaskSequence>;
    habits = result[9] as List<Habit>;
    habitEntries = result[10] as List<HabitEntry>;
    habitRestDays = result[11] as List<HabitRestDay>;
    goals = result[12] as List<Goal>;
    goalMilestones = result[13] as List<GoalMilestone>;
    timeEntries = result[14] as List<TimeEntry>;
    activeTimer = result[15] as TimerRun?;
    templates = result[16] as List<LifeTemplate>;
    savedViews = result[17] as List<SavedView>;
    trashItems = result[18] as List<TrashItem>;
    archivedTasks = result[19] as List<LifeTask>;
    archivedSeries = result[20] as List<ArchivedSeries>;
    reportTasks = result[21] as List<LifeTask>;
    iconKeys = result[22] as Map<String, String>;
    taskParents = result[23] as Map<String, String>;
    checklistItems = result[24] as List<TaskChecklistItem>;
    checklistGroups = result[26] as List<TaskChecklistGroup>;
    progressiveAssignments = result[25] as Map<String, ProgressiveAssignment>;
    _syncTimerHeartbeat();
    if (selectedTaskId != null && selectedTask == null) selectedTaskId = null;
    loading = false;
    notifyListeners();
    onLocalChange?.call();
  }

  void _syncTimerHeartbeat() {
    final run = activeTimer;
    if (run?.state != TimerState.running ||
        !run!.canControl ||
        run.needsReview(DateTime.now())) {
      _timerHeartbeat?.cancel();
      _timerHeartbeat = null;
      return;
    }
    _timerHeartbeat ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      final current = activeTimer;
      if (_heartbeatBusy || current?.state != TimerState.running) return;
      _heartbeatBusy = true;
      try {
        final seen = await repository.heartbeatTimer(current!);
        if (seen == null) {
          _timerHeartbeat?.cancel();
          _timerHeartbeat = null;
        } else if (activeTimer?.id == current.id) {
          activeTimer = current.withLastSeen(seen);
        }
        timerError = null;
        notifyListeners();
      } catch (failure) {
        timerError = '$failure';
        _timerHeartbeat?.cancel();
        _timerHeartbeat = null;
        notifyListeners();
      } finally {
        _heartbeatBusy = false;
      }
    });
  }

  @override
  void dispose() {
    _timerHeartbeat?.cancel();
    super.dispose();
  }

  void navigate(WorkspaceView next, {String? id}) {
    view = next;
    scopeId = id;
    selectedTaskId = null;
    notifyListeners();
  }

  void select(String? taskId) {
    selectedTaskId = taskId;
    notifyListeners();
  }

  void setSort(TaskSort value) {
    sort = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (appearanceStore != null) {
      theme = await appearanceStore!.load();
      customization = await appearanceStore!.loadCustomization();
      final navigation = await appearanceStore!.loadNavigationState();
      hiddenNavigation = (navigation['hidden'] as List? ?? [])
          .cast<String>()
          .toSet();
      customNavigationOrder = (navigation['customOrder'] as List? ?? [])
          .cast<String>();
      categoriesExpanded = navigation['categoriesExpanded'] == true;
      taskViewPreferences = await appearanceStore!.loadTaskViewPreferences();
      hotkeys = await appearanceStore!.loadHotkeys();
      firstWeekday = await appearanceStore!.loadFirstWeekday();
      lastCalendarMode = await appearanceStore!.loadLastCalendarMode();
      sidebarOrder = (await appearanceStore!.loadSidebarOrder(
        defaultSidebarOrder.map((item) => item.name).toList(),
      )).map(WorkspaceView.values.byName).toList();
      view = WorkspaceView.values.firstWhere(
        (candidate) => candidate.name == customization.openingScreen,
        orElse: () => WorkspaceView.today,
      );
    }
    if (calendarPreferenceStore != null) {
      calendarContent = await calendarPreferenceStore!.load();
    }
    await applyPortablePreferences(seed: true);
    await refresh();
  }

  Future<void> applyPortablePreferences({bool seed = false}) async {
    if (seed) {
      await repository.initializePortablePreferences({
        'theme': theme.name,
        'customization': customization.toJson()
          ..remove('author')
          ..remove('authorProfile'),
        'calendarContent': calendarContent.name,
        'firstWeekday': firstWeekday,
        'lastCalendarMode': lastCalendarMode,
        'keepCompletedVisible': taskViewPreferences.keepCompletedVisible,
        'spellCheckEnabled': taskViewPreferences.spellCheckEnabled,
        'newTaskPlannedDay': taskViewPreferences.newTaskPlannedDay.name,
        'compositionTextDisplay':
            taskViewPreferences.compositionTextDisplay.name,
      });
    }
    final values = await repository.portablePreferences();
    if (values['theme'] case final String mode) {
      theme = ThemeModePreference.values.byName(mode);
    }
    if (values['customization'] case final Map value) {
      final localMetadata =
          (await appearanceStore?.loadCustomization() ?? customization)
              .toJson();
      customization = ThemeCustomization.fromJson(<String, Object?>{
        ...Map<String, Object?>.from(value),
        for (final field in deviceLocalThemeFields)
          if (localMetadata.containsKey(field)) field: localMetadata[field],
      });
    }
    if (values['calendarContent'] case final String content) {
      calendarContent = CalendarContent.values.byName(content);
    }
    if (values['firstWeekday'] case final int day) firstWeekday = day;
    if (values.containsKey('lastCalendarMode')) {
      lastCalendarMode = values['lastCalendarMode'] as String?;
    }
    taskViewPreferences = taskViewPreferences.copyWith(
      keepCompletedVisible: values['keepCompletedVisible'] as bool?,
      spellCheckEnabled: values['spellCheckEnabled'] as bool?,
      newTaskPlannedDay: values['newTaskPlannedDay'] is String
          ? NewTaskPlannedDay.values.byName(
              values['newTaskPlannedDay'] as String,
            )
          : null,
      compositionTextDisplay: values['compositionTextDisplay'] is String
          ? CompositionTextDisplay.values.byName(
              values['compositionTextDisplay'] as String,
            )
          : null,
    );
    // SQL is the durable source after sync. Profile JSON remains a compatible
    // projection for existing native readers and portable settings exports.
    await appearanceStore?.save(theme);
    await appearanceStore?.saveCustomization(customization);
    await appearanceStore?.saveFirstWeekday(firstWeekday);
    await appearanceStore?.saveLastCalendarMode(lastCalendarMode);
    await appearanceStore?.saveTaskViewPreferences(taskViewPreferences);
    await calendarPreferenceStore?.save(calendarContent);
    notifyListeners();
  }

  Future<void> setTaskViewPreferences(TaskViewPreferences value) async {
    await repository.savePortablePreferences({
      'keepCompletedVisible': value.keepCompletedVisible,
      'spellCheckEnabled': value.spellCheckEnabled,
      'newTaskPlannedDay': value.newTaskPlannedDay.name,
      'compositionTextDisplay': value.compositionTextDisplay.name,
    });
    await appearanceStore?.saveTaskViewPreferences(value);
    taskViewPreferences = value;
    notifyListeners();
    onLocalChange?.call();
  }

  Future<void> setHotkeys(HotkeyPreferences value) async {
    await appearanceStore?.saveHotkeys(value);
    hotkeys = value;
    notifyListeners();
  }

  Future<void> setCalendarContent(CalendarContent value) async {
    final previous = calendarContent;
    calendarContent = value;
    notifyListeners();
    try {
      await repository.savePortablePreference('calendarContent', value.name);
      await calendarPreferenceStore?.save(value);
      onLocalChange?.call();
    } catch (_) {
      calendarContent = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setFirstWeekday(int value) async {
    await repository.savePortablePreference('firstWeekday', value);
    await appearanceStore?.saveFirstWeekday(value);
    firstWeekday = value;
    notifyListeners();
    onLocalChange?.call();
  }

  Future<void> setLastCalendarMode(String value) async {
    await repository.savePortablePreference('lastCalendarMode', value);
    await appearanceStore?.saveLastCalendarMode(value);
    lastCalendarMode = value;
    notifyListeners();
    onLocalChange?.call();
  }

  Future<void> setSidebarOrder(List<WorkspaceView> value) async {
    if (value.length != defaultSidebarOrder.length ||
        value.toSet().length != value.length ||
        !value.toSet().containsAll(defaultSidebarOrder)) {
      throw ArgumentError('Invalid sidebar order');
    }
    await appearanceStore?.saveSidebarOrder(
      value.map((item) => item.name).toList(),
    );
    sidebarOrder = List.of(value);
    notifyListeners();
  }

  String? iconForTask(LifeTask task) =>
      iconKeys['task:${task.id}'] ??
      (task.recurrenceSeriesId == null
          ? null
          : iconKeys['series:${task.recurrenceSeriesId}']);

  Future<void> setIcon(String kind, String id, String? key) async {
    await repository.setEntityIcon(kind, id, key);
    await refresh();
  }

  Future<void> addSubtask(
    LifeTask parent,
    TaskDraft draft, {
    List<DraftTaskResource> resources = const [],
    ValueChanged<LifeTask>? onCommitted,
    List<DraftChecklistGroup> groups = const [],
  }) async {
    final child = await repository.db.transaction(() async {
      final task = await repository.addSubtask(parent, draft);
      for (final group in groups) {
        final saved = await repository.addChecklistGroup(task.id, group.title);
        for (final title in group.items) {
          await repository.addChecklistItem(task.id, title, groupId: saved.id);
        }
      }
      await repository.addDraftResources(task.id, resources);
      return task;
    });
    onCommitted?.call(child);
    await refresh();
    select(child.id);
  }

  Future<void> addChecklistItem(
    String taskId,
    String title, {
    String? groupId,
  }) async {
    await repository.addChecklistItem(taskId, title, groupId: groupId);
    await refresh();
  }

  Future<void> updateChecklistItem(
    TaskChecklistItem item, {
    String? title,
    bool? done,
  }) async {
    await repository.updateChecklistItem(item, title: title, done: done);
    await refresh();
  }

  Future<void> removeChecklistItem(TaskChecklistItem item) async {
    await repository.removeChecklistItem(item);
    await refresh();
  }

  Future<void> moveChecklistItem(TaskChecklistItem item, int direction) async {
    await repository.moveChecklistItem(item, direction);
    await refresh();
  }

  Future<void> checkAutomaticBackup() async {
    final service = backupService;
    if (service == null) return;
    try {
      await service.ensureAutomaticBackup(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      backupError = null;
    } catch (failure) {
      backupError = '$failure';
    }
    notifyListeners();
  }

  Future<void> reloadTheme() async {
    final store = appearanceStore;
    if (store == null) return;
    final value = await store.load();
    final palette = await store.loadCustomization();
    await repository.savePortablePreferences({
      'theme': value.name,
      'customization': palette.toJson()
        ..remove('author')
        ..remove('authorProfile'),
    });
    customization = palette;
    theme = value;
    notifyListeners();
    onLocalChange?.call();
  }

  Future<void> saveCustomization(ThemeCustomization value) async {
    await repository.savePortablePreference(
      'customization',
      value.toJson()
        ..remove('author')
        ..remove('authorProfile'),
    );
    await appearanceStore?.saveCustomization(value);
    customization = value;
    notifyListeners();
    onLocalChange?.call();
  }

  Future<void> setTheme(ThemeModePreference value) async {
    final previous = theme;
    theme = value;
    notifyListeners();
    try {
      await repository.savePortablePreference('theme', value.name);
      await appearanceStore?.save(value);
      onLocalChange?.call();
    } catch (_) {
      theme = previous;
      notifyListeners();
      rethrow;
    }
  }

  final _viewFilters = <String, TaskFilter>{};
  String get _filterKey => '${view.name}:$scopeId';
  TaskFilter get activeFilter => _viewFilters[_filterKey] ?? const TaskFilter();
  void setFilter(TaskFilter filter) {
    _viewFilters[_filterKey] = filter;
    notifyListeners();
  }

  List<LifeTask> get filteredTasks =>
      activeFilter.isActive ? searchTasks(activeFilter) : tasks;
  List<FixedEvent> get filteredEvents {
    final saved = view == WorkspaceView.saved
        ? savedViews.where((v) => v.id == scopeId).firstOrNull?.filter
        : null;
    final categoryNames = {for (final item in categories) item.id: item};
    final projectNames = {for (final item in projects) item.id: item};
    return (view == WorkspaceView.today ? todayEvents : events)
        .where(
          (event) =>
              activeFilter.matchesEvent(
                event,
                categories: categoryNames,
                projects: projectNames,
              ) &&
              (view != WorkspaceView.project || event.projectId == scopeId) &&
              (view != WorkspaceView.category || event.categoryId == scopeId) &&
              (saved == null ||
                  saved.matchesEvent(
                    event,
                    categories: categoryNames,
                    projects: projectNames,
                  )),
        )
        .toList();
  }

  List<WorkSession> get filteredSessions {
    if (!activeFilter.isActive) return sessions;
    final ids = filteredTasks.map((task) => task.id).toSet();
    return sessions.where((session) => ids.contains(session.taskId)).toList();
  }

  List<LifeTask> get visibleTasks {
    final today = localDate(DateTime.now());
    bool active(LifeTask task) =>
        task.isOpen ||
        (taskViewPreferences.keepCompletedVisible &&
            task.status == TaskStatus.completed) ||
        activeFilter.statuses.contains(task.status);
    final selectedView = savedViews
        .where((item) => item.id == scopeId)
        .firstOrNull;
    final savedIds = view == WorkspaceView.saved && selectedView != null
        ? searchTasks(selectedView.filter).map((task) => task.id).toSet()
        : <String>{};
    final items = filteredTasks.where((task) {
      switch (view) {
        case WorkspaceView.today:
          return active(task) && task.scheduledDate == today;
        case WorkspaceView.anytime:
          return active(task) &&
              task.scheduledDate == null &&
              task.deadlineDate == null;
        case WorkspaceView.all:
          return active(task);
        case WorkspaceView.inbox:
          return active(task) &&
              task.categoryId == null &&
              task.projectId == null;
        case WorkspaceView.upcoming:
          return active(task) &&
              task.scheduledDate != null &&
              task.scheduledDate!.compareTo(today) > 0;
        case WorkspaceView.overdue:
          return active(task) &&
              task.deadlineDate != null &&
              task.deadlineDate!.compareTo(today) < 0;
        case WorkspaceView.waiting:
          return task.status == TaskStatus.waiting ||
              task.status == TaskStatus.onHold;
        case WorkspaceView.completed:
          return task.status == TaskStatus.completed ||
              task.status == TaskStatus.cancelled;
        case WorkspaceView.calendar:
        case WorkspaceView.habits:
        case WorkspaceView.goals:
        case WorkspaceView.reports:
        case WorkspaceView.contributors:
          return false;
        case WorkspaceView.saved:
          return savedIds.contains(task.id);
        case WorkspaceView.category:
          return active(task) && task.categoryId == scopeId;
        case WorkspaceView.project:
          return active(task) && task.projectId == scopeId;
      }
    }).toList();
    items.sort((a, b) {
      final aDone = a.status == TaskStatus.completed;
      final bDone = b.status == TaskStatus.completed;
      if (view != WorkspaceView.completed && aDone != bDone) {
        return aDone ? 1 : -1;
      }
      final effectiveSort = view == WorkspaceView.saved && selectedView != null
          ? TaskSort.values.byName(selectedView.filter.sort.name)
          : sort;
      switch (effectiveSort) {
        case TaskSort.schedule:
          return _compareNullable(a.scheduledDate, b.scheduledDate) != 0
              ? _compareNullable(a.scheduledDate, b.scheduledDate)
              : b.priority.compareTo(a.priority);
        case TaskSort.priority:
          return b.priority.compareTo(a.priority);
        case TaskSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TaskSort.created:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return items;
  }

  StatisticsReport report(String fromDate, String throughDate) =>
      StatisticsReport.calculate(
        tasks: reportTasks,
        timeEntries: timeEntries,
        habits: habits,
        habitEntries: habitEntries,
        restDays: habitRestDays,
        goals: goals,
        activeTimer: activeTimer,
        fromDate: fromDate,
        throughDate: throughDate,
        now: DateTime.now(),
      );

  List<LifeTask> searchTasks(TaskFilter filter) {
    final byId = {for (final task in tasks) task.id: task};
    final blocked = <String>{};
    for (final link in dependencies) {
      final prerequisite = byId[link.prerequisiteId];
      if (prerequisite != null && prerequisite.status != TaskStatus.completed) {
        blocked.add(link.taskId);
      }
    }
    final categoryMap = {for (final item in categories) item.id: item};
    final projectMap = {for (final item in projects) item.id: item};
    final now = DateTime.now();
    return tasks
        .where(
          (task) => filter.matches(
            task,
            now,
            categories: categoryMap,
            projects: projectMap,
            blockedTaskIds: blocked,
          ),
        )
        .toList();
  }

  Future<SavedView> addSavedView(String name, TaskFilter filter) async {
    final view = await repository.addSavedView(name, filter);
    await refresh();
    navigate(WorkspaceView.saved, id: view.id);
    return view;
  }

  Future<void> updateSavedView(
    SavedView previous,
    String name,
    TaskFilter filter,
  ) async {
    await repository.updateSavedView(previous, name, filter);
    await refresh();
  }

  Future<void> deleteSavedView(SavedView previous) async {
    await repository.deleteSavedView(previous);
    if (view == WorkspaceView.saved && scopeId == previous.id) {
      navigate(WorkspaceView.today);
    }
    await refresh();
  }

  int _compareNullable(String? a, String? b) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Future<void> addTask(TaskDraft draft) async {
    final task = await repository.addTask(draft);
    await refresh();
    select(task.id);
  }

  Future<void> addTaskWithComposition(
    TaskDraft draft,
    List<String> checklist,
    List<TaskDraft> subtasks, {
    List<DraftTaskResource> resources = const [],
    ValueChanged<LifeTask>? onCommitted,
    List<DraftChecklistGroup> groups = const [],
  }) async {
    final task = await repository.db.transaction(() async {
      final task = await repository.addTaskWithComposition(
        draft,
        checklist,
        subtasks,
        groups: groups,
      );
      await repository.addDraftResources(task.id, resources);
      return task;
    });
    onCommitted?.call(task);
    await refresh();
    select(task.id);
  }

  Future<void> addRecurringTask(
    TaskDraft draft,
    RecurrenceRule rule, {
    List<String> progressiveSteps = const [],
    bool repeatPlanAtEnd = false,
    List<DraftTaskResource> resources = const [],
    ValueChanged<LifeTask>? onCommitted,
    List<DraftChecklistGroup> groups = const [],
    List<String> checklist = const [],
    List<TaskDraft> subtasks = const [],
  }) async {
    final task = await repository.db.transaction(() async {
      final task = await repository.addRecurringTask(
        draft,
        rule,
        progressiveSteps: progressiveSteps,
        repeatPlanAtEnd: repeatPlanAtEnd,
      );
      for (final group in groups) {
        final saved = await repository.addChecklistGroup(task.id, group.title);
        for (final title in group.items) {
          await repository.addChecklistItem(task.id, title, groupId: saved.id);
        }
      }
      for (final title in checklist) {
        await repository.addChecklistItem(task.id, title);
      }
      for (final child in subtasks) {
        await repository.addSubtask(task, child);
      }
      await repository.addDraftResources(task.id, resources);
      return task;
    });
    onCommitted?.call(task);
    await refresh();
    select(task.id);
  }

  Future<void> ensureRecurringMonth(DateTime date) async {
    final first = localDate(DateTime(date.year, date.month, 1));
    _eventWindowFrom = RecurrenceRule.shiftDate(first, -7);
    _eventWindowThrough = RecurrenceRule.shiftDate(first, 45);
    await repository.ensureRecurringTasks(
      RecurrenceRule.shiftDate(first, -7),
      RecurrenceRule.shiftDate(first, 45),
    );
    await refresh();
  }

  Future<void> updateTask(
    LifeTask previous,
    TaskDraft draft, {
    Set<String> reviewedPrerequisiteIds = const {},
  }) async {
    await repository.updateTask(
      previous,
      draft,
      reviewedPrerequisiteIds: reviewedPrerequisiteIds,
    );
    await refresh();
  }

  Future<void> setComplete(LifeTask task, bool value) async {
    await repository.setComplete(task, value);
    await refresh();
  }

  Future<void> deleteTask(String id) async {
    await repository.deleteTask(id);
    await refresh();
  }

  Future<void> archiveTask(LifeTask task) async {
    await repository.archiveTask(task);
    await refresh();
  }

  Future<void> archiveSeries(LifeTask task) async {
    await repository.archiveSeries(task);
    await refresh();
  }

  Future<void> restoreArchivedSeries(ArchivedSeries series) async {
    await repository.restoreArchivedSeries(series);
    await refresh();
  }

  Future<void> deleteSeries(LifeTask task) async {
    await repository.deleteSeries(task);
    await refresh();
  }

  Future<void> restoreArchivedTask(LifeTask task) async {
    await repository.restoreArchivedTask(task);
    await refresh();
  }

  Future<void> restoreTrashItem(TrashItem item) async {
    await repository.restoreTrashItem(item);
    await refresh();
  }

  Future<void> permanentlyDelete(TrashItem item) async {
    await repository.permanentlyDelete(item);
    await refresh();
  }

  Future<void> startTimer(String taskId) async {
    await repository.startTimer(taskId);
    await refresh();
  }

  Future<void> startTask(LifeTask task) async {
    await repository.setTaskWorking(task, true);
    await refresh();
  }

  Future<void> endTaskWork(LifeTask task) async {
    if (activeTimer?.taskId == task.id) {
      await repository.stopTimer(activeTimer!);
    }
    await repository.setTaskWorking(task, false);
    await refresh();
  }

  Future<void> startFocusTask(LifeTask task) async {
    await repository.startFocusTask(task);
    await refresh();
  }

  Future<void> pauseTimer() async {
    await repository.pauseTimer(activeTimer!);
    await refresh();
  }

  Future<void> adoptTimerAtCheckpoint(TimerRun previous) async {
    await repository.adoptTimerAtCheckpoint(previous);
    await refresh();
  }

  Future<void> resumeTimer() async {
    await repository.resumeTimer(activeTimer!);
    await refresh();
  }

  Future<void> stopTimer() async {
    await repository.stopTimer(activeTimer!);
    await refresh();
  }

  Future<void> keepRecoveredTimer() async {
    await repository.keepRecoveredTimer(activeTimer!);
    await refresh();
  }

  Future<void> stopRecoveredTimerAtCheckpoint() async {
    await repository.stopRecoveredTimerAtCheckpoint(activeTimer!);
    await refresh();
  }

  Future<void> addManualTime(
    String taskId,
    DateTime startsAt,
    DateTime endsAt,
    String notes,
  ) async {
    await repository.addManualTime(taskId, startsAt, endsAt, notes);
    await refresh();
  }

  Future<void> updateManualTime(
    TimeEntry previous,
    DateTime startsAt,
    DateTime endsAt,
    String notes,
  ) async {
    await repository.updateManualTime(previous, startsAt, endsAt, notes);
    await refresh();
  }

  Future<void> clearManualTime(TimeEntry previous) async {
    await repository.clearManualTime(previous);
    await refresh();
  }

  Future<void> saveTaskTemplate(LifeTask source, String name) async {
    await repository.saveTaskTemplate(source, name);
    await refresh();
  }

  Future<void> saveProjectTemplate(Project project, String name) async {
    await repository.saveProjectTemplate(project, name);
    await refresh();
  }

  Future<String> instantiateTemplate(
    LifeTemplate template, {
    required String anchorDay,
    String? categoryId,
    String? projectId,
    String? projectName,
  }) async {
    final id = await repository.instantiateTemplate(
      template,
      anchorDay: anchorDay,
      categoryId: categoryId,
      projectId: projectId,
      projectName: projectName,
    );
    await refresh();
    if (template.kind == TemplateKind.project) {
      navigate(WorkspaceView.project, id: id);
    } else {
      select(id);
    }
    return id;
  }

  Future<void> deleteTemplate(LifeTemplate template) async {
    await repository.deleteTemplate(template);
    await refresh();
  }

  Future<void> skipRecurringOccurrence(LifeTask task, {bool? carryPlan}) async {
    await repository.skipRecurringOccurrence(task, carryPlan: carryPlan);
    await refresh();
  }

  Future<ProgressivePlan?> progressivePlan(String taskId) =>
      repository.progressivePlan(taskId);

  Future<void> configureProgressivePlan(
    String taskId,
    List<String> steps, {
    required bool repeatAtEnd,
  }) async {
    await repository.configureProgressivePlan(
      taskId,
      steps,
      repeatAtEnd: repeatAtEnd,
    );
    await refresh();
  }

  Future<void> reassignProgressiveStep(String taskId, int index) async {
    await repository.reassignProgressiveStep(taskId, index);
    await refresh();
  }

  Future<void> setProgressiveCarry(String taskId, bool carry) async {
    await repository.setProgressiveCarry(taskId, carry);
    await refresh();
  }

  Future<void> resumeCompletionSeries(LifeTask skipped, String nextDate) async {
    final next = await repository.resumeCompletionSeries(skipped, nextDate);
    await refresh();
    select(next.id);
  }

  Future<RecurrenceDefinition> recurrenceDefinition(String taskId) =>
      repository.recurrenceDefinition(taskId);

  Future<SeriesEditPreview> previewSeriesEdit({
    required LifeTask selected,
    required SeriesEditScope scope,
    required TaskDraft draft,
    required RecurrenceRule rule,
  }) => repository.previewSeriesEdit(
    selected: selected,
    scope: scope,
    draft: draft,
    rule: rule,
  );

  Future<void> applySeriesEdit(
    SeriesEditPreview preview,
    Map<String, SeriesCollisionChoice> choices,
  ) async {
    await repository.applySeriesEdit(preview, choices);
    await refresh();
  }

  List<LifeTask> unmetPrerequisites(String taskId) {
    final byId = {for (final task in tasks) task.id: task};
    return dependencies
        .where((link) => link.taskId == taskId)
        .map((link) => byId[link.prerequisiteId])
        .whereType<LifeTask>()
        .where((task) => task.status != TaskStatus.completed)
        .toList();
  }

  Future<void> setPrerequisites(LifeTask task, Set<String> ids) async {
    await repository.setPrerequisites(task, ids);
    await refresh();
  }

  Future<void> addSequence(String name) async {
    await repository.addSequence(name);
    await refresh();
  }

  Future<void> renameSequence(TaskSequence sequence, String name) async {
    await repository.renameSequence(sequence, name);
    await refresh();
  }

  Future<void> deleteSequence(TaskSequence sequence) async {
    await repository.deleteSequence(sequence);
    await refresh();
  }

  Future<void> setSequenceTasks(TaskSequence sequence, List<String> ids) async {
    await repository.setSequenceTasks(sequence, ids);
    await refresh();
  }

  Future<void> addEvent(EventDraft draft) async {
    await repository.addEvent(draft);
    await refresh();
  }

  Future<void> updateEvent(FixedEvent previous, EventDraft draft) async {
    await repository.updateEvent(previous, draft);
    await refresh();
  }

  Future<void> updateEventOccurrence(
    FixedEvent occurrence,
    EventDraft draft,
  ) async {
    await repository.updateEventOccurrence(occurrence, draft);
    await refresh();
  }

  Future<void> splitEventSeries(
    FixedEvent occurrence,
    String boundary,
    EventDraft draft,
  ) async {
    await repository.splitEventSeries(occurrence, boundary, draft);
    await refresh();
  }

  Future<void> setEventOccurrenceCancelled(
    FixedEvent occurrence,
    bool cancelled,
  ) async {
    await repository.setEventOccurrenceCancelled(occurrence, cancelled);
    await refresh();
  }

  Future<void> endEventSeries(FixedEvent occurrence) async {
    await repository.endEventSeries(occurrence);
    await refresh();
  }

  Future<void> deleteEventFamily(FixedEvent occurrence) async {
    await repository.deleteEventFamily(occurrence);
    await refresh();
  }

  Future<void> deleteEvent(String id) async {
    await repository.deleteEvent(id);
    await refresh();
  }

  Future<void> addSession(SessionDraft draft) async {
    await repository.addSession(draft);
    await refresh();
  }

  Future<void> addHabit(HabitDraft draft) async {
    await repository.addHabit(draft);
    await refresh();
  }

  Future<void> updateHabit(Habit previous, HabitDraft draft) async {
    await repository.updateHabit(previous, draft);
    await refresh();
  }

  Future<void> setHabitArchived(Habit previous, bool archived) async {
    await repository.setHabitArchived(previous, archived);
    await refresh();
  }

  Future<void> recordHabitDay(
    Habit habit,
    String day,
    double value, {
    String notes = '',
    HabitEntry? previous,
  }) async {
    await repository.recordHabitDay(
      habit,
      day,
      value,
      notes: notes,
      previous: previous,
    );
    await refresh();
  }

  Future<void> clearHabitDay(HabitEntry previous) async {
    await repository.clearHabitDay(previous);
    await refresh();
  }

  Future<void> addHabitRestDay(Habit habit, String day) async {
    await repository.addHabitRestDay(habit, day);
    await refresh();
  }

  Future<void> removeHabitRestDay(HabitRestDay rest) async {
    await repository.removeHabitRestDay(rest);
    await refresh();
  }

  Future<void> addGoal(GoalDraft draft, {GoalLinks? links}) async {
    await repository.db.transaction(() async {
      final goal = await repository.addGoal(draft);
      if (links != null) await repository.setGoalLinks(goal, links);
    });
    await refresh();
  }

  Future<void> updateGoal(Goal previous, GoalDraft draft) async {
    await repository.updateGoal(previous, draft);
    await refresh();
  }

  Future<void> setGoalCompleted(Goal previous, bool completed) async {
    await repository.setGoalCompleted(previous, completed);
    await refresh();
  }

  Future<void> setGoalArchived(Goal previous, bool archived) async {
    await repository.setGoalArchived(previous, archived);
    await refresh();
  }

  Future<void> addGoalProgress(Goal goal, double delta, String notes) async {
    await repository.addGoalProgress(goal, delta, notes);
    await refresh();
  }

  Future<void> addGoalMilestone(
    Goal goal,
    String title,
    double threshold,
    String? deadlineDate,
  ) async {
    await repository.addGoalMilestone(goal, title, threshold, deadlineDate);
    await refresh();
  }

  Future<void> setGoalMilestoneCompleted(
    GoalMilestone milestone,
    bool completed,
  ) async {
    await repository.setGoalMilestoneCompleted(milestone, completed);
    await refresh();
  }

  Future<void> updateGoalMilestone(
    Goal goal,
    GoalMilestone previous,
    String title,
    double threshold,
    String? deadlineDate,
  ) async {
    await repository.updateGoalMilestone(
      goal,
      previous,
      title,
      threshold,
      deadlineDate,
    );
    await refresh();
  }

  Future<GoalLinks> goalLinks(String goalId) => repository.goalLinks(goalId);

  Future<void> setGoalLinks(Goal goal, GoalLinks links) async {
    await repository.setGoalLinks(goal, links);
    await refresh();
  }

  Future<List<GoalProgressEntry>> goalProgressHistory(String goalId) =>
      repository.goalProgressHistory(goalId);

  Future<List<GoalLinkedEvent>> goalLinkedEvents(Goal goal) =>
      repository.goalLinkedEvents(goal);

  Future<void> updateSession(WorkSession previous, SessionDraft draft) async {
    await repository.updateSession(previous, draft);
    await refresh();
  }

  Future<void> deleteSession(String id) async {
    await repository.deleteSession(id);
    await refresh();
  }

  Future<void> saveAvailability(AvailabilityPlan value) async {
    await repository.saveAvailability(value);
    await refresh();
  }

  Future<List<SeriesScheduleCollision>> scheduleSeriesCollisions(
    SchedulingPreview preview,
  ) => repository.scheduleSeriesCollisions(preview);

  Future<String> applySchedulingPreview(
    SchedulingPreview preview, {
    Map<String, SeriesCollisionChoice> seriesChoices = const {},
    List<SeriesScheduleCollision> expectedSeriesCollisions = const [],
  }) async {
    final id = await repository.applySchedulingPreview(
      preview,
      seriesChoices: seriesChoices,
      expectedSeriesCollisions: expectedSeriesCollisions,
    );
    await refresh();
    return id;
  }

  Future<SchedulingPreview> previewRestore(
    String operationId, {
    bool original = false,
    bool undo = false,
  }) => repository.previewRestore(operationId, original: original, undo: undo);

  Future<void> addCategory(String name) async {
    await repository.addCategory(name);
    await refresh();
  }

  Future<void> renameCategory(String id, String name) async {
    await repository.renameCategory(id, name);
    await refresh();
  }

  Future<void> setCategoryEventColor(String id, int? color) async {
    await repository.setCategoryEventColor(id, color);
    await refresh();
  }

  int? effectiveEventColor(FixedEvent event) =>
      event.colorValue ??
      categories
          .where((category) => category.id == event.categoryId)
          .firstOrNull
          ?.eventColor;

  Future<void> deleteCategory(String id) async {
    await repository.deleteCategory(id);
    navigate(WorkspaceView.today);
    await refresh();
  }

  Future<void> addProject(String categoryId, String name) async {
    await repository.addProject(categoryId, name);
    await refresh();
  }

  Future<void> renameProject(String id, String name) async {
    await repository.renameProject(id, name);
    await refresh();
  }

  Future<void> deleteProject(String id) async {
    await repository.deleteProject(id);
    navigate(WorkspaceView.today);
    await refresh();
  }
}
