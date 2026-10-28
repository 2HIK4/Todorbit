import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../calendar/event_editor.dart';
import '../calendar/session_editor.dart';

Future<void> openMobileEditor(
  BuildContext context,
  Widget Function(BuildContext) builder,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (routeContext) =>
        Scaffold(body: SafeArea(child: builder(routeContext))),
  ),
);

class MobileCalendar extends ConsumerStatefulWidget {
  const MobileCalendar({
    super.key,
    required this.openTask,
    required this.addTask,
    this.initialDay,
  });
  final ValueChanged<LifeTask> openTask;
  final ValueChanged<DateTime> addTask;
  final DateTime? initialDay;
  @override
  ConsumerState<MobileCalendar> createState() => _MobileCalendarState();
}

class _MobileCalendarState extends ConsumerState<MobileCalendar> {
  late DateTime selected = DateUtils.dateOnly(
    widget.initialDay ?? DateTime.now(),
  );
  String mode = 'month';

  Future<void> move(int delta) async {
    setState(() {
      if (mode == 'month') {
        final first = DateTime(selected.year, selected.month + delta);
        selected = DateTime(
          first.year,
          first.month,
          selected.day.clamp(
            1,
            DateUtils.getDaysInMonth(first.year, first.month),
          ),
        );
      } else {
        selected = DateTime(
          selected.year,
          selected.month,
          selected.day + delta * (mode == 'week' ? 7 : 1),
        );
      }
    });
    try {
      await ref.read(appControllerProvider).ensureRecurringMonth(selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> event([FixedEvent? value]) => openMobileEditor(
    context,
    (route) => EventEditor(
      event: value,
      initialDay: selected,
      onClose: () => Navigator.pop(route),
    ),
  );

  Future<void> session([WorkSession? value]) => openMobileEditor(
    context,
    (route) => SessionEditor(
      session: value,
      initialDay: selected,
      onClose: () => Navigator.pop(route),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final local = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dayKey = localDate(selected);
    final first = mode == 'month'
        ? DateTime(selected.year, selected.month)
        : DateTime(
            selected.year,
            selected.month,
            selected.day - (selected.weekday - controller.firstWeekday + 7) % 7,
          );
    final offset = (first.weekday - controller.firstWeekday + 7) % 7;
    final cells = mode == 'week'
        ? 7
        : ((offset + DateUtils.getDaysInMonth(first.year, first.month)) / 7)
                  .ceil() *
              7;
    List<FixedEvent> eventsOn(DateTime d) => controller.events
        .where(
          (e) =>
              !e.cancelled &&
              e.startsAt.toLocal().isBefore(
                DateTime(d.year, d.month, d.day + 1),
              ) &&
              e.endsAt.toLocal().isAfter(d),
        )
        .toList();
    final tasks = controller.tasks
        .where((t) => t.scheduledDate == dayKey)
        .toList();
    final sessions =
        controller.sessions
            .where((s) => localDate(s.startsAt.toLocal()) == dayKey)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final events = eventsOn(selected)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final showTasks = controller.calendarContent != CalendarContent.eventsOnly;
    final showEvents = controller.calendarContent != CalendarContent.tasksOnly;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'day', label: Text('Day')),
            ButtonSegment(value: 'week', label: Text('Week')),
            ButtonSegment(value: 'month', label: Text('Month')),
          ],
          selected: {mode},
          onSelectionChanged: (value) => setState(() => mode = value.first),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous $mode',
              onPressed: () => move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null && mounted) {
                    setState(() => selected = d);
                    await move(0);
                  }
                },
                child: Text(local.formatMonthYear(selected)),
              ),
            ),
            IconButton(
              tooltip: 'Next $mode',
              onPressed: () => move(1),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Today',
              onPressed: () {
                setState(() => selected = DateUtils.dateOnly(DateTime.now()));
                move(0);
              },
              icon: const Icon(Icons.today),
            ),
          ],
        ),
        if (mode != 'day') ...[
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: Text(
                    local.narrowWeekdays[(controller.firstWeekday + i) % 7],
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 54,
            ),
            itemBuilder: (context, i) {
              final date = DateTime(
                first.year,
                first.month,
                first.day + i - (mode == 'week' ? 0 : offset),
              );
              final key = localDate(date);
              final count =
                  (showEvents ? eventsOn(date).length : 0) +
                  (showTasks
                      ? controller.tasks
                                .where((t) => t.scheduledDate == key)
                                .length +
                            controller.sessions
                                .where(
                                  (s) => localDate(s.startsAt.toLocal()) == key,
                                )
                                .length
                      : 0);
              return Semantics(
                selected: key == dayKey,
                label: '${local.formatFullDate(date)}, $count items',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => selected = date),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: key == dayKey ? scheme.primaryContainer : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontWeight:
                                DateUtils.isSameDay(date, DateTime.now())
                                ? FontWeight.bold
                                : null,
                            color: date.month != selected.month
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (count > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              count >= 4 ? 1 : count,
                              (_) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                width: count >= 4 ? 14 : 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        Text(
          local.formatFullDate(selected),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Event'),
              onPressed: () => event(),
            ),
            ActionChip(
              label: const Text('Task'),
              onPressed: () => widget.addTask(selected),
            ),
            ActionChip(
              label: const Text('Work session'),
              onPressed: () => session(),
            ),
          ],
        ),
        if ((!showTasks || tasks.isEmpty && sessions.isEmpty) &&
            (!showEvents || events.isEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('Nothing planned for this day.'),
          ),
        if (showEvents)
          for (final e in events)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(e.title),
                subtitle: Text(
                  e.allDay
                      ? 'All day'
                      : '${TimeOfDay.fromDateTime(e.startsAt.toLocal()).format(context)} – ${TimeOfDay.fromDateTime(e.endsAt.toLocal()).format(context)}',
                ),
                onTap: () => event(e),
              ),
            ),
        if (showTasks) ...[
          for (final s in sessions)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(
                  controller.tasks
                          .where((t) => t.id == s.taskId)
                          .firstOrNull
                          ?.title ??
                      'Work session',
                ),
                subtitle: Text(
                  '${TimeOfDay.fromDateTime(s.startsAt.toLocal()).format(context)} · ${s.outcome.name}',
                ),
                onTap: () => session(s),
              ),
            ),
          for (final t in tasks)
            Card(
              child: ListTile(
                leading: const Icon(Icons.task_alt_outlined),
                title: Text(t.title),
                subtitle: const Text('Planned task'),
                onTap: () => widget.openTask(t),
              ),
            ),
        ],
      ],
    );
  }
}
