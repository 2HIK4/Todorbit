import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/alarms.dart';
import '../shared/weekdays.dart';
import '../shared/app_spacing.dart';
import '../shared/icon_picker.dart';
import 'calendar_presentation.dart';
import 'calendar_config.dart';
import 'calendar_interaction_controller.dart';
import 'calendar_models.dart';
import 'timeline_grid.dart';

/// Full interactive Week time-grid featuring 7 synchronized day columns and cross-day dragging.
class CalendarWeekView extends StatefulWidget {
  const CalendarWeekView({
    super.key,
    required this.weekStart,
    this.selectedDate,
    required this.itemsByDay,
    required this.config,
    required this.interactionController,
    required this.onItemTap,
    required this.onSlotSecondaryTap,
    required this.onDayHeaderTap,
    this.alarmRules = const [],
    this.colorResolver,
    this.onInteractionFinished,
    this.onNavigateWeek,
  });

  final DateTime weekStart;
  final DateTime? selectedDate;
  final Map<DateTime, List<CalendarItem>> itemsByDay;
  final CalendarAppearanceConfiguration config;
  final CalendarInteractionController interactionController;
  final void Function(CalendarItem item) onItemTap;
  final void Function(DateTime slotTime, Offset globalPosition)
  onSlotSecondaryTap;
  final void Function(DateTime dayDate) onDayHeaderTap;
  final List<AlarmRule> alarmRules;
  final Color Function(CalendarItem item)? colorResolver;
  final Future<void> Function()? onInteractionFinished;
  final void Function(int direction)? onNavigateWeek;

  @override
  State<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends State<CalendarWeekView> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _gridHorizontalScrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  bool _isSyncingScroll = false;

  Timer? _edgeDwellTimer;
  int? _pendingDwellDirection;
  bool _hasNavigatedAtCurrentEdge = false;
  int? _navigatedDirection;
  String? _edgeDwellMessage;

  @override
  void initState() {
    super.initState();
    widget.interactionController.addListener(_handleInteractionChange);
    _headerScrollController.addListener(_syncHeaderToGrid);
    _gridHorizontalScrollController.addListener(_syncGridToHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollController.hasClients) {
        final initialY =
            widget.config.initialScrollHour * widget.config.hourHeight;
        _verticalScrollController.jumpTo(
          initialY.clamp(
            0.0,
            _verticalScrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _syncHeaderToGrid() {
    if (!_isSyncingScroll && _gridHorizontalScrollController.hasClients) {
      _isSyncingScroll = true;
      _gridHorizontalScrollController.jumpTo(_headerScrollController.offset);
      _isSyncingScroll = false;
    }
  }

  @override
  void didUpdateWidget(covariant CalendarWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart &&
        widget.interactionController.isDragging) {
      final forward = widget.weekStart.isAfter(oldWidget.weekStart);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _gridHorizontalScrollController.hasClients) {
          _gridHorizontalScrollController.jumpTo(
            forward
                ? 0
                : _gridHorizontalScrollController.position.maxScrollExtent,
          );
        }
      });
    }
    if (oldWidget.config.hourHeight != widget.config.hourHeight &&
        _verticalScrollController.hasClients) {
      final offset =
          _verticalScrollController.offset *
          widget.config.hourHeight /
          oldWidget.config.hourHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _verticalScrollController.hasClients) {
          _verticalScrollController.jumpTo(
            offset.clamp(
              0.0,
              _verticalScrollController.position.maxScrollExtent,
            ),
          );
        }
      });
    }
  }

  void _syncGridToHeader() {
    if (!_isSyncingScroll && _headerScrollController.hasClients) {
      _isSyncingScroll = true;
      _headerScrollController.jumpTo(_gridHorizontalScrollController.offset);
      _isSyncingScroll = false;
    }
  }

  @override
  void dispose() {
    widget.interactionController.removeListener(_handleInteractionChange);
    _edgeDwellTimer?.cancel();
    _headerScrollController.removeListener(_syncHeaderToGrid);
    _gridHorizontalScrollController.removeListener(_syncGridToHeader);
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    _gridHorizontalScrollController.dispose();
    super.dispose();
  }

  void _handleInteractionChange() {
    final interaction = widget.interactionController;
    if (!interaction.isDragging) {
      _cancelEdgeDwell();
      _hasNavigatedAtCurrentEdge = false;
      return;
    }
    final pointer = interaction.pointerCurrentLocal;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || box == null || !box.hasSize) return;
    final local = box.globalToLocal(pointer);
    _checkEdgeDwell(local.dx, box.size.width);
  }

  void _checkEdgeDwell(double localX, double totalGridWidth) {
    if (widget.onNavigateWeek == null ||
        !widget.interactionController.isDragging) {
      _cancelEdgeDwell();
      return;
    }
    const edgeThreshold = 36.0;
    final int direction;
    final scroll = _gridHorizontalScrollController.hasClients
        ? _gridHorizontalScrollController.position
        : null;
    final viewportX = localX - (scroll?.pixels ?? 0);
    final width = scroll?.viewportDimension ?? totalGridWidth;
    if (viewportX < -10 || viewportX > width + 10) {
      _cancelEdgeDwell();
      _hasNavigatedAtCurrentEdge = false;
      return;
    }
    if (viewportX >= width - edgeThreshold) {
      direction = 1;
    } else if (viewportX <= edgeThreshold) {
      direction = -1;
    } else {
      _cancelEdgeDwell();
      _hasNavigatedAtCurrentEdge = false;
      return;
    }

    if (_hasNavigatedAtCurrentEdge && _navigatedDirection == direction) {
      return;
    }

    if (_pendingDwellDirection == direction) {
      return;
    }

    _pendingDwellDirection = direction;
    if (mounted) {
      setState(() {
        final moreColumns =
            scroll != null &&
            (direction > 0 ? scroll.extentAfter : scroll.extentBefore) > 1;
        _edgeDwellMessage = moreColumns
            ? (direction > 0
                  ? 'Hold to scroll right →'
                  : '← Hold to scroll left')
            : (direction > 0
                  ? 'Hold to open next week →'
                  : '← Hold to open previous week');
      });
    }

    _edgeDwellTimer?.cancel();
    _edgeDwellTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !widget.interactionController.isDragging) return;
      _hasNavigatedAtCurrentEdge = true;
      _navigatedDirection = _pendingDwellDirection;
      final dir = _pendingDwellDirection;
      _cancelEdgeDwell();
      if (dir != null) {
        if (scroll != null &&
            (dir > 0 ? scroll.extentAfter : scroll.extentBefore) > 1) {
          _gridHorizontalScrollController.jumpTo(
            dir > 0 ? scroll.maxScrollExtent : scroll.minScrollExtent,
          );
        } else {
          widget.onNavigateWeek?.call(dir);
        }
      }
    });
  }

  void _cancelEdgeDwell() {
    _edgeDwellTimer?.cancel();
    _edgeDwellTimer = null;
    _pendingDwellDirection = null;
    if (_edgeDwellMessage != null && mounted) {
      setState(() {
        _edgeDwellMessage = null;
      });
    }
  }

  DateTime _resolveDayAt(
    Offset globalPosition,
    List<DateTime> days,
    double columnWidth,
  ) {
    final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return days.first;
    final local = renderBox.globalToLocal(globalPosition);
    final colIndex = (local.dx / columnWidth).floor().clamp(0, days.length - 1);
    if (colIndex < 0) {
      return DateTime(
        days.first.year,
        days.first.month,
        days.first.day + colIndex,
      );
    } else if (colIndex >= days.length) {
      return DateTime(
        days.last.year,
        days.last.month,
        days.last.day + (colIndex - (days.length - 1)),
      );
    }
    return days[colIndex];
  }

  List<DateTime> get _weekDays => List.generate(7, (index) {
    return DateTime(
      widget.weekStart.year,
      widget.weekStart.month,
      widget.weekStart.day + index,
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config = widget.config;
    final days = _weekDays;
    final today = DateTime.now();
    final untimedByDay = {
      for (final day in days)
        day: [
          for (final item in widget.itemsByDay[day] ?? const <CalendarItem>[])
            if (!item.isTimed) item,
        ],
    };
    final previewLines = untimedByDay.values.fold<int>(
      0,
      (visible, items) => math.max(visible, math.min(items.length, 2)),
    );
    final lineHeight = math.max(
      AppLayout.minTapTarget / 2,
      MediaQuery.textScalerOf(context).scale(14) + AppSpacing.gap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const timeGutterWidth = 48.0;
        final contentWidth = availableWidth - timeGutterWidth;

        // Ensure each day column is at least 95px wide for readability
        final columnWidth = math.max(contentWidth / 7.0, 95.0);
        final totalGridWidth = columnWidth * 7.0;
        final needsHorizontalScroll = totalGridWidth > contentWidth;

        return Column(
          children: [
            // 1. Week Day Headers row (synchronized horizontally)
            Row(
              children: [
                const SizedBox(width: timeGutterWidth),
                Expanded(
                  child: SingleChildScrollView(
                    controller: needsHorizontalScroll
                        ? _headerScrollController
                        : null,
                    scrollDirection: Axis.horizontal,
                    physics: needsHorizontalScroll
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalGridWidth,
                      child: Row(
                        children: [
                          for (final dayDate in days)
                            SizedBox(
                              width: columnWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildDayHeader(dayDate, today, scheme),
                                  if (previewLines != 0)
                                    SizedBox(
                                      height:
                                          lineHeight * previewLines +
                                          AppSpacing.small,
                                      child: ColoredBox(
                                        color: scheme.surfaceContainerLow,
                                        child: _buildUntimedPreview(
                                          dayDate,
                                          untimedByDay[dayDate]!,
                                          lineHeight,
                                        ),
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
              ],
            ),
            const Divider(height: 1),

            // 2. Timeline Grid with synchronized time gutter
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left shared time gutter
                    SizedBox(
                      width: timeGutterWidth,
                      height: config.totalGridHeight,
                      child: Stack(
                        children: [
                          for (
                            var hour = config.startHour;
                            hour < config.endHour;
                            hour++
                          )
                            Positioned(
                              top:
                                  (hour - config.startHour) *
                                      config.hourHeight +
                                  AppSpacing.small,
                              left: 4,
                              right: 6,
                              child: CalendarHourLabel(hour),
                            ),
                        ],
                      ),
                    ),

                    // Vertical separator between gutter and columns
                    Container(
                      width: 1,
                      height: config.totalGridHeight,
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),

                    // 7 Day columns
                    Expanded(
                      child: SingleChildScrollView(
                        controller: needsHorizontalScroll
                            ? _gridHorizontalScrollController
                            : null,
                        scrollDirection: Axis.horizontal,
                        physics: needsHorizontalScroll
                            ? null
                            : const NeverScrollableScrollPhysics(),
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerMove: (event) {
                            if (widget.interactionController.ownsPointer(
                                  event.pointer,
                                ) &&
                                widget.interactionController.isDragging) {
                              final renderBox =
                                  _gridKey.currentContext?.findRenderObject()
                                      as RenderBox?;
                              if (renderBox != null && renderBox.hasSize) {
                                final local = renderBox.globalToLocal(
                                  event.position,
                                );
                                final targetDay = _resolveDayAt(
                                  event.position,
                                  days,
                                  columnWidth,
                                );
                                widget.interactionController.updatePointer(
                                  event.position,
                                  targetDay,
                                  local.dy,
                                );
                                _checkEdgeDwell(local.dx, totalGridWidth);
                              }
                            }
                          },
                          onPointerUp: (event) async {
                            if (widget.interactionController.ownsPointer(
                                  event.pointer,
                                ) &&
                                widget.interactionController.isDragging) {
                              _cancelEdgeDwell();
                              await widget.onInteractionFinished?.call();
                            } else {
                              _cancelEdgeDwell();
                            }
                          },
                          onPointerCancel: (event) {
                            _cancelEdgeDwell();
                            if (widget.interactionController.ownsPointer(
                              event.pointer,
                            )) {
                              widget.interactionController.forceCancel();
                            }
                          },
                          child: SizedBox(
                            key: _gridKey,
                            width: totalGridWidth,
                            height: config.totalGridHeight,
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    for (var i = 0; i < days.length; i++)
                                      Container(
                                        width: columnWidth,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: scheme.outlineVariant
                                                  .withValues(alpha: 0.35),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: TimelineDayColumn(
                                          dayDate: days[i],
                                          items:
                                              widget.itemsByDay[days[i]] ??
                                              const [],
                                          config: config,
                                          interactionController:
                                              widget.interactionController,
                                          onItemTap: widget.onItemTap,
                                          onSlotSecondaryTap:
                                              widget.onSlotSecondaryTap,
                                          alarmRules: widget.alarmRules,
                                          colorResolver: widget.colorResolver,
                                          scrollController:
                                              _verticalScrollController,
                                          resolveDayAt: (globalPos) =>
                                              _resolveDayAt(
                                                globalPos,
                                                days,
                                                columnWidth,
                                              ),
                                          onInteractionFinished:
                                              widget.onInteractionFinished,
                                        ),
                                      ),
                                  ],
                                ),
                                if (_edgeDwellMessage != null)
                                  Positioned(
                                    top: 10,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(16),
                                        color: scheme.inverseSurface,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _pendingDwellDirection !=
                                                            null &&
                                                        _pendingDwellDirection! >
                                                            0
                                                    ? Icons.arrow_forward
                                                    : Icons.arrow_back,
                                                size: 14,
                                                color: scheme.onInverseSurface,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _edgeDwellMessage!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      scheme.onInverseSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayHeader(DateTime dayDate, DateTime today, ColorScheme scheme) {
    final isToday = _isSameDay(dayDate, today);
    final selected = DateUtils.isSameDay(dayDate, widget.selectedDate);
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(dayDate);
    final theme = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      label: '${isToday ? 'Today, ' : ''}$dateLabel',
      child: InkWell(
        onTap: () => widget.onDayHeaderTap(dayDate),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.gap,
            horizontal: AppSpacing.small,
          ),
          decoration: BoxDecoration(
            color: isToday || selected ? scheme.primaryContainer : null,
            border: Border(right: BorderSide(color: scheme.outlineVariant)),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekdayNames[dayDate.weekday - 1],
                  style: theme.labelMedium?.copyWith(
                    color: isToday || selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gap,
                  ),
                  decoration: isToday
                      ? BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        )
                      : null,
                  child: Text(
                    '${dayDate.day}',
                    style: theme.titleSmall?.copyWith(
                      color: isToday ? scheme.onPrimary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUntimedPreview(
    DateTime day,
    List<CalendarItem> items,
    double lineHeight,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = items.length > 2 ? items.take(1) : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in visible)
          SizedBox(
            height: lineHeight,
            child: Tooltip(
              message:
                  '${item.allDay ? 'All day' : item.subtitle ?? 'Planned task'} · ${item.title}',
              child: InkWell(
                onTap: () => widget.onItemTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.small,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.allDay
                            ? iconForKey(item.iconName, Icons.event_outlined)
                            : item.subtitle == 'Deadline'
                            ? Icons.flag_outlined
                            : Icons.task_alt_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            decoration: item.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (items.length > 2)
          SizedBox(
            height: lineHeight,
            child: InkWell(
              onTap: () => widget.onDayHeaderTap(day),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gap),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '+${items.length - 1} more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
