import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';

import 'initialization_database.dart';

/// A real child process is terminated by the parent while SQLite owns a WAL
/// transaction, including after user_version but before COMMIT.
Future<void> main(List<String> args) async {
  final database = InitializationDatabase(
    NativeDatabase(
      File(args[0]),
      setup: (db) => db.execute('PRAGMA journal_mode=WAL'),
    ),
    checkpoint: (count, sql) async {
      if (args[2] == '$count' ||
          (args[2] == 'version' && sql.startsWith('PRAGMA user_version'))) {
        await File(args[1]).writeAsString('transaction paused', flush: true);
        await Future<void>.delayed(const Duration(minutes: 2));
        throw StateError('Parent did not terminate the interrupted worker');
      }
    },
  );
  try {
    await database.customSelect('SELECT 1').get();
    throw StateError('The requested checkpoint was not reached');
  } finally {
    await database.close();
  }
}
