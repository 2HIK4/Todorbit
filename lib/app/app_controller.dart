import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/legacy.dart';

import '../data/life_repository.dart';
import '../data/appearance_preference_store.dart';
import '../domain/models.dart';
import '../domain/appearance.dart';
import '../domain/scheduling_models.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  throw StateError('AppController must be provided by the application');
});

enum WorkspaceView {
  today,
  all,
  inbox,
  upcoming,
  overdue,
  waiting,
  completed,
  calendar,
  category,
  project,
}

enum TaskSort { schedule, priority, title, created }

class AppController extends ChangeNotifier {
  AppController(this.repository, {this.appearanceStore});
  final LifeRepository repository;
  final AppearancePreferenceStore? appearanceStore;

  List<Category> categories = [];
  List<Project> projects = [];
  List<LifeTask> tasks = [];
  List<FixedEvent> events = [];
  List<WorkSession> sessions = [];
  AvailabilityPlan availability = const AvailabilityPlan(weekly: {});
  List<SchedulingOperation> schedulingHistory = [];
  WorkspaceView view = WorkspaceView.today;
  TaskSort sort = TaskSort.schedule;
  String? scopeId;
  String? selectedTaskId;
  ThemeModePreference theme = ThemeModePreference.system;
  bool loading = true;

  LifeTask? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId) return task;
    }
    return null;
  }

  Future<void> refresh() async {
    final result = await Future.wait<Object>([
      repository.categories(),
      repository.projects(),
      repository.tasks(),
      repository.events(),
      repository.sessions(),
      repository.availability(),
      repository.schedulingHistory(),
    ]);
    categories = result[0] as List<Category>;
    projects = result[1] as List<Project>;
    tasks = result[2] as List<LifeTask>;
    events = result[3] as List<FixedEvent>;
    sessions = result[4] as List<WorkSession>;
    availability = result[5] as AvailabilityPlan;
    schedulingHistory = result[6] as List<SchedulingOperation>;
    if (selectedTaskId != null && selectedTask == null) selectedTaskId = null;
    loading = false;
    notifyListeners();
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
    if (appearanceStore != null) theme = await appearanceStore!.load();
    await refresh();
  }

  Future<void> reloadTheme() async {
    final store = appearanceStore;
    if (store == null) return;
    final value = await store.load();
    if (theme == value) return;
    theme = value;
    notifyListeners();
  }

  Future<void> setTheme(ThemeModePreference value) async {
    final previous = theme;
    theme = value;
    notifyListeners();
    try {
      await appearanceStore?.save(value);
    } catch (_) {
      theme = previous;
      notifyListeners();
      rethrow;
    }
  }

  List<LifeTask> get visibleTasks {
    final today = localDate(DateTime.now());
    final items = tasks.where((task) {
      switch (view) {
        case WorkspaceView.today:
          return task.isOpen && task.scheduledDate == today;
        case WorkspaceView.all:
          return task.isOpen;
        case WorkspaceView.inbox:
          return task.isOpen &&
              task.categoryId == null &&
              task.projectId == null;
        case WorkspaceView.upcoming:
          return task.isOpen &&
              task.scheduledDate != null &&
              task.scheduledDate!.compareTo(today) > 0;
        case WorkspaceView.overdue:
          return task.isOpen &&
              task.deadlineDate != null &&
              task.deadlineDate!.compareTo(today) < 0;
        case WorkspaceView.waiting:
          return task.status == TaskStatus.waiting ||
              task.status == TaskStatus.onHold;
        case WorkspaceView.completed:
          return task.status == TaskStatus.completed ||
              task.status == TaskStatus.cancelled;
        case WorkspaceView.calendar:
          return false;
        case WorkspaceView.category:
          return task.isOpen && task.categoryId == scopeId;
        case WorkspaceView.project:
          return task.isOpen && task.projectId == scopeId;
      }
    }).toList();
    items.sort((a, b) {
      switch (sort) {
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

  Future<void> updateTask(LifeTask previous, TaskDraft draft) async {
    await repository.updateTask(previous, draft);
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

  Future<void> addEvent(EventDraft draft) async {
    await repository.addEvent(draft);
    await refresh();
  }

  Future<void> updateEvent(FixedEvent previous, EventDraft draft) async {
    await repository.updateEvent(previous, draft);
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

  Future<String> applySchedulingPreview(SchedulingPreview preview) async {
    final id = await repository.applySchedulingPreview(preview);
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
