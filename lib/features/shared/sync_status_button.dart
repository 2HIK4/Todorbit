import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import 'app_motion.dart';
import 'status_snackbar.dart';

/// Signature for displaying sync settings/configuration.
typedef SyncOpenSettingsCallback = FutureOr<void> Function(BuildContext context);

/// Signature for displaying sync conflict resolution review.
typedef SyncOpenConflictsCallback =
    FutureOr<void> Function(BuildContext context, SyncController controller);

class SyncStatusButton extends ConsumerStatefulWidget {
  const SyncStatusButton({
    super.key,
    this.allowAutomatic = true,
    this.onOpenSettings,
    this.onOpenConflicts,
  });

  // Retained for shell callers. Automatic attention is a badge, never a modal.
  final bool allowAutomatic;

  /// Callback to display sync settings/configuration dialog or page.
  final SyncOpenSettingsCallback? onOpenSettings;

  /// Callback to display sync conflict resolution review.
  final SyncOpenConflictsCallback? onOpenConflicts;

  @override
  ConsumerState<SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends ConsumerState<SyncStatusButton> {
  bool _successNoticePending = false;

  void _showSuccess(BuildContext context, String message) {
    if (_successNoticePending) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _successNoticePending = true;
    final shown = messenger.showSnackBar(
      transientStatusSnackBar(
        context,
        message,
        type: NotificationType.success,
        key: const ValueKey('sync-success-notice'),
      ),
      snackBarAnimationStyle: AppMotion.style(context),
    );
    unawaited(shown.closed.then((_) => _successNoticePending = false));
  }

  Future<void> _handleOpenSettings(BuildContext context) async {
    final callback = widget.onOpenSettings;
    if (callback != null) {
      await callback(context);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      transientStatusSnackBar(
        context,
        'Sync settings are unavailable from this view.',
        type: NotificationType.error,
        key: const ValueKey('sync-settings-unavailable-notice'),
      ),
    );
  }

  Future<void> _handleOpenConflicts(
    BuildContext context,
    SyncController controller,
  ) async {
    final callback = widget.onOpenConflicts;
    if (callback != null) {
      await callback(context, controller);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      transientStatusSnackBar(
        context,
        'Sync conflict review is unavailable from this view.',
        type: NotificationType.error,
        key: const ValueKey('sync-conflicts-unavailable-notice'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(syncControllerProvider);
    final busy =
        controller?.busy == true ||
        controller?.status.phase == SyncPhase.syncing;
    final conflicts = controller?.conflictCount ?? 0;
    final description = controller == null
        ? 'Sync unavailable'
        : 'Sync · ${controller.label}${conflicts > 0 ? ' · $conflicts ${conflicts == 1 ? 'conflict needs' : 'conflicts need'} attention' : ''}';
    return Semantics(
      label: description,
      child: IconButton(
        key: const ValueKey('sync-status-button'),
        tooltip: description,
        onPressed: controller == null || busy || !controller.isUnlocked()
            ? null
            : () async {
                if (controller.problem != null || controller.resetPending) {
                  await _handleOpenSettings(context);
                  return;
                }
                await controller.syncNow(manual: true);
                if (!context.mounted || !controller.isUnlocked()) return;
                if (controller.problem != null ||
                    controller.resetPending ||
                    controller.needsRecoveryCode ||
                    controller.recoveryReminder ||
                    controller.auth.account == null ||
                    controller.auth.needsReconnect ||
                    controller.snapshot?.binding == null ||
                    controller.snapshot?.quarantined == true) {
                  await _handleOpenSettings(context);
                  controller.recoveryReminder = false;
                } else if (controller.conflictCount > 0) {
                  await _handleOpenConflicts(context, controller);
                } else if (controller.standardIntroduction) {
                  final shown = ScaffoldMessenger.maybeOf(context)
                      ?.showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Google Drive Sync is ready. Review privacy choices in Sync settings.',
                          ),
                          showCloseIcon: true,
                          persist: false,
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                            label: 'Encryption options',
                            onPressed: () => _handleOpenSettings(context),
                          ),
                        ),
                      );
                  if (shown != null) {
                    await shown.closed;
                    if (context.mounted && controller.isUnlocked()) {
                      await controller.dismissStandardIntroduction();
                    }
                  }
                } else if (controller.status.phase == SyncPhase.upToDate &&
                    controller.status.notice == null) {
                  _showSuccess(context, controller.message ?? controller.label);
                } else {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      showCloseIcon: true,
                      persist: false,
                      duration: statusReadingDuration(
                        context,
                        controller.message ??
                            controller.status.notice ??
                            controller.label,
                        NotificationType.error,
                      ),
                      content: Text(
                        controller.message ??
                            controller.status.notice ??
                            controller.label,
                      ),
                      action: SnackBarAction(
                        label: 'Sync settings',
                        onPressed: () => _handleOpenSettings(context),
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
