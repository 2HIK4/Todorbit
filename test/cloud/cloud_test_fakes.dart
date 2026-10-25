import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';

class MemoryTokenStore implements CloudTokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class TestGoogleFlow implements GoogleAuthorizationFlow {
  Uri? authorization;
  bool canceled = false, wrongState = false;
  @override
  void cancel() {
    // This fake has no pending asynchronous authorization to cancel.
  }

  @override
  Future<Map<String, String>> authorize(Uri Function(String) build) async {
    // Cancel affects the pending attempt, not a subsequent sign-in.
    final wasCanceled = canceled;
    canceled = false;
    authorization = build('http://127.0.0.1:12345/oauth2callback');
    return {
      'state': wrongState
          ? 'bad-state'
          : authorization!.queryParameters['state']!,
      if (wasCanceled)
        'error': 'access_denied'
      else
        'code': 'authorization-code',
    };
  }
}

class MemoryCloud implements CloudStorageProvider {
  @override
  CloudAccount? account = const CloudAccount('test-account', 'Test account');
  final Map<String, Uint8List> content = {};
  final List<CloudObject> objects = [];
  @override
  Future<List<CloudObject>> list() async => objects;
  @override
  Future<Uint8List> download(
    CloudObject object,
    CloudProgress progress,
  ) async => content[object.id]!;
  @override
  Future<void> delete(CloudObject object) async {
    content.remove(object.id);
    objects.remove(object);
  }

  @override
  Future<CloudObject> upload(
    Uint8List bytes,
    Map<String, String> properties,
    CloudProgress progress,
  ) async {
    final id = properties['backupId']!;
    content[id] = bytes;
    final object = CloudObject(
      id: id,
      accountId: account!.id,
      name: '$id.tdbackup',
      bytes: bytes.length,
      createdAt: DateTime.now().toUtc(),
      properties: properties,
      md5: md5.convert(bytes).toString(),
    );
    objects.add(object);
    return object;
  }
}
