import 'package:flutter/material.dart';

class AlarmIndicator extends StatelessWidget {
  const AlarmIndicator({super.key});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Alarm configured',
    child: Icon(
      Icons.alarm_outlined,
      size: 16,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      semanticLabel: 'Alarm configured',
    ),
  );
}
