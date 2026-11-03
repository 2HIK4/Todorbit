import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/cloud/sync_workspace_format.dart';

import '../support/mock_sync_drive.dart';
import 'cloud_test_fakes.dart';

void main() {
  test(
    'Standard workspace joins without a secret and remembers its introduction',
    () async {
      final drive = MockSyncDrive(), vault = MemoryTokenStore();
      final first = SyncPairingService(storage: drive, vault: vault);
      final created = await first.prepare();
      expect(created.key.isStandard, isTrue);
      expect(created.introSeen, isFalse);
      expect(jsonDecode(vault.value!).containsKey('recovery'), isFalse);
      final second = await SyncPairingService(
        storage: drive,
        vault: MemoryTokenStore(),
      ).prepare();
      expect(second.key.isStandard, isTrue);
      expect(second.binding.device, isNot(created.binding.device));
      expect(second.introSeen, isTrue);
      await first.dismissIntroduction();
      expect((await first.prepare()).introSeen, isTrue);
      expect(drive.uploads, 1);
      await expectLater(
        first.prepare(privateKey: SyncWorkspaceKey.generate()),
        throwsA(isA<CloudFailure>()),
      );
      expect(drive.uploads, 1);
    },
  );

  test('API failure, future format, corruption and migration never become empty cloud', () async {
    final drive = MockSyncDrive(), vault = MemoryTokenStore();
    final pairing = SyncPairingService(storage: drive, vault: vault);
    drive.beforeList = () async =>
        throw const CloudFailure('Synthetic API failure');
    await expectLater(pairing.prepare(), throwsA(isA<CloudFailure>()));
    expect(drive.uploads, 0);
    expect(vault.value, isNull);
    drive.beforeList = null;
    await pairing.prepare();
    final object = drive.objects.single;
    final original = drive.payloads[object.id]!;
    final data = jsonDecode(utf8.decode(original)) as Map;
    data['schema'] = 999;
    drive.payloads[object.id] = Uint8List.fromList(
      utf8.encode(jsonEncode(data)),
    );
    final fresh = SyncPairingService(storage: drive, vault: MemoryTokenStore());
    await expectLater(
      fresh.prepare(),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.incompatible,
        ),
      ),
    );
    drive.payloads[object.id] = Uint8List.fromList([123]);
    await expectLater(fresh.prepare(), throwsA(isA<FormatException>()));
    drive.payloads[object.id] = original;
    drive.failDownload = true;
    await expectLater(fresh.prepare(), throwsA(isA<CloudFailure>()));
    expect(drive.uploads, 1);
    expect(await fresh.saved(), isNull);
    drive.failDownload = false;
    drive.objects[0] = CloudObject(
      id: object.id,
      accountId: object.accountId,
      name: object.name,
      bytes: object.bytes,
      createdAt: object.createdAt,
      properties: {...object.properties, 'state': 'migrating'},
      md5: object.md5,
    );
    await expectLater(
      fresh.prepare(),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.migrating,
        ),
      ),
    );
    expect(drive.uploads, 1);
  });

  test('private passphrase and recovery both unlock the same key; failed attempts do not persist', () async {
    final drive = MockSyncDrive(),
        firstVault = MemoryTokenStore(),
        secondVault = MemoryTokenStore();
    final first = SyncPairingService(storage: drive, vault: firstVault);
    final key = SyncWorkspaceKey.generate();
    const password = 'quiet orchard violet bicycle';
    drive.failAfterUpload = true;
    await expectLater(
      first.prepare(privateKey: key, password: password),
      throwsA(isA<CloudFailure>()),
    );
    expect(
      (await first.saved())!.key.exportRecoveryCode(),
      key.exportRecoveryCode(),
    );
    // Process-loss retry needs the stored wrapped proof, never the passphrase.
    final resumed = await SyncPairingService(
      storage: drive,
      vault: firstVault,
    ).prepare();
    expect(resumed.key.exportRecoveryCode(), key.exportRecoveryCode());
    final second = SyncPairingService(storage: drive, vault: secondVault);
    await expectLater(second.prepare(), throwsA(isA<SyncRecoveryRequired>()));
    await expectLater(
      second.prepare(password: 'wrong passphrase'),
      throwsA(isA<CloudFailure>()),
    );
    expect(secondVault.value, isNull);
    final unlocked = await second.prepare(password: password);
    expect(unlocked.key.exportRecoveryCode(), key.exportRecoveryCode());
    expect(firstVault.value, isNot(contains(password)));
    final recovered = await SyncPairingService(
      storage: drive,
      vault: MemoryTokenStore(),
    ).prepare(recoveryCode: key.exportRecoveryCode());
    expect(recovered.key.exportRecoveryCode(), key.exportRecoveryCode());
    expect(drive.uploads, 1);
  });

  test('legacy encrypted proof requires its original recovery key, never Standard initialization', () async {
    final drive = MockSyncDrive();
    final first = await SyncPairingService(
      storage: drive,
      vault: MemoryTokenStore(),
    ).prepare(privateKey: SyncWorkspaceKey.generate());
    final fresh = SyncPairingService(storage: drive, vault: MemoryTokenStore());
    await expectLater(fresh.prepare(), throwsA(isA<SyncRecoveryRequired>()));
    expect(drive.uploads, 1);
    final joined = await fresh.prepare(
      recoveryCode: first.key.exportRecoveryCode(),
    );
    expect(joined.key.isStandard, isFalse);
    expect(joined.binding.workspace, first.binding.workspace);
  });

  test('passphrases allow words and long text, reject predictable PINs', () {
    expect(
      SyncWorkspaceFormat.passwordError('quiet orchard violet bicycle'),
      isNull,
    );
    expect(SyncWorkspaceFormat.passwordError('words ' * 100), isNull);
    for (final weak in [
      '1234567890123456',
      'aaaaaaaaaaaaaaaa',
      'passwordpassword',
      'short',
    ]) {
      expect(SyncWorkspaceFormat.passwordError(weak), isNotNull);
    }
  });
}
