import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import 'event_editor.dart';
import 'session_editor.dart';

enum CalendarMode { day, week, month }

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({
    super.key,
    required this.onTaskTap,
    required this.onSmartReschedule,
  });
  final void Function(LifeTask task) onTaskTap;
  final VoidCallback onSmartReschedule;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime selected = DateTime.now();
  CalendarMode mode = CalendarMode.week;

  DateTime get day => DateTime(selected.year, selected.month, selected.day);
  DateTime get weekStart =>
      DateTime(day.year, day.month, day.day - day.weekday + 1);

  void _move(int direction) => setState(() {
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

  DateTime _shiftMonth(int direction) {
    final first = DateTime(day.year, day.month + direction);
    final lastDay = DateUtils.getDaysInMonth(first.year, first.month);
    return DateTime(first.year, first.month, day.day.clamp(1, lastDay));
  }

  Future<void> _editEvent([FixedEvent? event]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 460,
          height: 550,
          child: EventEditor(
            event: event,
            initialDay: day,
            onClose: () => Navigator.pop(context),
          ),
        ),
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
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              OutlinedButton(
                onPressed: () => setState(() => selected = DateTime.now()),
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
    if (entries.isEmpty) {
      return const Center(
        child: Text('No planned tasks, deadlines, or events on this day.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: entries.map((entry) => _entryTile(entry)).toList(),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    '${_weekdays[index]} ${localDate(date)}',
                    style: Theme.of(context).textTheme.titleSmall,
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
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${_weekdays[index]} ${date.day}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.95,
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
        return InkWell(
          onTap: () => setState(() {
            selected = date;
            mode = CalendarMode.day;
          }),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: localDate(date) == localDate(DateTime.now())
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
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
                for (final entry in entries.take(2))
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                if (entries.length > 2)
                  Text(
                    '+${entries.length - 2} more',
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_CalendarEntry> _entries(AppController controller, DateTime date) {
    final key = localDate(date);
    final list = <_CalendarEntry>[];
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
          _CalendarEntry('Event · $time · ${event.title}', event: event),
        );
      }
    }
    for (final task in controller.tasks) {
      if (task.scheduledDate == key) {
        list.add(_CalendarEntry('Plan · ${task.title}', task: task));
      }
      if (task.deadlineDate == key) {
        list.add(_CalendarEntry('Deadline · ${task.title}', task: task));
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
    return list;
  }

  Widget _entryTile(_CalendarEntry entry, {bool compact = false}) {
    final event = entry.event;
    final session = entry.session;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 10, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: event != null
            ? () => _editEvent(event)
            : session != null
            ? () => _editSession(session)
            : () => widget.onTaskTap(entry.task!),
        child: Padding(
          padding: EdgeInsets.all(compact ? 6 : 12),
          child: Text(
            entry.label,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: TextStyle(fontSize: compact ? 11 : 14),
          ),
        ),
      ),
    );
  }
}

class _CalendarEntry {
  const _CalendarEntry(this.label, {this.event, this.task, this.session});
  final String label;
  final FixedEvent? event;
  final LifeTask? task;
  final WorkSession? session;
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
