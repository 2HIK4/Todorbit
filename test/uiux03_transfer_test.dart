import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/sync_visibility.dart';

void main() {
  test(
    'scheduled restore preserves resource assignments and their bytes',
    () async {
      final root = await Directory.systemTemp.createTemp('uiux03-restore-');
      final sourceFile = File('${root.path}/source.sqlite');
      final liveFile = File('${root.path}/live.sqlite');
      final source = AppDatabase(NativeDatabase(sourceFile));
      final repo = LifeRepository(source);
      try {
        final parent = await repo.addTask(const TaskDraft(title: 'Parent'));
        final sub = await repo.addSubtask(
          parent,
          const TaskDraft(title: 'Child'),
        );
        final file = File('${root.path}/attached.txt')
          ..writeAsStringSync('preserve bytes');
        final attachment = await repo.attachManagedFile(parent.id, file);
        final url = await repo.addExternalResource(
          parent.id,
          TaskResourceKind.url,
          'example.com',
        );
        for (final resource in [attachment, url]) {
          await repo.assignResourceToSubtasks(resource.id, [sub.id]);
        }
        final snapshot = File('${root.path}/portable.sqlite');
        await BackupService(sourceFile).exportTo(snapshot);
        final target = AppDatabase(NativeDatabase(liveFile));
        await LifeRepository(target).addTask(const TaskDraft(title: 'Current'));
        await target.close();
        final recovery = BackupService(liveFile);
        final imported = await recovery.importSnapshot(
          snapshot,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await recovery.scheduleRestore(
          imported,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await recovery.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        final restored = AppDatabase(NativeDatabase(liveFile));
        try {
          final read = LifeRepository(restored);
          expect(await read.resourceSubtasks(attachment.id), [sub.id]);
          expect(await read.resourceSubtasks(url.id), [sub.id]);
          expect(
            await read.managedAttachmentBytes(
              (await read.taskResources(parent.id))
                  .firstWhere((r) => r.id == attachment.id),
            ),
            'preserve bytes'.codeUnits,
          );
          expect(
            await restored.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await restored.close();
        }
      } finally {
        await source.close();
        await root.delete(recursive: true);
      }
    },
  );
  for (final key in [
    SyncWorkspaceKey.standard(),
    SyncWorkspaceKey.generate(),
  ]) {
    test(
      'schema 29 accepts old batches and old clients reject new ones (${key.isStandard})',
      () async {
        final codec = SyncBatchCodec();
        SyncBatch batch(int schema) => SyncBatch(
          id: 'batch-$schema',
          device: 'windows',
          schema: schema,
          operations: [
            SyncRecordOperation(
              entity: 'tasks',
              recordKey: '{"id":"task"}',
              group: SyncMutationGroup(id: 'group', first: 1, last: 1),
              revision: SyncRevision(
                id: 'op',
                device: 'windows',
                sequence: 1,
                parents: [],
                visible: SyncVisibility(const {}),
                value: {'id': 'task', 'title': 'Preserved'},
              ),
            ),
          ],
        );
        for (final old in [26, 27, 28]) {
          final bytes = await codec.encrypt(
            batch(old),
            key,
            workspace: 'workspace',
            account: 'account',
          );
          expect(
            (await codec.decrypt(
              bytes,
              key,
              workspace: 'workspace',
              account: 'account',
              expectedSchema: 29,
            )).schema,
            old,
          );
        }
        final newer = await codec.encrypt(
          batch(29),
          key,
          workspace: 'workspace',
          account: 'account',
        );
        await expectLater(
          codec.decrypt(
            newer,
            key,
            workspace: 'workspace',
            account: 'account',
            expectedSchema: 28,
          ),
          throwsA(isA<SyncSchemaMismatch>()),
        );
      },
    );
  }
}
