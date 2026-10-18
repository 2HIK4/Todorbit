import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/task_composition.dart';

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
    final field = TextEditingController(text: item.title);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit checklist item'),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Activity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null && mounted) {
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
          Row(
            children: [
              Checkbox(
                value: items[index].done,
                onChanged: (value) => _run(
                  () => controller.updateChecklistItem(
                    items[index],
                    done: value ?? false,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  items[index].title,
                  style: TextStyle(
                    decoration: items[index].done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit checklist item',
                icon: const Icon(Icons.edit_outlined, size: 17),
                onPressed: () => _rename(items[index]),
              ),
              IconButton(
                tooltip: 'Move checklist item up',
                icon: const Icon(Icons.arrow_upward, size: 17),
                onPressed: index == 0
                    ? null
                    : () => _run(
                        () => controller.moveChecklistItem(items[index], -1),
                      ),
              ),
              IconButton(
                tooltip: 'Move checklist item down',
                icon: const Icon(Icons.arrow_downward, size: 17),
                onPressed: index == items.length - 1
                    ? null
                    : () => _run(
                        () => controller.moveChecklistItem(items[index], 1),
                      ),
              ),
              IconButton(
                tooltip: 'Remove checklist item',
                icon: const Icon(Icons.close, size: 17),
                onPressed: () =>
                    _run(() => controller.removeChecklistItem(items[index])),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: entry,
                decoration: const InputDecoration(
                  labelText: 'New checklist item',
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
        for (final child in children)
          ListTile(
            dense: true,
            leading: Icon(
              child.status == TaskStatus.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
            title: Text(child.title),
            subtitle: Text(child.status.name),
            onTap: () => controller.select(child.id),
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
