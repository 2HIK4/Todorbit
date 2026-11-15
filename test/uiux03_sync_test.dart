import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/domain/saved_views.dart';

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
import 'package:life_manager/domain/task_resources.dart';

class _BeforeApplyDatabase extends AppDatabase {
  _BeforeApplyDatabase(super.executor);
  Future<void> Function()? beforeTransaction;
  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    final checkpoint = beforeTransaction;
    beforeTransaction = null;
    if (checkpoint != null) await checkpoint();
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  const a = SyncBinding(
    workspace: '8b41595f-3258-40e7-8499-856772bf5fb8',
    account: 'mocked-apply-only',
    device: 'df0293d3-c369-4db8-a998-0ae0b076397d',
  );
  const b = SyncBinding(
    workspace: '8b41595f-3258-40e7-8499-856772bf5fb8',
    account: 'mocked-apply-only',
    device: 'b870f5ae-b161-4241-bd65-63b9553d9de3',
  );
  late Directory root;
  late AppDatabase left, right;
  late LifeRepository sender, receiver;
  late SyncWorkspaceKey key;
  SyncLease? leftLease, rightLease;
  CloudObject remote(PendingSyncBatch batch) => CloudObject(
    id: batch.id,
    accountId: a.account,
    name: 'opaque.tdsync',
    bytes: batch.bytes.length,
    createdAt: DateTime.now().toUtc(),
    md5: crypto.md5.convert(batch.bytes).toString(),
    properties: {
      ...batch.properties,
      'application': 'todorbit-sync',
      'verified': 'true',
    },
  );
  Future<List<PendingSyncBatch>> exchange({bool reverse = false}) async {
    final from = reverse ? receiver : sender, to = reverse ? sender : receiver;
    final fromBinding = reverse ? b : a, toBinding = reverse ? a : b;
    final fromLease = reverse ? rightLease : leftLease,
        toLease = reverse ? leftLease : rightLease;
    final batches = <PendingSyncBatch>[];
    while (true) {
      final batch = await from.prepareNextSyncBatch(
        fromBinding,
        key,
        lease: fromLease,
      );
      if (batch == null) break;
      await to.retainIncomingSyncBatch(
        toBinding,
        key,
        remote(batch),
        batch.bytes,
        lease: toLease,
      );
      await from.acknowledgeSyncBatch(batch, remote(batch), lease: fromLease);
      batches.add(batch);
    }
    return batches;
  }

  Future<SyncApplyResult> apply({bool reverse = false}) async {
    if (reverse) {
      leftLease ??= await sender.acquireSyncLease(a);
      return sender.applyNextSyncGroup(a, lease: leftLease!);
    }
    rightLease ??= await receiver.acquireSyncLease(b);
    return receiver.applyNextSyncGroup(b, lease: rightLease!);
  }

  Future<void> seed() async {
    await exchange();
    for (var i = 0; i < 100; i++) {
      final result = await apply();
      if (result.state == SyncApplyState.idle) return;
      expect(result.state, SyncApplyState.applied, reason: result.reason);
    }
    fail('Sync groups did not drain');
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-sync-apply-');
    final leftFile = File('${root.path}/left.sqlite'),
        rightFile = File('${root.path}/right.sqlite');
    left = AppDatabase(NativeDatabase(leftFile));
    right = _BeforeApplyDatabase(NativeDatabase(rightFile));
    sender = LifeRepository(left);
    receiver = LifeRepository(right, taskClock: () => DateTime.utc(2050));
    key = SyncWorkspaceKey.generate();
    leftLease = null;
    rightLease = null;
    await sender.addTask(const TaskDraft(title: 'Original synthetic task'));
    await sender.activateSyncCapture(
      workspaceId: a.workspace,
      accountId: a.account,
      deviceId: a.device,
      recovery: BackupService(leftFile),
    );
    await receiver.activateSyncCapture(
      workspaceId: b.workspace,
      accountId: b.account,
      deviceId: b.device,
      recovery: BackupService(rightFile),
    );
  });
  tearDown(() async {
    await left.close();
    await right.close();
    await root.delete(recursive: true);
  });

  test('UIUX03 assignments, custom views and visibility exchange and delete safely', () async {
    final category = await sender.addCategory('Hidden category');
    final project = await sender.addProject(category.id, 'Hidden project');
    final parent = await sender.addTask(
      TaskDraft(
        title: 'Parent',
        categoryId: category.id,
        projectId: project.id,
      ),
    );
    final sub = await sender.addSubtask(
      parent,
      const TaskDraft(title: 'Child'),
    );
    final resource = await sender.addExternalResource(
      parent.id,
      TaskResourceKind.url,
      'example.com/guide',
    );
    final file = File('${root.path}/image.png')..writeAsBytesSync([1, 2, 3, 4]);
    final image = await sender.attachManagedFile(parent.id, file);
    final local = await sender.addExternalResource(
      parent.id,
      TaskResourceKind.externalFile,
      file.path,
    );
    for (final res in [resource, image, local]) {
      await sender.assignResourceToSubtasks(res.id, [sub.id]);
    }
    final c = AppController(sender);
    await c.toggleCategoryStandardVisibility(category.id);
    await c.toggleProjectStandardVisibility(project.id);
    c.dispose();
    final view = await sender.addSavedView(
      'Custom',
      TaskFilter(
        categoryIds: {category.id},
        projectIds: {project.id},
        priorities: {0, 3},
        iconKey: 'work',
      ),
    );
    await seed();
    expect(await receiver.resourceSubtasks(resource.id), [sub.id]);
    expect(await receiver.resourceSubtasks(image.id), [sub.id]);
    expect(await receiver.resourceSubtasks(local.id), isEmpty);
    expect(
      await receiver.managedAttachmentBytes(
        (await receiver.taskResources(parent.id))
            .singleWhere((r) => r.id == image.id),
      ),
      [1, 2, 3, 4],
    );
    final copiedView = (await receiver.savedViews()).single;
    expect(copiedView.id, view.id);
    expect(copiedView.filter.toJson(), view.filter.toJson());
    final prefs = await receiver.portablePreferences();
    expect(prefs['hiddenStandardCategories'], [category.id]);
    expect(prefs['hiddenStandardProjects'], [project.id]);
    final snapshot = File('${root.path}/snapshot.sqlite');
    await BackupService(File('${root.path}/left.sqlite')).exportTo(snapshot);
    final restored = AppDatabase(NativeDatabase(snapshot));
    try {
      expect(await LifeRepository(restored).resourceSubtasks(resource.id), [
        sub.id,
      ]);
      expect(await LifeRepository(restored).resourceSubtasks(image.id), [
        sub.id,
      ]);
      expect(await LifeRepository(restored).resourceSubtasks(local.id), [
        sub.id,
      ]);
    } finally {
      await restored.close();
    }
    await sender.assignResourceToSubtasks(resource.id, []);
    await exchange();
    expect((await apply()).state, SyncApplyState.applied);
    expect(await receiver.resourceSubtasks(resource.id), isEmpty);
    await sender.removeTaskResource(image);
    await exchange();
    final deleted = await apply();
    expect(deleted.state, SyncApplyState.applied, reason: deleted.reason);
    expect(await receiver.resourceSubtasks(image.id), isEmpty);
    expect(
      (await right.customSelect('PRAGMA foreign_key_check').get()),
      isEmpty,
    );
  });
}
