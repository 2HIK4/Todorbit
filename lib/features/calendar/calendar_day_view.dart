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
  });

  final DateTime dayDate;
  final List<CalendarItem> items;
  final CalendarAppearanceConfiguration config;
  final CalendarInteractionController interactionController;
  final void Function(CalendarItem item) onItemTap;
  final void Function(DateTime slotTime, Offset globalPosition) onSlotSecondaryTap;
  final List<AlarmRule> alarmRules;
  final Color Function(CalendarItem item)? colorResolver;
  final Future<void> Function()? onInteractionFinished;

  @override
  State<CalendarDayView> createState() => _CalendarDayViewState();
}

class _CalendarDayViewState extends State<CalendarDayView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final initialY = widget.config.initialScrollHour * widget.config.hourHeight;
        _scrollController.jumpTo(
          initialY.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        if (untimedItems.isNotEmpty)
          _buildUntimedHeader(untimedItems, scheme),

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
                      for (var hour = config.startHour; hour < config.endHour; hour++)
                        Positioned(
                          top: (hour - config.startHour) * config.hourHeight - 8,
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
                  child: TimelineDayColumn(
                    dayDate: widget.dayDate,
                    items: timedItems,
                    config: config,
                    interactionController: widget.interactionController,
                    onItemTap: widget.onItemTap,
                    onSlotSecondaryTap: widget.onSlotSecondaryTap,
                    alarmRules: widget.alarmRules,
                    colorResolver: widget.colorResolver,
                    scrollController: _scrollController,
                    onInteractionFinished: widget.onInteractionFinished,
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
              for (final item in items)
                _buildUntimedChip(item, scheme),
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

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => widget.onItemTap(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, accent, 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent.withValues(alpha: 0.5),
            width: 1,
          ),
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
            Text(
              item.subtitle != null
                  ? '${item.subtitle} · ${item.title}'
                  : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
