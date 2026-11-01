import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/features/settings/sync_conflicts_dialog.dart';

import 'dart:io';

import 'cloud/cloud_test_fakes.dart';
import 'support/mock_sync_drive.dart';

class _Controller extends SyncController {
  _Controller({
    required super.repository,
    required super.recovery,
    required super.auth,
    required super.pairing,
    required bool Function() unlocked,
    required MockSyncDrive drive,
  }) : super(storage: drive, isUnlocked: unlocked, onApplied: () async {});
  int applied = 0;
  Map<String, SyncResolutionChoice>? selected;
  @override
  Future<SyncApplyResult?> resolve(
    SyncConflictReview review,
    Map<String, SyncResolutionChoice> choices,
  ) async {
    applied++;
    selected = Map.of(choices);
    return const SyncApplyResult(SyncApplyState.applied);
  }

  @override
  Future<void> dismiss(SyncConflictReview review) async {}
}

void main() {
  late AppDatabase database;
  late _Controller controller;
  late Directory root;
  var unlocked = true;
  late MockClient client;
  final local = {
    'title': 'Study Chapter 2',
    'notes': List.filled(40, 'Long synthetic notes.').join(' '),
  };
  final remote = {
    'title': 'Study Chapter 3',
    'notes': List.filled(40, 'Long synthetic notes.').join(' '),
  };
  final record = SyncConflictRecord(
    entity: 'tasks',
    key: '{"id":"synthetic"}',
    local: local,
    review: SyncRecordReview(
      heads: {'local', 'remote'},
      merged: {'notes': local['notes']},
      conflicts: [
        SyncConflict('title', 'Study Chapter 1', {
          'local': local['title'],
          'remote': remote['title'],
        }),
      ],
    ),
    candidates: {'local': local, 'remote': remote},
    remoteHeads: {'remote'},
  );
  final review = SyncConflictReview(
    token: 'snapshot',
    attentionToken: 'attention',
    records: [record],
    reason: null,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-conflict-ui-');
    database = AppDatabase(NativeDatabase.memory());
    final drive = MockSyncDrive(), vault = MemoryTokenStore();
    unlocked = true;
    client = MockClient(
      (_) async => throw StateError('UI fixture must not use network'),
    );
    final auth = GoogleDriveAuth(
      client: client,
      store: MemoryTokenStore(),
      flow: TestGoogleFlow(),
      clientId: 'fixture',
      enabled: false,
    );
    controller = _Controller(
      repository: LifeRepository(database),
      recovery: BackupService(File('${root.path}/unused.sqlite')),
      auth: auth,
      pairing: SyncPairingService(storage: drive, vault: vault),
      unlocked: () => unlocked,
      drive: drive,
    );
  });
  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
    client.close();
    await database.close();
    await root.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester tester,
    Size size,
    double scale,
    Brightness brightness,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    SyncConflictsDialog(controller: controller, review: review),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'compact ${brightness.name} large text remains scrollable and bulk choice is not applied immediately',
      (tester) async {
        await open(tester, const Size(360, 640), 1.8, brightness);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Use Cloud for All'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use Cloud for All'));
        await tester.pumpAndSettle();
        expect(controller.applied, 0);
        await tester.tap(find.text('Apply Selected'));
        await tester.pumpAndSettle();
        expect(controller.applied, 1);
        expect(controller.selected![record.id]!.revision, 'remote');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a locked app closes its conflict route', (tester) async {
    await open(tester, const Size(1100, 800), 1, Brightness.light);
    expect(find.text('Resolve sync conflicts'), findsOneWidget);
    unlocked = false;
    controller.privacyChanged();
    await tester.pumpAndSettle();
    expect(find.text('Resolve sync conflicts'), findsNothing);
    expect(controller.applied, 0);
  });
}
