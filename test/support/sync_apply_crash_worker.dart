import 'dart:io';

import 'package:drift/native.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';

class _InterruptedApply extends AppDatabase {
  _InterruptedApply(super.executor, this.marker, this.stop);
  final File marker;
  final String stop;
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    await super.customStatement(statement, args);
    if ((stop == 'rows' && statement.startsWith('INSERT INTO "tasks"')) ||
        (stop == 'materialized' &&
            statement.startsWith(
              'UPDATE sync_mutation_groups SET materialized=1',
            ))) {
      await marker.writeAsString('uncommitted remote apply', flush: true);
      await Future<void>.delayed(const Duration(minutes: 2));
      throw StateError('Parent did not terminate its owned synthetic worker');
    }
  }
}

Future<void> main(List<String> args) async {
  final db = _InterruptedApply(
    NativeDatabase(
      File(args[0]),
      setup: (raw) {
        raw.execute('PRAGMA busy_timeout=5000');
        raw.execute('PRAGMA journal_mode=WAL');
      },
    ),
    File(args[1]),
    args[2],
  );
  try {
    final context = await db
        .customSelect('SELECT * FROM sync_capture_context')
        .getSingle();
    final binding = SyncBinding(
      workspace: context.read<String>('workspace_id'),
      account: context.read<String>('account_id'),
      device: context.read<String>('device_id'),
    );
    final repository = LifeRepository(db);
    final lease = (await repository.acquireSyncLease(binding))!;
    final result = await repository.applyNextSyncGroup(binding, lease: lease);
    throw StateError(
      'Synthetic apply did not reach the requested barrier: ${result.reason}',
    );
  } finally {
    await db.close();
  }
}
