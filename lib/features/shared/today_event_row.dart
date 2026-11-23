import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'alarm_indicator.dart';
import 'app_spacing.dart';

/// Displays a fixed commitment and delegates opening it to its workspace.
class TodayEventRow extends StatelessWidget {
  const TodayEventRow({
    super.key,
    required this.event,
    required this.onOpen,
    this.hasAlarm = false,
    this.showDate = false,
  });

  final FixedEvent event;
  final bool hasAlarm;
  final bool showDate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    String time(DateTime instant) => localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(instant),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final start = event.startsAt.toLocal();
    final end = event.endsAt.toLocal();
    final range = DateUtils.isSameDay(start, end)
        ? '${time(start)}–${time(end)}'
        : '${localizations.formatShortDate(start)} ${time(start)} – '
              '${localizations.formatShortDate(end)} ${time(end)}';
    return ListTile(
      dense: theme.platform == TargetPlatform.windows,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.related,
      ),
      leading: const Icon(Icons.event_outlined),
      title: Text(event.title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        showDate && (event.allDay || DateUtils.isSameDay(start, end))
            ? '${localizations.formatShortDate(start)} · ${event.allDay ? 'All day' : range}'
            : event.allDay
            ? 'All day'
            : range,
        style: theme.textTheme.bodySmall,
      ),
      trailing: hasAlarm ? const AlarmIndicator() : null,
      onTap: onOpen,
    );
  }
}
