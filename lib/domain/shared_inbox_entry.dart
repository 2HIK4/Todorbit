import 'dart:io';
import 'package:path/path.dart' as path;

/// A durable file record stored in the device's local Shared Inbox.
class SharedInboxEntry {
  const SharedInboxEntry({
    required this.id,
    required this.displayName,
    required this.relativePath,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    required this.receivedAt,
  });

  final String id;
  final String displayName;
  final String relativePath;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final DateTime receivedAt;

  /// Resolves the concrete local file within the inbox directory.
  File fileIn(Directory inboxDirectory) =>
      File(path.join(inboxDirectory.path, relativePath));

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'relativePath': relativePath,
    'mimeType': mimeType,
    'byteSize': byteSize,
    'sha256': sha256,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
  };

  factory SharedInboxEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final displayName = json['displayName'] as String?;
    final relativePath = json['relativePath'] as String?;
    final byteSize = json['byteSize'] as int?;
    final sha256 = json['sha256'] as String?;
    final receivedAt = json['receivedAt'] as String?;

    if (id == null ||
        displayName == null ||
        relativePath == null ||
        byteSize == null ||
        sha256 == null ||
        receivedAt == null) {
      throw const FormatException('Invalid shared inbox entry metadata');
    }

    return SharedInboxEntry(
      id: id,
      displayName: displayName,
      relativePath: relativePath,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      byteSize: byteSize,
      sha256: sha256,
      receivedAt: DateTime.parse(receivedAt),
    );
  }
}
