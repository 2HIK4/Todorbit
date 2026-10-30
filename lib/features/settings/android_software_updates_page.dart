import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/software_update_service.dart';
import '../../platform/android/android_platform.dart';
import '../../platform/android/android_update_service.dart';
import '../shared/download_size.dart';

class AndroidSoftwareUpdatesPage extends StatefulWidget {
  const AndroidSoftwareUpdatesPage({
    super.key,
    this.service,
    this.store,
    this.loadDevice,
  });
  final AndroidUpdateService? service;
  final UpdatePreferenceStore? store;
  final Future<AndroidUpdateDevice> Function()? loadDevice;
  @override
  State<AndroidSoftwareUpdatesPage> createState() =>
      _AndroidSoftwareUpdatesPageState();
}

class _AndroidSoftwareUpdatesPageState
    extends State<AndroidSoftwareUpdatesPage> {
  late final service = widget.service ?? AndroidUpdateService();
  late final store = widget.store ?? UpdatePreferenceStore.forActiveProfile();
  UpdatePreferences preferences = const UpdatePreferences(
    automaticChecks: false,
  );
  AndroidUpdateDevice? device;
  AndroidUpdateRelease? release;
  File? apk;
  bool busy = false, downloading = false;
  int received = 0;
  String status = 'Check for a newer Android release.', error = '';

  @override
  void initState() {
    super.initState();
    unawaited(initialize());
  }

  Future<void> initialize() => run(() async {
    final loaded = await (widget.loadDevice ?? AndroidUpdateDevice.load)();
    preferences = await store.load();
    device = loaded;
    if (loaded.directory != null) {
      await service.clean(Directory(loaded.directory!));
    }
  });

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = switch (failure) {
            SocketException() =>
              'Network unavailable. Connect to the internet and retry.',
            TimeoutException() =>
              'The request timed out. Retry when connected.',
            PlatformException() =>
              failure.message ?? 'Android could not finish this operation.',
            _ => '$failure'.replaceFirst('Bad state: ', ''),
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          downloading = false;
        });
      }
    }
  }

  Future<void> check() => run(() async {
    status = 'Checking GitHub for Android releases…';
    release = null;
    apk = null;
    final found = await service.check(device!, preferences.channel);
    preferences = preferences.copyWith(lastChecked: DateTime.now().toUtc());
    await store.save(preferences);
    release = found;
    status = found == null
        ? 'No newer compatible Android update is available.'
        : 'An Android update is available.';
  });

  Future<void> download() => run(() async {
    downloading = true;
    received = 0;
    status = 'Downloading update…';
    if (mounted) setState(() {});
    final current = await (widget.loadDevice ?? AndroidUpdateDevice.load)();
    final file = await service.download(release!, current, (done, total) {
      if (mounted) setState(() => received = done);
    });
    downloading = false;
    status = 'Verifying APK signature, publisher and device compatibility…';
    if (mounted) setState(() {});
    try {
      await service.verify(release!, file);
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
    apk = file;
    status = 'Verified update is ready to install.';
  });

  Future<void> install() => run(() async {
    var current = await (widget.loadDevice ?? AndroidUpdateDevice.load)();
    if (!current.canInstall) {
      if (!mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow updates from Todorbit'),
          content: const Text(
            'Android needs your permission to install this GitHub update. On the next system screen, allow Todorbit to install apps. Android will still ask you to approve the update. Your tasks and settings stay in place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Android settings'),
            ),
          ],
        ),
      );
      if (allow != true) {
        status = 'Installation canceled. The verified download is retained.';
        return;
      }
      if (!await service.requestInstallPermission()) {
        status = 'Installation permission was not granted. Tap Install Update when ready.';
        return;
      }
      current = await (widget.loadDevice ?? AndroidUpdateDevice.load)();
    }
    if (!mounted) return;
    status = 'Waiting for your approval in Android’s package installer…';
    setState(() {});
    final result = await service.install(release!, apk!);
    status = switch (result) {
      'installed' => 'Update installed. Open Todorbit from your launcher.',
      'canceled' =>
        'Installation canceled. The verified download is retained for retry.',
      _ => 'Android did not finish installation. You can retry; existing app data is retained.',
    };
  });

  @override
  void dispose() {
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installed = device;
    return Scaffold(
      appBar: AppBar(title: const Text('Software Updates')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Todorbit for Android',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              installed == null
                  ? 'Loading installed version…'
                  : 'Installed version: ${installed.versionName}\nBuild number: ${installed.versionCode}\nDistribution: ${installed.distribution == 'play' ? 'Google Play' : 'GitHub'}',
            ),
            const SizedBox(height: 16),
            if (installed?.distribution == 'play') ...[
              const Text(
                'Google Play manages updates for this build. Check the official store for availability.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => run(
                        () => AndroidPlatform.channel.invokeMethod<void>(
                          'updatePlay',
                        ),
                      ),
                child: const Text('Check Google Play'),
              ),
            ] else ...[
              DropdownButtonFormField<UpdateChannel>(
                key: ValueKey(preferences.channel),
                initialValue: preferences.channel,
                decoration: const InputDecoration(labelText: 'Update channel'),
                items: const [
                  DropdownMenuItem(
                    value: UpdateChannel.stable,
                    child: Text('Stable'),
                  ),
                  DropdownMenuItem(
                    value: UpdateChannel.prerelease,
                    child: Text('Pre-release'),
                  ),
                ],
                onChanged: busy || installed == null
                    ? null
                    : (value) => run(() async {
                        preferences = preferences.copyWith(channel: value!);
                        await store.save(preferences);
                        release = null;
                        apk = null;
                        status = 'Channel changed. Check for updates.';
                      }),
              ),
              const SizedBox(height: 12),
              const Text(
                'Stable shows stable Android releases. Pre-release also includes experimental releases.',
              ),
              const SizedBox(height: 12),
              Text(
                preferences.lastChecked == null
                    ? 'Last checked: Never'
                    : 'Last checked: ${preferences.lastChecked!.toLocal()}',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy || installed == null ? null : check,
                icon: const Icon(Icons.refresh),
                label: const Text('Check for Updates'),
              ),
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(status)),
              if (downloading && release != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: received / release!.size,
                  semanticsLabel: 'Update download progress',
                ),
                Text(
                  '${(received * 100 / release!.size).round()}% · ${formatDownloadSize(received)} / ${formatDownloadSize(release!.size)}',
                ),
                TextButton(
                  onPressed: service.cancelDownload,
                  child: const Text('Cancel download'),
                ),
              ] else if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (release case final available?) ...[
                const Divider(height: 32),
                Text(
                  'Version ${available.versionName} (${available.versionCode})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Released: ${available.publishedAt.toLocal()}\nDownload: ${formatDownloadSize(available.size)}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (apk == null)
                      FilledButton(
                        onPressed: busy ? null : download,
                        child: const Text('Download Update'),
                      ),
                    if (apk != null)
                      FilledButton(
                        onPressed: busy ? null : install,
                        child: const Text('Install Update'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Release notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                MarkdownBody(
                  data: available.notes.isEmpty
                      ? 'No release notes provided.'
                      : available.notes,
                  selectable: true,
                  onTapLink: (_, href, _) {
                    final uri = Uri.tryParse(href ?? '');
                    if (uri?.scheme == 'https') {
                      unawaited(
                        launchUrl(uri!, mode: LaunchMode.externalApplication),
                      );
                    }
                  },
                ),
              ],
            ],
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Updates preserve app data when signed by the same publisher. Android controls installation and may close Todorbit. Reopen it from your launcher after updating.',
            ),
          ],
        ),
      ),
    );
  }
}
