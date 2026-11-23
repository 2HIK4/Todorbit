import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/task_list_projection.dart';
import 'app_spacing.dart';
import 'task_date_label.dart';

class TaskListGroupView extends StatefulWidget {
  const TaskListGroupView({
    super.key,
    required this.group,
    required this.items,
    required this.parents,
    required this.row,
    this.subtaskRow,
  });

  final TaskListGroup group;
  final List<LifeTask> items;
  final Map<String, String> parents;
  final Widget Function(LifeTask) row;
  final Widget Function(LifeTask)? subtaskRow;

  @override
  State<TaskListGroupView> createState() => _TaskListGroupViewState();
}

class _TaskListGroupViewState extends State<TaskListGroupView> {
  final Map<String, bool> _expandedSubtasks = {};

  bool _isExpanded(String taskId) => _expandedSubtasks[taskId] ?? true;

  @override
  Widget build(BuildContext context) {
    final childrenByParent = <String, List<LifeTask>>{};
    for (final child in widget.items) {
      final parent = widget.parents[child.id];
      if (parent != null) (childrenByParent[parent] ??= []).add(child);
    }

    Widget hierarchy(LifeTask task) {
      final children = childrenByParent[task.id] ?? const <LifeTask>[];
      if (children.isEmpty) return widget.row(task);

      final expanded = _isExpanded(task.id);
      final scheme = Theme.of(context).colorScheme;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.row(task),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.related,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                expanded: expanded,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _expandedSubtasks[task.id] = !expanded),
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(
                    '${children.length} ${children.length == 1 ? 'subtask' : 'subtasks'}',
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 24,
                top: 0,
                bottom: 8,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final child in children)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: widget.subtaskRow != null
                              ? widget.subtaskRow!(child)
                              : widget.row(child),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (!widget.group.recurring) {
      return hierarchy(widget.group.tasks.single);
    }

    final ordered = List.of(widget.group.tasks)
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

    return Column(
      children: [
        ExpansionTile(
          key: PageStorageKey(widget.group.key),
          leading: const Icon(Icons.repeat),
          title: Text((next ?? ordered.first).title),
          subtitle: Text(
            '${next == null ? 'Recurring task' : 'Next ${taskDateLabel(context, next.scheduledDate!)}'} · ${ordered.length} occurrences',
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [for (final task in ordered) hierarchy(task)],
        ),
        const Divider(height: 1),
      ],
    );
  }
}
