import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_view_preferences.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/portable_preferences.dart';
import 'package:life_manager/domain/sync/sync_visibility.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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

  Future<Map<String, Object?>> capturePrompt7Preference() async {
    // Prompt 7 used this same schema and capture trigger for the standalone
    // preference. Use its original write so sequence, group and heads are real.
    await db.customStatement(
      "INSERT INTO portable_preferences VALUES('detailPresentation', ?, ?)",
      ['"fullPage"', DateTime.now().toUtc().toIso8601String()],
    );
    final row = await db
        .customSelect(
          'SELECT j.*, g.first_sequence, g.last_sequence FROM sync_journal j '
          'JOIN sync_mutation_groups g ON j.mutation_group_id=g.id '
          "WHERE entity='portable_preferences'",
        )
        .getSingle();
    return row.data;
  }

  Future<List<Object?>> history() async => [
    (await db.customSelect('SELECT * FROM sync_capture_context').getSingle())
        .data,
    for (final table in [
      'sync_journal',
      'sync_entity_heads',
      'sync_mutation_groups',
    ])
      (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
          .map((row) => row.data)
          .toList(),
  ];

  Future<void> reopen() async {
    await db.close();
    db = await AppDatabase.open(file);
    repository = LifeRepository(db);
    expect(
      await db
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((row) => row.read<int>('user_version')),
      29,
    );
    expect(
      await db
          .customSelect('PRAGMA journal_mode')
          .getSingle()
          .then((row) => row.read<String>('journal_mode')),
      'wal',
    );
    expect(
      await db
          .customSelect('PRAGMA synchronous')
          .getSingle()
          .then((row) => row.read<int>('synchronous')),
      2,
    );
  }

  test('Prompt 7 reopen keeps captured preference and retries earlier upload byte for byte', () async {
    final original = (await repository.prepareNextSyncBatch(binding, key))!;
    final legacy = await capturePrompt7Preference();
    await repository.addTask(const TaskDraft(title: 'Dependent offline edit'));
    final before = await history();

    for (var restart = 0; restart < 2; restart++) {
      await reopen();
      expect(await history(), before);
      expect(await repository.portablePreferences(), isEmpty);
      expect(
        await db
            .customSelect(
              "SELECT value_json FROM portable_preferences WHERE key='detailPresentation'",
            )
            .getSingle()
            .then((row) => row.read<String>('value_json')),
        '"fullPage"',
      );
      final retried = (await repository.prepareNextSyncBatch(binding, key))!;
      expect(retried.id, original.id);
      expect(retried.bytes, original.bytes);
      expect(retried.sha256, original.sha256);
    }

    await repository.acknowledgeSyncBatch(original, remote(original));
    final afterAcknowledgement = await history();
    await expectLater(
      repository.prepareNextSyncBatch(binding, key),
      throwsA(isA<SyncPreferenceCompatibilityException>()),
    );
    expect(await history(), afterAcknowledgement);
    final dependent = await db
        .customSelect(
          'SELECT observed_json FROM sync_journal ORDER BY origin_sequence DESC LIMIT 1',
        )
        .getSingle();
    expect(
      jsonDecode(dependent.read<String>('observed_json'))[binding.device],
      legacy['origin_sequence'],
    );
    expect(
      (await repository.tasks()).map((task) => task.title),
      contains('Dependent offline edit'),
    );
  });

  test('previously published legacy envelope and dependent edit retain identity on a peer', () async {
    final peerFile = File('${root.path}/peer.sqlite');
    final peerDb = await AppDatabase.open(peerFile);
    addTearDown(peerDb.close);
    final peer = LifeRepository(peerDb);
    const peerBinding = SyncBinding(
      workspace: 'ba738dd5-6c52-497e-a6e3-04ab1888cd82',
      account: 'disposable-account',
      device: '307c48c3-8a55-451f-b859-dcd97f2a92fb',
    );
    await peer.activateSyncCapture(
      workspaceId: peerBinding.workspace,
      accountId: peerBinding.account,
      deviceId: peerBinding.device,
      recovery: BackupService(peerFile),
    );
    final lease = (await peer.acquireSyncLease(peerBinding))!;
    Future<void> apply(PendingSyncBatch batch) async {
      final object = remote(batch, id: batch.id);
      expect(
        await peer.retainIncomingSyncBatch(
          peerBinding,
          key,
          object,
          batch.bytes,
          lease: lease,
        ),
        1,
      );
      expect(
        await peer.retainIncomingSyncBatch(
          peerBinding,
          key,
          object,
          batch.bytes,
          lease: lease,
        ),
        0,
      );
      expect(
        (await peer.applyNextSyncGroup(peerBinding, lease: lease)).state,
        SyncApplyState.applied,
      );
    }

    final initial = (await repository.prepareNextSyncBatch(binding, key))!;
    await apply(initial);
    await repository.acknowledgeSyncBatch(
      initial,
      remote(initial, id: initial.id),
    );

    // Stage the exact legacy envelope as Prompt 7 would, before an upload
    // whose acknowledgement was interrupted.
    final row = await capturePrompt7Preference();
    const id = '405ca3dc-daf1-4653-b643-b1d024b3b832';
    final revision = SyncRevision(
      id: row['operation_id'] as String,
      device: binding.device,
      sequence: row['origin_sequence'] as int,
      parents: (jsonDecode(row['parent_ids_json'] as String) as List)
          .cast<String>(),
      observed: (jsonDecode(row['observed_json'] as String) as Map)
          .cast<String, int>(),
      visible: SyncVisibility.fromJson(
        (jsonDecode(row['visible_json'] as String) as Map)
            .cast<String, dynamic>(),
      ),
      value: (jsonDecode(row['after_json'] as String) as Map)
          .cast<String, Object?>(),
    );
    final bytes = await codec.encrypt(
      SyncBatch(
        id: id,
        device: binding.device,
        schema: 29,
        operations: [
          SyncRecordOperation(
            entity: 'portable_preferences',
            recordKey: row['record_key'] as String,
            revision: revision,
            group: SyncMutationGroup(
              id: row['mutation_group_id'] as String,
              first: row['first_sequence'] as int,
              last: row['last_sequence'] as int,
            ),
          ),
        ],
      ),
      key,
      workspace: binding.workspace,
      account: binding.account,
    );
    final digest = crypto.sha256.convert(bytes).toString();
    final legacy = PendingSyncBatch(
      id: id,
      binding: binding,
      bytes: bytes,
      sha256: digest,
    );
    await db.transaction(() async {
      await db.customStatement(
        "INSERT INTO sync_batches(id,workspace_id,account_id,device_id,direction,payload,sha256,created_at) "
        "VALUES(?,?,?,?,'outgoing',?,?,?)",
        [
          id,
          binding.workspace,
          binding.account,
          binding.device,
          bytes,
          digest,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
      await db.customStatement(
        'UPDATE sync_journal SET batch_id=? WHERE operation_id=?',
        [id, revision.id],
      );
    });
    final source = (await repository.tasks()).single;
    await repository.updateTask(
      source,
      const TaskDraft(title: 'Edit after legacy revision'),
    );
    final before = await history();
    await reopen();
    await expectLater(
      repository.prepareNextSyncBatch(binding, key),
      throwsA(isA<SyncPreferenceCompatibilityException>()),
    );
    expect(await history(), before);
    final retained = await db
        .customSelect(
          "SELECT id,payload,sha256,uploaded,superseded FROM sync_batches WHERE uploaded=0",
        )
        .getSingle();
    expect(retained.data, {
      'id': id,
      'payload': bytes,
      'sha256': digest,
      'uploaded': 0,
      'superseded': 0,
    });

    // Historical cloud delivery still accepts the original authenticated
    // revision. With a verified receipt, the dependent, compatible task
    // operation applies without a sequence gap.
    await apply(legacy);
    expect(await peer.portablePreferences(), isEmpty);
    await repository.acknowledgeSyncBatch(
      legacy,
      remote(legacy, id: legacy.id),
    );
    final next = (await repository.prepareNextSyncBatch(binding, key))!;
    final subsequent = (await decrypt(next)).operations.single.revision;
    expect(subsequent.observed[binding.device], revision.sequence);
    expect(subsequent.parents, [
      (await decrypt(initial)).operations.single.revision.id,
    ]);
    await apply(next);
    expect((await peer.tasks()).single.title, 'Edit after legacy revision');
  });

  test(
    'device presentation stays local while current preferences are exchanged',
    () async {
      final appearance = AppearancePreferenceStore(
        File('${root.path}/appearance.json'),
      );
      await appearance.saveTaskViewPreferences(
        const TaskViewPreferences(detailPresentation: 'fullPage'),
      );
      await appearance.saveCustomization(
        const ThemeCustomization(detailPresentation: 'fullPage'),
      );
      await reopen();
      final controller = AppController(repository, appearanceStore: appearance);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.taskViewPreferences.detailPresentation, 'fullPage');
      expect(
        (await appearance.loadTaskViewPreferences()).detailPresentation,
        'fullPage',
      );

      final outgoing = (await repository.prepareNextSyncBatch(binding, key))!;
      final decoded = await decrypt(outgoing);
      final preferences = decoded.operations.where(
        (op) => op.entity == 'portable_preferences',
      );
      final preferenceKeys = preferences.map((op) => op.revision.value!['key']);
      expect(
        preferenceKeys,
        containsAll(['theme', 'customization', 'calendarContent']),
      );
      expect(preferenceKeys, isNot(contains('detailPresentation')));
      final theme = preferences.singleWhere(
        (op) => op.revision.value!['key'] == 'customization',
      );
      expect(
        jsonDecode(theme.revision.value!['value_json'] as String),
        isNot(contains('detailPresentation')),
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
