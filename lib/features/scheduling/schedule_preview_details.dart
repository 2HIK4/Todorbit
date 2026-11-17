import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/scheduling_models.dart';
import '../../domain/series_edit.dart';
import 'schedule_task_list.dart';
import '../shared/app_motion.dart';

class SchedulePreviewDetails extends StatelessWidget {
  const SchedulePreviewDetails({
    super.key,
    required this.preview,
    required this.tasks,
    required this.parents,
    required this.collisions,
    required this.choices,
    required this.onKeep,
    required this.onLeave,
    required this.sessionMode,
    required this.sessions,
    required this.labels,
    required this.titles,
  });

  final SchedulingPreview preview;
  final List<LifeTask> tasks;
  final Map<String, String> parents;
  final List<SeriesScheduleCollision> collisions;
  final Map<String, SeriesCollisionChoice> choices;
  final void Function(Set<String>) onKeep;
  final void Function(Set<String>) onLeave;
  final bool sessionMode;
  final List<WorkSession> sessions;
  final Map<String, String> labels;
  final Map<String, String> titles;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final task in tasks) task.id: task};
    final groups = <String, List<SeriesScheduleCollision>>{};
    for (final collision in collisions) {
      final task = byId[collision.movedTaskId];
      final family =
          task?.recurrenceFamilyId ??
          task?.recurrenceSeriesId ??
          collision.movedTaskId;
      (groups[family] ??= []).add(collision);
    }
    final sessionTasks = {
      for (final session in sessions) session.id: session.taskId,
    };
    final seriesCount = preview.changes
        .map(
          (change) =>
              byId[change.targetKind == ScheduleTargetKind.task
                  ? change.targetId
                  : change.taskId ?? sessionTasks[change.targetId]],
        )
        .whereType<LifeTask>()
        .map((task) => task.recurrenceFamilyId ?? task.recurrenceSeriesId)
        .whereType<String>()
        .toSet()
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(
            'Preview · ${preview.changes.length} ${sessionMode ? (preview.changes.length == 1 ? 'session' : 'sessions') : (preview.changes.length == 1 ? 'task' : 'tasks')} · $seriesCount recurring series',
          ),
          subtitle: Text(
            '${groups.length} recurring collision ${groups.length == 1 ? 'group' : 'groups'} · ${preview.issues.length} scheduling issues. ${sessionMode ? '' : 'Task dates only; work sessions stay unchanged. '}Not applied.',
          ),
        ),
        for (final entry in groups.entries)
          Builder(
            builder: (context) {
              final items = entry.value;
              final ids = items.map((item) => item.movedTaskId).toSet();
              final existing =
                  items.expand((item) => item.existingTaskIds).toSet()
                    ..removeAll(ids);
              final dates =
                  items.map((item) => item.plannedDate).toSet().toList()
                    ..sort();
              final resolved = ids.every(
                (id) => choices[id] == SeriesCollisionChoice.keepBoth,
              );
              final title =
                  byId[items.first.movedTaskId]?.title ?? 'Recurring series';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: Icon(
                      resolved
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                    ),
                    title: Text(
                      '$title · ${ids.length} moving ${ids.length == 1 ? 'occurrence collides' : 'occurrences collide'}',
                    ),
                    subtitle: Text(
                      '${existing.length} other ${existing.length == 1 ? 'occurrence' : 'occurrences'} already planned · ${dates.first} – ${dates.last}',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => onKeep(ids),
                          child: Text(
                            resolved
                                ? 'Keep all occurrences ✓'
                                : 'Keep all occurrences',
                          ),
                        ),
                        TextButton(
                          onPressed: () => onLeave(ids),
                          child: const Text(
                            'Leave moving occurrences unchanged',
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExpansionTile(
                    expansionAnimationStyle: AppMotion.style(context),
                    key: PageStorageKey('collision-details:${entry.key}'),
                    title: const Text('Collision details and restrictions'),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Keep retains distinct occurrence identities on the proposed dates. Combine is unsupported. To preserve history and undo, skipping or cancelling occurrences is unavailable here; leave them unchanged instead.',
                        ),
                      ),
                      for (final collision in items)
                        ListTile(
                          title: Text(
                            'Occurrence ${byId[collision.movedTaskId]?.nominalDate ?? ''} · Proposed ${collision.plannedDate}',
                          ),
                          subtitle: Text(
                            '${collision.existingTaskIds.length} other occurrences share this proposed day.',
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        if (preview.issues.isNotEmpty)
          ExpansionTile(
            key: const PageStorageKey('schedule-issues'),
            expansionAnimationStyle: AppMotion.style(context),
            initiallyExpanded: preview.issues.any((issue) => issue.isHard),
            title: Text(
              '${preview.issues.where((issue) => issue.isHard).length} blocking issues · ${preview.issues.where((issue) => !issue.isHard).length} warnings',
            ),
            children: [
              for (final issue in preview.issues)
                ListTile(
                  leading: Icon(
                    issue.isHard
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                  ),
                  title: Text(issue.message),
                  subtitle: Text(issue.isHard ? 'Must be resolved' : 'Warning'),
                ),
            ],
          ),
        if (preview.changes.isEmpty)
          const ListTile(title: Text('No eligible scheduling changes.')),
        if (!sessionMode)
          ScheduleTaskList(
            tasks: tasks,
            parents: parents,
            taskIds: preview.changes.map((change) => change.targetId).toSet(),
            selected: const {},
            onChanged: null,
            labels: labels,
          )
        else
          for (final change in preview.changes)
            ListTile(
              title: Text(titles[change.targetId] ?? 'Work session'),
              subtitle: Text(labels[change.targetId]!),
            ),
      ],
    );
  }
}
