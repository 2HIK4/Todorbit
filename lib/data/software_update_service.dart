import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'profile_paths.dart';

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

  Future<File> download(
    UpdateRelease release,
    Directory stagingDirectory, {
    void Function(int received, int total)? onProgress,
  }) async {
    await stagingDirectory.create(recursive: true);
    final target = File(
      path.join(stagingDirectory.path, path.basename(release.assetUri.path)),
    );
    final partial = File('${target.path}.part');
    if (await partial.exists()) await partial.delete();
    try {
      var uri = release.assetUri;
      HttpClientResponse? response;
      for (var redirect = 0; redirect < 5; redirect++) {
        if (!_approvedDownload(uri)) {
          throw StateError('Unapproved download source');
        }
        final request = await _client
            .getUrl(uri)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Todorbit-Update-Checker',
        );
        response = await request.close().timeout(const Duration(seconds: 20));
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw StateError('Download redirect has no location');
          }
          uri = uri.resolve(location);
          continue;
        }
        break;
      }
      if (response == null ||
          response.statusCode != 200 ||
          response.isRedirect) {
        throw StateError('Package download failed (${response?.statusCode}).');
      }
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          received += chunk.length;
          if (received > release.size) {
            throw StateError('Download exceeds published size');
          }
          sink.add(chunk);
          onProgress?.call(received, release.size);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received != release.size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              release.sha256Digest) {
        throw StateError(
          'Package size or SHA-256 digest does not match the release',
        );
      }
      if (await target.exists()) await target.delete();
      return await partial.rename(target.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  void close() => _client.close(force: true);
}
