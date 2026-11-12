import '../shared/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sync_controller.dart';
import '../../data/cloud/sync_batch_codec.dart';
import '../../data/cloud/sync_workspace_format.dart';
import '../shared/settings_section.dart';
import '../shared/status_snackbar.dart';

Future<void> showPrivateSyncSetup(
  BuildContext context,
  SyncController controller,
) async {
  final result = await collectPrivateSyncCredentials(context, controller);
  if (result != null && controller.isUnlocked()) {
    await controller.startPrivateSync(result.$1, result.$2);
  }
}

Future<(String, SyncWorkspaceKey)?> collectPrivateSyncCredentials(
  BuildContext context,
  SyncController controller,
) => showDialog<(String, SyncWorkspaceKey)>(
  context: context,
  animationStyle: AppMotion.style(context),
  builder: (_) => _PrivateSyncSetup(controller: controller),
);

class _PrivateSyncSetup extends StatefulWidget {
  const _PrivateSyncSetup({required this.controller});
  final SyncController controller;
  @override
  State<_PrivateSyncSetup> createState() => _PrivateSyncSetupState();
}

class _PrivateSyncSetupState extends State<_PrivateSyncSetup> {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  final key = SyncWorkspaceKey.generate();
  final form = GlobalKey<FormState>();
  bool visible = false, saved = false;
  bool _closingForPrivacy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_privacy);
  }

  void _privacy() {
    if (!widget.controller.isUnlocked() && mounted && !_closingForPrivacy) {
      _closingForPrivacy = true;
      password.clear();
      confirmation.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_privacy);
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Private Encrypted Sync'),
    insetPadding: const EdgeInsets.all(16),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Encrypt a new cloud workspace before upload. Existing cloud data keeps its current mode.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
              obscureText: !visible,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Private Sync passphrase',
                helperText:
                    'At least 12 characters (not your Google password). Several unrelated words work well; length and unpredictability matter.',
                suffixIcon: IconButton(
                  tooltip: visible ? 'Hide passphrase' : 'Show passphrase',
                  onPressed: () => setState(() => visible = !visible),
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                ),
              ),
              validator: (value) =>
                  SyncWorkspaceFormat.passwordError(value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmation,
              obscureText: !visible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Confirm passphrase',
              ),
              validator: (value) => value == password.text
                  ? null
                  : 'The passphrases do not match.',
            ),
            const SizedBox(height: 20),
            Text(
              'Save your recovery code',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const SettingsHelperText(
              'Store this code privately outside this device. If you lose the passphrase and every copy of the code, encrypted cloud data cannot be recovered.',
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Recovery code: ${key.exportRecoveryCode()}',
                    child: SelectableText(key.exportRecoveryCode()),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy recovery code',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    if (!widget.controller.isUnlocked()) return;
                    await Clipboard.setData(
                      ClipboardData(text: key.exportRecoveryCode()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      transientStatusSnackBar(context, 'Recovery code copied'),
                      snackBarAnimationStyle: AppMotion.style(context),
                    );
                  },
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I saved my recovery code'),
              value: saved,
              onChanged: (value) => setState(() => saved = value ?? false),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: !saved
            ? null
            : () {
                if (form.currentState!.validate()) {
                  Navigator.of(context).pop((password.text, key));
                }
              },
        child: const Text('Connect with encryption'),
      ),
    ],
  );
}
