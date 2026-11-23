import 'app_refresh_snapshot.dart';
import '../domain/focus_session.dart';
import '../domain/task_resources.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/legacy.dart';

import '../data/life_repository.dart';
import '../data/widget_configuration_store.dart';
import '../data/app_database.dart';
import '../data/appearance_preference_store.dart';
import '../data/calendar_preference_store.dart';
import '../data/backup_service.dart';
import '../domain/models.dart';
import '../domain/alarms.dart';
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

export 'app_refresh_snapshot.dart';

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

  List<AlarmRule> _alarmRules = [];
  UnmodifiableListView<AlarmRule> get alarmRules =>
      UnmodifiableListView(_alarmRules);

  List<Category> _categories = [];
  UnmodifiableListView<Category> get categories =>
      UnmodifiableListView(_categories);

  List<Project> _projects = [];
  UnmodifiableListView<Project> get projects => UnmodifiableListView(_projects);

  List<LifeTask> _tasks = [];
  UnmodifiableListView<LifeTask> get tasks => UnmodifiableListView(_tasks);
  set tasks(List<LifeTask> value) {
    _tasks = List.of(value);
    _invalidateTaskCaches();
  }

  List<FixedEvent> _events = [];
  UnmodifiableListView<FixedEvent> get events => UnmodifiableListView(_events);

  List<FixedEvent> _todayEvents = [];
  UnmodifiableListView<FixedEvent> get todayEvents =>
      UnmodifiableListView(_todayEvents);
  @visibleForTesting
  set todayEvents(List<FixedEvent> value) {
    _todayEvents = List.of(value);
  }

  Map<String, String> _iconKeys = {};
  UnmodifiableMapView<String, String> get iconKeys =>
      UnmodifiableMapView(_iconKeys);

  Map<String, String> _taskParents = {};
  UnmodifiableMapView<String, String> get taskParents =>
      UnmodifiableMapView(_taskParents);

  List<TaskChecklistItem> _checklistItems = [];
  UnmodifiableListView<TaskChecklistItem> get checklistItems =>
      UnmodifiableListView(_checklistItems);

  List<TaskChecklistGroup> _checklistGroups = [];
  UnmodifiableListView<TaskChecklistGroup> get checklistGroups =>
      UnmodifiableListView(_checklistGroups);

  Map<String, ProgressiveAssignment> _progressiveAssignments = {};
  UnmodifiableMapView<String, ProgressiveAssignment>
  get progressiveAssignments => UnmodifiableMapView(_progressiveAssignments);

  String? _eventWindowFrom;
  String? _eventWindowThrough;
  String get eventWindowFrom =>
      _eventWindowFrom ??
      RecurrenceRule.shiftDate(localDate(DateTime.now()), -30);
  String get eventWindowThrough =>
      _eventWindowThrough ??
      RecurrenceRule.shiftDate(localDate(DateTime.now()), 90);
  String get eventWindowLabel => '$eventWindowFrom to $eventWindowThrough';

  List<WorkSession> _sessions = [];
  UnmodifiableListView<WorkSession> get sessions =>
      UnmodifiableListView(_sessions);

  List<TaskDependency> _dependencies = [];
  UnmodifiableListView<TaskDependency> get dependencies =>
      UnmodifiableListView(_dependencies);

  List<TaskSequence> _sequences = [];
  UnmodifiableListView<TaskSequence> get sequences =>
      UnmodifiableListView(_sequences);

  List<Habit> _habits = [];
  UnmodifiableListView<Habit> get habits => UnmodifiableListView(_habits);

  List<HabitEntry> _habitEntries = [];
  UnmodifiableListView<HabitEntry> get habitEntries =>
      UnmodifiableListView(_habitEntries);

  List<HabitRestDay> _habitRestDays = [];
  UnmodifiableListView<HabitRestDay> get habitRestDays =>
      UnmodifiableListView(_habitRestDays);

  List<Goal> _goals = [];
  UnmodifiableListView<Goal> get goals => UnmodifiableListView(_goals);

  List<GoalMilestone> _goalMilestones = [];
  UnmodifiableListView<GoalMilestone> get goalMilestones =>
      UnmodifiableListView(_goalMilestones);

  List<TimeEntry> _timeEntries = [];
  UnmodifiableListView<TimeEntry> get timeEntries =>
      UnmodifiableListView(_timeEntries);

  List<LifeTemplate> _templates = [];
  UnmodifiableListView<LifeTemplate> get templates =>
      UnmodifiableListView(_templates);

  List<SavedView> _savedViews = [];
  UnmodifiableListView<SavedView> get savedViews =>
      UnmodifiableListView(_savedViews);

  List<TrashItem> _trashItems = [];
  UnmodifiableListView<TrashItem> get trashItems =>
      UnmodifiableListView(_trashItems);

  List<LifeTask> _archivedTasks = [];
  UnmodifiableListView<LifeTask> get archivedTasks =>
      UnmodifiableListView(_archivedTasks);

  List<ArchivedSeries> _archivedSeries = [];
  UnmodifiableListView<ArchivedSeries> get archivedSeries =>
      UnmodifiableListView(_archivedSeries);

  List<LifeTask> _reportTasks = [];
  UnmodifiableListView<LifeTask> get reportTasks =>
      UnmodifiableListView(_reportTasks);
  final focusSessions = <String, FocusSession>{};
  Timer? _focusTicker;
  bool _focusBusy = false;
  FocusSession focusSessionFor(String taskId) =>
      focusSessions.putIfAbsent(taskId, () => FocusSession());

  Future<void> changeFocusPhase(
    String taskId, {
    FocusMode? mode,
    PomodoroPhase? phase,
  }) async {
    await pauseFocus(taskId);
    final session = focusSessionFor(taskId);
    if (mode != null) session.mode = mode;
    if (phase != null) session.phase = phase;
    session.reset();
    notifyListeners();
  }

  Future<void> pauseFocus(String taskId, {DateTime? endsAt}) async {
    final session = focusSessionFor(taskId);
    if (activeTimer?.taskId == taskId &&
        activeTimer?.state == TimerState.running) {
      await repository.pauseTimer(activeTimer!, endsAt: endsAt);
      await refreshAfterLocalChange();
    }
    session.pause();
    notifyListeners();
  }

  Future<void> toggleFocus(String taskId) async {
    final session = focusSessionFor(taskId);
    if (session.mode == FocusMode.stopwatch) {
      if (activeTimer?.taskId == taskId &&
          activeTimer?.state == TimerState.running) {
        await pauseTimer();
      } else {
        await _startFocusWork(taskId);
      }
      return;
    }
    if (session.running) {
      await pauseFocus(taskId);
      return;
    }
    if (session.remaining == Duration.zero) session.reset();
    if (session.recordsWork) {
      await _startFocusWork(taskId);
      final open = timeEntries.firstWhere(
        (entry) => entry.timerRunId == activeTimer?.id && entry.endsAt == null,
      );
      session.workDeadline = open.startsAt.add(session.remaining);
    } else {
      await pauseFocus(taskId);
      session.workDeadline = null;
    }
    session.start();
    _focusTicker ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tickFocus(),
    );
    notifyListeners();
  }

  Future<void> _startFocusWork(String taskId) async {
    if (activeTimer != null && activeTimer!.taskId != taskId) {
      throw StateError('Stop the existing timer before focusing another task.');
    }
    if (activeTimer == null) {
      await startFocusTask(tasks.firstWhere((task) => task.id == taskId));
    } else if (activeTimer!.state == TimerState.paused) {
      await resumeTimer();
    } else if (!activeTimer!.canControl ||
        activeTimer!.needsReview(DateTime.now())) {
      throw StateError('Review the existing timer before continuing.');
    }
  }

  Future<void> _tickFocus() async {
    if (_focusBusy || _disposed) return;
    _focusBusy = true;
    try {
      for (final item in focusSessions.entries.toList()) {
        final session = item.value;
        if (!session.running || session.remaining > Duration.zero) continue;
        await pauseFocus(item.key, endsAt: session.workDeadline);
        session.finish();
        notifyListeners();
      }
    } catch (error) {
      for (final session in focusSessions.values) {
        session.pause();
      }
      timerError = '$error';
      notifyListeners();
    } finally {
      _focusBusy = false;
    }
  }

  bool _timerLoaded = false;
  String? _interruptedTimerId;
  TimerRun? activeTimer;
  String? timerError;
  Timer? _timerHeartbeat;
  bool _heartbeatBusy = false;
  Timer? _midnightTimer;
  bool _disposed = false;
  String? _lastKnownDate;
  String? get lastKnownDate => _lastKnownDate;
  @visibleForTesting
  set lastKnownDate(String? value) => _lastKnownDate = value;
  AvailabilityPlan availability = const AvailabilityPlan(weekly: {});
  List<SchedulingOperation> _schedulingHistory = [];
  UnmodifiableListView<SchedulingOperation> get schedulingHistory =>
      UnmodifiableListView(_schedulingHistory);
  WorkspaceView view = WorkspaceView.today;

  List<LifeTask>? _cachedVisibleTasks;
  String? _cachedVisibleTasksDate;
  List<LifeTask>? _cachedFilteredTasks;
  String? _cachedFilteredTasksDate;

  void _invalidateTaskCaches() {
    _cachedVisibleTasks = null;
    _cachedVisibleTasksDate = null;
    _cachedFilteredTasks = null;
    _cachedFilteredTasksDate = null;
  }

  int _stateRevision = 0;
  int get stateRevision => _stateRevision;

  @override
  void notifyListeners() {
    if (_disposed) return;
    _stateRevision++;
    _invalidateTaskCaches();
    super.notifyListeners();
  }

  TaskSort sort = TaskSort.schedule;
  String? scopeId;
  String? selectedTaskId;
  ThemeModePreference theme = ThemeModePreference.system;
  ThemeCustomization customization = const ThemeCustomization();
  int? taskPanelWidth;
  TaskViewPreferences taskViewPreferences = const TaskViewPreferences();
  bool get isFullPageDetails => taskViewPreferences.isFullPageDetails;
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

  Future<void> refreshAfterLocalChange() {
    onLocalChange?.call();
    return refresh();
  }

  Future<void> refresh() async {
    final today = localDate(DateTime.now());
    final materialized = await repository.ensureRecurringTasks(
      RecurrenceRule.shiftDate(today, -14),
      RecurrenceRule.shiftDate(today, 30),
    );
    if (materialized > 0) {
      onLocalChange?.call();
    }
    final snapshot = await AppRefreshSnapshot.load(
      repository,
      eventWindowFrom: eventWindowFrom,
      eventWindowThrough: eventWindowThrough,
      today: today,
    );
    _applyRefreshSnapshot(snapshot, today);
  }

  @visibleForTesting
  void applyRefreshSnapshotForTesting(
    AppRefreshSnapshot snapshot,
    String today,
  ) {
    _applyRefreshSnapshot(snapshot, today);
  }

  void _applyRefreshSnapshot(AppRefreshSnapshot snapshot, String today) {
    if (_disposed) return;
    _categories = snapshot.categories;
    _projects = snapshot.projects;
    _tasks = snapshot.tasks;
    _events = snapshot.events;
    _todayEvents = snapshot.todayEvents;
    _alarmRules = snapshot.alarmRules;
    _sessions = snapshot.sessions;
    availability = snapshot.availability;
    _schedulingHistory = snapshot.schedulingHistory;
    _dependencies = snapshot.dependencies;
    _sequences = snapshot.sequences;
    _habits = snapshot.habits;
    _habitEntries = snapshot.habitEntries;
    _habitRestDays = snapshot.habitRestDays;
    _goals = snapshot.goals;
    _goalMilestones = snapshot.goalMilestones;
    _timeEntries = snapshot.timeEntries;
    activeTimer = snapshot.activeTimer;
    for (final item in focusSessions.entries) {
      if (item.value.recordsWork &&
          (activeTimer?.taskId != item.key ||
              activeTimer?.state != TimerState.running ||
              !activeTimer!.canControl ||
              activeTimer!.needsReview(DateTime.now()))) {
        item.value.pause();
      }
    }
    if (!_timerLoaded) {
      _timerLoaded = true;
      if (activeTimer?.state == TimerState.running && activeTimer!.canControl) {
        _interruptedTimerId = activeTimer!.id;
      }
    }
    if (activeTimer?.id == _interruptedTimerId && activeTimer != null) {
      activeTimer = activeTimer!.forRecovery();
    }
    _templates = snapshot.templates;
    _savedViews = snapshot.savedViews;
    _trashItems = snapshot.trashItems;
    _archivedTasks = snapshot.archivedTasks;
    _archivedSeries = snapshot.archivedSeries;
    _reportTasks = snapshot.reportTasks;
    _iconKeys = snapshot.iconKeys;
    _taskParents = snapshot.taskParents;
    _checklistItems = snapshot.checklistItems;
    _checklistGroups = snapshot.checklistGroups;
    _progressiveAssignments = snapshot.progressiveAssignments;
    _syncTimerHeartbeat();
    _lastKnownDate = today;
    _scheduleMidnightTimer();
    if (selectedTaskId != null && selectedTask == null) selectedTaskId = null;
    loading = false;
    _loadedCalendarStateRevision = _stateRevision;
    notifyListeners();
  }

  @visibleForTesting
  static bool enableMidnightTimerInTests = false;

  void _scheduleMidnightTimer({Duration? retryAfter}) {
    _midnightTimer?.cancel();
    if (_disposed) return;
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        !enableMidnightTimerInTests) {
      return;
    }
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay =
        retryAfter ?? nextMidnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, () async {
      try {
        await checkDateRollover();
      } catch (error, stack) {
        // Keep the previous projection and retry; never replace it with empty
        // data or advance the date marker after a failed refresh.
        _scheduleMidnightTimer(retryAfter: const Duration(minutes: 1));
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'Todorbit date refresh',
          ),
        );
      }
    });
  }

  /// Checks if the local date has changed (e.g. crossing midnight or waking from sleep),
  /// invalidates task caches, and notifies listeners so views like Today rebuild.
  Future<void> checkDateRollover() async {
    if (_disposed) return;
    final today = localDate(DateTime.now());
    if (_lastKnownDate != today) {
      // Refresh also expands recurring tasks and reloads the separate Today
      // event projection when the calendar is browsing another month.
      await refresh();
    } else {
      _scheduleMidnightTimer();
    }
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
    _disposed = true;
    _timerHeartbeat?.cancel();
    _focusTicker?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void navigate(WorkspaceView next, {String? id}) {
    view = next;
    scopeId = id;
    selectedTaskId = null;
    notifyListeners();
  }

  void select(String? taskId) {
    if (selectedTaskId == taskId || _disposed) return;
    selectedTaskId = taskId;
    _stateRevision++;
    super.notifyListeners();
  }

  void setSort(TaskSort value) {
    sort = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (appearanceStore != null) {
      theme = await appearanceStore!.load();
      customization = await appearanceStore!.loadCustomization();
      taskPanelWidth = await appearanceStore!.loadTaskPanelWidth();
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
        'hiddenStandardCategories': taskViewPreferences.hiddenStandardCategories
            .toList(),
        'hiddenStandardProjects': taskViewPreferences.hiddenStandardProjects
            .toList(),
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
      hiddenStandardCategories: (values['hiddenStandardCategories'] as List?)
          ?.cast<String>()
          .toSet(),
      hiddenStandardProjects: (values['hiddenStandardProjects'] as List?)
          ?.cast<String>()
          .toSet(),
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
    _invalidateTaskCaches();
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
      'hiddenStandardCategories': value.hiddenStandardCategories.toList(),
      'hiddenStandardProjects': value.hiddenStandardProjects.toList(),
      'newTaskPlannedDay': value.newTaskPlannedDay.name,
      'compositionTextDisplay': value.compositionTextDisplay.name,
    });
    await appearanceStore?.saveTaskViewPreferences(value);
    taskViewPreferences = value;
    _invalidateTaskCaches();
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
    await refreshAfterLocalChange();
  }

  Future<void> addSubtask(
    LifeTask parent,
    TaskDraft draft, {
    List<DraftTaskResource> resources = const [],
    ValueChanged<LifeTask>? onCommitted,
    List<DraftChecklistGroup> groups = const [],
  }) async {
    final child = await repository.addSubtaskWithComposition(
      parent,
      draft,
      groups: groups,
      resources: resources,
    );
    onCommitted?.call(child);
    await refreshAfterLocalChange();
    select(child.id);
  }

  Future<void> addChecklistItem(
    String taskId,
    String title, {
    String? groupId,
  }) async {
    await repository.addChecklistItem(taskId, title, groupId: groupId);
    await refreshAfterLocalChange();
  }

  Future<void> updateChecklistItem(
    TaskChecklistItem item, {
    String? title,
    bool? done,
  }) async {
    await repository.updateChecklistItem(item, title: title, done: done);
    await refreshAfterLocalChange();
  }

  Future<void> removeChecklistItem(TaskChecklistItem item) async {
    await repository.removeChecklistItem(item);
    await refreshAfterLocalChange();
  }

  Future<void> moveChecklistItem(TaskChecklistItem item, int direction) async {
    await repository.moveChecklistItem(item, direction);
    await refreshAfterLocalChange();
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
    store.invalidateCache();
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

  Future<void> setTaskPanelWidth(int width) async {
    await appearanceStore?.saveTaskPanelWidth(width);
    taskPanelWidth = width;
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

  List<LifeTask> get filteredTasks {
    if (!activeFilter.isActive) return tasks;
    final today = localDate(DateTime.now());
    if (_cachedFilteredTasks != null && _cachedFilteredTasksDate == today) {
      return _cachedFilteredTasks!;
    }
    _cachedFilteredTasksDate = today;
    return _cachedFilteredTasks = List.unmodifiable(searchTasks(activeFilter));
  }

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

  /// Projects the filtered event window onto one local calendar day.
  List<FixedEvent> agendaForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return filteredEvents
        .where(
          (event) =>
              !event.cancelled &&
              event.startsAt.toLocal().isBefore(end) &&
              event.endsAt.toLocal().isAfter(start),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  List<WorkSession> get filteredSessions {
    if (!activeFilter.isActive) return sessions;
    final ids = filteredTasks.map((task) => task.id).toSet();
    return sessions.where((session) => ids.contains(session.taskId)).toList();
  }

  bool isStandardView(WorkspaceView v) =>
      v == WorkspaceView.today ||
      v == WorkspaceView.anytime ||
      v == WorkspaceView.all ||
      v == WorkspaceView.inbox ||
      v == WorkspaceView.upcoming ||
      v == WorkspaceView.overdue ||
      v == WorkspaceView.waiting ||
      v == WorkspaceView.completed;

  bool isTaskHiddenFromStandard(LifeTask task) {
    if (task.categoryId != null &&
        taskViewPreferences.hiddenStandardCategories.contains(
          task.categoryId,
        )) {
      return true;
    }
    if (task.projectId != null &&
        taskViewPreferences.hiddenStandardProjects.contains(task.projectId)) {
      return true;
    }
    return false;
  }

  bool isCategoryShownInStandardViews(String categoryId) =>
      !taskViewPreferences.hiddenStandardCategories.contains(categoryId);

  bool isProjectShownInStandardViews(String projectId) =>
      !taskViewPreferences.hiddenStandardProjects.contains(projectId);

  Future<void> toggleCategoryStandardVisibility(String categoryId) async {
    final hidden = Set<String>.from(
      taskViewPreferences.hiddenStandardCategories,
    );
    if (hidden.contains(categoryId)) {
      hidden.remove(categoryId);
    } else {
      hidden.add(categoryId);
    }
    await setTaskViewPreferences(
      taskViewPreferences.copyWith(hiddenStandardCategories: hidden),
    );
  }

  Future<void> toggleProjectStandardVisibility(String projectId) async {
    final hidden = Set<String>.from(taskViewPreferences.hiddenStandardProjects);
    if (hidden.contains(projectId)) {
      hidden.remove(projectId);
    } else {
      hidden.add(projectId);
    }
    await setTaskViewPreferences(
      taskViewPreferences.copyWith(hiddenStandardProjects: hidden),
    );
  }

  int get hiddenStandardTasksCount {
    if (!isStandardView(view)) return 0;
    final today = localDate(DateTime.now());
    bool active(LifeTask task) =>
        task.isOpen ||
        (taskViewPreferences.keepCompletedVisible &&
            task.status == TaskStatus.completed) ||
        activeFilter.statuses.contains(task.status);
    return filteredTasks.where((task) {
      if (!isTaskHiddenFromStandard(task)) return false;
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
        default:
          return false;
      }
    }).length;
  }

  Future<SavedView> duplicateSavedView(
    SavedView original, [
    String? newName,
  ]) async {
    final name = newName ?? '${original.name} (copy)';
    final created = await repository.duplicateSavedView(original, name);
    _savedViews = await repository.savedViews();
    _invalidateTaskCaches();
    notifyListeners();
    return created;
  }

  Future<void> renameSavedView(SavedView previous, String newName) async {
    await repository.renameSavedView(previous, newName);
    _savedViews = await repository.savedViews();
    _invalidateTaskCaches();
    notifyListeners();
  }

  Future<void> deleteArchivedTask(LifeTask task) async {
    await repository.deleteArchivedTask(task);
    await refreshAfterLocalChange();
  }

  Future<void> deleteArchivedSeries(ArchivedSeries series) async {
    await repository.deleteArchivedSeries(series);
    await refreshAfterLocalChange();
  }

  Future<Map<String, List<String>>> taskResourceSubtaskMap(String taskId) =>
      repository.taskResourceSubtaskMap(taskId);

  Future<void> assignResourceToSubtasks(
    String resourceId,
    List<String> subtaskIds,
  ) async {
    await repository.assignResourceToSubtasks(resourceId, subtaskIds);
    notifyListeners();
  }

  Future<void> moveSavedView(String viewId, int direction) async {
    final current = List<String>.from(orderedSavedViews.map((v) => v.id));
    final index = current.indexOf(viewId);
    if (index == -1) return;
    final target = index + direction;
    if (target < 0 || target >= current.length) return;
    final item = current.removeAt(index);
    current.insert(target, item);
    await setNavigationState(customOrder: current);
  }

  List<LifeTask> get visibleTasks {
    final today = localDate(DateTime.now());
    if (_cachedVisibleTasks != null && _cachedVisibleTasksDate == today) {
      return _cachedVisibleTasks!;
    }
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

    bool customViewAllows(LifeTask task, SavedView? v) {
      if (!isTaskHiddenFromStandard(task)) return true;
      if (v == null) return false;
      final f = v.filter;
      final includesCategory =
          task.categoryId != null &&
          (f.categoryIds.contains(task.categoryId) ||
              f.categoryId == task.categoryId);
      final includesProject =
          task.projectId != null &&
          (f.projectIds.contains(task.projectId) ||
              f.projectId == task.projectId);
      return includesCategory || includesProject;
    }

    final items = filteredTasks.where((task) {
      if (isStandardView(view) && isTaskHiddenFromStandard(task)) {
        return false;
      }
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
          return savedIds.contains(task.id) &&
              customViewAllows(task, selectedView);
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
    _cachedVisibleTasks = List.unmodifiable(items);
    _cachedVisibleTasksDate = today;
    return _cachedVisibleTasks!;
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
    await refreshAfterLocalChange();
    navigate(WorkspaceView.saved, id: view.id);
    return view;
  }

  Future<void> updateSavedView(
    SavedView previous,
    String name,
    TaskFilter filter,
  ) async {
    await repository.updateSavedView(previous, name, filter);
    await refreshAfterLocalChange();
  }

  Future<void> deleteSavedView(SavedView previous) async {
    await repository.deleteSavedView(previous);
    if (view == WorkspaceView.saved && scopeId == previous.id) {
      navigate(WorkspaceView.today);
    }
    await refreshAfterLocalChange();
  }

  int _compareNullable(String? a, String? b) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Future<void> addTask(TaskDraft draft) async {
    final task = await repository.addTask(draft);
    await refreshAfterLocalChange();
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
    final task = await repository.addTaskWithComposition(
      draft,
      checklist,
      subtasks,
      groups: groups,
      resources: resources,
    );
    onCommitted?.call(task);
    await refreshAfterLocalChange();
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
    final task = await repository.addRecurringTaskWithComposition(
      draft,
      rule,
      progressiveSteps: progressiveSteps,
      repeatPlanAtEnd: repeatPlanAtEnd,
      groups: groups,
      checklist: checklist,
      subtasks: subtasks,
      resources: resources,
    );
    onCommitted?.call(task);
    await refreshAfterLocalChange();
    select(task.id);
  }

  DateTime? _requestedRecurringMonth;
  Future<void>? _recurringMonthLoad;
  int? _loadedCalendarStateRevision;

  Future<void> ensureRecurringMonth(DateTime date) {
    _requestedRecurringMonth = DateTime(date.year, date.month);
    return _recurringMonthLoad ??= _loadRequestedRecurringMonths().whenComplete(
      () {
        _recurringMonthLoad = null;
      },
    );
  }

  Future<void> refreshCalendarWindow() async {
    final today = localDate(DateTime.now());
    final windowEvents = repository.eventOccurrences(
      eventWindowFrom,
      eventWindowThrough,
    );
    final todayEventsLoad =
        today.compareTo(eventWindowFrom) >= 0 &&
            today.compareTo(eventWindowThrough) <= 0
        ? windowEvents
        : repository.eventOccurrences(today, today);
    final results = await Future.wait([
      windowEvents,
      todayEventsLoad,
      repository.tasks(),
      repository.taskParents(),
      repository.reportTasks(),
    ]);
    if (_disposed) return;
    _events = results[0] as List<FixedEvent>;
    _todayEvents = results[1] as List<FixedEvent>;
    tasks = results[2] as List<LifeTask>;
    _taskParents = results[3] as Map<String, String>;
    _reportTasks = results[4] as List<LifeTask>;
    notifyListeners();
  }

  Future<void> _loadRequestedRecurringMonths() async {
    while (_requestedRecurringMonth != null) {
      final date = _requestedRecurringMonth!;
      _requestedRecurringMonth = null;
      final from = localDate(DateTime(date.year, date.month - 1, 1));
      final through = localDate(DateTime(date.year, date.month + 2, 0));
      if (_eventWindowFrom == from &&
          _eventWindowThrough == through &&
          _loadedCalendarStateRevision == stateRevision) {
        continue;
      }
      final materialized = await repository.ensureRecurringTasks(from, through);
      if (materialized > 0) {
        onLocalChange?.call();
      }
      // Navigation may have advanced while recurrence was materializing. Only
      // load the newest requested window, and never run overlapping refreshes.
      if (_requestedRecurringMonth != null) continue;
      final previousFrom = _eventWindowFrom;
      final previousThrough = _eventWindowThrough;
      _eventWindowFrom = from;
      _eventWindowThrough = through;
      try {
        await refreshCalendarWindow();
        _loadedCalendarStateRevision = stateRevision;
      } catch (_) {
        _eventWindowFrom = previousFrom;
        _eventWindowThrough = previousThrough;
        rethrow;
      }
    }
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
    await refreshAfterLocalChange();
  }

  Future<void> setComplete(LifeTask task, bool value) async {
    await repository.setComplete(task, value);
    await refreshAfterLocalChange();
  }

  Future<void> deleteTask(String id) async {
    await repository.deleteTask(id);
    await refreshAfterLocalChange();
  }

  Future<void> archiveTask(LifeTask task) async {
    await repository.archiveTask(task);
    await refreshAfterLocalChange();
  }

  Future<void> archiveSeries(LifeTask task) async {
    await repository.archiveSeries(task);
    await refreshAfterLocalChange();
  }

  Future<void> restoreArchivedSeries(ArchivedSeries series) async {
    await repository.restoreArchivedSeries(series);
    await refreshAfterLocalChange();
  }

  Future<void> deleteSeries(LifeTask task) async {
    await repository.deleteSeries(task);
    await refreshAfterLocalChange();
  }

  Future<void> restoreArchivedTask(LifeTask task) async {
    await repository.restoreArchivedTask(task);
    await refreshAfterLocalChange();
  }

  Future<void> restoreTrashItem(TrashItem item) async {
    await repository.restoreTrashItem(item);
    await refreshAfterLocalChange();
  }

  Future<void> permanentlyDelete(TrashItem item) async {
    await repository.permanentlyDelete(item);
    await refreshAfterLocalChange();
  }

  Future<void> startTimer(String taskId) async {
    await repository.startTimer(taskId);
    await refreshAfterLocalChange();
  }

  final _timerEntries = <String, Future<void>>{};

  Future<void> enterTaskTimer(String taskId) => _timerEntries.putIfAbsent(
    taskId,
    () => _enterTaskTimer(taskId).whenComplete(() {
      _timerEntries.remove(taskId);
    }),
  );

  Future<void> _enterTaskTimer(String taskId) async {
    final run = await repository.activeTimerRun();
    if (run != null) {
      // Reopening a paused/recovered/remote session never resumes or adopts it.
      if (run.taskId != taskId) throw StateError('Another timer is active');
      await refresh();
      return;
    }
    if (focusSessionFor(taskId).mode == FocusMode.stopwatch) {
      await startTimer(taskId);
    } else {
      await toggleFocus(taskId);
    }
  }

  Future<void> switchTaskTimer(TimerRun previous, String taskId) async {
    final session = focusSessionFor(taskId);
    await repository.switchTaskTimer(
      previous,
      taskId,
      startWork: session.mode == FocusMode.stopwatch || session.recordsWork,
    );
    focusSessions[previous.taskId]?.pause();
    await refreshAfterLocalChange();
    if (session.mode != FocusMode.stopwatch && !session.running) {
      // The new ledger interval is already running. Start the selected phase
      // without toggling (and therefore pausing) that interval.
      if (session.remaining == Duration.zero) session.reset();
      if (session.recordsWork) {
        session.workDeadline = timeEntries
            .firstWhere(
              (entry) =>
                  entry.timerRunId == activeTimer?.id && entry.endsAt == null,
            )
            .startsAt
            .add(session.remaining);
        session.start();
        _focusTicker ??= Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => _tickFocus(),
        );
      } else {
        await toggleFocus(taskId);
      }
    }
    notifyListeners();
  }

  Future<void> startTask(LifeTask task) async {
    await repository.setTaskWorking(task, true);
    await refreshAfterLocalChange();
  }

  Future<void> endTaskWork(LifeTask task) async {
    if (activeTimer?.taskId == task.id) {
      await repository.stopTimer(activeTimer!);
    }
    await repository.setTaskWorking(task, false);
    await refreshAfterLocalChange();
  }

  Future<void> startFocusTask(LifeTask task) async {
    await repository.startFocusTask(task);
    await refreshAfterLocalChange();
  }

  Future<void> pauseTimer() async {
    final session = focusSessions[activeTimer?.taskId];
    await repository.pauseTimer(activeTimer!);
    session?.pause();
    await refreshAfterLocalChange();
  }

  Future<void> adoptTimerAtCheckpoint(TimerRun previous) async {
    await repository.adoptTimerAtCheckpoint(previous);
    await refreshAfterLocalChange();
  }

  Future<void> resumeTimer() async {
    await repository.resumeTimer(activeTimer!);
    await refreshAfterLocalChange();
  }

  Future<void> stopTimer() async {
    final session = focusSessions[activeTimer?.taskId];
    await repository.stopTimer(activeTimer!);
    session?.pause();
    await refreshAfterLocalChange();
  }

  Future<void> keepRecoveredTimer() async {
    await repository.keepRecoveredTimer(activeTimer!);
    _interruptedTimerId = null;
    await refreshAfterLocalChange();
  }

  Future<void> stopRecoveredTimerAtCheckpoint() async {
    await repository.stopRecoveredTimerAtCheckpoint(activeTimer!);
    _interruptedTimerId = null;
    await refreshAfterLocalChange();
  }

  Future<void> addManualTime(
    String taskId,
    DateTime startsAt,
    DateTime endsAt,
    String notes,
  ) async {
    await repository.addManualTime(taskId, startsAt, endsAt, notes);
    await refreshAfterLocalChange();
  }

  Future<void> updateManualTime(
    TimeEntry previous,
    DateTime startsAt,
    DateTime endsAt,
    String notes,
  ) async {
    await repository.updateManualTime(previous, startsAt, endsAt, notes);
    await refreshAfterLocalChange();
  }

  Future<void> clearManualTime(TimeEntry previous) async {
    await repository.clearManualTime(previous);
    await refreshAfterLocalChange();
  }

  Future<void> saveTaskTemplate(LifeTask source, String name) async {
    await repository.saveTaskTemplate(source, name);
    await refreshAfterLocalChange();
  }

  Future<void> saveProjectTemplate(Project project, String name) async {
    await repository.saveProjectTemplate(project, name);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
    if (template.kind == TemplateKind.project) {
      navigate(WorkspaceView.project, id: id);
    } else {
      select(id);
    }
    return id;
  }

  Future<void> deleteTemplate(LifeTemplate template) async {
    await repository.deleteTemplate(template);
    await refreshAfterLocalChange();
  }

  Future<void> skipRecurringOccurrence(LifeTask task, {bool? carryPlan}) async {
    await repository.skipRecurringOccurrence(task, carryPlan: carryPlan);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
  }

  Future<void> reassignProgressiveStep(String taskId, int index) async {
    await repository.reassignProgressiveStep(taskId, index);
    await refreshAfterLocalChange();
  }

  Future<void> setProgressiveCarry(String taskId, bool carry) async {
    await repository.setProgressiveCarry(taskId, carry);
    await refreshAfterLocalChange();
  }

  Future<void> resumeCompletionSeries(LifeTask skipped, String nextDate) async {
    final next = await repository.resumeCompletionSeries(skipped, nextDate);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
  }

  Future<void> addSequence(String name) async {
    await repository.addSequence(name);
    await refreshAfterLocalChange();
  }

  Future<void> renameSequence(TaskSequence sequence, String name) async {
    await repository.renameSequence(sequence, name);
    await refreshAfterLocalChange();
  }

  Future<void> deleteSequence(TaskSequence sequence) async {
    await repository.deleteSequence(sequence);
    await refreshAfterLocalChange();
  }

  Future<void> setSequenceTasks(TaskSequence sequence, List<String> ids) async {
    await repository.setSequenceTasks(sequence, ids);
    await refreshAfterLocalChange();
  }

  Future<void> addEvent(EventDraft draft) async {
    await repository.addEvent(draft);
    await refreshAfterLocalChange();
  }

  Future<void> updateEvent(FixedEvent previous, EventDraft draft) async {
    await repository.updateEvent(previous, draft);
    await refreshAfterLocalChange();
  }

  Future<void> moveCalendarSeries(FixedEvent previous, EventDraft draft) async {
    await repository.moveCalendarSeries(previous, draft);
    await refreshAfterLocalChange();
  }

  Future<String?> calendarSeriesMoveProblem(
    FixedEvent master, [
    EventDraft? draft,
  ]) => repository.calendarSeriesMoveProblem(master, draft);

  Future<void> updateEventOccurrence(
    FixedEvent occurrence,
    EventDraft draft,
  ) async {
    await repository.updateEventOccurrence(occurrence, draft);
    await refreshAfterLocalChange();
  }

  Future<void> splitEventSeries(
    FixedEvent occurrence,
    String boundary,
    EventDraft draft,
  ) async {
    await repository.splitEventSeries(occurrence, boundary, draft);
    await refreshAfterLocalChange();
  }

  Future<void> setEventOccurrenceCancelled(
    FixedEvent occurrence,
    bool cancelled,
  ) async {
    await repository.setEventOccurrenceCancelled(occurrence, cancelled);
    await refreshAfterLocalChange();
  }

  Future<void> endEventSeries(FixedEvent occurrence) async {
    await repository.endEventSeries(occurrence);
    await refreshAfterLocalChange();
  }

  Future<void> deleteEventFamily(FixedEvent occurrence) async {
    await repository.deleteEventFamily(occurrence);
    await refreshAfterLocalChange();
  }

  Future<void> deleteEvent(String id) async {
    await repository.deleteEvent(id);
    await refreshAfterLocalChange();
  }

  Future<void> addSession(SessionDraft draft) async {
    await repository.addSession(draft);
    await refreshAfterLocalChange();
  }

  Future<void> addHabit(HabitDraft draft) async {
    await repository.addHabit(draft);
    await refreshAfterLocalChange();
  }

  Future<void> updateHabit(Habit previous, HabitDraft draft) async {
    await repository.updateHabit(previous, draft);
    await refreshAfterLocalChange();
  }

  Future<void> setHabitArchived(Habit previous, bool archived) async {
    await repository.setHabitArchived(previous, archived);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
  }

  Future<void> clearHabitDay(HabitEntry previous) async {
    await repository.clearHabitDay(previous);
    await refreshAfterLocalChange();
  }

  Future<void> addHabitRestDay(Habit habit, String day) async {
    await repository.addHabitRestDay(habit, day);
    await refreshAfterLocalChange();
  }

  Future<void> removeHabitRestDay(HabitRestDay rest) async {
    await repository.removeHabitRestDay(rest);
    await refreshAfterLocalChange();
  }

  Future<void> addGoal(GoalDraft draft, {GoalLinks? links}) async {
    await repository.addGoalWithComposition(draft, links: links);
    await refreshAfterLocalChange();
  }

  Future<void> updateGoal(Goal previous, GoalDraft draft) async {
    await repository.updateGoal(previous, draft);
    await refreshAfterLocalChange();
  }

  Future<void> setGoalCompleted(Goal previous, bool completed) async {
    await repository.setGoalCompleted(previous, completed);
    await refreshAfterLocalChange();
  }

  Future<void> setGoalArchived(Goal previous, bool archived) async {
    await repository.setGoalArchived(previous, archived);
    await refreshAfterLocalChange();
  }

  Future<void> addGoalProgress(Goal goal, double delta, String notes) async {
    await repository.addGoalProgress(goal, delta, notes);
    await refreshAfterLocalChange();
  }

  Future<void> addGoalMilestone(
    Goal goal,
    String title,
    double threshold,
    String? deadlineDate,
  ) async {
    await repository.addGoalMilestone(goal, title, threshold, deadlineDate);
    await refreshAfterLocalChange();
  }

  Future<void> setGoalMilestoneCompleted(
    GoalMilestone milestone,
    bool completed,
  ) async {
    await repository.setGoalMilestoneCompleted(milestone, completed);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
  }

  Future<GoalLinks> goalLinks(String goalId) => repository.goalLinks(goalId);

  Future<void> setGoalLinks(Goal goal, GoalLinks links) async {
    await repository.setGoalLinks(goal, links);
    await refreshAfterLocalChange();
  }

  Future<List<GoalProgressEntry>> goalProgressHistory(String goalId) =>
      repository.goalProgressHistory(goalId);

  Future<List<GoalLinkedEvent>> goalLinkedEvents(Goal goal) =>
      repository.goalLinkedEvents(goal);

  Future<void> updateSession(WorkSession previous, SessionDraft draft) async {
    await repository.updateSession(previous, draft);
    await refreshAfterLocalChange();
  }

  Future<void> deleteSession(String id) async {
    await repository.deleteSession(id);
    await refreshAfterLocalChange();
  }

  Future<void> saveAvailability(AvailabilityPlan value) async {
    await repository.saveAvailability(value);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
    return id;
  }

  Future<SchedulingPreview> previewRestore(
    String operationId, {
    bool original = false,
    bool undo = false,
  }) => repository.previewRestore(operationId, original: original, undo: undo);

  Future<void> addCategory(String name) async {
    await repository.addCategory(name);
    await refreshAfterLocalChange();
  }

  Future<void> renameCategory(String id, String name) async {
    await repository.renameCategory(id, name);
    await refreshAfterLocalChange();
  }

  Future<void> setCategoryEventColor(String id, int? color) async {
    await repository.setCategoryEventColor(id, color);
    await refreshAfterLocalChange();
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
    await refreshAfterLocalChange();
  }

  Future<void> addProject(String categoryId, String name) async {
    await repository.addProject(categoryId, name);
    await refreshAfterLocalChange();
  }

  Future<void> renameProject(String id, String name) async {
    await repository.renameProject(id, name);
    await refreshAfterLocalChange();
  }

  Future<void> deleteProject(String id) async {
    await repository.deleteProject(id);
    navigate(WorkspaceView.today);
    await refreshAfterLocalChange();
  }
}
