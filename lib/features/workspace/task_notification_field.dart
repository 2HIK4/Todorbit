import 'package:flutter/material.dart';

import 'dart:io';

import '../../domain/notifications.dart';
import '../shared/anchored_select_field.dart';

class TaskNotificationField extends StatelessWidget {
  const TaskNotificationField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final TaskNotification value;
  final ValueChanged<TaskNotification> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AnchoredSelectField<String>(
        isExpanded: true,
        key: ValueKey('notification-${value.mode}'),
        initialValue: value.mode,
        decoration: const InputDecoration(labelText: 'Notifications'),
        items: const [
          DropdownMenuItem(value: 'off', child: Text('Off')),
          DropdownMenuItem(
            value: 'custom',
            child: Text('Custom date and time'),
          ),
          DropdownMenuItem(
            value: 'session',
            child: Text('At/before next scheduled session'),
          ),
        ],
        onChanged: (mode) {
          if (mode != null) {
            onChanged(
              TaskNotification(
                mode: mode,
                at: value.at,
                minutesBefore: value.minutesBefore,
              ),
            );
          }
        },
      ),
      if (value.mode == 'custom')
        TextButton.icon(
          icon: const Icon(Icons.schedule),
          label: Text(
            value.at == null
                ? 'Choose notification date and time'
                : value.at!.toLocal().toString().substring(0, 16),
          ),
          onPressed: () async {
            final initial = value.at?.toLocal() ?? DateTime.now();
            final day = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (day == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );
            if (time != null) {
              onChanged(
                TaskNotification(
                  mode: 'custom',
                  at: DateTime(
                    day.year,
                    day.month,
                    day.day,
                    time.hour,
                    time.minute,
                  ).toUtc(),
                ),
              );
            }
          },
        ),
      if (value.mode == 'session')
        AnchoredSelectField<int>(
          key: ValueKey('notification-offset-${value.minutesBefore}'),
          initialValue: value.minutesBefore,
          decoration: const InputDecoration(labelText: 'Notify'),
          items: [
            for (final n in {0, 5, 15, 30, 60, 1440, value.minutesBefore})
              DropdownMenuItem(
                value: n,
                child: Text(n == 0 ? 'At session start' : '$n minutes before'),
              ),
          ],
          onChanged: (n) {
            if (n != null) {
              onChanged(TaskNotification(mode: 'session', minutesBefore: n));
            }
          },
        ),
      if (value.enabled)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Off unless explicitly enabled. Relative timing uses the next upcoming work session; a planned day or deadline has no time. Recurring task reminders apply to this occurrence only. ${Platform.isAndroid ? 'Android may delay delivery while idle or battery restricted.' : 'Windows delivery requires the companion.'}',
          ),
        ),
    ],
  );
}
