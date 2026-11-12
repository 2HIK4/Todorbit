import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/alarm_plan.dart';
import '../../domain/alarms.dart';
import '../shared/alarm_indicator.dart';
import '../shared/icon_picker.dart';
import 'calendar_config.dart';
import 'calendar_interaction_controller.dart';
import 'calendar_layout_engine.dart';
import 'calendar_models.dart';

/// Interactive vertical timeline grid representing a single day's hours and timed items.
class TimelineDayColumn extends StatefulWidget {
  const TimelineDayColumn({
    super.key,
    required this.dayDate,
    required this.items,
    required this.config,
    required this.interactionController,
    required this.onItemTap,
    required this.onSlotSecondaryTap,
    this.alarmRules = const [],
    this.colorResolver,
    this.scrollController,
    this.resolveDayAt,
    this.onInteractionFinished,
  });

  final DateTime dayDate;
  final List<CalendarItem> items;
  final CalendarAppearanceConfiguration config;
  final CalendarInteractionController interactionController;
  final void Function(CalendarItem item) onItemTap;
  final void Function(DateTime slotTime, Offset globalPosition) onSlotSecondaryTap;
  final List<AlarmRule> alarmRules;
  final Color Function(CalendarItem item)? colorResolver;
  final ScrollController? scrollController;
  final DateTime Function(Offset globalPosition)? resolveDayAt;
  final Future<void> Function()? onInteractionFinished;

  @override
  State<TimelineDayColumn> createState() => _TimelineDayColumnState();
}

class _TimelineDayColumnState extends State<TimelineDayColumn> {
  Timer? _autoScrollTimer;
  Offset? _lastGlobalPointerPosition;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _checkAutoScroll(Offset globalPosition) {
    if (widget.scrollController == null || !widget.scrollController!.hasClients) return;
    final scroller = widget.scrollController!;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final localInColumn = renderBox.globalToLocal(globalPosition);
    final viewportHeight = scroller.position.viewportDimension;
    final scrollOffset = scroller.offset;
    final viewportY = localInColumn.dy - scrollOffset;

    final margin = widget.config.autoScrollMargin;
    if (viewportY >= -10 && viewportY < margin) {
      if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
        _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
          if (!scroller.hasClients) return;
          final target = (scroller.offset - widget.config.autoScrollSpeed).clamp(0.0, scroller.position.maxScrollExtent);
          if (target == scroller.offset) return;
          scroller.jumpTo(target);
          _onAutoScrollTick();
        });
      }
    } else if (viewportY > viewportHeight - margin && viewportY <= viewportHeight + 10) {
      if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
        _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
          if (!scroller.hasClients) return;
          final target = (scroller.offset + widget.config.autoScrollSpeed).clamp(0.0, scroller.position.maxScrollExtent);
          if (target == scroller.offset) return;
          scroller.jumpTo(target);
          _onAutoScrollTick();
        });
      }
    } else {
      _autoScrollTimer?.cancel();
    }
  }

  void _onAutoScrollTick() {
    if (_lastGlobalPointerPosition == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final localInColumn = renderBox.globalToLocal(_lastGlobalPointerPosition!);
    final targetDay = widget.resolveDayAt != null
        ? widget.resolveDayAt!(_lastGlobalPointerPosition!)
        : widget.dayDate;
    widget.interactionController.updatePointer(
      _lastGlobalPointerPosition!,
      targetDay,
      localInColumn.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config = widget.config;
    final engine = widget.interactionController.engine;
    final controller = widget.interactionController;

    final placements = engine.computePlacements(widget.items, widget.dayDate);
    final isToday = _isSameDay(widget.dayDate, DateTime.now());

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final activeItem = controller.activeItem;
        final isDraggingActive = controller.isDragging && activeItem != null;
        final isCurrentColumnTarget = controller.proposedDayDate != null &&
            _isSameDay(controller.proposedDayDate!, widget.dayDate);

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final gridHeight = config.totalGridHeight;

            return Stack(
              children: [
                // 1. Background grid rows and hour lines
                SizedBox(
                  height: gridHeight,
                  width: availableWidth,
                  child: Column(
                    children: [
                      for (var hour = config.startHour; hour < config.endHour; hour++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onSecondaryTapDown: (details) {
                            final slotTime = DateTime(
                              widget.dayDate.year,
                              widget.dayDate.month,
                              widget.dayDate.day,
                              hour,
                              0,
                            );
                            widget.onSlotSecondaryTap(slotTime, details.globalPosition);
                          },
                          onLongPressStart: (details) {
                            // Touch alternative for Android
                            final slotTime = DateTime(
                              widget.dayDate.year,
                              widget.dayDate.month,
                              widget.dayDate.day,
                              hour,
                              0,
                            );
                            widget.onSlotSecondaryTap(slotTime, details.globalPosition);
                          },
                          child: Container(
                            height: config.hourHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Current time indicator line if today
                if (isToday) _buildCurrentTimeLine(engine, scheme, availableWidth),

                // 3. Timed item placements
                for (final placement in placements)
                  _buildPlacedItem(
                    placement: placement,
                    availableWidth: availableWidth,
                    scheme: scheme,
                    isBeingDragged: isDraggingActive && activeItem.id == placement.item.id,
                  ),

                // 4. Ghost preview when dragging into or within this column
                if (isDraggingActive && isCurrentColumnTarget && controller.proposedStartsAt != null && controller.proposedEndsAt != null)
                  _buildGhostPreview(
                    engine: engine,
                    activeItem: activeItem,
                    proposedStart: controller.proposedStartsAt!,
                    proposedEnd: controller.proposedEndsAt!,
                    availableWidth: availableWidth,
                    scheme: scheme,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentTimeLine(CalendarLayoutEngine engine, ColorScheme scheme, double width) {
    final now = DateTime.now();
    final y = engine.timeToY(now, widget.dayDate);
    final timeStr = _formatTime(now);
    return Positioned(
      top: y - 8,
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Current time ($timeStr)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: IgnorePointer(
              child: Container(
                height: 1.5,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacedItem({
    required CalendarPlacement placement,
    required double availableWidth,
    required ColorScheme scheme,
    required bool isBeingDragged,
  }) {
    final item = placement.item;
    final config = widget.config;
    final itemLeft = (placement.leftFraction * availableWidth) + (config.overlapSpacing / 2);
    final itemWidth = (placement.widthFraction * availableWidth) - config.overlapSpacing;

    final accent = widget.colorResolver != null
        ? widget.colorResolver!(item)
        : (item.colorValue != null ? Color(item.colorValue!) : scheme.primary);

    final isCancelled = item.isCancelled;
    final hasAlarm = item.event != null &&
        !isCancelled &&
        eventAlarmRule(item.event!, widget.alarmRules)?.config.enabled == true;

    final bool isCompact = placement.height < 44 || itemWidth < 60;

    return Positioned(
      top: placement.top,
      left: itemLeft.clamp(0.0, availableWidth),
      width: itemWidth.clamp(16.0, availableWidth),
      height: placement.height,
      child: Opacity(
        opacity: isBeingDragged ? 0.35 : 1.0,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: Color.lerp(scheme.surface, accent, isCancelled ? 0.12 : 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accent.withValues(alpha: isCancelled ? 0.35 : 0.7),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  // Left colored accent stripe
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: 4,
                    child: Container(color: accent),
                  ),

                  // Center body (handles click to open and center drag to move)
                  Positioned.fill(
                    left: 5,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onItemTap(item),
                      onPanStart: (details) {
                        _lastGlobalPointerPosition = details.globalPosition;
                        final renderBox = context.findRenderObject() as RenderBox?;
                        final timelineY = renderBox != null && renderBox.hasSize
                            ? renderBox.globalToLocal(details.globalPosition).dy
                            : null;
                        widget.interactionController.startMove(
                          item: item,
                          dayDate: widget.dayDate,
                          pointerLocal: details.globalPosition,
                          pointerTimelineY: timelineY,
                        );
                      },
                      onPanUpdate: (details) {
                        _lastGlobalPointerPosition = details.globalPosition;
                        final renderBox = context.findRenderObject() as RenderBox?;
                        final timelineY = renderBox != null && renderBox.hasSize
                            ? renderBox.globalToLocal(details.globalPosition).dy
                            : null;
                        final targetDay = widget.resolveDayAt != null
                            ? widget.resolveDayAt!(details.globalPosition)
                            : widget.dayDate;
                        widget.interactionController.updatePointer(
                          details.globalPosition,
                          targetDay,
                          timelineY,
                        );
                        _checkAutoScroll(details.globalPosition);
                      },
                      onPanEnd: (_) async {
                        _autoScrollTimer?.cancel();
                        _lastGlobalPointerPosition = null;
                        await widget.onInteractionFinished?.call();
                      },
                      onPanCancel: () {
                        _autoScrollTimer?.cancel();
                        _lastGlobalPointerPosition = null;
                        widget.interactionController.cancel();
                      },
                      child: Semantics(
                        label: '${item.title}, ${_formatTime(item.startsAt!)} – ${_formatTime(item.endsAt!)}'
                            '${hasAlarm ? ', Alarm set' : ''}'
                            '${placement.hasConflict ? ', Overlaps ${placement.conflictCount} items' : ''}',
                        button: true,
                        enabled: true,
                        excludeSemantics: true,
                        onTap: () => widget.onItemTap(item),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 2 : 4,
                            vertical: isCompact ? 1 : 3,
                          ),
                          child: ClipRect(
                            child: _buildItemContent(item, placement, accent, scheme, isCompact, hasAlarm, itemWidth),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top edge resize handle
                  if (config.enableResize)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: config.resizeHandleHeight,
                      child: Tooltip(
                        message: 'Drag to adjust start time',
                        waitDuration: const Duration(milliseconds: 500),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragStart: (details) {
                              _lastGlobalPointerPosition = details.globalPosition;
                              final renderBox = context.findRenderObject() as RenderBox?;
                              final timelineY = renderBox != null && renderBox.hasSize
                                  ? renderBox.globalToLocal(details.globalPosition).dy
                                  : null;
                              widget.interactionController.startResizeTop(
                                item: item,
                                dayDate: widget.dayDate,
                                pointerLocal: details.globalPosition,
                                pointerTimelineY: timelineY,
                              );
                            },
                            onVerticalDragUpdate: (details) {
                              _lastGlobalPointerPosition = details.globalPosition;
                              final renderBox = context.findRenderObject() as RenderBox?;
                              final timelineY = renderBox != null && renderBox.hasSize
                                  ? renderBox.globalToLocal(details.globalPosition).dy
                                  : null;
                              widget.interactionController.updatePointer(
                                details.globalPosition,
                                widget.dayDate,
                                timelineY,
                              );
                              _checkAutoScroll(details.globalPosition);
                            },
                            onVerticalDragEnd: (_) async {
                              _autoScrollTimer?.cancel();
                              _lastGlobalPointerPosition = null;
                              await widget.onInteractionFinished?.call();
                            },
                            onVerticalDragCancel: () {
                              _autoScrollTimer?.cancel();
                              _lastGlobalPointerPosition = null;
                              widget.interactionController.cancel();
                            },
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),

                  // Bottom edge resize handle
                  if (config.enableResize)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: config.resizeHandleHeight,
                      child: Tooltip(
                        message: 'Drag to adjust end time',
                        waitDuration: const Duration(milliseconds: 500),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragStart: (details) {
                              _lastGlobalPointerPosition = details.globalPosition;
                              final renderBox = context.findRenderObject() as RenderBox?;
                              final timelineY = renderBox != null && renderBox.hasSize
                                  ? renderBox.globalToLocal(details.globalPosition).dy
                                  : null;
                              widget.interactionController.startResizeBottom(
                                item: item,
                                dayDate: widget.dayDate,
                                pointerLocal: details.globalPosition,
                                pointerTimelineY: timelineY,
                              );
                            },
                            onVerticalDragUpdate: (details) {
                              _lastGlobalPointerPosition = details.globalPosition;
                              final renderBox = context.findRenderObject() as RenderBox?;
                              final timelineY = renderBox != null && renderBox.hasSize
                                  ? renderBox.globalToLocal(details.globalPosition).dy
                                  : null;
                              widget.interactionController.updatePointer(
                                details.globalPosition,
                                widget.dayDate,
                                timelineY,
                              );
                              _checkAutoScroll(details.globalPosition);
                            },
                            onVerticalDragEnd: (_) async {
                              _autoScrollTimer?.cancel();
                              _lastGlobalPointerPosition = null;
                              await widget.onInteractionFinished?.call();
                            },
                            onVerticalDragCancel: () {
                              _autoScrollTimer?.cancel();
                              _lastGlobalPointerPosition = null;
                              widget.interactionController.cancel();
                            },
                            child: const SizedBox.expand(),
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
    );
  }

  Widget _buildItemContent(
    CalendarItem item,
    CalendarPlacement placement,
    Color accent,
    ColorScheme scheme,
    bool isCompact,
    bool hasAlarm,
    double itemWidth,
  ) {
    final dayStart = DateTime(widget.dayDate.year, widget.dayDate.month, widget.dayDate.day);
    final isContinuation = item.startsAt!.isBefore(dayStart);
    final startTimeStr = _formatTime(item.startsAt!);
    final endTimeStr = _formatTime(item.endsAt!);
    final timeRangeStr = isContinuation ? 'Continues' : '$startTimeStr – $endTimeStr';
    final conflictTooltip = placement.hasConflict
        ? 'Overlaps ${placement.conflictCount} other event${placement.conflictCount == 1 ? '' : 's'} or work session${placement.conflictCount == 1 ? '' : 's'}'
        : null;

    if (isCompact) {
      if (itemWidth < 44) {
        return Tooltip(
          message: '${item.title}\n$timeRangeStr',
          child: const SizedBox.expand(),
        );
      }
      return ClipRect(
        child: Row(
          children: [
            if (itemWidth >= 60) ...[
              Icon(
                item.kind == CalendarItemKind.event
                    ? iconForKey(item.iconName, Icons.event_outlined)
                    : Icons.schedule,
                size: 11,
                color: accent,
              ),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Text(
                '${item.title} ($timeRangeStr)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: item.isCancelled ? scheme.outline : scheme.onSurface,
                  decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (hasAlarm && itemWidth >= 70)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: AlarmIndicator(),
              ),
            if (placement.hasConflict && itemWidth >= 80)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Tooltip(
                  message: conflictTooltip!,
                  child: Icon(Icons.warning_amber_rounded, size: 10, color: scheme.error),
                ),
              ),
          ],
        ),
      );
    }

    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  item.kind == CalendarItemKind.event
                      ? iconForKey(item.iconName, Icons.event_outlined)
                      : Icons.schedule,
                  size: 12,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.isCancelled ? scheme.outline : scheme.onSurface,
                      decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (hasAlarm) const AlarmIndicator(),
                if (placement.hasConflict)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Tooltip(
                      message: conflictTooltip!,
                      child: Icon(Icons.warning_amber_rounded, size: 11, color: scheme.error),
                    ),
                  ),
              ],
            ),
            if (placement.height >= 42) ...[
              const SizedBox(height: 1),
              Text(
                timeRangeStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (placement.height >= 58 && item.detailsText != null && item.detailsText!.isNotEmpty)
              Text(
                item.detailsText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: scheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostPreview({
    required CalendarLayoutEngine engine,
    required CalendarItem activeItem,
    required DateTime proposedStart,
    required DateTime proposedEnd,
    required double availableWidth,
    required ColorScheme scheme,
  }) {
    final top = engine.timeToY(proposedStart, widget.dayDate);
    final bottom = engine.timeToY(proposedEnd, widget.dayDate);
    final height = (bottom - top).clamp(widget.config.minItemHeight, double.infinity);

    final startStr = _formatTime(proposedStart);
    final endStr = _formatTime(proposedEnd);

    return Positioned(
      top: top,
      left: 2,
      width: availableWidth - 4,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: scheme.primary,
              width: 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Live start time chip above preview
              Positioned(
                top: -16,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    startStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),

              // Title preview inside
              Center(
                child: Text(
                  activeItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),

              // Live end time chip below preview
              Positioned(
                bottom: -16,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    endStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
