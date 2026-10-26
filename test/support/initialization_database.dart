import 'dart:async';

import 'package:life_manager/data/app_database.dart';

/// Fault injection belongs in the test executor, never in the application.
class InitializationDatabase extends AppDatabase {
  InitializationDatabase(
    super.executor, {
    required this.checkpoint,
    this.atomic = true,
  });

  final FutureOr<void> Function(int count, String sql) checkpoint;
  final bool atomic;
  int statements = 0;

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    await super.customStatement(statement, args);
    await checkpoint(++statements, statement);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) => atomic ? super.transaction(action, requireNew: requireNew) : action();
}
