import '../shared/app_motion.dart';

import 'package:flutter/material.dart';

import '../../app/sync_controller.dart';
import 'sync_encryption_setup_dialog.dart';

Future<void> showStartNewSync(
  BuildContext context,
  SyncController controller,
) async {
  if (controller.resetState?['phase'] != 'review') {
    await controller.reviewNewSync();
  }
  if (!context.mounted ||
      !controller.isUnlocked() ||
      controller.resetState?['phase'] != 'review') {
    return;
  }
  final private = await showDialog<bool>(
    context: context,
    animationStyle: AppMotion.style(context),
    barrierDismissible: false,
    builder: (_) => SyncResetConfirmation(controller: controller),
  );
  if (!context.mounted || !controller.isUnlocked()) return;
  if (private == null) {
    await controller.cancelNewSyncReview();
    return;
  }
  if (private) {
    final credential = await collectPrivateSyncCredentials(context, controller);
    if (credential == null) {
      await controller.cancelNewSyncReview();
      return;
    }
    if (controller.isUnlocked()) {
      await controller.startNewSync(
        password: credential.$1,
        privateKey: credential.$2,
      );
    }
  } else {
    await controller.startNewSync();
  }
}

class SyncResetConfirmation extends StatefulWidget {
  const SyncResetConfirmation({super.key, required this.controller});
  final SyncController controller;
  @override
  State<SyncResetConfirmation> createState() => _SyncResetConfirmationState();
}

class _SyncResetConfirmationState extends State<SyncResetConfirmation> {
  bool acknowledged = false, private = false, closing = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_privacy);
  }

  void _privacy() {
    if (!widget.controller.isUnlocked() && mounted && !closing) {
      closing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_privacy);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Start a New Sync?'),
    insetPadding: const EdgeInsets.all(16),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.controller.auth.account?.label ?? 'Selected Google account',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Replace cloud sync with this device’s current tasks, events, attachments and supported settings. All local records, backups and retained conflict history stay on this device.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Cloud-only records and unresolved cloud versions may be permanently lost. Old encrypted data is not recovered. Other devices must update and reconnect; their offline edits stay local until reconciled.',
          ),
          const SizedBox(height: 12),
          const Text(
            'A verified local recovery snapshot is ready. Old cloud content will be removed only after the new copy is uploaded, read back and activated. Non-content safety markers remain. Old devices may recreate isolated old files until updated.',
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Affected workspace and recovery copy'),
            children: [
              SelectableText(
                'Workspace: ${(widget.controller.resetState?['selected'] as List? ?? []).join(', ')}\nRecovery: ${widget.controller.resetState?['backup'] ?? 'Prepared local snapshot'}',
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Private Encrypted Sync'),
            subtitle: Text(
              private
                  ? 'Next, choose a new passphrase and save a new recovery code.'
                  : 'Standard Sync (default): no extra Todorbit password.',
            ),
            value: private,
            onChanged: (v) => setState(() => private = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I understand that cloud-only data may be lost and other devices must reconnect.',
            ),
            value: acknowledged,
            onChanged: (v) => setState(() => acknowledged = v ?? false),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: acknowledged
            ? () => Navigator.of(context).pop(private)
            : null,
        child: Text(private ? 'Continue with encryption' : 'Start New Sync'),
      ),
    ],
  );
}
