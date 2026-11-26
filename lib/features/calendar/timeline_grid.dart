import 'calendar_presentation.dart';
import '../shared/app_spacing.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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
  final void Function(DateTime slotTime, Offset globalPosition)
  onSlotSecondaryTap;
  final List<AlarmRule> alarmRules;
  final Color Function(CalendarItem item)? colorResolver;
  final ScrollController? scrollController;
  final DateTime Function(Offset globalPosition)? resolveDayAt;
  final Future<void> Function()? onInteractionFinished;

  @override
  State<TimelineDayColumn> createState() => _TimelineDayColumnState();

  static double calculateContrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color contrastAwareTextColor({
    required Color background,
    required ColorScheme scheme,
    bool isPrimary = true,
  }) {
    // Callers supply the opaque, composited card background. Prefer semantic
    // foregrounds, then choose the stronger extreme (not a luminance cutoff).
    final baseColor = isPrimary ? scheme.onSurface : scheme.onSurfaceVariant;
    if (calculateContrastRatio(baseColor, background) >=
        (isPrimary ? 5.0 : 4.5)) {
      return baseColor;
    }
    return calculateContrastRatio(Colors.black, background) >=
            calculateContrastRatio(Colors.white, background)
        ? Colors.black
        : Colors.white;
  }
}

class _TimelineDayColumnState extends State<TimelineDayColumn> {
  Timer? _autoScrollTimer;
  Offset? _lastGlobalPointerPosition;
  int _autoScrollDirection = 0;
  String? _keyboardFocusedItemId;

  @override
  void initState() {
    super.initState();
    widget.interactionController.addListener(_stopCancelledScroll);
  }

  void _stopCancelledScroll() {
    if (widget.interactionController.gestureKind == CalendarGestureKind.none) {
      _autoScrollTimer?.cancel();
      _autoScrollDirection = 0;
      _lastGlobalPointerPosition = null;
    }
  }

  @override
  void dispose() {
    widget.interactionController.removeListener(_stopCancelledScroll);
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _checkAutoScroll(Offset globalPosition) {
    if (widget.interactionController.gestureKind == CalendarGestureKind.none) {
      _stopCancelledScroll();
      return;
    }
    if (widget.scrollController == null ||
        !widget.scrollController!.hasClients) {
      return;
    }
    final scroller = widget.scrollController!;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final localInColumn = renderBox.globalToLocal(globalPosition);
    final viewportHeight = scroller.position.viewportDimension;
    final scrollOffset = scroller.offset;
    final viewportY = localInColumn.dy - scrollOffset;

    final margin = widget.config.autoScrollMargin;
    _autoScrollDirection = viewportY >= -10 && viewportY < margin
        ? -1
        : viewportY > viewportHeight - margin &&
              viewportY <= viewportHeight + 10
        ? 1
        : 0;
    if (_autoScrollDirection == 0) {
      _autoScrollTimer?.cancel();
      return;
    }
    if (_autoScrollTimer?.isActive == true) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted ||
          !scroller.hasClients ||
          _lastGlobalPointerPosition == null) {
        return;
      }
      final target =
          (scroller.offset +
                  _autoScrollDirection * widget.config.autoScrollSpeed)
              .clamp(0.0, scroller.position.maxScrollExtent);
      if (target != scroller.offset) {
        scroller.jumpTo(target);
        _onAutoScrollTick();
      }
    });
  }

  void _onAutoScrollTick() {
    if (_lastGlobalPointerPosition == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final targetDay = widget.resolveDayAt != null
        ? widget.resolveDayAt!(_lastGlobalPointerPosition!)
        : widget.dayDate;
    final timelineY = _resolveTimelineY(
      renderBox,
      _lastGlobalPointerPosition!,
      targetDay,
    );
    widget.interactionController.updatePointer(
      _lastGlobalPointerPosition!,
      targetDay,
      timelineY,
    );
  }

  double? _resolveTimelineY(
    RenderBox? renderBox,
    Offset globalPosition,
    DateTime targetDay,
  ) {
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.globalToLocal(globalPosition).dy;
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

    return Listener(
      onPointerDown: (event) => controller.trackPointer(event.pointer),
      onPointerCancel: (event) {
        if (!controller.ownsPointer(event.pointer)) return;
        // A cancelled accepted pan can finish through onPanEnd. Clear the
        // draft before recognizers dispatch their end callback.
        _autoScrollTimer?.cancel();
        _lastGlobalPointerPosition = null;
        controller.cancel();
      },
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final activeItem = controller.activeItem;
          final isDraggingActive = controller.isDragging && activeItem != null;
          final isSpanningThisColumn =
              controller.proposedStartsAt != null &&
              controller.proposedEndsAt != null &&
              controller.proposedStartsAt!.isBefore(
                DateTime(
                  widget.dayDate.year,
                  widget.dayDate.month,
                  widget.dayDate.day + 1,
                ),
              ) &&
              controller.proposedEndsAt!.isAfter(
                DateTime(
                  widget.dayDate.year,
                  widget.dayDate.month,
                  widget.dayDate.day,
                ),
              );
          final isCurrentColumnTarget =
              controller.proposedDayDate != null &&
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
                    child: CustomPaint(
                      painter: _TimelineHourLines(
                        startHour: config.startHour,
                        endHour: config.endHour,
                        hourHeight: config.hourHeight,
                        color: scheme.outlineVariant,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var hour = config.startHour;
                            hour < config.endHour;
                            hour++
                          )
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
                                widget.onSlotSecondaryTap(
                                  slotTime,
                                  details.globalPosition,
                                );
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
                                widget.onSlotSecondaryTap(
                                  slotTime,
                                  details.globalPosition,
                                );
                              },
                              child: SizedBox(height: config.hourHeight),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Timed item placements
                  for (final placement in placements)
                    _buildPlacedItem(
                      placement: placement,
                      availableWidth: availableWidth,
                      scheme: scheme,
                      isBeingDragged:
                          isDraggingActive &&
                          activeItem.id == placement.item.id,
                    ),

                  if (isToday)
                    _buildCurrentTimeLine(engine, scheme, availableWidth),

                  // 4. Ghost preview when dragging into or within this column
                  if (isDraggingActive &&
                      (isCurrentColumnTarget || isSpanningThisColumn) &&
                      controller.proposedStartsAt != null &&
                      controller.proposedEndsAt != null)
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
      ),
    );
  }

  Widget _buildCurrentTimeLine(
    CalendarLayoutEngine engine,
    ColorScheme scheme,
    double width,
  ) {
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
              child: Container(height: 1.5, color: scheme.primary),
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
    final gridStart = DateTime(
      widget.dayDate.year,
      widget.dayDate.month,
      widget.dayDate.day,
      config.startHour,
    );
    final gridEnd = DateTime(
      widget.dayDate.year,
      widget.dayDate.month,
      widget.dayDate.day,
      config.endHour,
    );
    final itemLeft =
        (placement.leftFraction * availableWidth) + (config.overlapSpacing / 2);
    final itemWidth =
        (placement.widthFraction * availableWidth) - config.overlapSpacing;

    final accent = widget.colorResolver != null
        ? widget.colorResolver!(item)
        : (item.colorValue != null ? Color(item.colorValue!) : scheme.primary);

    final isCancelled = item.isCancelled;
    final cardBg = Color.alphaBlend(
      Color.lerp(scheme.surface, accent, isCancelled ? 0.08 : 0.17)!,
      scheme.surface,
    );
    final hasAlarm =
        item.event != null &&
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
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: _keyboardFocusedItemId == item.id
                    ? scheme.primary
                    : accent.withValues(alpha: isCancelled ? 0.35 : 0.55),
                width: _keyboardFocusedItemId == item.id ? 2 : 1,
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
                    child: FocusableActionDetector(
                      onShowFocusHighlight: (visible) {
                        if (!mounted ||
                            !visible && _keyboardFocusedItemId != item.id) {
                          return;
                        }
                        setState(
                          () =>
                              _keyboardFocusedItemId = visible ? item.id : null,
                        );
                      },
                      shortcuts: const {
                        SingleActivator(LogicalKeyboardKey.enter):
                            ActivateIntent(),
                        SingleActivator(LogicalKeyboardKey.space):
                            ActivateIntent(),
                      },
                      actions: {
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) {
                            widget.onItemTap(item);
                            return null;
                          },
                        ),
                      },
                      child: Tooltip(
                        excludeFromSemantics: true,
                        message:
                            '${item.title}\n${_formatTime(item.startsAt!)} – ${_formatTime(item.endsAt!)}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onItemTap(item),
                          onPanStart: (details) {
                            _lastGlobalPointerPosition = details.globalPosition;
                            final renderBox =
                                context.findRenderObject() as RenderBox?;
                            final timelineY =
                                renderBox != null && renderBox.hasSize
                                ? renderBox
                                      .globalToLocal(details.globalPosition)
                                      .dy
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
                            final renderBox =
                                context.findRenderObject() as RenderBox?;
                            final targetDay = widget.resolveDayAt != null
                                ? widget.resolveDayAt!(details.globalPosition)
                                : widget.dayDate;
                            final timelineY = _resolveTimelineY(
                              renderBox,
                              details.globalPosition,
                              targetDay,
                            );
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
                            widget.interactionController.cancelFromRecognizer();
                          },
                          child: Semantics(
                            label:
                                '${item.kind == CalendarItemKind.event ? 'Event' : 'Work session'}, ${item.title}, ${_formatTime(item.startsAt!)} – ${_formatTime(item.endsAt!)}'
                                '${isCancelled ? ', Cancelled' : ''}'
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
                                child: _keepContinuationReadable(
                                  placement,
                                  _buildItemContent(
                                    item: item,
                                    placement: placement,
                                    accent: accent,
                                    scheme: scheme,
                                    isCompact: isCompact,
                                    hasAlarm: hasAlarm,
                                    itemWidth: itemWidth,
                                    cardBackground: cardBg,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top edge resize handle
                  if (config.enableResize &&
                      !item.startsAt!.isBefore(gridStart))
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
                          child: _resizeInput(
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanStart: (details) {
                                _lastGlobalPointerPosition =
                                    details.globalPosition;
                                final renderBox =
                                    context.findRenderObject() as RenderBox?;
                                final timelineY =
                                    renderBox != null && renderBox.hasSize
                                    ? renderBox
                                          .globalToLocal(details.globalPosition)
                                          .dy
                                    : null;
                                widget.interactionController.startResizeTop(
                                  item: item,
                                  dayDate: widget.dayDate,
                                  pointerLocal: details.globalPosition,
                                  pointerTimelineY: timelineY,
                                );
                              },
                              onPanUpdate: (details) {
                                _lastGlobalPointerPosition =
                                    details.globalPosition;
                                final renderBox =
                                    context.findRenderObject() as RenderBox?;
                                final targetDay = widget.resolveDayAt != null
                                    ? widget.resolveDayAt!(
                                        details.globalPosition,
                                      )
                                    : widget.dayDate;
                                final timelineY = _resolveTimelineY(
                                  renderBox,
                                  details.globalPosition,
                                  targetDay,
                                );
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
                                widget.interactionController
                                    .cancelFromRecognizer();
                              },
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Bottom edge resize handle
                  if (config.enableResize && !item.endsAt!.isAfter(gridEnd))
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
                          child: _resizeInput(
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanStart: (details) {
                                _lastGlobalPointerPosition =
                                    details.globalPosition;
                                final renderBox =
                                    context.findRenderObject() as RenderBox?;
                                final timelineY =
                                    renderBox != null && renderBox.hasSize
                                    ? renderBox
                                          .globalToLocal(details.globalPosition)
                                          .dy
                                    : null;
                                widget.interactionController.startResizeBottom(
                                  item: item,
                                  dayDate: widget.dayDate,
                                  pointerLocal: details.globalPosition,
                                  pointerTimelineY: timelineY,
                                );
                              },
                              onPanUpdate: (details) {
                                _lastGlobalPointerPosition =
                                    details.globalPosition;
                                final renderBox =
                                    context.findRenderObject() as RenderBox?;
                                final targetDay = widget.resolveDayAt != null
                                    ? widget.resolveDayAt!(
                                        details.globalPosition,
                                      )
                                    : widget.dayDate;
                                final timelineY = _resolveTimelineY(
                                  renderBox,
                                  details.globalPosition,
                                  targetDay,
                                );
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
                                widget.interactionController
                                    .cancelFromRecognizer();
                              },
                              child: const SizedBox.expand(),
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
    );
  }

  Widget _resizeInput(Widget child) => MediaQuery(
    // Precision handles must win before an ancestor directional scroller.
    // The controller still enforces its normal movement/snap threshold.
    data: MediaQuery.of(context).copyWith(
      gestureSettings: DeviceGestureSettings(
        touchSlop: widget.config.dragThreshold / 2,
      ),
    ),
    child: child,
  );

  Widget _keepContinuationReadable(
    CalendarPlacement placement,
    Widget content,
  ) {
    final scroll = widget.scrollController;
    if (scroll == null ||
        !placement.item.startsAt!.isBefore(
          DateUtils.dateOnly(widget.dayDate),
        )) {
      return content;
    }
    final labelHeight = MediaQuery.textScalerOf(context).scale(32);
    return ListenableBuilder(
      listenable: scroll,
      child: content,
      builder: (context, child) => Padding(
        padding: EdgeInsets.only(
          top: scroll.hasClients
              ? (scroll.offset - placement.top).clamp(
                  0.0,
                  math.max(0.0, placement.height - labelHeight),
                )
              : 0.0,
        ),
        child: child,
      ),
    );
  }

  Widget _buildItemContent({
    required CalendarItem item,
    required CalendarPlacement placement,
    required Color accent,
    required ColorScheme scheme,
    required bool isCompact,
    required bool hasAlarm,
    required double itemWidth,
    required Color cardBackground,
  }) {
    final dayStart = DateTime(
      widget.dayDate.year,
      widget.dayDate.month,
      widget.dayDate.day,
    );
    final isContinuation = item.startsAt!.isBefore(dayStart);
    final dayEnd = DateTime(
      widget.dayDate.year,
      widget.dayDate.month,
      widget.dayDate.day + 1,
    );
    final continuesNextDay = item.endsAt!.isAfter(dayEnd);
    final startTimeStr = isContinuation ? '00:00' : _formatTime(item.startsAt!);
    final endTimeStr = !item.endsAt!.isBefore(dayEnd)
        ? '24:00'
        : _formatTime(item.endsAt!);
    final timeRangeStr =
        '${isContinuation ? '← ' : ''}$startTimeStr – $endTimeStr${continuesNextDay ? ' →' : ''}';
    final conflictTooltip = placement.hasConflict
        ? 'Overlaps ${placement.conflictCount} other event${placement.conflictCount == 1 ? '' : 's'} or work session${placement.conflictCount == 1 ? '' : 's'}'
        : null;

    final primaryTextColor = TimelineDayColumn.contrastAwareTextColor(
      background: cardBackground,
      scheme: scheme,
      isPrimary: true,
    );
    final secondaryTextColor = TimelineDayColumn.contrastAwareTextColor(
      background: cardBackground,
      scheme: scheme,
      isPrimary: false,
    );

    if (isCompact) {
      final showTime =
          placement.height >= MediaQuery.textScalerOf(context).scale(30);
      if (itemWidth < 60) {
        final shortTime = isContinuation ? '←' : startTimeStr;
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  decoration: item.isCancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (showTime)
                Text(
                  shortTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: secondaryTextColor),
                ),
            ],
          ),
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
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  decoration: item.isCancelled
                      ? TextDecoration.lineThrough
                      : null,
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
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 10,
                    color: scheme.error,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final showLeadingIcon = itemWidth >= 105;
    final compactTimeStr =
        '${isContinuation ? '← ' : ''}$startTimeStr${continuesNextDay ? ' →' : ''}';
    final displayedTimeStr = itemWidth < 130 ? compactTimeStr : timeRangeStr;

    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showLeadingIcon) ...[
                  Icon(
                    item.kind == CalendarItemKind.event
                        ? iconForKey(item.iconName, Icons.event_outlined)
                        : Icons.schedule,
                    size: 12,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                      decoration: item.isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (hasAlarm) const AlarmIndicator(),
                if (placement.hasConflict)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Tooltip(
                      message: conflictTooltip!,
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 11,
                        color: scheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            if (placement.height >= 42) ...[
              const SizedBox(height: 1),
              Text(
                displayedTimeStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: secondaryTextColor),
              ),
            ],
            if (placement.height >= 58 &&
                item.detailsText != null &&
                item.detailsText!.isNotEmpty)
              Text(
                item.detailsText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
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
    final height = (bottom - top).clamp(
      widget.config.minItemHeight,
      double.infinity,
    );

    final isMultiDay = !_isSameDay(proposedStart, proposedEnd);
    final startStr = isMultiDay
        ? '${_formatDateBadge(proposedStart)} ${_formatTime(proposedStart)}'
        : _formatTime(proposedStart);
    final endStr = isMultiDay
        ? '${_formatDateBadge(proposedEnd)} ${_formatTime(proposedEnd)}'
        : _formatTime(proposedEnd);

    final dayStart = DateTime(
      widget.dayDate.year,
      widget.dayDate.month,
      widget.dayDate.day,
    );
    final dayEnd = DateTime(
      widget.dayDate.year,
      widget.dayDate.month,
      widget.dayDate.day + 1,
    );
    final isFirstSegment = !proposedStart.isBefore(dayStart);
    final isLastSegment = !proposedEnd.isAfter(dayEnd);
    final background = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.18),
      scheme.surface,
    );
    final foreground = TimelineDayColumn.contrastAwareTextColor(
      background: background,
      scheme: scheme,
    );

    return Positioned(
      top: top,
      left: 2,
      width: availableWidth - 4,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: scheme.primary, width: 1.5),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Live start time chip above preview (on start day) or continuation label
              if (isFirstSegment)
                Positioned(
                  top: -16,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      startStr,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  top: 2,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Continues',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
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
                    color: foreground,
                  ),
                ),
              ),

              // Live end time chip below preview (on end day) or continuation label
              if (isLastSegment)
                Positioned(
                  bottom: -16,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      endStr,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 2,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'Continues',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
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

  String _formatTime(DateTime dt) => calendarTimeLabel(context, dt);

  String _formatDateBadge(DateTime dt) =>
      MaterialLocalizations.of(context).formatShortMonthDay(dt);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Batch static lines by color without changing individual slot hit targets.
class _TimelineHourLines extends CustomPainter {
  const _TimelineHourLines({
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.color,
  });

  final int startHour;
  final int endHour;
  final double hourHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final major = <double>[];
    final minor = <double>[];
    for (var hour = startHour; hour < endHour; hour++) {
      final y = (hour - startHour) * hourHeight + 0.5;
      (hour % 3 == 0 ? major : minor).addAll([0, y, size.width, y]);
    }
    final paint = Paint()
      ..strokeWidth = 1
      ..isAntiAlias = false;
    paint.color = color.withValues(alpha: 0.9);
    canvas.drawRawPoints(PointMode.lines, Float32List.fromList(major), paint);
    paint.color = color.withValues(alpha: 0.6);
    canvas.drawRawPoints(PointMode.lines, Float32List.fromList(minor), paint);
  }

  @override
  bool shouldRepaint(_TimelineHourLines oldDelegate) =>
      startHour != oldDelegate.startHour ||
      endHour != oldDelegate.endHour ||
      hourHeight != oldDelegate.hourHeight ||
      color != oldDelegate.color;
}
