import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/migration_gate.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// A separate isolate releases the real SQLite lock even when the foreground
// schema probe is blocked inside SQLite's synchronous busy handler.
Future<void> holdLock((String, SendPort) args) async {
  final commands = ReceivePort();
  final database = sqlite.sqlite3.open(args.$1);
  try {
    database.execute('BEGIN EXCLUSIVE');
    args.$2.send(commands.sendPort);
    await for (final command in commands) {
      if (command is int) {
        await Future<void>.delayed(Duration(milliseconds: command));
      }
      break;
    }
  } finally {
    database.execute('ROLLBACK');
    database.close();
    commands.close();
    args.$2.send('released');
  }
}

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('todorbit-contention-');
    file = File('${directory.path}/life.sqlite');
    final database = AppDatabase(NativeDatabase(file));
    try {
      await LifeRepository(database)
          .addTask(const TaskDraft(title: 'Retain committed task'));
    } finally {
      await database.close();
    }
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<void> withLock(Future<void> Function(SendPort) action) async {
    final replies = ReceivePort();
    final messages = StreamIterator<Object?>(replies);
    final worker = await Isolate.spawn(holdLock, (file.path, replies.sendPort));
    try {
      expect(await messages.moveNext(), isTrue);
      final release = messages.current! as SendPort;
      try {
        await action(release);
      } finally {
        release.send('release');
        expect(await messages.moveNext(), isTrue);
        expect(messages.current, 'released');
      }
    } finally {
      await messages.cancel();
      replies.close();
      worker.kill();
    }
  }

  for (final operation in ['schema', 'automatic backup', 'manual backup']) {
    test(
      '$operation waits for brief contention and retains committed data',
      () async {
        await withLock((release) async {
          release.send(700);
          switch (operation) {
            case 'schema':
              expect(await MigrationGate.olderSchema(file), isNull);
            case 'automatic backup':
              expect(
                await BackupService(file).ensureAutomaticBackup(
                  appSchemaVersion: AppDatabase.currentSchemaVersion,
                ),
                isNotNull,
              );
            case 'manual backup':
              await BackupService(file).createBackup(BackupKind.manual);
          }
        });
        final database = AppDatabase(NativeDatabase(file));
        try {
          expect(
            (await LifeRepository(database).tasks()).single.title,
            'Retain committed task',
          );
        } finally {
          await database.close();
        }
        for (final backup in await BackupService(file).list()) {
          final snapshot = sqlite.sqlite3.open(
            backup.file.path,
            mode: sqlite.OpenMode.readOnly,
          );
          try {
            expect(
              snapshot.select('SELECT title FROM tasks').single['title'],
              'Retain committed task',
            );
            expect(
              snapshot.select('PRAGMA quick_check').single.values.single,
              'ok',
            );
          } finally {
            snapshot.close();
          }
        }
      },
    );
  }

  test(
    'persistent contention fails without replacing data or publishing backup',
    () async {
      final original = file.readAsBytesSync();
      await withLock((_) async {
        await expectLater(
          BackupService(file).ensureAutomaticBackup(
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsA(
            isA<sqlite.SqliteException>().having(
              (error) => error.resultCode,
              'resultCode',
              5,
            ),
          ),
        );
      });
      expect(file.readAsBytesSync(), original);
      expect(await BackupService(file).list(), isEmpty);
    },
  );
}
