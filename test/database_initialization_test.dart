import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/migration_gate.dart';
import 'package:life_manager/domain/models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'support/initialization_database.dart';

List<Map<String, Object?>> schema(sqlite.Database db) => db
    .select(
      "SELECT type,name,tbl_name,sql FROM sqlite_schema "
      "WHERE name NOT GLOB 'sqlite_*' ORDER BY type,name",
    )
    .map((row) => Map<String, Object?>.from(row))
    .toList();

void legacyDatabase(File file) {
  final db = sqlite.sqlite3.open(file.path);
  try {
    db.execute('''CREATE TABLE categories (
      id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    db.execute('''CREATE TABLE projects (
      id TEXT PRIMARY KEY, category_id TEXT NOT NULL, name TEXT NOT NULL,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    db.execute('''CREATE TABLE tasks (
      id TEXT PRIMARY KEY, title TEXT NOT NULL, notes TEXT NOT NULL,
      status TEXT NOT NULL, priority INTEGER NOT NULL, category_id TEXT,
      project_id TEXT, scheduled_date TEXT, deadline_date TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL, completed_at TEXT
    )''');
    db.execute('''INSERT INTO tasks VALUES(
      'legacy-id','Keep me','','notStarted',0,NULL,NULL,NULL,NULL,
      '2026-10-16T00:00:00.000Z','2026-10-16T00:00:00.000Z',NULL)''');
    db.execute('PRAGMA user_version=1');
  } finally {
    db.close();
  }
}

Future<void> openAndVerify(File file, {bool legacy = false}) async {
  final db = AppDatabase(NativeDatabase(file));
  try {
    final tasks = await LifeRepository(db).tasks();
    expect(tasks.map((task) => task.title), legacy ? ['Keep me'] : isEmpty);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      AppDatabase.currentSchemaVersion,
    );
    expect(
      (await db
              .customSelect(
                "SELECT name FROM sqlite_schema WHERE type='table' "
                "AND name NOT GLOB 'sqlite_*'",
              )
              .get())
          .length,
      44,
    );
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
  } finally {
    await db.close();
  }
}

Future<void> makeOldPartial(File file, int stop) async {
  final db = InitializationDatabase(
    NativeDatabase(file),
    atomic:
        false, // Reproduce the old autocommit initialization, only in tests.
    checkpoint: (count, _) {
      if (count == stop) throw StateError('simulated old initialization stop');
    },
  );
  try {
    await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
  } finally {
    await db.close();
  }
}

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('todorbit-init-');
    file = File('${directory.path}/life.sqlite');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'fresh and zero-byte files create complete persistent databases',
    () async {
      expect(await MigrationGate.olderSchema(file), isNull);
      await openAndVerify(file);
      await openAndVerify(file);
      final zero = File('${directory.path}/zero.sqlite')..writeAsBytesSync([]);
      expect(await MigrationGate.olderSchema(zero), 0);
      await openAndVerify(zero);
    },
  );

  for (final stop in [1, 8, 35, 75]) {
    test(
      'old empty partial schema at statement $stop completes safely',
      () async {
        await makeOldPartial(file, stop);
        expect(await MigrationGate.olderSchema(file), 0);
        await openAndVerify(file);
        await openAndVerify(file);
      },
    );
  }

  test(
    'populated schema zero is rejected with rows and schema unchanged',
    () async {
      await makeOldPartial(file, 3);
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute(
        "INSERT INTO categories VALUES('keep','Preserve me','now','now')",
      );
      final original = schema(raw);
      raw.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      } finally {
        await db.close();
      }
      final verify = sqlite.sqlite3.open(file.path);
      try {
        expect(schema(verify), original);
        expect(
          verify.select('SELECT name FROM categories').single['name'],
          'Preserve me',
        );
        expect(verify.userVersion, 0);
      } finally {
        verify.close();
      }
    },
  );

  for (final extra in [
    'CREATE TABLE unexpected(id TEXT)',
    'CREATE TABLE sqlitecustom(id TEXT)',
    'CREATE VIEW unexpected AS SELECT 1',
    'CREATE TRIGGER unexpected AFTER INSERT ON categories BEGIN SELECT 1; END',
    'ALTER TABLE categories ADD COLUMN unexpected TEXT',
  ]) {
    test('incompatible empty schema rolls back every repair: $extra', () async {
      await makeOldPartial(file, 3);
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute(extra);
      final original = schema(raw);
      raw.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      } finally {
        await db.close();
      }
      final verify = sqlite.sqlite3.open(file.path);
      try {
        expect(schema(verify), original);
        expect(verify.userVersion, 0);
      } finally {
        verify.close();
      }
    });
  }

  test(
    'sqlite-like user table cannot bypass populated schema detection',
    () async {
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('CREATE TABLE sqlitecustom(payload TEXT)');
      raw.execute("INSERT INTO sqlitecustom VALUES('preserve synthetic data')");
      raw.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      } finally {
        await db.close();
      }
      final verify = sqlite.sqlite3.open(file.path);
      try {
        expect(verify.userVersion, 0);
        expect(
          verify.select('SELECT payload FROM sqlitecustom').single['payload'],
          'preserve synthetic data',
        );
      } finally {
        verify.close();
      }
    },
  );

  test('corrupt and future schemas are never reset', () async {
    file.writeAsStringSync('not a SQLite database');
    final original = file.readAsBytesSync();
    await expectLater(
      MigrationGate.olderSchema(file),
      throwsA(isA<sqlite.SqliteException>()),
    );
    expect(file.readAsBytesSync(), original);
    final future = File('${directory.path}/future.sqlite');
    final raw = sqlite.sqlite3.open(future.path);
    raw.execute('PRAGMA user_version=99');
    raw.close();
    await expectLater(MigrationGate.olderSchema(future), throwsStateError);
    final db = AppDatabase(NativeDatabase(future));
    try {
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
    } finally {
      await db.close();
    }
    final verify = sqlite.sqlite3.open(future.path);
    try {
      expect(verify.userVersion, 99);
    } finally {
      verify.close();
    }
  });

  test(
    'existing schema upgrade retains data and Before upgrade snapshot',
    () async {
      legacyDatabase(file);
      expect(await MigrationGate.olderSchema(file), 1);
      final snapshot = await BackupService(file)
          .ensureAutomaticBackup(appSchemaVersion: 21);
      expect(snapshot!.kind, BackupKind.beforeUpgrade);
      await openAndVerify(file, legacy: true);
      final raw = sqlite.sqlite3.open(
        snapshot.file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(raw.userVersion, 1);
        expect(
          raw.select('SELECT title FROM tasks').single['title'],
          'Keep me',
        );
      } finally {
        raw.close();
      }
    },
  );

  for (final upgrading in [false, true]) {
    for (final stop in ['1', '35', 'version']) {
      test(
        'process death during ${upgrading ? 'upgrade' : 'creation'} at $stop is atomic',
        () async {
          if (upgrading) legacyDatabase(file);
          final marker = File('${directory.path}/checkpoint');
          final child = await Process.start('dart', [
            'run',
            'test/support/database_startup_worker.dart',
            file.path,
            marker.path,
            stop,
          ], runInShell: Platform.isWindows);
          final stdout = child.stdout.transform(utf8.decoder).join();
          final stderr = child.stderr.transform(utf8.decoder).join();
          try {
            final deadline = DateTime.now().add(const Duration(seconds: 70));
            while (!marker.existsSync() && DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
            expect(
              marker.existsSync(),
              isTrue,
              reason: 'worker did not reach checkpoint',
            );
          } finally {
            // Windows runInShell starts cmd.exe; terminate its entire owned child
            // tree so the actual Dart process releases its SQLite handles.
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
            await stdout;
            await stderr;
          }
          final raw = sqlite.sqlite3.open(file.path);
          try {
            expect(raw.userVersion, upgrading ? 1 : 0);
            expect(
              raw.select('PRAGMA integrity_check').single.values.single,
              'ok',
            );
            if (upgrading) {
              expect(
                raw.select('SELECT title FROM tasks').single['title'],
                'Keep me',
              );
              expect(raw.select('PRAGMA table_info(tasks)').length, 12);
            } else {
              expect(schema(raw), isEmpty);
            }
          } finally {
            raw.close();
          }
          await openAndVerify(file, legacy: upgrading);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  }

  test('repair itself rolls back on interruption and can be retried', () async {
    await makeOldPartial(file, 8);
    final raw = sqlite.sqlite3.open(file.path);
    final original = schema(raw);
    raw.close();
    final db = InitializationDatabase(
      NativeDatabase(file),
      checkpoint: (count, sql) {
        if (sql.startsWith('PRAGMA user_version')) {
          throw StateError('stop before commit');
        }
      },
    );
    try {
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
    } finally {
      await db.close();
    }
    final verify = sqlite.sqlite3.open(file.path);
    try {
      expect(schema(verify), original);
      expect(verify.userVersion, 0);
    } finally {
      verify.close();
    }
    await openAndVerify(file);
  });

  test(
    'current database reopens without changing schema or planner rows',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await LifeRepository(db)
          .addTask(const TaskDraft(title: 'Keep current data'));
      await db.close();
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await LifeRepository(reopened).tasks()).single.title,
          'Keep current data',
        );
      } finally {
        await reopened.close();
      }
    },
  );
}
