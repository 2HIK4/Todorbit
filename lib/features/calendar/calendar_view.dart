import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import 'event_editor.dart';
import '../shared/icon_picker.dart';
import 'session_editor.dart';

enum CalendarMode { day, week, month }

int monthEntryCapacity(double cellHeight, double textScale) {
  final rowHeight = 32.0 * textScale.clamp(1.0, 2.0);
  return ((cellHeight - 34) / rowHeight).floor().clamp(0, 30);
}

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({
    super.key,
    required this.onTaskTap,
    required this.onSmartReschedule,
    required this.onAddTask,
  });
  final void Function(LifeTask task) onTaskTap;
  final VoidCallback onSmartReschedule;
  final void Function(DateTime date) onAddTask;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime selected = DateTime.now();
  CalendarMode mode = CalendarMode.week;
  Offset _lastTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    mode = CalendarMode.values.byName(
      ref.read(appControllerProvider).customization.calendarDefaultView,
    );
  }

  DateTime get day => DateTime(selected.year, selected.month, selected.day);
  DateTime get weekStart =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);

  Future<void> _move(int direction) async {
    setState(() {
      selected = switch (mode) {
        CalendarMode.day => DateTime(day.year, day.month, day.day + direction),
        CalendarMode.week => DateTime(
          day.year,
          day.month,
          day.day + 7 * direction,
        ),
        CalendarMode.month => _shiftMonth(direction),
      };
    });
    await _loadSelectedMonth();
  }

  Future<void> _loadSelectedMonth() async {
    try {
      await ref.read(appControllerProvider).ensureRecurringMonth(selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load recurring tasks: $error')),
        );
      }
    }
  }

  DateTime _shiftMonth(int direction) {
    final first = DateTime(day.year, day.month + direction);
    final lastDay = DateUtils.getDaysInMonth(first.year, first.month);
    return DateTime(first.year, first.month, day.day.clamp(1, lastDay));
  }

  Future<void> _editEvent([FixedEvent? event, DateTime? initialDate]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 460,
          height: 550,
          child: EventEditor(
            event: event,
            initialDay: initialDate ?? day,
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
    if (mounted) await _loadSelectedMonth();
  }

  Future<void> _showCreateMenu(DateTime date, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'event',
          child: Text(date.hour == 0 ? 'Add Event' : 'Add Event at this time'),
        ),
        const PopupMenuItem(value: 'task', child: Text('Add Task')),
      ],
    );
    if (!mounted) return;
    if (action == 'event') await _editEvent(null, date);
    if (action == 'task') widget.onAddTask(date);
  }

  Future<void> _showDayPreview(DateTime date, Offset position) async {
    final size = MediaQuery.sizeOf(context);
    final entries = _entries(ref.read(appControllerProvider), date);
    final previewHeight = (132.0 + entries.length * 58.0)
        .clamp(160.0, 440.0)
        .clamp(0.0, size.height - 16);
    final left = position.dx.clamp(
      8.0,
      (size.width - 370).clamp(8.0, double.infinity),
    );
    final top = position.dy.clamp(
      8.0,
      (size.height - previewHeight - 8).clamp(8.0, double.infinity),
    );
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close day preview',
      pageBuilder: (popupContext, _, _) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: (size.width - 16).clamp(0.0, 350.0),
                height: previewHeight,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(localDate(date)),
                      trailing: IconButton(
                        tooltip: 'Close preview',
                        onPressed: () => Navigator.pop(popupContext),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final entry in entries)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                entry.event != null
                                    ? Icons.event_outlined
                                    : entry.session != null
                                    ? Icons.schedule
                                    : Icons.task_alt_outlined,
                              ),
                              title: Text(
                                entry.label,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: entry.event?.cancelled == true
                                  ? const Text('Cancelled')
                                  : entry.task == null
                                  ? null
                                  : Text(entry.task!.status.name),
                              onTap: () {
                                Navigator.pop(popupContext);
                                if (entry.event != null) {
                                  _editEvent(entry.event);
                                } else if (entry.session != null) {
                                  _editSession(entry.session);
                                } else {
                                  widget.onTaskTap(entry.task!);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(popupContext);
                            _editEvent(null, date);
                          },
                          child: const Text('Add Event'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(popupContext);
                            widget.onAddTask(date);
                          },
                          child: const Text('Add Task'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(popupContext);
                            setState(() {
                              selected = date;
                              mode = CalendarMode.day;
                            });
                          },
                          child: const Text('Open Day View'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSession([WorkSession? session]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 460,
          height: 550,
          child: SessionEditor(
            session: session,
            initialDay: day,
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Calendar',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() => selected = DateTime.now());
                  _loadSelectedMonth();
                },
                child: const Text('Today'),
              ),
              IconButton(
                tooltip: 'Previous period',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next period',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
              Text(
                _periodLabel(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SegmentedButton<CalendarMode>(
                segments: const [
                  ButtonSegment(value: CalendarMode.day, label: Text('Day')),
                  ButtonSegment(value: CalendarMode.week, label: Text('Week')),
                  ButtonSegment(
                    value: CalendarMode.month,
                    label: Text('Month'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (value) =>
                    setState(() => mode = value.first),
              ),
              SegmentedButton<CalendarContent>(
                segments: const [
                  ButtonSegment(
                    value: CalendarContent.both,
                    label: Text('Both'),
                  ),
                  ButtonSegment(
                    value: CalendarContent.eventsOnly,
                    label: Text('Events only'),
                  ),
                  ButtonSegment(
                    value: CalendarContent.tasksOnly,
                    label: Text('Tasks only'),
                  ),
                ],
                selected: {controller.calendarContent},
                onSelectionChanged: (value) async {
                  try {
                    await controller.setCalendarContent(value.first);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not save calendar filter: $error',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              FilledButton.icon(
                onPressed: () => _editEvent(),
                icon: const Icon(Icons.add),
                label: const Text('Event'),
              ),
              OutlinedButton.icon(
                onPressed: controller.tasks.any((task) => task.isOpen)
                    ? () => _editSession()
                    : null,
                icon: const Icon(Icons.schedule),
                label: const Text('Work session'),
              ),
              OutlinedButton.icon(
                onPressed: controller.sessions.isEmpty
                    ? null
                    : widget.onSmartReschedule,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Reschedule'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (mode) {
            CalendarMode.day => _dayList(controller, day),
            CalendarMode.week => _weekGrid(controller),
            CalendarMode.month => _monthGrid(controller),
          },
        ),
      ],
    );
  }

  String _periodLabel() {
    if (mode == CalendarMode.day) return localDate(day);
    if (mode == CalendarMode.week) {
      return '${localDate(weekStart)} – ${localDate(DateTime(weekStart.year, weekStart.month, weekStart.day + 6))}';
    }
    return '${_months[day.month - 1]} ${day.year}';
  }

  Widget _dayList(AppController controller, DateTime date) {
    final entries = _entries(controller, date);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No planned tasks, deadlines, or events on this day.'),
          ),
        ...entries.map((entry) => _entryTile(entry)),
        const SizedBox(height: 12),
        Text('Time slots', style: Theme.of(context).textTheme.titleSmall),
        for (var hour = 7; hour <= 22; hour++)
          GestureDetector(
            onSecondaryTapDown: (details) => _showCreateMenu(
              DateTime(date.year, date.month, date.day, hour),
              details.globalPosition,
            ),
            child: Container(
              height: 42,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }

  Widget _weekGrid(AppController controller) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth < 650) {
        return ListView(
          children: List.generate(7, (index) {
            final date = DateTime(
              weekStart.year,
              weekStart.month,
              weekStart.day + index,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onSecondaryTapDown: (details) =>
                      _showCreateMenu(date, details.globalPosition),
                  onTapDown: (details) =>
                      _lastTapPosition = details.globalPosition,
                  child: InkWell(
                    onTap: () => _showDayPreview(date, _lastTapPosition),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Text(
                        '${_weekdays[index]} ${localDate(date)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ),
                ..._entries(controller, date).map(_entryTile),
              ],
            );
          }),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (index) {
          final date = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + index,
          );
          final entries = _entries(controller, date);
          return Expanded(
            child: GestureDetector(
              onSecondaryTapDown: (details) =>
                  _showCreateMenu(date, details.globalPosition),
              onTapDown: (details) => _lastTapPosition = details.globalPosition,
              onTap: () => _showDayPreview(date, _lastTapPosition),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTapDown: (details) =>
                          _lastTapPosition = details.globalPosition,
                      onTap: () => _showDayPreview(date, _lastTapPosition),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: localDate(date) == localDate(DateTime.now())
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.55)
                            : null,
                        child: Text(
                          '${_weekdays[index]} ${date.day}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: localDate(date) == localDate(DateTime.now())
                                ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: entries
                            .map((entry) => _entryTile(entry, compact: true))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      );
    },
  );

  Widget _monthGrid(AppController controller) {
    final first = DateTime(day.year, day.month);
    final offset = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(day.year, day.month);
    final cellCount = ((offset + days + 6) ~/ 7) * 7;
    return LayoutBuilder(
      builder: (context, bounds) {
        final rows = cellCount ~/ 7;
        final cellHeight = (bounds.maxHeight - 24) / rows;
        final previewCount = monthEntryCapacity(
          cellHeight,
          MediaQuery.textScalerOf(context).scale(1),
        );
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: cellHeight.clamp(90.0, double.infinity),
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            final date = DateTime(
              first.year,
              first.month,
              first.day + index - offset,
            );
            final inMonth = date.month == day.month;
            final entries = _entries(controller, date);
            final scheme = Theme.of(context).colorScheme;
            return GestureDetector(
              onSecondaryTapDown: (details) =>
                  _showCreateMenu(date, details.globalPosition),
              child: InkWell(
                onTapDown: (details) =>
                    _lastTapPosition = details.globalPosition,
                onTap: () => _showDayPreview(date, _lastTapPosition),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: localDate(date) == localDate(DateTime.now())
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        date.year == selected.year &&
                            date.month == selected.month &&
                            date.day == selected.day
                        ? Border.all(color: scheme.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: inMonth ? null : scheme.outline,
                        ),
                      ),
                      const SizedBox(height: 3),
                      for (final entry in entries.take(
                        entries.length > previewCount
                            ? (previewCount - 1).clamp(0, 30)
                            : previewCount,
                      ))
                        _monthEntry(entry),
                      if (entries.length > previewCount)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 22),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () =>
                              _showDayPreview(date, _lastTapPosition),
                          child: Text(
                            '+${entries.length - (previewCount - 1).clamp(0, 30)} more',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_CalendarEntry> _entries(AppController controller, DateTime date) {
    final key = localDate(date);
    final list = <_CalendarEntry>[];
    if (controller.calendarContent != CalendarContent.tasksOnly) {
      for (final event in controller.events) {
        final start = event.startsAt.toLocal();
        final end = event.endsAt.toLocal();
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = DateTime(date.year, date.month, date.day + 1);
        if (start.isBefore(dayEnd) && end.isAfter(dayStart)) {
          final time = localDate(start) == key
              ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
              : 'Continues';
          list.add(
            _CalendarEntry(
              'Event · '
              '${event.allDay ? 'All day' : time} · ${event.title}'
              '${event.location.isEmpty ? '' : ' · ${event.location}'}',
              event: event,
            ),
          );
        }
      }
    }
    if (controller.calendarContent != CalendarContent.eventsOnly) {
      for (final task in controller.tasks) {
        final parentId = controller.taskParents[task.id];
        final parent = controller.tasks
            .where((item) => item.id == parentId)
            .firstOrNull;
        final parentTitle = parent?.title;
        if (task.scheduledDate == key) {
          final activity = controller.progressiveAssignments[task.id]?.title;
          list.add(
            _CalendarEntry(
              'Plan · ${parentTitle == null ? task.title : '$parentTitle\n${task.title}'}${activity == null ? '' : '\nCurrent step: $activity'}',
              task: task,
              parentTitle: parentTitle,
            ),
          );
        }
        if (task.deadlineDate == key && task.scheduledDate != key) {
          list.add(
            _CalendarEntry(
              'Deadline · ${parentTitle == null ? task.title : '$parentTitle\n${task.title}'}',
              task: task,
              parentTitle: parentTitle,
            ),
          );
        }
      }
      for (final session in controller.sessions) {
        final start = session.startsAt.toLocal();
        final end = session.endsAt.toLocal();
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = DateTime(date.year, date.month, date.day + 1);
        if (start.isBefore(dayEnd) && end.isAfter(dayStart)) {
          final task = controller.tasks
              .where((item) => item.id == session.taskId)
              .firstOrNull;
          final state = session.needsConfirmation
              ? 'Needs confirmation'
              : session.lateStart
              ? 'Late start'
              : session.outcome.name;
          list.add(
            _CalendarEntry(
              'Work · ${task?.title ?? 'Task'} · $state',
              session: session,
            ),
          );
        }
      }
    }
    return list;
  }

  Widget _monthEntry(_CalendarEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final event = entry.event;
    final accent = event?.colorValue == null
        ? scheme.primary
        : Color(event!.colorValue!);
    final text = event == null
        ? entry.label.replaceAll('\n', ' · ')
        : event.title;
    return Tooltip(
      message: event?.cancelled == true
          ? 'Cancelled event: ${entry.label}'
          : entry.label,
      child: GestureDetector(
        onSecondaryTapDown: (_) {},
        child: InkWell(
          onTap: () {
            if (event != null) {
              _editEvent(event);
            } else if (entry.session != null) {
              _editSession(entry.session);
            } else {
              widget.onTaskTap(entry.task!);
            }
          },
          child: Container(
            height: 29 * MediaQuery.textScalerOf(context).scale(1),
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: event != null
                  ? Color.lerp(
                      scheme.surface,
                      accent,
                      event.cancelled ? 0.07 : 0.17,
                    )
                  : entry.session != null
                  ? scheme.tertiaryContainer.withValues(alpha: 0.55)
                  : scheme.surfaceContainerHigh,
              border: Border(
                left: BorderSide(
                  color: event != null
                      ? accent
                      : entry.session != null
                      ? scheme.tertiary
                      : scheme.outline,
                  width: 2,
                ),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  event != null
                      ? Icons.event_outlined
                      : entry.session != null
                      ? Icons.schedule_outlined
                      : Icons.task_alt_outlined,
                  size: 12,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: entry.parentTitle == null
                      ? Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: event?.cancelled == true
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            decoration: event?.cancelled == true
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              entry.parentTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              entry.task!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryTile(_CalendarEntry entry, {bool compact = false}) {
    final event = entry.event;
    final session = entry.session;
    final conflicts = event == null || event.cancelled
        ? 0
        : _eventConflictCount(event);
    final scheme = Theme.of(context).colorScheme;
    final accent = event?.colorValue == null
        ? scheme.primary
        : Color(event!.colorValue!);
    return Card(
      color: event == null
          ? null
          : Color.lerp(scheme.surface, accent, event.cancelled ? 0.07 : 0.17),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: event == null
            ? BorderSide.none
            : BorderSide(color: accent.withValues(alpha: 0.55)),
      ),
      margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 10, vertical: 3),
      child: GestureDetector(
        onSecondaryTapDown: (_) {},
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: event != null
              ? () => _editEvent(event)
              : session != null
              ? () => _editSession(session)
              : () => widget.onTaskTap(entry.task!),
          child: Padding(
            padding: EdgeInsets.all(compact ? 6 : 12),
            child: Row(
              children: [
                Icon(
                  event != null
                      ? iconForKey(event.iconName, Icons.event_outlined)
                      : session != null
                      ? Icons.schedule
                      : Icons.check_circle_outline,
                  size: compact ? 14 : 18,
                  color: event?.colorValue == null
                      ? Theme.of(context).colorScheme.primary
                      : Color(event!.colorValue!),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: event != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              maxLines: compact ? 2 : null,
                              overflow: compact ? TextOverflow.ellipsis : null,
                              style: TextStyle(
                                fontSize: compact ? 11 : 14,
                                fontWeight: FontWeight.w600,
                                color: event.cancelled
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                                decoration: event.cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              '${event.allDay ? 'All day' : '${event.startsAt.toLocal().hour.toString().padLeft(2, '0')}:${event.startsAt.toLocal().minute.toString().padLeft(2, '0')}'}${event.cancelled ? ' · Cancelled' : ''}',
                              style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : entry.parentTitle != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.parentTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 11 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              entry.task!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          entry.label,
                          maxLines: compact ? 3 : null,
                          overflow: compact ? TextOverflow.ellipsis : null,
                          style: TextStyle(fontSize: compact ? 11 : 14),
                        ),
                ),
                if (conflicts > 0)
                  Tooltip(
                    message:
                        'Overlaps $conflicts other event${conflicts == 1 ? '' : 's'} or work session${conflicts == 1 ? '' : 's'}',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: compact ? 14 : 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _eventConflictCount(FixedEvent event) {
    final controller = ref.read(appControllerProvider);
    final otherEvents = controller.events
        .where(
          (other) =>
              !other.cancelled &&
              !(other.id == event.id &&
                  other.nominalDate == event.nominalDate) &&
              other.startsAt.isBefore(event.endsAt) &&
              other.endsAt.isAfter(event.startsAt),
        )
        .length;
    final sessions = controller.sessions
        .where(
          (session) =>
              session.outcome != SessionOutcome.skipped &&
              session.startsAt.isBefore(event.endsAt) &&
              session.endsAt.isAfter(event.startsAt),
        )
        .length;
    return otherEvents + sessions;
  }
}

class _CalendarEntry {
  const _CalendarEntry(
    this.label, {
    this.event,
    this.task,
    this.session,
    this.parentTitle,
  });
  final String label;
  final FixedEvent? event;
  final LifeTask? task;
  final WorkSession? session;
  final String? parentTitle;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
