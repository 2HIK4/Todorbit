import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';

class SessionEditor extends ConsumerStatefulWidget {
  const SessionEditor({
    super.key,
    this.session,
    this.initialTaskId,
    required this.initialDay,
    required this.onClose,
  });
  final WorkSession? session;
  final String? initialTaskId;
  final DateTime initialDay;
  final VoidCallback onClose;

  @override
  ConsumerState<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends ConsumerState<SessionEditor> {
  String? taskId;
  late DateTime start;
  late DateTime end;
  late SessionOutcome outcome;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    taskId = widget.session?.taskId ?? widget.initialTaskId;
    start =
        widget.session?.startsAt.toLocal() ??
        DateTime(
          widget.initialDay.year,
          widget.initialDay.month,
          widget.initialDay.day,
          9,
        );
    end =
        widget.session?.endsAt.toLocal() ?? start.add(const Duration(hours: 1));
    outcome = widget.session?.outcome ?? SessionOutcome.upcoming;
  }

  Future<void> _pick(bool isStart, bool dateOnly) async {
    final current = isStart ? start : end;
    DateTime? next;
    if (dateOnly) {
      final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date != null) {
        next = DateTime(
          date.year,
          date.month,
          date.day,
          current.hour,
          current.minute,
        );
      }
    } else {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time != null) {
        next = DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
        );
      }
    }
    if (next != null) {
      setState(() {
        if (isStart) {
          start = next!;
        } else {
          end = next!;
        }
      });
    }
  }

  Future<void> _save() async {
    if (taskId == null || !end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a task and an end after the start.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final draft = SessionDraft(
        taskId: taskId!,
        startsAt: start,
        endsAt: end,
        outcome: outcome,
      );
      final controller = ref.read(appControllerProvider);
      if (widget.session == null) {
        await controller.addSession(draft);
      } else {
        await controller.updateSession(widget.session!, draft);
      }
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save session: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final session = widget.session;
    if (session == null) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete planned session?'),
            content: const Text(
              'Move this planned session to Trash? The task remains and the session can be restored.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => busy = true);
    try {
      await ref.read(appControllerProvider).deleteSession(session.id);
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete session: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final candidates = controller.tasks
        .where((task) => task.isOpen || task.id == taskId)
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
                  widget.session == null ? 'Plan work session' : 'Work session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: taskId,
                  decoration: const InputDecoration(labelText: 'Task'),
                  items: candidates
                      .map(
                        (task) => DropdownMenuItem(
                          value: task.id,
                          child: Text(
                            task.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => taskId = value),
                ),
                const SizedBox(height: 15),
                Text('Start', style: Theme.of(context).textTheme.titleSmall),
                _dateTimeRow(start, true),
                const SizedBox(height: 12),
                Text('End', style: Theme.of(context).textTheme.titleSmall),
                _dateTimeRow(end, false),
                const SizedBox(height: 16),
                DropdownButtonFormField<SessionOutcome>(
                  initialValue: outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: SessionOutcome.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_outcomeName(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => outcome = value!),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Session outcome is manual and does not complete the task.',
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (widget.session != null)
                TextButton.icon(
                  onPressed: busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(busy ? 'Saving…' : 'Save session'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTimeRow(DateTime value, bool isStart) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(isStart, true),
            child: Text(localDate(value)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(isStart, false),
            child: Text(
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      ],
    ),
  );
}

String _outcomeName(SessionOutcome outcome) => switch (outcome) {
  SessionOutcome.upcoming => 'Upcoming',
  SessionOutcome.inProgress => 'In progress',
  SessionOutcome.completed => 'Completed',
  SessionOutcome.partial => 'Partial',
  SessionOutcome.missed => 'Missed',
  SessionOutcome.skipped => 'Skipped',
};
