import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import '../settings/sync_conflicts_dialog.dart';
import '../settings/sync_settings_page.dart';

class SyncStatusButton extends ConsumerStatefulWidget {
  const SyncStatusButton({super.key, this.allowAutomatic = true});
  final bool allowAutomatic;
  @override
  ConsumerState<SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends ConsumerState<SyncStatusButton> {
  bool prompting = false;
  String? promptedToken;
  Future<void> _attention(SyncController controller) async {
    if (!widget.allowAutomatic ||
        prompting ||
        !mounted ||
        !controller.isUnlocked() ||
        controller.busy ||
        Navigator.of(context).canPop() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    prompting = true;
    try {
      final review = await controller.reviewConflicts();
      if (!mounted ||
          review == null ||
          review.dismissed ||
          review.attentionToken == promptedToken ||
          !controller.isUnlocked() ||
          Navigator.of(context).canPop()) {
        return;
      }
      promptedToken = review.attentionToken;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            SyncConflictsDialog(controller: controller, review: review),
      );
    } catch (_) {
      // Durable attention remains available through settings; a background
      // review must not interrupt an editor or become an unhandled UI error.
    } finally {
      prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(syncControllerProvider);
    final busy =
        controller?.busy == true ||
        controller?.status.phase == SyncPhase.syncing;
    if (controller != null && controller.status.conflicts > 0 && !busy) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_attention(controller)),
      );
    }
    return IconButton(
      key: const ValueKey('sync-status-button'),
      tooltip: controller == null
          ? 'Sync unavailable'
          : 'Sync Now · ${controller.label}',
      onPressed: controller == null || busy || !controller.isUnlocked()
          ? null
          : () async {
              prompting = true;
              try {
                if (controller.auth.account == null ||
                    controller.auth.needsReconnect ||
                    controller.snapshot?.binding == null ||
                    controller.snapshot?.quarantined == true) {
                  await showSyncSettings(context);
                  return;
                }
                await controller.syncNow(manual: true);
                if (!context.mounted || !controller.isUnlocked()) return;
                if (controller.status.conflicts > 0) {
                  await showSyncConflicts(context, controller);
                } else {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        controller.status.notice ?? controller.label,
                      ),
                      action:
                          controller.status.phase == SyncPhase.needsAttention
                          ? SnackBarAction(
                              label: 'Settings',
                              onPressed: () => showSyncSettings(context),
                            )
                          : null,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } finally {
                prompting = false;
              }
            },
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Badge(
              isLabelVisible:
                  controller?.status.conflicts != 0 && controller != null,
              child: Icon(
                controller?.status.phase == SyncPhase.error
                    ? Icons.sync_problem
                    : Icons.sync,
              ),
            ),
    );
  }
}
