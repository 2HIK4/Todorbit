import 'planned_session_delete.dart';
import '../shared/app_motion.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/status_snackbar.dart';
import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/time_tracking.dart';
import 'task_composition_section.dart';
import 'unified_resources_section.dart';
import 'task_editor.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskDetailsView extends ConsumerStatefulWidget {
  const TaskDetailsView({
    super.key,
    required this.task,
    required this.onBack,
    this.onEdit,
    this.onStartFocus,
  });

  final LifeTask task;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onStartFocus;

  @override
  ConsumerState<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends ConsumerState<TaskDetailsView> {
  bool workLogExpanded = false;
  bool busy = false;

  LifeTask get task =>
      ref
          .read(appControllerProvider)
          .tasks
          .where((t) => t.id == widget.task.id)
          .firstOrNull ??
      widget.task;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showTransientStatus(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleComplete(AppController controller) async {
    final done = task.status == TaskStatus.completed;
    await _run(() => controller.setComplete(task, !done));
  }

  Future<void> _addManualTime(AppController controller) async {
    final now = DateTime.now();
    var startsAt = now.subtract(const Duration(minutes: 30));
    var endsAt = now;
    var notes = '';

    final result = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add manual work time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: const Text('Start time'),
                subtitle: Text(
                  '${startsAt.toLocal().hour.toString().padLeft(2, '0')}:${startsAt.toLocal().minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(startsAt),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startsAt = DateTime(
                        startsAt.year,
                        startsAt.month,
                        startsAt.day,
                        picked.hour,
                        picked.minute,
                      );
                      if (endsAt.isBefore(startsAt)) {
                        endsAt = startsAt.add(const Duration(minutes: 30));
                      }
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('End time'),
                subtitle: Text(
                  '${endsAt.toLocal().hour.toString().padLeft(2, '0')}:${endsAt.toLocal().minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(endsAt),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      endsAt = DateTime(
                        endsAt.year,
                        endsAt.month,
                        endsAt.day,
                        picked.hour,
                        picked.minute,
                      );
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => notes = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await _run(
        () => controller.addManualTime(task.id, startsAt, endsAt, notes),
      );
    }
  }

  Future<void> _newSubtask(LifeTask parent, AppController controller) async {
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 520,
          height: 600,
          child: TaskEditor(
            parentTaskId: parent.id,
            protectUnsavedEdits: true,
            onSaved: () => Navigator.pop(dialogContext),
            onCancel: () => Navigator.pop(dialogContext),
          ),
        ),
      ),
    );
    if (mounted) controller.select(parent.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final done = task.status == TaskStatus.completed;
    final category = controller.categories
        .where((c) => c.id == task.categoryId)
        .firstOrNull;
    final project = controller.projects
        .where((p) => p.id == task.projectId)
        .firstOrNull;

    final subtasks = controller.tasks
        .where((t) => controller.taskParents[t.id] == task.id)
        .toList();

    // Time entries for work log (meaningless zero-duration completed entries suppressed for display)
    final allEntries = controller.timeEntries
        .where((e) => e.taskId == task.id)
        .toList();
    final entries = allEntries.where((e) {
      if (e.endsAt != null && e.durationAt(DateTime.now()) <= Duration.zero) {
        return false;
      }
      return true;
    }).toList();
    final run = controller.activeTimer;
    final confirmedNow =
        run?.taskId == task.id &&
            (!run!.canControl || run.needsReview(DateTime.now()))
        ? run.lastSeenAt
        : DateTime.now();
    final totalDuration = TimeEntry.distinctDuration(allEntries, confirmedNow);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to tasks',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Task Details'),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              tooltip: 'Edit task',
              icon: const Icon(Icons.edit_outlined),
              onPressed: widget.onEdit,
            ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (action) {
              if (action == 'complete') _toggleComplete(controller);
              if (action == 'archive') {
                _run(() async {
                  await controller.archiveTask(task);
                  widget.onBack();
                });
              }
              if (action == 'delete') {
                _run(() async {
                  await controller.deleteTask(task.id);
                  widget.onBack();
                });
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'complete',
                child: Text(done ? 'Reopen task' : 'Mark completed'),
              ),
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Move to Trash'),
              ),
            ],
          ),
        ],
      ),
      body: FadingListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Header Row: Completion Checkbox + Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Transform.scale(
                  scale: 1.15,
                  child: Checkbox(
                    value: done,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: busy ? null : (_) => _toggleComplete(controller),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done
                        ? scheme.onSurface.withValues(alpha: 0.5)
                        : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Primary Actions row: Edit + Start Focus Session
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (widget.onStartFocus != null && task.isOpen)
                FilledButton.icon(
                  onPressed: widget.onStartFocus,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    run?.taskId == task.id
                        ? 'Open timer'
                        : 'Start Focus Session',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6), // Purple accent
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Metadata Badges Row: Category, Project, Priority, Schedule, Deadline
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.status.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Priority Badge
              if (task.priority > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: task.priority == 3
                        ? scheme.errorContainer
                        : scheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 14,
                        color: task.priority == 3
                            ? scheme.error
                            : scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Priority ${task.priority}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: task.priority == 3
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),

              // Category Pill
              if (category != null)
                ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 16),
                  label: Text(category.name),
                  onPressed: () {
                    controller.navigate(
                      WorkspaceView.category,
                      id: category.id,
                    );
                    widget.onBack();
                  },
                ),

              // Project Pill
              if (project != null)
                ActionChip(
                  avatar: const Icon(Icons.folder_open_outlined, size: 16),
                  label: Text(project.name),
                  onPressed: () {
                    controller.navigate(WorkspaceView.project, id: project.id);
                    widget.onBack();
                  },
                ),

              // Scheduled Date Badge
              if (task.scheduledDate != null)
                Chip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text('Planned: ${task.scheduledDate}'),
                ),

              // Deadline Badge
              if (task.deadlineDate != null)
                Chip(
                  avatar: Icon(
                    Icons.alarm,
                    size: 15,
                    color:
                        (task.isOpen &&
                            DateTime.tryParse(task.deadlineDate!)
                                    ?.isBefore(DateTime.now()) ==
                                true)
                        ? scheme.error
                        : null,
                  ),
                  label: Text(
                    'Due: ${task.deadlineDate}',
                    style: TextStyle(
                      color:
                          (task.isOpen &&
                              DateTime.tryParse(task.deadlineDate!)
                                      ?.isBefore(DateTime.now()) ==
                                  true)
                          ? scheme.error
                          : null,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Description / Notes Card
          if (task.notes.trim().isNotEmpty) ...[
            Text(
              'Notes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: SelectableText(
                task.notes,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Interactive Checklist and Subtasks
          Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TaskCompositionSection(
                task: task,
                onAddSubtask: controller.taskParents.containsKey(task.id)
                    ? null
                    : () => _newSubtask(task, controller),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Unified Resources Component
          UnifiedResourcesSection.persisted(
            taskId: task.id,
            repository: controller.repository,
            subtasks: subtasks,
            onAddSubtask: controller.taskParents.containsKey(task.id)
                ? null
                : (title) async {
                    LifeTask? created;
                    await controller.addSubtask(
                      task,
                      TaskDraft(title: title),
                      onCommitted: (child) => created = child,
                    );
                    controller.select(task.id);
                    return created;
                  },
          ),

          const SizedBox(height: 20),

          if (controller.sessions.any(
            (session) => session.taskId == task.id,
          )) ...[
            Text('Planned work sessions', style: theme.textTheme.titleSmall),
            for (final session in controller.sessions.where(
              (session) => session.taskId == task.id,
            ))
              ListTile(
                title: Text('${session.startsAt.toLocal()}'),
                subtitle: Text(session.outcome.name),
                trailing:
                    session.outcome == SessionOutcome.upcoming &&
                        session.actualStartedAt == null
                    ? PlannedSessionDelete(session: session)
                    : null,
              ),
            const SizedBox(height: 20),
          ],

          // Collapsible Work History / Log (Collapsed by default per Requirement 16)
          Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              title: Row(
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Work Log',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatWorkClock(totalDuration),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${entries.length} recorded session${entries.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _addManualTime(controller),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add manual time'),
                          ),
                        ],
                      ),
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'No work recorded yet. Start a focus session to track time.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final entry in entries)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              entry.source == TimeEntrySource.timer
                                  ? Icons.timer_outlined
                                  : Icons.edit_note_outlined,
                              size: 18,
                            ),
                            title: Text(
                              entry.endsAt == null
                                  ? 'Running'
                                  : entry
                                            .durationAt(DateTime.now())
                                            .inSeconds ==
                                        0
                                  ? '<1s'
                                  : formatWorkClock(
                                      entry.durationAt(DateTime.now()),
                                    ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.source == TimeEntrySource.timer ? 'Timer' : 'Manual'} · '
                              '${entry.startsAt.toLocal().toString().split('.').first}'
                              '${entry.endsAt != null ? ' – ${entry.endsAt!.toLocal().toString().split('.').first}' : ' (ongoing)'}',
                            ),
                            trailing: entry.source == TimeEntrySource.manual
                                ? IconButton(
                                    tooltip: 'Delete entry',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    onPressed: () => _run(
                                      () => controller.clearManualTime(entry),
                                    ),
                                  )
                                : null,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
