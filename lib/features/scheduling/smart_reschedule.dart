import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/scheduling_engine.dart';
import '../../domain/series_edit.dart';

class SmartRescheduleDialog extends ConsumerStatefulWidget {
  const SmartRescheduleDialog({
    super.key,
    required this.scope,
    this.taskIds = const [],
    this.sessionIds = const [],
  });

  final String scope;
  final List<String> taskIds;
  final List<String> sessionIds;

  @override
  ConsumerState<SmartRescheduleDialog> createState() =>
      _SmartRescheduleDialogState();
}

class _SmartRescheduleDialogState extends ConsumerState<SmartRescheduleDialog> {
  final engine = const SchedulingEngine();
  final selected = <String>{};
  final included = <String>{};
  ScheduleOperationType operation = ScheduleOperationType.move;
  SchedulingPreview? preview;
  List<SeriesScheduleCollision> seriesCollisions = const [];
  final seriesChoices = <String, SeriesCollisionChoice>{};
  DateTime targetDay = DateTime.now();
  TimeOfDay targetTime = const TimeOfDay(hour: 9, minute: 0);
  int offsetDays = 1;
  int bufferMinutes = 0;
  int splitMinutes = 30;
  bool allowWarnings = false;
  bool allowOverlap = false;
  bool applying = false;

  bool get sessionMode => widget.sessionIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    selected.addAll(sessionMode ? widget.sessionIds : widget.taskIds);
  }

  List<ScheduleOperationType> get operations => sessionMode
      ? const [
          ScheduleOperationType.move,
          ScheduleOperationType.shift,
          ScheduleOperationType.push,
          ScheduleOperationType.pull,
          ScheduleOperationType.swap,
          ScheduleOperationType.reorder,
          ScheduleOperationType.repack,
          ScheduleOperationType.split,
        ]
      : const [
          ScheduleOperationType.move,
          ScheduleOperationType.shift,
          ScheduleOperationType.push,
          ScheduleOperationType.pull,
          ScheduleOperationType.swap,
          ScheduleOperationType.reorder,
        ];

  Future<void> _generate(AppController controller) async {
    SchedulingPreview next;
    if (sessionMode) {
      final sessions = controller.sessions
          .where((item) => selected.contains(item.id))
          .toList();
      final others = controller.sessions
          .where((item) => !selected.contains(item.id))
          .toList();
      final tasks = {for (final task in controller.tasks) task.id: task};
      final firstStart = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day,
        targetTime.hour,
        targetTime.minute,
      );
      next = switch (operation) {
        ScheduleOperationType.move => engine.moveSessions(
          selected: sessions,
          otherSessions: others,
          fixedEvents: controller.events,
          tasksById: tasks,
          firstStart: firstStart,
          scope: widget.scope,
          buffer: Duration(minutes: bufferMinutes),
          allowOverlap: allowOverlap,
        ),
        ScheduleOperationType.shift => engine.shiftSessions(
          selected: sessions,
          otherSessions: others,
          fixedEvents: controller.events,
          tasksById: tasks,
          days: offsetDays,
          scope: widget.scope,
          allowOverlap: allowOverlap,
        ),
        ScheduleOperationType.push => engine.shiftSessions(
          selected: sessions,
          otherSessions: others,
          fixedEvents: controller.events,
          tasksById: tasks,
          days: offsetDays.abs(),
          scope: widget.scope,
          operation: ScheduleOperationType.push,
          allowOverlap: allowOverlap,
        ),
        ScheduleOperationType.pull => engine.shiftSessions(
          selected: sessions,
          otherSessions: others,
          fixedEvents: controller.events,
          tasksById: tasks,
          days: -offsetDays.abs(),
          scope: widget.scope,
          operation: ScheduleOperationType.pull,
          allowOverlap: allowOverlap,
        ),
        ScheduleOperationType.swap when sessions.length == 2 =>
          engine.swapSessions(
            first: sessions[0],
            second: sessions[1],
            tasksById: tasks,
            scope: widget.scope,
          ),
        ScheduleOperationType.repack => engine.repack(
          selected: sessions,
          otherSessions: others,
          fixedEvents: controller.events,
          tasksById: tasks,
          availability: controller.availability,
          earliest: firstStart,
          scope: widget.scope,
          buffer: Duration(minutes: bufferMinutes),
        ),
        ScheduleOperationType.split when sessions.length == 1 =>
          engine.splitSession(
            session: sessions.single,
            task: tasks[sessions.single.taskId],
            firstMinutes: splitMinutes,
            newSessionId: const Uuid().v4(),
            scope: widget.scope,
            gap: Duration(minutes: bufferMinutes),
          ),
        ScheduleOperationType.reorder => _asOperation(
          engine.moveSessions(
            selected: sessions,
            otherSessions: others,
            fixedEvents: controller.events,
            tasksById: tasks,
            firstStart: firstStart,
            scope: widget.scope,
            buffer: Duration(minutes: bufferMinutes),
            allowOverlap: allowOverlap,
          ),
          ScheduleOperationType.reorder,
        ),
        _ => _invalidPreview(
          operation,
          'This operation needs exactly ${operation == ScheduleOperationType.swap ? 'two' : 'one'} selected sessions.',
        ),
      };
    } else {
      final tasksById = {for (final item in controller.tasks) item.id: item};
      final tasks = widget.taskIds
          .where(selected.contains)
          .map((id) => tasksById[id])
          .whereType<LifeTask>()
          .toList();
      next = switch (operation) {
        ScheduleOperationType.move => engine.moveTasks(
          selected: tasks,
          targetDay: targetDay,
          scope: widget.scope,
        ),
        ScheduleOperationType.shift => engine.shiftTasks(
          selected: tasks,
          days: offsetDays,
          scope: widget.scope,
        ),
        ScheduleOperationType.push => engine.shiftTasks(
          selected: tasks,
          days: offsetDays.abs(),
          scope: widget.scope,
          operation: ScheduleOperationType.push,
        ),
        ScheduleOperationType.pull => engine.shiftTasks(
          selected: tasks,
          days: -offsetDays.abs(),
          scope: widget.scope,
          operation: ScheduleOperationType.pull,
        ),
        ScheduleOperationType.swap when tasks.length == 2 => engine.swapTasks(
          first: tasks[0],
          second: tasks[1],
          scope: widget.scope,
        ),
        ScheduleOperationType.reorder => engine.reorderTasks(
          ordered: tasks,
          firstDay: targetDay,
          scope: widget.scope,
        ),
        _ => _invalidPreview(
          operation,
          'Swap needs exactly two selected tasks.',
        ),
      };
    }
    final dependencyIssues = <ScheduleIssue>[];
    final tasksById = {for (final task in controller.tasks) task.id: task};
    final sessionsById = {
      for (final session in controller.sessions) session.id: session,
    };
    final proposedTaskDays = <String, String?>{
      for (final change in next.changes)
        if (change.targetKind == ScheduleTargetKind.task)
          change.targetId: change.afterDate,
    };
    for (final change in next.changes) {
      final taskId = change.targetKind == ScheduleTargetKind.task
          ? change.targetId
          : change.taskId ?? sessionsById[change.targetId]?.taskId;
      if (taskId == null) continue;
      final proposedDay = change.targetKind == ScheduleTargetKind.task
          ? change.afterDate
          : change.afterStartsAt == null
          ? null
          : localDate(change.afterStartsAt!.toLocal());
      if (proposedDay == null) continue;
      for (final dependency in controller.dependencies.where(
        (link) => link.taskId == taskId,
      )) {
        final prerequisite = tasksById[dependency.prerequisiteId];
        if (prerequisite == null ||
            prerequisite.status == TaskStatus.completed) {
          continue;
        }
        final prerequisiteDay = proposedTaskDays.containsKey(prerequisite.id)
            ? proposedTaskDays[prerequisite.id]
            : prerequisite.scheduledDate;
        if (prerequisiteDay == null ||
            proposedDay.compareTo(prerequisiteDay) <= 0) {
          dependencyIssues.add(
            ScheduleIssue(
              kind: ScheduleIssueKind.dependencyOrder,
              severity: ScheduleIssueSeverity.warning,
              targetId: change.targetId,
              relatedId: prerequisite.id,
              message:
                  '“${tasksById[taskId]?.title ?? 'Task'}” is planned before unfinished prerequisite “${prerequisite.title}”.',
            ),
          );
        }
      }
    }
    next = SchedulingPreview(
      operation: next.operation,
      scope: next.scope,
      changes: next.changes,
      issues: [...next.issues, ...dependencyIssues],
      createdAt: next.createdAt,
    );
    final collisions = await controller.scheduleSeriesCollisions(next);
    if (!mounted) return;
    setState(() {
      preview = next;
      seriesCollisions = collisions;
      seriesChoices.clear();
      included
        ..clear()
        ..addAll(next.changes.map((change) => change.targetId));
      allowWarnings = false;
    });
  }

  SchedulingPreview _asOperation(
    SchedulingPreview value,
    ScheduleOperationType type,
  ) => SchedulingPreview(
    operation: type,
    scope: value.scope,
    changes: value.changes,
    issues: value.issues,
    createdAt: value.createdAt,
  );

  SchedulingPreview _invalidPreview(
    ScheduleOperationType type,
    String message,
  ) => SchedulingPreview(
    operation: type,
    scope: widget.scope,
    changes: const [],
    issues: [
      ScheduleIssue(kind: ScheduleIssueKind.invalidSelection, message: message),
    ],
    createdAt: DateTime.now().toUtc(),
  );

  Future<void> _apply(AppController controller) async {
    final reviewed = preview?.including(included);
    if (reviewed == null || !reviewed.canApply) return;
    final reviewedCollisions = seriesCollisions
        .where((item) => included.contains(item.movedTaskId))
        .toList();
    if (reviewedCollisions.any(
      (item) => !seriesChoices.containsKey(item.movedTaskId),
    )) {
      return;
    }
    setState(() => applying = true);
    try {
      await controller.applySchedulingPreview(
        reviewed,
        seriesChoices: seriesChoices,
        expectedSeriesCollisions: reviewedCollisions,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Schedule was not applied: $error')),
        );
        setState(() {
          preview = null;
          included.clear();
          seriesCollisions = const [];
          seriesChoices.clear();
        });
      }
    } finally {
      if (mounted) setState(() => applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final source = sessionMode
        ? controller.sessions
              .where((item) => widget.sessionIds.contains(item.id))
              .toList()
        : controller.tasks
              .where((item) => widget.taskIds.contains(item.id))
              .toList();
    final reviewed = preview?.including(included);
    final hasWarnings = reviewed?.issues.any((issue) => !issue.isHard) ?? false;
    final unresolvedSeriesCollisions = seriesCollisions.any(
      (item) =>
          included.contains(item.movedTaskId) &&
          !seriesChoices.containsKey(item.movedTaskId),
    );
    return Dialog(
      child: SizedBox(
        width: math.min(880, MediaQuery.sizeOf(context).width - 48),
        height: math.min(720, MediaQuery.sizeOf(context).height - 64),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_fix_high),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Smart Reschedule',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AvailabilityDialog(),
                    ),
                    icon: const Icon(Icons.access_time),
                    label: const Text('Availability'),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<ScheduleOperationType>(
                      initialValue: operation,
                      decoration: const InputDecoration(labelText: 'Operation'),
                      items: operations
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_operationName(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        operation = value!;
                        preview = null;
                        seriesCollisions = const [];
                        seriesChoices.clear();
                      }),
                    ),
                  ),
                  if ({
                    ScheduleOperationType.move,
                    ScheduleOperationType.reorder,
                    ScheduleOperationType.repack,
                  }.contains(operation))
                    OutlinedButton.icon(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: targetDay,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (value != null) setState(() => targetDay = value);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(localDate(targetDay)),
                    ),
                  if (sessionMode &&
                      {
                        ScheduleOperationType.move,
                        ScheduleOperationType.reorder,
                        ScheduleOperationType.repack,
                      }.contains(operation))
                    OutlinedButton.icon(
                      onPressed: () async {
                        final value = await showTimePicker(
                          context: context,
                          initialTime: targetTime,
                        );
                        if (value != null) setState(() => targetTime = value);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(targetTime.format(context)),
                    ),
                  if ({
                    ScheduleOperationType.shift,
                    ScheduleOperationType.push,
                    ScheduleOperationType.pull,
                  }.contains(operation))
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        initialValue: '$offsetDays',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Days'),
                        onChanged: (value) =>
                            offsetDays = int.tryParse(value) ?? 0,
                      ),
                    ),
                  if (sessionMode &&
                      {
                        ScheduleOperationType.move,
                        ScheduleOperationType.reorder,
                        ScheduleOperationType.repack,
                        ScheduleOperationType.split,
                      }.contains(operation))
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        initialValue: '$bufferMinutes',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Buffer minutes',
                        ),
                        onChanged: (value) =>
                            bufferMinutes = int.tryParse(value) ?? 0,
                      ),
                    ),
                  if (operation == ScheduleOperationType.split)
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        initialValue: '$splitMinutes',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'First session minutes',
                        ),
                        onChanged: (value) =>
                            splitMinutes = int.tryParse(value) ?? 0,
                      ),
                    ),
                  if (sessionMode &&
                      {
                        ScheduleOperationType.move,
                        ScheduleOperationType.shift,
                        ScheduleOperationType.push,
                        ScheduleOperationType.pull,
                        ScheduleOperationType.reorder,
                      }.contains(operation))
                    FilterChip(
                      selected: allowOverlap,
                      onSelected: (value) =>
                          setState(() => allowOverlap = value),
                      avatar: const Icon(Icons.layers_outlined, size: 18),
                      label: const Text('Allow intentional overlap'),
                    ),
                  FilledButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => _generate(controller),
                    icon: const Icon(Icons.preview_outlined),
                    label: const Text('Generate preview'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 280,
                      child: Card(
                        child: ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            const ListTile(
                              dense: true,
                              title: Text(
                                'Included items',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'Changing selection clears the preview.',
                              ),
                            ),
                            for (final item in source)
                              CheckboxListTile(
                                dense: true,
                                value: selected.contains(_sourceId(item)),
                                title: Text(_sourceTitle(item, controller)),
                                subtitle: Text(_sourceSchedule(item)),
                                onChanged: (value) => setState(() {
                                  value == true
                                      ? selected.add(_sourceId(item))
                                      : selected.remove(_sourceId(item));
                                  preview = null;
                                  seriesCollisions = const [];
                                  seriesChoices.clear();
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: preview == null
                            ? const Center(
                                child: Text(
                                  'Generate a preview. Nothing is changed until Apply.',
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(12),
                                children: [
                                  for (final collision
                                      in seriesCollisions.where(
                                        (item) =>
                                            included.contains(item.movedTaskId),
                                      ))
                                    DropdownButtonFormField<
                                      SeriesCollisionChoice
                                    >(
                                      key: ValueKey(
                                        'schedule-collision:${collision.movedTaskId}:${seriesChoices[collision.movedTaskId]}',
                                      ),
                                      initialValue:
                                          seriesChoices[collision.movedTaskId],
                                      decoration: InputDecoration(
                                        labelText:
                                            'Recurring collision on ${collision.plannedDate}',
                                        helperText:
                                            '${collision.existingTaskIds.length} occurrence(s) already planned. Combine is unavailable for distinct scheduled tasks.',
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: SeriesCollisionChoice.keepBoth,
                                          child: Text('Keep both occurrences'),
                                        ),
                                        DropdownMenuItem(
                                          value: SeriesCollisionChoice.skipNew,
                                          enabled: collision.canSkipMoved,
                                          child: Text(
                                            collision.canSkipMoved
                                                ? 'Skip moved occurrence'
                                                : 'Skip unavailable: linked or started work',
                                          ),
                                        ),
                                        const DropdownMenuItem(
                                          value: SeriesCollisionChoice.combine,
                                          enabled: false,
                                          child: Text('Combine unavailable'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(
                                            () =>
                                                seriesChoices[collision
                                                        .movedTaskId] =
                                                    value,
                                          );
                                        }
                                      },
                                    ),
                                  for (final issue in preview!.issues)
                                    ListTile(
                                      dense: true,
                                      leading: Icon(
                                        issue.isHard
                                            ? Icons.error_outline
                                            : Icons.warning_amber_rounded,
                                        color: issue.isHard
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .error
                                            : Colors.amber.shade800,
                                      ),
                                      title: Text(issue.message),
                                      subtitle: Text(
                                        issue.isHard
                                            ? 'Must be resolved'
                                            : 'Warning',
                                      ),
                                    ),
                                  if (preview!.changes.isEmpty)
                                    const ListTile(
                                      title: Text(
                                        'No eligible scheduling changes.',
                                      ),
                                    ),
                                  for (final change in preview!.changes)
                                    CheckboxListTile(
                                      value: included.contains(change.targetId),
                                      onChanged: (value) => setState(() {
                                        value == true
                                            ? included.add(change.targetId)
                                            : included.remove(change.targetId);
                                      }),
                                      title: Text(
                                        _changeTitle(change, controller),
                                      ),
                                      subtitle: Text(
                                        '${_before(change)}  →  ${_after(change)}',
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasWarnings)
                CheckboxListTile(
                  value: allowWarnings,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I reviewed the warnings and want to apply these changes.',
                  ),
                  onChanged: (value) =>
                      setState(() => allowWarnings = value ?? false),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        applying ||
                            unresolvedSeriesCollisions ||
                            reviewed == null ||
                            !reviewed.canApply ||
                            (hasWarnings && !allowWarnings)
                        ? null
                        : () => _apply(controller),
                    icon: const Icon(Icons.check),
                    label: Text(applying ? 'Applying…' : 'Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvailabilityDialog extends ConsumerStatefulWidget {
  const AvailabilityDialog({super.key});

  @override
  ConsumerState<AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends ConsumerState<AvailabilityDialog> {
  late final Map<int, bool> enabled;
  late final Map<int, TimeOfDay> starts;
  late final Map<int, TimeOfDay> ends;
  late final Map<String, List<AvailabilityWindow>> exceptions;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(appControllerProvider).availability;
    enabled = {};
    starts = {};
    ends = {};
    exceptions = {
      for (final entry in plan.exceptions.entries) entry.key: [...entry.value],
    };
    for (var day = 1; day <= 7; day++) {
      final windows = plan.weekly[day] ?? const [];
      enabled[day] = windows.isNotEmpty;
      final first = windows.isEmpty ? null : windows.first;
      starts[day] = _time(first?.startMinute ?? 9 * 60);
      ends[day] = _time(first?.endMinute ?? 17 * 60);
    }
  }

  TimeOfDay _time(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
  int _minute(TimeOfDay value) => value.hour * 60 + value.minute;

  Future<void> _pick(int day, bool start) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? starts[day]! : ends[day]!,
    );
    if (value != null) {
      setState(() => start ? starts[day] = value : ends[day] = value);
    }
  }

  Future<void> _save() async {
    final weekly = <int, List<AvailabilityWindow>>{};
    for (var day = 1; day <= 7; day++) {
      if (enabled[day] != true) continue;
      final start = _minute(starts[day]!);
      final end = _minute(ends[day]!);
      if (end <= start) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_weekday(day)} must end after it starts.')),
        );
        return;
      }
      weekly[day] = [AvailabilityWindow(start, end)];
    }
    setState(() => saving = true);
    try {
      await ref
          .read(appControllerProvider)
          .saveAvailability(
            AvailabilityPlan(weekly: weekly, exceptions: exceptions),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _addException({required bool unavailable}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    if (unavailable) {
      setState(() => exceptions[localDate(date)] = []);
      return;
    }
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (end == null) return;
    final startMinute = _minute(start);
    final endMinute = _minute(end);
    if (endMinute <= startMinute) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The exception must end after it starts.'),
          ),
        );
      }
      return;
    }
    setState(() {
      exceptions[localDate(date)] = [
        AvailabilityWindow(startMinute, endMinute),
      ];
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Weekly availability'),
    content: SizedBox(
      width: 480,
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'No hours are assumed. Repack only uses windows enabled here. Buffer defaults to 0 minutes.',
          ),
          const SizedBox(height: 12),
          for (var day = 1; day <= 7; day++)
            Row(
              children: [
                Checkbox(
                  value: enabled[day],
                  onChanged: (value) =>
                      setState(() => enabled[day] = value ?? false),
                ),
                SizedBox(width: 86, child: Text(_weekday(day))),
                TextButton(
                  onPressed: enabled[day]! ? () => _pick(day, true) : null,
                  child: Text(starts[day]!.format(context)),
                ),
                const Text('to'),
                TextButton(
                  onPressed: enabled[day]! ? () => _pick(day, false) : null,
                  child: Text(ends[day]!.format(context)),
                ),
              ],
            ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Date exceptions',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Add date exception',
                onSelected: (value) =>
                    _addException(unavailable: value == 'off'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'off', child: Text('Unavailable date')),
                  PopupMenuItem(value: 'custom', child: Text('Custom hours')),
                ],
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (exceptions.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No date-specific exceptions.'),
            ),
          for (final entry
              in exceptions.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key)))
            ListTile(
              dense: true,
              title: Text(entry.key),
              subtitle: Text(
                entry.value.isEmpty
                    ? 'Unavailable all day'
                    : '${_formatMinute(entry.value.first.startMinute)} – ${_formatMinute(entry.value.first.endMinute)}',
              ),
              trailing: IconButton(
                tooltip: 'Remove exception',
                onPressed: () => setState(() => exceptions.remove(entry.key)),
                icon: const Icon(Icons.delete_outline),
              ),
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
        onPressed: saving ? null : _save,
        child: Text(saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

class ScheduleHistoryDialog extends ConsumerWidget {
  const ScheduleHistoryDialog({super.key});

  Future<void> _restore(
    BuildContext context,
    AppController controller,
    SchedulingOperation operation, {
    bool original = false,
    bool undo = false,
  }) async {
    final preview = await controller.previewRestore(
      operation.id,
      original: original,
      undo: undo,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _RestorePreviewDialog(preview: preview),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    return Dialog(
      child: SizedBox(
        width: 760,
        height: 620,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Schedule history',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: controller.schedulingHistory.isEmpty
                  ? const Center(child: Text('No scheduling changes yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: controller.schedulingHistory.length,
                      itemBuilder: (context, index) {
                        final item = controller.schedulingHistory[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              item.source == ScheduleChangeSource.manual
                                  ? Icons.edit_calendar_outlined
                                  : Icons.auto_fix_high,
                            ),
                            title: Text(
                              '${_operationName(item.type)} · ${item.changes.length} ${item.changes.length == 1 ? 'item' : 'items'}',
                            ),
                            subtitle: Text(
                              '${item.scope}\n${item.createdAt.toLocal()}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'undo') {
                                  _restore(
                                    context,
                                    controller,
                                    item,
                                    undo: true,
                                  );
                                }
                                if (value == 'previous') {
                                  _restore(context, controller, item);
                                }
                                if (value == 'original') {
                                  _restore(
                                    context,
                                    controller,
                                    item,
                                    original: true,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'undo',
                                  child: Text('Undo safely'),
                                ),
                                PopupMenuItem(
                                  value: 'previous',
                                  child: Text('Restore this previous schedule'),
                                ),
                                PopupMenuItem(
                                  value: 'original',
                                  child: Text('Restore original schedule'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestorePreviewDialog extends ConsumerStatefulWidget {
  const _RestorePreviewDialog({required this.preview});
  final SchedulingPreview preview;

  @override
  ConsumerState<_RestorePreviewDialog> createState() =>
      _RestorePreviewDialogState();
}

class _RestorePreviewDialogState extends ConsumerState<_RestorePreviewDialog> {
  late final Set<String> included = widget.preview.changes
      .map((item) => item.targetId)
      .toSet();
  bool applying = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final reviewed = widget.preview.including(included);
    return AlertDialog(
      title: Text(_operationName(widget.preview.operation)),
      content: SizedBox(
        width: 650,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Later manual scheduling changes are excluded automatically. Review before applying.',
            ),
            for (final issue in widget.preview.issues)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(issue.message),
              ),
            for (final change in widget.preview.changes)
              CheckboxListTile(
                value: included.contains(change.targetId),
                onChanged: (value) => setState(
                  () => value == true
                      ? included.add(change.targetId)
                      : included.remove(change.targetId),
                ),
                title: Text(_changeTitle(change, controller)),
                subtitle: Text('${_before(change)}  →  ${_after(change)}'),
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
          onPressed: applying || !reviewed.canApply
              ? null
              : () async {
                  setState(() => applying = true);
                  try {
                    await controller.applySchedulingPreview(reviewed);
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Restore failed: $error')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => applying = false);
                  }
                },
          child: Text(applying ? 'Applying…' : 'Apply restoration'),
        ),
      ],
    );
  }
}

String _operationName(ScheduleOperationType value) => switch (value) {
  ScheduleOperationType.move => 'Move',
  ScheduleOperationType.shift => 'Shift',
  ScheduleOperationType.push => 'Push',
  ScheduleOperationType.pull => 'Pull',
  ScheduleOperationType.swap => 'Swap',
  ScheduleOperationType.reorder => 'Reorder',
  ScheduleOperationType.repack => 'Repack',
  ScheduleOperationType.split => 'Split',
  ScheduleOperationType.restorePrevious => 'Restore previous schedule',
  ScheduleOperationType.restoreOriginal => 'Restore original schedule',
  ScheduleOperationType.undo => 'Undo schedule change',
};

String _sourceTitle(Object value, AppController controller) {
  if (value is LifeTask) return value.title;
  final session = value as WorkSession;
  return controller.tasks
          .where((task) => task.id == session.taskId)
          .firstOrNull
          ?.title ??
      'Work session';
}

String _sourceId(Object value) => switch (value) {
  LifeTask task => task.id,
  WorkSession session => session.id,
  _ => throw ArgumentError('Unsupported scheduling item'),
};

String _sourceSchedule(Object value) {
  if (value is LifeTask) return value.scheduledDate ?? 'Not planned';
  final session = value as WorkSession;
  return '${session.startsAt.toLocal()} – ${session.endsAt.toLocal()}';
}

String _changeTitle(ScheduleChange change, AppController controller) {
  if (change.targetKind == ScheduleTargetKind.task) {
    return controller.tasks
            .where((task) => task.id == change.targetId)
            .firstOrNull
            ?.title ??
        'Task';
  }
  if (change.createsSession) return 'New split work session';
  final session = controller.sessions
      .where((item) => item.id == change.targetId)
      .firstOrNull;
  return controller.tasks
          .where((task) => task.id == session?.taskId)
          .firstOrNull
          ?.title ??
      'Work session';
}

String _before(ScheduleChange change) {
  if (change.targetKind == ScheduleTargetKind.task) {
    return change.beforeDate ?? 'Unscheduled';
  }
  if (change.beforeStartsAt == null) return 'New session';
  return '${change.beforeStartsAt!.toLocal()} – ${change.beforeEndsAt!.toLocal()}';
}

String _after(ScheduleChange change) {
  if (change.targetKind == ScheduleTargetKind.task) {
    return change.afterDate ?? 'Unscheduled';
  }
  if (change.deleteSession) return 'Remove generated session';
  return '${change.afterStartsAt!.toLocal()} – ${change.afterEndsAt!.toLocal()}';
}

String _weekday(int day) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][day - 1];

String _formatMinute(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
