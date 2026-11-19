import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/cloud/sync_problem.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/features/shared/sync_status_button.dart';

import 'cloud/cloud_test_fakes.dart';
import 'support/mock_sync_drive.dart';

class _FakeSyncController extends SyncController {
  _FakeSyncController({
    required super.repository,
    required super.recovery,
    required super.auth,
    required super.pairing,
    required bool Function() unlocked,
    required MockSyncDrive drive,
  }) : super(
          storage: drive,
          isUnlocked: unlocked,
          onApplied: () async {},
          resetVault: MemoryTokenStore(),
        );

  SyncProblem? injectedProblem;
  @override
  SyncProblem? get problem => injectedProblem ?? super.problem;

  int manualSyncRequests = 0;
  @override
  Future<void> syncNow({bool manual = false}) async {
    if (manual) manualSyncRequests++;
  }
}

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late _FakeSyncController controller;
  late MockClient client;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit-sync-btn-test-');
    database = AppDatabase(NativeDatabase.memory());
    final drive = MockSyncDrive();
    final vault = MemoryTokenStore();
    client = MockClient((_) async => throw StateError('UI test has no network'));
    final auth = GoogleDriveAuth(
      client: client,
      store: vault,
      flow: TestGoogleFlow(),
      clientId: 'fixture',
      enabled: false,
    );
    controller = _FakeSyncController(
      repository: LifeRepository(database),
      recovery: BackupService(File('${tempDir.path}/backup.sqlite')),
      auth: auth,
      pairing: SyncPairingService(storage: drive, vault: vault),
      unlocked: () => true,
      drive: drive,
    );
  });

  tearDown(() async {
    client.close();
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('SyncStatusButton invokes onOpenSettings when problem exists', (
    tester,
  ) async {
    controller.injectedProblem = SyncProblem.from(
      const CloudFailure('Network timeout', kind: CloudFailureKind.offline),
    );
    bool settingsOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Scaffold(
            body: SyncStatusButton(
              onOpenSettings: (ctx) {
                settingsOpened = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('sync-status-button')));
    await tester.pumpAndSettle();

    expect(settingsOpened, isTrue);
  });

  testWidgets('SyncStatusButton invokes onOpenConflicts when conflicts exist', (
    tester,
  ) async {
    controller.auth.account = const CloudAccount('synthetic', 'Synthetic account');
    controller.snapshot = const SyncExchangeStatus(
      binding: SyncBinding(
        workspace: 'fixture',
        account: 'synthetic',
        device: 'fixture',
      ),
      enabled: true,
      automatic: true,
      quarantined: false,
      pending: 0,
      conflicts: 2,
      waiting: 0,
    );
    controller.engine.status = const SyncEngineStatus(
      SyncPhase.upToDate,
      conflicts: 2,
    );
    bool conflictsOpened = false;
    SyncController? receivedController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Scaffold(
            body: SyncStatusButton(
              onOpenConflicts: (ctx, ctrl) {
                conflictsOpened = true;
                receivedController = ctrl;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('sync-status-button')));
    await tester.pumpAndSettle();

    expect(conflictsOpened, isTrue);
    expect(receivedController, equals(controller));
  });

  testWidgets(
    'SyncStatusButton displays conflict badge and tooltip without callbacks',
    (tester) async {
      controller.engine.status = const SyncEngineStatus(
        SyncPhase.syncing,
        conflicts: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: Scaffold(
              body: SyncStatusButton(),
            ),
          ),
        ),
      );

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(
        find.byTooltip('Sync · Syncing · 4 conflicts need attention'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SyncStatusButton shows settings unavailable notice when problem exists and callback is null',
    (tester) async {
      controller.injectedProblem = SyncProblem.from(
        const CloudFailure('Network timeout', kind: CloudFailureKind.offline),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: Scaffold(
              body: SyncStatusButton(),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('sync-status-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('sync-settings-unavailable-notice')),
        findsOneWidget,
      );
      expect(
        find.text('Sync settings are unavailable from this view.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SyncStatusButton shows conflict review unavailable notice when conflicts exist and callback is null',
    (tester) async {
      controller.auth.account =
          const CloudAccount('synthetic', 'Synthetic account');
      controller.snapshot = const SyncExchangeStatus(
        binding: SyncBinding(
          workspace: 'fixture',
          account: 'synthetic',
          device: 'fixture',
        ),
        enabled: true,
        automatic: true,
        quarantined: false,
        pending: 0,
        conflicts: 2,
        waiting: 0,
      );
      controller.engine.status = const SyncEngineStatus(
        SyncPhase.upToDate,
        conflicts: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: Scaffold(
              body: SyncStatusButton(),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('sync-status-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('sync-conflicts-unavailable-notice')),
        findsOneWidget,
      );
      expect(
        find.text('Sync conflict review is unavailable from this view.'),
        findsOneWidget,
      );
    },
  );
}
