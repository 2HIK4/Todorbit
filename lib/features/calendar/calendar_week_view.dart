import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/alarms.dart';
import '../shared/weekdays.dart';
import 'calendar_config.dart';
import 'calendar_interaction_controller.dart';
import 'calendar_models.dart';
import 'timeline_grid.dart';

/// Full interactive Week time-grid featuring 7 synchronized day columns and cross-day dragging.
class CalendarWeekView extends StatefulWidget {
  const CalendarWeekView({
    super.key,
    required this.weekStart,
    required this.itemsByDay,
    required this.config,
    required this.interactionController,
    required this.onItemTap,
    required this.onSlotSecondaryTap,
    required this.onDayHeaderTap,
    this.alarmRules = const [],
    this.colorResolver,
    this.onInteractionFinished,
  });

  final DateTime weekStart;
  final Map<DateTime, List<CalendarItem>> itemsByDay;
  final CalendarAppearanceConfiguration config;
  final CalendarInteractionController interactionController;
  final void Function(CalendarItem item) onItemTap;
  final void Function(DateTime slotTime, Offset globalPosition) onSlotSecondaryTap;
  final void Function(DateTime dayDate) onDayHeaderTap;
  final List<AlarmRule> alarmRules;
  final Color Function(CalendarItem item)? colorResolver;
  final Future<void> Function()? onInteractionFinished;

  @override
  State<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends State<CalendarWeekView> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _gridHorizontalScrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _headerScrollController.addListener(_syncHeaderToGrid);
    _gridHorizontalScrollController.addListener(_syncGridToHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollController.hasClients) {
        final initialY = widget.config.initialScrollHour * widget.config.hourHeight;
        _verticalScrollController.jumpTo(
          initialY.clamp(0.0, _verticalScrollController.position.maxScrollExtent),
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

  void _syncGridToHeader() {
    if (!_isSyncingScroll && _headerScrollController.hasClients) {
      _isSyncingScroll = true;
      _headerScrollController.jumpTo(_gridHorizontalScrollController.offset);
      _isSyncingScroll = false;
    }
  }

  @override
  void dispose() {
    _headerScrollController.removeListener(_syncHeaderToGrid);
    _gridHorizontalScrollController.removeListener(_syncGridToHeader);
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    _gridHorizontalScrollController.dispose();
    super.dispose();
  }

  DateTime _resolveDayAt(Offset globalPosition, List<DateTime> days, double columnWidth) {
    final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return days.first;
    final local = renderBox.globalToLocal(globalPosition);
    final colIndex = (local.dx / columnWidth).floor().clamp(0, days.length - 1);
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
                    controller: needsHorizontalScroll ? _headerScrollController : null,
                    scrollDirection: Axis.horizontal,
                    physics: needsHorizontalScroll ? null : const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalGridWidth,
                      child: Row(
                        children: [
                          for (final dayDate in days)
                            SizedBox(
                              width: columnWidth,
                              child: _buildDayHeader(dayDate, today, scheme),
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
                          for (var hour = config.startHour; hour < config.endHour; hour++)
                            Positioned(
                              top: (hour - config.startHour) * config.hourHeight - 8,
                              left: 4,
                              right: 6,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.outline,
                                  fontSize: 10,
                                ),
                              ),
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
                        controller: needsHorizontalScroll ? _gridHorizontalScrollController : null,
                        scrollDirection: Axis.horizontal,
                        physics: needsHorizontalScroll ? null : const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          key: _gridKey,
                          width: totalGridWidth,
                          height: config.totalGridHeight,
                          child: Row(
                            children: [
                              for (var i = 0; i < days.length; i++)
                                Container(
                                  width: columnWidth,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: TimelineDayColumn(
                                    dayDate: days[i],
                                    items: widget.itemsByDay[days[i]] ?? const [],
                                    config: config,
                                    interactionController: widget.interactionController,
                                    onItemTap: widget.onItemTap,
                                    onSlotSecondaryTap: widget.onSlotSecondaryTap,
                                    alarmRules: widget.alarmRules,
                                    colorResolver: widget.colorResolver,
                                    scrollController: _verticalScrollController,
                                    resolveDayAt: (globalPos) => _resolveDayAt(globalPos, days, columnWidth),
                                    onInteractionFinished: widget.onInteractionFinished,
                                  ),
                                ),
                            ],
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
    final weekdayName = weekdayNames[dayDate.weekday - 1];

    return InkWell(
      onTap: () => widget.onDayHeaderTap(dayDate),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isToday
              ? scheme.primaryContainer.withValues(alpha: 0.55)
              : null,
          border: Border(
            right: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: isToday
                  ? BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${dayDate.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isToday ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
