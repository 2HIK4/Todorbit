import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory root;
  late File file;
  late AppDatabase db;
  late LifeRepository repository;
  late SyncWorkspaceKey key;
  const binding = SyncBinding(
    workspace: 'ba738dd5-6c52-497e-a6e3-04ab1888cd82',
    account: 'disposable-account',
    device: 'a255ba17-481a-4b50-8807-23e91ecc3762',
  );
  final codec = SyncBatchCodec();
  CloudObject remote(
    PendingSyncBatch batch, {
    String? account,
    String id = 'drive-object',
  }) => CloudObject(
    id: id,
    accountId: account ?? binding.account,
    name: 'opaque.tdsync',
    bytes: batch.bytes.length,
    createdAt: DateTime.now().toUtc(),
    properties: {
      ...batch.properties,
      'application': 'todorbit-sync',
      'verified': 'true',
    },
    md5: crypto.md5.convert(batch.bytes).toString(),
  );
  Future<SyncBatch> decrypt(PendingSyncBatch batch) => codec.decrypt(
    batch.bytes,
    key,
    workspace: binding.workspace,
    account: binding.account,
    expectedSchema: AppDatabase.currentSchemaVersion,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-staged-batch-');
    file = File('${root.path}/life.sqlite');
    db = AppDatabase(NativeDatabase(file));
    repository = LifeRepository(db);
    key = SyncWorkspaceKey.generate();
    await repository.addTask(
      const TaskDraft(title: 'Synthetic private offline work'),
    );
    await repository.activateSyncCapture(
      workspaceId: binding.workspace,
      accountId: binding.account,
      deviceId: binding.device,
      recovery: BackupService(file),
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'encrypted staging survives restart and preserves exact retry bytes',
    () async {
      final first = (await repository.prepareNextSyncBatch(binding, key))!;
      expect(utf8.decode(first.bytes), isNot(contains('Synthetic private')));
      final clear = await decrypt(first);
      expect(clear.operations.single.entity, 'tasks');
      expect(clear.operations.single.revision.observed[binding.device], 0);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repository = LifeRepository(db);
      final resumed = (await repository.prepareNextSyncBatch(binding, key))!;
      expect(resumed.id, first.id);
      expect(resumed.bytes, first.bytes);
      expect(resumed.sha256, first.sha256);
      expect(() => resumed.bytes[0] ^= 1, throwsUnsupportedError);
      expect(
        await db.customSelect('SELECT * FROM sync_batches').get(),
        hasLength(1),
      );
    },
  );

  test('acknowledgement never drops edits made during upload', () async {
    final first = (await repository.prepareNextSyncBatch(binding, key))!;
    await repository.addTask(
      const TaskDraft(title: 'Edit while upload is pending'),
    );
    await repository.acknowledgeSyncBatch(first, remote(first));
    await repository.acknowledgeSyncBatch(first, remote(first));
    final next = (await repository.prepareNextSyncBatch(binding, key))!;
    expect(next.id, isNot(first.id));
    expect(
      (await decrypt(next)).operations.single.revision.value!['title'],
      'Edit while upload is pending',
    );
    final pending = await repository.pendingSyncChanges(
      workspaceId: binding.workspace,
      accountId: binding.account,
    );
    expect(pending, hasLength(1));
    expect(
      await db.customSelect('SELECT * FROM sync_journal').get(),
      hasLength(2),
    );
    expect(
      await db.customSelect('SELECT * FROM sync_remote_objects').get(),
      hasLength(1),
    );
    final context = await db
        .customSelect('SELECT * FROM sync_capture_context')
        .getSingle();
    expect(context.readNullable<String>('last_success_utc'), isNull);
  });

  test(
    'wrong account acknowledgement and restored binding leave work pending',
    () async {
      final first = (await repository.prepareNextSyncBatch(binding, key))!;
      await expectLater(
        repository.acknowledgeSyncBatch(
          first,
          remote(first, account: 'another-account'),
        ),
        throwsStateError,
      );
      expect(
        (await repository.pendingSyncChanges(
          workspaceId: binding.workspace,
          accountId: binding.account,
        )),
        hasLength(1),
      );
      await repository.quarantineRestoredSync();
      await expectLater(
        repository.prepareNextSyncBatch(binding, key),
        throwsStateError,
      );
      await expectLater(
        repository.acknowledgeSyncBatch(first, remote(first)),
        throwsStateError,
      );
      expect(
        (await db.customSelect('SELECT uploaded FROM sync_batches').getSingle())
            .read<int>('uploaded'),
        0,
      );
    },
  );

  test(
    'managed byte encoding round trips and durable operations are immutable',
    () async {
      final task = (await repository.tasks()).single;
      final attachment = File('${root.path}/bytes.bin')
        ..writeAsBytesSync([0, 255, 4]);
      await repository.attachManagedFile(task.id, attachment);
      final first = (await repository.prepareNextSyncBatch(binding, key))!;
      final clear = await decrypt(first);
      final resource = clear.operations.singleWhere(
        (op) => op.entity == 'task_resources',
      );
      final binary = resource.revision.value!['content'] as Map;
      expect(base64Decode(binary[r'$bytes'] as String), [0, 255, 4]);
      expect(
        resource.revision.value!['sha256'],
        crypto.sha256.convert([0, 255, 4]).toString(),
      );
      await expectLater(
        db.customStatement("UPDATE sync_journal SET after_json='{}'"),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        db.customStatement("UPDATE sync_batches SET sha256='changed'"),
        throwsA(isA<sqlite.SqliteException>()),
      );
      final retained = (await repository.prepareNextSyncBatch(binding, key))!;
      expect(retained.bytes, first.bytes);
    },
  );

  test(
    'a reused Drive object cannot acknowledge a different immutable batch',
    () async {
      final first = (await repository.prepareNextSyncBatch(binding, key))!;
      await repository.acknowledgeSyncBatch(first, remote(first));
      await repository.addTask(const TaskDraft(title: 'Another operation'));
      final second = (await repository.prepareNextSyncBatch(binding, key))!;
      await expectLater(
        repository.acknowledgeSyncBatch(second, remote(second)),
        throwsStateError,
      );
      expect(
        await repository.pendingSyncChanges(
          workspaceId: binding.workspace,
          accountId: binding.account,
        ),
        hasLength(1),
      );
      expect(
        (await db
                .customSelect('SELECT batch_id FROM sync_remote_objects')
                .getSingle())
            .read<String>('batch_id'),
        first.id,
      );
    },
  );

  test('nested rollback preserves one contiguous committed action', () async {
    await db.transaction(() async {
      await repository.addTask(const TaskDraft(title: 'Committed A'));
      try {
        await db.transaction(() async {
          await repository.addTask(const TaskDraft(title: 'Rolled back'));
          throw StateError('Synthetic savepoint rollback');
        }, requireNew: true);
      } on StateError {
        // The outer user action deliberately continues after its savepoint.
      }
      await repository.addTask(const TaskDraft(title: 'Committed C'));
    });
    final batch = await decrypt(
      (await repository.prepareNextSyncBatch(binding, key))!,
    );
    expect(batch.operations.map((op) => op.revision.sequence), [1, 2, 3]);
    expect(
      batch.operations.map((op) => op.revision.value!['title']),
      isNot(contains('Rolled back')),
    );
    final group = batch.operations[1].group!;
    expect(group.first, 2);
    expect(group.last, 3);
    expect(batch.operations[2].group!.id, group.id);
  });

  test('first action after lazy reopen keeps its original transaction boundary', () async {
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    repository = LifeRepository(db);
    await db.transaction(() async {
      await repository.addTask(const TaskDraft(title: 'First after restart'));
      await repository.addTask(const TaskDraft(title: 'Same original action'));
    });
    final rows = await db
        .customSelect(
          'SELECT mutation_group_id FROM sync_journal WHERE origin_sequence>1',
        )
        .get();
    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row.read<String>('mutation_group_id')).toSet(),
      hasLength(1),
    );
  });

  test('one action retains its bounds across wire batch limits', () async {
    await db.transaction(() async {
      for (var i = 0; i < 513; i++) {
        await repository.addTask(TaskDraft(title: 'Synthetic grouped task $i'));
      }
    });
    final first = (await repository.prepareNextSyncBatch(binding, key))!;
    final firstClear = await decrypt(first);
    expect(firstClear.operations, hasLength(512));
    final group = firstClear.operations.last.group!;
    expect(group.first, 2);
    expect(group.last, 514);
    await repository.acknowledgeSyncBatch(first, remote(first));
    final next = await decrypt(
      (await repository.prepareNextSyncBatch(binding, key))!,
    );
    expect(next.operations, hasLength(2));
    expect(next.operations.map((op) => op.group!.id).toSet(), {group.id});
    expect(next.operations.last.group!.last, 514);
  });
}
