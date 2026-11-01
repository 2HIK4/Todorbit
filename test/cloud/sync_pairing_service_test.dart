import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';

import '../support/mock_sync_drive.dart';
import 'cloud_test_fakes.dart';

void main() {
  test(
    'second device must prove the original account-bound recovery key',
    () async {
      final drive = MockSyncDrive(),
          firstVault = MemoryTokenStore(),
          secondVault = MemoryTokenStore();
      final first = SyncPairingService(storage: drive, vault: firstVault);
      final second = SyncPairingService(storage: drive, vault: secondVault);
      final created = await first.prepare();
      expect(drive.objects, hasLength(1));
      expect(
        drive.payloads.values.single.toString(),
        isNot(contains(created.key.exportRecoveryCode())),
      );
      await expectLater(second.prepare(), throwsA(isA<CloudFailure>()));
      await expectLater(
        second.prepare(
          recoveryCode: SyncWorkspaceKey.generate().exportRecoveryCode(),
        ),
        throwsA(isA<CloudFailure>()),
      );
      expect(secondVault.value, isNull);
      final joined = await second.prepare(
        recoveryCode: created.key.exportRecoveryCode(),
      );
      expect(joined.binding.workspace, created.binding.workspace);
      expect(joined.binding.device, isNot(created.binding.device));
      expect(joined.key.exportRecoveryCode(), created.key.exportRecoveryCode());
      expect(drive.objects, hasLength(1));
    },
  );
  test(
    'an ambiguous workspace upload retains its only key before retry',
    () async {
      final drive = MockSyncDrive()..failAfterUpload = true;
      final vault = MemoryTokenStore();
      final pairing = SyncPairingService(storage: drive, vault: vault);
      await expectLater(pairing.prepare(), throwsA(isA<CloudFailure>()));
      final saved = (await pairing.saved())!;
      final retried = await pairing.prepare();
      expect(retried.key.exportRecoveryCode(), saved.key.exportRecoveryCode());
      expect(drive.objects, hasLength(1));
    },
  );
  test(
    'account switching preserves the paired key and refuses activation',
    () async {
      final drive = MockSyncDrive(), vault = MemoryTokenStore();
      final pairing = SyncPairingService(storage: drive, vault: vault);
      await pairing.prepare();
      final original = vault.value;
      drive.account = const CloudAccount(
        'other-mocked-account',
        'Synthetic other',
      );
      await expectLater(pairing.prepare(), throwsA(isA<CloudFailure>()));
      expect(vault.value, original);
      expect(drive.uploads, 1);
    },
  );
  test('competing first-device workspace keys stop verification without deleting either', () async {
    final leftDrive = MockSyncDrive(), rightDrive = MockSyncDrive();
    final leftVault = MemoryTokenStore(), rightVault = MemoryTokenStore();
    final left = SyncPairingService(storage: leftDrive, vault: leftVault);
    final right = SyncPairingService(storage: rightDrive, vault: rightVault);
    final first = await left.prepare(), second = await right.prepare();
    final proof = rightDrive.objects.single;
    leftDrive.objects.add(
      CloudObject(
        id: 'competing-proof',
        accountId: proof.accountId,
        name: proof.name,
        bytes: proof.bytes,
        createdAt: proof.createdAt,
        properties: proof.properties,
        md5: proof.md5,
      ),
    );
    leftDrive.payloads['competing-proof'] = rightDrive.payloads[proof.id]!;
    await expectLater(
      left.verifyWorkspace(first.binding, first.key),
      throwsA(isA<CloudFailure>()),
    );
    expect(
      (await left.saved())!.key.exportRecoveryCode(),
      first.key.exportRecoveryCode(),
    );
    expect(
      (await right.saved())!.key.exportRecoveryCode(),
      second.key.exportRecoveryCode(),
    );
    expect(leftDrive.objects, hasLength(2));
  });
}
