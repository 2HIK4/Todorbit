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

void main() {
  const a = SyncBinding(
    workspace: '143ed082-f0c1-4ba6-8be3-c00feb7618e8',
    account: 'mocked-crash-only',
    device: '073075ce-a0ce-4635-a4dd-5add297c7663',
  );
  const b = SyncBinding(
    workspace: '143ed082-f0c1-4ba6-8be3-c00feb7618e8',
    account: 'mocked-crash-only',
    device: 'b50069da-a5dc-4b23-bd1b-6a10026b78d4',
  );
  for (final stop in ['rows', 'materialized']) {
    test(
      'real process death after $stop rolls back data, flags and domain triggers',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'todorbit-apply-crash-',
        );
        final target = File('${root.path}/target.sqlite');
        final source = File('${root.path}/source.sqlite');
        final marker = File('${root.path}/barrier');
        AppDatabase? db;
        try {
          final senderDb = AppDatabase(NativeDatabase(source));
          late PendingSyncBatch batch;
          final key = SyncWorkspaceKey.generate();
          try {
            final sender = LifeRepository(senderDb);
            await sender.addTask(
              const TaskDraft(title: 'Original authenticated synthetic task'),
            );
            await sender.activateSyncCapture(
              workspaceId: a.workspace,
              accountId: a.account,
              deviceId: a.device,
              recovery: BackupService(source),
            );
            batch = (await sender.prepareNextSyncBatch(a, key))!;
          } finally {
            await senderDb.close();
          }
          db = AppDatabase(NativeDatabase(target));
          var receiver = LifeRepository(db);
          await receiver.activateSyncCapture(
            workspaceId: b.workspace,
            accountId: b.account,
            deviceId: b.device,
            recovery: BackupService(target),
          );
          final object = CloudObject(
            id: batch.id,
            accountId: b.account,
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
          await receiver.retainIncomingSyncBatch(b, key, object, batch.bytes);
          await db.close();
          db = null;
          final child = await Process.start(
            'dart',
            [
              'run',
              'test/support/sync_apply_crash_worker.dart',
              target.path,
              marker.path,
              stop,
            ],
            runInShell: Platform.isWindows,
            environment: {
              'APPDATA': '${root.path}/roaming',
              'LOCALAPPDATA': '${root.path}/local',
            },
          );
          final output = child.stdout.transform(utf8.decoder).join();
          final errors = child.stderr.transform(utf8.decoder).join();
          try {
            final deadline = DateTime.now().add(const Duration(seconds: 60));
            while (!marker.existsSync() && DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
            expect(
              marker.existsSync(),
              isTrue,
              reason:
                  'Synthetic apply worker did not reach its durable barrier',
            );
          } finally {
            if (Platform.isWindows) {
              await Process.run('taskkill', [
                '/PID',
                '${child.pid}',
                '/T',
                '/F',
              ]);
            } else {
              child.kill(ProcessSignal.sigkill);
            }
            await child.exitCode;
            await output;
            await errors;
          }
          db = AppDatabase(NativeDatabase(target));
          receiver = LifeRepository(db);
          expect(await receiver.tasks(), isEmpty);
          expect(
            (await db.customSelect('PRAGMA integrity_check').getSingle())
                .data
                .values
                .single,
            'ok',
          );
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          expect(
            (await db
                    .customSelect(
                      'SELECT applying_remote FROM sync_capture_context',
                    )
                    .getSingle())
                .read<int>('applying_remote'),
            0,
          );
          expect(
            (await db
                    .customSelect(
                      'SELECT materialized FROM sync_mutation_groups',
                    )
                    .getSingle())
                .read<int>('materialized'),
            0,
          );
          expect(
            await db
                .customSelect(
                  "SELECT name FROM sqlite_schema WHERE type='trigger' AND name NOT GLOB 'sync_*'",
                )
                .get(),
            hasLength(7),
          );
          expect(
            await db.customSelect('SELECT * FROM sync_entity_heads').get(),
            isEmpty,
          );
          // Advance the synthetic lease expiry without a time-dependent sleep.
          // All actual user data/operation rows remain unchanged.
          await db.customStatement(
            'UPDATE sync_capture_context SET lease_until_ms=0',
          );
          final lease = (await receiver.acquireSyncLease(b))!;
          final resumed = await receiver.applyNextSyncGroup(b, lease: lease);
          expect(resumed.state, SyncApplyState.applied, reason: resumed.reason);
          expect(
            (await receiver.tasks()).single.title,
            'Original authenticated synthetic task',
          );
          expect(
            (await receiver.applyNextSyncGroup(b, lease: lease)).state,
            SyncApplyState.idle,
          );
          expect(
            await db.customSelect('SELECT * FROM sync_journal').get(),
            hasLength(1),
          );
          expect(
            await receiver.pendingSyncChanges(
              workspaceId: b.workspace,
              accountId: b.account,
            ),
            isEmpty,
          );
          expect(
            (await db
                    .customSelect('SELECT payload FROM sync_batches')
                    .getSingle())
                .data['payload'],
            batch.bytes,
          );
        } finally {
          await db?.close();
          await root.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
