import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../domain/shared_inbox_entry.dart';
import 'profile_paths.dart';

/// Durable local storage for files shared to Todorbit from external Android applications.
///
/// Files are stored in an app-private `shared_inbox` directory with an atomic
/// manifest JSON index. They remain local-only until explicitly attached to a task.
class SharedInboxStore {
  SharedInboxStore([Directory? rootDirectory])
    : _customDirectory = rootDirectory;

  final Directory? _customDirectory;
  static const _uuid = Uuid();

  /// Maximum file size accepted into the Shared Inbox (32 MiB).
  static const maxFileBytes = 32 * 1024 * 1024;

  /// Maximum file size supported for task attachments (16 MiB).
  static const maxAttachmentBytes = 16 * 1024 * 1024;

  Directory get directory =>
      _customDirectory ??
      Directory(path.join(ProfilePaths.activeDirectory().path, 'shared_inbox'));

  File get manifestFile => File(path.join(directory.path, 'shared_inbox.json'));
  Directory get filesDirectory => Directory(path.join(directory.path, 'files'));
  Directory get stagingDirectory =>
      Directory(path.join(directory.path, 'staging'));

  /// Sanitizes an incoming filename, stripping illegal characters and directory traversal.
  static String sanitizeFilename(String rawName) {
    var cleaned = rawName.trim();
    // Normalize path separators and remove any parent directory references
    cleaned = path.basename(cleaned);
    // Replace forbidden characters with underscores
    cleaned = cleaned.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    // Strip leading/trailing dots and spaces which are invalid on Windows/Android
    cleaned = cleaned.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');

    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      cleaned = 'shared_file';
    }

    // Limit length to 120 characters while preserving extension
    if (cleaned.length > 120) {
      final ext = path.extension(cleaned);
      final stem = path.basenameWithoutExtension(cleaned);
      final maxStem = 120 - ext.length;
      cleaned = (maxStem > 0 ? stem.substring(0, maxStem) : stem) + ext;
    }

    return cleaned;
  }

  /// Determines a default MIME type from file extension.
  static String inferMimeType(String filename) {
    final ext = path.extension(filename).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.txt':
        return 'text/plain';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.md':
        return 'text/markdown';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.zip':
        return 'application/zip';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  /// Loads all stored entries from the manifest, verifying existence on disk.
  List<SharedInboxEntry> loadSync() {
    if (!manifestFile.existsSync()) return [];

    try {
      final content = manifestFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! Map || decoded['version'] != 1) {
        return [];
      }

      final rawEntries = decoded['entries'];
      if (rawEntries is! List) return [];

      final validEntries = <SharedInboxEntry>[];
      for (final raw in rawEntries) {
        if (raw is Map<String, dynamic>) {
          try {
            final entry = SharedInboxEntry.fromJson(raw);
            if (entry.fileIn(directory).existsSync()) {
              validEntries.add(entry);
            }
          } catch (_) {
            // Skip corrupt entries
          }
        }
      }

      // Sort newest received first
      validEntries.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return validEntries;
    } catch (_) {
      return [];
    }
  }

  /// Loads all stored entries from the manifest asynchronously, verifying existence on disk.
  Future<List<SharedInboxEntry>> load() async {
    if (!await manifestFile.exists()) return [];

    try {
      final content = await manifestFile.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map || decoded['version'] != 1) {
        return [];
      }

      final rawEntries = decoded['entries'];
      if (rawEntries is! List) return [];

      final validEntries = <SharedInboxEntry>[];
      for (final raw in rawEntries) {
        if (raw is Map<String, dynamic>) {
          try {
            final entry = SharedInboxEntry.fromJson(raw);
            if (await entry.fileIn(directory).exists()) {
              validEntries.add(entry);
            }
          } catch (_) {
            // Skip corrupt entries
          }
        }
      }

      // Sort newest received first
      validEntries.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return validEntries;
    } catch (_) {
      return [];
    }
  }

  /// Atomically saves the entries manifest.
  void saveSync(List<SharedInboxEntry> entries) {
    directory.createSync(recursive: true);
    final staging = File('${manifestFile.path}.tmp');
    final payload = {
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    staging.writeAsStringSync(jsonEncode(payload), flush: true);
    try {
      staging.renameSync(manifestFile.path);
    } catch (_) {
      if (manifestFile.existsSync()) {
        manifestFile.deleteSync();
      }
      staging.renameSync(manifestFile.path);
    }
  }

  /// Atomically saves the entries manifest asynchronously.
  Future<void> save(List<SharedInboxEntry> entries) async {
    await directory.create(recursive: true);
    final staging = File('${manifestFile.path}.tmp');
    final payload = {
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    await staging.writeAsString(jsonEncode(payload), flush: true);
    try {
      await staging.rename(manifestFile.path);
    } catch (_) {
      if (await manifestFile.exists()) {
        await manifestFile.delete();
      }
      await staging.rename(manifestFile.path);
    }
  }

  /// Ingests a file safely into the Shared Inbox.
  ///
  /// Performs atomic copying, size limits validation, SHA-256 duplicate detection,
  /// and filename sanitization. Streams content for SHA-256 calculation to avoid
  /// holding large byte arrays in the Dart heap.
  Future<SharedInboxEntry> addFile(
    File source, {
    String? displayName,
    String? mimeType,
  }) async {
    final type = await FileSystemEntity.type(source.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw ArgumentError('Selected item is not a regular file');
    }

    final stat = await source.stat();
    if (stat.size > maxFileBytes) {
      throw ArgumentError(
        'Shared file exceeds maximum allowed size of 32 MiB (${(stat.size / (1024 * 1024)).toStringAsFixed(1)} MiB)',
      );
    }

    // Stream sha256 to avoid holding large byte arrays in memory for up to 32 MiB
    final digest = (await sha256.bind(source.openRead()).first).toString();
    final safeName = sanitizeFilename(
      displayName ?? path.basename(source.path),
    );
    final mime = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim()
        : inferMimeType(safeName);

    // Duplicate detection: check if this content is already present in inbox
    final currentEntries = await load();
    for (final existing in currentEntries) {
      if (existing.sha256 == digest &&
          existing.byteSize == stat.size &&
          await existing.fileIn(directory).exists()) {
        return existing;
      }
    }

    await filesDirectory.create(recursive: true);
    await stagingDirectory.create(recursive: true);

    final id = _uuid.v4();
    final relativePath = 'files/${id}_$safeName';
    final stagingFile = File(path.join(stagingDirectory.path, '$id.tmp'));
    final targetFile = File(path.join(directory.path, relativePath));

    await source.copy(stagingFile.path);
    await stagingFile.rename(targetFile.path);

    final entry = SharedInboxEntry(
      id: id,
      displayName: safeName,
      relativePath: relativePath,
      mimeType: mime,
      byteSize: stat.size,
      sha256: digest,
      receivedAt: DateTime.now().toUtc(),
    );

    currentEntries.insert(0, entry);
    await save(currentEntries);
    return entry;
  }

  /// Ingests raw bytes safely into the Shared Inbox synchronously.
  SharedInboxEntry addBytesSync(
    List<int> bytes, {
    required String displayName,
    String? mimeType,
  }) {
    if (bytes.length > maxFileBytes) {
      throw ArgumentError(
        'Shared file exceeds maximum allowed size of 32 MiB (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MiB)',
      );
    }

    final safeName = sanitizeFilename(displayName);
    final digest = sha256.convert(bytes).toString();
    final mime = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim()
        : inferMimeType(safeName);

    // Duplicate detection: check if this content is already present in inbox
    final currentEntries = loadSync();
    for (final existing in currentEntries) {
      if (existing.sha256 == digest &&
          existing.byteSize == bytes.length &&
          existing.fileIn(directory).existsSync()) {
        // Return existing entry without storing redundant copy
        return existing;
      }
    }

    filesDirectory.createSync(recursive: true);
    stagingDirectory.createSync(recursive: true);

    final id = _uuid.v4();
    final relativePath = 'files/${id}_$safeName';
    final stagingFile = File(path.join(stagingDirectory.path, '$id.tmp'));
    final targetFile = File(path.join(directory.path, relativePath));

    // Atomically write bytes to staging, then rename to target
    stagingFile.writeAsBytesSync(bytes, flush: true);
    stagingFile.renameSync(targetFile.path);

    final entry = SharedInboxEntry(
      id: id,
      displayName: safeName,
      relativePath: relativePath,
      mimeType: mime,
      byteSize: bytes.length,
      sha256: digest,
      receivedAt: DateTime.now().toUtc(),
    );

    currentEntries.insert(0, entry);
    saveSync(currentEntries);
    return entry;
  }

  /// Ingests raw bytes safely into the Shared Inbox asynchronously.
  Future<SharedInboxEntry> addBytes(
    List<int> bytes, {
    required String displayName,
    String? mimeType,
  }) async {
    if (bytes.length > maxFileBytes) {
      throw ArgumentError(
        'Shared file exceeds maximum allowed size of 32 MiB (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MiB)',
      );
    }

    final safeName = sanitizeFilename(displayName);
    final digest = sha256.convert(bytes).toString();
    final mime = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim()
        : inferMimeType(safeName);

    // Duplicate detection: check if this content is already present in inbox
    final currentEntries = await load();
    for (final existing in currentEntries) {
      if (existing.sha256 == digest &&
          existing.byteSize == bytes.length &&
          await existing.fileIn(directory).exists()) {
        return existing;
      }
    }

    await filesDirectory.create(recursive: true);
    await stagingDirectory.create(recursive: true);

    final id = _uuid.v4();
    final relativePath = 'files/${id}_$safeName';
    final stagingFile = File(path.join(stagingDirectory.path, '$id.tmp'));
    final targetFile = File(path.join(directory.path, relativePath));

    await stagingFile.writeAsBytes(bytes, flush: true);
    await stagingFile.rename(targetFile.path);

    final entry = SharedInboxEntry(
      id: id,
      displayName: safeName,
      relativePath: relativePath,
      mimeType: mime,
      byteSize: bytes.length,
      sha256: digest,
      receivedAt: DateTime.now().toUtc(),
    );

    currentEntries.insert(0, entry);
    await save(currentEntries);
    return entry;
  }

  /// Deletes a single entry from the inbox and removes its file from disk.
  void deleteEntrySync(String id) {
    final currentEntries = loadSync();
    final index = currentEntries.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final entry = currentEntries.removeAt(index);
    final file = entry.fileIn(directory);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {
        // Continue even if disk delete had an OS lock
      }
    }

    saveSync(currentEntries);
  }

  Future<void> deleteEntry(String id) async => deleteEntrySync(id);

  /// Deletes multiple entries in batch.
  void deleteEntriesSync(List<String> ids) {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    final currentEntries = loadSync();
    final remaining = <SharedInboxEntry>[];

    for (final entry in currentEntries) {
      if (idSet.contains(entry.id)) {
        final file = entry.fileIn(directory);
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      } else {
        remaining.add(entry);
      }
    }

    saveSync(remaining);
  }

  Future<void> deleteEntries(List<String> ids) async => deleteEntriesSync(ids);

  /// Clears all files and manifest from the inbox.
  Future<void> clear() async {
    final entries = await load();
    for (final entry in entries) {
      final file = entry.fileIn(directory);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    if (manifestFile.existsSync()) {
      try {
        manifestFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Cleans up interrupted staging files and unindexed orphaned files.
  Future<void> cleanOrphans() async {
    if (stagingDirectory.existsSync()) {
      try {
        for (final entity in stagingDirectory.listSync()) {
          if (entity is File) {
            entity.deleteSync();
          }
        }
      } catch (_) {}
    }

    final entries = await load();
    final referenced = entries
        .map((e) => path.normalize(e.fileIn(directory).path))
        .toSet();

    if (filesDirectory.existsSync()) {
      try {
        for (final entity in filesDirectory.listSync()) {
          if (entity is File &&
              !referenced.contains(path.normalize(entity.path))) {
            entity.deleteSync();
          }
        }
      } catch (_) {}
    }
  }
}
