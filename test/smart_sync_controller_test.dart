import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

import 'cloud/cloud_test_fakes.dart';
import 'support/mock_sync_drive.dart';

class _Auth extends GoogleDriveAuth {
  _Auth()
    : super(
        client: MockClient((_) async => throw StateError('No real network')),
        store: MemoryTokenStore(),
        flow: TestGoogleFlow(),
        clientId: 'fixture',
      );
  int connects = 0;
  @override
  Future<void> load() async {}
  @override
  Future<void> connect() async {
    connects++;
    account = const CloudAccount('mock-only', 'Synthetic account');
    needsReconnect = false;
  }
}

void main() {
  late Directory root;
  late MockSyncDrive drive;
  final databases = <AppDatabase>[];
  final controllers = <SyncController>[];
  final auths = <_Auth>[];

  SyncController device(
    String name, {
    Future<void> Function(bool)? scheduleBackground,
  }) {
    final file = File('${root.path}/$name.sqlite');
    final db = AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000');
          db.execute('PRAGMA foreign_keys = ON');
          db.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
    final auth = _Auth();
    databases.add(db);
    auths.add(auth);
    final controller = SyncController(
      repository: LifeRepository(db),
      recovery: BackupService(file),
      auth: auth,
      storage: drive,
      pairing: SyncPairingService(storage: drive, vault: MemoryTokenStore()),
      isUnlocked: () => true,
      onApplied: () async {},
      scheduleBackground: scheduleBackground,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-smart-sync-');
    drive = MockSyncDrive();
  });
  tearDown(() async {
    for (final controller in controllers) {
      await controller.shutdown();
      controller.dispose();
    }
    for (final db in databases) {
      await db.close();
    }
    for (final auth in auths) {
      auth.client.close();
    }
    controllers.clear();
    databases.clear();
    auths.clear();
    await root.delete(recursive: true);
  });

  test('one manual request signs in, authorizes first device and completes exchange', () async {
    final a = device('first');
    await a.repository.addTask(const TaskDraft(title: 'Windows task'));
    await a.syncNow(manual: true);
    expect((a.auth as _Auth).connects, 1);
    expect(a.snapshot!.binding, isNotNull);
    expect(a.snapshot!.automatic, isTrue);
    expect(a.status.phase, SyncPhase.upToDate);
    expect(a.status.lastSuccess, isNotNull);
    expect(a.needsRecoveryCode, isFalse);
    expect(a.recoveryReminder, isFalse);
    expect(a.standardSync, isTrue);
    expect(a.standardIntroduction, isTrue);
    expect(await a.recoveryCode(), isNull);
    await a.dismissStandardIntroduction();
    final saved = await a.pairing.saved();
    expect(saved!.introSeen, isTrue);
  });

  test('metadata refreshes do not schedule native background jobs but committed edits do', () async {
    var scheduled = 0;
    final a = device(
      'local-change',
      scheduleBackground: (_) async {
        scheduled++;
      },
    );
    await a.syncNow(manual: true);
    scheduled = 0;
    await a.localChanged();
    expect(scheduled, 0);
    await a.repository.addTask(const TaskDraft(title: 'Committed change'));
    await a.localChanged();
    expect(scheduled, 1);
    expect((await a.repository.syncExchangeStatus()).pending, greaterThan(0));
  });

  test(
    'Standard Sync joins without credentials and preserves both local datasets',
    () async {
      final a = device('standard-windows'), b = device('standard-android');
      await a.repository.addTask(const TaskDraft(title: 'Windows local'));
      await b.repository.addTask(const TaskDraft(title: 'Android local'));
      await a.syncNow(manual: true);
      await b.syncNow(manual: true);
      expect(b.needsRecoveryCode, isFalse);
      expect(b.standardSync, isTrue);
      expect(b.standardIntroduction, isFalse);
      await a.syncNow(manual: true);
      expect(a.status.phase, SyncPhase.upToDate);
      expect(b.status.phase, SyncPhase.upToDate);
      expect(
        (await a.repository.tasks()).map((t) => t.id).toSet(),
        (await b.repository.tasks()).map((t) => t.id).toSet(),
      );
      expect(await b.repository.tasks(), hasLength(2));
    },
  );

  test('second device asks for its code once, retains local data, and exchanges both ways', () async {
    final a = device('windows'), b = device('android');
    await a.pairing.prepare(privateKey: SyncWorkspaceKey.generate());
    await a.repository.addTask(const TaskDraft(title: 'Windows task'));
    await a.syncNow(manual: true);
    final uploads = drive.uploads;
    await b.repository.addTask(const TaskDraft(title: 'Android task'));
    await b.syncNow(manual: true);
    expect(b.needsRecoveryCode, isTrue);
    expect(b.snapshot!.binding, isNull);
    expect(drive.uploads, uploads);
    expect((await b.repository.tasks()).single.title, 'Android task');
    await b.activate(recoveryCode: await a.recoveryCode());
    expect(b.needsRecoveryCode, isFalse);
    expect(b.status.phase, SyncPhase.upToDate);
    await a.syncNow(manual: true);
    final ids = (await a.repository.tasks()).map((t) => t.id).toSet();
    expect(ids, hasLength(2));
    expect((await b.repository.tasks()).map((t) => t.id).toSet(), ids);
    final reloaded = SyncPairingService(storage: drive, vault: b.pairing.vault);
    expect(
      (await reloaded.prepare()).binding.device,
      b.snapshot!.binding!.device,
    );
    await b.syncNow(manual: true);
    expect((b.auth as _Auth).connects, 1);
    expect(b.status.phase, SyncPhase.upToDate);
  });

  for (final resolveOnFirst in [false, true]) {
    test(
      'offline decision on ${resolveOnFirst ? 'Windows' : 'Android'} survives retry and converges without suppressing new conflicts',
      () async {
        final a = device('windows'), b = device('android');
        await a.repository.addTask(const TaskDraft(title: 'Original'));
        await a.syncNow(manual: true);
        await b.syncNow(manual: true);
        await b.activate(recoveryCode: await a.recoveryCode());
        await a.repository.updateTask(
          (await a.repository.tasks()).single,
          const TaskDraft(title: 'Windows edit', priority: 2),
        );
        await b.repository.updateTask(
          (await b.repository.tasks()).single,
          const TaskDraft(title: 'Android edit', notes: 'Independent note'),
        );
        await a.syncNow(manual: true);
        await b.syncNow(manual: true);
        await a.syncNow(manual: true);
        final resolver = resolveOnFirst ? a : b;
        final other = resolveOnFirst ? b : a;
        final review = (await resolver.reviewConflicts())!;
        expect(review.records.single.review.needsDecision, isTrue);
        drive.failDownload = true;
        drive.beforeList = () async =>
            throw const CloudFailure('Synthetic offline');
        // Fail the change feed, including clients which already have a cursor.
        drive.failChanges = true;
        final result = await resolver.resolve(review, {
          review.records.single.id: const SyncResolutionChoice.local(),
        });
        expect(result?.state, SyncApplyState.applied);
        expect(resolver.message, contains('saved on this device'));
        expect(
          (await resolver.repository.syncExchangeStatus()).pending,
          greaterThan(0),
        );
        drive.failDownload = false;
        drive.failChanges = false;
        drive.beforeList = null;
        await resolver.repository.db.customStatement(
          'UPDATE sync_capture_context SET next_attempt_utc=NULL',
        );
        await resolver.engine.syncNow();
        expect(resolver.message, contains('Decisions synced'));
        await other.syncNow(manual: true);
        await resolver.syncNow(manual: true);
        expect(await resolver.reviewConflicts(), isNull);
        expect(await other.reviewConflicts(), isNull);
        final accepted = resolveOnFirst ? 'Windows edit' : 'Android edit';
        for (final c in [a, b]) {
          final task = (await c.repository.tasks()).single;
          expect(task.title, accepted);
          expect(task.notes, 'Independent note');
          expect(task.priority, 2);
          expect(c.status.conflicts, 0);
        }
        await a.repository.updateTask(
          (await a.repository.tasks()).single,
          const TaskDraft(title: 'New Windows divergence'),
        );
        await b.repository.updateTask(
          (await b.repository.tasks()).single,
          const TaskDraft(title: 'New Android divergence'),
        );
        await a.syncNow(manual: true);
        await b.syncNow(manual: true);
        expect(b.status.conflicts, greaterThan(0));
      },
    );
  }

  for (final agree in [true, false]) {
    test(
      'concurrent offline resolutions ${agree ? 'agree and converge' : 'retain genuinely competing decisions'}',
      () async {
        final a = device('windows'), b = device('android');
        await a.repository.addTask(const TaskDraft(title: 'Original'));
        await a.syncNow(manual: true);
        await b.syncNow(manual: true);
        await b.activate(recoveryCode: await a.recoveryCode());
        await a.repository.updateTask(
          (await a.repository.tasks()).single,
          const TaskDraft(title: 'Windows decision'),
        );
        await b.repository.updateTask(
          (await b.repository.tasks()).single,
          const TaskDraft(title: 'Android decision'),
        );
        await Future.wait([a.syncNow(manual: true), b.syncNow(manual: true)]);
        await a.syncNow(manual: true);
        await b.syncNow(manual: true);
        final left = (await a.reviewConflicts())!,
            right = (await b.reviewConflicts())!;
        final matching = right.records.single.candidates.entries
            .firstWhere((e) => e.value?['title'] == 'Windows decision')
            .key;
        drive.failDownload = true;
        await Future.wait([
          a.resolve(left, {
            left.records.single.id: const SyncResolutionChoice.local(),
          }),
          b.resolve(right, {
            right.records.single.id: agree
                ? SyncResolutionChoice.revision(matching)
                : const SyncResolutionChoice.local(),
          }),
        ]);
        drive.failDownload = false;
        await Future.wait([a.syncNow(manual: true), b.syncNow(manual: true)]);
        await a.syncNow(manual: true);
        await b.syncNow(manual: true);
        if (agree) {
          expect(await a.reviewConflicts(), isNull);
          expect(await b.reviewConflicts(), isNull);
          expect((await a.repository.tasks()).single.title, 'Windows decision');
          expect((await b.repository.tasks()).single.title, 'Windows decision');
        } else {
          final review = (await b.reviewConflicts())!;
          expect(review.records.single.review.needsDecision, isTrue);
          await b.resolve(review, {
            review.records.single.id: const SyncResolutionChoice.local(),
          });
          await a.syncNow(manual: true);
          expect(await a.reviewConflicts(), isNull);
          expect(await b.reviewConflicts(), isNull);
          expect((await a.repository.tasks()).single.title, 'Android decision');
        }
      },
    );
  }
}
