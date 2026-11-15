import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/alarms.dart';
import '../shared/icon_picker.dart';
import 'calendar_config.dart';
import 'calendar_interaction_controller.dart';
import 'calendar_models.dart';
import 'timeline_grid.dart';

/// Full interactive Day view featuring an all-day / planned header and a vertical time-grid.
class CalendarDayView extends StatefulWidget {
  const CalendarDayView({
    super.key,
    required this.dayDate,
    required this.items,
    required this.config,
    required this.interactionController,
    required this.onItemTap,
    required this.onSlotSecondaryTap,
    this.alarmRules = const [],
    this.colorResolver,
    this.onInteractionFinished,
    this.onNavigateDay,
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
  final Future<void> Function()? onInteractionFinished;
  final void Function(int direction)? onNavigateDay;

  @override
  State<CalendarDayView> createState() => _CalendarDayViewState();
}

class _CalendarDayViewState extends State<CalendarDayView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dayGridKey = GlobalKey();
  Timer? _edgeDwellTimer;
  int? _pendingDwellDirection;
  bool _hasNavigatedAtCurrentEdge = false;
  int? _navigatedDirection;
  String? _edgeDwellMessage;

  @override
  void initState() {
    super.initState();
    widget.interactionController.addListener(_handleInteractionChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final initialY =
            widget.config.initialScrollHour * widget.config.hourHeight;
        _scrollController.jumpTo(
          initialY.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.interactionController.removeListener(_handleInteractionChange);
    _edgeDwellTimer?.cancel();
    _scrollController.dispose();
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
    final box = _dayGridKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || box == null || !box.hasSize) return;
    final local = box.globalToLocal(pointer);
    _checkDayEdgeDwell(local.dy, box.size.height);
  }

  void _checkDayEdgeDwell(double localY, double totalGridHeight) {
    if (widget.onNavigateDay == null ||
        !widget.interactionController.isDragging) {
      _cancelEdgeDwell();
      return;
    }
    const edgeThreshold = 36.0;
    final int direction;
    final scroll = _scrollController.position;
    final viewportY = localY - scroll.pixels;
    final visibleHeight = scroll.viewportDimension.clamp(0.0, totalGridHeight);
    if (viewportY < -10 || viewportY > visibleHeight + 10) {
      _cancelEdgeDwell();
      _hasNavigatedAtCurrentEdge = false;
      return;
    }
    if (scroll.extentAfter <= 1 &&
        viewportY >=
            scroll.viewportDimension.clamp(0.0, totalGridHeight) -
                edgeThreshold) {
      direction = 1;
    } else if (scroll.extentBefore <= 1 && viewportY <= edgeThreshold) {
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
        _edgeDwellMessage = direction > 0
            ? 'Hold to open tomorrow ↓'
            : '↑ Hold to open yesterday';
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
        widget.onNavigateDay?.call(dir);
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

  @override
  void didUpdateWidget(covariant CalendarDayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayDate != widget.dayDate &&
        widget.interactionController.isDragging) {
      final forward = widget.dayDate.isAfter(oldWidget.dayDate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(
            forward ? 0 : _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
    if (oldWidget.config.hourHeight != widget.config.hourHeight &&
        _scrollController.hasClients) {
      final offset =
          _scrollController.offset *
          widget.config.hourHeight /
          oldWidget.config.hourHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final config = widget.config;

    // Separate untimed/all-day items and timed items
    final untimedItems = widget.items.where((item) => !item.isTimed).toList();
    final timedItems = widget.items.where((item) => item.isTimed).toList();

    return Column(
      children: [
        // 1. All-day and Planned Tasks header section
        if (untimedItems.isNotEmpty) _buildUntimedHeader(untimedItems, scheme),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: Text(
            'Time slots',
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),

        // 2. Vertical timeline grid
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left time label gutter
                SizedBox(
                  width: 56,
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
                              (hour - config.startHour) * config.hourHeight - 8,
                          left: 8,
                          right: 8,
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

                // Vertical separator line
                Container(
                  width: 1,
                  height: config.totalGridHeight,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),

                // Main timeline day column
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerMove: (event) {
                      if (widget.interactionController.ownsPointer(
                            event.pointer,
                          ) &&
                          widget.interactionController.isDragging) {
                        final renderBox =
                            _dayGridKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (renderBox != null && renderBox.hasSize) {
                          final local = renderBox.globalToLocal(event.position);
                          widget.interactionController.updatePointer(
                            event.position,
                            widget.dayDate,
                            local.dy,
                          );
                          _checkDayEdgeDwell(local.dy, config.totalGridHeight);
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
                      key: _dayGridKey,
                      height: config.totalGridHeight,
                      child: Stack(
                        children: [
                          TimelineDayColumn(
                            dayDate: widget.dayDate,
                            items: timedItems,
                            config: config,
                            interactionController: widget.interactionController,
                            onItemTap: widget.onItemTap,
                            onSlotSecondaryTap: widget.onSlotSecondaryTap,
                            alarmRules: widget.alarmRules,
                            colorResolver: widget.colorResolver,
                            scrollController: _scrollController,
                            resolveDayAt: (_) => widget.dayDate,
                            onInteractionFinished: widget.onInteractionFinished,
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
                                          _pendingDwellDirection != null &&
                                                  _pendingDwellDirection! > 0
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 14,
                                          color: scheme.onInverseSurface,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _edgeDwellMessage!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onInverseSurface,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUntimedHeader(List<CalendarItem> items, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.event_note, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'All-day & Planned (${items.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final item in items) _buildUntimedChip(item, scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUntimedChip(CalendarItem item, ColorScheme scheme) {
    final accent = widget.colorResolver != null
        ? widget.colorResolver!(item)
        : (item.colorValue != null ? Color(item.colorValue!) : scheme.primary);
    final background = Color.alphaBlend(
      Color.lerp(scheme.surface, accent, 0.15)!,
      scheme.surface,
    );
    final primary = TimelineDayColumn.contrastAwareTextColor(
      background: background,
      scheme: scheme,
    );
    final secondary = TimelineDayColumn.contrastAwareTextColor(
      background: background,
      scheme: scheme,
      isPrimary: false,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => widget.onItemTap(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.kind == CalendarItemKind.event
                  ? iconForKey(item.iconName, Icons.event_outlined)
                  : Icons.task_alt_outlined,
              size: 12,
              color: accent,
            ),
            const SizedBox(width: 4),
            if (item.allDay) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'All day',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    if (item.detailsText != null)
                      Text(
                        item.detailsText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (item.detailsText != null) ...[
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.subtitle != null
                            ? '${item.subtitle} · ${item.title}\n'
                            : '${item.title}\n',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      TextSpan(
                        text: item.detailsText!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              Flexible(
                child: Text(
                  item.subtitle != null
                      ? '${item.subtitle} · ${item.title}'
                      : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
