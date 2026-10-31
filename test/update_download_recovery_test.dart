import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/resumable_update_download.dart';
import 'package:life_manager/data/software_update_service.dart';
import 'package:life_manager/platform/android/android_update_service.dart';

void main() {
  test('Android restores release and exact partial bytes with a new service, offline', () async {
    final folder = await Directory.systemTemp.createTemp(
      'android-update-recovery-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final device = AndroidUpdateDevice(
      versionName: '1.0.19-beta.1',
      versionCode: 23,
      sdk: 35,
      abis: ['arm64-v8a'],
      distribution: 'github',
      directory: folder.path,
    );
    final release = AndroidUpdateRelease(
      tag: 'v1.0.20-beta.1',
      versionName: '1.0.20-beta.1',
      versionCode: 24,
      publishedAt: DateTime.utc(2026, 10, 31),
      notes: 'Retained notes',
      uri: Uri.parse(
        'https://github.com/2HIK4/Todorbit/releases/download/v1.0.20-beta.1/Todorbit-1.0.20-beta.1-android-arm64.apk',
      ),
      size: 50000000,
      sha256Digest: 'a' * 64,
    );
    final first = AndroidUpdateService();
    await first.remember(release, device);
    final target = first.target(release, device);
    await File('${target.path}.part').writeAsBytes(List.filled(3000, 5));
    await File('${target.path}.part.json')
        .writeAsString(jsonEncode(first.identity(release)));
    first.close();
    final second = AndroidUpdateService();
    addTearDown(second.close);
    final restored = (await second.remembered(device))!;
    expect(restored.uri, release.uri);
    expect(restored.notes, 'Retained notes');
    expect(await second.saved(restored, device), 3000);
    await second.discard(restored, device);
    expect(await second.saved(restored, device), 0);
  });

  test('Windows restores selection and verified complete package offline; rejects downgrade', () async {
    final folder = await Directory.systemTemp.createTemp(
      'windows-update-recovery-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final bytes = [1, 2, 3, 4];
    final release = UpdateRelease(
      version: UpdateVersion.parse('1.0.20')!,
      tag: 'v1.0.20',
      notes: '',
      assetUri: Uri.parse(
        'https://github.com/2HIK4/Todorbit/releases/download/v1.0.20/Todorbit-1.0.20-win-x64-setup.exe',
      ),
      sha256Digest: sha256.convert(bytes).toString(),
      size: bytes.length,
    );
    final first = SoftwareUpdateService();
    await first.remember(release, folder);
    await first.target(release, folder).writeAsBytes(bytes);
    first.close();
    final second = SoftwareUpdateService();
    addTearDown(second.close);
    final restored = (await second.remembered(folder, '1.0.19', false))!;
    expect(await second.saved(restored, folder), bytes.length);
    expect(
      await (await second.download(restored, folder)).readAsBytes(),
      bytes,
    );
    expect(await second.remembered(folder, '1.0.20', false), isNull);
    expect(await second.remembered(folder, '1.0.19', true), isNull);
    expect(
      await second.transfer.saved(
        second.target(restored, folder),
        ResumableUpdateDownload.identity(
          restored.assetUri,
          restored.size,
          '0' * 64,
          restored.tag,
        ),
      ),
      0,
    );
  });
}
