import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../data/software_update_service.dart';
import '../../data/resumable_update_download.dart';
import 'android_platform.dart';

class AndroidUpdateDevice {
  const AndroidUpdateDevice({
    required this.versionName,
    required this.versionCode,
    required this.sdk,
    required this.abis,
    required this.distribution,
    this.directory,
    this.freeBytes = 0,
    this.canInstall = false,
  });
  final String versionName, distribution;
  final int versionCode, sdk, freeBytes;
  final List<String> abis;
  final String? directory;
  final bool canInstall;
  static Future<AndroidUpdateDevice> load() async {
    final data = (await AndroidPlatform.channel
        .invokeMapMethod<String, dynamic>('updateInfo'))!;
    return AndroidUpdateDevice(
      versionName: data['versionName'] as String,
      versionCode: data['versionCode'] as int,
      sdk: data['sdk'] as int,
      abis: (data['abis'] as List).cast<String>(),
      distribution: data['distribution'] as String,
      directory: data['directory'] as String?,
      freeBytes: data['freeBytes'] as int? ?? 0,
      canInstall: data['canInstall'] == true,
    );
  }
}

class AndroidUpdateRelease {
  const AndroidUpdateRelease({
    required this.tag,
    required this.versionName,
    required this.versionCode,
    required this.publishedAt,
    required this.notes,
    required this.uri,
    required this.size,
    required this.sha256Digest,
  });
  final String tag, versionName, notes, sha256Digest;
  final int versionCode, size;
  final DateTime publishedAt;
  final Uri uri;
  Map<String, Object> verification(File file) => {
    'path': file.path,
    'versionName': versionName,
    'versionCode': versionCode,
    'size': size,
    'sha256': sha256Digest,
  };
}

class AndroidUpdateCanceled implements Exception {
  const AndroidUpdateCanceled();
  @override
  String toString() => 'Download canceled. You can retry when ready.';
}

/// Android release metadata is independently discoverable in the shared repo.
/// SHA-256 binds assets to GitHub metadata; native APK verification separately
/// checks the installed publisher certificate and signed package metadata.
class AndroidUpdateService {
  AndroidUpdateService({
    HttpClient? client,
    HttpClient Function()? downloadClient,
  }) : _client = client ?? HttpClient(),
       _createDownloadClient = downloadClient ?? HttpClient.new;
  final HttpClient _client;
  final HttpClient Function() _createDownloadClient;
  late final transfer = ResumableUpdateDownload(
    approved: (uri) =>
        SoftwareUpdateService.approvedDownload(uri) &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443),
    client: _createDownloadClient,
  );
  Object? _releases;
  DateTime? _fetched;
  String? _etag;
  DateTime? _retryAfter;
  static const maxApkBytes = 1024 * 1024 * 1024;
  static const packageName = 'io.github.hik4.todorbit';
  static final _manifests = <String, Map<String, dynamic>>{};

  static String metadataName(String tag) =>
      'Todorbit-${tag.replaceFirst(RegExp(r'^v'), '')}-android-update.json';
  static bool official(Uri uri, String tag, String name) =>
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.pathSegments.join('/') ==
          '2HIK4/Todorbit/releases/download/$tag/$name';

  static Map<String, dynamic>? asset(Object? values, String name, String tag) {
    if (values is! List) return null;
    final matches = values
        .whereType<Map<String, dynamic>>()
        .where((a) => a['name'] == name)
        .toList();
    if (matches.length != 1) return null;
    final value = matches.single;
    final uri = Uri.tryParse('${value['browser_download_url']}');
    if (value['state'] != 'uploaded' ||
        uri == null ||
        !official(uri, tag, name) ||
        value['size'] is! int ||
        (value['size'] as int) <= 0 ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch('${value['digest']}')) {
      return null;
    }
    return value;
  }

  static AndroidUpdateRelease? parseManifest(
    Map<String, dynamic> manifest,
    Map<String, dynamic> release,
    AndroidUpdateDevice device,
    UpdateChannel channel,
  ) {
    final tag = release['tag_name'];
    final version = tag is String ? UpdateVersion.parse(tag) : null;
    final current = UpdateVersion.parse(device.versionName);
    if (version == null ||
        current == null ||
        version.compareTo(current) < 0 ||
        (channel == UpdateChannel.stable &&
            (release['prerelease'] == true || version.pre.isNotEmpty))) {
      return null;
    }
    final date = DateTime.tryParse('${release['published_at']}');
    final code = manifest['versionCode'];
    final sdk = manifest['minSdk'];
    final entries = manifest['apks'];
    if (release['draft'] != false ||
        date == null ||
        manifest['formatVersion'] != 1 ||
        manifest['packageName'] != packageName ||
        manifest['versionName'] != tag!.replaceFirst(RegExp(r'^v'), '') ||
        code is! int ||
        code <= device.versionCode ||
        code > 2100000000 ||
        sdk is! int ||
        sdk < 26 ||
        sdk > device.sdk ||
        entries is! List) {
      return null;
    }
    // Device ABI priority determines selection; universal APKs list each ABI.
    for (final abi in device.abis) {
      for (final entry
          in (entries.whereType<Map<String, dynamic>>().toList()..sort(
            (a, b) => (a['size'] is int ? a['size'] as int : maxApkBytes)
                .compareTo(b['size'] is int ? b['size'] as int : maxApkBytes),
          ))) {
        if (entry['abis'] is! List || !(entry['abis'] as List).contains(abi)) {
          continue;
        }
        final name = entry['name'];
        if (name is! String ||
            !RegExp(
              r'^Todorbit-[0-9A-Za-z.+-]+-android-(arm64|x64|universal)\.apk$',
            ).hasMatch(name)) {
          continue;
        }
        final a = asset(release['assets'], name, tag);
        if (a == null ||
            a['size'] != entry['size'] ||
            (a['size'] as int) > maxApkBytes ||
            '${a['digest']}'.substring(7).toLowerCase() != entry['sha256']) {
          continue;
        }
        return AndroidUpdateRelease(
          tag: tag,
          versionName: manifest['versionName'] as String,
          versionCode: code,
          publishedAt: date.toUtc(),
          notes: release['body'] is String ? release['body'] as String : '',
          uri: Uri.parse(a['browser_download_url'] as String),
          size: a['size'] as int,
          sha256Digest: entry['sha256'] as String,
        );
      }
    }
    return null;
  }

  Future<List<int>> _get(Uri uri, {int limit = 2 * 1024 * 1024}) async {
    for (var redirects = 0; redirects < 5; redirects++) {
      if (!SoftwareUpdateService.approvedDownload(uri) ||
          uri.userInfo.isNotEmpty ||
          (uri.hasPort && uri.port != 443)) {
        throw StateError('Unapproved update download source.');
      }
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw StateError('Invalid update redirect.');
        uri = uri.resolve(location);
        await response.drain<void>();
        continue;
      }
      if (response.statusCode != 200) {
        throw StateError(
          'Update metadata unavailable (HTTP ${response.statusCode}).',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
        if (bytes.length > limit) {
          throw const FormatException('Update metadata is too large.');
        }
      }
      return bytes;
    }
    throw StateError('Too many update redirects.');
  }

  Future<AndroidUpdateRelease?> check(
    AndroidUpdateDevice device,
    UpdateChannel channel,
  ) async {
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) {
      throw StateError(
        'GitHub is rate limited. Try again after ${_retryAfter!.toLocal()}.',
      );
    }
    if (_fetched == null ||
        DateTime.now().difference(_fetched!) > const Duration(minutes: 10)) {
      final request = await _client
          .getUrl(SoftwareUpdateService.releasesUri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Todorbit-Android-Updater',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      if (_etag != null) request.headers.set('If-None-Match', _etag!);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 403 || response.statusCode == 429) {
        final reset = int.tryParse(
          response.headers.value('x-ratelimit-reset') ?? '',
        );
        _retryAfter = reset == null
            ? DateTime.now().add(const Duration(minutes: 10))
            : DateTime.fromMillisecondsSinceEpoch(reset * 1000);
        throw StateError(
          'GitHub update checks are rate limited. Try again later.',
        );
      }
      if (response.statusCode == 200) {
        final bytes = <int>[];
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 8 * 1024 * 1024) {
            throw const FormatException('Release response too large.');
          }
        }
        _releases = jsonDecode(utf8.decode(bytes));
        if (_releases is! List) {
          throw const FormatException('Malformed GitHub release response.');
        }
        _etag = response.headers.value('etag');
      } else if (response.statusCode != 304 || _releases == null) {
        throw StateError(
          'GitHub update check failed (HTTP ${response.statusCode}).',
        );
      }
      _fetched = DateTime.now();
    }
    AndroidUpdateRelease? selected;
    var invalidAndroidRelease = false;
    for (final release
        in (_releases as List).whereType<Map<String, dynamic>>()) {
      final tag = release['tag_name'];
      final version = tag is String ? UpdateVersion.parse(tag) : null;
      if (version == null ||
          release['draft'] != false ||
          release['published_at'] == null ||
          version.compareTo(UpdateVersion.parse(device.versionName)!) < 0 ||
          (channel == UpdateChannel.stable &&
              (release['prerelease'] == true || version.pre.isNotEmpty))) {
        continue;
      }
      final a = asset(release['assets'], metadataName(tag as String), tag);
      // Windows-only releases are normal and are ignored.
      if (a == null) {
        if (release['assets'] case final List values
            when values.any(
              (v) => v is Map && '${v['name']}'.contains('-android-'),
            )) {
          invalidAndroidRelease = true;
        }
        continue;
      }
      if ((a['size'] as int) > 1024 * 1024) {
        invalidAndroidRelease = true;
        continue;
      }
      final key = '${a['digest']}';
      var manifest = _manifests[key];
      if (manifest == null) {
        final bytes = await _get(
          Uri.parse(a['browser_download_url'] as String),
          limit: 1024 * 1024,
        );
        if (bytes.length != a['size'] ||
            'sha256:${sha256.convert(bytes)}' != key.toLowerCase()) {
          throw StateError('Android release metadata checksum failed.');
        }
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Malformed Android update metadata.');
        }
        manifest = _manifests[key] = decoded;
      }
      final candidate = parseManifest(manifest, release, device, channel);
      if (candidate != null &&
          (selected == null || candidate.versionCode > selected.versionCode)) {
        selected = candidate;
      }
    }
    if (selected == null && invalidAndroidRelease) {
      throw StateError(
        'An Android release has incomplete or unverified assets. Try again after the publisher completes it.',
      );
    }
    return selected;
  }

  // Partial updates are user-owned until explicitly discarded.
  Future<void> clean(Directory directory, {String? keep}) async {
    await directory.create(recursive: true);
  }

  File target(AndroidUpdateRelease release, AndroidUpdateDevice device) =>
      File(path.join(device.directory!, path.basename(release.uri.path)));
  Map<String, Object> identity(AndroidUpdateRelease release) =>
      ResumableUpdateDownload.identity(
        release.uri,
        release.size,
        release.sha256Digest,
        '${release.versionName}+${release.versionCode}',
      );
  Future<int> saved(AndroidUpdateRelease release, AndroidUpdateDevice device) =>
      transfer.saved(target(release, device), identity(release));
  Future<void> discard(
    AndroidUpdateRelease release,
    AndroidUpdateDevice device,
  ) => transfer.discard(target(release, device));

  Future<File> download(
    AndroidUpdateRelease release,
    AndroidUpdateDevice device,
    void Function(int received, int total) progress,
  ) async {
    if (!official(release.uri, release.tag, path.basename(release.uri.path))) {
      throw StateError('Unapproved update source.');
    }
    final retained = await saved(release, device);
    if (device.freeBytes < release.size * 2 - retained + 32 * 1024 * 1024) {
      throw StateError(
        'Not enough free storage for this update. Free some space and retry.',
      );
    }
    return transfer.download(
      uri: release.uri,
      target: target(release, device),
      size: release.size,
      digest: release.sha256Digest,
      version: '${release.versionName}+${release.versionCode}',
      progress: progress,
    );
  }

  void pauseDownload() => transfer.pause();
  void cancelDownload() => pauseDownload();

  Future<void> remember(
    AndroidUpdateRelease release,
    AndroidUpdateDevice device,
  ) async {
    final file = File(path.join(device.directory!, 'selected-update.json'));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'tag': release.tag,
        'versionName': release.versionName,
        'versionCode': release.versionCode,
        'publishedAt': release.publishedAt.toIso8601String(),
        'notes': release.notes,
        'uri': release.uri.toString(),
        'size': release.size,
        'sha256': release.sha256Digest,
      }),
      flush: true,
    );
  }

  Future<AndroidUpdateRelease?> remembered(AndroidUpdateDevice device) async {
    try {
      final data = jsonDecode(
        await File(path.join(device.directory!, 'selected-update.json'))
            .readAsString(),
      ) as Map;
      final release = AndroidUpdateRelease(
        tag: data['tag'] as String,
        versionName: data['versionName'] as String,
        versionCode: data['versionCode'] as int,
        publishedAt: DateTime.parse(data['publishedAt'] as String),
        notes: data['notes'] as String,
        uri: Uri.parse(data['uri'] as String),
        size: data['size'] as int,
        sha256Digest: data['sha256'] as String,
      );
      if (release.versionCode <= device.versionCode ||
          release.size <= 0 ||
          release.size > maxApkBytes ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(release.sha256Digest) ||
          !official(
            release.uri,
            release.tag,
            path.basename(release.uri.path),
          )) {
        return null;
      }
      return release;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> verify(AndroidUpdateRelease release, File file) =>
      AndroidPlatform.channel.invokeMethod<void>(
        'updateVerify',
        release.verification(file),
      );
  Future<bool> requestInstallPermission() async =>
      await AndroidPlatform.channel.invokeMethod<bool>('updatePermission') ??
      false;
  Future<String> install(AndroidUpdateRelease release, File file) async =>
      await AndroidPlatform.channel.invokeMethod<String>(
        'updateInstall',
        release.verification(file),
      ) ??
      'failed';
  void close() {
    cancelDownload();
    _client.close(force: true);
  }
}
