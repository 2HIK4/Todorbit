import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
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
  late final TextEditingController recurrenceInterval;
  late final TextEditingController recurrenceCount;
  late TaskStatus status;
  late int priority;
  String? categoryId;
  String? projectId;
  DateTime? scheduled;
  DateTime? deadline;
  DateTime? recurrenceEnd;
  RecurrenceKind? recurrenceKind;
  Set<int> recurrenceWeekdays = {};
  bool saving = false;
  bool schedulingLocked = false;
  LifeTask? currentTask;
  late Set<String> prerequisiteIds;
  bool savingPrerequisites = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    currentTask = task;
    final workspace = ref.read(appControllerProvider);
    prerequisiteIds = workspace.dependencies
        .where((link) => link.taskId == task?.id)
        .map((link) => link.prerequisiteId)
        .toSet();
    title = TextEditingController(text: task?.title ?? '');
    notes = TextEditingController(text: task?.notes ?? '');
    plannedDuration = TextEditingController(
      text: task?.plannedDurationMinutes?.toString() ?? '',
    );
    remainingWork = TextEditingController(
      text: task?.remainingWorkMinutes?.toString() ?? '',
    );
    recurrenceInterval = TextEditingController(text: '1');
    recurrenceCount = TextEditingController();
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
    recurrenceInterval.dispose();
    recurrenceCount.dispose();
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
      final plannedMinutes = _parseMinutes(
        plannedDuration.text,
        'Planned minutes',
      );
      final remainingMinutes = _parseMinutes(
        remainingWork.text,
        'Remaining minutes',
        allowZero: true,
      );
      final draft = TaskDraft(
        title: title.text,
        notes: notes.text,
        status: status,
        priority: priority,
        categoryId: categoryId,
        projectId: projectId,
        scheduledDate: scheduled == null ? null : localDate(scheduled!),
        deadlineDate: deadline == null ? null : localDate(deadline!),
        plannedDurationMinutes: plannedMinutes,
        remainingWorkMinutes: remainingMinutes,
        schedulingLocked: schedulingLocked,
      );
      final reviewedPrerequisiteIds = <String>{};
      if (currentTask != null &&
          draft.scheduledDate != currentTask!.scheduledDate &&
          draft.scheduledDate != null) {
        final byId = {for (final task in controller.tasks) task.id: task};
        final conflicts = controller.dependencies
            .where((link) => link.taskId == currentTask!.id)
            .map((link) => byId[link.prerequisiteId])
            .whereType<LifeTask>()
            .where(
              (task) =>
                  task.status != TaskStatus.completed &&
                  (task.scheduledDate == null ||
                      draft.scheduledDate!.compareTo(task.scheduledDate!) <= 0),
            )
            .toList();
        if (conflicts.isNotEmpty) {
          if (!mounted) return;
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Plan before prerequisites?'),
              content: Text(
                'This day is before unfinished prerequisite work: '
                '${conflicts.map((task) => task.title).join(', ')}.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
          reviewedPrerequisiteIds.addAll(conflicts.map((task) => task.id));
        }
      }
      if (currentTask == null) {
        if (recurrenceKind == null) {
          await controller.addTask(draft);
        } else {
          if (draft.scheduledDate == null) {
            throw const FormatException(
              'Select a scheduled day for recurrence',
            );
          }
          final interval = int.tryParse(recurrenceInterval.text.trim());
          final countText = recurrenceCount.text.trim();
          final count = countText.isEmpty ? null : int.tryParse(countText);
          if (interval == null ||
              interval < 1 ||
              (countText.isNotEmpty && (count == null || count < 1))) {
            throw const FormatException('Enter positive recurrence numbers');
          }
          await controller.addRecurringTask(
            draft,
            RecurrenceRule(
              kind: recurrenceKind!,
              startDate: draft.scheduledDate!,
              interval: interval,
              weekdays: recurrenceKind == RecurrenceKind.weekdays
                  ? recurrenceWeekdays
                  : const {},
              endDate: recurrenceEnd == null ? null : localDate(recurrenceEnd!),
              maxOccurrences: count,
            ),
          );
        }
      } else {
        await controller.updateTask(
          currentTask!,
          draft,
          reviewedPrerequisiteIds: reviewedPrerequisiteIds,
        );
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

  int? _parseMinutes(String input, String label, {bool allowZero = false}) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    if (value == null || value < (allowZero ? 0 : 1)) {
      throw FormatException(
        '$label must be ${allowZero ? 'zero or a positive' : 'a positive'} whole number',
      );
    }
    return value;
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

  Future<void> _pickRecurrenceEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: recurrenceEnd ?? scheduled ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => recurrenceEnd = picked);
  }

  Future<void> _skipOccurrence() async {
    final task = currentTask;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip this occurrence?'),
        content: const Text(
          'This occurrence will be kept in history as skipped. '
          'For after-completion recurrence, no next day is calculated '
          'without an actual completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep task'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip occurrence'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(appControllerProvider).skipRecurringOccurrence(task);
      if (mounted) widget.onSaved?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not skip occurrence: $error')),
        );
      }
    }
  }

  Future<void> _resumeCompletionSeries() async {
    final skipped = currentTask;
    if (skipped == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Planned day for the next occurrence',
    );
    if (picked == null) return;
    try {
      await ref
          .read(appControllerProvider)
          .resumeCompletionSeries(skipped, localDate(picked));
      if (mounted) widget.onSaved?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resume series: $error')),
        );
      }
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

  Future<void> _savePrerequisites() async {
    final task = currentTask;
    if (task == null) return;
    setState(() => savingPrerequisites = true);
    try {
      final controller = ref.read(appControllerProvider);
      await controller.setPrerequisites(task, prerequisiteIds);
      currentTask = controller.tasks.firstWhere((item) => item.id == task.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prerequisites saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save prerequisites: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => savingPrerequisites = false);
    }
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
                  key: ValueKey('status:$status:$recurrenceKind'),
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
                  onChanged: widget.task == null && recurrenceKind != null
                      ? null
                      : (value) => setState(() => status = value!),
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
                if (widget.task == null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RecurrenceKind?>(
                    initialValue: recurrenceKind,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: const [
                      DropdownMenuItem<RecurrenceKind?>(
                        value: null,
                        child: Text('Does not repeat'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.weekly,
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.weekdays,
                        child: Text('Selected weekdays'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.monthly,
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.yearly,
                        child: Text('Yearly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.afterCompletion,
                        child: Text('After completion'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      recurrenceKind = value;
                      if (value != null) status = TaskStatus.notStarted;
                      if (value == RecurrenceKind.weekdays &&
                          recurrenceWeekdays.isEmpty) {
                        recurrenceWeekdays = {
                          scheduled?.weekday ?? DateTime.now().weekday,
                        };
                      }
                    }),
                  ),
                  if (recurrenceKind != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: recurrenceInterval,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            recurrenceKind == RecurrenceKind.afterCompletion
                            ? 'Days after completion'
                            : 'Repeat every (days, weeks, months, or years)',
                      ),
                    ),
                    if (recurrenceKind == RecurrenceKind.weekdays)
                      Wrap(
                        spacing: 4,
                        children: [
                          for (var weekday = 1; weekday <= 7; weekday++)
                            FilterChip(
                              label: Text(
                                const [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ][weekday - 1],
                              ),
                              selected: recurrenceWeekdays.contains(weekday),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  recurrenceWeekdays.add(weekday);
                                } else {
                                  recurrenceWeekdays.remove(weekday);
                                }
                              }),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    _dateRow(
                      'Repeat until',
                      recurrenceEnd,
                      _pickRecurrenceEnd,
                      () => setState(() => recurrenceEnd = null),
                    ),
                    TextField(
                      controller: recurrenceCount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                            'Stop after this many occurrences (optional)',
                      ),
                    ),
                  ],
                ] else if (widget.task!.recurrenceSeriesId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recurring occurrence • ${widget.task!.nominalDate}. Edits here affect this occurrence.',
                  ),
                  if (widget.task!.recurrenceDisposition == 'skipped')
                    const Text('Skipped'),
                  if (widget.task!.recurrenceDisposition == 'skipped' &&
                      widget.task!.recurrenceKindName == 'afterCompletion')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _resumeCompletionSeries,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Resume series on a chosen day'),
                      ),
                    ),
                  if (widget.task!.recurrenceRescheduled)
                    const Text('Rescheduled from the nominal day'),
                  if (widget.task!.isOpen)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _skipOccurrence,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip this occurrence'),
                      ),
                    ),
                ],
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
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Prerequisites'),
                    subtitle: Text(
                      controller.unmetPrerequisites(widget.task!.id).isEmpty
                          ? 'No unmet prerequisites'
                          : 'Blocked by ${controller.unmetPrerequisites(widget.task!.id).length} task(s)',
                    ),
                    children: [
                      const Text(
                        'A task can appear in any project. Sequence order is separate.',
                      ),
                      for (final candidate in controller.tasks.where(
                        (item) => item.id != widget.task!.id,
                      ))
                        CheckboxListTile(
                          dense: true,
                          title: Text(candidate.title),
                          subtitle: Text(
                            candidate.status == TaskStatus.completed
                                ? 'Completed'
                                : 'Incomplete',
                          ),
                          value: prerequisiteIds.contains(candidate.id),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              prerequisiteIds.add(candidate.id);
                            } else {
                              prerequisiteIds.remove(candidate.id);
                            }
                          }),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: savingPrerequisites
                              ? null
                              : _savePrerequisites,
                          child: const Text('Save prerequisites'),
                        ),
                      ),
                    ],
                  ),
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
