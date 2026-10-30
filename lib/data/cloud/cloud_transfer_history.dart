import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../backup_service.dart';
import '../profile_fingerprint.dart';

String settingsFingerprint(String settings) {
  Object? ordered(Object? value) => switch (value) {
    Map() => {
      for (final key in value.keys.cast<String>().toList()..sort())
        key: ordered(value[key]),
    },
    List() => value.map(ordered).toList(),
    _ => value,
  };
  return sha256
      .convert(utf8.encode(jsonEncode(ordered(jsonDecode(settings)))))
      .toString();
}

class CloudTransferStatus {
  const CloudTransferStatus({
    this.lastBackup,
    this.lastRestore,
    required this.localChanges,
  });
  final DateTime? lastBackup, lastRestore;
  // Null means there is no trustworthy baseline, never "safe to overwrite".
  final bool? localChanges;
}

class CloudTransferHistory {
  CloudTransferHistory(this.local);
  final BackupService local;
  File get _file => File(
    path.join(local.databaseFile.parent.path, 'cloud-transfer-history.json'),
  );

  Future<Map<String, dynamic>> _read() async {
    if (!await _file.exists()) return {};
    final data = jsonDecode(await _file.readAsString());
    if (data is! Map<String, dynamic> || data['version'] != 1) {
      throw const FormatException('Unsupported cloud transfer history');
    }
    final pending = data['pendingRestore'];
    final completed = await local.completedRestore();
    if (pending is Map && completed?.backup == pending['backup']) {
      data['lastRestore'] = {
        ...pending,
        'at': completed!.openedAt.toUtc().toIso8601String(),
      };
    }
    return data;
  }

  Future<void> record(String key, Map<String, dynamic> receipt) async {
    final data = await _read();
    data['version'] = 1;
    data[key] = receipt;
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(_file.path);
  }

  Future<CloudTransferStatus> status(String settings) async {
    final data = await _read();
    DateTime? time(Object? receipt) =>
        receipt is Map ? DateTime.tryParse('${receipt['at']}') : null;
    final backupTime = time(data['lastBackup']);
    final restoreTime = time(data['lastRestore']);
    final baseline =
        restoreTime != null &&
            (backupTime == null || restoreTime.isAfter(backupTime))
        ? data['lastRestore']
        : data['lastBackup'];
    return CloudTransferStatus(
      lastBackup: backupTime,
      lastRestore: restoreTime,
      localChanges: baseline is! Map
          ? null
          : baseline['database'] !=
                    await databaseFingerprint(local.databaseFile.path) ||
                baseline['settings'] != settingsFingerprint(settings),
    );
  }
}
