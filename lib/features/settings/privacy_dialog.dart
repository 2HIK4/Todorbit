import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/privacy_manager.dart';
import '../shared/settings_section.dart';

final privacyManagerProvider = ChangeNotifierProvider<PrivacyManager>((ref) {
  throw StateError('PrivacyManager must be provided by the application');
});

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final pin = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> unlock() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final manager = ref.read(privacyManagerProvider);
      final success = await manager.unlock(pin.text);
      if (!mounted) return;
      if (!success) {
        final delay = manager.retryDelay;
        setState(
          () => error = delay == null
              ? 'Incorrect PIN.'
              : 'Too many attempts. Try again in ${delay.inSeconds + 1} seconds.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unlock failed. Check privacy settings and try again.',
        );
      }
    } finally {
      pin.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 42),
              const SizedBox(height: 16),
              Text(
                'Todorbit is locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(labelText: 'PIN'),
                onSubmitted: (_) => unlock(),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy ? null : unlock,
                child: const Text('Unlock'),
              ),
              const SizedBox(height: 16),
              const SettingsHelperText(
                'Forgot your PIN? Close Todorbit, then use Settings > Data profile to locate privacy-settings.json and rename that file. This resets only app lock; your database remains intact. App lock protects the UI, not files accessible through your Windows account.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PrivacyDialog extends ConsumerStatefulWidget {
  const PrivacyDialog({super.key});

  @override
  ConsumerState<PrivacyDialog> createState() => _PrivacyDialogState();
}

class _PrivacyDialogState extends ConsumerState<PrivacyDialog> {
  final currentPin = TextEditingController();
  final newPin = TextEditingController();
  final confirmPin = TextEditingController();
  bool busy = false;
  String? message;

  @override
  void dispose() {
    currentPin.dispose();
    newPin.dispose();
    confirmPin.dispose();
    super.dispose();
  }

  Future<void> run(Future<String> Function(PrivacyManager) action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await action(ref.read(privacyManagerProvider));
      if (mounted) setState(() => message = result);
    } catch (error) {
      if (mounted) setState(() => message = '$error');
    } finally {
      currentPin.clear();
      newPin.clear();
      confirmPin.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(privacyManagerProvider);
    final settings = manager.settings;
    return AlertDialog(
      title: const Text('Privacy and app lock'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsHelperText(
                'App lock hides Todorbit content in the app and native widget. It does not encrypt the SQLite database or protect files from someone with access to your Windows account.',
              ),
              const SizedBox(height: 12),
              Text(settings.enabled ? 'App lock enabled' : 'App lock disabled'),
              const SizedBox(height: 12),
              if (settings.enabled) ...[
                TextField(
                  controller: currentPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Current PIN'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: settings.enabled
                      ? 'New PIN'
                      : 'Set PIN (6–12 digits)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(labelText: 'Confirm new PIN'),
              ),
              const SizedBox(height: 8),
              if (!settings.enabled)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run((manager) async {
                          if (newPin.text != confirmPin.text) {
                            return 'PINs do not match.';
                          }
                          await manager.setup(newPin.text);
                          return 'App lock enabled.';
                        }),
                  child: const Text('Enable app lock'),
                ),
              if (settings.enabled) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => run((manager) async {
                              if (newPin.text != confirmPin.text) {
                                return 'PINs do not match.';
                              }
                              return await manager.changePin(
                                    currentPin.text,
                                    newPin.text,
                                  )
                                  ? 'PIN changed.'
                                  : 'Incorrect PIN.';
                            }),
                      child: const Text('Change PIN'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run((manager) async {
                              return await manager.remove(currentPin.text)
                                  ? 'App lock disabled.'
                                  : 'Incorrect PIN.';
                            }),
                      child: const Text('Remove app lock'),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Lock on every launch'),
                  value: settings.lockOnLaunch,
                  onChanged: busy
                      ? null
                      : (value) => run((manager) async {
                          await manager.updateSettings(
                            settings.copyWith(lockOnLaunch: value),
                          );
                          return 'Saved.';
                        }),
                ),
                SwitchListTile(
                  title: const Text('Lock when the app loses focus'),
                  subtitle: const Text(
                    'Locks on return after a Flutter lifecycle interruption.',
                  ),
                  value: settings.lockOnInactive,
                  onChanged: busy
                      ? null
                      : (value) => run((manager) async {
                          await manager.updateSettings(
                            settings.copyWith(lockOnInactive: value),
                          );
                          return 'Saved.';
                        }),
                ),
                AnchoredSelectField<int>(
                  initialValue: settings.inactivityMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Lock after inactivity',
                  ),
                  items: const [1, 5, 15, 30, 60]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            run((manager) async {
                              await manager.updateSettings(
                                settings.copyWith(inactivityMinutes: value),
                              );
                              return 'Saved.';
                            });
                          }
                        },
                ),
                SwitchListTile(
                  title: const Text('Suppress notifications while locked'),
                  subtitle: const Text(
                    'When off, locked notifications contain only a generic message.',
                  ),
                  value: settings.hideNotifications,
                  onChanged: busy
                      ? null
                      : (value) => run((manager) async {
                          await manager.updateSettings(
                            settings.copyWith(hideNotifications: value),
                          );
                          return 'Saved.';
                        }),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          Navigator.pop(context);
                          manager.lock();
                        },
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock now'),
                ),
              ],
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message!),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
