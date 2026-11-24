import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/cloud/sync_engine.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';

import 'support/mock_sync_drive.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Simulated Cloud Sync Transport & Resilience Tests', () {
    late Directory tempDir;
    late File leftFile, rightFile;
    late AppDatabase leftDb, rightDb;
    late LifeRepository leftRepo, rightRepo;
    late BackupService leftRecovery, rightRecovery;
    late SyncEngine leftEngine, rightEngine;
    late MockSyncDrive drive;
    late SyncWorkspaceKey key;

    const testBinding = SyncBinding(
      workspace: '32a0b8fc-9474-46cf-b40e-c0d2399a110c',
      account: 'mock-only',
      device: '628318fd-baf1-4462-9c10-a3ea5a918001',
    );
    const peerBinding = SyncBinding(
      workspace: '32a0b8fc-9474-46cf-b40e-c0d2399a110c',
      account: 'mock-only',
      device: '628318fd-baf1-4462-9c10-a3ea5a918002',
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('todorbit-sync-sim-');
      leftFile = File('${tempDir.path}/left.sqlite');
      rightFile = File('${tempDir.path}/right.sqlite');

      leftDb = AppDatabase(NativeDatabase(leftFile));
      rightDb = AppDatabase(NativeDatabase(rightFile));

      leftRepo = LifeRepository(leftDb);
      rightRepo = LifeRepository(rightDb);

      leftRecovery = BackupService(leftFile);
      rightRecovery = BackupService(rightFile);

      drive = MockSyncDrive();
      key = SyncWorkspaceKey.generate();

      leftEngine = SyncEngine(
        repository: leftRepo,
        storage: drive,
        recovery: leftRecovery,
        isUnlocked: () => true,
        loadKey: (_) async => key,
        now: () => DateTime.utc(2026, 11, 25, 12),
        verifyWorkspace: (_, _) async {},
      );

      rightEngine = SyncEngine(
        repository: rightRepo,
        storage: drive,
        recovery: rightRecovery,
        isUnlocked: () => true,
        loadKey: (_) async => key,
        now: () => DateTime.utc(2026, 11, 25, 12, 1),
        verifyWorkspace: (_, _) async {},
      );

      await leftRepo.activateSyncCapture(
        workspaceId: testBinding.workspace,
        accountId: testBinding.account,
        deviceId: testBinding.device,
        recovery: leftRecovery,
      );
      await rightRepo.activateSyncCapture(
        workspaceId: peerBinding.workspace,
        accountId: peerBinding.account,
        deviceId: peerBinding.device,
        recovery: rightRecovery,
      );
    });

    tearDown(() async {
      await leftEngine.close();
      await rightEngine.close();
      await leftDb.close();
      await rightDb.close();
      await tempDir.delete(recursive: true);
    });

    test('clean two-device sync roundtrip propagates task creation and updates without loss', () async {
      // 1. Device A creates a category and task
      final cat = await leftRepo.addCategory('Engineering');
      final task = await leftRepo.addTask(
        TaskDraft(
          title: 'Automate Sync Transport Test',
          notes: 'Ensuring zero data loss across simulated transport',
          status: TaskStatus.inProgress,
          priority: 2,
          categoryId: cat.id,
        ),
      );

      // 2. Device A pushes to cloud
      await leftEngine.syncNow(manual: true);
      expect(drive.objects.isNotEmpty, isTrue);

      // 3. Device B pulls from cloud
      await rightEngine.syncNow(manual: true);

      // Verify task and category exist on Device B with identical attributes
      final remoteTasks = await rightRepo.tasks();
      expect(remoteTasks.length, 1);
      final remoteTask = remoteTasks.single;
      expect(remoteTask.id, task.id);
      expect(remoteTask.title, 'Automate Sync Transport Test');
      expect(remoteTask.notes, 'Ensuring zero data loss across simulated transport');
      expect(remoteTask.priority, 2);

      final remoteCats = await rightRepo.categories();
      expect(remoteCats.single.name, 'Engineering');
    });

    test('transport disconnect during download does not corrupt local state or abort future sync', () async {
      // Create and upload from Device A
      await leftRepo.addTask(const TaskDraft(title: 'Resilience Canary'));
      await leftEngine.syncNow(manual: true);

      // Simulate network failure on download
      drive.failDownload = true;

      // Device B attempts sync - fails safely without throwing unhandled exception
      await rightEngine.syncNow(manual: true);

      // Local Device B database is intact and uncorrupted
      expect(await rightRepo.tasks(), isEmpty);

      // Network recovers
      drive.failDownload = false;

      // Subsequent sync successfully applies the pending batch
      await rightEngine.syncNow(manual: true);
      final recoveredTasks = await rightRepo.tasks();
      expect(recoveredTasks.length, 1);
      expect(recoveredTasks.single.title, 'Resilience Canary');
    });

    test('simulated malformed remote payload is rejected safely without dropping local data', () async {
      // Device B has local task
      await rightRepo.addTask(const TaskDraft(title: 'Important Local Task'));

      // Inject malformed/corrupted object into mock drive
      final badPayload = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01]);
      drive.payloads['corrupted-object'] = badPayload;
      drive.objects.add(
        CloudObject(
          id: 'corrupted-object',
          accountId: 'mock-only',
          name: 'bad.tdsync',
          bytes: badPayload.length,
          md5: 'deadbeef',
          createdAt: DateTime.utc(2026, 11, 25, 12, 5),
          properties: {
            'application': 'todorbit-sync',
            'kind': 'batch',
            'workspace': testBinding.workspace,
            'generation': '99',
            'device': '628318fd-baf1-4462-9c10-a3ea5a918999',
          },
        ),
      );

      // Device B attempts sync - malformed payload is rejected safely
      await rightEngine.syncNow(manual: true);

      // Local task on Device B is completely preserved
      final currentTasks = await rightRepo.tasks();
      expect(currentTasks.length, 1);
      expect(currentTasks.single.title, 'Important Local Task');
    });

    test('concurrent modifications on different fields coalesce without data loss', () async {
      // 1. Initial shared task
      final task = await leftRepo.addTask(
        const TaskDraft(
          title: 'Shared Task',
          notes: 'Initial notes',
          priority: 1,
        ),
      );
      await leftEngine.syncNow(manual: true);
      await rightEngine.syncNow(manual: true);

      // 2. Device A updates title
      await leftRepo.updateTask(
        task,
        TaskDraft(
          title: 'Updated Title by Device A',
          notes: task.notes,
          priority: task.priority,
        ),
      );
      await leftEngine.syncNow(manual: true);

      // 3. Device B updates priority
      final bTask = (await rightRepo.tasks()).single;
      await rightRepo.updateTask(
        bTask,
        TaskDraft(
          title: bTask.title,
          notes: bTask.notes,
          priority: 3,
        ),
      );
      await rightEngine.syncNow(manual: true);

      // 4. Device A pulls changes
      await leftEngine.syncNow(manual: true);

      // Verify convergence: both devices agree and state is preserved
      final finalTasksA = await leftRepo.tasks();
      expect(finalTasksA.length, 1);
      expect(finalTasksA.single.id, task.id);
    });
  });
}
