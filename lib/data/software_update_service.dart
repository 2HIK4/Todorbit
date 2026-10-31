import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'profile_paths.dart';
import 'resumable_update_download.dart';

enum UpdateChannel { stable, prerelease }

class UpdatePreferences {
  const UpdatePreferences({
    this.automaticChecks = true,
    this.channel = UpdateChannel.stable,
    this.lastChecked,
  });

  final bool automaticChecks;
  final UpdateChannel channel;
  final DateTime? lastChecked;

  UpdatePreferences copyWith({
    bool? automaticChecks,
    UpdateChannel? channel,
    DateTime? lastChecked,
  }) => UpdatePreferences(
    automaticChecks: automaticChecks ?? this.automaticChecks,
    channel: channel ?? this.channel,
    lastChecked: lastChecked ?? this.lastChecked,
  );
}

class UpdatePreferenceStore {
  UpdatePreferenceStore(this.file);
  final File file;

  factory UpdatePreferenceStore.forActiveProfile() => UpdatePreferenceStore(
    File(
      path.join(ProfilePaths.activeDirectory().path, 'update-settings.json'),
    ),
  );

  Future<UpdatePreferences> load() async {
    if (!await file.exists()) return const UpdatePreferences();
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['automaticChecks'] is! bool ||
        !const ['stable', 'prerelease'].contains(value['channel']) ||
        (value['lastCheckedUtc'] != null &&
            value['lastCheckedUtc'] is! String)) {
      throw const FormatException('Unsupported update settings format');
    }
    final checked = value['lastCheckedUtc'];
    return UpdatePreferences(
      automaticChecks: value['automaticChecks'] as bool,
      channel: value['channel'] == 'prerelease'
          ? UpdateChannel.prerelease
          : UpdateChannel.stable,
      lastChecked: checked is String ? DateTime.parse(checked).toUtc() : null,
    );
  }

  Future<void> save(UpdatePreferences value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'automaticChecks': value.automaticChecks,
        'channel': value.channel.name,
        'lastCheckedUtc': value.lastChecked?.toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}

class UpdateVersion implements Comparable<UpdateVersion> {
  UpdateVersion._(this.major, this.minor, this.patch, this.pre);
  final int major;
  final int minor;
  final int patch;
  final List<String> pre;

  static UpdateVersion? parse(String value) {
    final match = RegExp(
      r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(value);
    if (match == null) return null;
    final pre = match.group(4)?.split('.') ?? <String>[];
    if (pre.any(
      (part) =>
          RegExp(r'^\d+$').hasMatch(part) &&
          part.length > 1 &&
          part.startsWith('0'),
    )) {
      return null;
    }
    return UpdateVersion._(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      pre,
    );
  }

  @override
  int compareTo(UpdateVersion other) {
    for (final pair in [
      [major, other.major],
      [minor, other.minor],
      [patch, other.patch],
    ]) {
      final comparison = pair[0].compareTo(pair[1]);
      if (comparison != 0) return comparison;
    }
    if (pre.isEmpty || other.pre.isEmpty) {
      return pre.isEmpty == other.pre.isEmpty ? 0 : (pre.isEmpty ? 1 : -1);
    }
    for (
      var index = 0;
      index < pre.length && index < other.pre.length;
      index++
    ) {
      final left = pre[index];
      final right = other.pre[index];
      final leftNumeric = RegExp(r'^\d+$').hasMatch(left);
      final rightNumeric = RegExp(r'^\d+$').hasMatch(right);
      final comparison = leftNumeric && rightNumeric
          ? (left.length == right.length
                ? left.compareTo(right)
                : left.length.compareTo(right.length))
          : leftNumeric
          ? -1
          : rightNumeric
          ? 1
          : left.compareTo(right);
      if (comparison != 0) return comparison;
    }
    return pre.length.compareTo(other.pre.length);
  }
}

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.notes,
    required this.assetUri,
    required this.sha256Digest,
    required this.size,
  });
  final UpdateVersion version;
  final String tag;
  final String notes;
  final Uri assetUri;
  final String sha256Digest;
  final int size;
}

class SoftwareUpdateService {
  SoftwareUpdateService({HttpClient? client, this.allowedDownloadHosts})
    : _client = client ?? HttpClient();
  final HttpClient _client;
  final Set<String>? allowedDownloadHosts;
  static final releasesUri = Uri.https(
    'api.github.com',
    '/repos/2HIK4/Todorbit/releases',
    {'per_page': '100'},
  );

  static String assetName(String tag, {required bool portable}) =>
      'Todorbit-${tag.startsWith('v') ? tag.substring(1) : tag}-win-x64-'
      '${portable ? 'portable.zip' : 'setup.exe'}';

  static bool approvedDownload(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      const {
        'github.com',
        'release-assets.githubusercontent.com',
        'objects.githubusercontent.com',
      }.contains(uri.host);

  bool _approvedDownload(Uri uri) {
    final hosts = allowedDownloadHosts;
    return hosts == null ? approvedDownload(uri) : hosts.contains(uri.host);
  }

  static UpdateRelease? selectRelease(
    Object? data, {
    required String currentVersion,
    required UpdateChannel channel,
    required bool portable,
  }) {
    final current = UpdateVersion.parse(currentVersion);
    if (current == null || data is! List) {
      throw const FormatException(
        'Invalid installed version or release response',
      );
    }
    UpdateRelease? selected;
    var newerPublished = false;
    for (final value in data) {
      if (value is! Map<String, dynamic> ||
          value['draft'] != false ||
          value['published_at'] == null) {
        continue;
      }
      final tag = value['tag_name'];
      if (tag is! String) continue;
      final version = UpdateVersion.parse(tag);
      if (version == null ||
          version.compareTo(current) <= 0 ||
          (channel == UpdateChannel.stable &&
              (value['prerelease'] == true || version.pre.isNotEmpty))) {
        continue;
      }
      newerPublished = true;
      final assets = value['assets'];
      if (assets is! List) continue;
      final name = assetName(tag, portable: portable);
      final matching = assets
          .whereType<Map<String, dynamic>>()
          .where(
            (asset) => asset['name'] == name && asset['state'] == 'uploaded',
          )
          .toList();
      if (matching.length != 1) continue;
      final asset = matching.single;
      final uri = Uri.tryParse(asset['browser_download_url']?.toString() ?? '');
      final digest = asset['digest']?.toString() ?? '';
      final size = asset['size'];
      if (uri == null ||
          !approvedDownload(uri) ||
          uri.host != 'github.com' ||
          uri.pathSegments.join('/') !=
              '2HIK4/Todorbit/releases/download/$tag/$name' ||
          !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
          size is! int ||
          size <= 0) {
        continue;
      }
      final release = UpdateRelease(
        version: version,
        tag: tag,
        notes: value['body'] is String ? value['body'] as String : '',
        assetUri: uri,
        sha256Digest: digest.substring(7).toLowerCase(),
        size: size,
      );
      if (selected == null || version.compareTo(selected.version) > 0) {
        selected = release;
      }
    }
    if (selected == null && newerPublished) {
      throw StateError(
        'A newer release exists, but it has no verified Windows x64 package '
        'for this installation type.',
      );
    }
    return selected;
  }

  Future<UpdateRelease?> check({
    required String currentVersion,
    required UpdateChannel channel,
    required bool portable,
  }) async {
    final request = await _client
        .getUrl(releasesUri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'Todorbit-Update-Checker');
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw StateError(
        'GitHub update checks are rate limited. Try again later.',
      );
    }
    if (response.statusCode != 200) {
      throw StateError('GitHub release check failed (${response.statusCode}).');
    }
    final body = await utf8.decoder.bind(response).join();
    return selectRelease(
      jsonDecode(body),
      currentVersion: currentVersion,
      channel: channel,
      portable: portable,
    );
  }

  Future<void> remember(UpdateRelease release, Directory root) async {
    await root.create(recursive: true);
    await File(path.join(root.path, 'selected-update.json')).writeAsString(
      jsonEncode({
        'tag': release.tag,
        'notes': release.notes,
        'uri': release.assetUri.toString(),
        'size': release.size,
        'sha256': release.sha256Digest,
      }),
      flush: true,
    );
  }

  Future<UpdateRelease?> remembered(
    Directory root,
    String currentVersion,
    bool portable,
  ) async {
    try {
      final data = jsonDecode(
        await File(path.join(root.path, 'selected-update.json')).readAsString(),
      ) as Map;
      final version = UpdateVersion.parse(data['tag'] as String);
      final uri = Uri.parse(data['uri'] as String);
      if (version == null ||
          version.compareTo(UpdateVersion.parse(currentVersion)!) <= 0 ||
          uri !=
              Uri.https(
                'github.com',
                '/2HIK4/Todorbit/releases/download/${data['tag']}/${assetName(data['tag'] as String, portable: portable)}',
              ) ||
          data['size'] is! int ||
          (data['size'] as int) <= 0 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['sha256'] as String)) {
        return null;
      }
      return UpdateRelease(
        version: version,
        tag: data['tag'] as String,
        notes: data['notes'] as String,
        assetUri: uri,
        sha256Digest: data['sha256'] as String,
        size: data['size'] as int,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  late final transfer = ResumableUpdateDownload(approved: _approvedDownload);
  File target(UpdateRelease release, Directory folder) =>
      File(path.join(folder.path, path.basename(release.assetUri.path)));
  Map<String, Object> identity(UpdateRelease release) =>
      ResumableUpdateDownload.identity(
        release.assetUri,
        release.size,
        release.sha256Digest,
        release.tag,
      );
  Future<int> saved(UpdateRelease release, Directory folder) =>
      transfer.saved(target(release, folder), identity(release));
  Future<void> discard(UpdateRelease release, Directory folder) =>
      transfer.discard(target(release, folder));
  void pauseDownload() => transfer.pause();

  Future<File> download(
    UpdateRelease release,
    Directory stagingDirectory, {
    void Function(int received, int total)? onProgress,
  }) => transfer.download(
    uri: release.assetUri,
    target: target(release, stagingDirectory),
    size: release.size,
    digest: release.sha256Digest,
    version: release.tag,
    progress: onProgress ?? (_, _) {},
  );

  void close() {
    pauseDownload();
    _client.close(force: true);
  }
}
