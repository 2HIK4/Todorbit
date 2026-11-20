import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../shared/app_motion.dart';

/// Presentation only: group headers never imply selection or a series edit.
class ScheduleTaskList extends StatelessWidget {
  const ScheduleTaskList({
    super.key,
    required this.tasks,
    required this.parents,
    required this.taskIds,
    required this.selected,
    required this.onChanged,
    this.labels = const {},
  });

  final List<LifeTask> tasks;
  final Map<String, String> parents;
  final Set<String> taskIds;
  final Set<String> selected;
  final void Function(String, bool)? onChanged;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final task in tasks) task.id: task};
    final visible = <String>{...taskIds};
    for (final id in taskIds) {
      final parent = parents[id];
      if (parent != null && byId.containsKey(parent)) visible.add(parent);
    }
    final children = <String, List<LifeTask>>{};
    final roots = <LifeTask>[];
    for (final task in tasks.where((task) => visible.contains(task.id))) {
      final parent = parents[task.id];
      if (parent != null && visible.contains(parent)) {
        (children[parent] ??= []).add(task);
      } else {
        roots.add(task);
      }
    }

    Widget row(LifeTask task, {bool child = false}) {
      final inScope = taskIds.contains(task.id);
      final occurrence = task.recurrenceSeriesId != null;
      final metadata = [
        if (child) 'Subtask',
        if (!inScope) 'Parent context only',
        if (occurrence) 'Occurrence ${task.nominalDate ?? ''}',
        if (task.recurrenceEdited) 'Edited exception',
        if (task.recurrenceRescheduled) 'Rescheduled',
        if (!task.isOpen) task.status.name,
        labels[task.id] ?? task.scheduledDate ?? 'Not planned',
      ].join(' · ');
      final tile = onChanged == null
          ? ListTile(title: Text(task.title), subtitle: Text(metadata))
          : CheckboxListTile(
              key: ValueKey('schedule-task:${task.id}'),
              value: inScope && selected.contains(task.id),
              onChanged: inScope
                  ? (value) => onChanged!(task.id, value!)
                  : null,
              title: Text(task.title),
              subtitle: Text(metadata),
              controlAffinity: ListTileControlAffinity.leading,
            );
      return Padding(
        padding: EdgeInsetsDirectional.only(start: child ? 20 : 0),
        child: child
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: tile,
              )
            : tile,
      );
    }

    Widget hierarchy(LifeTask task) {
      final nested = children[task.id] ?? const <LifeTask>[];
      if (nested.isEmpty) return row(task);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(task),
          ExpansionTile(
            expansionAnimationStyle: AppMotion.style(context),
            key: PageStorageKey(
              'schedule-children:${task.id}:${labels.isEmpty}',
            ),
            initiallyExpanded: true,
            title: Text(
              '${nested.length} ${nested.length == 1 ? 'subtask' : 'subtasks'}',
            ),
            subtitle: const Text(
              'Parent and subtasks are selected separately.',
            ),
            children: [for (final task in nested) row(task, child: true)],
          ),
        ],
      );
    }

    final groups = <String, List<LifeTask>>{};
    for (final task in roots) {
      final family = task.recurrenceFamilyId ?? task.recurrenceSeriesId;
      if (family != null) (groups[family] ??= []).add(task);
    }
    final emitted = <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final task in roots)
          if ((task.recurrenceFamilyId ?? task.recurrenceSeriesId)
              case final String family)
            if (emitted.add(family))
              Builder(
                builder: (context) {
                  final group = groups[family]!;
                  final dates =
                      group
                          .map((task) => task.scheduledDate ?? task.nominalDate)
                          .whereType<String>()
                          .toList()
                        ..sort();
                  final count = group
                      .where((task) => selected.contains(task.id))
                      .length;
                  return ExpansionTile(
                    expansionAnimationStyle: AppMotion.style(context),
                    key: PageStorageKey(
                      'schedule-series:$family:${labels.isEmpty}',
                    ),
                    initiallyExpanded: labels.isNotEmpty && group.length == 1,
                    leading: const Icon(Icons.repeat),
                    title: Text('${task.title} · Recurring series'),
                    subtitle: Text(
                      [
                        'Rule type: ${task.recurrenceKindName ?? 'recurring'}',
                        '${group.length} ${group.length == 1 ? 'occurrence' : 'occurrences'} in scope',
                        if (onChanged != null) '$count selected',
                        if (dates.isNotEmpty)
                          'Planned ${dates.first}${dates.first == dates.last ? '' : ' – ${dates.last}'}',
                      ].join(' · '),
                    ),
                    children: [
                      if (onChanged != null)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Select individual occurrences below. Series rules and history cannot be changed here.',
                          ),
                        ),
                      for (final item in group) hierarchy(item),
                    ],
                  );
                },
              )
            else
              const SizedBox.shrink()
          else
            hierarchy(task),
      ],
    );
  }
}
