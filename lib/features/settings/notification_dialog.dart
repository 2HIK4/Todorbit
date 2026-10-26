import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/life_repository.dart';
import '../../domain/notifications.dart';
import '../widget/native_widget_service.dart';
import '../shared/settings_section.dart';

class NotificationDialog extends ConsumerStatefulWidget {
  const NotificationDialog({super.key, this.service});

  final NativeWidgetService? service;

  @override
  ConsumerState<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends ConsumerState<NotificationDialog> {
  late final companion = widget.service ?? NativeWidgetService();
  NotificationSettings settings = const NotificationSettings();
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref
          .read(appControllerProvider)
          .repository
          .notificationSettings();
      if (mounted) {
        setState(() {
          settings = value;
          loading = false;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '$failure';
          loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (settings.enabled) await companion.ensureRemindersRunning();
      await ref
          .read(appControllerProvider)
          .repository
          .saveNotificationSettings(settings);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '$failure';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(
      hour: settings.localMinute ~/ 60,
      minute: settings.localMinute % 60,
    );
    return AlertDialog(
      title: const Text('Notifications'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsHelperText(
                    'Off by default. The Windows tray companion delivers reminders while it is running, even when the main window is closed.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due task reminders'),
                    subtitle: const Text('Open tasks due today or overdue.'),
                    value: settings.dueReminders,
                    onChanged: companion.isAvailable && !saving
                        ? (value) => setState(
                            () => settings = NotificationSettings(
                              dueReminders: value,
                              dailySummary: settings.dailySummary,
                              localMinute: settings.localMinute,
                            ),
                          )
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Daily summary'),
                    subtitle: const Text('Counts of planned and due tasks.'),
                    value: settings.dailySummary,
                    onChanged: companion.isAvailable && !saving
                        ? (value) => setState(
                            () => settings = NotificationSettings(
                              dueReminders: settings.dueReminders,
                              dailySummary: value,
                              localMinute: settings.localMinute,
                            ),
                          )
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: companion.isAvailable && !saving
                        ? () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: time,
                            );
                            if (picked != null && mounted) {
                              setState(
                                () => settings = NotificationSettings(
                                  dueReminders: settings.dueReminders,
                                  dailySummary: settings.dailySummary,
                                  localMinute: picked.hour * 60 + picked.minute,
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('Local delivery time: ${time.format(context)}'),
                  ),
                  const SettingsHelperText(
                    'Each type is sent at most once per local day, within an hour of the selected time. Windows notification settings may affect visibility.',
                  ),
                  if (!companion.isAvailable)
                    const Text(
                      'The packaged Windows tray companion is unavailable.',
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              loading || saving || (!companion.isAvailable && settings.enabled)
              ? null
              : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
