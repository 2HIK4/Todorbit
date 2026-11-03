import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

import '../support/mock_sync_drive.dart';

void main() {
  test('committed edits after the outgoing pass upload in a follow-up job', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-sync-schedule-',
    );
    addTearDown(() async {
      await root.delete(recursive: true);
    });
    final file = File('${root.path}/planner.sqlite');
    // Match the app's background executor and WAL mode so disk work does not
    // starve the foreground scheduling/lease timers. Keep recovery gates real.
    final db = AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000');
          db.execute('PRAGMA foreign_keys = ON');
          db.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
    addTearDown(db.close);
    final repository = LifeRepository(db);
    await repository.addTask(const TaskDraft(title: 'Before exchange'));
    final recovery = BackupService(file);
    const binding = SyncBinding(
      workspace: '32a0b8fc-9474-46cf-b40e-c0d2399a110c',
      account: 'mock-only',
      device: '628318fd-baf1-4462-9c10-a3ea5a918001',
    );
    await repository.activateSyncCapture(
      workspaceId: binding.workspace,
      accountId: binding.account,
      deviceId: binding.device,
      recovery: recovery,
    );
    await repository.setAutomaticSync(binding, true);
    final drive = MockSyncDrive(), key = SyncWorkspaceKey.generate();
    final entered = Completer<void>(), release = Completer<void>();
    var proofs = 0;
    final engine = SyncEngine(
      repository: repository,
      storage: drive,
      recovery: recovery,
      loadKey: (_) async => key,
      isUnlocked: () => true,
      changeDebounce: Duration.zero,
      verifyWorkspace: (_, _) async {
        proofs++;
      },
    );
    drive.beforeList = () async {
      drive.beforeList = null;
      entered.complete();
      await release.future;
    };
    final completed = engine.changes.firstWhere(
      (s) => proofs > 1 && s.phase == SyncPhase.upToDate,
    );
    completed.ignore();
    try {
      final first = engine.syncNow();
      await Future.any<void>([
        entered.future,
        first.then((_) {
          if (!entered.isCompleted) {
            throw StateError(
              'Exchange stopped before scan: ${engine.status.phase.name}, ${engine.status.notice}',
            );
          }
        }),
      ]);
      await repository.addTask(
        const TaskDraft(title: 'Committed during download'),
      );
      engine.localChanged();
      release.complete();
      await first;
      await completed;
      expect(proofs, 2);
      expect(drive.uploads, 2);
      expect((await repository.syncExchangeStatus()).pending, 0);
    } finally {
      if (!release.isCompleted) release.complete();
      await engine.close();
    }
  });
}
