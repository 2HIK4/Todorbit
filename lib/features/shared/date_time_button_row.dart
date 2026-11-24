import 'package:flutter/material.dart';

import 'app_spacing.dart';

class DateTimeButtonRow extends StatelessWidget {
  const DateTimeButtonRow({
    super.key,
    required this.dateLabel,
    required this.onDatePressed,
    this.dateKey,
    this.fieldLabel,
    this.timeLabel,
    this.onTimePressed,
    this.timeKey,
  });

  final String dateLabel;
  final VoidCallback onDatePressed;
  final Key? dateKey;
  final String? fieldLabel;
  final String? timeLabel;
  final VoidCallback? onTimePressed;
  final Key? timeKey;

  Widget _withTooltip(String part, Widget child) => fieldLabel == null
      ? child
      : Tooltip(message: 'Change $fieldLabel $part', child: child);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final date = _withTooltip(
        'date',
        OutlinedButton(
          key: dateKey,
          onPressed: onDatePressed,
          child: Text(dateLabel),
        ),
      );
      if (timeLabel == null) return date;
      final time = _withTooltip(
        'time',
        OutlinedButton(
          key: timeKey,
          onPressed: onTimePressed,
          child: Text(timeLabel!),
        ),
      );
      final minimum = 150 * MediaQuery.textScalerOf(context).scale(14) / 14;
      if ((bounds.maxWidth - AppSpacing.related) / 2 < minimum) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            date,
            const SizedBox(height: AppSpacing.related),
            time,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: date),
          const SizedBox(width: AppSpacing.related),
          Expanded(child: time),
        ],
      );
    },
  );
}
