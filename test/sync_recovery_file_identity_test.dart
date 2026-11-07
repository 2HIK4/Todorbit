import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';
import 'package:path/path.dart' as path;

void main() {
  const first = SyncBinding(
    workspace: '8e2668f4-af81-4209-b1f3-bb00299a44d3',
    account: 'synthetic-alias-account',
    device: '8e2668f4-af81-4209-b1f3-bb00299a44d4',
  );
  final restored = SyncBinding(
    workspace: first.workspace,
    account: first.account,
    device: '8e2668f4-af81-4209-b1f3-bb00299a44d5',
  );

  test(
    'directory alias preserves Before Sync and restored reconciliation',
    () async {
      final root = await Directory.systemTemp.createTemp('todorbit-db-alias-');
      final real = await Directory('${root.path}/real').create();
      final alias = Directory('${root.path}/alias');
      if (Platform.isWindows) {
        final result = await Process.run('cmd', [
          '/d',
          '/c',
          'mklink',
          '/J',
          path.normalize(alias.path),
          path.normalize(real.path),
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      } else {
        await Link(alias.path).create(real.path);
      }
      final file = File('${real.path}/life.sqlite');
      final aliasFile = File('${alias.path}/life.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(db);
        final task = await repo.addTask(
          const TaskDraft(title: 'Synthetic alias task'),
        );
        final service = BackupService(aliasFile);
        final backup = await repo.activateSyncCapture(
          workspaceId: first.workspace,
          accountId: first.account,
          deviceId: first.device,
          recovery: service,
        );
        expect(backup, isNotNull);
        expect((await repo.syncExchangeStatus()).binding?.device, first.device);
        await repo.quarantineRestoredSync();
        await repo.reconcileRestoredSync(binding: restored, recovery: service);
        expect((await repo.syncExchangeStatus()).quarantined, false);
        expect((await repo.tasks()).single.id, task.id);
        expect((await service.list()).length, greaterThanOrEqualTo(2));
      } finally {
        await db.close();
        // Remove only the verified alias itself, never recurse through its target.
        if (Platform.isWindows) {
          await alias.delete();
        } else {
          await Link(alias.path).delete();
        }
        await real.delete(recursive: true);
        await root.delete();
      }
    },
  );

  test(
    'different database with the same basename is rejected before backup',
    () async {
      final root = await Directory.systemTemp.createTemp('todorbit-db-other-');
      final a = await Directory('${root.path}/a').create();
      final b = await Directory('${root.path}/b').create();
      final db = AppDatabase(NativeDatabase(File('${a.path}/life.sqlite')));
      try {
        final repo = LifeRepository(db);
        await repo.addTask(const TaskDraft(title: 'Synthetic preserved task'));
        final wrong = File('${b.path}/life.sqlite');
        await wrong.writeAsString(
          'Unrelated file; must never be opened as backup',
        );
        final service = BackupService(wrong);
        await expectLater(
          repo.activateSyncCapture(
            workspaceId: first.workspace,
            accountId: first.account,
            deviceId: first.device,
            recovery: service,
          ),
          throwsStateError,
        );
        expect((await repo.syncExchangeStatus()).binding, isNull);
        expect(await service.list(), isEmpty);
        await repo.quarantineRestoredSync();
        await expectLater(
          repo.reconcileRestoredSync(binding: restored, recovery: service),
          throwsStateError,
        );
        expect((await repo.syncExchangeStatus()).quarantined, true);
        expect(
          await wrong.readAsString(),
          'Unrelated file; must never be opened as backup',
        );
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'hard-linked database in another journal directory is rejected',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-db-hardlink-',
      );
      final a = await Directory('${root.path}/a').create();
      final b = await Directory('${root.path}/b').create();
      final source = File('${a.path}/life.sqlite');
      final other = File('${b.path}/life.sqlite');
      final db = AppDatabase(NativeDatabase(source));
      try {
        final repo = LifeRepository(db);
        await repo.addTask(const TaskDraft(title: 'Synthetic WAL sentinel'));
        final result = Platform.isWindows
            ? await Process.run('cmd', [
                '/d',
                '/c',
                'mklink',
                '/H',
                path.normalize(other.path),
                path.normalize(source.path),
              ])
            : await Process.run('ln', [source.path, other.path]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(await FileSystemEntity.identical(source.path, other.path), true);
        final service = BackupService(other);
        await expectLater(
          repo.activateSyncCapture(
            workspaceId: first.workspace,
            accountId: first.account,
            deviceId: first.device,
            recovery: service,
          ),
          throwsStateError,
        );
        expect((await repo.syncExchangeStatus()).binding, isNull);
        expect(await service.list(), isEmpty);
        expect((await repo.tasks()).single.title, 'Synthetic WAL sentinel');
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );
}
