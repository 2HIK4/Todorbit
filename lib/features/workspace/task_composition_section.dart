import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/task_composition.dart';
import '../shared/spelling_review_button.dart';
import 'checklist_item_dialog.dart';

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
  final entry = TextEditingController();
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
        const Divider(),
        Text(
          'Checklist${items.isEmpty ? '' : ' · $done/${items.length}'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < items.length; index++)
          ChecklistItemRow(
            key: ValueKey(items[index].id),
            title: items[index].title,
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
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: entry,
                decoration: InputDecoration(
                  labelText: 'New checklist item',
                  suffixIcon: SpellingReviewButton(
                    controller: entry,
                    enabled: controller.taskViewPreferences.spellCheckEnabled,
                  ),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              tooltip: 'Add checklist item',
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        for (var index = 0; index < children.length; index++) ...[
          ListTile(
            dense: true,
            leading: Icon(
              children[index].status == TaskStatus.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
            title: Text(children[index].title),
            subtitle: Text(children[index].status.name),
            onTap: () => controller.select(children[index].id),
          ),
          if (index < children.length - 1)
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
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

class ChecklistItemRow extends StatefulWidget {
  const ChecklistItemRow({
    super.key,
    required this.title,
    required this.done,
    required this.onChanged,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final String title;
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
  bool expanded = false;

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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final painter = TextPainter(
                        text: TextSpan(text: widget.title, style: style),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                        maxLines: 2,
                      )..layout(maxWidth: constraints.maxWidth);
                      final hasMore = painter.didExceedMaxLines;
                      painter.dispose();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            widget.title,
                            maxLines: expanded ? null : 2,
                            style: style,
                          ),
                          if (hasMore || expanded)
                            TextButton(
                              onPressed: () =>
                                  setState(() => expanded = !expanded),
                              child: Text(expanded ? 'Show less' : 'Show more'),
                            ),
                        ],
                      );
                    },
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
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}
