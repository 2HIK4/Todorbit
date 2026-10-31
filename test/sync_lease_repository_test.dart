import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  const binding = SyncBinding(
    workspace: '0b88ee31-7b7b-4dbe-9f0c-6b45e8ee1925',
    account: 'mocked-lease-only',
    device: '01f9d40b-cf23-471c-b9c8-701f788ef3a4',
  );
  late Directory root;
  late AppDatabase first, second;
  late LifeRepository left, right;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-sync-lease-');
    final file = File('${root.path}/synthetic.sqlite');
    final initial = AppDatabase(NativeDatabase(file));
    try {
      final repository = LifeRepository(initial);
      await repository.addTask(
        const TaskDraft(title: 'Original offline action'),
      );
      await repository.activateSyncCapture(
        workspaceId: binding.workspace,
        accountId: binding.account,
        deviceId: binding.device,
        recovery: BackupService(file),
      );
    } finally {
      await initial.close();
    }
    first = AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA busy_timeout=5000');
          db.execute('PRAGMA journal_mode=WAL');
        },
      ),
    );
    second = AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA busy_timeout=5000');
          db.execute('PRAGMA journal_mode=WAL');
        },
      ),
    );
    left = LifeRepository(first);
    right = LifeRepository(second);
  });
  tearDown(() async {
    await first.close();
    await second.close();
    await root.delete(recursive: true);
  });

  test('independent SQLite engines elect exactly one concurrent job', () async {
    final now = DateTime.now().toUtc();
    final leases = await Future.wait([
      left.acquireSyncLease(binding, now: now),
      right.acquireSyncLease(binding, now: now),
    ]);
    expect(leases.whereType<SyncLease>(), hasLength(1));
    final winner = leases.whereType<SyncLease>().single;
    expect(await left.syncLeaseIsCurrent(winner, now: now), isTrue);
    await right.addTask(
      const TaskDraft(title: 'User writes while exchange owns lease'),
    );
    expect(await left.tasks(), hasLength(2));
    await right.releaseSyncLease(winner);
    expect(await left.acquireSyncLease(binding, now: now), isNotNull);
  });

  test('expired owner cannot renew or release its successor', () async {
    final now = DateTime.now().toUtc();
    final old = (await left.acquireSyncLease(binding, now: now))!;
    final later = now.add(const Duration(seconds: 31));
    final successor = (await right.acquireSyncLease(binding, now: later))!;
    expect(successor.owner, isNot(old.owner));
    expect(await left.renewSyncLease(old, now: later), isFalse);
    await left.releaseSyncLease(old);
    expect(await right.syncLeaseIsCurrent(successor, now: later), isTrue);
  });

  test(
    'heartbeat extends ownership without allowing overlapping acquisition',
    () async {
      final now = DateTime.now().toUtc();
      final lease = (await left.acquireSyncLease(binding, now: now))!;
      expect(
        await right.renewSyncLease(
          lease,
          now: now.add(const Duration(seconds: 20)),
        ),
        isTrue,
      );
      expect(
        await left.acquireSyncLease(
          binding,
          now: now.add(const Duration(seconds: 31)),
        ),
        isNull,
      );
      expect(
        await left.syncLeaseIsCurrent(
          lease,
          now: now.add(const Duration(seconds: 51)),
        ),
        isFalse,
      );
    },
  );

  test(
    'backward wall clock jump allows recovery and fences the old job',
    () async {
      final now = DateTime.now().toUtc();
      final old = (await left.acquireSyncLease(binding, now: now))!;
      final backwards = now.subtract(const Duration(hours: 1));
      expect(await left.syncLeaseIsCurrent(old, now: backwards), isFalse);
      final next = (await right.acquireSyncLease(binding, now: backwards))!;
      expect(await left.renewSyncLease(old, now: backwards), isFalse);
      expect(await right.syncLeaseIsCurrent(next, now: backwards), isTrue);
    },
  );

  test(
    'lost ownership fences acknowledgement and retains identical retry bytes',
    () async {
      final key = SyncWorkspaceKey.generate();
      final lease = (await left.acquireSyncLease(binding))!;
      await expectLater(
        right.prepareNextSyncBatch(binding, key),
        throwsStateError,
      );
      final batch = (await left.prepareNextSyncBatch(
        binding,
        key,
        lease: lease,
      ))!;
      await first.customStatement(
        'UPDATE sync_capture_context SET lease_until_ms=0 WHERE id=1',
      );
      final next = (await right.acquireSyncLease(binding))!;
      final object = CloudObject(
        id: 'mocked-verified',
        accountId: binding.account,
        name: 'batch.tdsync',
        bytes: batch.bytes.length,
        createdAt: DateTime.now().toUtc(),
        md5: crypto.md5.convert(batch.bytes).toString(),
        properties: {
          ...batch.properties,
          'application': 'todorbit-sync',
          'verified': 'true',
        },
      );
      await expectLater(
        left.acknowledgeSyncBatch(batch, object, lease: lease),
        throwsStateError,
      );
      expect(
        await left.pendingSyncChanges(
          workspaceId: binding.workspace,
          accountId: binding.account,
        ),
        hasLength(1),
      );
      final resumed = (await right.prepareNextSyncBatch(
        binding,
        key,
        lease: next,
      ))!;
      expect(resumed.bytes, batch.bytes);
      await right.acknowledgeSyncBatch(resumed, object, lease: next);
      expect(
        await left.pendingSyncChanges(
          workspaceId: binding.workspace,
          accountId: binding.account,
        ),
        isEmpty,
      );
    },
  );

  test(
    'restore quarantine revokes exchange while preserving its lease receipt',
    () async {
      final lease = (await left.acquireSyncLease(binding))!;
      await right.quarantineRestoredSync();
      expect(await left.syncLeaseIsCurrent(lease), isFalse);
      expect(await left.renewSyncLease(lease), isFalse);
      await expectLater(right.acquireSyncLease(binding), throwsStateError);
      await left.releaseSyncLease(lease);
      expect(
        (await second
                .customSelect('SELECT lease_owner FROM sync_capture_context')
                .getSingle())
            .readNullable<String>('lease_owner'),
        isNull,
      );
    },
  );
}
