import 'dart:convert';
import 'dart:typed_data';

import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/sync_visibility.dart';
import 'package:test/test.dart';

void main() {
  final codec = SyncBatchCodec();
  final key = SyncWorkspaceKey.generate();
  final batch = SyncBatch(
    id: 'batch-id',
    device: 'windows',
    schema: 22,
    operations: [
      SyncRecordOperation(
        entity: 'tasks',
        recordKey: 'task-id',
        revision: SyncRevision(
          id: 'operation-id',
          device: 'windows',
          sequence: 1,
          parents: [],
          value: {
            'title': 'Private task text',
            'attachment': base64Encode([0, 255, 4]),
          },
        ),
      ),
    ],
  );
  Future<Uint8List> encrypt() =>
      codec.encrypt(batch, key, workspace: 'workspace', account: 'account');
  Future<SyncBatch> decrypt(
    Uint8List bytes, {
    SyncWorkspaceKey? usingKey,
    String workspace = 'workspace',
    String account = 'account',
    int schema = 22,
  }) => codec.decrypt(
    bytes,
    usingKey ?? key,
    workspace: workspace,
    account: account,
    expectedSchema: schema,
  );

  for (final mode in [
    SyncWorkspaceKey.standard(),
    SyncWorkspaceKey.generate(),
  ]) {
    test(
      'schema 27 accepts unchanged schema 26 envelopes (${mode.isStandard})',
      () async {
        final legacy = SyncBatch(
          id: 'legacy',
          device: 'windows',
          schema: 26,
          operations: [
            SyncRecordOperation(
              entity: 'fixed_events',
              recordKey: '{"id":"event"}',
              group: SyncMutationGroup(id: 'legacy-group', first: 1, last: 1),
              revision: SyncRevision(
                id: 'op',
                device: 'windows',
                sequence: 1,
                parents: [],
                visible: SyncVisibility(const {}),
                value: {'id': 'event', 'title': 'Legacy'},
              ),
            ),
          ],
        );
        final bytes = await codec.encrypt(
          legacy,
          mode,
          workspace: 'workspace',
          account: 'account',
        );
        expect(
          (await codec.decrypt(
            bytes,
            mode,
            workspace: 'workspace',
            account: 'account',
            expectedSchema: 27,
          )).toJson(),
          legacy.toJson(),
        );
        await expectLater(
          codec.decrypt(
            bytes,
            mode,
            workspace: 'workspace',
            account: 'account',
            expectedSchema: 25,
          ),
          throwsA(isA<SyncSchemaMismatch>()),
        );
      },
    );
  }

  test(
    'pairing recovery code round-trips encrypted per-device operations',
    () async {
      final encrypted = await encrypt();
      expect(utf8.decode(encrypted), isNot(contains('Private task text')));
      expect(utf8.decode(encrypted), isNot(contains(key.exportRecoveryCode())));
      final paired = SyncWorkspaceKey.fromRecoveryCode(
        key.exportRecoveryCode(),
      );
      expect(
        (await decrypt(encrypted, usingKey: paired)).toJson(),
        batch.toJson(),
      );
      expect(await encrypt(), isNot(orderedEquals(encrypted)));
    },
  );

  test(
    'workspace, account, key, schema and authenticated bytes cannot mix',
    () async {
      final encrypted = await encrypt();
      for (final attempt in [
        () => decrypt(encrypted, usingKey: SyncWorkspaceKey.generate()),
        () => decrypt(encrypted, workspace: 'another-workspace'),
        () => decrypt(encrypted, account: 'another-account'),
      ]) {
        await expectLater(attempt(), throwsFormatException);
      }
      await expectLater(
        decrypt(encrypted, schema: 23),
        throwsA(isA<SyncSchemaMismatch>()),
      );
      final envelope =
          jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
      final cipher = base64Decode(envelope['ciphertext'] as String);
      cipher[0] ^= 1;
      envelope['ciphertext'] = base64Encode(cipher);
      await expectLater(
        decrypt(Uint8List.fromList(utf8.encode(jsonEncode(envelope)))),
        throwsFormatException,
      );
      envelope['format'] = 'todorbit-sync:2:aes256gcm';
      await expectLater(
        decrypt(Uint8List.fromList(utf8.encode(jsonEncode(envelope)))),
        throwsFormatException,
      );
    },
  );

  test('Standard payload is plaintext, account bound and never accepted as private', () async {
    final standard = SyncWorkspaceKey.standard();
    final bytes = await codec.encrypt(
      batch,
      standard,
      workspace: 'workspace',
      account: 'account',
    );
    expect(utf8.decode(bytes), contains('Private task text'));
    expect((await decrypt(bytes, usingKey: standard)).toJson(), batch.toJson());
    await expectLater(decrypt(bytes), throwsFormatException);
    await expectLater(
      decrypt(bytes, usingKey: standard, account: 'other'),
      throwsFormatException,
    );
    await expectLater(
      decrypt(await encrypt(), usingKey: standard),
      throwsFormatException,
    );
    expect(() => standard.exportRecoveryCode(), throwsStateError);
  });

  test('recovery codes reject short, malformed and noncanonical encodings', () {
    for (final code in [
      '',
      'backup password',
      'AA',
      '${key.exportRecoveryCode()}=',
      '!' * 43,
    ]) {
      expect(
        () => SyncWorkspaceKey.fromRecoveryCode(code),
        throwsFormatException,
      );
    }
  });

  test(
    'mixed device identities and reused operation sequences are rejected',
    () {
      final op = batch.operations.single;
      expect(
        () =>
            SyncBatch(id: 'b', device: 'android', schema: 22, operations: [op]),
        throwsFormatException,
      );
      expect(
        () => SyncBatch(
          id: 'b',
          device: 'windows',
          schema: 22,
          operations: [op, op],
        ),
        throwsFormatException,
      );
      expect(
        () => SyncBatch.fromJson({...batch.toJson(), 'unknown': true}),
        throwsFormatException,
      );
    },
  );
}
