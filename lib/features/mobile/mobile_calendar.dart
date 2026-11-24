import 'dart:async';

import '../shared/scroll_edge_fade.dart';
import '../shared/item_filters.dart';
import '../shared/status_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../calendar/calendar_presentation.dart';
import '../calendar/event_editor.dart';
import '../shared/app_section_heading.dart';
import '../calendar/session_editor.dart';
import '../shared/app_spacing.dart';
import '../shared/icon_picker.dart';

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
    this.onEditorClosed,
    this.clock = DateTime.now,
    this.showFilters = true,
  });
  final ValueChanged<LifeTask> openTask;
  final ValueChanged<DateTime> addTask;
  final DateTime? initialDay;
  final Future<void> Function()? onEditorClosed;
  final DateTime Function() clock;
  final bool showFilters;
  @override
  ConsumerState<MobileCalendar> createState() => _MobileCalendarState();
}

class _MobileCalendarState extends ConsumerState<MobileCalendar>
    with WidgetsBindingObserver {
  late DateTime selected;
  late bool followingToday;
  Timer? dayRefresh;
  String mode = 'month';

  @override
  void initState() {
    super.initState();
    final today = widget.clock();
    selected = DateUtils.dateOnly(widget.initialDay ?? today);
    followingToday =
        widget.initialDay == null ||
        DateUtils.isSameDay(widget.initialDay, today);
    WidgetsBinding.instance.addObserver(this);
    scheduleDayRefresh();
    final controller = ref.read(appControllerProvider);
    mode =
        controller.lastCalendarMode ??
        controller.customization.calendarDefaultView;
    if (widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) move(0);
      });
    }
  }

  @override
  void dispose() {
    dayRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    dayRefresh?.cancel();
    if (state == AppLifecycleState.resumed) {
      refreshDay();
      scheduleDayRefresh();
    }
  }

  void refreshDay() {
    final today = DateUtils.dateOnly(widget.clock());
    final changed = followingToday && !DateUtils.isSameDay(selected, today);
    // Browsing stays put, but Today's indicator must still move on rollover.
    setState(() {
      if (followingToday) selected = today;
    });
    if (changed) unawaited(move(0));
  }

  void scheduleDayRefresh() {
    dayRefresh?.cancel();
    final now = widget.clock();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    dayRefresh = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      refreshDay();
      scheduleDayRefresh();
    });
  }

  void changeMode(String value) {
    setState(() => mode = value);
    ref.read(appControllerProvider).setLastCalendarMode(value);
  }

  void returnToToday() {
    setState(() {
      selected = DateUtils.dateOnly(widget.clock());
      followingToday = true;
    });
    unawaited(move(0));
  }

  Future<void> pickDay() async {
    final day = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    setState(() {
      selected = day;
      followingToday = DateUtils.isSameDay(day, widget.clock());
    });
    await move(0);
  }

  Future<void> move(int delta) async {
    setState(() {
      if (delta != 0) {
        followingToday = false;
      }
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
        showTransientStatus(context, '$error', type: NotificationType.error);
      }
    }
  }

  Future<void> event([FixedEvent? value]) async {
    await openMobileEditor(
      context,
      (route) => EventEditor(
        protectUnsavedEdits: true,
        event: value,
        initialDay: selected,
        onClose: () => Navigator.pop(route),
      ),
    );
    if (mounted) await widget.onEditorClosed?.call();
  }

  Future<void> session([WorkSession? value]) async {
    await openMobileEditor(
      context,
      (route) => SessionEditor(
        protectUnsavedEdits: true,
        session: value,
        initialDay: selected,
        onClose: () => Navigator.pop(route),
      ),
    );
    if (mounted) await widget.onEditorClosed?.call();
  }

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
    List<FixedEvent> eventsOn(DateTime d) => controller.filteredEvents
        .where(
          (e) =>
              !e.cancelled &&
              e.startsAt.toLocal().isBefore(
                DateTime(d.year, d.month, d.day + 1),
              ) &&
              e.endsAt.toLocal().isAfter(d),
        )
        .toList();
    final tasks = controller.filteredTasks
        .where((t) => t.scheduledDate == dayKey)
        .toList();
    final sessions =
        controller.filteredSessions
            .where((s) => localDate(s.startsAt.toLocal()) == dayKey)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final events = eventsOn(selected)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final showTasks = controller.calendarContent != CalendarContent.eventsOnly;
    final showEvents = controller.calendarContent != CalendarContent.tasksOnly;
    return FadingListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.content,
        AppSpacing.gap,
        AppSpacing.content,
        AppSpacing.section,
      ),
      children: [
        if (widget.showFilters) ...[
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: ItemFilters(),
          ),
          const SizedBox(height: AppSpacing.gap),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <
                280 * MediaQuery.textScalerOf(context).scale(1)) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in [
                    ('day', 'Day'),
                    ('week', 'Week'),
                    ('month', 'Month'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: mode == value,
                      side: BorderSide.none,
                      backgroundColor: scheme.surfaceContainerHigh,
                      selectedColor: scheme.primaryContainer,
                      onSelected: (_) => changeMode(value),
                    ),
                ],
              );
            }
            return SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'day', label: Text('Day')),
                ButtonSegment(value: 'week', label: Text('Week')),
                ButtonSegment(value: 'month', label: Text('Month')),
              ],
              selected: {mode},
              onSelectionChanged: (value) => changeMode(value.first),
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final date = calendarPeriodLabel(
              local,
              selected,
              weekStart: mode == 'week' ? first : null,
              month: mode == 'month',
            );
            final title = Tooltip(
              message: 'Choose date',
              child: TextButton(
                onPressed: pickDay,
                child: Text(
                  mode == 'day' && DateUtils.isSameDay(selected, widget.clock())
                      ? 'Today · $date'
                      : date,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            );
            final previous = IconButton(
              tooltip: 'Previous $mode',
              onPressed: () => move(-1),
              icon: const Icon(Icons.chevron_left),
            );
            final next = IconButton(
              tooltip: 'Next $mode',
              onPressed: () => move(1),
              icon: const Icon(Icons.chevron_right),
            );
            final today = IconButton(
              tooltip: 'Today',
              style: DateUtils.isSameDay(selected, widget.clock())
                  ? null
                  : IconButton.styleFrom(
                      foregroundColor: scheme.primary,
                      backgroundColor: scheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                    ),
              onPressed: returnToToday,
              icon: const Icon(Icons.today),
            );
            if (constraints.maxWidth <
                250 * MediaQuery.textScalerOf(context).scale(1)) {
              return Column(
                children: [
                  title,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [previous, next, today],
                  ),
                ],
              );
            }
            return Row(
              children: [
                previous,
                Expanded(child: title),
                next,
                today,
              ],
            );
          },
        ),
        if (mode != 'day') ...[
          const Divider(height: AppSpacing.related),
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
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent:
                  (MediaQuery.textScalerOf(context).scale(25) + AppSpacing.gap)
                      .clamp(AppLayout.minTapTarget, double.infinity),
            ),
            itemBuilder: (context, i) {
              final date = DateTime(
                first.year,
                first.month,
                first.day + i - (mode == 'week' ? 0 : offset),
              );
              final key = localDate(date);
              final eventCount = showEvents ? eventsOn(date).length : 0;
              final daySessions = showTasks
                  ? controller.filteredSessions
                        .where((s) => localDate(s.startsAt.toLocal()) == key)
                        .toList()
                  : <WorkSession>[];
              // A task with a session on this day is represented by its session;
              // do not present its plan as a second calendar commitment.
              final taskCount = showTasks
                  ? controller.filteredTasks
                        .where(
                          (t) =>
                              t.scheduledDate == key &&
                              !daySessions.any((s) => s.taskId == t.id),
                        )
                        .length
                  : 0;
              final count = eventCount + taskCount + daySessions.length;
              final isToday = DateUtils.isSameDay(date, widget.clock());
              final isSelected = key == dayKey;
              return Semantics(
                selected: isSelected,
                label:
                    '${isToday ? 'Today, ' : ''}${local.formatFullDate(date)}, $eventCount events, $taskCount planned tasks, ${daySessions.length} sessions',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  onTap: () => setState(() {
                    selected = date;
                    followingToday = isToday;
                  }),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected ? scheme.primaryContainer : null,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: isToday
                          ? Border.all(color: scheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          maxLines: 1,
                          softWrap: false,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : null,
                                color: isSelected
                                    ? scheme.onPrimaryContainer
                                    : date.month != selected.month
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
        const Divider(height: AppSpacing.section),
        if (mode != 'day')
          LayoutBuilder(
            builder: (context, constraints) {
              final isToday = DateUtils.isSameDay(selected, widget.clock());
              final title = Semantics(
                header: true,
                child: Text(
                  isToday
                      ? 'Today \u00b7 ${local.formatFullDate(selected)}'
                      : local.formatFullDate(selected),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
              if (isToday) return title;
              final back = TextButton.icon(
                icon: const Icon(Icons.today, size: 16),
                label: const Text('Back to today'),
                onPressed: returnToToday,
              );
              if (constraints.maxWidth <
                  350 * MediaQuery.textScalerOf(context).scale(1)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: back,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  back,
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: AppSpacing.gap,
          runSpacing: AppSpacing.gap,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.outline
                        .withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No commitments for this day',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use the action buttons above to schedule an event or task.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showEvents && events.isNotEmpty) ...[
          const AppSectionHeading('Events'),
          for (final e in events)
            ListTile(
              leading: _eventIcon(e, controller),
              title: Text(e.title),
              subtitle: Text(_eventTimeLabel(e)),
              onTap: () => event(e),
            ),
        ],
        if (showTasks && sessions.isNotEmpty) ...[
          const AppSectionHeading('Work sessions'),
          for (final s in sessions)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                controller.filteredTasks
                        .where((t) => t.id == s.taskId)
                        .firstOrNull
                        ?.title ??
                    'Work session',
              ),
              subtitle: Text(
                '${calendarTimeLabel(context, s.startsAt.toLocal())} · ${s.outcome.name}',
              ),
              onTap: () => session(s),
            ),
        ],
        if (showTasks && tasks.isNotEmpty) ...[
          const AppSectionHeading('Planned tasks'),
          for (final t in tasks)
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: Text(t.title),
              onTap: () => widget.openTask(t),
            ),
        ],
      ],
    );
  }

  String _eventTimeLabel(FixedEvent event) {
    if (event.allDay) return 'All day';
    final start = event.startsAt.toLocal(), end = event.endsAt.toLocal();
    if (start.isBefore(DateUtils.dateOnly(selected))) {
      return localDate(end) == localDate(selected)
          ? 'Continues until ${calendarTimeLabel(context, end)}'
          : 'Continues';
    }
    return '${calendarTimeLabel(context, start)} – ${calendarTimeLabel(context, end)}';
  }

  Widget _eventIcon(FixedEvent event, AppController controller) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(
      controller.effectiveEventColor(event) ?? scheme.primary.toARGB32(),
    );
    final surface = scheme.surfaceContainerLow;
    final luminance = color.computeLuminance();
    final backgroundLuminance = surface.computeLuminance();
    final contrast = (luminance > backgroundLuminance)
        ? (luminance + .05) / (backgroundLuminance + .05)
        : (backgroundLuminance + .05) / (luminance + .05);
    // Keep the configured accent visible while giving low-contrast icons a
    // legible foreground on the agenda surface.
    final foreground = contrast >= 3 ? color : scheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gap),
        child: Icon(
          iconForKey(event.iconName, Icons.event_outlined),
          color: foreground,
        ),
      ),
    );
  }
}
