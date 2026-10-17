import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../scheduling/smart_reschedule.dart';

class SequenceDialog extends ConsumerStatefulWidget {
  const SequenceDialog({super.key});

  @override
  ConsumerState<SequenceDialog> createState() => _SequenceDialogState();
}

class _SequenceDialogState extends ConsumerState<SequenceDialog> {
  String? selectedId;
  bool busy = false;

  Future<String?> _askName(String title, [String initial = '']) async {
    final field = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Sequence name'),
            onSubmitted: (_) => Navigator.pop(context, field.text),
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
    } finally {
      field.dispose();
    }
  }

  Future<void> _run(Future<void> Function(AppController) action) async {
    setState(() => busy = true);
    try {
      await action(ref.read(appControllerProvider));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sequence change failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _create() async {
    final name = await _askName('New sequence');
    if (name == null) return;
    await _run((controller) async {
      final before = controller.sequences.map((item) => item.id).toSet();
      await controller.addSequence(name);
      selectedId = controller.sequences
          .firstWhere((item) => !before.contains(item.id))
          .id;
    });
  }

  Future<void> _addTask(TaskSequence sequence, AppController controller) async {
    final available = controller.tasks
        .where(
          (task) => !controller.sequences.any(
            (item) => item.taskIds.contains(task.id),
          ),
        )
        .toList();
    final taskId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add task to sequence'),
        children: available.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No unassigned tasks available.'),
                ),
              ]
            : available
                  .map(
                    (task) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, task.id),
                      child: Text(task.title),
                    ),
                  )
                  .toList(),
      ),
    );
    if (taskId == null) return;
    await _run(
      (value) =>
          value.setSequenceTasks(sequence, [...sequence.taskIds, taskId]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final selected = controller.sequences
        .where((item) => item.id == selectedId)
        .firstOrNull;
    final byId = {for (final task in controller.tasks) task.id: task};
    return Dialog(
      child: SizedBox(
        width: 650,
        height: 560,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Task sequences',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Sequences keep an explicit order. They do not make tasks prerequisites.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(selectedId),
                      initialValue: selectedId,
                      decoration: const InputDecoration(labelText: 'Sequence'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Choose a sequence'),
                        ),
                        ...controller.sequences.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => selectedId = value),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New sequence',
                    onPressed: busy ? null : _create,
                    icon: const Icon(Icons.add),
                  ),
                  if (selected != null) ...[
                    IconButton(
                      tooltip: 'Rename sequence',
                      onPressed: busy
                          ? null
                          : () async {
                              final name = await _askName(
                                'Rename sequence',
                                selected.name,
                              );
                              if (name != null) {
                                await _run(
                                  (value) =>
                                      value.renameSequence(selected, name),
                                );
                              }
                            },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete sequence',
                      onPressed: busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete sequence?'),
                                  content: const Text(
                                    'The tasks themselves will be kept.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await _run(
                                  (value) => value.deleteSequence(selected),
                                );
                                if (mounted) setState(() => selectedId = null);
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (selected != null) ...[
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _addTask(selected, controller),
                      icon: const Icon(Icons.add),
                      label: const Text('Add task'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: busy || selected.taskIds.isEmpty
                          ? null
                          : () => showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => SmartRescheduleDialog(
                                scope: 'sequence:${selected.id}',
                                taskIds: selected.taskIds,
                              ),
                            ),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Reschedule sequence'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: selected.taskIds.isEmpty
                      ? const Center(child: Text('No tasks in this sequence.'))
                      : ListView.builder(
                          itemCount: selected.taskIds.length,
                          itemBuilder: (context, index) {
                            final taskId = selected.taskIds[index];
                            final task = byId[taskId];
                            return ListTile(
                              leading: Text('${index + 1}'),
                              title: Text(task?.title ?? 'Task removed'),
                              subtitle: task?.status == TaskStatus.completed
                                  ? const Text('Completed')
                                  : null,
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Move up',
                                    onPressed: busy || index == 0
                                        ? null
                                        : () => _move(selected, index, -1),
                                    icon: const Icon(Icons.arrow_upward),
                                  ),
                                  IconButton(
                                    tooltip: 'Move down',
                                    onPressed:
                                        busy ||
                                            index == selected.taskIds.length - 1
                                        ? null
                                        : () => _move(selected, index, 1),
                                    icon: const Icon(Icons.arrow_downward),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove from sequence',
                                    onPressed: busy
                                        ? null
                                        : () => _run(
                                            (value) => value.setSequenceTasks(
                                              selected,
                                              [...selected.taskIds]
                                                ..removeAt(index),
                                            ),
                                          ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ] else
                const Expanded(
                  child: Center(child: Text('Create or choose a sequence.')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _move(TaskSequence sequence, int index, int offset) async {
    final ids = [...sequence.taskIds];
    final id = ids.removeAt(index);
    ids.insert(index + offset, id);
    await _run((controller) => controller.setSequenceTasks(sequence, ids));
  }
}
