import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/task_list_projection.dart';

class TaskListGroupView extends StatefulWidget {
  const TaskListGroupView({
    super.key,
    required this.group,
    required this.items,
    required this.parents,
    required this.row,
    this.subtaskRow,
    this.margin,
  });

  final TaskListGroup group;
  final List<LifeTask> items;
  final Map<String, String> parents;
  final Widget Function(LifeTask) row;
  final Widget Function(LifeTask)? subtaskRow;
  final EdgeInsetsGeometry? margin;

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

    Widget hierarchy(LifeTask task, {bool isOccurrence = false}) {
      final children = childrenByParent[task.id] ?? const <LifeTask>[];
      if (children.isEmpty) return widget.row(task);

      final expanded = _isExpanded(task.id);
      final scheme = Theme.of(context).colorScheme;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              widget.row(task),
              PositionedDirectional(
                end: 96,
                child: Tooltip(
                  message: expanded
                      ? 'Collapse ${children.length} subtask${children.length == 1 ? '' : 's'}'
                      : 'Expand ${children.length} subtask${children.length == 1 ? '' : 's'}',
                  child: Material(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _expandedSubtasks[task.id] = !expanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${children.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                            Icon(
                              expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

    final resolvedMargin = widget.margin ?? const EdgeInsets.only(bottom: 8);

    return Card(
      margin: resolvedMargin,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(widget.group.key),
        leading: const Icon(Icons.repeat),
        title: Text((next ?? ordered.first).title),
        subtitle: Text(
          '${next == null ? 'Recurring task' : 'Next: ${next.scheduledDate}'} · ${ordered.length} occurrences',
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          for (final task in ordered) hierarchy(task, isOccurrence: true),
        ],
      ),
    );
  }
}
