import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/software_update_service.dart';

Map<String, Object?> release(
  String tag, {
  bool prerelease = false,
  bool draft = false,
  String? digest,
  String? asset,
}) => {
  'tag_name': tag,
  'published_at': '2026-10-23T00:00:00Z',
  'draft': draft,
  'prerelease': prerelease,
  'body': 'Changes in $tag',
  'assets': [
    {
      'name': asset ?? SoftwareUpdateService.assetName(tag, portable: false),
      'state': 'uploaded',
      'browser_download_url':
          'https://github.com/2HIK4/Todorbit/releases/download/$tag/${asset ?? SoftwareUpdateService.assetName(tag, portable: false)}',
      'size': 123,
      'digest': digest ?? 'sha256:${'a' * 64}',
    },
  ],
};

void main() {
  test('semantic versions compare pre-releases and numeric identifiers', () {
    final versions = [
      '1.0.5-alpha.2',
      '1.0.5-alpha.10',
      '1.0.5-beta',
      '1.0.5',
      '1.0.6',
    ].map((value) => UpdateVersion.parse(value)!).toList();
    for (var i = 1; i < versions.length; i++) {
      expect(versions[i].compareTo(versions[i - 1]), greaterThan(0));
    }
    expect(UpdateVersion.parse('v1.0.5+6'), isNotNull);
    expect(UpdateVersion.parse('1.0.5-alpha.01'), isNull);
    expect(UpdateVersion.parse('1.0.5+broken..metadata'), isNull);
    expect(UpdateVersion.parse('1.0.5-99999999999999999999')!
        .compareTo(UpdateVersion.parse('1.0.5-2')!), greaterThan(0));
    expect(UpdateVersion.parse('unpublished'), isNull);
  });

  test('stable channel selects stable release, never draft or downgrade', () {
    final selected = SoftwareUpdateService.selectRelease(
      [
        release('v1.0.4'),
        release('v1.0.9', draft: true),
        release('v1.0.8-rc.1', prerelease: true),
        release('v1.0.7'),
      ],
      currentVersion: '1.0.5',
      channel: UpdateChannel.stable,
      portable: false,
    );
    expect(selected?.tag, 'v1.0.7');
  });

  test('pre-release channel selects highest compatible published version', () {
    final selected = SoftwareUpdateService.selectRelease(
      [release('v1.0.6'), release('v1.0.7-rc.2', prerelease: true)],
      currentVersion: '1.0.5',
      channel: UpdateChannel.prerelease,
      portable: false,
    );
    expect(selected?.tag, 'v1.0.7-rc.2');
  });

  test(
    'release requires exact Windows x64 asset and GitHub SHA-256 digest',
    () {
      final selected = SoftwareUpdateService.selectRelease(
        [
          release('v1.0.9', digest: ''),
          release('v1.0.8', asset: 'Todorbit-1.0.8-linux.zip'),
          release('v1.0.7'),
        ],
        currentVersion: '1.0.5',
        channel: UpdateChannel.stable,
        portable: false,
      );
      expect(selected?.tag, 'v1.0.7');
      expect(
        SoftwareUpdateService.approvedDownload(
          Uri.parse('http://github.com/a'),
        ),
        isFalse,
      );
      expect(
        SoftwareUpdateService.approvedDownload(
          Uri.parse('https://evil.example/a'),
        ),
        isFalse,
      );
    },
  );

  test(
    'update preferences persist per profile and reject unknown format',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'todorbit-update-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = UpdatePreferenceStore(
        File('${directory.path}/updates.json'),
      );
      expect((await store.load()).channel, UpdateChannel.stable);
      final checked = DateTime.utc(2026, 10, 23);
      await store.save(
        UpdatePreferences(
          automaticChecks: false,
          channel: UpdateChannel.prerelease,
          lastChecked: checked,
        ),
      );
      final saved = await store.load();
      expect(saved.automaticChecks, isFalse);
      expect(saved.channel, UpdateChannel.prerelease);
      expect(saved.lastChecked, checked);
      await store.save(saved.copyWith(automaticChecks: true));
      expect((await store.load()).automaticChecks, isTrue);
      await store.file.writeAsString('{"version":2}');
      expect(store.load(), throwsFormatException);
    },
  );

  test('download verifies bytes, size, and redirect source', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'todorbit-download-',
    );
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final bytes = [1, 2, 3, 4, 5];
    server.listen((request) async {
      if (request.uri.path == '/redirect') {
        request.response.statusCode = 302;
        request.response.headers.set('location', 'https://evil.example/file');
      } else {
        request.response.add(
          request.uri.path == '/corrupt' ? [9, 9, 9, 9, 9] : bytes,
        );
      }
      await request.response.close();
    });
    final service = SoftwareUpdateService(allowedDownloadHosts: {'127.0.0.1'});
    addTearDown(service.close);
    UpdateRelease item(String route, {int? size}) => UpdateRelease(
      version: UpdateVersion.parse('1.0.6')!,
      tag: 'v1.0.6',
      notes: '',
      assetUri: Uri.parse('http://127.0.0.1:${server.port}/$route'),
      sha256Digest: sha256.convert(bytes).toString(),
      size: size ?? bytes.length,
    );

    final valid = await service.download(item('valid'), directory);
    expect(await valid.readAsBytes(), bytes);
    expect(service.download(item('corrupt'), directory), throwsStateError);
    expect(
      service.download(item('short', size: bytes.length + 1), directory),
      throwsStateError,
    );
    expect(service.download(item('redirect'), directory), throwsStateError);
  });
}
