import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/software_update_service.dart';
import 'package:life_manager/data/resumable_update_download.dart';
import 'package:life_manager/platform/android/android_update_service.dart';

const device = AndroidUpdateDevice(
  versionName: '1.0.18',
  versionCode: 19,
  sdk: 35,
  abis: ['arm64-v8a', 'x86_64'],
  distribution: 'github',
);

Map<String, dynamic> apkAsset(
  String name, {
  String tag = 'v1.0.19',
  String? digest,
  int size = 100,
}) => {
  'name': name,
  'state': 'uploaded',
  'size': size,
  'digest': 'sha256:${digest ?? 'a' * 64}',
  'browser_download_url':
      'https://github.com/2HIK4/Todorbit/releases/download/$tag/$name',
};
Map<String, dynamic> androidManifest({
  int code = 20,
  String version = '1.0.19',
}) => {
  'formatVersion': 1,
  'packageName': AndroidUpdateService.packageName,
  'versionName': version,
  'versionCode': code,
  'minSdk': 26,
  'apks': [
    for (final arch in ['arm64', 'x64'])
      {
        'name': 'Todorbit-$version-android-$arch.apk',
        'abis': [arch == 'arm64' ? 'arm64-v8a' : 'x86_64'],
        'size': 100,
        'sha256': 'a' * 64,
      },
  ],
};
Map<String, dynamic> androidRelease({
  String version = '1.0.19',
  bool pre = false,
}) => {
  'draft': false,
  'prerelease': pre,
  'tag_name': 'v$version',
  'published_at': '2026-10-29T09:00:00Z',
  'body': '# Changes\n- Android update',
  'assets': [
    for (final arch in ['arm64', 'x64'])
      apkAsset('Todorbit-$version-android-$arch.apk', tag: 'v$version'),
  ],
};

// Fake HTTPS responses exercise the production parser, checksum and cache logic
// without weakening the official-host allowlist or contacting GitHub.
class Reply {
  Reply(this.body, {this.status = 200, this.headers = const {}});
  final List<int> body;
  final int status;
  final Map<String, String> headers;
}

class FakeHeaders extends Fake implements HttpHeaders {
  FakeHeaders(this.values);
  final Map<String, String> values;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  String? value(String name) => values[name];
}

class FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeResponse(this.reply);
  final Reply reply;
  @override
  int get statusCode => reply.status;
  @override
  int get contentLength => -1;
  @override
  bool get isRedirect => [301, 302, 303, 307, 308].contains(statusCode);
  @override
  HttpHeaders get headers => FakeHeaders(reply.headers);
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(reply.body).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRequest extends Fake implements HttpClientRequest {
  FakeRequest(this.reply);
  final Reply reply;
  @override
  HttpHeaders get headers => FakeHeaders({});
  @override
  set followRedirects(bool _) {}
  @override
  Future<HttpClientResponse> close() async => FakeResponse(reply);
}

class FakeClient extends Fake implements HttpClient {
  FakeClient(this.handle);
  final Reply Function(Uri) handle;
  int requests = 0;
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requests++;
    return FakeRequest(handle(uri));
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  AndroidUpdateRelease? parse(
    Map<String, dynamic> m,
    Map<String, dynamic> r, [
    UpdateChannel channel = UpdateChannel.stable,
  ]) => AndroidUpdateService.parseManifest(m, r, device, channel);

  test('selects device ABI and newer Android version code', () {
    final result = parse(androidManifest(), androidRelease())!;
    expect(result.versionCode, 20);
    expect(result.uri.path, endsWith('-android-arm64.apk'));
    expect(result.notes, contains('# Changes'));
    expect(parse(androidManifest(code: 19), androidRelease()), isNull);
    expect(parse(androidManifest(code: 18), androidRelease()), isNull);
    expect(
      parse(
        androidManifest(code: 21, version: '1.0.17'),
        androidRelease(version: '1.0.17'),
      ),
      isNull,
    );
    expect(
      parse(
        androidManifest(code: 20, version: '1.0.18'),
        androidRelease(version: '1.0.18'),
      ),
      isNotNull,
    );
  });
  test(
    'prefers smaller compatible split even when universal appears first',
    () {
      final manifest = androidManifest();
      final release = androidRelease();
      final universal = {
        'name': 'Todorbit-1.0.19-android-universal.apk',
        'abis': ['arm64-v8a', 'x86_64'],
        'size': 200,
        'sha256': 'a' * 64,
      };
      (manifest['apks'] as List).insert(0, universal);
      (release['assets'] as List).insert(
        0,
        apkAsset(universal['name'] as String, size: 200),
      );
      expect(parse(manifest, release)!.uri.path, endsWith('-arm64.apk'));
      (manifest['apks'] as List).removeAt(1);
      expect(parse(manifest, release)!.uri.path, endsWith('-universal.apk'));
    },
  );
  test('stable excludes prereleases; pre-release includes them', () {
    final m = androidManifest(version: '1.0.19-rc.1');
    final r = androidRelease(version: '1.0.19-rc.1', pre: true);
    expect(parse(m, r), isNull);
    expect(parse(m, r, UpdateChannel.prerelease), isNotNull);
    expect(
      parse(androidManifest(), androidRelease(), UpdateChannel.prerelease),
      isNotNull,
    );
  });
  test(
    'rejects wrong package, unsupported SDK, malformed metadata and drafts',
    () {
      for (final change in [
        {'packageName': 'other.app'},
        {'formatVersion': 2},
        {'versionName': '9.0.0'},
        {'versionCode': '20'},
        {'versionCode': 2100000001},
        {'minSdk': 36},
        {'minSdk': null},
        {'apks': null},
      ]) {
        expect(
          parse({...androidManifest(), ...change}, androidRelease()),
          isNull,
          reason: '$change',
        );
      }
      expect(
        parse(androidManifest(), {...androidRelease(), 'draft': true}),
        isNull,
      );
      expect(
        parse(androidManifest(), {
          ...androidRelease(),
          'published_at': 'broken',
        }),
        isNull,
      );
    },
  );
  test(
    'rejects Windows-only, missing APK, incompatible ABI and altered digest',
    () {
      expect(
        parse(androidManifest(), {...androidRelease(), 'assets': []}),
        isNull,
      );
      final manifest = androidManifest();
      manifest['apks'] = [
        {
          'name': 'Todorbit-1.0.19-win-x64-setup.exe',
          'abis': ['arm64-v8a'],
        },
      ];
      expect(parse(manifest, androidRelease()), isNull);
      final unsupported = androidManifest();
      for (final entry in unsupported['apks']) {
        entry['abis'] = ['armeabi-v7a'];
      }
      expect(parse(unsupported, androidRelease()), isNull);
      final altered = androidRelease();
      for (final a in altered['assets']) {
        a['digest'] = 'sha256:${'b' * 64}';
      }
      expect(parse(androidManifest(), altered), isNull);
    },
  );
  test('official repository and exact APK path are mandatory', () {
    for (final url in [
      'https://github.com/evil/Todorbit/releases/download/v1.0.19/Todorbit-1.0.19-android-arm64.apk',
      'http://github.com/2HIK4/Todorbit/releases/download/v1.0.19/Todorbit-1.0.19-android-arm64.apk',
      'https://github.com:444/2HIK4/Todorbit/releases/download/v1.0.19/Todorbit-1.0.19-android-arm64.apk',
    ]) {
      final r = androidRelease();
      for (final a in r['assets']) {
        a['browser_download_url'] = url;
      }
      expect(parse(androidManifest(), r), isNull);
    }
  });
  test(
    'release discovery ignores Windows-only releases and caches checks',
    () async {
      final client = FakeClient(
        (_) => Reply(
          utf8.encode(
            jsonEncode([
              {
                ...androidRelease(),
                'assets': [apkAsset('Todorbit-1.0.19-win-x64-setup.exe')],
              },
            ]),
          ),
        ),
      );
      final service = AndroidUpdateService(client: client);
      expect(await service.check(device, UpdateChannel.stable), isNull);
      expect(await service.check(device, UpdateChannel.prerelease), isNull);
      expect(client.requests, 1);
      service.close();
    },
  );
  test('metadata digest is checked before parsing the APK selection', () async {
    final bytes = utf8.encode(jsonEncode(androidManifest()));
    final r = androidRelease();
    (r['assets'] as List).add(
      apkAsset(
        AndroidUpdateService.metadataName('v1.0.19'),
        size: bytes.length,
        digest: sha256.convert(bytes).toString(),
      ),
    );
    final client = FakeClient(
      (uri) => uri.host == 'api.github.com'
          ? Reply(utf8.encode(jsonEncode([r])))
          : Reply(bytes),
    );
    final service = AndroidUpdateService(client: client);
    expect(
      (await service.check(device, UpdateChannel.stable))?.versionCode,
      20,
    );
    service.close();
    final bad = androidRelease();
    (bad['assets'] as List).add(
      apkAsset(
        AndroidUpdateService.metadataName('v1.0.19'),
        size: bytes.length,
      ),
    );
    final tampered = AndroidUpdateService(
      client: FakeClient(
        (uri) => uri.host == 'api.github.com'
            ? Reply(utf8.encode(jsonEncode([bad])))
            : Reply(bytes),
      ),
    );
    await expectLater(
      tampered.check(device, UpdateChannel.stable),
      throwsStateError,
    );
    tampered.close();
  });
  test(
    'rate limits are useful and repeated checks do not repeat requests',
    () async {
      final client = FakeClient((_) => Reply([], status: 429));
      final service = AndroidUpdateService(client: client);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          service.check(device, UpdateChannel.stable),
          throwsStateError,
        );
      }
      expect(client.requests, 1);
      service.close();
    },
  );
  test('cleanup preserves saved updates until owner discards them', () async {
    final dir = await Directory.systemTemp.createTemp('android-update-clean-');
    try {
      final old = await File('${dir.path}/old.apk').writeAsString('old');
      await old.setLastModified(
        DateTime.now().subtract(const Duration(days: 8)),
      );
      await File('${dir.path}/interrupted.apk.part').writeAsString('partial');
      final kept = await File('${dir.path}/current.apk')
          .writeAsString('current');
      final service = AndroidUpdateService();
      await service.clean(dir);
      expect(await dir.list().length, 3);
      expect(await kept.exists(), isTrue);
      service.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
    'download verifies size/digest, reuses valid APK and cleans failures',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'android-update-download-',
      );
      final bytes = utf8.encode('verified APK test fixture');
      final client = FakeClient((_) => Reply(bytes));
      final service = AndroidUpdateService(downloadClient: () => client);
      final update = AndroidUpdateRelease(
        tag: 'v1.0.19',
        versionName: '1.0.19',
        versionCode: 20,
        publishedAt: DateTime.utc(2026),
        notes: '',
        uri: Uri.parse(
          'https://github.com/2HIK4/Todorbit/releases/download/v1.0.19/Todorbit-1.0.19-android-universal.apk',
        ),
        size: bytes.length,
        sha256Digest: sha256.convert(bytes).toString(),
      );
      final local = AndroidUpdateDevice(
        versionName: '1.0.18',
        versionCode: 19,
        sdk: 35,
        abis: ['arm64-v8a'],
        distribution: 'github',
        directory: dir.path,
        freeBytes: 1 << 30,
      );
      try {
        var received = 0;
        final file = await service.download(
          update,
          local,
          (done, _) => received = done,
        );
        expect(received, bytes.length);
        expect(await file.readAsBytes(), bytes);
        expect(
          (await service.download(update, local, (_, _) {})).path,
          file.path,
        );
        expect(client.requests, 1);
        await file.delete();
        final bad = AndroidUpdateService(
          downloadClient: () => FakeClient((_) => Reply([0])),
        );
        await expectLater(
          bad.download(update, local, (_, _) {}),
          throwsA(isA<HttpException>()),
        );
        expect(await bad.saved(update, local), 1);
        await bad.discard(update, local);
        bad.close();
        final failed = AndroidUpdateService(
          downloadClient: () => FakeClient((_) => Reply([], status: 503)),
        );
        await expectLater(
          failed.download(update, local, (_, _) {}),
          throwsA(isA<HttpException>()),
        );
        expect(await failed.saved(update, local), 0);
        failed.close();
        final canceled = AndroidUpdateService(
          downloadClient: () => FakeClient((_) => Reply(bytes)),
        );
        await expectLater(
          canceled.download(update, local, (_, _) => canceled.cancelDownload()),
          throwsA(isA<UpdateDownloadPaused>()),
        );
        await canceled.discard(update, local);
        canceled.close();
      } finally {
        service.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
