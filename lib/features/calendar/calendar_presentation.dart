import 'package:flutter/material.dart';

/// Display dates only. Calendar queries and recurrence use their existing date keys.
String calendarPeriodLabel(
  MaterialLocalizations local,
  DateTime date, {
  DateTime? weekStart,
  bool month = false,
}) {
  if (month) return local.formatMonthYear(date);
  if (weekStart == null) return local.formatFullDate(date);
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  final beginLabel = weekStart.year == end.year
      ? local.formatShortMonthDay(weekStart)
      : local.formatShortDate(weekStart);
  return '$beginLabel – ${local.formatShortDate(end)}';
}

bool calendarUses24HourClock(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS => MediaQuery.alwaysUse24HourFormatOf(context),
      _ => true,
    };

String calendarTimeLabel(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: calendarUses24HourClock(context),
    );

class CalendarHourLabel extends StatelessWidget {
  const CalendarHourLabel(this.hour, {super.key});

  final int hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          calendarTimeLabel(context, DateTime(2000, 1, 1, hour)),
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
