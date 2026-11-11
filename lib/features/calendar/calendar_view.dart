import '../../domain/alarm_plan.dart';
import '../shared/alarm_indicator.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';
import '../shared/item_filters.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import 'event_editor.dart';
import 'calendar_config.dart';
import 'calendar_day_view.dart';
import 'calendar_interaction_controller.dart';
import 'calendar_models.dart';
import 'calendar_month_view.dart';
import 'calendar_week_view.dart';
import 'calendar_zoom_controller.dart';
import '../shared/icon_picker.dart';
import '../shared/about_view_button.dart';
import '../shared/settings_history_scope.dart';
import '../shared/weekdays.dart';
import 'session_editor.dart';

enum CalendarMode { day, week, month }

int monthEntryCapacity(double cellHeight, double textScale) {
  final rowHeight = 32.0 * textScale.clamp(1.0, 2.0);
  return ((cellHeight - 34) / rowHeight).floor().clamp(0, 30);
}

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({
    super.key,
    this.initialDate,
    required this.onTaskTap,
    required this.onSmartReschedule,
    required this.onAddTask,
  });
  final DateTime? initialDate;
  final void Function(LifeTask task) onTaskTap;
  final VoidCallback onSmartReschedule;
  final void Function(DateTime date) onAddTask;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime selected = DateTime.now();
  CalendarMode mode = CalendarMode.week;
  final CalendarAppearanceConfiguration _config =
      const CalendarAppearanceConfiguration();
  late final CalendarInteractionController _interactionController =
      CalendarInteractionController(config: _config);
  late final CalendarZoomController _zoomController =
      CalendarZoomController(config: _config);
  bool _useLegacy = false;

  @override
  void dispose() {
    _interactionController.removeListener(_onInteractionChanged);
    _interactionController.dispose();
    super.dispose();
  }

  void _onInteractionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _interactionController.addListener(_onInteractionChanged);
    selected = widget.initialDate ?? selected;
    final controller = ref.read(appControllerProvider);
    mode = CalendarMode.values.byName(
      controller.lastCalendarMode ??
          controller.customization.calendarDefaultView,
    );
  }

  DateTime get day => DateTime(selected.year, selected.month, selected.day);
  DateTime get weekStart {
    final first = ref.read(appControllerProvider).firstWeekday;
    return DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - first + 7) % 7,
    );
  }

  void _setMode(CalendarMode value) {
    setState(() => mode = value);
    ref.read(appControllerProvider).setLastCalendarMode(value.name);
  }

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
      animationStyle: AppMotion.style(context),
      builder: (context) => Dialog(
        child: SizedBox(
          width: 500,
          height: (MediaQuery.sizeOf(context).height - 48).clamp(0.0, 650.0),
          child: EventEditor(
            protectUnsavedEdits: true,
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

  Future<void> _showDayPreview(DateTime date) async {
    final size = MediaQuery.sizeOf(context);
    final entries = _entries(ref.read(appControllerProvider), date);
    final previewHeight = (132.0 + entries.length * 58.0)
        .clamp(160.0, 440.0)
        .clamp(0.0, size.height - 16);
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (popupContext) => Dialog(
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
                child: FadingListView(
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
                            : entry.event != null &&
                                  entry.event!.details.isNotEmpty
                            ? Text(
                                entry.event!.details
                                    .map(
                                      (item) => '${item.label}: ${item.value}',
                                    )
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
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
                      ref
                          .read(appControllerProvider)
                          .setLastCalendarMode('day');
                    },
                    child: const Text('Open Day View'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editSession([WorkSession? session]) async {
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => Dialog(
        child: SizedBox(
          width: 460,
          height: 550,
          child: SessionEditor(
            protectUnsavedEdits: true,
            session: session,
            initialDay: day,
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Future<void> _undo() async {
    final message = await _interactionController.undo(ref.read(appControllerProvider));
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: _interactionController.canRedo
              ? SnackBarAction(
                  label: 'Redo',
                  onPressed: _redo,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _redo() async {
    final message = await _interactionController.redo(ref.read(appControllerProvider));
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: _interactionController.canUndo
              ? SnackBarAction(
                  label: 'Undo',
                  onPressed: _undo,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _handleInteractionFinished() async {
    final appCtrl = ref.read(appControllerProvider);
    final summary = await _interactionController.commit(appCtrl);
    if (summary != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: _undo,
          ),
        ),
      );
    }
  }

  Future<void> _handleMonthItemDropped(CalendarItem item, DateTime targetDate) async {
    final originDate = item.startsAt ??
        (item.task?.scheduledDate != null
            ? DateTime.tryParse(item.task!.scheduledDate!)
            : null) ??
        targetDate;

    _interactionController.startDateDrag(
      item: item,
      originDate: originDate,
    );
    _interactionController.updatePointer(Offset.zero, targetDate);
    await _handleInteractionFinished();
  }

  void _handleCalendarItemTap(CalendarItem item) {
    if (item.event != null) {
      _editEvent(item.event);
    } else if (item.session != null) {
      _editSession(item.session);
    } else if (item.task != null) {
      widget.onTaskTap(item.task!);
    }
  }

  List<CalendarItem> _buildCalendarItems(AppController controller, DateTime date) {
    final key = localDate(date);
    final items = <CalendarItem>[];

    if (controller.calendarContent != CalendarContent.tasksOnly) {
      for (final event in controller.filteredEvents) {
        final start = event.startsAt.toLocal();
        final end = event.endsAt.toLocal();
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = DateTime(date.year, date.month, date.day + 1);

        if (start.isBefore(dayEnd) && end.isAfter(dayStart)) {
          final detailsStr = event.details.isNotEmpty
              ? event.details.map((d) => '${d.label}: ${d.value}').join(' · ')
              : (event.location.isNotEmpty ? event.location : null);
          items.add(
            CalendarItem(
              id: event.id,
              title: event.title,
              kind: CalendarItemKind.event,
              startsAt: start,
              endsAt: end,
              allDay: event.allDay,
              event: event,
              colorValue: controller.effectiveEventColor(event),
              iconName: event.iconName,
              isCancelled: event.cancelled,
              detailsText: detailsStr,
            ),
          );
        }
      }
    }

    if (controller.calendarContent != CalendarContent.eventsOnly) {
      for (final task in controller.filteredTasks) {
        final parentId = controller.taskParents[task.id];
        final parent = controller.tasks
            .where((item) => item.id == parentId)
            .firstOrNull;
        final parentTitle = parent?.title;

        if (task.scheduledDate == key) {
          items.add(
            CalendarItem(
              id: task.id,
              title: task.title,
              kind: CalendarItemKind.task,
              task: task,
              parentTitle: parentTitle,
              subtitle: 'Plan',
            ),
          );
        }
        if (task.deadlineDate == key && task.scheduledDate != key) {
          items.add(
            CalendarItem(
              id: task.id,
              title: task.title,
              kind: CalendarItemKind.task,
              task: task,
              parentTitle: parentTitle,
              subtitle: 'Deadline',
            ),
          );
        }
      }

      for (final session in controller.filteredSessions) {
        final start = session.startsAt.toLocal();
        final end = session.endsAt.toLocal();
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = DateTime(date.year, date.month, date.day + 1);

        if (start.isBefore(dayEnd) && end.isAfter(dayStart)) {
          final task = controller.tasks
              .where((item) => item.id == session.taskId)
              .firstOrNull;
          items.add(
            CalendarItem(
              id: session.id,
              title: task?.title ?? 'Work session',
              kind: CalendarItemKind.session,
              startsAt: start,
              endsAt: end,
              session: session,
              subtitle: session.outcome.name,
            ),
          );
        }
      }
    }

    return items;
  }

  Map<DateTime, List<CalendarItem>> _buildWeekItemsByDay(AppController controller) {
    final map = <DateTime, List<CalendarItem>>{};
    for (var i = 0; i < 7; i++) {
      final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      map[d] = _buildCalendarItems(controller, d);
    }
    return map;
  }

  Map<DateTime, List<CalendarItem>> _buildMonthItemsByDay(AppController controller) {
    final map = <DateTime, List<CalendarItem>>{};
    final first = DateTime(day.year, day.month);
    final offset = (first.weekday - ref.read(appControllerProvider).firstWeekday + 7) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(day.year, day.month);
    final cellCount = ((offset + daysInMonth + 6) ~/ 7) * 7;

    for (var i = 0; i < cellCount; i++) {
      final d = DateTime(first.year, first.month, first.day + i - offset);
      map[d] = _buildCalendarItems(controller, d);
    }
    return map;
  }

  DateTime _resolveAnchorDate(Offset localPosition, Size viewSize) {
    if (mode == CalendarMode.day) {
      return day;
    } else if (mode == CalendarMode.week) {
      return _zoomController.resolveWeekAnchorDate(
        localX: (localPosition.dx - 48.0).clamp(0.0, viewSize.width),
        totalWidth: viewSize.width - 48.0,
        weekStart: weekStart,
      );
    } else {
      return _zoomController.resolveMonthAnchorDate(
        localX: localPosition.dx.clamp(0.0, viewSize.width),
        localY: (localPosition.dy - 30.0).clamp(0.0, viewSize.height),
        gridWidth: viewSize.width,
        gridHeight: (viewSize.height - 30.0).clamp(1.0, double.infinity),
        monthDate: day,
        firstWeekday: ref.read(appControllerProvider).firstWeekday,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            _setMode(CalendarMode.day),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            _setMode(CalendarMode.week),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            _setMode(CalendarMode.month),
        const SingleActivator(LogicalKeyboardKey.keyT): () {
          setState(() => selected = DateTime.now());
          _loadSelectedMonth();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _interactionController.cancel();
        },
      },
      child: SettingsHistoryScope(
        undo: _undo,
        redo: _redo,
        child: Column(
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
              const AboutViewButton(
                description: 'See planned tasks, fixed events, and work sessions by day, week, or month. Move between dates and open an item to inspect or edit it.',
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() => selected = DateTime.now());
                  _loadSelectedMonth();
                },
                child: const Text('Today'),
              ),
              const ItemFilters(),
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
              SizedBox(
                width: 240 * MediaQuery.textScalerOf(context).scale(16) / 16,
                child: Text(
                  key: const ValueKey('calendar-period-label'),
                  _periodLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SegmentedButton<CalendarMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: CalendarMode.day,
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48),
                      child: const Center(child: Text('Day')),
                    ),
                  ),
                  ButtonSegment(
                    value: CalendarMode.week,
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48),
                      child: const Center(child: Text('Week')),
                    ),
                  ),
                  ButtonSegment(
                    value: CalendarMode.month,
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48),
                      child: const Center(child: Text('Month')),
                    ),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (value) => _setMode(value.first),
              ),
              SegmentedButton<CalendarContent>(
                showSelectedIcon: false,
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
              IconButton(
                tooltip: 'Undo calendar change (Ctrl+Z)',
                onPressed: _interactionController.canUndo ? _undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo calendar change (Ctrl+Shift+Z)',
                onPressed: _interactionController.canRedo ? _redo : null,
                icon: const Icon(Icons.redo),
              ),
              IconButton(
                tooltip: _useLegacy
                    ? 'Switch to interactive timeline'
                    : 'Switch to legacy calendar presentation',
                icon: Icon(
                  _useLegacy
                      ? Icons.view_timeline
                      : Icons.view_timeline_outlined,
                ),
                onPressed: () => setState(() => _useLegacy = !_useLegacy),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bodySize = Size(constraints.maxWidth, constraints.maxHeight);
              return Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final isCtrl = HardwareKeyboard.instance.isControlPressed;
                    if (isCtrl) {
                      final targetMode = _zoomController.handlePointerScroll(
                        scrollDeltaY: pointerSignal.scrollDelta.dy,
                        currentMode: mode,
                        isControlPressed: true,
                      );
                      if (targetMode != null && targetMode != mode) {
                        final anchorDate = _resolveAnchorDate(
                          pointerSignal.localPosition,
                          bodySize,
                        );
                        setState(() {
                          selected = anchorDate;
                          mode = targetMode;
                        });
                        ref
                            .read(appControllerProvider)
                            .setLastCalendarMode(targetMode.name);
                        _loadSelectedMonth();
                      }
                    }
                  }
                },
                child: _useLegacy
                    ? switch (mode) {
                        CalendarMode.day => _dayList(controller, day),
                        CalendarMode.week => _weekGrid(controller),
                        CalendarMode.month => _monthGrid(controller),
                      }
                    : switch (mode) {
                        CalendarMode.day => CalendarDayView(
                            dayDate: day,
                            items: _buildCalendarItems(controller, day),
                            config: _config,
                            interactionController: _interactionController,
                            onItemTap: _handleCalendarItemTap,
                            onSlotSecondaryTap: _showCreateMenu,
                            alarmRules: controller.alarmRules,
                            onInteractionFinished: _handleInteractionFinished,
                          ),
                        CalendarMode.week => CalendarWeekView(
                            weekStart: weekStart,
                            itemsByDay: _buildWeekItemsByDay(controller),
                            config: _config,
                            interactionController: _interactionController,
                            onItemTap: _handleCalendarItemTap,
                            onSlotSecondaryTap: _showCreateMenu,
                            onDayHeaderTap: (date) {
                              setState(() {
                                selected = date;
                                mode = CalendarMode.day;
                              });
                              ref
                                  .read(appControllerProvider)
                                  .setLastCalendarMode('day');
                            },
                            alarmRules: controller.alarmRules,
                            onInteractionFinished: _handleInteractionFinished,
                          ),
                        CalendarMode.month => CalendarMonthView(
                            selectedDate: day,
                            firstWeekday:
                                ref.read(appControllerProvider).firstWeekday,
                            itemsByDay: _buildMonthItemsByDay(controller),
                            config: _config,
                            onItemTap: _handleCalendarItemTap,
                            onDayTap: _showDayPreview,
                            onItemDroppedOnDate: _handleMonthItemDropped,
                            onShowDay: (date) {
                              setState(() {
                                selected = date;
                                mode = CalendarMode.day;
                              });
                              ref
                                  .read(appControllerProvider)
                                  .setLastCalendarMode('day');
                            },
                            onShowWeek: (date) {
                              setState(() {
                                selected = date;
                                mode = CalendarMode.week;
                              });
                              ref
                                  .read(appControllerProvider)
                                  .setLastCalendarMode('week');
                            },
                            onAddEvent: (date) => _editEvent(null, date),
                            onAddTask: widget.onAddTask,
                            onAddSession: (date) => _editSession(),
                          ),
                      },
              );
            },
          ),
        ),
      ],
    ),
  ),
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
    return FadingListView(
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
      if (bounds.maxWidth <
          650 * MediaQuery.textScalerOf(context).scale(14) / 14) {
        return FadingListView(
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
                  child: InkWell(
                    onTap: () => _showDayPreview(date),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Text(
                        '${weekdayNames[date.weekday - 1]} ${localDate(date)}',
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
              onTap: () => _showDayPreview(date),
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
                      onTap: () => _showDayPreview(date),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: localDate(date) == localDate(DateTime.now())
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.55)
                            : null,
                        child: Text(
                          '${weekdayNames[date.weekday - 1]} ${date.day}',
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
                      child: FadingListView(
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
    final offset =
        (first.weekday - ref.read(appControllerProvider).firstWeekday + 7) % 7;
    final days = DateUtils.getDaysInMonth(day.year, day.month);
    final cellCount = ((offset + days + 6) ~/ 7) * 7;
    return LayoutBuilder(
      builder: (context, bounds) {
        final rows = cellCount ~/ 7;
        final cellHeight = (bounds.maxHeight - 62) / rows;
        final previewCount = monthEntryCapacity(
          cellHeight,
          MediaQuery.textScalerOf(context).scale(1),
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  for (final weekday in weekdaysFrom(
                    ref.read(appControllerProvider).firstWeekday,
                  ))
                    Expanded(
                      child: Text(
                        weekdayNames[weekday - 1],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
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
                      onTap: () => _showDayPreview(date),
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
                                onPressed: () => _showDayPreview(date),
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
              ),
            ),
          ],
        );
      },
    );
  }

  List<_CalendarEntry> _entries(AppController controller, DateTime date) {
    final key = localDate(date);
    final list = <_CalendarEntry>[];
    if (controller.calendarContent != CalendarContent.tasksOnly) {
      for (final event in controller.filteredEvents) {
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
              timeLabel: event.allDay ? 'All day' : time,
            ),
          );
        }
      }
    }
    if (controller.calendarContent != CalendarContent.eventsOnly) {
      for (final task in controller.filteredTasks) {
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
      for (final session in controller.filteredSessions) {
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
    final eventColor = event == null
        ? null
        : ref.read(appControllerProvider).effectiveEventColor(event);
    final accent = eventColor == null ? scheme.primary : Color(eventColor);
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
                      event.cancelled ? 0.12 : 0.17,
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
                                ? Color.lerp(
                                    scheme.onSurfaceVariant,
                                    scheme.onSurface,
                                    0.45,
                                  )
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
    final eventColor = event == null
        ? null
        : ref.read(appControllerProvider).effectiveEventColor(event);
    final accent = eventColor == null ? scheme.primary : Color(eventColor);
    return Card(
      color: event == null
          ? null
          : Color.lerp(scheme.surface, accent, event.cancelled ? 0.12 : 0.17),
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
                  color: accent,
                ),
                if (event != null &&
                    !event.cancelled &&
                    eventAlarmRule(
                          event,
                          ref.read(appControllerProvider).alarmRules,
                        )?.config.enabled ==
                        true)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: AlarmIndicator(),
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
                                    ? Color.lerp(
                                        scheme.onSurfaceVariant,
                                        scheme.onSurface,
                                        0.45,
                                      )
                                    : scheme.onSurface,
                                decoration: event.cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              '${entry.timeLabel}${event.cancelled ? ' · Cancelled' : ''}',
                              style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (!compact && event.details.isNotEmpty)
                              Text(
                                event.details
                                    .map(
                                      (item) => '${item.label}: ${item.value}',
                                    )
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
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
    final sessions = controller.filteredSessions
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
    this.timeLabel = '',
  });
  final String label;
  final FixedEvent? event;
  final LifeTask? task;
  final WorkSession? session;
  final String? parentTitle;
  final String timeLabel;
}

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
