import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:crypto/crypto.dart';

import 'widget_configuration_store.dart';
import '../domain/notifications.dart';

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

class BackupSummary {
  const BackupSummary(this.counts);
  final Map<String, int> counts;

  String get description => counts.entries
      .where((entry) => entry.value > 0)
      .map((entry) => '${entry.value} ${entry.key}')
      .join(' · ');
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

  File get _restoreStatus =>
      File(path.join(databaseFile.parent.path, 'restore-status.json'));

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
        () => _writeSnapshot(sourcePath, temporaryPath, includeWidgets: false),
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

  Future<String?> restoreStatus() async {
    if (!await _restoreStatus.exists()) return null;
    try {
      final data = jsonDecode(await _restoreStatus.readAsString());
      if (data is! Map ||
          data['state'] != 'opened' ||
          data['backup'] is! String) {
        return null;
      }
      return 'The selected backup was restored and its database opened successfully.';
    } catch (_) {
      return null;
    }
  }

  Future<void> markRestoreOpened() async {
    if (!await _restoreStatus.exists()) return;
    final data = jsonDecode(await _restoreStatus.readAsString());
    if (data is! Map ||
        data['state'] != 'applied' ||
        data['backup'] is! String) {
      return;
    }
    await _restoreStatus.writeAsString(
      jsonEncode({
        'state': 'opened',
        'backup': data['backup'],
        'openedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }

  /// Personalization from a cloud restore is applied only after the replaced
  /// database has opened and migrated. Credentials and privacy stay local.
  Future<String?> restoredPortableSettings() async {
    if (!await _restoreStatus.exists()) return null;
    final data = jsonDecode(await _restoreStatus.readAsString());
    if (data is Map && data['state'] == 'applied') {
      return data['portableSettings'] as String?;
    }
    return null;
  }

  Future<BackupSummary> summarize(BackupRecord selected) async {
    final filePath = selected.file.path;
    return Isolate.run(() => _summarizeSnapshot(filePath));
  }

  Future<void> scheduleRestore(
    BackupRecord selected, {
    required int appSchemaVersion,
    String? portableSettings,
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
        'portableSettings': ?portableSettings,
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
    final widgetBundle = await Isolate.run(
      () => _snapshotWidgets(snapshotPath),
    );
    if (widgetBundle != null) {
      WidgetConfigurationStore.validateBundle(widgetBundle);
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
    if (widgetBundle != null) {
      await WidgetConfigurationStore(databaseFile.parent)
          .importBundle(widgetBundle);
    }
    await _restoreStatus.writeAsString(
      jsonEncode({
        'state': 'applied',
        'backup': filename,
        if (marker['portableSettings'] != null)
          'portableSettings': marker['portableSettings'],
      }),
      flush: true,
    );
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
    if (schema >= 22) {
      required.add('task_reminder_deliveries');
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
    if (schema >= 20) required.add('event_reminder_deliveries');
    if (!names.containsAll(required)) {
      throw StateError('Snapshot is not a Todorbit database');
    }
    if (connection.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Snapshot has broken record relationships');
    }
    if (schema >= 22) {
      final columns = connection
          .select('PRAGMA table_info(tasks)')
          .map((r) => r['name']);
      if (!columns.contains('notification_json')) {
        throw StateError('Missing task notification configuration');
      }
      for (final row in connection.select(
        'SELECT notification_json FROM tasks',
      )) {
        TaskNotification.fromJson(
          jsonDecode(row['notification_json'] as String)
              as Map<String, dynamic>,
        );
      }
    }
    if (schema >= 15) {
      if (connection
          .select(
            "SELECT 1 FROM task_resources WHERE kind='managed' AND length(content)>16777216 LIMIT 1",
          )
          .isNotEmpty) {
        throw StateError('Snapshot has an oversized managed attachment');
      }
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

int _writeSnapshot(
  String sourcePath,
  String destinationPath, {
  bool includeWidgets = true,
}) {
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
  if (!includeWidgets) return _inspectSnapshot(destinationPath);
  final bundle = WidgetConfigurationStore(Directory(path.dirname(sourcePath)))
      .exportBundle();
  final snapshot = sqlite.sqlite3.open(destinationPath);
  try {
    snapshot.execute(
      'CREATE TABLE IF NOT EXISTS backup_widget_personalization (id INTEGER PRIMARY KEY CHECK(id=1),json TEXT NOT NULL)',
    );
    snapshot.execute(
      'INSERT OR REPLACE INTO backup_widget_personalization VALUES(1,?)',
      [jsonEncode(bundle)],
    );
  } finally {
    snapshot.close();
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
    // The envelope table belongs to the snapshot, not the planner schema.
    target.execute('DROP TABLE IF EXISTS backup_widget_personalization');
  } finally {
    target.close();
    source.close();
  }
}

BackupSummary _summarizeSnapshot(String snapshotPath) {
  _validateLifeManagerSnapshot(snapshotPath);
  final database = sqlite.sqlite3.open(
    snapshotPath,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    final tables = database
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((row) => row['name'] as String)
        .toSet();
    final counts = <String, int>{};
    for (final (table, label) in <(String, String)>[
      ('tasks', 'tasks'),
      ('fixed_events', 'events'),
      ('categories', 'categories'),
      ('projects', 'projects'),
      ('habits', 'habits'),
      ('goals', 'goals'),
      ('work_sessions', 'work sessions'),
      ('recurrence_series', 'task recurrence series'),
    ]) {
      if (tables.contains(table)) {
        counts[label] =
            database
                    .select('SELECT COUNT(*) AS count FROM $table')
                    .single['count']
                as int;
      }
    }
    return BackupSummary(counts);
  } finally {
    database.close();
  }
}

Future<String> _hashFile(String filePath) async =>
    (await sha256.bind(File(filePath).openRead()).first).toString();

Map<String, dynamic>? _snapshotWidgets(String filename) {
  final db = sqlite.sqlite3.open(filename, mode: sqlite.OpenMode.readOnly);
  try {
    if (db
        .select(
          "SELECT name FROM sqlite_master WHERE name='backup_widget_personalization'",
        )
        .isEmpty) {
      return null;
    }
    final rows = db.select(
      'SELECT json FROM backup_widget_personalization WHERE id=1',
    );
    if (rows.isEmpty) return null;
    final raw = rows.single['json'] as String;
    if (utf8.encode(raw).length > 1200 * 1024) {
      throw const FormatException('Widget personalization too large');
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  } finally {
    db.close();
  }
}
