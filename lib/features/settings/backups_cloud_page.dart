import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/app_controller.dart';
import '../../data/app_database.dart';
import '../../data/cloud/cloud_backup_service.dart';
import '../../data/cloud/cloud_storage_provider.dart';
import '../../data/cloud/google_drive_auth.dart';
import '../../data/cloud/google_drive_provider.dart';
import '../../platform/android/android_google_drive_auth.dart';
import 'backup_dialog.dart';
import 'settings_transfer.dart';
import 'settings_transfer_dialog.dart';
import 'windows_settings_file_dialog.dart';
import '../shared/settings_section.dart';

class BackupsCloudPage extends ConsumerStatefulWidget {
  const BackupsCloudPage({super.key, this.auth, this.service});
  final GoogleDriveAuth? auth;
  final CloudBackupService? service;
  @override
  ConsumerState<BackupsCloudPage> createState() => _BackupsCloudPageState();
}

class _BackupsCloudPageState extends ConsumerState<BackupsCloudPage> {
  http.Client? client;
  GoogleDriveAuth? auth;
  CloudBackupService? service;
  List<CloudObject> objects = [];
  bool busy = false, signingIn = false;
  bool historyLoaded = false;
  String? error, message;
  String stage = '';
  double? progress;
  final cloudProgress = ValueNotifier<({String stage, double? fraction})>((
    stage: 'Preparing encrypted settings backup',
    fraction: null,
  ));

  @override
  void initState() {
    super.initState();
    final local = ref.read(appControllerProvider).backupService;
    if (local == null) return;
    client = widget.auth == null ? http.Client() : null;
    auth =
        widget.auth ??
        (Platform.isAndroid
            ? AndroidGoogleDriveAuth(
                client: client!,
                store: SecureCloudTokenStore(local.databaseFile.absolute.path),
              )
            : GoogleDriveAuth(
                client: client!,
                store: SecureCloudTokenStore(local.databaseFile.absolute.path),
                configurationStore: kDebugMode
                    ? SecureCloudTokenStore(
                        local.databaseFile.absolute.path,
                        purpose: 'oauth-client',
                      )
                    : null,
                flow: LoopbackGoogleAuthorization(),
                clientId: GoogleDriveAuth.configuredClientId,
                clientSecret: GoogleDriveAuth.configuredClientSecret,
                enabled: GoogleDriveAuth.publicConnectionEnabled,
              ));
    service =
        widget.service ??
        CloudBackupService(
          local: local,
          provider: GoogleDriveProvider(auth!, client!),
          appVersion: Platform.isAndroid
              ? const String.fromEnvironment(
                  'FLUTTER_BUILD_NAME',
                  defaultValue: 'Unknown',
                )
              : 'Unknown',
        );
    unawaited(
      _run(() async {
        if (widget.service == null && Platform.isWindows) {
          final version = await const MethodChannel('life_manager/window_theme')
              .invokeMethod<String>('getVersion');
          service = CloudBackupService(
            local: local,
            provider: service!.provider,
            appVersion: version ?? 'Unknown',
          );
        }
        await auth!.load();
        if (auth!.account != null) await _list();
      }),
    );
  }

  @override
  void dispose() {
    auth?.flow.cancel();
    client?.close();
    cloudProgress.dispose();
    super.dispose();
  }

  void _progress(String value, int done, int total) {
    if (mounted) {
      cloudProgress.value = (
        stage: value,
        fraction: total > 0 ? done / total : null,
      );
    }
    if (mounted) {
      setState(() {
        stage = value;
        progress = total > 0 ? done / total : null;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
      stage = 'Working';
      progress = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = switch (failure) {
            CloudFailure() => failure.message,
            SocketException() || http.ClientException() => 'Network unavailable. Local backups remain available. Try again when connected.',
            TimeoutException() => 'The request timed out. Try again; previous backups are unchanged.',
            _ => 'The operation could not finish. Check the connection, local storage, and Google configuration, then try again.',
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          signingIn = false;
        });
      }
    }
  }

  Future<void> _list() async {
    final loaded = await service!.provider.list();
    if (mounted) {
      setState(() {
        objects = loaded;
        historyLoaded = true;
      });
    }
  }

  Future<void> _connect() => _run(() async {
    setState(() {
      signingIn = true;
      stage = 'Waiting for Google sign-in in your browser';
    });
    await auth!.connect();
    if (mounted) {
      setState(() {
        objects = [];
        historyLoaded = false;
        message =
            'Google Drive connected. Browse cloud backups to load history.';
      });
    }
  });

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<String?> _passphrase({required bool create}) async {
    final input = TextEditingController();
    final repeat = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            create ? 'Protect this cloud backup' : 'Unlock this cloud backup',
          ),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use your own recovery passphrase. Todorbit does not save it or upload it. Losing it makes this backup unrecoverable.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: input,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLength: 1024,
                    decoration: const InputDecoration(
                      labelText: 'Recovery passphrase (at least 12 characters)',
                    ),
                    onChanged: (_) => update(() {}),
                  ),
                  if (create) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: repeat,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      maxLength: 1024,
                      decoration: const InputDecoration(
                        labelText: 'Confirm recovery passphrase',
                      ),
                      onChanged: (_) => update(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  input.text.length >= 12 &&
                      (!create || input.text == repeat.text)
                  ? () => Navigator.pop(context, input.text)
                  : null,
              child: Text(
                create ? 'Encrypt and upload' : 'Download and unlock',
              ),
            ),
          ],
        ),
      ),
    );
    // Controllers belong to the route until its closing transition finishes.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    repeat.dispose();
    return result;
  }

  Future<void> _upload(CloudBackupKind kind, String settings) async {
    final passphrase = await _passphrase(create: true);
    if (passphrase == null || !mounted) return;
    await _run(() async {
      await service!.backUp(
        kind: kind,
        settings: settings,
        passphrase: passphrase,
        progress: _progress,
      );
      if (mounted) {
        setState(
          () => message =
              'Encrypted backup uploaded and remote content verified.',
        );
      }
      await _list();
    });
  }

  Future<void> _settingsUpload() async {
    await showDialog<void>(
      context: context,
      builder: (_) => SettingsTransferDialog(
        cloudProgress: cloudProgress,
        uploadSettings: (settings) async {
          // Keep the category dialog open on upload failures/cancellation.
          final passphrase = await _passphrase(create: true);
          if (passphrase == null || !mounted) {
            throw const CloudFailure('Backup canceled.');
          }
          Object? failure;
          await _run(() async {
            try {
              await service!.backUp(
                kind: CloudBackupKind.settings,
                settings: settings,
                passphrase: passphrase,
                progress: _progress,
              );
              if (mounted) {
                setState(
                  () => message =
                      'Settings backup uploaded and remote content verified.',
                );
              }
              await _list();
            } catch (error) {
              failure = error;
              rethrow;
            }
          });
          if (failure != null) {
            throw const CloudFailure(
              'Settings backup failed. Close this dialog to review the error.',
            );
          }
        },
      ),
    );
  }

  Future<void> _restore(CloudObject object) async {
    final passphrase = await _passphrase(create: false);
    if (passphrase == null || !mounted) return;
    await _run(() async {
      final preview = await service!.preview(object, passphrase, _progress);
      final settings = SettingsTransfer.decode(
        preview.manifest['settings'] as String,
      );
      if (!mounted) return;
      if (object.kind == CloudBackupKind.settings) {
        await showDialog<void>(
          context: context,
          builder: (_) => SettingsTransferDialog(initialTransfer: settings),
        );
      } else {
        final approved = await _confirm(
          'Replace this local profile?',
          'Backup: ${_date(object.createdAt)} • Todorbit ${preview.manifest['appVersion']}\n'
              'Source profile: ${preview.manifest['profileId']}\n'
              'Target profile: ${service!.local.databaseFile.parent.path}\n\n'
              '${preview.summary?.description}\n\n'
              'This replaces all database records and the included personalization after you close and reopen Todorbit. It does not merge tasks. '
              'A verified local Before Restore database backup is created first. '
              'Current personalization is saved separately as JSON. Credentials and privacy controls stay on this device. '
              'Linked external files are not bundled and may need relinking. '
              'Settings to replace: ${settings.categories.keys.map((item) => item.label).join(', ')}.',
          'Confirm replacement',
        );
        if (!approved || !mounted) return;
        final recovery = SettingsTransfer.fromController(
          ref.read(appControllerProvider),
        );
        final recoveryFile = File(
          '${preview.snapshot!.file.path}.before-settings.json',
        );
        await recovery.exportTo(recoveryFile, recovery.categories.keys.toSet());
        await service!.scheduleRestore(preview);
        if (mounted) {
          setState(
            () => message = 'Restore scheduled, not yet applied. Close Todorbit and its widget, then reopen. Review Local Backups for the actual restore result or to cancel.',
          );
        }
      }
    });
  }

  Future<void> _browse(CloudBackupKind kind) => _run(() async {
    await _list();
    if (!mounted) return;
    final selected = await showDialog<CloudObject>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          kind == CloudBackupKind.full
              ? 'Restore from Google Drive'
              : 'Restore settings from Google Drive',
        ),
        content: SizedBox(
          width: 480,
          height: 300,
          child: ListView(
            children: [
              if (!objects.any((item) => item.kind == kind))
                const Text('No backups of this kind in this account.'),
              for (final item in objects.where((item) => item.kind == kind))
                ListTile(
                  title: Text(_date(item.createdAt)),
                  subtitle: Text(_details(item)),
                  enabled: _compatible(item),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      // End this operation before starting the download/preview operation.
      setState(() => busy = false);
      await _restore(selected);
    }
  });

  bool _compatible(CloudObject item) =>
      item.kind != null &&
      item.properties['formatVersion'] == '1' &&
      item.properties['encryption'] == 'aes256gcm-v1' &&
      (item.kind == CloudBackupKind.settings ||
          ((int.tryParse(item.properties['schema'] ?? '') ?? -1) >= 1 &&
              (int.tryParse(item.properties['schema'] ?? '') ?? 9999) <=
                  AppDatabase.currentSchemaVersion));

  String _date(DateTime value) => value.toLocal().toString().split('.').first;
  String _details(CloudObject item) =>
      '${item.kind?.name ?? 'Unknown'} • Todorbit ${item.properties['appVersion']} • '
      '${(item.bytes / 1024).toStringAsFixed(1)} KiB • '
      '${item.properties['verified'] == 'true' ? 'Verified upload' : 'Unverified upload'} • '
      '${_compatible(item) ? 'Compatible' : 'Unsupported format/schema'}';

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final connected = auth?.account != null;
    final configured = auth?.canConnect == true;
    final ready = connected && !busy;
    final full =
        objects
            .where(
              (item) =>
                  item.kind == CloudBackupKind.full &&
                  item.properties['verified'] == 'true',
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Local Backups'),
        if (controller.backupService case final local?)
          SettingsSection(
            title: 'Local backup actions & history',
            description: 'Create, import, export, restore, and recovery',
            contentPadding: EdgeInsets.zero,
            children: [
              BackupDialog(
                key: ValueKey(message),
                service: local,
                automaticError: controller.backupError,
                embedded: true,
              ),
            ],
          )
        else
          const Text('Local backup service is unavailable in this session.'),
        const SettingsSection(
          title: 'Local backup retention',
          children: [
            SettingsHelperText(
              'Automatic backups run locally once a day on launch; the latest 14 automatic snapshots are retained. Manual and recovery backups are retained.',
            ),
          ],
        ),
        _heading('Google Drive'),
        Text(
          connected
              ? 'Google Drive • ${auth!.account!.label}'
              : 'Google Drive is disconnected.',
        ),
        if (auth?.needsReconnect == true)
          const Text('Session needs reconnecting.'),
        if (!configured)
          const Text(
            'Google Drive connection is unavailable in this build while public access is being prepared. Local backups and settings JSON transfer remain available. No Google Cloud setup is needed by users.',
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: busy || !configured ? null : _connect,
              child: Text(
                connected ? 'Reconnect Google Drive' : 'Connect Google Drive',
              ),
            ),
            if (signingIn)
              TextButton(
                onPressed: () => auth!.flow.cancel(),
                child: const Text('Cancel sign-in'),
              ),
            if (connected || auth?.needsReconnect == true)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (await _confirm(
                              'Disconnect Google Drive?',
                              'Remove this profile’s saved Google credentials from this device. Cloud backups remain in Google Drive. To revoke the app grant too, use your Google Account connections page.',
                              'Disconnect',
                            ) &&
                            mounted) {
                          await _run(() async {
                            await auth!.disconnect();
                            if (mounted) setState(() => objects = []);
                          });
                        }
                      },
                child: const Text('Disconnect'),
              ),
            if (!connected && auth?.configurationStore != null)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        final file = await const WindowsSettingsFileDialog()
                            .chooseImport();
                        if (file == null) return;
                        if (await file.length() > 16 * 1024) {
                          throw const CloudFailure(
                            'Desktop OAuth configuration exceeds 16 KiB.',
                          );
                        }
                        await auth!.importClientConfiguration(
                          await file.readAsString(),
                        );
                        if (mounted) {
                          setState(
                            () => message = 'Desktop OAuth configuration saved securely on this device. Connect Google Drive to continue.',
                          );
                        }
                      }),
                child: const Text('Import Google Desktop configuration'),
              ),
            if (!connected && auth?.hasClientConfiguration == true)
              TextButton(
                onPressed: busy
                    ? null
                    : () => _run(() async {
                        await auth!.removeClientConfiguration();
                        if (mounted) setState(() {});
                      }),
                child: const Text('Remove OAuth configuration'),
              ),
          ],
        ),
        _heading('Cloud Backups'),
        const Text(
          'Encrypted snapshots on demand. Backups do not sync or merge devices.',
        ),
        const SizedBox(height: 10),
        Text(
          !connected
              ? 'Connect to view cloud backup history.'
              : full.isEmpty
              ? historyLoaded
                    ? 'No verified full backups in this account.'
                    : 'Refresh history to check the last successful full backup.'
              : 'Last successful full backup: ${_date(full.first.createdAt)}',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: ready
                  ? () => _upload(
                      CloudBackupKind.full,
                      SettingsTransfer.fromController(controller)
                          .encode(SettingsCategory.values.toSet()),
                    )
                  : null,
              child: const Text('Back Up Now'),
            ),
            OutlinedButton(
              onPressed: ready ? () => _browse(CloudBackupKind.full) : null,
              child: const Text('Restore from Google Drive'),
            ),
            TextButton(
              onPressed: ready ? () => _run(_list) : null,
              child: const Text('Refresh cloud backups'),
            ),
          ],
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          Text(stage),
          LinearProgressIndicator(value: progress),
          if (progress != null) Text('${(progress! * 100).round()}%'),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Last error: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SelectableText(message!),
          ),
        for (final object in objects)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_date(object.createdAt)),
                  Text(_details(object)),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: ready && _compatible(object)
                            ? () => _restore(object)
                            : null,
                        child: const Text('Download & review restore'),
                      ),
                      TextButton(
                        onPressed: ready
                            ? () async {
                                if (await _confirm(
                                      'Delete this cloud backup?',
                                      '${_date(object.createdAt)}\n${_details(object)}\n\nThis permanently deletes this snapshot from Google Drive. Keep another recoverable backup before deleting.',
                                      'Delete backup',
                                    ) &&
                                    mounted) {
                                  await _run(() async {
                                    await service!.provider.delete(object);
                                    await _list();
                                  });
                                }
                              }
                            : null,
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SettingsSection(
          title: 'How cloud backups work',
          children: [
            SettingsHelperText(
              'Includes every SQLite table and portable personalization. External linked files, PINs, credentials, per-widget customization, window position/startup and device-local controls are excluded. '
              'Backups stay in your Google account’s hidden app storage. Google receives encrypted contents and backup metadata. Todorbit reads account identity to show the connected account. '
              'Delete snapshots before disconnecting; disconnect keeps cloud files. Full backups are limited to a 50 MiB database.',
            ),
          ],
        ),
        const Text(
          'Keep your recovery passphrase separately: it cannot be recovered.',
        ),
        _heading('Settings & Preferences Backup'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: ready ? _settingsUpload : null,
              child: const Text('Back Up Settings to Google Drive'),
            ),
            OutlinedButton(
              onPressed: ready ? () => _browse(CloudBackupKind.settings) : null,
              child: const Text('Restore Settings from Google Drive'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => const SettingsTransferDialog(),
                    ),
              child: const Text('Import / Export Settings JSON'),
            ),
          ],
        ),
        const SettingsSection(
          title: 'About settings backups',
          children: [
            SettingsHelperText(
              'Select appearance and themes (including shared widget theme colors), hotkey presets, calendar, sidebar order and task display. Per-widget customization stays on this device. Restore selected categories without changing tasks or events. Named hotkey presets can merge.',
            ),
          ],
        ),
      ],
    );
  }
}
