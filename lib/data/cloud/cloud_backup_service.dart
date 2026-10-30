import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../backup_service.dart';
import '../profile_fingerprint.dart';
import 'cloud_backup_codec.dart';
import 'cloud_storage_provider.dart';
import 'cloud_transfer_history.dart';

class CloudRestorePreview {
  const CloudRestorePreview(
    this.manifest,
    this.snapshot,
    this.summary, {
    this.localFingerprint,
    this.localPreferences,
  });
  final Map<String, dynamic> manifest;
  final BackupRecord? snapshot;
  final BackupSummary? summary;
  final String? localFingerprint;
  final String? localPreferences;
}

class CloudBackupService {
  CloudBackupService({
    required this.local,
    required this.provider,
    required this.appVersion,
    CloudBackupCodec? codec,
  }) : codec = codec ?? CloudBackupCodec();
  final BackupService local;
  final CloudStorageProvider provider;
  final CloudBackupCodec codec;
  final String appVersion;
  static final _activeProfiles = <String>{};
  CloudTransferHistory get history => CloudTransferHistory(local);

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final key = path.normalize(local.databaseFile.absolute.path);
    if (!_activeProfiles.add(key)) {
      throw const CloudFailure(
        'Another cloud backup or restore is running for this profile. Wait for it to finish.',
      );
    }
    try {
      return await action();
    } finally {
      _activeProfiles.remove(key);
    }
  }

  Future<String> _profileId() async {
    final file = File(
      path.join(local.databaseFile.parent.path, 'cloud-profile-id'),
    );
    if (await file.exists()) {
      final id = (await file.readAsString()).trim();
      if (Uuid.isValidUUID(fromString: id)) return id;
      throw const CloudFailure('Local cloud profile identifier is invalid.');
    }
    final id = const Uuid().v4();
    await file.writeAsString(id, flush: true);
    return id;
  }

  Future<CloudObject> backUp({
    required CloudBackupKind kind,
    required String settings,
    required String passphrase,
    required CloudProgress progress,
  }) => _exclusive(() async {
    if (await local.hasScheduledRestore()) {
      throw const CloudFailure(
        'A restore is pending. Apply or cancel it before backing up.',
      );
    }
    if (provider.account == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    final accountId = provider.account!.id;
    final id = const Uuid().v4();
    final profileId = await _profileId();
    final manifest = <String, dynamic>{
      'format': 'todorbit-cloud-package',
      'version': 1,
      'id': id,
      'profileId': profileId,
      'appVersion': appVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'kind': kind.name,
      'schema': AppDatabase.currentSchemaVersion,
      'settings': settings,
      'sourcePlatform': Platform.operatingSystem,
    };
    String? fingerprint;
    if (kind == CloudBackupKind.full) {
      progress('Creating verified SQLite snapshot', 0, 0);
      final snapshot = await local.createBackup(BackupKind.manual);
      fingerprint = await databaseFingerprint(snapshot.file.path);
      final summary = await local.summarize(snapshot);
      manifest['counts'] = summary.counts;
      // Bound memory before reading/base64 encoding; the codec enforces the
      // final JSON limit as well. External task-resource files are not bundled.
      if (snapshot.bytes > 50 * 1024 * 1024) {
        throw const CloudFailure(
          'Database exceeds the 50 MiB cloud snapshot limit. Use a local backup.',
        );
      }
      final bytes = await snapshot.file.readAsBytes();
      manifest.addAll({
        'schema': snapshot.schemaVersion,
        'database': base64Encode(bytes),
        'databaseBytes': bytes.length,
        'databaseSha256': sha256.convert(bytes).toString(),
      });
    }
    progress('Encrypting with your recovery passphrase', 0, 0);
    final encrypted = await codec.encrypt(manifest, passphrase);
    if (provider.account?.id != accountId) {
      throw const CloudFailure('Google account changed. Try again.');
    }
    final uploaded = await provider.upload(encrypted, {
      'backupId': id,
      'kind': kind.name,
      'appVersion': appVersion,
      'schema': '${manifest['schema']}',
      'formatVersion': '1',
      'encryption': 'aes256gcm-v1',
      'sourcePlatform': Platform.operatingSystem,
    }, progress);
    if (fingerprint != null) {
      await history.record('lastBackup', {
        'at': DateTime.now().toUtc().toIso8601String(),
        'database': fingerprint,
        'settings': settingsFingerprint(settings),
      });
    }
    return uploaded;
  });

  Future<CloudRestorePreview> preview(
    CloudObject object,
    String passphrase,
    CloudProgress progress,
  ) => _exclusive(() async {
    final fingerprint = await local.databaseFile.exists()
        ? await databaseFingerprint(local.databaseFile.path)
        : null;
    final preferences = await profilePreferencesFingerprint(
      local.databaseFile.parent,
    );
    final bytes = await provider.download(object, progress);
    progress('Decrypting and validating backup', 0, 0);
    final manifest = await codec.decrypt(bytes, passphrase);
    if (manifest['id'] != object.properties['backupId'] ||
        manifest['kind'] != object.kind?.name ||
        manifest['appVersion'] != object.properties['appVersion'] ||
        '${manifest['schema']}' != object.properties['schema']) {
      throw const CloudFailure(
        'Backup manifest does not match the selected cloud object.',
      );
    }
    if (manifest['kind'] == 'settings') {
      return CloudRestorePreview(manifest, null, null);
    }
    final schema = manifest['schema'] as int;
    if (schema < 1 || schema > AppDatabase.currentSchemaVersion) {
      throw const CloudFailure(
        'This database schema is not supported by this Todorbit version.',
      );
    }
    final directory = await Directory.systemTemp.createTemp(
      'todorbit-cloud-restore-',
    );
    try {
      final file = File(path.join(directory.path, 'snapshot.sqlite'));
      await file.writeAsBytes(
        base64Decode(manifest['database'] as String),
        flush: true,
      );
      final staged = await local.importSnapshot(
        file,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      if (staged.schemaVersion != schema) {
        throw const CloudFailure('Backup schema differs from its manifest.');
      }
      final summary = await local.summarize(staged);
      // Do not keep a second in-memory base64 database after validation.
      manifest.remove('database');
      return CloudRestorePreview(
        manifest,
        staged,
        summary,
        localFingerprint: fingerprint,
        localPreferences: preferences,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  Future<void> scheduleRestore(CloudRestorePreview preview) => _exclusive(
    () async {
      final snapshot = preview.snapshot;
      if (snapshot == null) {
        throw const CloudFailure('Select a full database backup.');
      }
      // Reuses all managed-file, digest, integrity and schema gates. Startup
      // creates Before Restore and closes native connections before applying.
      await local.scheduleRestore(
        snapshot,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
        portableSettings: preview.manifest['settings'] as String,
        expectedLocalFingerprint: preview.localFingerprint,
        expectedLocalPreferences: preview.localPreferences,
      );
      await history.record('pendingRestore', {
        'backup': path.basename(snapshot.file.path),
        'database': await databaseFingerprint(snapshot.file.path),
        'settings': settingsFingerprint(preview.manifest['settings'] as String),
      });
    },
  );
}
