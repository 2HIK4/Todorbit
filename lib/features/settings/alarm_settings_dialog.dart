import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/alarm_device_store.dart';
import '../../platform/android/android_platform.dart';
import '../widget/native_widget_service.dart';

class AlarmSettingsDialog extends StatefulWidget {
  const AlarmSettingsDialog({super.key});
  @override
  State<AlarmSettingsDialog> createState() => _AlarmSettingsState();
}

class _AlarmSettingsState extends State<AlarmSettingsDialog>
    with WidgetsBindingObserver {
  final store = AlarmDeviceStore.active();
  bool? enabled;
  bool? exact;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final value = await store.enabled();
      final access = Platform.isAndroid
          ? await AndroidPlatform.alarmAccess()
          : null;
      if (mounted) {
        setState(() {
          enabled = value;
          exact = access;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Alarm settings could not be read. Keep this profile and retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Alarms on this device'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabled == null && error == null)
            const CircularProgressIndicator(),
          if (enabled != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deliver configured alarms'),
              subtitle: const Text(
                'Other devices keep their own delivery settings.',
              ),
              value: enabled!,
              onChanged: busy
                  ? null
                  : (value) async {
                      setState(() => busy = true);
                      try {
                        await store.save(value);
                        if (Platform.isAndroid) {
                          await AndroidPlatform.channel.invokeMethod<void>(
                            'alarmSettingsChanged',
                          );
                        }
                        if (mounted) setState(() => enabled = value);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => error = 'The setting was not saved. Check available storage and retry.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          if (Platform.isAndroid) ...[
            Text(
              exact == true ? 'Exact alarm access is allowed.' : 'Exact alarm access is off. Delivery can be delayed; fallback notifications may use a single sound.',
            ),
            TextButton(
              onPressed: AndroidPlatform.requestAlarmAccess,
              child: const Text('Review exact alarm access'),
            ),
            TextButton(
              onPressed: AndroidPlatform.openNotificationSettings,
              child: const Text('Notification and sound settings'),
            ),
            const Text(
              'Force-stop, denied notifications, Do Not Disturb and battery/OEM restrictions can prevent delivery. Open Todorbit after reboot if required.',
            ),
          ] else ...[
            const Text(
              'Keep the Todorbit tray companion running. Alarms cannot wake a powered-off or sleeping PC; missed alarms have a five-minute grace period.',
            ),
            for (final enable in [true, false])
              TextButton(
                onPressed: NativeWidgetService().isAvailable && !busy
                    ? () async {
                        setState(() => busy = true);
                        try {
                          await NativeWidgetService().ensureRemindersRunning();
                          await NativeWidgetService().setLaunchAtSignIn(enable);
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => error = 'Startup could not be changed. Review the tray companion.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      }
                    : null,
                child: Text(
                  enable
                      ? 'Enable companion at Windows sign-in'
                      : 'Disable companion at Windows sign-in',
                ),
              ),
          ],
          const Text(
            'Sound stops after the selected duration. Snooze changes only local delivery, never task dates. Existing alarm rules and backups are kept.',
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
