import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  static Future<AppDatabase> openDefault() async {
    final String basePath;
    if (Platform.isWindows) {
      basePath =
          Platform.environment['APPDATA'] ??
          (throw StateError('Windows APPDATA directory is unavailable'));
    } else {
      final home = Platform.environment['HOME'];
      basePath =
          Platform.environment['XDG_DATA_HOME'] ??
          (home == null
              ? throw StateError('User data directory is unavailable')
              : path.join(home, '.local', 'share'));
    }
    final directory = Directory(path.join(basePath, 'Life Manager'));
    await directory.create(recursive: true);
    final file = File(path.join(directory.path, 'life_manager.sqlite'));
    return AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON');
          database.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await customStatement('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL COLLATE NOCASE UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE projects (
          id TEXT PRIMARY KEY,
          category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(category_id, name)
        )
      ''');
      await customStatement('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL CHECK(length(trim(title)) > 0),
          notes TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL CHECK(status IN ('notStarted','inProgress','waiting','onHold','completed','cancelled')),
          priority INTEGER NOT NULL DEFAULT 0 CHECK(priority BETWEEN 0 AND 3),
          category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
          project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
          scheduled_date TEXT,
          deadline_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          completed_at TEXT
        )
      ''');
      await customStatement(
        'CREATE INDEX tasks_status_schedule ON tasks(status, scheduled_date)',
      );
      await customStatement(
        'CREATE INDEX tasks_deadline ON tasks(deadline_date)',
      );
      await customStatement('CREATE INDEX tasks_project ON tasks(project_id)');
      await customStatement(
        'CREATE INDEX tasks_category ON tasks(category_id)',
      );
      await customStatement(
        'CREATE INDEX projects_category ON projects(category_id)',
      );
    },
    onUpgrade: (migrator, from, to) async {
      throw StateError('No migration registered from schema $from to $to');
    },
  );
}
