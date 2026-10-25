import 'dart:typed_data';

enum CloudBackupKind { full, settings }

typedef CloudProgress = void Function(String stage, int done, int total);

class CloudAccount {
  const CloudAccount(this.id, this.label);
  final String id;
  final String label;
}

class CloudObject {
  const CloudObject({
    required this.id,
    required this.accountId,
    required this.name,
    required this.bytes,
    required this.createdAt,
    required this.properties,
    required this.md5,
  });
  final String id, accountId, name, md5;
  final int bytes;
  final DateTime createdAt;
  final Map<String, String> properties;
  CloudBackupKind? get kind => CloudBackupKind.values
      .where((value) => value.name == properties['kind'])
      .firstOrNull;
}

/// Storage operations are independent of SQLite, packaging and the UI.
abstract interface class CloudStorageProvider {
  CloudAccount? get account;
  Future<List<CloudObject>> list();
  Future<CloudObject> upload(
    Uint8List bytes,
    Map<String, String> properties,
    CloudProgress progress,
  );
  Future<Uint8List> download(CloudObject object, CloudProgress progress);
  Future<void> delete(CloudObject object);
}

class CloudFailure implements Exception {
  const CloudFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
