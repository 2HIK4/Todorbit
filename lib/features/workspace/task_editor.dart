import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../calendar/session_editor.dart';

class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({super.key, this.task, this.onSaved, this.onCancel});
  final LifeTask? task;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  late final TextEditingController title;
  late final TextEditingController notes;
  late final TextEditingController plannedDuration;
  late final TextEditingController remainingWork;
  late TaskStatus status;
  late int priority;
  String? categoryId;
  String? projectId;
  DateTime? scheduled;
  DateTime? deadline;
  bool saving = false;
  bool schedulingLocked = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final workspace = ref.read(appControllerProvider);
    title = TextEditingController(text: task?.title ?? '');
    notes = TextEditingController(text: task?.notes ?? '');
    plannedDuration = TextEditingController(
      text: task?.plannedDurationMinutes?.toString() ?? '',
    );
    remainingWork = TextEditingController(
      text: task?.remainingWorkMinutes?.toString() ?? '',
    );
    schedulingLocked = task?.schedulingLocked ?? false;
    status = task?.status ?? TaskStatus.notStarted;
    priority = task?.priority ?? 0;
    categoryId = task?.categoryId;
    projectId = task?.projectId;
    if (task == null && workspace.view == WorkspaceView.category) {
      categoryId = workspace.scopeId;
    } else if (task == null && workspace.view == WorkspaceView.project) {
      projectId = workspace.scopeId;
      for (final project in workspace.projects) {
        if (project.id == projectId) categoryId = project.categoryId;
      }
    }
    scheduled = task?.scheduledDate == null
        ? (task == null && workspace.view == WorkspaceView.today
              ? DateTime.now()
              : null)
        : DateTime.parse(task!.scheduledDate!);
    deadline = task?.deadlineDate == null
        ? null
        : DateTime.parse(task!.deadlineDate!);
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    plannedDuration.dispose();
    remainingWork.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a task title.')));
      return;
    }
    setState(() => saving = true);
    try {
      final controller = ref.read(appControllerProvider);
      final draft = TaskDraft(
        title: title.text,
        notes: notes.text,
        status: status,
        priority: priority,
        categoryId: categoryId,
        projectId: projectId,
        scheduledDate: scheduled == null ? null : localDate(scheduled!),
        deadlineDate: deadline == null ? null : localDate(deadline!),
        plannedDurationMinutes: int.tryParse(plannedDuration.text),
        remainingWorkMinutes: int.tryParse(remainingWork.text),
        schedulingLocked: schedulingLocked,
      );
      if (widget.task == null) {
        await controller.addTask(draft);
      } else {
        await controller.updateTask(widget.task!, draft);
      }
      if (mounted) widget.onSaved?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save task: $error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickDate(bool isDeadline) async {
    final current = isDeadline ? deadline : scheduled;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isDeadline) {
          deadline = picked;
        } else {
          scheduled = picked;
        }
      });
    }
  }

  Future<void> _editSession([WorkSession? session]) async {
    final task = widget.task;
    if (task == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 460,
          height: 550,
          child: SessionEditor(
            session: session,
            initialTaskId: task.id,
            initialDay: scheduled ?? DateTime.now(),
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final projectChoices = controller.projects
        .where((project) => project.categoryId == categoryId)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.task == null ? 'New task' : 'Task details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close details',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: title,
                  autofocus: widget.task == null,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaskStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: TaskStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusName(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => status = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('None')),
                    DropdownMenuItem(value: 1, child: Text('Low')),
                    DropdownMenuItem(value: 2, child: Text('Medium')),
                    DropdownMenuItem(value: 3, child: Text('High')),
                  ],
                  onChanged: (value) => setState(() => priority = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('category:$categoryId'),
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None / Inbox'),
                    ),
                    ...controller.categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    categoryId = value;
                    projectId = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('project:$projectId:$categoryId'),
                  initialValue: projectId,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...projectChoices.map(
                      (project) => DropdownMenuItem<String?>(
                        value: project.id,
                        child: Text(project.name),
                      ),
                    ),
                  ],
                  onChanged: categoryId == null
                      ? null
                      : (value) => setState(() => projectId = value),
                ),
                const SizedBox(height: 16),
                _dateRow(
                  'Scheduled day',
                  scheduled,
                  () => _pickDate(false),
                  () => setState(() => scheduled = null),
                ),
                _dateRow(
                  'Deadline',
                  deadline,
                  () => _pickDate(true),
                  () => setState(() => deadline = null),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: plannedDuration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Planned minutes',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: remainingWork,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Remaining minutes',
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Protect schedule'),
                  subtitle: const Text(
                    'Smart Reschedule will not move this task or its sessions.',
                  ),
                  value: schedulingLocked,
                  onChanged: (value) =>
                      setState(() => schedulingLocked = value),
                ),
                if (widget.task != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Planned work sessions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add work session',
                        onPressed: () => _editSession(),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  for (final session in controller.sessions.where(
                    (item) => item.taskId == widget.task!.id,
                  ))
                    ListTile(
                      dense: true,
                      title: Text(
                        '${localDate(session.startsAt.toLocal())} · ${session.outcome.name}',
                      ),
                      subtitle: Text(
                        session.needsConfirmation
                            ? 'Needs confirmation'
                            : session.lateStart
                            ? 'Late start'
                            : 'Tap to edit',
                      ),
                      onTap: () => _editSession(session),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              saving
                  ? 'Saving…'
                  : widget.task == null
                  ? 'Create task'
                  : 'Save changes',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(
    String label,
    DateTime? date,
    VoidCallback pick,
    VoidCallback clear,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text('$label: ${date == null ? 'None' : localDate(date)}'),
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: 'Clear $label',
            onPressed: clear,
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    ),
  );
}

String _statusName(TaskStatus status) => switch (status) {
  TaskStatus.notStarted => 'Not started',
  TaskStatus.inProgress => 'In progress',
  TaskStatus.waiting => 'Waiting',
  TaskStatus.onHold => 'On hold',
  TaskStatus.completed => 'Completed',
  TaskStatus.cancelled => 'Cancelled',
};
