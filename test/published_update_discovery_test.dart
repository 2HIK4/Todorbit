import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/software_update_service.dart';
import 'package:life_manager/platform/android/android_update_service.dart';

// Bypass flutter_test's fake HTTP client for this opt-in public release check.
class _PublicHttp extends HttpOverrides {}

void main() {
  const tag = String.fromEnvironment('TODORBIT_RELEASE_TAG');
  const buildCode = int.fromEnvironment('TODORBIT_RELEASE_CODE');
  const previousVersion = String.fromEnvironment('TODORBIT_PREVIOUS_VERSION');
  const previousCode = int.fromEnvironment('TODORBIT_PREVIOUS_CODE');

  test(
    'published release is discoverable on Experimental only',
    () async {
      expect(tag, startsWith('v'));
      expect(previousVersion, isNotEmpty);
      expect(previousCode, greaterThan(0));
      expect(buildCode, greaterThan(previousCode));

      final client = _PublicHttp().createHttpClient(null);
      addTearDown(() => client.close(force: true));
      final windows = SoftwareUpdateService(client: client);
      final android = AndroidUpdateService(client: client);

      for (final portable in [false, true]) {
        final experimental = await windows.check(
          currentVersion: previousVersion,
          channel: UpdateChannel.prerelease,
          portable: portable,
        );
        expect(experimental?.tag, tag);
        expect(
          experimental?.assetUri.pathSegments.last,
          SoftwareUpdateService.assetName(tag, portable: portable),
        );
        final stable = await windows.check(
          currentVersion: previousVersion,
          channel: UpdateChannel.stable,
          portable: portable,
        );
        expect(stable?.tag, isNot(tag));
      }

      for (final (abi, assetSuffix) in [
        ('arm64-v8a', 'arm64'),
        ('x86_64', 'x64'),
      ]) {
        final device = AndroidUpdateDevice(
          versionName: previousVersion,
          versionCode: previousCode,
          sdk: 36,
          abis: [abi],
          distribution: 'github',
        );
        final experimental = await android.check(
          device,
          UpdateChannel.prerelease,
        );
        expect(experimental?.tag, tag);
        expect(experimental?.versionCode, buildCode);
        expect(
          experimental?.uri.pathSegments.last,
          'Todorbit-${tag.substring(1)}-android-$assetSuffix.apk',
        );
        final stable = await android.check(device, UpdateChannel.stable);
        expect(stable?.tag, isNot(tag));
      }
    },
    skip: tag.isEmpty
        ? 'Supply the public release and previous build defines'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
