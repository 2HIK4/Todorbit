import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/time_tracking.dart';

String _duration(Duration value) {
  return formatWorkClock(value);
}

String _stamp(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

class TimeTrackingDialog extends ConsumerStatefulWidget {
  const TimeTrackingDialog({super.key, required this.taskId, this.now});
  final String taskId;
  final DateTime Function()? now;

  @override
  ConsumerState<TimeTrackingDialog> createState() => _TimeTrackingDialogState();
}

class _TimeTrackingDialogState extends ConsumerState<TimeTrackingDialog> {
  bool busy = false;
  String? error;
  Timer? clock;

  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit([TimeEntry? entry]) async {
    final changed = await showDialog<_TimeDraft>(
      context: context,
      builder: (_) => _TimeEntryEditor(entry: entry),
    );
    if (changed == null || !mounted) return;
    final controller = ref.read(appControllerProvider);
    await _run(
      () => entry == null
          ? controller.addManualTime(
              widget.taskId,
              changed.start,
              changed.end,
              changed.notes,
            )
          : controller.updateManualTime(
              entry,
              changed.start,
              changed.end,
              changed.notes,
            ),
    );
  }

  Future<void> _clear(TimeEntry entry) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear manual work log?'),
        content: const Text(
          'The change will remain in the correction history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear log'),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await _run(() => ref.read(appControllerProvider).clearManualTime(entry));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final task = controller.tasks
        .where((item) => item.id == widget.taskId)
        .firstOrNull;
    final run = controller.activeTimer;
    final thisRun = run?.taskId == widget.taskId ? run : null;
    final now = widget.now?.call() ?? DateTime.now();
    final recovery = run?.needsReview(now) ?? false;
    final entries = controller.timeEntries
        .where((item) => item.taskId == widget.taskId)
        .toList();
    final confirmedEnd = recovery ? run!.lastSeenAt : now;
    final total = TimeEntry.distinctDuration(entries, confirmedEnd);
    final session = thisRun == null
        ? Duration.zero
        : TimeEntry.distinctDuration(
            entries.where((item) => item.timerRunId == thisRun.id),
            confirmedEnd,
          );
    return Dialog(
      child: SizedBox(
        width: 550,
        height: 630,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Focus: ${task?.title ?? 'Deleted task'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close actual work',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Stopwatch time is recorded separately from planned sessions and task completion.',
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        thisRun == null
                            ? 'Stopped'
                            : recovery
                            ? 'Needs review'
                            : thisRun.state == TimerState.running
                            ? 'Running'
                            : 'Paused',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _duration(session),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      const Text('Current focus session'),
                      const SizedBox(height: 6),
                      Text(
                        'Total recorded: ${_duration(total)} (overlaps counted once)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.timerError != null)
                Text(
                  controller.timerError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (recovery && thisRun != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Timer needs review. Last confirmed running at ${_stamp(thisRun.lastSeenAt)}.',
                ),
                const Text(
                  'Choose whether work continued while the app was away.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _run(controller.keepRecoveredTimer),
                      child: const Text('Keep elapsed time'),
                    ),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () =>
                                _run(controller.stopRecoveredTimerAtCheckpoint),
                      child: const Text('Stop at last checkpoint'),
                    ),
                  ],
                ),
              ] else if (thisRun != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _run(
                              thisRun.state == TimerState.running
                                  ? controller.pauseTimer
                                  : controller.resumeTimer,
                            ),
                      icon: Icon(
                        thisRun.state == TimerState.running
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        thisRun.state == TimerState.running
                            ? 'Pause'
                            : 'Resume',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _run(controller.stopTimer),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
              ] else if (run == null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: busy || task == null
                        ? null
                        : () =>
                              _run(() => controller.startTimer(widget.taskId)),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start focus stopwatch'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'A timer is active for another task. Pause or stop it there first.',
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Work log',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy || task == null ? null : () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add manual time'),
                  ),
                ],
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('No actual work recorded yet.'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${_duration(entry.durationAt(confirmedEnd))} · ${entry.source == TimeEntrySource.manual ? 'Manual' : 'Timer'}${entry.endsAt == null ? ' · Running' : ''}',
                            ),
                            subtitle: Text(
                              '${_stamp(entry.startsAt)} – ${entry.endsAt == null ? 'running' : _stamp(entry.endsAt!)}${entry.notes.isEmpty ? '' : '\n${entry.notes}'}',
                            ),
                            isThreeLine: entry.notes.isNotEmpty,
                            trailing: entry.source == TimeEntrySource.manual
                                ? PopupMenuButton<String>(
                                    tooltip: 'Manual log actions',
                                    onSelected: (value) => value == 'edit'
                                        ? _edit(entry)
                                        : _clear(entry),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'clear',
                                        child: Text('Clear'),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeDraft {
  const _TimeDraft(this.start, this.end, this.notes);
  final DateTime start;
  final DateTime end;
  final String notes;
}

class _TimeEntryEditor extends StatefulWidget {
  const _TimeEntryEditor({this.entry});
  final TimeEntry? entry;

  @override
  State<_TimeEntryEditor> createState() => _TimeEntryEditorState();
}

class _TimeEntryEditorState extends State<_TimeEntryEditor> {
  late DateTime start =
      widget.entry?.startsAt.toLocal() ??
      DateTime.now().subtract(const Duration(hours: 1));
  late DateTime end = widget.entry?.endsAt?.toLocal() ?? DateTime.now();
  late String notes = widget.entry?.notes ?? '';
  String? error;

  Future<void> _pick(bool forStart) async {
    final current = forStart ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (forStart) {
        start = value;
      } else {
        end = value;
      }
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.entry == null ? 'Add actual work' : 'Correct actual work',
    ),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () => _pick(true),
            child: Text('Start: ${_stamp(start)}'),
          ),
          OutlinedButton(
            onPressed: () => _pick(false),
            child: Text('End: ${_stamp(end)}'),
          ),
          TextFormField(
            initialValue: notes,
            onChanged: (value) => notes = value,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!end.isAfter(start) ||
              end.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
            setState(
              () =>
                  error = 'End must follow start and cannot be in the future.',
            );
            return;
          }
          Navigator.pop(context, _TimeDraft(start, end, notes.trim()));
        },
        child: const Text('Save work log'),
      ),
    ],
  );
}
