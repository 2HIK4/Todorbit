import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/life_repository.dart';

import 'cloud/cloud_test_fakes.dart';
import 'support/mock_sync_drive.dart';

class _DamagedSession extends GoogleDriveAuth {
  _DamagedSession(MockClient client)
    : super(
        client: client,
        store: MemoryTokenStore(),
        flow: TestGoogleFlow(),
        clientId: 'fixture',
      );
  int loads = 0, connects = 0;
  @override
  Future<void> load() async {
    loads++;
    needsReconnect = true;
    throw const CloudFailure('Synthetic damaged saved session');
  }

  @override
  Future<void> connect() async {
    connects++;
    account = const CloudAccount('mock-only', 'Synthetic account');
    needsReconnect = false;
  }
}

void main() {
  test('a damaged saved session preserves SQL status and permits explicit reconnect', () async {
    final root = await Directory.systemTemp.createTemp('todorbit-sync-auth-');
    final database = AppDatabase(NativeDatabase.memory());
    final client = MockClient(
      (_) async => throw StateError('No real account access'),
    );
    final auth = _DamagedSession(client);
    final drive = MockSyncDrive();
    final controller = SyncController(
      repository: LifeRepository(database),
      recovery: BackupService(File('${root.path}/unused.sqlite')),
      auth: auth,
      storage: drive,
      pairing: SyncPairingService(storage: drive, vault: MemoryTokenStore()),
      isUnlocked: () => true,
      onApplied: () async {},
    );
    try {
      await controller.initialize();
      expect(controller.snapshot, isNotNull);
      expect(controller.label, 'Reconnect Google Drive');
      await controller.connect();
      expect(auth.loads, 1);
      expect(auth.connects, 1);
      expect(auth.account?.id, 'mock-only');
      expect(controller.message, isNull);
      expect(drive.uploads, 0);
    } finally {
      await controller.shutdown();
      controller.dispose();
      client.close();
      await database.close();
      await root.delete(recursive: true);
    }
  });
}
