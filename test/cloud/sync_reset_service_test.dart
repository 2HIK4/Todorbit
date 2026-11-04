import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/profile_fingerprint.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/cloud/sync_generation.dart';
import 'package:life_manager/data/cloud/sync_pairing_service.dart';
import 'package:life_manager/data/cloud/sync_problem.dart';
import 'package:life_manager/data/cloud/sync_reset_service.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';
import 'package:uuid/uuid.dart';

import 'cloud_test_fakes.dart';
import '../support/mock_sync_drive.dart';

class _Drive extends MockSyncDrive {
  bool failDelete = false, corruptSeed = false;
  Future<void> Function()? beforeOperation;
  final events = <String>[];
  final readBack = <String>{};
  @override
  Future<Uint8List> download(CloudObject object, CloudProgress progress) async {
    final bytes = await super.download(object, progress);
    readBack.add(object.id);
    if (corruptSeed && object.properties['kind'] == 'operations')
      return Uint8List.fromList([0]);
    return bytes;
  }

  @override
  Future<CloudObject> upload(
    Uint8List bytes,
    Map<String, String> properties,
    CloudProgress progress,
  ) async {
    if (properties['kind'] == 'operations' && beforeOperation != null) {
      final wait = beforeOperation!;
      beforeOperation = null;
      await wait();
    }
    if (properties['kind'] == 'head') {
      final workspace = properties['workspaceId'];
      expect(
        objects
            .where(
              (o) =>
                  o.properties['workspaceId'] == workspace &&
                  o.properties['kind'] != 'head',
            )
            .every((o) => readBack.contains(o.id)),
        isTrue,
        reason: 'Every staged object must be read back before activation',
      );
    }
    final value = await super.upload(bytes, properties, progress);
    events.add('upload:${properties['kind']}');
    return value;
  }

  @override
  Future<void> delete(CloudObject object) async {
    expect(
      events,
      contains('upload:head'),
      reason: 'Never delete before activation',
    );
    events.add('delete');
    if (failDelete)
      throw const CloudFailure(
        'Synthetic denied',
        kind: CloudFailureKind.permission,
      );
    objects.removeWhere((o) => o.id == object.id);
    payloads.remove(object.id);
  }
}

void main() {
  late Directory root;
  late AppDatabase db;
  late LifeRepository repository;
  late BackupService backup;
  late _Drive drive;
  late MemoryTokenStore keys, operation;
  late SyncPairingService pairing;
  bool unlocked = true;
  SyncResetService service() => SyncResetService(
    repository: repository,
    recovery: backup,
    pairing: pairing,
    vault: operation,
    isUnlocked: () => unlocked,
  );
  Future<SyncPairing> legacy() async {
    final original = await pairing.prepare(
      privateKey: SyncWorkspaceKey.generate(),
    );
    await repository.activateSyncCapture(
      workspaceId: original.binding.workspace,
      accountId: original.binding.account,
      deviceId: original.binding.device,
      recovery: backup,
    );
    return original;
  }

  setUp(() async {
    unlocked = true;
    root = await Directory.systemTemp.createTemp('todorbit-reset-fixture-');
    final file = File('${root.path}/profile.sqlite');
    db = AppDatabase(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA foreign_keys=ON');
        },
      ),
    );
    repository = LifeRepository(db);
    backup = BackupService(file);
    drive = _Drive();
    keys = MemoryTokenStore();
    operation = MemoryTokenStore();
    pairing = SyncPairingService(
      storage: drive,
      vault: keys,
      resetVault: operation,
    );
    await repository.addTask(const TaskDraft(title: 'Preserved local parent'));
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('unknown legacy key: preserve planner, attachments, pending journal and verified snapshot; upload/readback before delete', () async {
    final original = await legacy();
    final oldProtected = keys.value;
    final attachment = File('${root.path}/synthetic.txt');
    await attachment.writeAsString('synthetic attachment bytes');
    final task = (await repository.tasks()).first;
    await repository.attachManagedFile(task.id, attachment);
    await repository.addTask(const TaskDraft(title: 'Offline pending edit'));
    final before = await databaseFingerprint(backup.databaseFile.path);
    final oldPending = await repository.pendingSyncChanges(
      workspaceId: original.binding.workspace,
      accountId: original.binding.account,
    );
    await keys.delete(); // No old password/key required by reset.
    final reset = service();
    final review = await reset.review();
    expect(await File(review['backup'] as String).exists(), isTrue);
    await expectLater(
      pairing.prepare(),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.reset,
        ),
      ),
    );
    expect(keys.value, isNull);
    expect(drive.events.where((e) => e == 'delete'), isEmpty);
    await reset.confirm();
    await reset.resume();
    final current = (await repository.syncExchangeStatus()).binding!;
    expect(current.workspace, isNot(original.binding.workspace));
    expect(await databaseFingerprint(backup.databaseFile.path), before);
    expect(
      (await repository.pendingSyncChanges(
        workspaceId: original.binding.workspace,
        accountId: original.binding.account,
      )).length,
      oldPending.length,
    );
    expect(await databaseFingerprint(review['backup'] as String), before);
    expect((await pairing.saved())!.key.isStandard, isTrue);
    expect(
      drive.objects.every(
        (o) => o.properties['workspaceId'] == current.workspace,
      ),
      isTrue,
    );
    expect((await reset.state())!['phase'], 'complete');
    expect(oldProtected, isNotNull);
    expect(
      drive.events.indexOf('upload:head'),
      lessThan(drive.events.indexOf('delete')),
    );
    final join = await SyncPairingService(
      storage: drive,
      vault: MemoryTokenStore(),
    ).prepare();
    expect(join.binding.workspace, current.workspace);
    expect(join.key.isStandard, isTrue);
  });

  test('ambiguous staged upload resumes same generation after restart; corrupt readback never deletes', () async {
    final old = await legacy();
    final reset = service();
    await reset.review();
    await reset.confirm();
    final id = (await reset.state())!['workspace'];
    drive.failAfterUpload = true;
    await expectLater(reset.resume(), throwsA(isA<CloudFailure>()));
    expect(drive.events, isNot(contains('delete')));
    drive.corruptSeed = true;
    await expectLater(service().resume(), throwsA(isA<FormatException>()));
    expect(drive.events, isNot(contains('upload:head')));
    expect(
      drive.objects.any(
        (o) => o.properties['workspaceId'] == old.binding.workspace,
      ),
      isTrue,
    );
    drive.corruptSeed = false;
    await service().resume();
    expect((await service().state())!['workspace'], id);
    expect((await service().state())!['phase'], 'complete');
  });

  test('cleanup failure leaves active verified new sync, retry is idempotent, legacy recreation cannot become active', () async {
    final old = await legacy();
    final oldObject = drive.objects.single;
    final oldBytes = drive.payloads[oldObject.id]!;
    final reset = service();
    await reset.review();
    await reset.confirm();
    drive.failDelete = true;
    await expectLater(
      reset.resume(),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.cleanup,
        ),
      ),
    );
    final next = (await pairing.saved())!;
    expect((await reset.state())!['phase'], 'cleanup');
    await pairing.verifyWorkspace(next.binding, next.key);
    await expectLater(
      pairing.verifyWorkspace(old.binding, old.key),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.stale,
        ),
      ),
    );
    drive.failDelete = false;
    await service().resume();
    await drive.upload(
      oldBytes,
      oldObject.properties,
      (_, _, _) {},
    ); // Unmodified old client recreates its old proof.
    final joined = await SyncPairingService(
      storage: drive,
      vault: MemoryTokenStore(),
    ).prepare();
    expect(joined.binding.workspace, next.binding.workspace);
    final engine = SyncEngine(
      repository: repository,
      storage: drive,
      recovery: backup,
      loadKey: pairing.loadKey,
      isUnlocked: () => true,
      verifyWorkspace: pairing.verifyWorkspace,
    );
    await engine.syncNow(manual: true);
    expect(engine.status.phase, SyncPhase.upToDate);
    await engine.close();
    await service().resume();
    expect(
      drive.objects.any(
        (o) => o.properties['workspaceId'] == old.binding.workspace,
      ),
      isFalse,
    );
    final fork = const Uuid().v4();
    await drive.upload(
      SyncGeneration.encode(
        account: 'mock-only',
        workspace: fork,
        parents: [],
        batches: 0,
        digest: '0' * 64,
      ),
      {
        'application': 'todorbit-sync',
        'kind': 'head',
        'protocol': '3',
        'workspaceId': fork,
        'batchId': fork,
      },
      (_, _, _) {},
    );
    await expectLater(
      pairing.verifyWorkspace(next.binding, next.key),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.conflict,
        ),
      ),
    );
    final selected = await service().review();
    expect((selected['parents'] as List).length, 2);
    await service().confirm();
    await service().resume();
    final latest = (await pairing.saved())!;
    await pairing.verifyWorkspace(latest.binding, latest.key);
    final afterFork = SyncEngine(
      repository: repository,
      storage: drive,
      recovery: backup,
      loadKey: pairing.loadKey,
      isUnlocked: () => true,
      verifyWorkspace: pairing.verifyWorkspace,
    );
    await afterFork.syncNow(manual: true);
    expect(afterFork.status.problem, isNull);
    await afterFork.close();
    expect(
      drive.objects.where((o) => o.properties['kind'] == 'head'),
      hasLength(3),
    );
  });

  test('private replacement uses fresh credentials; explicit reconnect preserves stale local offline records and old pairing', () async {
    final old = await legacy();
    final protectedOld = keys.value;
    final reset = service();
    await reset.review();
    final freshKey = SyncWorkspaceKey.generate();
    await reset.confirm(
      privateKey: freshKey,
      password: 'a new private test phrase',
    );
    drive.beforeOperation = () async {
      final before = await db
          .customSelect(
            'SELECT lease_heartbeat_ms FROM sync_capture_context WHERE id=1',
          )
          .getSingle();
      await Future<void>.delayed(const Duration(seconds: 9));
      final after = await db
          .customSelect(
            'SELECT lease_heartbeat_ms FROM sync_capture_context WHERE id=1',
          )
          .getSingle();
      expect(
        after.read<int>('lease_heartbeat_ms'),
        greaterThan(before.read<int>('lease_heartbeat_ms')),
      );
    };
    await reset.resume();
    final joined = await SyncPairingService(
      storage: drive,
      vault: MemoryTokenStore(),
    ).prepare(password: 'a new private test phrase');
    expect(joined.key.exportRecoveryCode(), freshKey.exportRecoveryCode());
    await keys.write(protectedOld!);
    // Use another disposable device DB to retain its old binding and local edits.
    final otherFile = File('${root.path}/stale.sqlite');
    final otherDb = AppDatabase(NativeDatabase(otherFile));
    try {
      final otherRepo = LifeRepository(otherDb),
          otherBackup = BackupService(otherFile);
      await otherRepo.addTask(const TaskDraft(title: 'Stale offline edit'));
      await otherRepo.activateSyncCapture(
        workspaceId: old.binding.workspace,
        accountId: old.binding.account,
        deviceId: old.binding.device,
        recovery: otherBackup,
      );
      final before = await databaseFingerprint(otherFile.path);
      final otherOperation = MemoryTokenStore();
      final otherPairing = SyncPairingService(
        storage: drive,
        vault: keys,
        resetVault: otherOperation,
      );
      final reconnect = SyncResetService(
        repository: otherRepo,
        recovery: otherBackup,
        pairing: otherPairing,
        vault: otherOperation,
        isUnlocked: () => true,
      );
      await expectLater(
        reconnect.reconnect(),
        throwsA(isA<SyncRecoveryRequired>()),
      );
      expect(keys.value, protectedOld);
      expect(otherOperation.value, isNull);
      await reconnect.reconnect(recoveryCode: freshKey.exportRecoveryCode());
      expect(await databaseFingerprint(otherFile.path), before);
      expect(
        (await otherRepo.syncExchangeStatus()).binding!.workspace,
        joined.binding.workspace,
      );
      expect((await reconnect.state())!['oldPairings'], contains(protectedOld));
      final nextLocal = (await otherRepo.syncExchangeStatus()).binding!;
      expect(nextLocal.device, isNot(old.binding.device));
      final engine = SyncEngine(
        repository: otherRepo,
        storage: drive,
        recovery: otherBackup,
        loadKey: otherPairing.loadKey,
        isUnlocked: () => true,
        verifyWorkspace: otherPairing.verifyWorkspace,
      );
      await engine.syncNow(manual: true);
      expect(engine.status.problem, isNull);
      expect((await otherRepo.syncExchangeStatus()).pending, 0);
      await engine.close();
      expect(
        await otherRepo.pendingSyncChanges(
          workspaceId: old.binding.workspace,
          accountId: old.binding.account,
        ),
        isNotEmpty,
      );
    } finally {
      await otherDb.close();
    }
  });

  test('wrong account, checkpoint damage, live lease and concurrent generation all block destructive work', () async {
    final old = await legacy();
    final reset = service();
    final review = await reset.review();
    await reset.confirm();
    drive.account = const CloudAccount('wrong', 'Wrong synthetic account');
    await expectLater(
      reset.resume(),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.account,
        ),
      ),
    );
    drive.account = const CloudAccount('mock-only', 'Synthetic account');
    final lease = await repository.acquireSyncLease(old.binding);
    await expectLater(reset.resume(), throwsA(isA<StateError>()));
    await repository.releaseSyncLease(lease!);
    final checkpoint = File(review['backup'] as String);
    final bytes = await checkpoint.readAsBytes();
    await checkpoint.writeAsBytes([0]);
    await expectLater(reset.resume(), throwsA(isA<StateError>()));
    await checkpoint.writeAsBytes(bytes);
    final other = const Uuid().v4();
    await drive.upload(
      SyncGeneration.encode(
        account: 'mock-only',
        workspace: other,
        parents: [],
        batches: 0,
        digest: '0' * 64,
      ),
      {
        'application': 'todorbit-sync',
        'kind': 'head',
        'protocol': '3',
        'workspaceId': other,
        'batchId': other,
      },
      (_, _, _) {},
    );
    await expectLater(
      reset.resume(),
      throwsA(
        isA<CloudFailure>().having(
          (e) => e.kind,
          'kind',
          CloudFailureKind.conflict,
        ),
      ),
    );
    expect(drive.events, isNot(contains('delete')));
  });

  test('error causes select distinct safe actions and never display raw exception secrets', () {
    for (final kind in CloudFailureKind.values) {
      final p = SyncProblem.from(
        CloudFailure('SECRET token or task content', kind: kind),
      );
      expect(p.title, isNotEmpty);
      expect(p.actionLabel, isNotEmpty);
      expect('${p.title} ${p.explanation}', isNot(contains('SECRET')));
    }
    expect(
      SyncProblem.from(const SocketException('SECRET')).action,
      SyncProblemAction.retry,
    );
    expect(
      SyncProblem.from(const SyncRecoveryRequired()).action,
      SyncProblemAction.unlock,
    );
    expect(
      SyncProblem.from(const FormatException('SECRET')).action,
      SyncProblemAction.recovery,
    );
    expect(
      SyncProblem.from(const CloudFailure('', kind: CloudFailureKind.stale))
          .action,
      SyncProblemAction.reconnect,
    );
    expect(
      SyncProblem.from(const CloudFailure('', kind: CloudFailureKind.cleanup))
          .action,
      SyncProblemAction.cleanup,
    );
  });
}
