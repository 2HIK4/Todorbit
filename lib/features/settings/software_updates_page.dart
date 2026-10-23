import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../data/profile_paths.dart';
import '../../data/software_update_service.dart';
import '../../app/app_controller.dart';
import '../widget/native_widget_service.dart';

enum UpdateStatus {
  idle,
  checking,
  current,
  available,
  downloading,
  ready,
  offline,
  failed,
}

class SoftwareUpdatesPage extends ConsumerStatefulWidget {
  const SoftwareUpdatesPage({
    super.key,
    required this.nativeWidget,
    this.preferenceStore,
  });
  final NativeWidgetService nativeWidget;
  final UpdatePreferenceStore? preferenceStore;

  @override
  ConsumerState<SoftwareUpdatesPage> createState() =>
      _SoftwareUpdatesPageState();
}

class _SoftwareUpdatesPageState extends ConsumerState<SoftwareUpdatesPage> {
  final _service = SoftwareUpdateService();
  late final UpdatePreferenceStore _store;
  UpdatePreferences _preferences = const UpdatePreferences();
  UpdateRelease? _release;
  UpdateStatus _status = UpdateStatus.idle;
  String? _error;
  String _version = 'Loading…';
  File? _package;
  int _received = 0;
  bool _portable = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _store = widget.preferenceStore ?? UpdatePreferenceStore.forActiveProfile();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final version = Platform.isWindows
          ? await const MethodChannel('life_manager/window_theme')
                .invokeMethod<String>('getVersion')
          : null;
      final preferences = await _store.load();
      final portable = File(
        path.join(
          File(Platform.resolvedExecutable).parent.path,
          ProfilePaths.portableMarkerName,
        ),
      ).existsSync();
      if (!mounted) return;
      final previousFailure = widget.preferenceStore == null
          ? await _lastInstallFailure()
          : null;
      if (!mounted) return;
      setState(() {
        _version = version ?? 'Unknown';
        _preferences = preferences;
        _portable = portable;
        if (previousFailure != null) {
          _status = UpdateStatus.failed;
          _error = previousFailure;
        }
      });
      if (preferences.automaticChecks && previousFailure == null) {
        await _check();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.failed;
          _error = '$error';
        });
      }
    }
  }

  Future<String?> _lastInstallFailure() async {
    final root = Directory(
      path.join(ProfilePaths.activeDirectory().path, 'updates'),
    );
    if (!await root.exists()) return null;
    final results = <File>[];
    await for (final child in root.list()) {
      if (child is Directory) {
        final result = File(path.join(child.path, 'last-install-result.txt'));
        if (await result.exists()) results.add(result);
      }
    }
    if (results.isEmpty) return null;
    results.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    final message = await results.first.readAsString();
    return message.startsWith('Update failed:') ? message.trim() : null;
  }

  Future<void> _save(UpdatePreferences value) async {
    try {
      await _store.save(value);
      if (mounted) setState(() => _preferences = value);
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.failed;
          _error = 'Could not save update settings: $error';
        });
      }
    }
  }

  Future<void> _check() async {
    if (_status == UpdateStatus.checking ||
        _status == UpdateStatus.downloading ||
        _version == 'Loading…') {
      return;
    }
    setState(() {
      _status = UpdateStatus.checking;
      _error = null;
      _release = null;
      _package = null;
    });
    try {
      final result = await _service.check(
        currentVersion: _version,
        channel: _preferences.channel,
        portable: _portable,
      );
      final updated = _preferences.copyWith(
        lastChecked: DateTime.now().toUtc(),
      );
      await _store.save(updated);
      if (!mounted) return;
      setState(() {
        _preferences = updated;
        _release = result;
        _status = result == null
            ? UpdateStatus.current
            : UpdateStatus.available;
      });
    } on SocketException catch (error) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.offline;
          _error = 'No internet connection: $error';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.failed;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _download() async {
    final release = _release;
    if (release == null) return;
    setState(() {
      _status = UpdateStatus.downloading;
      _received = 0;
      _error = null;
    });
    try {
      final folder = Directory(
        path.join(ProfilePaths.activeDirectory().path, 'updates', release.tag),
      );
      final package = await _service.download(
        release,
        folder,
        onProgress: (received, _) {
          if (mounted) setState(() => _received = received);
        },
      );
      if (mounted) {
        setState(() {
          _package = package;
          _status = UpdateStatus.ready;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.failed;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _install() async {
    if (_installing) return;
    final package = _package;
    final release = _release;
    if (package == null || release == null) return;
    setState(() => _installing = true);
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Install Todorbit ${release.tag}?'),
        content: const Text(
          'The package matches the SHA-256 digest published by GitHub, but '
          'Todorbit releases are currently unsigned. A checksum does not prove '
          'publisher identity. The app and widget will close, then Todorbit '
          'will restart. Keep your backup before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Install unsigned update'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) {
      if (mounted) setState(() => _installing = false);
      return;
    }
    try {
      // Installation is delegated to a separate process after verification.
      if (widget.nativeWidget.isAvailable) {
        await widget.nativeWidget.close();
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _launchInstaller(package);
    } catch (error) {
      if (mounted) {
        setState(() {
          _installing = false;
          _status = UpdateStatus.failed;
          _error = 'Could not start update: $error';
        });
      }
    }
  }

  Future<void> _launchInstaller(File package) async {
    if (!Platform.isWindows) throw StateError('Windows updates only');
    final release = _release!;
    if ((await package.length()) != release.size ||
        (await sha256.bind(package.openRead()).first).toString() !=
            release.sha256Digest) {
      throw StateError('Downloaded package changed after verification');
    }
    final target = File(Platform.resolvedExecutable).parent;
    String stage = '';
    if (_portable) {
      final parent = target.parent;
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final container = Directory(
        path.join(parent.path, '.todorbit-extract-$nonce'),
      );
      await container.create();
      try {
        await Isolate.run(() => _extractPortable(package.path, container.path));
        final extracted = Directory(path.join(container.path, 'Todorbit'));
        if (!await File(path.join(extracted.path, 'Todorbit.exe')).exists() ||
            !await File(path.join(extracted.path, 'TodorbitWidget.exe'))
                .exists() ||
            !await File(path.join(extracted.path, 'PORTABLE-MODE')).exists() ||
            !await File(path.join(extracted.path, 'flutter_windows.dll'))
                .exists() ||
            !await File(path.join(extracted.path, 'sqlite3.dll')).exists()) {
          throw StateError('Portable archive lacks required application files');
        }
        stage = path.join(parent.path, '.todorbit-stage-$nonce');
        await extracted.rename(stage);
      } finally {
        if (await container.exists()) await container.delete(recursive: true);
      }
    } else if (path.extension(package.path).toLowerCase() != '.exe') {
      throw StateError('Unexpected installer package');
    }
    final script = File(path.join(package.parent.path, 'update-helper.ps1'));
    final bundled = await rootBundle.loadString('tools/update-helper.ps1');
    await script.writeAsString(bundled, flush: true);
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
      '-Mode',
      _portable ? 'portable' : 'installed',
      '-Package',
      package.path,
      '-Target',
      target.path,
      '-Digest',
      release.sha256Digest,
      '-Size',
      '${release.size}',
      '-ParentPid',
      '$pid',
      if (_portable) ...['-Stage', stage],
    ], mode: ProcessStartMode.detached);
    if (process.pid <= 0) throw StateError('Update helper did not start');
    try {
      await ref.read(appControllerProvider).repository.db.close();
    } finally {
      // Once the helper is running, this process must release bundle files.
      exit(0);
    }
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    final total = release?.size ?? 0;
    final statusText = switch (_status) {
      UpdateStatus.idle => 'Ready to check',
      UpdateStatus.checking => 'Checking GitHub Releases…',
      UpdateStatus.current => 'Up to date',
      UpdateStatus.available => 'Update available',
      UpdateStatus.downloading => 'Downloading update…',
      UpdateStatus.ready => 'Ready to install',
      UpdateStatus.offline => 'Offline',
      UpdateStatus.failed => 'Update failed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: const Text('Installed version'),
          subtitle: Text(_version),
        ),
        ListTile(title: const Text('Status'), subtitle: Text(statusText)),
        ListTile(
          title: const Text('Last checked'),
          subtitle: Text(
            _preferences.lastChecked == null
                ? 'Never'
                : _preferences.lastChecked!.toLocal().toString(),
          ),
        ),
        SwitchListTile(
          title: const Text('Automatically check for updates'),
          subtitle: const Text(
            'Checks when you open Software Updates; downloads require your approval.',
          ),
          value: _preferences.automaticChecks,
          onChanged: (value) =>
              _save(_preferences.copyWith(automaticChecks: value)),
        ),
        DropdownButtonFormField<UpdateChannel>(
          initialValue: _preferences.channel,
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
          onChanged: (value) async {
            if (value == null) return;
            await _save(_preferences.copyWith(channel: value));
            if (mounted) {
              setState(() {
                _status = UpdateStatus.idle;
                _release = null;
                _package = null;
              });
            }
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed:
                _status == UpdateStatus.checking ||
                    _status == UpdateStatus.downloading
                ? null
                : _check,
            icon: const Icon(Icons.refresh),
            label: const Text('Check for Updates'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (release != null) ...[
          const SizedBox(height: 16),
          Text(
            'Todorbit ${release.tag}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            release.notes.isEmpty
                ? 'No release notes provided.'
                : release.notes,
          ),
          const SizedBox(height: 12),
          if (_status == UpdateStatus.downloading)
            LinearProgressIndicator(
              value: total == 0 ? null : _received / total,
            ),
          if (_status == UpdateStatus.downloading)
            Text('$_received of $total bytes'),
          if (_status == UpdateStatus.available ||
              _status == UpdateStatus.failed)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _download,
                child: Text(
                  _status == UpdateStatus.failed
                      ? 'Retry download'
                      : 'Download update',
                ),
              ),
            ),
          if (_status == UpdateStatus.ready)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _installing ? null : _install,
                child: Text(
                  _installing ? 'Preparing update…' : 'Update and Restart',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

void _extractPortable(String archivePath, String containerPath) {
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input, verify: true);
    final names = <String>{};
    var total = 0;
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      if (!name.startsWith('Todorbit/') ||
          name.contains('..') ||
          name.contains(':') ||
          file.isSymbolicLink ||
          !names.add(name.toLowerCase())) {
        throw const FormatException(
          'Unsafe or duplicate portable archive entry',
        );
      }
      total += file.size;
      if (total > 1024 * 1024 * 1024) {
        throw const FormatException(
          'Portable archive expands beyond the allowed size',
        );
      }
      if (RegExp(
        r'\.(sqlite|db)(-wal|-shm)?$|\.log$|\.pem$|\.key$',
        caseSensitive: false,
      ).hasMatch(name)) {
        throw const FormatException('Portable archive contains private data');
      }
    }
    extractArchiveToDiskSync(
      archive,
      containerPath,
      maxSize: 1024 * 1024 * 1024,
    );
  } finally {
    input.closeSync();
  }
}
