import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  const original = SyncBinding(
    workspace: '9d0bc866-4346-4872-8841-b0e7f08e21d5',
    account: 'mock-restore',
    device: 'e67d75a3-024f-4ab7-a5f5-bc7c6e2b9521',
  );
  final restored = SyncBinding(
    workspace: original.workspace,
    account: original.account,
    device: 'e67d75a3-024f-4ab7-a5f5-bc7c6e2b9522',
  );
  final peer = SyncBinding(
    workspace: original.workspace,
    account: original.account,
    device: 'e67d75a3-024f-4ab7-a5f5-bc7c6e2b9523',
  );
  CloudObject remote(PendingSyncBatch batch) => CloudObject(
    id: batch.id,
    accountId: original.account,
    name: 'synthetic.tdsync',
    bytes: batch.bytes.length,
    createdAt: DateTime.now().toUtc(),
    md5: md5.convert(batch.bytes).toString(),
    properties: {
      ...batch.properties,
      'application': 'todorbit-sync',
      'verified': 'true',
    },
  );
  test('restore retains original queued ciphertext and reconciles restored/latest/cloud-only records without inferred deletes', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-sync-restore-',
    );
    final file = File('${root.path}/active.sqlite'),
        otherFile = File('${root.path}/peer.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final other = AppDatabase(NativeDatabase(otherFile));
    AppDatabase? archive;
    final recovery = BackupService(file);
    final key = SyncWorkspaceKey.generate();
    try {
      var repository = LifeRepository(db);
      await repository.addTask(const TaskDraft(title: 'Restored older view'));
      final task = (await repository.tasks()).single;
      await repository.activateSyncCapture(
        workspaceId: original.workspace,
        accountId: original.account,
        deviceId: original.device,
        recovery: recovery,
      );
      final staged = (await repository.prepareNextSyncBatch(original, key))!;
      final older = await recovery.createBackup(BackupKind.manual);
      await repository.updateTask(
        (await repository.tasks()).single,
        const TaskDraft(title: 'Offline latest before restore'),
      );
      final latestOperation = (await repository.pendingSyncChanges(
        workspaceId: original.workspace,
        accountId: original.account,
      )).last['operation_id'];
      await recovery.scheduleRestore(
        older,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await db.close();
      final before = (await recovery.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      ))!;
      final archiveDigest = sha256
          .convert(await before.file.readAsBytes())
          .toString();
      await recovery.markRestoreOpened();
      expect(
        (await recovery.restorationRecoveryBackup())!.file.path,
        before.file.path,
      );
      archive = AppDatabase(
        NativeDatabase.opened(
          sqlite.sqlite3.open(before.file.path, mode: sqlite.OpenMode.readOnly),
          enableMigrations: false,
        ),
      );
      db = AppDatabase(NativeDatabase(file));
      repository = LifeRepository(db);
      expect((await repository.tasks()).single.title, 'Restored older view');
      expect((await repository.syncExchangeStatus()).quarantined, isTrue);
      final kept = await repository.reconcileRestoredSync(
        binding: restored,
        recovery: recovery,
        beforeRestore: archive,
      );
      expect(await kept.file.exists(), isTrue);
      expect((await repository.tasks()).single.title, 'Restored older view');
      expect((await repository.syncExchangeStatus()).automatic, isFalse);
      expect(
        (await db
                .customSelect(
                  'SELECT operation_id FROM sync_journal WHERE operation_id=?',
                  variables: [Variable.withString(latestOperation as String)],
                )
                .get())
            .length,
        1,
      );
      final lease = (await repository.acquireSyncLease(restored))!;
      final retry = (await repository.prepareNextSyncBatch(
        restored,
        key,
        lease: lease,
      ))!;
      expect(retry.id, staged.id);
      expect(retry.originDevice, original.device);
      expect(retry.bytes, orderedEquals(staged.bytes));
      final otherRepository = LifeRepository(other);
      await otherRepository.activateSyncCapture(
        workspaceId: peer.workspace,
        accountId: peer.account,
        deviceId: peer.device,
        recovery: BackupService(otherFile),
      );
      await otherRepository.addTask(
        const TaskDraft(title: 'New cloud-only task'),
      );
      final cloudOnly = (await otherRepository.prepareNextSyncBatch(
        peer,
        key,
      ))!;
      await repository.retainIncomingSyncBatch(
        restored,
        key,
        remote(cloudOnly),
        cloudOnly.bytes,
        lease: lease,
      );
      await otherRepository.acknowledgeSyncBatch(cloudOnly, remote(cloudOnly));
      var applied = await repository.applyNextSyncGroup(restored, lease: lease);
      expect(applied.state, SyncApplyState.applied, reason: applied.reason);
      applied = await repository.applyNextSyncGroup(restored, lease: lease);
      expect(applied.state, SyncApplyState.needsReview);
      expect((await repository.tasks()).map((t) => t.title).toSet(), {
        'Restored older view',
        'New cloud-only task',
      });
      final sent = <String>{};
      while (true) {
        final batch = await repository.prepareNextSyncBatch(
          restored,
          key,
          lease: lease,
        );
        if (batch == null) break;
        final decoded = await SyncBatchCodec().decrypt(
          batch.bytes,
          key,
          workspace: restored.workspace,
          account: restored.account,
          expectedSchema: AppDatabase.currentSchemaVersion,
        );
        sent.addAll(decoded.operations.map((op) => op.revision.id));
        await otherRepository.retainIncomingSyncBatch(
          peer,
          key,
          remote(batch),
          batch.bytes,
        );
        await repository.acknowledgeSyncBatch(
          batch,
          remote(batch),
          lease: lease,
        );
      }
      expect(sent, contains(latestOperation));
      expect((await repository.syncExchangeStatus()).pending, 0);
      final review = (await repository.reviewSyncConflicts(
        restored,
        lease: lease,
      ))!;
      final conflict = review.records.singleWhere(
        (r) => jsonDecode(r.key)['id'] == task.id,
      );
      expect(conflict.candidates.values.map((v) => v?['title']).toSet(), {
        'Restored older view',
        'Offline latest before restore',
      });
      expect(
        sha256.convert(await before.file.readAsBytes()).toString(),
        archiveDigest,
      );
      expect(await before.file.exists(), isTrue);
      await repository.releaseSyncLease(lease);
    } finally {
      await archive?.close();
      await db.close();
      await other.close();
      await root.delete(recursive: true);
    }
  });
}
