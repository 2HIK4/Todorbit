import 'package:flutter/material.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';

enum CalendarRecurringMoveAction {
  thisOccurrence,
  entireSeries,
  editInEditor,
  cancel,
}

class RecurringEventMoveDialog extends StatelessWidget {
  const RecurringEventMoveDialog({
    super.key,
    required this.event,
    required this.master,
    required this.originStart,
    required this.targetStart,
    required this.interactionController,
    this.seriesMoveProblem,
    this.targetEnd,
  });

  final FixedEvent event;
  final FixedEvent master;
  final DateTime originStart;
  final DateTime targetStart;
  final CalendarInteractionController interactionController;
  final String? seriesMoveProblem;
  final DateTime? targetEnd;

  static const _fullWeekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _monthNames = [
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

  static String formatRecurrence(EventRepeat? repeat, DateTime startsAt) {
    final until = repeat?.untilDate;
    return '${_formatRecurrence(repeat, startsAt)}${until == null ? '' : ' through $until'}';
  }

  static String _formatRecurrence(EventRepeat? repeat, DateTime startsAt) {
    if (repeat == null) return 'Does not repeat';
    final timeStr = _formatTime(startsAt);
    switch (repeat.kind) {
      case EventRepeatKind.daily:
        final intervalStr = repeat.interval > 1
            ? 'every ${repeat.interval} days'
            : 'every day';
        return 'Repeats $intervalStr at $timeStr';
      case EventRepeatKind.weekly:
        final weekdayName = _fullWeekdayNames[startsAt.weekday - 1];
        final intervalStr = repeat.interval > 1
            ? 'every ${repeat.interval} weeks on $weekdayName'
            : 'every $weekdayName';
        return 'Repeats $intervalStr at $timeStr';
      case EventRepeatKind.weekdays:
        if (repeat.weekdays.isEmpty) {
          return 'Repeats at $timeStr';
        }
        final sorted = repeat.weekdays.toList()..sort();
        final dayNames = sorted.map((d) => _fullWeekdayNames[d - 1]).join(', ');
        final intervalStr = repeat.interval > 1
            ? 'every ${repeat.interval} weeks on $dayNames'
            : 'every $dayNames';
        return 'Repeats $intervalStr at $timeStr';
      case EventRepeatKind.monthly:
        final intervalStr = repeat.interval > 1
            ? 'every ${repeat.interval} months'
            : 'monthly';
        return 'Repeats $intervalStr on day ${startsAt.day} at $timeStr';
      case EventRepeatKind.yearly:
        final intervalStr = repeat.interval > 1
            ? 'every ${repeat.interval} years'
            : 'yearly';
        return 'Repeats $intervalStr on ${_monthNames[startsAt.month - 1]} ${startsAt.day} at $timeStr';
    }
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDate(DateTime dt) {
    final weekday = _fullWeekdayNames[dt.weekday - 1];
    final month = _monthNames[dt.month - 1];
    return '$weekday, $month ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proposedRepeat = interactionController.calculateProposedSeriesRepeat(
      master: master,
      proposedStart: targetStart,
      originStart: originStart,
    );

    final currentRecurrenceText = formatRecurrence(
      master.repeat,
      master.startsAt.toLocal(),
    );
    final proposedRecurrenceText = formatRecurrence(
      proposedRepeat,
      interactionController.proposedSeriesStart(
        master,
        originStart,
        targetStart,
      ),
    );

    final isMultiWeekdayAmbiguous =
        master.repeat?.kind == EventRepeatKind.weekdays &&
        (master.repeat?.weekdays.length ?? 0) > 1 &&
        !master.repeat!.weekdays.contains(targetStart.weekday);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.event_repeat, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              interactionController.gestureKind ==
                          CalendarGestureKind.resizeStart ||
                      interactionController.gestureKind ==
                          CalendarGestureKind.resizeEnd
                  ? 'Resize recurring event'
                  : 'Move recurring event',
            ),
          ),
        ],
      ),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              master.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This occurrence:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      '${_formatDate(originStart)} ${_formatTime(originStart)}  →  ${_formatDate(targetStart)} ${_formatTime(targetStart)}${targetEnd == null ? '' : '\nEnds ${_formatDate(targetEnd!.toLocal())} ${_formatTime(targetEnd!.toLocal())}'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Entire series proposed rule:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposedRecurrenceText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Current: $currentRecurrenceText',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMultiWeekdayAmbiguous) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Text(
                        'Notice: Moving all occurrences of a multi-day schedule shifts the whole pattern. You can also customize repeat days in the Event Editor.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    seriesMoveProblem ?? 'Entire series also changes past occurrences. Monthly and yearly dates use the last day when a month is shorter.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, CalendarRecurringMoveAction.cancel),
          child: const Text('Cancel'),
        ),
        if (isMultiWeekdayAmbiguous || seriesMoveProblem != null)
          TextButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Customize in Editor'),
            onPressed: () => Navigator.pop(
              context,
              CalendarRecurringMoveAction.editInEditor,
            ),
          ),
        OutlinedButton(
          onPressed: () => Navigator.pop(
            context,
            CalendarRecurringMoveAction.thisOccurrence,
          ),
          child: const Text('This occurrence only'),
        ),
        FilledButton(
          onPressed: seriesMoveProblem != null
              ? null
              : () => Navigator.pop(
                  context,
                  CalendarRecurringMoveAction.entireSeries,
                ),
          child: const Text('Entire series'),
        ),
      ],
    );
  }
}
