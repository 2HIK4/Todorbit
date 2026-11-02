import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import 'sync_conflicts_dialog.dart';
import '../shared/settings_section.dart';
import '../shared/status_notice.dart';

Future<void> showSyncSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Sync'),
    scrollable: true,
    content: const SizedBox(width: 580, child: SyncSettingsPage()),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});
  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage>
    with WidgetsBindingObserver {
  final code = TextEditingController();
  final recoveryFocus = FocusNode();
  final recoveryField = GlobalKey();
  bool revealingField = false;
  String? revealed;
  SyncController? listening;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    recoveryFocus.addListener(_revealRecoveryField);
  }

  @override
  void didChangeMetrics() => _revealRecoveryField();

  void _revealRecoveryField() {
    if (!recoveryFocus.hasFocus || revealingField) return;
    revealingField = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      revealingField = false;
      if (!mounted || !recoveryFocus.hasFocus) return;
      final fieldContext = recoveryField.currentContext;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ref.read(syncControllerProvider);
    if (current != listening) {
      listening?.removeListener(_privacy);
      listening = current;
      current?.addListener(_privacy);
    }
  }

  void _privacy() {
    if (listening?.isUnlocked() == false) {
      code.clear();
      if (mounted) setState(() => revealed = null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recoveryFocus.dispose();
    listening?.removeListener(_privacy);
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(syncControllerProvider);
    if (controller == null) {
      return const Text('Sync is unavailable for this profile.');
    }
    if (!controller.isUnlocked()) {
      return const Text('Unlock Todorbit to manage synchronization.');
    }
    final busy =
        controller.busy || controller.status.phase == SyncPhase.syncing;
    final paired = controller.snapshot?.binding != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.sync),
          title: Text(controller.label),
          subtitle: Text(
            controller.auth.account?.label ?? 'Google Drive is disconnected',
          ),
        ),
        const SettingsHelperText(
          'Keep paired devices up to date with encrypted changes. Edits save locally immediately.',
        ),
        const SizedBox(height: 12),
        if (controller.auth.account == null)
          OutlinedButton.icon(
            onPressed: busy ? null : controller.connect,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Connect Google Drive'),
          ),
        if ((!paired || controller.snapshot?.quarantined == true) &&
            controller.auth.account != null) ...[
          StatusNotice(
            title: controller.snapshot?.quarantined == true
                ? 'Restore needs review'
                : 'Pair your devices',
            icon: Icons.key_outlined,
            message: controller.snapshot?.quarantined == true
                ? 'Restore paused synchronization. Reconcile with the original workspace to retain both restored records and pre-restore pending work. Enter the original recovery code if it is unavailable on this device. Automatic sync stays off until you enable it.'
                : 'Enter the recovery code from your other device. On your first device, leave it blank to create a workspace. A verified recovery backup is created before sync starts.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: recoveryField,
            focusNode: recoveryFocus,
            controller: code,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Workspace recovery code',
              helperText: 'Leave blank only for your first device.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final entered = code.text.trim();
                    if (controller.snapshot?.quarantined == true) {
                      await controller.reconcileRestored(
                        recoveryCode: entered.isEmpty ? null : entered,
                      );
                    } else {
                      await controller.activate(
                        recoveryCode: entered.isEmpty ? null : entered,
                      );
                    }
                    if (mounted && controller.snapshot?.binding != null) {
                      code.clear();
                    }
                  },
            child: Text(
              controller.snapshot?.quarantined == true
                  ? 'Reconcile restored profile'
                  : 'Set up encrypted sync',
            ),
          ),
        ],
        if (paired) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic Sync'),
            subtitle: const Text(
              'Checks while open. Background checks depend on your device and account access.',
            ),
            value: controller.snapshot?.automatic ?? false,
            onChanged: busy || controller.snapshot?.quarantined == true
                ? null
                : controller.setAutomatic,
          ),
          const SizedBox(height: 8),
          Text(
            'Pending changes: ${controller.status.pending} · Conflicts: ${controller.status.conflicts}',
          ),
          const SizedBox(height: 6),
          SettingsHelperText(
            'Last synced: ${controller.status.lastSuccess == null ? 'Not yet' : '${MaterialLocalizations.of(context).formatMediumDate(controller.status.lastSuccess!.toLocal())} \u00b7 ${TimeOfDay.fromDateTime(controller.status.lastSuccess!.toLocal()).format(context)}'}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => controller.syncNow(manual: true),
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => showSyncConflicts(context, controller),
                child: Text(
                  'Review conflicts (${controller.status.conflicts})',
                ),
              ),
              TextButton(
                onPressed: busy ? null : controller.connect,
                child: const Text('Reconnect account'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final value = await controller.recoveryCode();
                        if (mounted && controller.isUnlocked()) {
                          setState(() => revealed = value);
                        }
                      },
                child: const Text('Show recovery code'),
              ),
            ],
          ),
          if (revealed != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StatusNotice(
                      title: 'Keep your recovery code private',
                      message: 'Anyone with this code and access to this Google account can decrypt the sync workspace.',
                      icon: Icons.key_outlined,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(revealed!),
                    TextButton(
                      onPressed: () => setState(() => revealed = null),
                      child: const Text('Hide code'),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (controller.message != null)
          StatusNotice(title: 'Sync status', message: controller.message!),
        if (controller.status.notice != null)
          StatusNotice(
            title: 'Attention needed',
            message: controller.status.notice!,
            icon: Icons.warning_amber_outlined,
          ),
        const SizedBox(height: 16),
        const SettingsSection(
          title: 'About encrypted sync',
          children: [
            SettingsHelperText(
              'Sync exchanges incremental changes between paired devices. Backups remain separate recovery snapshots. Background delivery depends on operating-system scheduling and authorization.',
            ),
          ],
        ),
      ],
    );
  }
}
