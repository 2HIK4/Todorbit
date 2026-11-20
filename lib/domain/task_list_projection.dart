import 'package:meta/meta.dart';

import 'models.dart';

class TaskListGroup {
  const TaskListGroup(this.key, this.tasks, {this.recurring = false});
  final String key;
  final List<LifeTask> tasks;
  final bool recurring;
}

List<LifeTask>? _lastTasks;
Map<String, String>? _lastParents;
bool? _lastGroupRecurrence;
List<LifeTask>? _lastRelated;
List<TaskListGroup>? _lastResult;

@visibleForTesting
void resetTaskListProjectionCacheForTesting() {
  _lastTasks = null;
  _lastParents = null;
  _lastGroupRecurrence = null;
  _lastRelated = null;
  _lastResult = null;
}

// Presentation only: never changes identity, dates, or occurrence state. Input
// is already filtered; a matching child stays discoverable without its parent.
List<TaskListGroup> projectTaskList(
  List<LifeTask> tasks,
  Map<String, String> parents, {
  required bool groupRecurrence,
  List<LifeTask> relatedOccurrences = const [],
}) {
  if (identical(tasks, _lastTasks) &&
      identical(parents, _lastParents) &&
      groupRecurrence == _lastGroupRecurrence &&
      identical(relatedOccurrences, _lastRelated) &&
      _lastResult != null) {
    return _lastResult!;
  }
  final ids = tasks.map((task) => task.id).toSet();
  final groups = <String, List<LifeTask>>{};
  final recurringKeys = <String>{};
  for (final task in tasks) {
    if (ids.contains(parents[task.id])) continue;
    final series = task.recurrenceFamilyId ?? task.recurrenceSeriesId;
    final key = groupRecurrence && series != null
        ? 'series:$series'
        : 'task:${task.id}';
    if (groupRecurrence && series != null) recurringKeys.add(key);
    (groups[key] ??= []).add(task);
  }
  for (final task in relatedOccurrences) {
    final series = task.recurrenceFamilyId ?? task.recurrenceSeriesId;
    final key = 'series:$series';
    if (recurringKeys.contains(key) &&
        !ids.contains(task.id) &&
        !parents.containsKey(task.id)) {
      groups[key]!.add(task);
    }
  }
  final result = [
    for (final entry in groups.entries)
      TaskListGroup(
        entry.key,
        entry.value,
        recurring: recurringKeys.contains(entry.key),
      ),
  ];
  _lastTasks = tasks;
  _lastParents = parents;
  _lastGroupRecurrence = groupRecurrence;
  _lastRelated = relatedOccurrences;
  _lastResult = result;
  return result;
}
