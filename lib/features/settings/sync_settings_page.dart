import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import 'sync_conflicts_dialog.dart';
import '../shared/settings_section.dart';
import '../shared/status_notice.dart';

Future<void> showSyncSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => NotificationListener<ScrollMetricsNotification>(
    onNotification: (_) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null && ModalRoute.of(focused) == ModalRoute.of(context)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focused.mounted) {
            Scrollable.ensureVisible(
              focused,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
      return false;
    },
    child: AlertDialog(
      title: const Text('Sync'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      scrollable: true,
      content: const SizedBox(width: 460, child: SyncSettingsPage()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
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
  Timer? recoveryReveal;
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
    recoveryReveal?.cancel();
    if (!recoveryFocus.hasFocus) return;
    recoveryReveal = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !recoveryFocus.hasFocus) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !recoveryFocus.hasFocus) return;
        final fieldContext = recoveryField.currentContext;
        if (fieldContext != null) {
          Scrollable.ensureVisible(
            fieldContext,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      });
      WidgetsBinding.instance.scheduleFrame();
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
    recoveryReveal?.cancel();
    recoveryFocus.dispose();
    listening?.removeListener(_privacy);
    code.dispose();
    super.dispose();
  }

  Future<void> _authorize(SyncController controller) async {
    final entered = code.text.trim();
    if (controller.snapshot?.quarantined == true) {
      await controller.reconcileRestored(
        recoveryCode: entered.isEmpty ? null : entered,
      );
    } else {
      await controller.activate(recoveryCode: entered.isEmpty ? null : entered);
    }
    if (mounted && !controller.needsRecoveryCode) code.clear();
  }

  Future<void> _showCode(SyncController controller) async {
    try {
      final value = await controller.recoveryCode();
      if (mounted && controller.isUnlocked()) {
        if (value != null) controller.recoveryReminder = false;
        setState(() => revealed = value);
      }
    } catch (_) {
      if (mounted && controller.isUnlocked()) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'The retained code could not be read. Keep your recovery copy and try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(syncControllerProvider);
    if (controller == null) {
      return const Text('Sync is unavailable for this profile.');
    }
    if (!controller.isUnlocked()) {
      return const Text('Unlock Todorbit to manage sync.');
    }
    final theme = Theme.of(context);
    final busy =
        controller.busy || controller.status.phase == SyncPhase.syncing;
    final paired = controller.snapshot?.binding != null;
    final connected =
        controller.auth.account != null && !controller.auth.needsReconnect;
    final restored = controller.snapshot?.quarantined == true;
    final last =
        controller.status.lastSuccess ?? controller.snapshot?.lastSuccess;
    final conflicts = controller.conflictCount;
    final notice =
        controller.message ??
        (controller.needsRecoveryCode ? null : controller.status.notice);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.cloud_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Google Drive', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    controller.auth.account?.label ??
                        'Connect to sync across your devices',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            busy ? 'Synchronizing' : controller.label,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (paired) ...[
          const SizedBox(height: 6),
          SettingsHelperText(
            last == null
                ? 'No successful sync yet'
                : 'Last synced ${MaterialLocalizations.of(context).formatMediumDate(last.toLocal())} · ${TimeOfDay.fromDateTime(last.toLocal()).format(context)}',
          ),
        ],
        const SizedBox(height: 16),
        if (restored) ...[
          const StatusNotice(
            title: 'Review restored data',
            message: 'Reconnect restored records with your encrypted data. Existing changes and the recovery snapshot are kept. Automatic sync stays off.',
            icon: Icons.restore,
          ),
        ],
        if (controller.needsRecoveryCode || restored && connected) ...[
          if (!restored)
            const Text(
              'Enter the recovery code shown in Sync on your other device. This device will remember it securely.',
            ),
          const SizedBox(height: 12),
          TextField(
            key: recoveryField,
            focusNode: recoveryFocus,
            controller: code,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Recovery code',
              helperText: restored
                  ? 'Only needed if this device has lost access.'
                  : null,
            ),
            onSubmitted: busy ? null : (_) => _authorize(controller),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: busy || (!connected && !controller.auth.canConnect)
              ? null
              : () async {
                  if (connected && (controller.needsRecoveryCode || restored)) {
                    await _authorize(controller);
                  } else {
                    await controller.syncNow(manual: true);
                  }
                },
          icon: Icon(connected ? Icons.sync : Icons.account_circle_outlined),
          label: Text(
            !connected
                ? controller.auth.needsReconnect
                      ? 'Reconnect Google Drive'
                      : 'Connect Google Drive'
                : restored
                ? 'Reconcile restored profile'
                : controller.needsRecoveryCode
                ? 'Authorize this device'
                : paired
                ? 'Sync now'
                : 'Set up sync',
          ),
        ),
        if (conflicts > 0) ...[
          const SizedBox(height: 16),
          Text(
            '$conflicts ${conflicts == 1 ? 'conflict needs' : 'conflicts need'} attention',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => showSyncConflicts(context, controller),
            child: const Text('Review conflicts'),
          ),
        ],
        if (notice != null) ...[
          const SizedBox(height: 12),
          Text(notice, style: theme.textTheme.bodyMedium),
        ],
        if (notice == null && !connected && !controller.auth.canConnect)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Google Drive is unavailable in this build. Local backups remain available.',
            ),
          ),
        if (paired && !restored) ...[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic sync'),
            subtitle: const Text(
              'Checks while open. Background checks depend on your device.',
            ),
            value: controller.snapshot?.automatic ?? false,
            onChanged: busy ? null : controller.setAutomatic,
          ),
          if (controller.recoveryReminder)
            TextButton.icon(
              onPressed: busy ? null : () => _showCode(controller),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Save your recovery code'),
            ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced'),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy ? null : controller.reconnectAndSync,
                      child: const Text('Reconnect account'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => _showCode(controller),
                      child: const Text('Show recovery code'),
                    ),
                  ],
                ),
              ),
              const SettingsHelperText(
                'Sync keeps current data consistent, including deletions. Backups remain separate recovery snapshots.',
              ),
              const SizedBox(height: 8),
              SettingsHelperText(
                'Pending changes: ${controller.status.pending}',
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (revealed != null) ...[
            const StatusNotice(
              title: 'Keep this code private',
              message: 'Save it outside this device. It authorizes another device and recovers encrypted sync data. Google sign-in alone cannot recover a lost code.',
              icon: Icons.key_outlined,
            ),
            SelectableText(revealed!),
            TextButton(
              onPressed: () => setState(() => revealed = null),
              child: const Text('Hide code'),
            ),
          ],
        ],
      ],
    );
  }
}
