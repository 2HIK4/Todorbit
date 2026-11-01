import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/data/sync_exchange_schema.dart';
import 'package:life_manager/data/sync_schema.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'support/legacy_sync_fixture.dart';

class _Schema24Connection extends AppDatabase {
  _Schema24Connection(super.executor);
  @override
  int get schemaVersion => 24;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      throw StateError('Existing synthetic schema24 required');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );
}

void main() {
  test('schema24 retains original ciphertext and upgraded visibility while quarantining prototype exchange', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-sync-v24-upgrade-',
    );
    final file = File('${root.path}/synthetic.sqlite');
    const binding = SyncBinding(
      workspace: 'dd103cbe-f818-42e7-8182-82decc125643',
      account: 'mock-only',
      device: '37b9d9a3-0949-4ff3-bfcc-cb52932c62ac',
    );
    var db = AppDatabase(NativeDatabase(file));
    try {
      await db.customSelect('SELECT 1').get();
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        stripSyncSchemaForLegacyFixture(raw);
        raw.execute('PRAGMA user_version=24');
      } finally {
        raw.close();
      }
      db = _Schema24Connection(NativeDatabase(file));
      await createSyncSchema(db, installTriggers: false);
      await upgradeSyncExchangeSchema(db);
      await db.customStatement(
        'UPDATE sync_capture_context SET workspace_id=?,account_id=?,device_id=?,capture_enabled=1 WHERE id=1',
        [binding.workspace, binding.account, binding.device],
      );
      var repository = LifeRepository(db);
      await repository.addTask(
        const TaskDraft(title: 'First retained operation'),
      );
      await repository.addTask(
        const TaskDraft(title: 'Second retained operation'),
      );
      final before = await db.customSelect(
        '''SELECT j.*,g.first_sequence,g.last_sequence FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id ORDER BY j.sequence''',
      ).get();
      final legacy = SyncBatch(
        id: 'legacy-encrypted-batch',
        device: binding.device,
        schema: 24,
        operations: before.map(
          (row) => SyncRecordOperation(
            entity: row.read<String>('entity'),
            recordKey: row.read<String>('record_key'),
            group: SyncMutationGroup(
              id: row.read<String>('mutation_group_id'),
              first: row.read<int>('first_sequence'),
              last: row.read<int>('last_sequence'),
            ),
            revision: SyncRevision(
              id: row.read<String>('operation_id'),
              device: binding.device,
              sequence: row.read<int>('origin_sequence'),
              observed: (jsonDecode(row.read<String>('observed_json')) as Map)
                  .cast<String, int>(),
              parents: (jsonDecode(row.read<String>('parent_ids_json')) as List)
                  .cast<String>(),
              value: (jsonDecode(row.read<String>('after_json')) as Map)
                  .cast<String, Object?>(),
            ),
          ),
        ),
      );
      final key = SyncWorkspaceKey.generate();
      final codec = SyncBatchCodec();
      final ciphertext = await codec.encrypt(
        legacy,
        key,
        workspace: binding.workspace,
        account: binding.account,
      );
      await db.customStatement(
        '''INSERT INTO sync_batches(id,workspace_id,account_id,device_id,direction,payload,sha256,created_at)
        VALUES(?,?,?,?,'outgoing',?,?,?)''',
        [
          legacy.id,
          binding.workspace,
          binding.account,
          binding.device,
          ciphertext,
          crypto.sha256.convert(ciphertext).toString(),
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
      await db.customStatement('UPDATE sync_journal SET batch_id=?', [
        legacy.id,
      ]);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repository = LifeRepository(db);
      expect(await repository.tasks(), hasLength(2));
      final archived = await db
          .customSelect('SELECT * FROM sync_batches')
          .getSingle();
      expect(archived.read<int>('superseded'), 1);
      expect(archived.data['payload'], ciphertext);
      final ids = before
          .map((row) => row.read<String>('operation_id'))
          .toList();
      await expectLater(
        repository.prepareNextSyncBatch(binding, key),
        throwsStateError,
      );
      final retained = await db
          .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
          .get();
      expect(retained.map((r) => r.read<String>('operation_id')), ids);
      expect(jsonDecode(retained.first.read<String>('visible_json')), isEmpty);
      expect(jsonDecode(retained.last.read<String>('visible_json')), {
        binding.device: [
          [1, 1],
        ],
      });
      final context = await db
          .customSelect('SELECT * FROM sync_capture_context')
          .getSingle();
      expect(jsonDecode(context.read<String>('visible_json')), {
        binding.device: [
          [1, 2],
        ],
      });
      expect(context.read<int>('automatic_sync'), 0);
      expect(context.read<int>('capture_enabled'), 0);
      expect(context.read<int>('restore_quarantined'), 1);
      expect(
        await db.customSelect('SELECT * FROM sync_batches').get(),
        hasLength(1),
      );
      await repository.addTask(
        const TaskDraft(title: 'Retained local work during quarantine'),
      );
      expect(await repository.tasks(), hasLength(3));
      final afterEdit = await db
          .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
          .get();
      expect(afterEdit.map((r) => r.read<String>('operation_id')), ids);
      expect(
        (await db.customSelect('SELECT payload FROM sync_batches').getSingle())
            .data['payload'],
        ciphertext,
      );
      await expectLater(
        db.customStatement("UPDATE sync_journal SET visible_json='{}'"),
        throwsA(isA<sqlite.SqliteException>()),
      );
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });
}
