import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_provider.dart';

class MockSyncDrive implements SyncStorageProvider {
  @override
  CloudAccount? account = const CloudAccount('mock-only', 'Synthetic account');
  final objects = <CloudObject>[];
  final payloads = <String, Uint8List>{};
  bool failAfterUpload = false, failDownload = false, expired = false;
  int uploads = 0, downloads = 0, lists = 0;
  Future<void> Function()? beforeList;
  @override
  Future<String> startChangeToken() async => '${objects.length}';
  @override
  Future<List<CloudObject>> list() async {
    lists++;
    await beforeList?.call();
    return List.of(objects);
  }

  @override
  Future<DriveChangePage> changes(String token) async {
    if (expired) {
      expired = false;
      throw const DriveCheckpointExpired();
    }
    final first = int.parse(token);
    return DriveChangePage(
      objects: objects.skip(first).toList(),
      removedIds: const {},
      checkpoint: '${objects.length}',
      hasMore: false,
    );
  }

  @override
  Future<CloudObject> upload(
    Uint8List bytes,
    Map<String, String> properties,
    CloudProgress progress,
  ) async {
    uploads++;
    final object = CloudObject(
      id: 'object-$uploads',
      accountId: account!.id,
      name: 'opaque.tdsync',
      bytes: bytes.length,
      createdAt: DateTime.now().toUtc(),
      properties: {
        ...properties,
        'application': 'todorbit-sync',
        'verified': 'true',
      },
      md5: md5.convert(bytes).toString(),
    );
    objects.add(object);
    payloads[object.id] = Uint8List.fromList(bytes);
    if (failAfterUpload) {
      failAfterUpload = false;
      throw const CloudFailure('Synthetic ambiguous upload');
    }
    return object;
  }

  @override
  Future<Uint8List> download(CloudObject object, CloudProgress progress) async {
    downloads++;
    if (failDownload) throw const CloudFailure('Synthetic offline');
    return payloads[object.id]!;
  }

  @override
  Future<void> delete(CloudObject object) async =>
      throw UnimplementedError('Sync must retain immutable objects');
}
