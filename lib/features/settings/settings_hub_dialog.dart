import '../shared/scroll_edge_fade.dart';

import 'package:life_manager/features/shared/anchored_select_field.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/appearance.dart';
import '../widget/native_widget_service.dart';
import 'backups_cloud_page.dart';
import 'settings_transfer_dialog.dart';
import 'hotkeys_dialog.dart';
import 'notification_dialog.dart';
import 'privacy_dialog.dart';
import 'task_view_settings_dialog.dart';
import 'theme_dialog.dart';
import 'sidebar_order_dialog.dart';
import 'software_updates_page.dart';
import 'widget_settings_page.dart';
import '../../domain/widget_configuration.dart';

enum _SettingsPage {
  appearance('Appearance & Themes', Icons.palette_outlined),
  hotkeys('Hotkeys', Icons.keyboard_outlined),
  tasks('Task Preferences', Icons.task_alt_outlined),
  navigation('Navigation & Calendar', Icons.calendar_month_outlined),
  notifications('Notifications', Icons.notifications_outlined),
  widget('Widget', Icons.widgets_outlined),
  privacy('Privacy & Data', Icons.lock_outline),
  backups('Backups & Cloud', Icons.backup_outlined),
  updates('Software Updates', Icons.system_update_outlined);

  const _SettingsPage(this.title, this.icon);
  final String title;
  final IconData icon;
}

class SettingsHubDialog extends ConsumerStatefulWidget {
  const SettingsHubDialog({
    super.key,
    required this.nativeWidget,
    required this.showDataProfile,
    this.openBackups = false,
    this.editWidget,
    this.widgetController,
  });
  final NativeWidgetService nativeWidget;
  final VoidCallback showDataProfile;
  final bool openBackups;
  final DesktopWidgetKind? editWidget;
  final WidgetSettingsController? widgetController;

  @override
  ConsumerState<SettingsHubDialog> createState() => _SettingsHubDialogState();
}

class _SettingsHubDialogState extends ConsumerState<SettingsHubDialog> {
  _SettingsPage page = _SettingsPage.appearance;
  @override
  void initState() {
    super.initState();
    if (widget.openBackups) page = _SettingsPage.backups;
    if (widget.editWidget != null) page = _SettingsPage.widget;
    widget.widgetController?.addListener(_widgetRequest);
  }

  void _widgetRequest() {
    if (mounted) setState(() => page = _SettingsPage.widget);
  }

  @override
  void dispose() {
    widget.widgetController?.removeListener(_widgetRequest);
    super.dispose();
  }

  Future<void> _open(Widget dialog) =>
      showDialog<void>(context: context, builder: (_) => dialog);

  Widget _action(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? action,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: action,
  );

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 650;
    return Dialog(
      child: SizedBox(
        width: math.min(920, size.width - 48),
        height: math.min(720, size.height - 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Settings',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: narrow
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: AnchoredSelectField<_SettingsPage>(
                            initialValue: page,
                            decoration: const InputDecoration(
                              labelText: 'Settings section',
                            ),
                            items: [
                              for (final item in _SettingsPage.values)
                                DropdownMenuItem(
                                  value: item,
                                  child: Text(item.title),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => page = value);
                            },
                          ),
                        ),
                        Expanded(child: _content(controller)),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 205,
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              for (final item in _SettingsPage.values)
                                ListTile(
                                  dense: true,
                                  selected: page == item,
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  leading: Icon(item.icon, size: 20),
                                  title: Text(item.title),
                                  onTap: () => setState(() => page = item),
                                ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: _content(controller)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppController controller) => FadingListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
    children: [
      Text(page.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      switch (page) {
        _SettingsPage.appearance => Column(
          children: [
            SegmentedButton<ThemeModePreference>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeModePreference.system,
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeModePreference.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeModePreference.dark,
                  label: Text('Dark'),
                ),
              ],
              selected: {controller.theme},
              onSelectionChanged: (value) => controller.setTheme(value.first),
            ),
            const SizedBox(height: 12),
            _action(
              'Customize Theme',
              'Colors, presets, text scale, density, layout, and import/export',
              Icons.tune,
              () => _open(const ThemeDialog()),
            ),
            const SizedBox(height: 12),
            _action(
              'Share settings',
              'Export or import selected personalization as JSON',
              Icons.ios_share_outlined,
              () => _open(const SettingsTransferDialog()),
            ),
          ],
        ),
        _SettingsPage.hotkeys => _action(
          'Edit hotkeys',
          'Search, change bindings, resolve conflicts, and manage presets',
          Icons.keyboard_outlined,
          () => _open(const HotkeysDialog()),
        ),
        _SettingsPage.tasks => _action(
          'Task display and defaults',
          'Default date, completed tasks, inline spelling, and checklist text',
          Icons.task_alt_outlined,
          () => _open(const TaskViewSettingsDialog()),
        ),
        _SettingsPage.navigation => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _action(
              'Sidebar order',
              'Reorder the main navigation items',
              Icons.reorder,
              () => _open(const SidebarOrderDialog()),
            ),
            const SizedBox(height: 12),
            AnchoredSelectField<int>(
              key: ValueKey(controller.firstWeekday),
              initialValue: controller.firstWeekday,
              decoration: const InputDecoration(
                labelText: 'First day of the week',
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('Sunday')),
                DropdownMenuItem(value: 1, child: Text('Monday')),
                DropdownMenuItem(value: 2, child: Text('Tuesday')),
                DropdownMenuItem(value: 3, child: Text('Wednesday')),
                DropdownMenuItem(value: 4, child: Text('Thursday')),
                DropdownMenuItem(value: 5, child: Text('Friday')),
                DropdownMenuItem(value: 6, child: Text('Saturday')),
              ],
              onChanged: (value) {
                if (value != null) controller.setFirstWeekday(value);
              },
            ),
          ],
        ),
        _SettingsPage.notifications => _action(
          'Reminder settings',
          'Reminders and daily summary delivery',
          Icons.notifications_outlined,
          () => _open(const NotificationDialog()),
        ),
        _SettingsPage.widget => WidgetSettingsPage(
          service: widget.nativeWidget,
          initialKind: widget.widgetController?.kind ?? widget.editWidget,
          requestRevision: widget.widgetController?.revision ?? 0,
        ),
        _SettingsPage.privacy => Column(
          children: [
            _action(
              'Privacy and app lock',
              'PIN and privacy controls',
              Icons.lock_outline,
              () => _open(const PrivacyDialog()),
            ),
            if (Platform.isWindows)
              _action(
                'Data profile and location',
                'See which local profile is active',
                Icons.folder_outlined,
                widget.showDataProfile,
              ),
          ],
        ),
        _SettingsPage.updates => SoftwareUpdatesPage(
          nativeWidget: widget.nativeWidget,
        ),
        _SettingsPage.backups => const BackupsCloudPage(),
      },
    ],
  );
}
