import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import '../settings/sync_conflicts_dialog.dart';
import '../settings/sync_settings_page.dart';

class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key, this.allowAutomatic = true});
  // Retained for shell callers. Automatic attention is a badge, never a modal.
  final bool allowAutomatic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(syncControllerProvider);
    final busy =
        controller?.busy == true ||
        controller?.status.phase == SyncPhase.syncing;
    final conflicts = controller?.conflictCount ?? 0;
    final description = controller == null
        ? 'Sync unavailable'
        : 'Sync · ${controller.label}${conflicts > 0 ? ' · $conflicts conflicts need attention' : ''}';
    return Semantics(
      label: description,
      child: IconButton(
        key: const ValueKey('sync-status-button'),
        tooltip: description,
        onPressed: controller == null || busy || !controller.isUnlocked()
            ? null
            : () async {
                await controller.syncNow(manual: true);
                if (!context.mounted || !controller.isUnlocked()) return;
                if (controller.needsRecoveryCode ||
                    controller.recoveryReminder ||
                    controller.auth.account == null ||
                    controller.auth.needsReconnect ||
                    controller.snapshot?.binding == null ||
                    controller.snapshot?.quarantined == true) {
                  await showSyncSettings(context);
                  controller.recoveryReminder = false;
                } else if (controller.conflictCount > 0) {
                  await showSyncConflicts(context, controller);
                } else {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        controller.message ??
                            controller.status.notice ??
                            controller.label,
                      ),
                      action: SnackBarAction(
                        label: 'Sync settings',
                        onPressed: () => showSyncSettings(context),
                      ),
                    ),
                  );
                }
              },
        icon: Badge(
          isLabelVisible: conflicts > 0,
          label: Text('$conflicts'),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  controller?.status.phase == SyncPhase.error
                      ? Icons.sync_problem
                      : Icons.sync,
                ),
        ),
      ),
    );
  }
}
