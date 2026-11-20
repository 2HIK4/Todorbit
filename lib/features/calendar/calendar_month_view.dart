import 'package:flutter/material.dart';
import '../shared/weekdays.dart';
import 'calendar_config.dart';
import 'calendar_models.dart';
import 'calendar_contracts.dart';

/// Interactive Month view supporting drag-and-drop between date cells and extended context actions.
class CalendarMonthView extends StatefulWidget {
  const CalendarMonthView({
    super.key,
    required this.selectedDate,
    required this.firstWeekday,
    required this.itemsByDay,
    required this.config,
    required this.onItemTap,
    required this.onDayTap,
    required this.onItemDroppedOnDate,
    required this.onShowDay,
    required this.onShowWeek,
    required this.onAddEvent,
    required this.onAddTask,
    required this.onAddSession,
    this.colorResolver,
  });

  final DateTime selectedDate;
  final int firstWeekday;
  final Map<DateTime, List<CalendarItem>> itemsByDay;
  final CalendarAppearanceConfiguration config;
  final void Function(CalendarItem item) onItemTap;
  final void Function(DateTime date) onDayTap;
  final void Function(CalendarItem item, DateTime targetDate) onItemDroppedOnDate;
  final void Function(DateTime date) onShowDay;
  final void Function(DateTime date) onShowWeek;
  final void Function(DateTime date) onAddEvent;
  final void Function(DateTime date) onAddTask;
  final void Function(DateTime date) onAddSession;
  final Color Function(CalendarItem item)? colorResolver;

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  DateTime? _dragHoverDate;

  Future<void> _showContextMenu(DateTime date, Offset position) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'event', child: Text('Add Event')),
        PopupMenuItem(value: 'task', child: Text('Add Task')),
        PopupMenuItem(value: 'session', child: Text('Add Work Session')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'day', child: Text('Show Day')),
        PopupMenuItem(value: 'week', child: Text('Show Week')),
      ],
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'event':
        widget.onAddEvent(date);
        break;
      case 'task':
        widget.onAddTask(date);
        break;
      case 'session':
        widget.onAddSession(date);
        break;
      case 'day':
        widget.onShowDay(date);
        break;
      case 'week':
        widget.onShowWeek(date);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = widget.selectedDate;

    final first = DateTime(day.year, day.month);
    final offset = (first.weekday - widget.firstWeekday + 7) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(day.year, day.month);
    final cellCount = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final rowCount = cellCount ~/ 7;

    return LayoutBuilder(
      builder: (context, bounds) {
        final rawCellHeight = (bounds.maxHeight - 40) / rowCount;
        final cellHeight = rawCellHeight.clamp(90.0, double.infinity);
        final isOverflowing = (cellHeight * rowCount) > (bounds.maxHeight - 40);
        final cellWidth = ((bounds.maxWidth - 20) / 7).clamp(30.0, double.infinity);
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final previewCount = monthEntryCapacity(
          cellHeight,
          textScale,
        );

        return Column(
          children: [
            // Weekday label headers
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Row(
                children: [
                  for (final weekday in weekdaysFrom(widget.firstWeekday))
                    Expanded(
                      child: Text(
                        weekdayNames[weekday - 1],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 7xN Calendar grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                physics: isOverflowing
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: cellHeight,
                ),
                itemCount: cellCount,
                itemBuilder: (context, index) {
                  final date = DateTime(
                    first.year,
                    first.month,
                    first.day + index - offset,
                  );
                  final inMonth = date.month == day.month;
                  final isToday = _isSameDay(date, DateTime.now());
                  final isSelected = _isSameDay(date, widget.selectedDate);
                  final isHoverTarget = _dragHoverDate != null && _isSameDay(date, _dragHoverDate!);
                  final items = widget.itemsByDay[date] ?? const [];

                  return DragTarget<CalendarItem>(
                    onWillAcceptWithDetails: (details) {
                      setState(() => _dragHoverDate = date);
                      return true;
                    },
                    onLeave: (_) {
                      setState(() => _dragHoverDate = null);
                    },
                    onAcceptWithDetails: (details) {
                      setState(() => _dragHoverDate = null);
                      widget.onItemDroppedOnDate(details.data, date);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        onSecondaryTapDown: (details) =>
                            _showContextMenu(date, details.globalPosition),
                        onLongPressStart: (details) =>
                            _showContextMenu(date, details.globalPosition),
                        child: InkWell(
                          onTap: () => widget.onDayTap(date),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(2),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isHoverTarget
                                  ? scheme.primaryContainer.withValues(alpha: 0.45)
                                  : isToday
                                  ? scheme.primaryContainer.withValues(alpha: 0.3)
                                  : scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isHoverTarget
                                    ? scheme.primary
                                    : isSelected
                                    ? scheme.primary
                                    : scheme.outlineVariant.withValues(alpha: 0.25),
                                width: (isHoverTarget || isSelected) ? 1.5 : 1.0,
                              ),
                            ),
                            child: Builder(
                              builder: (context) {
                                final visibleLimit = previewCount.clamp(1, 30);
                                final showOverflow = items.length > visibleLimit;
                                final visibleCount = showOverflow
                                    ? (visibleLimit > 1 ? visibleLimit - 1 : 1)
                                    : items.length;
                                final overflowCount = items.length - visibleCount;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: inMonth
                                                ? (isToday ? scheme.primary : scheme.onSurface)
                                                : scheme.outline,
                                          ),
                                        ),
                                        if (isToday)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Expanded(
                                      child: ListView(
                                        physics: const NeverScrollableScrollPhysics(),
                                        children: [
                                          for (final item in items.take(visibleCount))
                                            _buildMonthItem(item, scheme, date, cellWidth),
                                          if (showOverflow && overflowCount > 0)
                                            InkWell(
                                              onTap: () => widget.onDayTap(date),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                                child: Text(
                                                  cellWidth < 75 ? '+$overflowCount' : '+$overflowCount more',
                                                  style: TextStyle(
                                                    fontSize: cellWidth < 75 ? 9.5 : 10.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: scheme.primary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthItem(
    CalendarItem item,
    ColorScheme scheme,
    DateTime date,
    double cellWidth,
  ) {
    final accent = widget.colorResolver != null
        ? widget.colorResolver!(item)
        : (item.colorValue != null ? Color(item.colorValue!) : scheme.primary);

    final hasParent = item.parentTitle != null;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isNarrow = cellWidth < 85;
    final isVeryNarrow = cellWidth < 68;
    final cardHeight = (hasParent && !isNarrow ? 34.0 : 26.0) * textScale.clamp(1.0, 1.4);

    final itemWidget = Tooltip(
      message: '${item.title}${item.parentTitle != null ? ' (${item.parentTitle})' : ''}',
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        width: double.infinity,
        height: cardHeight,
        margin: const EdgeInsets.only(bottom: 2),
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 3 : 6,
          vertical: 1.5,
        ),
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, accent, item.isCancelled ? 0.12 : 0.18),
          border: Border(
            left: BorderSide(
              color: accent,
              width: isNarrow ? 2.5 : 3.0,
            ),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            if (!isVeryNarrow) ...[
              Icon(
                item.kind == CalendarItemKind.event
                    ? Icons.event_outlined
                    : item.kind == CalendarItemKind.session
                    ? Icons.schedule_outlined
                    : Icons.task_alt_outlined,
                size: isNarrow ? 10 : 12,
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(width: isNarrow ? 2 : 4),
            ],
            Expanded(
              child: hasParent && !isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.parentTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isNarrow ? 10 : 11,
                        fontWeight: FontWeight.w500,
                        color: item.isCancelled ? scheme.outline : scheme.onSurface,
                        decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    final isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    final feedbackWidget = Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(4),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_indicator, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    final childWidget = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onItemTap(item),
      onSecondaryTapDown: (details) =>
          _showContextMenu(item.startsAt ?? date, details.globalPosition),
      child: itemWidget,
    );

    final draggableWidget = isMobile
        ? LongPressDraggable<CalendarItem>(
            data: item,
            delay: const Duration(milliseconds: 250),
            hapticFeedbackOnStart: true,
            hitTestBehavior: HitTestBehavior.opaque,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedbackWidget,
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: itemWidget,
            ),
            child: childWidget,
          )
        : Draggable<CalendarItem>(
            data: item,
            hitTestBehavior: HitTestBehavior.opaque,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedbackWidget,
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: itemWidget,
            ),
            child: childWidget,
          );

    return Tooltip(
      message: _buildTooltipMessage(item),
      child: draggableWidget,
    );
  }

  String _buildTooltipMessage(CalendarItem item) {
    final buffer = StringBuffer();
    if (item.isCancelled) buffer.write('Cancelled: ');
    if (item.parentTitle != null && item.parentTitle!.isNotEmpty) {
      buffer.write('${item.parentTitle} · ');
    }
    buffer.write(item.title);
    if (item.isTimed && item.startsAt != null && item.endsAt != null) {
      final startStr = _formatTime(item.startsAt!);
      final endStr = _formatTime(item.endsAt!);
      buffer.write('\n$startStr – $endStr');
    } else if (item.subtitle != null && item.subtitle!.isNotEmpty) {
      buffer.write('\n${item.subtitle}');
    }
    if (item.detailsText != null && item.detailsText!.isNotEmpty) {
      buffer.write('\n${item.detailsText}');
    }
    return buffer.toString();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
