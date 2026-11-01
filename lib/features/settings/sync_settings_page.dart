import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import 'sync_conflicts_dialog.dart';

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

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage> {
  final code = TextEditingController();
  String? revealed;
  SyncController? listening;
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
        const Text(
          'Edits save locally immediately. Sync exchanges encrypted incremental changes between your paired devices. Backups remain independent recoverable snapshots.',
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
          Text(
            controller.snapshot?.quarantined == true
                ? 'Restore paused synchronization. Reconcile with the original workspace to retain both restored records and pre-restore pending work. Enter the original recovery code if it is unavailable on this device. Automatic sync stays off until you enable it.'
                : 'Joining another device? Enter its recovery code. For your first device, leave this blank to create a workspace. A verified recovery snapshot is made before local capture starts.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: code,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Workspace recovery code',
              helperText: 'Leave blank only for your first device.',
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
              'Checks while open; background delivery is subject to operating-system scheduling and authorization.',
            ),
            value: controller.snapshot?.automatic ?? false,
            onChanged: busy || controller.snapshot?.quarantined == true
                ? null
                : controller.setAutomatic,
          ),
          Text(
            'Pending changes: ${controller.status.pending} · Conflicts: ${controller.status.conflicts}',
          ),
          const SizedBox(height: 6),
          Text(
            'Last successful exchange: ${controller.status.lastSuccess?.toLocal().toString() ?? 'Not yet recorded'}',
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
                child: const Text('Open Conflict Resolution'),
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
                    const Text(
                      'Keep this code private. Anyone with the code and access to this Google account can decrypt its sync workspace.',
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(controller.message!),
          ),
        if (controller.status.notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(controller.status.notice!),
          ),
      ],
    );
  }
}
