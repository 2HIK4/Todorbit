import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  const binding = SyncBinding(
    workspace: 'b1cbde7f-503e-468d-8291-07f327cdeacc',
    account: 'synthetic-only',
    device: '91668f48-d085-4d32-a420-6b89baef051e',
  );
  for (final stop in ['uncommitted', 'staged']) {
    test('real process death at $stop retains exact committed state', () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-sync-crash-',
      );
      final file = File('${root.path}/synthetic.sqlite');
      final marker = File('${root.path}/barrier.json');
      final key = SyncWorkspaceKey.generate();
      var db = AppDatabase(NativeDatabase(file));
      try {
        var repository = LifeRepository(db);
        await repository.addTask(
          const TaskDraft(title: 'Original committed synthetic action'),
        );
        await repository.activateSyncCapture(
          workspaceId: binding.workspace,
          accountId: binding.account,
          deviceId: binding.device,
          recovery: BackupService(file),
        );
        await db.close();
        final child = await Process.start(
          'dart',
          [
            'run',
            'test/support/sync_crash_worker.dart',
            file.path,
            marker.path,
            stop,
          ],
          runInShell: Platform.isWindows,
          environment: {
            'APPDATA': '${root.path}/roaming',
            'LOCALAPPDATA': '${root.path}/local',
            'TODORBIT_SYNTHETIC_SYNC_KEY': key.exportRecoveryCode(),
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
            reason: 'Synthetic child did not reach its durable barrier',
          );
        } finally {
          if (Platform.isWindows) {
            await Process.run('taskkill', ['/PID', '${child.pid}', '/T', '/F']);
          } else {
            child.kill(ProcessSignal.sigkill);
          }
          await child.exitCode;
          await output;
          await errors;
        }
        db = AppDatabase(NativeDatabase(file));
        repository = LifeRepository(db);
        expect((await repository.tasks()).map((task) => task.title), [
          'Original committed synthetic action',
        ]);
        expect(
          await db.customSelect('SELECT * FROM sync_journal').get(),
          hasLength(1),
        );
        final context = await db
            .customSelect('SELECT * FROM sync_capture_context')
            .getSingle();
        expect(context.readNullable<String>('mutation_group'), isNull);
        expect(context.read<int>('device_sequence'), 1);
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        if (stop == 'staged') {
          final receipt = jsonDecode(await marker.readAsString()) as Map;
          final resumed = (await repository.prepareNextSyncBatch(
            binding,
            key,
          ))!;
          expect(resumed.id, receipt['batch']);
          expect(resumed.sha256, receipt['sha256']);
          expect(resumed.bytes, base64Decode(receipt['bytes'] as String));
        } else {
          expect(
            await db.customSelect('SELECT * FROM sync_batches').get(),
            isEmpty,
          );
        }
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
