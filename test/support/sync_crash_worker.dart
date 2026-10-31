import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

// The parent supplies a disposable profile and kills this owned process tree
// after a durable barrier. No production key is read or printed.
Future<void> main(List<String> args) async {
  final db = AppDatabase(
    NativeDatabase(
      File(args[0]),
      setup: (raw) => raw.execute('PRAGMA journal_mode=WAL'),
    ),
  );
  final repository = LifeRepository(db);
  final marker = File(args[1]);
  Future<void> pause(Object value) async {
    await marker.writeAsString(jsonEncode(value), flush: true);
    await Future<void>.delayed(const Duration(minutes: 2));
    throw StateError('Parent did not terminate its synthetic worker');
  }

  try {
    if (args[2] == 'uncommitted') {
      await db.transaction(() async {
        await repository.addTask(
          const TaskDraft(title: 'Uncommitted synthetic action'),
        );
        await pause({'barrier': 'uncommitted'});
      });
    } else {
      final context = await db
          .customSelect('SELECT * FROM sync_capture_context')
          .getSingle();
      final binding = SyncBinding(
        workspace: context.read<String>('workspace_id'),
        account: context.read<String>('account_id'),
        device: context.read<String>('device_id'),
      );
      final key = SyncWorkspaceKey.fromRecoveryCode(
        Platform.environment['TODORBIT_SYNTHETIC_SYNC_KEY']!,
      );
      final batch = (await repository.prepareNextSyncBatch(binding, key))!;
      await pause({
        'barrier': 'staged',
        'batch': batch.id,
        'sha256': batch.sha256,
        'bytes': base64Encode(batch.bytes),
      });
    }
  } finally {
    await db.close();
  }
}
