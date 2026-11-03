import 'dart:io';
import 'dart:async';

import '../support/mock_sync_drive.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/domain/models.dart';

class _ScheduledEngine extends SyncEngine {
  _ScheduledEngine({
    required super.repository,
    required super.storage,
    required super.recovery,
    required super.loadKey,
    required super.now,
  }) : super(isUnlocked: () => true, verifyWorkspace: (_, _) async {});
  int attempts = 0;
  @override
  Future<void> syncNow({bool manual = false}) async {
    attempts++;
  }
}

void main() {
  late Directory root;
  late AppDatabase left, right;
  late LifeRepository sender, receiver;
  late BackupService leftRecovery, rightRecovery;
  late SyncEngine a, b;
  late MockSyncDrive drive;
  const first = SyncBinding(
    workspace: '32a0b8fc-9474-46cf-b40e-c0d2399a110c',
    account: 'mock-only',
    device: '628318fd-baf1-4462-9c10-a3ea5a918001',
  );
  const second = SyncBinding(
    workspace: '32a0b8fc-9474-46cf-b40e-c0d2399a110c',
    account: 'mock-only',
    device: '628318fd-baf1-4462-9c10-a3ea5a918002',
  );
  var unlocked = true;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-engine-mock-');
    final l = File('${root.path}/left.sqlite'),
        r = File('${root.path}/right.sqlite');
    left = AppDatabase(NativeDatabase(l));
    right = AppDatabase(NativeDatabase(r));
    sender = LifeRepository(left);
    receiver = LifeRepository(right);
    leftRecovery = BackupService(l);
    rightRecovery = BackupService(r);
    await sender.addTask(const TaskDraft(title: 'Synthetic local task'));
    await sender.activateSyncCapture(
      workspaceId: first.workspace,
      accountId: first.account,
      deviceId: first.device,
      recovery: leftRecovery,
    );
    await receiver.activateSyncCapture(
      workspaceId: second.workspace,
      accountId: second.account,
      deviceId: second.device,
      recovery: rightRecovery,
    );
    drive = MockSyncDrive();
    unlocked = true;
    final key = SyncWorkspaceKey.generate();
    a = SyncEngine(
      repository: sender,
      storage: drive,
      recovery: leftRecovery,
      loadKey: (_) async => key,
      isUnlocked: () => unlocked,
      verifyWorkspace: (_, _) async {},
    );
    b = SyncEngine(
      repository: receiver,
      storage: drive,
      recovery: rightRecovery,
      loadKey: (_) async => key,
      isUnlocked: () => unlocked,
      verifyWorkspace: (_, _) async {},
    );
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await left.close();
    await right.close();
    await root.delete(recursive: true);
  });
  test(
    'bounded shared exchange converges and duplicate clicks share one job',
    () async {
      final one = a.syncNow(manual: true), two = a.syncNow(manual: true);
      expect(identical(one, two), isTrue);
      await one;
      await b.syncNow(manual: true);
      expect((await receiver.tasks()).single.title, 'Synthetic local task');
      expect(b.status.phase, SyncPhase.upToDate);
      final downloads = drive.downloads;
      await b.syncNow(manual: true);
      expect(drive.downloads, downloads);
      expect((await receiver.tasks()), hasLength(1));
    },
  );
  testWidgets(
    'startup, active polling, debounced edits and throttled resume release timers on close',
    (tester) async {
      var clock = DateTime.utc(2026, 11, 3);
      final scheduled = _ScheduledEngine(
        repository: sender,
        storage: drive,
        recovery: leftRecovery,
        loadKey: a.loadKey,
        now: () => clock,
      );
      scheduled.start();
      scheduled.start();
      expect(scheduled.attempts, 1);
      scheduled.localChanged();
      scheduled.localChanged();
      await tester.pump(const Duration(milliseconds: 749));
      expect(scheduled.attempts, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(scheduled.attempts, 2);
      await tester.pump(const Duration(minutes: 2));
      expect(scheduled.attempts, 3);
      scheduled.setForeground(false);
      scheduled.localChanged();
      await tester.pump(const Duration(minutes: 4));
      expect(scheduled.attempts, 3);
      scheduled.setForeground(true);
      expect(scheduled.attempts, 4);
      scheduled.setForeground(false);
      scheduled.setForeground(true);
      expect(scheduled.attempts, 4);
      clock = clock.add(const Duration(seconds: 16));
      scheduled.setForeground(false);
      scheduled.setForeground(true);
      expect(scheduled.attempts, 5);
      await scheduled.close();
      await tester.pump(const Duration(minutes: 4));
      expect(scheduled.attempts, 5);
    },
  );

  test('committed edits during a running exchange schedule a follow-up instead of disappearing', () async {
    await sender.setAutomaticSync(first, true);
    final entered = Completer<void>(), release = Completer<void>();
    var proofs = 0;
    final queued = SyncEngine(
      repository: sender,
      storage: drive,
      recovery: leftRecovery,
      loadKey: a.loadKey,
      isUnlocked: () => true,
      changeDebounce: Duration.zero,
      verifyWorkspace: (_, _) async {
        if (++proofs == 1) {
          entered.complete();
          await release.future;
        }
      },
    );
    final secondCycle = queued.changes.firstWhere(
      (s) => proofs > 1 && s.phase == SyncPhase.upToDate,
    );
    try {
      final firstCycle = queued.syncNow();
      await entered.future;
      await sender.addTask(const TaskDraft(title: 'Committed while syncing'));
      queued.localChanged();
      release.complete();
      await firstCycle;
      await secondCycle.timeout(const Duration(seconds: 10));
      expect(proofs, 2);
      expect((await sender.syncExchangeStatus()).pending, 0);
    } finally {
      await queued.close();
    }
  });
  test(
    'ambiguous uploads retry exact ciphertext and cannot duplicate domain work',
    () async {
      drive.failAfterUpload = true;
      await a.syncNow(manual: true);
      expect(a.status.phase, SyncPhase.offline);
      final original = drive.payloads.values.single;
      final failed = await sender.syncExchangeStatus();
      expect(failed.pending, greaterThan(0));
      expect(failed.retryAt, isNotNull);
      await a.syncNow(manual: true);
      expect(drive.payloads.values.last, orderedEquals(original));
      await b.syncNow(manual: true);
      expect((await receiver.tasks()), hasLength(1));
      expect((await sender.syncExchangeStatus()).pending, 0);
    },
  );
  test('a failed page never advances its durable cursor; expired history rescans retained facts', () async {
    await a.syncNow(manual: true);
    drive.failDownload = true;
    await b.syncNow(manual: true);
    expect((await receiver.syncExchangeStatus()).changeToken, isNull);
    drive.failDownload = false;
    await b.syncNow(manual: true);
    expect((await receiver.tasks()), hasLength(1));
    drive.expired = true;
    await b.syncNow(manual: true);
    expect((await receiver.syncExchangeStatus()).changeToken, isNull);
    await b.syncNow(manual: true);
    expect((await receiver.tasks()), hasLength(1));
    expect((await receiver.syncExchangeStatus()).changeToken, isNotNull);
  });
  test(
    'lock, automatic opt-out and account mismatch perform no network exchange',
    () async {
      await a.syncNow();
      expect(drive.uploads, 0);
      unlocked = false;
      await a.syncNow(manual: true);
      expect(drive.uploads, 0);
      unlocked = true;
      drive.account = const CloudAccount(
        'different-account',
        'Synthetic other',
      );
      await a.syncNow(manual: true);
      expect(drive.uploads, 0);
      expect(drive.lists, 0);
      expect(a.status.phase, SyncPhase.disconnected);
    },
  );
  test('background budget yields without consuming queued bytes or adding failure backoff', () async {
    final bounded = SyncEngine(
      repository: sender,
      storage: drive,
      recovery: leftRecovery,
      loadKey: (_) async => SyncWorkspaceKey.generate(),
      isUnlocked: () => true,
      verifyWorkspace: (_, _) async {},
      timeBudget: Duration.zero,
    );
    try {
      await bounded.syncNow(manual: true);
      expect(bounded.status.phase, SyncPhase.pending);
      expect(drive.uploads, 0);
      expect((await sender.syncExchangeStatus()).retryAt, isNull);
      expect((await sender.syncExchangeStatus()).pending, greaterThan(0));
      expect(await sender.acquireSyncLease(first), isNotNull);
    } finally {
      await bounded.close();
    }
  });
  test('workspace verification failure is actionable and cannot upload queued edits', () async {
    final verified = SyncEngine(
      repository: sender,
      storage: drive,
      recovery: leftRecovery,
      loadKey: (_) async => SyncWorkspaceKey.generate(),
      isUnlocked: () => true,
      verifyWorkspace: (_, _) async =>
          throw const FormatException('Untrusted proof'),
    );
    try {
      await verified.syncNow(manual: true);
      expect(verified.status.phase, SyncPhase.needsAttention);
      expect(verified.status.notice, contains('could not be verified'));
      expect(drive.uploads, 0);
      expect((await sender.syncExchangeStatus()).pending, greaterThan(0));
    } finally {
      await verified.close();
    }
  });
  test('a changed background privacy policy fences a job before receiving remote content', () async {
    await a.syncNow(manual: true);
    var allowed = true;
    drive.beforeList = () async => allowed = false;
    final protected = SyncEngine(
      repository: receiver,
      storage: drive,
      recovery: rightRecovery,
      loadKey: (_) async => SyncWorkspaceKey.generate(),
      isUnlocked: () => true,
      canExchange: () async => allowed,
      verifyWorkspace: (_, _) async {},
    );
    try {
      await protected.syncNow(manual: true);
      expect(protected.status.phase, SyncPhase.error);
      expect(await receiver.tasks(), isEmpty);
      expect((await receiver.syncExchangeStatus()).changeToken, isNull);
      expect(drive.downloads, 0);
    } finally {
      await protected.close();
    }
  });
}
