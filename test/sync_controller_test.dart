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
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/sync/causal_record.dart';

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
  test(
    'decision draft survives restart and rejects stale reviews and candidates',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-decision-draft-',
      );
      final db = AppDatabase(NativeDatabase.memory());
      final client = MockClient(
        (_) async => throw StateError('No real network'),
      );
      final drive = MockSyncDrive();
      SyncController create() => SyncController(
        repository: LifeRepository(db),
        recovery: BackupService(File('${root.path}/unused.sqlite')),
        auth: GoogleDriveAuth(
          client: client,
          store: MemoryTokenStore(),
          flow: TestGoogleFlow(),
          clientId: 'fixture',
          enabled: false,
        ),
        storage: drive,
        pairing: SyncPairingService(storage: drive, vault: MemoryTokenStore()),
        isUnlocked: () => true,
        onApplied: () async {},
      );
      SyncConflictReview review(String token, Set<String> heads) =>
          SyncConflictReview(
            token: token,
            attentionToken: 'attention',
            reason: null,
            records: [
              SyncConflictRecord(
                entity: 'tasks',
                key: 'fixture',
                local: const {'title': 'Never persist this value'},
                review: SyncRecordReview(
                  heads: {'local', ...heads},
                  merged: const {},
                  conflicts: const [],
                ),
                candidates: const {},
                remoteHeads: heads,
              ),
            ],
          );
      final first = create(), second = create();
      try {
        final current = review('snapshot', {'remote'});
        final id = current.records.single.id;
        final older = first.saveDecisionDraft(current, {
          id: const SyncResolutionChoice.local(),
        });
        final newest = first.saveDecisionDraft(current, {
          id: const SyncResolutionChoice.revision('remote'),
        });
        await Future.wait([older, newest]);
        expect(
          (await second.loadDecisionDraft(current))[id]!.revision,
          'remote',
        );
        expect(
          await second.loadDecisionDraft(review('changed', {'remote'})),
          isEmpty,
        );
        expect(
          await second.loadDecisionDraft(
            review('snapshot', {'different-head'}),
          ),
          isEmpty,
        );
        expect(
          await File('${root.path}/sync-decision-draft.json').readAsString(),
          isNot(contains('Never persist')),
        );
        await second.saveDecisionDraft(current, const {});
        expect(await first.loadDecisionDraft(current), isEmpty);
      } finally {
        await first.shutdown();
        await second.shutdown();
        first.dispose();
        second.dispose();
        client.close();
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );
}
