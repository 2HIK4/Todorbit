import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/sync_visibility.dart';
import 'package:life_manager/domain/alarms.dart';

void main() {
  for (final private in [false, true]) {
    test(
      'alarm rule schema/round trip ${private ? 'Private' : 'Standard'}',
      () async {
        final key = private
            ? SyncWorkspaceKey.generate()
            : SyncWorkspaceKey.standard();
        final codec = SyncBatchCodec();
        final config = AlarmConfig(
          mode: 'custom',
          at: DateTime.utc(2027, 1, 1),
        );
        final batch = SyncBatch(
          id: 'alarm-batch',
          device: 'windows',
          schema: 28,
          operations: [
            SyncRecordOperation(
              entity: 'alarm_rules',
              recordKey: '{"id":"alarm-rule"}',
              group: SyncMutationGroup(id: 'alarm-group', first: 1, last: 1),
              revision: SyncRevision(
                id: 'alarm-op',
                device: 'windows',
                sequence: 1,
                parents: [],
                visible: SyncVisibility(const {}),
                value: {
                  'id': 'alarm-rule',
                  'task_id': 'synthetic-task',
                  'config_json': jsonEncode(config.toJson()),
                },
              ),
            ),
          ],
        );
        final bytes = await codec.encrypt(
          batch,
          key,
          workspace: 'synthetic-workspace',
          account: 'synthetic-account',
        );
        final result = await codec.decrypt(
          bytes,
          key,
          workspace: 'synthetic-workspace',
          account: 'synthetic-account',
          expectedSchema: 28,
        );
        expect(result.toJson(), batch.toJson());
        if (private) {
          expect(utf8.decode(bytes), isNot(contains('synthetic-task')));
        }
        await expectLater(
          codec.decrypt(
            bytes,
            key,
            workspace: 'synthetic-workspace',
            account: 'synthetic-account',
            expectedSchema: 27,
          ),
          throwsA(isA<SyncSchemaMismatch>()),
        );
      },
    );
  }
}
