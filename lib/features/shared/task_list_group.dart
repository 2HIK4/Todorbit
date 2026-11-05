import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/task_list_projection.dart';

class TaskListGroupView extends StatelessWidget {
  const TaskListGroupView({
    super.key,
    required this.group,
    required this.items,
    required this.parents,
    required this.row,
  });
  final TaskListGroup group;
  final List<LifeTask> items;
  final Map<String, String> parents;
  final Widget Function(LifeTask) row;

  @override
  Widget build(BuildContext context) {
    final childrenByParent = <String, List<LifeTask>>{};
    for (final child in items) {
      final parent = parents[child.id];
      if (parent != null) (childrenByParent[parent] ??= []).add(child);
    }
    Widget hierarchy(LifeTask task) {
      final children = childrenByParent[task.id] ?? const <LifeTask>[];
      if (children.isEmpty) return row(task);
      return ExpansionTile(
        key: PageStorageKey('task-children:${task.id}'),
        title: row(task),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsetsDirectional.only(start: 24),
        subtitle: Text('${children.length} subtasks'),
        children: [for (final child in children) row(child)],
      );
    }

    if (!group.recurring) return hierarchy(group.tasks.single);
    final ordered = List.of(group.tasks)
      ..sort(
        (a, b) => (a.scheduledDate ?? a.nominalDate ?? '').compareTo(
          b.scheduledDate ?? b.nominalDate ?? '',
        ),
      );
    final today = DateUtils.dateOnly(DateTime.now());
    final next = ordered
        .where(
          (task) =>
              task.isOpen &&
              task.scheduledDate != null &&
              !DateTime.parse(task.scheduledDate!).isBefore(today),
        )
        .firstOrNull;
    return Card(
      child: ExpansionTile(
        key: PageStorageKey(group.key),
        leading: const Icon(Icons.repeat),
        title: Text((next ?? ordered.first).title),
        subtitle: Text(
          '${next == null ? 'Recurring task' : 'Next: ${next.scheduledDate}'} · ${ordered.length} occurrences',
        ),
        children: [for (final task in ordered) hierarchy(task)],
      ),
    );
  }
}
