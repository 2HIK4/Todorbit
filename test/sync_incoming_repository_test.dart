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
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/sync_visibility.dart';
import 'package:uuid/uuid.dart';

void main() {
  const source = SyncBinding(
    workspace: 'a7ff3798-c2d1-4ee5-b918-953d3e0828f1',
    account: 'mock-only',
    device: 'cffd91d4-6579-4b3c-be11-8cef2e913299',
  );
  const target = SyncBinding(
    workspace: 'a7ff3798-c2d1-4ee5-b918-953d3e0828f1',
    account: 'mock-only',
    device: 'e61ee894-10e3-4ef3-9c20-05803e814bfc',
  );
  late Directory root;
  late AppDatabase left, right;
  late LifeRepository sender, receiver;
  late SyncWorkspaceKey key;
  final codec = SyncBatchCodec();
  CloudObject remote(PendingSyncBatch batch, {String? id, String? account}) =>
      CloudObject(
        id: id ?? batch.id,
        accountId: account ?? source.account,
        name: '${batch.id}.tdsync',
        bytes: batch.bytes.length,
        createdAt: DateTime.now().toUtc(),
        md5: crypto.md5.convert(batch.bytes).toString(),
        properties: {
          ...batch.properties,
          'application': 'todorbit-sync',
          'verified': 'true',
        },
      );
  Future<SyncBatch> clear(PendingSyncBatch batch) => codec.decrypt(
    batch.bytes,
    key,
    workspace: source.workspace,
    account: source.account,
    expectedSchema: AppDatabase.currentSchemaVersion,
  );
  Future<PendingSyncBatch> wrap(
    List<SyncRecordOperation> operations, {
    String? device,
  }) async {
    final batch = SyncBatch(
      id: const Uuid().v4(),
      device: device ?? source.device,
      schema: AppDatabase.currentSchemaVersion,
      operations: operations,
    );
    final bytes = await codec.encrypt(
      batch,
      key,
      workspace: source.workspace,
      account: source.account,
    );
    return PendingSyncBatch(
      id: batch.id,
      binding: SyncBinding(
        workspace: source.workspace,
        account: source.account,
        device: device ?? source.device,
      ),
      bytes: bytes,
      sha256: crypto.sha256.convert(bytes).toString(),
    );
  }

  Future<int> receive(PendingSyncBatch batch, {String? id}) => receiver
      .retainIncomingSyncBatch(target, key, remote(batch, id: id), batch.bytes);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-incoming-mocked-');
    final leftFile = File('${root.path}/left.sqlite');
    final rightFile = File('${root.path}/right.sqlite');
    left = AppDatabase(NativeDatabase(leftFile));
    right = AppDatabase(NativeDatabase(rightFile));
    sender = LifeRepository(left);
    receiver = LifeRepository(right);
    key = SyncWorkspaceKey.generate();
    await sender.activateSyncCapture(
      workspaceId: source.workspace,
      accountId: source.account,
      deviceId: source.device,
      recovery: BackupService(leftFile),
    );
    await receiver.activateSyncCapture(
      workspaceId: target.workspace,
      accountId: target.account,
      deviceId: target.device,
      recovery: BackupService(rightFile),
    );
  });
  tearDown(() async {
    await left.close();
    await right.close();
    await root.delete(recursive: true);
  });

  test(
    'out-of-order receipt survives restart without inventing visible success',
    () async {
      await sender.addTask(const TaskDraft(title: 'First retained fact'));
      final first = (await sender.prepareNextSyncBatch(source, key))!;
      await sender.acknowledgeSyncBatch(first, remote(first));
      await sender.addTask(const TaskDraft(title: 'Second retained fact'));
      final second = (await sender.prepareNextSyncBatch(source, key))!;
      expect(await receive(second), 1);
      expect(
        (await right.customSelect('SELECT known FROM sync_journal').getSingle())
            .read<int>('known'),
        0,
      );
      expect(await receiver.tasks(), isEmpty);
      await right.close();
      right = AppDatabase(NativeDatabase(File('${root.path}/right.sqlite')));
      receiver = LifeRepository(right);
      expect(await receive(first), 1);
      expect(await receive(second, id: 'duplicate-cloud-copy'), 0);
      final rows = await right
          .customSelect('SELECT known FROM sync_journal')
          .get();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.read<int>('known') == 1), isTrue);
      expect(
        await right.customSelect('SELECT * FROM sync_remote_objects').get(),
        hasLength(3),
      );
      final context = await right
          .customSelect('SELECT * FROM sync_capture_context')
          .getSingle();
      expect(context.readNullable<String>('last_success_utc'), isNull);
      expect(context.read<int>('device_sequence'), 0);
      expect(
        jsonDecode(context.read<String>('received_json'))[source.device],
        2,
      );
      expect(jsonDecode(context.read<String>('observed_json')), {
        target.device: 0,
      });
      expect(await receiver.tasks(), isEmpty);
      expect(await receiver.prepareNextSyncBatch(target, key), isNull);
      await receiver.addTask(const TaskDraft(title: 'Visible local work'));
      final local = await codec.decrypt(
        (await receiver.prepareNextSyncBatch(target, key))!.bytes,
        key,
        workspace: target.workspace,
        account: target.account,
        expectedSchema: AppDatabase.currentSchemaVersion,
      );
      expect(local.operations.single.revision.observed[source.device], isNull);
    },
  );

  test('partial original action waits for all batch fragments', () async {
    await left.transaction(() async {
      for (var i = 0; i < 513; i++) {
        await sender.addTask(TaskDraft(title: 'One large action $i'));
      }
    });
    final first = (await sender.prepareNextSyncBatch(source, key))!;
    await sender.acknowledgeSyncBatch(first, remote(first));
    final last = (await sender.prepareNextSyncBatch(source, key))!;
    expect(await receive(last), 1);
    expect(
      (await right
              .customSelect('SELECT complete FROM sync_mutation_groups')
              .getSingle())
          .read<int>('complete'),
      0,
    );
    expect(await receive(first), 512);
    expect(
      (await right
              .customSelect('SELECT complete FROM sync_mutation_groups')
              .getSingle())
          .read<int>('complete'),
      1,
    );
    expect(await receiver.tasks(), isEmpty);
  });

  test(
    'managed bytes remain exact while device-local resources are rejected',
    () async {
      final task = await sender.addTask(
        const TaskDraft(title: 'Managed resource owner'),
      );
      final file = File('${root.path}/synthetic.bin')
        ..writeAsBytesSync([0, 255, 4]);
      await sender.attachManagedFile(task.id, file);
      final batch = (await sender.prepareNextSyncBatch(source, key))!;
      expect(await receive(batch), 2);
      final resource = await right
          .customSelect(
            "SELECT after_json FROM sync_journal WHERE entity='task_resources'",
          )
          .getSingle();
      expect(jsonDecode(resource.read<String>('after_json'))['content'], {
        r'$blob': '00FF04',
      });
      final operations = (await clear(batch)).operations;
      final op = operations.singleWhere((op) => op.entity == 'task_resources');
      final bad = await wrap([
        SyncRecordOperation(
          entity: op.entity,
          recordKey: op.recordKey,
          group: op.group,
          revision: SyncRevision(
            id: const Uuid().v4(),
            device: source.device,
            sequence: op.revision.sequence,
            parents: op.revision.parents,
            observed: op.revision.observed,
            visible: op.revision.visible,
            value: {
              ...op.revision.value!,
              'kind': 'file',
              'target': r'C:\private\unrelated.txt',
            },
          ),
        ),
      ]);
      await expectLater(receive(bad), throwsFormatException);
      expect(
        await right.customSelect('SELECT * FROM sync_batches').get(),
        hasLength(1),
      );
    },
  );

  test(
    'authentication and metadata failure leave no receipt or cloud checkpoint',
    () async {
      await sender.addTask(const TaskDraft(title: 'Retain locally'));
      final batch = (await sender.prepareNextSyncBatch(source, key))!;
      await expectLater(
        receiver.retainIncomingSyncBatch(
          target,
          SyncWorkspaceKey.generate(),
          remote(batch),
          batch.bytes,
        ),
        throwsFormatException,
      );
      await expectLater(
        receiver.retainIncomingSyncBatch(
          target,
          key,
          remote(batch, account: 'wrong-account'),
          batch.bytes,
        ),
        throwsFormatException,
      );
      expect(
        await right.customSelect('SELECT * FROM sync_batches').get(),
        isEmpty,
      );
      expect(
        await right.customSelect('SELECT * FROM sync_journal').get(),
        isEmpty,
      );
      expect(
        (await right
                .customSelect('SELECT change_token FROM sync_capture_context')
                .getSingle())
            .readNullable<String>('change_token'),
        isNull,
      );
    },
  );

  test('malformed final operation rolls back the entire batch', () async {
    await sender.addTask(const TaskDraft(title: 'Valid first'));
    await sender.addTask(const TaskDraft(title: 'Invalid second'));
    final batch = await clear(
      (await sender.prepareNextSyncBatch(source, key))!,
    );
    final second = batch.operations.last;
    final bad = await wrap([
      batch.operations.first,
      SyncRecordOperation(
        entity: 'notification_settings',
        recordKey: second.recordKey,
        revision: second.revision,
        group: second.group,
      ),
    ]);
    await expectLater(receive(bad), throwsFormatException);
    expect(
      await right.customSelect('SELECT * FROM sync_batches').get(),
      isEmpty,
    );
    expect(
      await right.customSelect('SELECT * FROM sync_journal').get(),
      isEmpty,
    );
    expect(
      await right.customSelect('SELECT * FROM sync_mutation_groups').get(),
      isEmpty,
    );
  });

  test(
    'cross-device causal cycle is rejected when its missing side arrives',
    () async {
      await sender.addTask(
        const TaskDraft(title: 'Full portable synthetic row'),
      );
      final prototype = (await clear(
        (await sender.prepareNextSyncBatch(source, key))!,
      )).operations.single;
      const other = '98c1804a-6642-4617-af68-8f756db397c2';
      SyncRecordOperation operation(String device, String observedDevice) =>
          SyncRecordOperation(
            entity: prototype.entity,
            recordKey: prototype.recordKey,
            group: SyncMutationGroup(id: const Uuid().v4(), first: 1, last: 1),
            revision: SyncRevision(
              id: const Uuid().v4(),
              device: device,
              sequence: 1,
              parents: [],
              observed: {observedDevice: 1},
              visible: SyncVisibility({}),
              value: prototype.revision.value,
            ),
          );
      final a = await wrap([operation(source.device, other)]);
      final b = await wrap([operation(other, source.device)], device: other);
      expect(await receive(a), 1);
      await expectLater(receive(b), throwsFormatException);
      expect(
        await right.customSelect('SELECT * FROM sync_batches').get(),
        hasLength(1),
      );
      expect(
        (await right.customSelect('SELECT known FROM sync_journal').getSingle())
            .read<int>('known'),
        0,
      );
      expect(await receiver.tasks(), isEmpty);
    },
  );

  test(
    'visibility cannot acknowledge a fragment of another original action',
    () async {
      await left.transaction(() async {
        await sender.addTask(const TaskDraft(title: 'One grouped action A'));
        await sender.addTask(const TaskDraft(title: 'One grouped action B'));
      });
      final batch = (await sender.prepareNextSyncBatch(source, key))!;
      final prototype = (await clear(batch)).operations.first;
      expect(await receive(batch), 2);
      const other = '11d34975-bd28-43df-9dba-8d228c97ea74';
      Future<PendingSyncBatch> edit(int visibleThrough) => wrap([
        SyncRecordOperation(
          entity: prototype.entity,
          recordKey: prototype.recordKey,
          group: SyncMutationGroup(id: const Uuid().v4(), first: 1, last: 1),
          revision: SyncRevision(
            id: const Uuid().v4(),
            device: other,
            sequence: 1,
            parents: [prototype.revision.id],
            observed: {source.device: 2},
            visible: SyncVisibility({})
                .withRange(source.device, 1, visibleThrough),
            value: {
              ...prototype.revision.value!,
              'title': 'Reviewed whole source action',
            },
          ),
        ),
      ], device: other);
      await expectLater(receive(await edit(1)), throwsFormatException);
      expect(
        await right.customSelect('SELECT * FROM sync_journal').get(),
        hasLength(2),
      );
      expect(await receive(await edit(2)), 1);
      expect(await receiver.tasks(), isEmpty);
    },
  );
  test('a delayed page unlocks bounded durable work across restart', () async {
    await left.transaction(() async {
      for (var i = 0; i < 1025; i++) {
        await sender.addTask(TaskDraft(title: 'One large original action $i'));
      }
    });
    final batches = <PendingSyncBatch>[];
    while (true) {
      final batch = await sender.prepareNextSyncBatch(source, key);
      if (batch == null) break;
      batches.add(batch);
      await sender.acknowledgeSyncBatch(batch, remote(batch));
    }
    expect(batches, hasLength(3));
    expect(await receive(batches[2]), 1);
    expect(await receive(batches[1]), 512);
    expect(await receive(batches[0]), 512);
    expect(
      (await right
              .customSelect(
                'SELECT COUNT(*) AS n FROM sync_journal WHERE known=1',
              )
              .getSingle())
          .read<int>('n'),
      1024,
    );
    expect(
      (await right
              .customSelect('SELECT complete FROM sync_mutation_groups')
              .getSingle())
          .read<int>('complete'),
      0,
    );
    await right.close();
    right = AppDatabase(NativeDatabase(File('${root.path}/right.sqlite')));
    receiver = LifeRepository(right);
    await receiver.addTask(
      const TaskDraft(title: 'User action between short sync jobs'),
    );
    expect(await receiver.advanceRetainedSyncHistory(target), 1);
    expect(await receiver.advanceRetainedSyncHistory(target), 0);
    expect(
      (await right
              .customSelect(
                "SELECT complete FROM sync_mutation_groups WHERE device_id='${source.device}'",
              )
              .getSingle())
          .read<int>('complete'),
      1,
    );
    expect(
      (await receiver.tasks()).single.title,
      'User action between short sync jobs',
    );
    final context = await right
        .customSelect('SELECT * FROM sync_capture_context')
        .getSingle();
    expect(
      jsonDecode(context.read<String>('received_json'))[source.device],
      1025,
    );
    expect(
      jsonDecode(context.read<String>('visible_json'))[source.device],
      isNull,
    );
  });
}
