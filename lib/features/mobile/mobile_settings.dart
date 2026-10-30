import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/mobile_preference_store.dart';
import '../../domain/appearance.dart';
import '../../domain/models.dart';
import '../../platform/android/android_platform.dart';
import '../settings/backups_cloud_page.dart';
import '../settings/android_software_updates_page.dart';
import '../settings/privacy_dialog.dart';
import '../settings/task_view_settings_dialog.dart';
import '../settings/theme_dialog.dart';
import '../settings/notification_dialog.dart';
import '../shared/sidebar_items.dart';
import '../shared/weekdays.dart';

class MobileSettings extends ConsumerStatefulWidget {
  const MobileSettings({
    super.key,
    required this.store,
    required this.preferences,
    required this.onChanged,
  });
  final MobilePreferenceStore store;
  final MobilePreferences preferences;
  final ValueChanged<MobilePreferences> onChanged;
  @override
  ConsumerState<MobileSettings> createState() => _MobileSettingsState();
}

class _MobileSettingsState extends ConsumerState<MobileSettings>
    with WidgetsBindingObserver {
  late MobilePreferences preferences = widget.preferences;
  bool? notifications;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(run(refreshPermissions));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(run(refreshPermissions));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refreshPermissions() async {
    final allowed = await AndroidPlatform.notificationsAllowed();
    if (mounted) setState(() => notifications = allowed);
  }

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings could not be changed: $e')),
        );
      }
    }
  }

  Future<void> save(MobilePreferences next) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.store.save(next);
      await ref.read(appControllerProvider).refresh();
      if (mounted) {
        setState(() => preferences = next);
        widget.onChanged(next);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> show(Widget child) =>
      showDialog<void>(context: context, builder: (_) => child);

  Future<void> navigation() async {
    var draft = List.of(preferences.destinations);
    final result = await showDialog<List<WorkspaceView>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Mobile navigation'),
          scrollable: true,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose three or four destinations. Use the arrows to order them.',
                ),
                for (final v in MobilePreferences.supported)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sidebarName(v)),
                    value: draft.contains(v),
                    onChanged: (value) => update(() {
                      if (value == true && draft.length < 4) draft.add(v);
                      if (value == false && draft.length > 3) draft.remove(v);
                    }),
                  ),
                const Divider(),
                for (var i = 0; i < draft.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${i + 1}. ${sidebarName(draft[i])}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: i == 0
                              ? null
                              : () => update(() {
                                  final v = draft.removeAt(i);
                                  draft.insert(i - 1, v);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: i == draft.length - 1
                              ? null
                              : () => update(() {
                                  final v = draft.removeAt(i);
                                  draft.insert(i + 1, v);
                                }),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await run(() => save(preferences.copyWith(destinations: result)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<ThemeModePreference>(
              isExpanded: true,
              initialValue: c.theme,
              decoration: const InputDecoration(labelText: 'Theme'),
              items: [
                for (final t in ThemeModePreference.values)
                  DropdownMenuItem(
                    value: t,
                    child: Text(
                      t == ThemeModePreference.system
                          ? 'Follow system'
                          : t.name,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) run(() => c.setTheme(v));
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Colors and custom themes'),
              onTap: () => show(const ThemeDialog()),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Task display and defaults'),
              onTap: () => show(const TaskViewSettingsDialog()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.navigation_outlined),
              title: const Text('Mobile navigation'),
              subtitle: const Text('Destinations and order'),
              onTap: saving ? null : navigation,
            ),
            DropdownButtonFormField<WorkspaceView>(
              isExpanded: true,
              initialValue: preferences.start,
              decoration: const InputDecoration(labelText: 'Open on launch'),
              items: [
                for (final v in MobilePreferences.supported)
                  DropdownMenuItem(value: v, child: Text(sidebarName(v))),
              ],
              onChanged: saving
                  ? null
                  : (v) {
                      if (v != null) {
                        run(() => save(preferences.copyWith(start: v)));
                      }
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CalendarContent>(
              isExpanded: true,
              initialValue: c.calendarContent,
              decoration: const InputDecoration(labelText: 'Calendar content'),
              items: [
                for (final v in CalendarContent.values)
                  DropdownMenuItem(
                    value: v,
                    child: Text(switch (v) {
                      CalendarContent.both => 'Tasks and events',
                      CalendarContent.eventsOnly => 'Events',
                      CalendarContent.tasksOnly => 'Tasks and sessions',
                    }),
                  ),
              ],
              onChanged: (v) {
                if (v != null) run(() => c.setCalendarContent(v));
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: c.firstWeekday,
              decoration: const InputDecoration(labelText: 'First day of week'),
              items: [
                for (var i = 1; i <= 7; i++)
                  DropdownMenuItem(value: i, child: Text(weekdayNames[i - 1])),
              ],
              onChanged: (v) {
                if (v != null) run(() => c.setFirstWeekday(v));
              },
            ),
            const Divider(height: 32),
            Text(
              'Notifications and privacy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notification permission'),
              subtitle: Text(
                notifications == true
                    ? 'Allowed. Enable reminders separately on each task or event.'
                    : 'Off until you allow notifications. Task reminders are off by default.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: Platform.isAndroid
                  ? () => run(() async {
                      await AndroidPlatform.requestNotifications();
                      await refreshPermissions();
                    })
                  : null,
            ),
            if (Platform.isAndroid)
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Android notification settings'),
                subtitle: const Text(
                  'Allow previously denied permission, or change channel sound and visibility.',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => run(AndroidPlatform.openNotificationSettings),
              ),
            ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Daily summary and due reminders'),
              subtitle: const Text(
                'Optional daily reminders and delivery time',
              ),
              onTap: () => show(const NotificationDialog()),
            ),
            SwitchListTile(
              title: const Text('Quiet hours'),
              subtitle: const Text('Hold reminders until quiet hours end.'),
              value: preferences.quietHours,
              onChanged: saving
                  ? null
                  : (v) => run(() => save(preferences.copyWith(quietHours: v))),
            ),
            if (preferences.quietHours)
              for (final start in [true, false])
                ListTile(
                  title: Text(start ? 'Quiet hours start' : 'Quiet hours end'),
                  subtitle: Text(
                    TimeOfDay(
                      hour:
                          (start
                              ? preferences.quietStart
                              : preferences.quietEnd) ~/
                          60,
                      minute:
                          (start
                              ? preferences.quietStart
                              : preferences.quietEnd) %
                          60,
                    ).format(context),
                  ),
                  onTap: () async {
                    final current = start
                        ? preferences.quietStart
                        : preferences.quietEnd;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: current ~/ 60,
                        minute: current % 60,
                      ),
                    );
                    if (t != null) {
                      await run(
                        () => save(
                          start
                              ? preferences.copyWith(
                                  quietStart: t.hour * 60 + t.minute,
                                )
                              : preferences.copyWith(
                                  quietEnd: t.hour * 60 + t.minute,
                                ),
                        ),
                      );
                    }
                  },
                ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('PIN and app lock'),
              onTap: () => show(const PrivacyDialog()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backups and Google Drive'),
              subtitle: const Text(
                'Verified snapshots. Restore replaces data; devices do not sync.',
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Backups')),
                    body: const SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: BackupsCloudPage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Software Updates'),
              subtitle: const Text(
                'Check Android releases, download and install updates.',
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AndroidSoftwareUpdatesPage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Home-screen widgets'),
              subtitle: const Text(
                'Long press your launcher, choose Widgets, then Todorbit Tasks or Calendar. Configure each widget when adding it.',
              ),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'Todorbit ${String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: 'development')} '
                '(${String.fromEnvironment('FLUTTER_BUILD_NUMBER', defaultValue: 'unknown')})',
              ),
              subtitle: Text(
                'Local-first productivity\nOpen Software Updates to check for Android releases.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
