import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/legacy.dart';

import '../data/life_repository.dart';
import '../domain/models.dart';

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
  category,
  project,
}

enum TaskSort { schedule, priority, title, created }

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final LifeRepository repository;

  List<Category> categories = [];
  List<Project> projects = [];
  List<LifeTask> tasks = [];
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
    ]);
    categories = result[0] as List<Category>;
    projects = result[1] as List<Project>;
    tasks = result[2] as List<LifeTask>;
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

  void setTheme(ThemeModePreference value) {
    theme = value;
    notifyListeners();
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

enum ThemeModePreference { system, light, dark }
