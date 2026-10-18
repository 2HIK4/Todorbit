import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite;

enum BackupKind { automatic, beforeUpgrade, manual }

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
    r'^(auto|before-upgrade|manual)-\d{8}T\d{6}\d{6}Z\.sqlite$',
  );

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
    final stamp =
        '${instant.year.toString().padLeft(4, '0')}'
        '${instant.month.toString().padLeft(2, '0')}'
        '${instant.day.toString().padLeft(2, '0')}T'
        '${instant.hour.toString().padLeft(2, '0')}'
        '${instant.minute.toString().padLeft(2, '0')}'
        '${instant.second.toString().padLeft(2, '0')}'
        '${(instant.millisecond * 1000 + instant.microsecond).toString().padLeft(6, '0')}Z';
    final prefix = switch (kind) {
      BackupKind.automatic => 'auto',
      BackupKind.beforeUpgrade => 'before-upgrade',
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

  Future<void> _pruneAutomatic() async {
    final records = (await list())
        .where((item) => item.kind == BackupKind.automatic)
        .toList();
    for (final stale in records.skip(automaticRetention)) {
      await stale.file.delete();
    }
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
