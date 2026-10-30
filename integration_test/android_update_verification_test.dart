import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_manager/platform/android/android_platform.dart';
import 'package:life_manager/platform/android/android_update_service.dart';
import 'package:path/path.dart' as path;

/// Prepare same-key candidate.apk (code > 19) and negative signed fixtures under
/// app-private files/update-fixtures on a disposable emulator before running.
/// Flutter test and default Drive teardown uninstall; use --keep-app-running.
/// Never use a phone.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Android APK publisher, package and integrity gates', (
    tester,
  ) async {
    final device = await AndroidUpdateDevice.load();
    expect(device.distribution, 'github');
    final files = (await AndroidPlatform.channel.invokeMethod<String>(
      'dataRoot',
    ))!;
    final fixtures = Directory(path.join(files, 'update-fixtures'));
    final service = AndroidUpdateService();
    try {
      final source = File(path.join(fixtures.path, 'candidate.apk'));
      expect(
        await source.exists(),
        isTrue,
        reason: 'Prepare disposable APK fixtures first; see tools/test-android-update.ps1.',
      );
      final apk = await source.copy(
        path.join(device.directory!, 'acceptance.apk'),
      );
      final metadata = jsonDecode(
        await File(path.join(fixtures.path, 'candidate.json')).readAsString(),
      ) as Map<String, dynamic>;
      AndroidUpdateRelease release(
        File file, {
        int code = 20,
        String version = '1.0.18',
        String? digest,
      }) => AndroidUpdateRelease(
        tag: 'v$version',
        versionName: version,
        versionCode: code,
        publishedAt: DateTime.utc(2026),
        notes: '',
        uri: Uri.parse('https://github.com'),
        size: file.path == source.path || file.path == apk.path
            ? metadata['size'] as int
            : file.lengthSync(),
        sha256Digest:
            digest ??
            (file.path == source.path || file.path == apk.path
                ? metadata['sha256'] as String
                : sha256.convert(file.readAsBytesSync()).toString()),
      );
      await service.verify(release(apk), apk);
      await expectLater(
        service.verify(release(apk, digest: '0' * 64), apk),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        service.verify(release(apk, code: 21), apk),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        service.verify(release(apk, version: '9.9.9'), apk),
        throwsA(isA<PlatformException>()),
      );
      for (final name in [
        'wrong-package',
        'wrong-signer',
        'wrong-abi',
        'newer-sdk',
        'older',
        'tampered',
      ]) {
        final file = await File(path.join(fixtures.path, '$name.apk'))
            .copy(path.join(device.directory!, '$name.apk'));
        await expectLater(
          service.verify(release(file), file),
          throwsA(isA<PlatformException>()),
          reason: name,
        );
      }
      // Outside the narrow private update cache is never accepted.
      await expectLater(
        service.verify(release(source), source),
        throwsA(isA<PlatformException>()),
      );
    } finally {
      service.close();
    }
  });
}
