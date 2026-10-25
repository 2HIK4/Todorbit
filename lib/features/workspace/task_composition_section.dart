import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/task_composition.dart';
import '../../domain/task_view_preferences.dart';
import '../shared/inline_spelling_controller.dart';
import '../shared/checklist_entry.dart';
import 'checklist_item_dialog.dart';
import 'composition_text.dart';

class TaskCompositionSection extends ConsumerStatefulWidget {
  const TaskCompositionSection({
    super.key,
    required this.task,
    required this.onAddSubtask,
  });
  final LifeTask task;
  final VoidCallback? onAddSubtask;

  @override
  ConsumerState<TaskCompositionSection> createState() =>
      _TaskCompositionSectionState();
}

class _TaskCompositionSectionState
    extends ConsumerState<TaskCompositionSection> {
  late final entry = InlineSpellingController(
    enabled: ref
        .read(appControllerProvider)
        .taskViewPreferences
        .spellCheckEnabled,
  );
  String? error;

  @override
  void dispose() {
    entry.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => error = null);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    }
  }

  Future<void> _rename(TaskChecklistItem item) async {
    final value = await editChecklistItem(
      context,
      title: 'Edit checklist item',
      initialValue: item.title,
      spellCheckEnabled: ref
          .read(appControllerProvider)
          .taskViewPreferences
          .spellCheckEnabled,
    );
    if (value != null && value.isNotEmpty && mounted) {
      await _run(
        () => ref
            .read(appControllerProvider)
            .updateChecklistItem(item, title: value),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        entry.enabled = controller.taskViewPreferences.spellCheckEnabled;
      }
    });
    final items = controller.checklistItems
        .where((item) => item.taskId == widget.task.id)
        .toList();
    final children = controller.tasks
        .where((task) => controller.taskParents[task.id] == widget.task.id)
        .toList();
    final done = items.where((item) => item.done).length;
    final childDone = children
        .where((task) => task.status == TaskStatus.completed)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Checklist${items.isEmpty ? '' : ' · $done/${items.length}'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (var index = 0; index < items.length; index++)
          ChecklistItemRow(
            key: ValueKey(items[index].id),
            title: items[index].title,
            display: controller.taskViewPreferences.compositionTextDisplay,
            done: items[index].done,
            onChanged: (value) => _run(
              () => controller.updateChecklistItem(items[index], done: value),
            ),
            onEdit: () => _rename(items[index]),
            onMoveUp: index == 0
                ? null
                : () => _run(
                    () => controller.moveChecklistItem(items[index], -1),
                  ),
            onMoveDown: index == items.length - 1
                ? null
                : () =>
                      _run(() => controller.moveChecklistItem(items[index], 1)),
            onRemove: () =>
                _run(() => controller.removeChecklistItem(items[index])),
          ),
        ChecklistEntry(
          fieldKey: const ValueKey('saved-checklist-entry'),
          controller: entry,
          onAdd: _add,
          tooltip: 'Add checklist item',
        ),
        const SizedBox(height: 12),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                'Subtasks${children.isEmpty ? '' : ' · $childDone/${children.length}'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (widget.onAddSubtask != null)
              TextButton.icon(
                onPressed: widget.onAddSubtask,
                icon: const Icon(Icons.add),
                label: const Text('Add subtask'),
              ),
          ],
        ),
        for (var index = 0; index < children.length; index++)
          ListTile(
            dense: true,
            leading: Icon(
              children[index].status == TaskStatus.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
            title: CompositionText(
              text: children[index].title,
              display: controller.taskViewPreferences.compositionTextDisplay,
            ),
            subtitle: Text(_statusLabel(children[index].status)),
            onTap: () => controller.select(children[index].id),
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Future<void> _add() async {
    final title = entry.text.trim();
    if (title.isEmpty) return;
    await _run(
      () => ref
          .read(appControllerProvider)
          .addChecklistItem(widget.task.id, title),
    );
    if (error == null) entry.clear();
  }
}

String _statusLabel(TaskStatus status) => switch (status) {
  TaskStatus.notStarted => 'Not started',
  TaskStatus.inProgress => 'In progress',
  TaskStatus.waiting => 'Waiting',
  TaskStatus.onHold => 'On hold',
  TaskStatus.completed => 'Completed',
  TaskStatus.cancelled => 'Cancelled',
};

class ChecklistItemRow extends StatefulWidget {
  const ChecklistItemRow({
    super.key,
    required this.title,
    this.display = CompositionTextDisplay.compact,
    required this.done,
    required this.onChanged,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final String title;
  final CompositionTextDisplay display;
  final bool done;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onRemove;

  @override
  State<ChecklistItemRow> createState() => _ChecklistItemRowState();
}

class _ChecklistItemRowState extends State<ChecklistItemRow> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      decoration: widget.done ? TextDecoration.lineThrough : null,
      color: widget.done ? theme.colorScheme.onSurfaceVariant : null,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: widget.done,
                semanticLabel: 'Complete ${widget.title}',
                onChanged: (value) => widget.onChanged(value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: CompositionText(
                    text: widget.title,
                    display: widget.display,
                    style: style,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Checklist actions for ${widget.title}',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      widget.onEdit();
                    case 'up':
                      widget.onMoveUp?.call();
                    case 'down':
                      widget.onMoveDown?.call();
                    case 'remove':
                      widget.onRemove();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (widget.onMoveUp != null)
                    const PopupMenuItem(value: 'up', child: Text('Move up')),
                  if (widget.onMoveDown != null)
                    const PopupMenuItem(
                      value: 'down',
                      child: Text('Move down'),
                    ),
                  const PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
