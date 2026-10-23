import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:crypto/crypto.dart';

enum BackupKind { automatic, beforeUpgrade, beforeRestore, manual }

class BackupRecord {
  const BackupRecord({
    required this.file,
    required this.kind,
    required this.createdAt,
    required this.bytes,
    required this.schemaVersion,
  });
  final File file;
  final BackupKind kind;
  final DateTime createdAt;
  final int bytes;
  final int schemaVersion;
}

/// Creates standalone, integrity-checked SQLite snapshots through VACUUM INTO.
/// It never copies a live WAL file or removes user-created backup files.
class BackupService {
  BackupService(this.databaseFile);
  final File databaseFile;
  static const automaticRetention = 14;
  static final _managedName = RegExp(
    r'^(auto|before-upgrade|before-restore|manual)-\d{8}T\d{6}\d{6}Z\.sqlite$',
  );

  File get _restoreMarker =>
      File(path.join(databaseFile.parent.path, 'pending-restore.json'));

  Directory get backupDirectory =>
      Directory(path.join(databaseFile.parent.path, 'backups'));

  Future<List<BackupRecord>> list() async {
    if (!await backupDirectory.exists()) return [];
    final files = await backupDirectory
        .list(followLinks: false)
        .where(
          (item) =>
              item is File && _managedName.hasMatch(path.basename(item.path)),
        )
        .cast<File>()
        .toList();
    final result = <BackupRecord>[];
    for (final file in files) {
      final name = path.basename(file.path);
      final kind = name.startsWith('auto-')
          ? BackupKind.automatic
          : name.startsWith('before-upgrade-')
          ? BackupKind.beforeUpgrade
          : name.startsWith('before-restore-')
          ? BackupKind.beforeRestore
          : BackupKind.manual;
      final stat = await file.stat();
      final filename = file.path;
      int schema;
      try {
        schema = await Isolate.run(() => _inspectSnapshot(filename));
      } catch (_) {
        schema = -1;
      }
      result.add(
        BackupRecord(
          file: file,
          kind: kind,
          createdAt: _timeFromFilename(name),
          bytes: stat.size,
          schemaVersion: schema,
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<BackupRecord?> ensureAutomaticBackup({
    required int appSchemaVersion,
    DateTime? now,
  }) async {
    if (!await databaseFile.exists()) return null;
    final current = now?.toUtc() ?? DateTime.now().toUtc();
    final sourcePath = databaseFile.path;
    final databaseSchema = await Isolate.run(
      () => _inspectSnapshot(sourcePath),
    );
    if (databaseSchema > appSchemaVersion) {
      throw StateError(
        'Database schema $databaseSchema is newer than this app',
      );
    }
    if (databaseSchema < appSchemaVersion) {
      return createBackup(BackupKind.beforeUpgrade, now: current);
    }
    final recent = (await list()).where(
      (item) =>
          item.kind == BackupKind.automatic &&
          item.schemaVersion >= 0 &&
          current.difference(item.createdAt) < const Duration(hours: 24),
    );
    if (recent.isNotEmpty) return null;
    return createBackup(BackupKind.automatic, now: current);
  }

  Future<BackupRecord> createBackup(BackupKind kind, {DateTime? now}) async {
    if (!await databaseFile.exists()) {
      throw StateError('There is no database to back up');
    }
    await backupDirectory.create(recursive: true);
    final instant = now?.toUtc() ?? DateTime.now().toUtc();
    final stamp = _stamp(instant);
    final prefix = switch (kind) {
      BackupKind.automatic => 'auto',
      BackupKind.beforeUpgrade => 'before-upgrade',
      BackupKind.beforeRestore => 'before-restore',
      BackupKind.manual => 'manual',
    };
    final destination = File(
      path.join(backupDirectory.path, '$prefix-$stamp.sqlite'),
    );
    final temporary = File('${destination.path}.tmp');
    if (await destination.exists() || await temporary.exists()) {
      throw StateError('Backup name already exists');
    }
    try {
      final sourcePath = databaseFile.path;
      final temporaryPath = temporary.path;
      final schema = await Isolate.run(
        () => _writeSnapshot(sourcePath, temporaryPath),
      );
      await Isolate.run(() => _validateLifeManagerSnapshot(temporaryPath));
      await temporary.rename(destination.path);
      if (kind == BackupKind.automatic) await _pruneAutomatic();
      final stat = await destination.stat();
      return BackupRecord(
        file: destination,
        kind: kind,
        createdAt: instant,
        bytes: stat.size,
        schemaVersion: schema,
      );
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  /// Publishes a consistent, standalone SQLite export at a user-chosen path.
  /// An existing file is never intentionally replaced.
  Future<File> exportTo(File destination) async {
    if (!await databaseFile.exists()) {
      throw StateError('There is no database to export');
    }
    if (path.extension(destination.path).toLowerCase() != '.sqlite') {
      throw ArgumentError('Choose a .sqlite filename');
    }
    if (!await destination.parent.exists()) {
      throw StateError('The export folder does not exist');
    }
    final temporary = File('${destination.path}.life-manager-tmp');
    if (await destination.exists() || await temporary.exists()) {
      throw StateError('The export filename already exists');
    }
    try {
      final sourcePath = databaseFile.path;
      final temporaryPath = temporary.path;
      await Isolate.run(() => _writeSnapshot(sourcePath, temporaryPath));
      await Isolate.run(() => _validateLifeManagerSnapshot(temporaryPath));
      if (await destination.exists()) {
        throw StateError('The export filename was created by another process');
      }
      await temporary.rename(destination.path);
      return destination;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  /// Stages an external SQLite file as a verified managed snapshot. The live
  /// database is changed only by the reviewed next-launch restore flow.
  Future<BackupRecord> importSnapshot(
    File source, {
    required int appSchemaVersion,
  }) async {
    if (!await source.exists()) throw StateError('Import file is missing');
    await backupDirectory.create(recursive: true);
    final instant = DateTime.now().toUtc();
    final destination = File(
      path.join(backupDirectory.path, 'manual-${_stamp(instant)}.sqlite'),
    );
    final temporary = File('${destination.path}.tmp');
    if (await destination.exists() || await temporary.exists()) {
      throw StateError('An import with this timestamp already exists');
    }
    try {
      final sourcePath = source.path;
      final temporaryPath = temporary.path;
      final schema = await Isolate.run(
        () => _writeSnapshot(sourcePath, temporaryPath),
      );
      if (schema < 1 || schema > appSchemaVersion) {
        throw StateError('Import schema $schema is unsupported');
      }
      await Isolate.run(() => _validateLifeManagerSnapshot(temporaryPath));
      if (await destination.exists()) {
        throw StateError('Import name was created by another process');
      }
      await temporary.rename(destination.path);
      final stat = await destination.stat();
      return BackupRecord(
        file: destination,
        kind: BackupKind.manual,
        createdAt: instant,
        bytes: stat.size,
        schemaVersion: schema,
      );
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<void> _pruneAutomatic() async {
    final records = (await list())
        .where((item) => item.kind == BackupKind.automatic)
        .toList();
    for (final stale in records.skip(automaticRetention)) {
      await stale.file.delete();
    }
  }

  Future<String?> pendingRestoreName() async {
    if (!await _restoreMarker.exists()) return null;
    final marker = jsonDecode(await _restoreMarker.readAsString()) as Map;
    return marker['filename'] as String;
  }

  Future<bool> hasScheduledRestore() => _restoreMarker.exists();

  Future<void> scheduleRestore(
    BackupRecord selected, {
    required int appSchemaVersion,
  }) async {
    if (await _restoreMarker.exists()) {
      throw StateError('A restore is already scheduled. Cancel it first.');
    }
    final filename = path.basename(selected.file.path);
    if (!_managedName.hasMatch(filename) ||
        path.normalize(selected.file.absolute.path).toLowerCase() !=
            path
                .normalize(path.join(backupDirectory.absolute.path, filename))
                .toLowerCase()) {
      throw ArgumentError(
        'Select a managed backup in the Todorbit backup folder',
      );
    }
    final selectedPath = selected.file.path;
    final verifiedSchema = await Isolate.run(
      () => _inspectSnapshot(selectedPath),
    );
    await Isolate.run(() => _validateLifeManagerSnapshot(selectedPath));
    if (verifiedSchema < 1 ||
        verifiedSchema > appSchemaVersion ||
        verifiedSchema != selected.schemaVersion) {
      throw StateError('Backup schema is unsupported or changed');
    }
    final stat = await selected.file.stat();
    if (stat.size != selected.bytes) {
      throw StateError('Backup changed. Reload the list.');
    }
    final digest = await Isolate.run(() => _hashFile(selectedPath));
    final temporary = File('${_restoreMarker.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(
      jsonEncode({
        'filename': filename,
        'bytes': stat.size,
        'modified_us': stat.modified.toUtc().microsecondsSinceEpoch,
        'schema': verifiedSchema,
        'sha256': digest,
      }),
      flush: true,
    );
    await temporary.rename(_restoreMarker.path);
  }

  Future<void> cancelScheduledRestore() async {
    if (await _restoreMarker.exists()) await _restoreMarker.delete();
  }

  /// Call before opening Drift. The caller first closes the native widget.
  Future<BackupRecord?> applyScheduledRestore({
    required int appSchemaVersion,
  }) async {
    if (!await _restoreMarker.exists()) return null;
    final marker = (jsonDecode(await _restoreMarker.readAsString()) as Map)
        .cast<String, dynamic>();
    final filename = marker['filename'] as String;
    if (!_managedName.hasMatch(filename) ||
        path.basename(filename) != filename) {
      throw StateError('Invalid restore marker');
    }
    final snapshot = File(path.join(backupDirectory.path, filename));
    if (!await snapshot.exists()) {
      throw StateError('Scheduled backup is missing');
    }
    final stat = await snapshot.stat();
    if (stat.size != marker['bytes'] ||
        stat.modified.toUtc().microsecondsSinceEpoch != marker['modified_us']) {
      throw StateError('Scheduled backup changed after review');
    }
    final snapshotPath = snapshot.path;
    final digest = await Isolate.run(() => _hashFile(snapshotPath));
    if (digest != marker['sha256']) {
      throw StateError('Scheduled backup content changed after review');
    }
    final sourceSchema = await Isolate.run(
      () => _inspectSnapshot(snapshotPath),
    );
    await Isolate.run(() => _validateLifeManagerSnapshot(snapshotPath));
    if (sourceSchema != marker['schema'] ||
        sourceSchema < 1 ||
        sourceSchema > appSchemaVersion) {
      throw StateError('Scheduled backup schema is unsupported or changed');
    }
    final rollback = await createBackup(BackupKind.beforeRestore);
    final targetPath = databaseFile.path;
    await Isolate.run(() => _restoreSnapshot(snapshotPath, targetPath));
    final restoredSchema = await Isolate.run(
      () => _inspectSnapshot(targetPath),
    );
    if (restoredSchema != sourceSchema) {
      throw StateError('Restored database failed schema verification');
    }
    await _restoreMarker.delete();
    return rollback;
  }
}

DateTime _timeFromFilename(String name) {
  final value = name.substring(
    name.lastIndexOf('-') + 1,
    name.length - '.sqlite'.length,
  );
  final microseconds = int.parse(value.substring(15, 21));
  return DateTime.utc(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(4, 6)),
    int.parse(value.substring(6, 8)),
    int.parse(value.substring(9, 11)),
    int.parse(value.substring(11, 13)),
    int.parse(value.substring(13, 15)),
    microseconds ~/ 1000,
    microseconds % 1000,
  );
}

String _stamp(DateTime instant) =>
    '${instant.year.toString().padLeft(4, '0')}'
    '${instant.month.toString().padLeft(2, '0')}'
    '${instant.day.toString().padLeft(2, '0')}T'
    '${instant.hour.toString().padLeft(2, '0')}'
    '${instant.minute.toString().padLeft(2, '0')}'
    '${instant.second.toString().padLeft(2, '0')}'
    '${(instant.millisecond * 1000 + instant.microsecond).toString().padLeft(6, '0')}Z';

void _validateLifeManagerSnapshot(String filePath) {
  final connection = sqlite.sqlite3.open(
    filePath,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    final schema =
        connection.select('PRAGMA user_version').single.values.single as int;
    if (schema < 1) {
      throw StateError('Snapshot is not a Todorbit database');
    }
    final names = connection
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((row) => row['name'] as String)
        .toSet();
    final required = <String>{'tasks', 'categories', 'projects'};
    if (schema >= 2) {
      required.add('fixed_events');
    }
    if (schema >= 21) {
      required.add('event_detail_types');
    }
    if (schema >= 3) {
      required.add('work_sessions');
    }
    if (schema >= 4) {
      required.addAll({
        'availability_windows',
        'availability_exceptions',
        'scheduling_operations',
        'scheduling_changes',
      });
    }
    if (schema >= 5) {
      required.addAll({
        'task_sequences',
        'sequence_tasks',
        'task_dependencies',
      });
    }
    if (schema >= 6) {
      required.addAll({'recurrence_series', 'recurrence_occurrences'});
    }
    if (schema >= 7) {
      required.addAll({'series_edit_history', 'recurrence_collision_history'});
    }
    if (schema >= 8) {
      required.addAll({
        'habits',
        'habit_entries',
        'habit_rest_days',
        'habit_entry_history',
      });
    }
    if (schema >= 9) {
      required.addAll({
        'goals',
        'goal_milestones',
        'goal_progress_entries',
        'goal_task_links',
        'goal_project_links',
        'goal_habit_links',
      });
    }
    if (schema >= 10) {
      required.addAll({'timer_runs', 'time_entries', 'time_entry_history'});
    }
    if (schema >= 11) {
      required.add('templates');
    }
    if (schema >= 12) {
      required.add('saved_views');
    }
    if (schema >= 13) {
      required.add('deletion_tombstones');
    }
    if (schema >= 14) {
      required.addAll({'notification_settings', 'notification_deliveries'});
    }
    if (schema >= 15) required.add('task_resources');
    if (schema >= 16) required.add('event_occurrence_changes');
    if (schema >= 17) required.add('entity_icons');
    if (schema >= 18) {
      required.add('task_parent_links');
      required.add('task_checklist');
    }
    if (schema >= 19) {
      required.addAll({
        'progressive_plans',
        'progressive_plan_steps',
        'progressive_plan_assignments',
      });
    }
    if (!names.containsAll(required)) {
      throw StateError('Snapshot is not a Todorbit database');
    }
    if (connection.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Snapshot has broken record relationships');
    }
    if (schema >= 15) {
      if (connection
          .select(
            "SELECT 1 FROM task_resources WHERE kind='managed' AND length(content)>16777216 LIMIT 1",
          )
          .isNotEmpty) {
        throw StateError('Snapshot has an oversized managed attachment');
      }
      if (schema >= 20) required.add('event_reminder_deliveries');
      final statement = connection.prepare(
        "SELECT id, byte_size, sha256, original_name, content FROM task_resources WHERE kind='managed'",
      );
      try {
        final cursor = statement.selectCursor();
        while (cursor.moveNext()) {
          final row = cursor.current;
          final bytes = row['content'] as List<int>;
          final originalName = row['original_name'] as String;
          if (originalName.isEmpty ||
              originalName == '.' ||
              originalName == '..' ||
              RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(originalName)) {
            throw StateError('Snapshot has an unsafe attachment filename');
          }
          if (bytes.length != row['byte_size'] ||
              sha256.convert(bytes).toString() != row['sha256']) {
            throw StateError('Snapshot has a damaged managed attachment');
          }
        }
      } finally {
        statement.close();
      }
    }
  } finally {
    connection.close();
  }
}

int _inspectSnapshot(String sourcePath) {
  final connection = sqlite.sqlite3.open(
    sourcePath,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    final result = connection.select('PRAGMA quick_check');
    if (result.length != 1 || result.single.values.single != 'ok') {
      throw StateError('SQLite integrity check failed for $sourcePath');
    }
    return connection.select('PRAGMA user_version').single.values.single as int;
  } finally {
    connection.close();
  }
}

int _writeSnapshot(String sourcePath, String destinationPath) {
  final source = sqlite.sqlite3.open(
    sourcePath,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    final result = source.select('PRAGMA quick_check');
    if (result.length != 1 || result.single.values.single != 'ok') {
      throw StateError('Source database integrity check failed');
    }
    final escaped = destinationPath.replaceAll("'", "''");
    source.execute("VACUUM INTO '$escaped'");
  } finally {
    source.close();
  }
  return _inspectSnapshot(destinationPath);
}

Future<void> _restoreSnapshot(String snapshotPath, String targetPath) async {
  final source = sqlite.sqlite3.open(
    snapshotPath,
    mode: sqlite.OpenMode.readOnly,
  );
  final target = sqlite.sqlite3.open(targetPath);
  try {
    target.execute('PRAGMA busy_timeout=0');
    target.execute('PRAGMA locking_mode=EXCLUSIVE');
    target.select('PRAGMA quick_check');
    await source.backup(target, nPage: -1).drain<void>();
  } finally {
    target.close();
    source.close();
  }
}

Future<String> _hashFile(String filePath) async =>
    (await sha256.bind(File(filePath).openRead()).first).toString();
