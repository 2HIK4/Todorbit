import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_backup_codec.dart';
import 'package:life_manager/data/cloud/cloud_backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/profile_fingerprint.dart';
import 'package:life_manager/domain/models.dart';

import 'cloud_test_fakes.dart';

// Transfer-safety tests isolate disk/race behavior; real encryption is exercised
// by cloud_backup_test.dart rather than repeating PBKDF2 in each race fixture.
class _FastCodec extends CloudBackupCodec {
  @override
  Future<Uint8List> encrypt(
    Map<String, dynamic> manifest,
    String passphrase,
  ) async => Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
  @override
  Future<Map<String, dynamic>> decrypt(
    Uint8List bytes,
    String passphrase,
  ) async => jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

class _PausedCloud extends MemoryCloud {
  final started = Completer<void>();
  final resume = Completer<void>();
  bool fail = false;
  @override
  Future<CloudObject> upload(
    Uint8List bytes,
    Map<String, String> properties,
    CloudProgress progress,
  ) async {
    if (!started.isCompleted) started.complete();
    await resume.future;
    if (fail) throw const CloudFailure('Fixture network failure');
    return super.upload(bytes, properties, progress);
  }
}

void main() {
  late Directory root;
  late AppDatabase database;
  late LifeRepository repository;
  late BackupService local;
  const settings =
      '{"format":"test","categories":{"appearance":{"mode":"dark"}}}';
  void progress(String stage, int done, int total) {}
  CloudBackupService service(MemoryCloud provider) => CloudBackupService(
    local: local,
    provider: provider,
    appVersion: '1.0.18',
    codec: _FastCodec(),
  );
  Future<CloudObject> upload(CloudBackupService cloud) => cloud.backUp(
    kind: CloudBackupKind.full,
    settings: settings,
    passphrase: 'fixture passphrase',
    progress: progress,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-transfer-safety-');
    local = BackupService(File('${root.path}/life.sqlite'));
    database = AppDatabase(NativeDatabase(local.databaseFile));
    repository = LifeRepository(database);
    await repository.addTask(const TaskDraft(title: 'Keep my local work'));
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'checkpoint survives VACUUM, detects data and portable setting edits',
    () async {
      final cloud = service(MemoryCloud());
      expect((await cloud.history.status(settings)).localChanges, isNull);
      await upload(cloud);
      final status = await cloud.history.status(settings);
      expect(status.lastBackup, isNotNull);
      expect(status.lastRestore, isNull);
      expect(status.localChanges, isFalse);
      final snapshot = await local.createBackup(BackupKind.manual);
      expect(
        await databaseFingerprint(snapshot.file.path),
        await databaseFingerprint(local.databaseFile.path),
      );
      expect(
        (await cloud.history.status(
          '{"categories":{"appearance":{"mode":"dark"}},"format":"test"}',
        )).localChanges,
        isFalse,
      );
      expect(
        (await cloud.history.status(settings.replaceFirst('dark', 'light')))
            .localChanges,
        isTrue,
      );
      await repository.addTask(const TaskDraft(title: 'Offline work'));
      expect((await cloud.history.status(settings)).localChanges, isTrue);
    },
  );

  test('writes during upload remain dirty and parallel service instances are blocked', () async {
    final provider = _PausedCloud();
    final cloud = service(provider);
    final pending = upload(cloud);
    await provider.started.future;
    await expectLater(upload(service(provider)), throwsA(isA<CloudFailure>()));
    await repository.addTask(const TaskDraft(title: 'Edit during upload'));
    provider.resume.complete();
    final first = await pending;
    expect((await cloud.history.status(settings)).localChanges, isTrue);
    final second = await upload(cloud);
    expect(second.id, isNot(first.id));
    expect(provider.objects, hasLength(2));
    expect((await cloud.history.status(settings)).localChanges, isFalse);
  });

  test(
    'failed upload releases lock without recording a successful backup',
    () async {
      final provider = _PausedCloud()..fail = true;
      final cloud = service(provider);
      provider.resume.complete();
      await expectLater(upload(cloud), throwsA(isA<CloudFailure>()));
      expect((await cloud.history.status(settings)).lastBackup, isNull);
      provider.fail = false;
      await upload(cloud);
      expect((await cloud.history.status(settings)).localChanges, isFalse);
    },
  );

  test(
    'editing after preview refuses scheduling without touching active records',
    () async {
      final cloud = service(MemoryCloud());
      final object = await upload(cloud);
      final preview = await cloud.preview(object, 'fixture', progress);
      await repository.addTask(const TaskDraft(title: 'Newer local edit'));
      await expectLater(cloud.scheduleRestore(preview), throwsStateError);
      expect(await local.hasScheduledRestore(), isFalse);
      expect(
        await database.customSelect('SELECT title FROM tasks').get(),
        hasLength(2),
      );
      expect((await cloud.history.status(settings)).lastRestore, isNull);
    },
  );

  test('editing after confirmation refuses startup replacement and keeps recovery copy', () async {
    final cloud = service(MemoryCloud());
    final object = await upload(cloud);
    await cloud.scheduleRestore(
      await cloud.preview(object, 'fixture', progress),
    );
    await expectLater(upload(cloud), throwsA(isA<CloudFailure>()));
    await repository.addTask(const TaskDraft(title: 'Work after scheduling'));
    await database.close();
    await expectLater(
      local.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      ),
      throwsStateError,
    );
    database = AppDatabase(NativeDatabase(local.databaseFile));
    expect(
      await database.customSelect('SELECT title FROM tasks').get(),
      hasLength(2),
    );
    expect(
      (await local.list()).where((r) => r.kind == BackupKind.beforeRestore),
      isNotEmpty,
    );
    expect(await local.hasScheduledRestore(), isTrue);
    await local.cancelScheduledRestore();
    expect((await cloud.history.status(settings)).lastRestore, isNull);
  });

  test('restore is successful only after apply and reopen, then detects later edits', () async {
    final cloud = service(MemoryCloud());
    final object = await upload(cloud);
    await repository.addTask(const TaskDraft(title: 'Explicitly replace this'));
    await cloud.scheduleRestore(
      await cloud.preview(object, 'fixture', progress),
    );
    expect((await cloud.history.status(settings)).lastRestore, isNull);
    await database.close();
    await local.applyScheduledRestore(
      appSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    database = AppDatabase(NativeDatabase(local.databaseFile));
    repository = LifeRepository(database);
    expect(
      await database.customSelect('SELECT title FROM tasks').get(),
      hasLength(1),
    );
    await local.markRestoreOpened();
    final status = await cloud.history.status(settings);
    expect(status.lastRestore, isNotNull);
    expect(status.localChanges, isFalse);
    await repository.addTask(const TaskDraft(title: 'Next device session'));
    expect((await cloud.history.status(settings)).localChanges, isTrue);
  });

  test(
    'preferences changed during review or before restart prevent replacement',
    () async {
      final cloud = service(MemoryCloud());
      final object = await upload(cloud);
      final preview = await cloud.preview(object, 'fixture', progress);
      final appearance = File('${root.path}/appearance-settings.json');
      await appearance.writeAsString('{"theme":"dark"}');
      await expectLater(cloud.scheduleRestore(preview), throwsStateError);
      await cloud.scheduleRestore(
        await cloud.preview(object, 'fixture', progress),
      );
      await appearance.writeAsString('{"theme":"light"}');
      await database.close();
      await expectLater(
        local.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        ),
        throwsStateError,
      );
      database = AppDatabase(NativeDatabase(local.databaseFile));
      expect(await appearance.readAsString(), contains('light'));
      expect(
        await database.customSelect('SELECT title FROM tasks').get(),
        hasLength(1),
      );
      expect((await cloud.history.status(settings)).lastRestore, isNull);
    },
  );
}
