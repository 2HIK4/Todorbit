import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_engine.dart';
import 'sync_conflicts_dialog.dart';
import 'sync_encryption_setup_dialog.dart';
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
  bool showCredential = false,
      useRecoveryCode = true,
      encryptionExpanded = false;
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
      showCredential = false;
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
    final entered =
        controller.snapshot?.quarantined == true ||
            useRecoveryCode ||
            !controller.pairing.passwordAvailable
        ? code.text.trim()
        : code.text;
    if (controller.snapshot?.quarantined == true) {
      await controller.reconcileRestored(
        recoveryCode: entered.isEmpty ? null : entered,
      );
    } else {
      await controller.activate(
        recoveryCode: useRecoveryCode || !controller.pairing.passwordAvailable
            ? (entered.isEmpty ? null : entered)
            : null,
        password: !useRecoveryCode && controller.pairing.passwordAvailable
            ? entered
            : null,
      );
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
            message: 'Reconnect restored records with your cloud data. Existing changes and the recovery snapshot are kept. Automatic sync stays off.',
            icon: Icons.restore,
          ),
        ],
        if (controller.needsRecoveryCode || restored && connected) ...[
          if (!restored)
            const Text(
              'Unlock your encrypted cloud data once. This device will remember the key in protected storage.',
            ),
          if (!restored && controller.pairing.passwordAvailable)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use recovery code'),
              value: useRecoveryCode,
              onChanged: busy
                  ? null
                  : (value) => setState(() {
                      useRecoveryCode = value;
                      code.clear();
                    }),
            ),
          const SizedBox(height: 12),
          TextField(
            key: recoveryField,
            focusNode: recoveryFocus,
            controller: code,
            obscureText: !showCredential,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText:
                  !restored &&
                      controller.pairing.passwordAvailable &&
                      !useRecoveryCode
                  ? 'Encryption passphrase'
                  : 'Recovery code',
              suffixIcon: IconButton(
                tooltip: showCredential ? 'Hide credential' : 'Show credential',
                onPressed: () =>
                    setState(() => showCredential = !showCredential),
                icon: Icon(
                  showCredential ? Icons.visibility_off : Icons.visibility,
                ),
              ),
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
        if (controller.standardIntroduction) ...[
          const SizedBox(height: 16),
          const StatusNotice(
            title: 'Google Drive Sync is ready',
            message: 'Your data can sync across your devices without an extra password. Review Encryption options for privacy choices.',
            icon: Icons.cloud_done_outlined,
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : controller.dismissStandardIntroduction,
                child: const Text('Got it'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        await controller.dismissStandardIntroduction();
                        if (mounted) setState(() => encryptionExpanded = true);
                      },
                child: const Text('Encryption options'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        ExpansionTile(
          key: ValueKey(encryptionExpanded),
          initiallyExpanded: encryptionExpanded,
          tilePadding: EdgeInsets.zero,
          title: const Text('Encryption options'),
          subtitle: Text(
            controller.standardSync == null
                ? 'Standard Sync is the default'
                : controller.standardSync!
                ? 'Standard Sync'
                : 'Private Encrypted Sync',
          ),
          children: [
            const SettingsHelperText(
              'Standard Sync uses Google Drive protection without an extra Todorbit password. Private Encrypted Sync encrypts data on your device before upload.',
            ),
            const SizedBox(height: 12),
            if (!paired)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => showPrivateSyncSetup(context, controller),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Set up Private Encrypted Sync'),
              )
            else ...[
              const OutlinedButton(
                onPressed: null,
                child: Text('Change encryption (unavailable)'),
              ),
              const SettingsHelperText(
                'This version cannot safely convert an existing cloud workspace or change its passphrase. Its current protection, data and recovery code are kept.',
              ),
            ],
            const SizedBox(height: 12),
          ],
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
          if (controller.recoveryReminder && controller.standardSync != true)
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
                    if (controller.standardSync != true)
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
