import 'package:flutter/material.dart';

import '../../domain/alarms.dart';
import 'anchored_select_field.dart';
import 'app_motion.dart';

/// Optional, draft-only alarm editor shared by tasks and events.
class AlarmField extends StatelessWidget {
  const AlarmField({
    super.key,
    required this.value,
    required this.onChanged,
    this.event = false,
    this.recurring = false,
    this.allowCustom = true,
  });
  final AlarmConfig value;
  final ValueChanged<AlarmConfig> onChanged;
  final bool event;
  final bool recurring;
  final bool allowCustom;

  @override
  Widget build(BuildContext context) {
    if (!value.enabled) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.alarm_add_outlined),
          label: const Text('Add alarm'),
          onPressed: () => onChanged(
            value.copyWith(
              mode: event
                  ? 'relative'
                  : recurring
                  ? 'planned'
                  : 'custom',
              at: DateTime.now().add(const Duration(minutes: 30)).toUtc(),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.alarm),
            const SizedBox(width: 8),
            const Expanded(child: Text('Alarm')),
            IconButton(
              tooltip: 'Remove alarm',
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(const AlarmConfig()),
            ),
          ],
        ),
        AnchoredSelectField<String>(
          key: ValueKey('alarm-mode-${value.mode}'),
          initialValue: value.mode,
          decoration: const InputDecoration(labelText: 'When'),
          items: [
            if ((allowCustom && (!event || !recurring)) ||
                value.mode == 'custom')
              DropdownMenuItem(
                value: 'custom',
                enabled: allowCustom && (!event || !recurring),
                child: Text(
                  event && recurring
                      ? 'Exact time needs a single occurrence'
                      : 'Exact date and time',
                ),
              ),
            if (event)
              const DropdownMenuItem(
                value: 'relative',
                child: Text('At or before event start'),
              ),
            if (!event) ...[
              const DropdownMenuItem(
                value: 'planned',
                child: Text('On the planned day'),
              ),
              const DropdownMenuItem(
                value: 'relative',
                child: Text('At or before next work session'),
              ),
            ],
          ],
          onChanged: (v) {
            if (v != null) onChanged(value.copyWith(mode: v));
          },
        ),
        if (value.mode == 'custom')
          TextButton.icon(
            icon: const Icon(Icons.event),
            label: Text(
              value.at?.toLocal().toString().substring(0, 16) ??
                  'Choose date and time',
            ),
            onPressed: () async {
              final now = DateTime.now();
              final initial = value.at?.toLocal() ?? now;
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
              if (time != null && context.mounted) {
                onChanged(
                  value.copyWith(
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
        if (value.mode == 'planned')
          TextButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(
              TimeOfDay(
                hour: value.localMinute ~/ 60,
                minute: value.localMinute % 60,
              ).format(context),
            ),
            onPressed: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: value.localMinute ~/ 60,
                  minute: value.localMinute % 60,
                ),
              );
              if (time != null && context.mounted) {
                onChanged(
                  value.copyWith(localMinute: time.hour * 60 + time.minute),
                );
              }
            },
          ),
        if (value.mode != 'custom')
          AnchoredSelectField<int>(
            key: ValueKey('alarm-offset-${value.minutesBefore}'),
            initialValue: value.minutesBefore,
            decoration: const InputDecoration(labelText: 'Advance'),
            items: [
              for (final n in {0, 5, 10, 15, 30, 60, value.minutesBefore})
                DropdownMenuItem(
                  value: n,
                  child: Text(
                    n == 0 ? 'At the selected time' : '$n minutes before',
                  ),
                ),
              const DropdownMenuItem(value: -1, child: Text('Custom advance…')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              if (v >= 0) {
                onChanged(value.copyWith(minutesBefore: v));
                return;
              }
              final input = TextEditingController(
                text: value.minutesBefore.toString(),
              );
              final route = DialogRoute<int>(
                context: context,
                animationStyle: AppMotion.style(context),
                builder: (context) => StatefulBuilder(
                  builder: (context, update) {
                    final n = int.tryParse(input.text);
                    final valid = n != null && n >= 0 && n <= 10080;
                    return AlertDialog(
                      title: const Text('Minutes before'),
                      content: TextField(
                        controller: input,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => update(() {}),
                        decoration: InputDecoration(
                          labelText: '0-10080 minutes',
                          errorText: valid
                              ? null
                              : 'Enter a whole number from 0 to 10080.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: valid
                              ? () => Navigator.pop(context, n)
                              : null,
                          child: const Text('Apply'),
                        ),
                      ],
                    );
                  },
                ),
              );
              final picked = await Navigator.of(context).push(route);
              await route.completed;
              input.dispose();
              // The route owns the field through its exit transition.
              if (picked != null && context.mounted) {
                onChanged(value.copyWith(minutesBefore: picked));
              }
            },
          ),
        if (recurring)
          const Text(
            'Planned-day and session timing repeats for each occurrence. An exact date applies only to the first occurrence.',
          ),
        ExpansionTile(
          title: const Text('Sound and options'),
          tilePadding: EdgeInsets.zero,
          children: [
            AnchoredSelectField<String>(
              key: ValueKey('alarm-sound-${value.sound}'),
              initialValue: value.sound,
              decoration: const InputDecoration(labelText: 'System sound'),
              items: const [
                DropdownMenuItem(value: 'alarm', child: Text('Alarm')),
                DropdownMenuItem(
                  value: 'notification',
                  child: Text('Notification'),
                ),
                DropdownMenuItem(
                  value: 'ringtone',
                  child: Text('Ringtone / bell'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(value.copyWith(sound: v));
              },
            ),
            AnchoredSelectField<int>(
              key: ValueKey('alarm-duration-${value.durationSeconds}'),
              initialValue: value.durationSeconds,
              decoration: const InputDecoration(labelText: 'Stop sound after'),
              items: [
                for (final n in [15, 30, 60, 120])
                  DropdownMenuItem(value: n, child: Text('$n seconds')),
              ],
              onChanged: (v) {
                if (v != null) onChanged(value.copyWith(durationSeconds: v));
              },
            ),
            SwitchListTile(
              title: const Text('Vibrate on Android'),
              value: value.vibrate,
              onChanged: (v) => onChanged(value.copyWith(vibrate: v)),
            ),
            const Text(
              'Snooze: 5, 10 or 15 minutes. Each device delivers its own alarms. Notification, quiet-hour and system restrictions apply.',
            ),
          ],
        ),
      ],
    );
  }
}
