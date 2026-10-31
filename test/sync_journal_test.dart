import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_schema.dart';
import 'package:life_manager/data/profile_fingerprint.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import 'support/legacy_sync_fixture.dart';

void main() {
  late Directory root;
  late File file;
  late AppDatabase db;
  late LifeRepository repository;
  const workspace = 'b08c9595-3b39-4c33-9914-591eb469ed81';
  const device = 'c07545ea-63c2-46e6-b84e-205a11e9ed42';
  Future<List<Map<String, Object?>>> pending() => repository.pendingSyncChanges(
    workspaceId: workspace,
    accountId: 'disposable-account',
  );
  Future<BackupRecord?> activate() => repository.activateSyncCapture(
    workspaceId: workspace,
    accountId: 'disposable-account',
    deviceId: device,
    recovery: BackupService(file),
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-journal-');
    file = File('${root.path}/life.sqlite');
    db = AppDatabase(NativeDatabase(file));
    repository = LifeRepository(db);
    await repository.tasks();
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('schema 22 upgrades with record IDs and managed bytes intact', () async {
    final task = await repository.addTask(
      const TaskDraft(title: 'Public beta data'),
    );
    final attachment = File('${root.path}/old.bin')
      ..writeAsBytesSync([0, 255, 8]);
    final resource = await repository.attachManagedFile(task.id, attachment);
    await db.close();
    final old = sqlite.sqlite3.open(file.path);
    try {
      stripSyncSchemaForLegacyFixture(old);
      old.execute('PRAGMA user_version=22');
    } finally {
      old.close();
    }
    final recovery = await BackupService(
      file,
    ).ensureAutomaticBackup(appSchemaVersion: AppDatabase.currentSchemaVersion);
    expect(recovery!.schemaVersion, 22);
    db = AppDatabase(NativeDatabase(file));
    repository = LifeRepository(db);
    expect((await repository.tasks()).single.id, task.id);
    final content = await db
        .customSelect('SELECT content FROM task_resources')
        .getSingle();
    expect(content.data['content'], [0, 255, 8]);
    expect((await repository.taskResources(task.id)).single.id, resource.id);
    expect(await pending(), isEmpty);
    expect((await db.customSelect('PRAGMA foreign_key_check').get()), isEmpty);
  });

  test('default capture is off; activation seeds IDs after a verified recovery snapshot', () async {
    final task = await repository.addTask(
      const TaskDraft(title: 'Existing local work'),
    );
    expect(await pending(), isEmpty);
    final before = await activate();
    expect(before, isNotNull);
    expect(
      await databaseFingerprint(before!.file.path),
      await databaseFingerprint(file.path),
    );
    final recovery = sqlite.sqlite3.open(
      before.file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(recovery.select('SELECT id FROM tasks').single['id'], task.id);
      expect(
        recovery
            .select('SELECT capture_enabled FROM sync_capture_context')
            .single
            .values
            .single,
        0,
      );
      expect(
        recovery.select('PRAGMA integrity_check').single.values.single,
        'ok',
      );
    } finally {
      recovery.close();
    }
    final seeded = (await pending())
        .where((entry) => entry['entity'] == 'tasks')
        .single;
    expect(jsonDecode(seeded['record_key'] as String), {'id': task.id});
    expect(
      (jsonDecode(seeded['after_json'] as String) as Map)['title'],
      'Existing local work',
    );
    expect(
      Uuid.isValidUUID(fromString: seeded['operation_id'] as String),
      isTrue,
    );
    final count = (await pending()).length;
    expect(await activate(), isNull);
    expect(await pending(), hasLength(count));
    final triggers = await db
        .customSelect(
          "SELECT name FROM sqlite_schema WHERE type='trigger' AND name LIKE 'sync_capture_%'",
        )
        .get();
    expect(triggers, hasLength(portableSyncTables.length * 3));
  });

  test(
    'mutation, revision ancestry and journal roll back as one transaction',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Keep'));
      await activate();
      final initial = (await pending())
          .where((r) => r['entity'] == 'tasks')
          .single;
      await expectLater(
        db.transaction(() async {
          await db.customStatement('UPDATE tasks SET title=? WHERE id=?', [
            'Aborted',
            task.id,
          ]);
          throw StateError('synthetic interruption before commit');
        }),
        throwsStateError,
      );
      expect((await repository.tasks()).single.title, 'Keep');
      expect(
        (await pending()).where((r) => r['entity'] == 'tasks'),
        hasLength(1),
      );
      await repository.updateTask(
        (await repository.tasks()).single,
        const TaskDraft(title: 'Committed'),
      );
      final changes = (await pending())
          .where((r) => r['entity'] == 'tasks')
          .toList();
      expect(changes, hasLength(2));
      expect(changes.last['parent_id'], initial['operation_id']);
      expect(
        (jsonDecode(changes.last['before_json'] as String) as Map)['title'],
        'Keep',
      );
    },
  );

  test(
    'separate native connection changes are durable across app reopen',
    () async {
      final task = await repository.addTask(
        const TaskDraft(title: 'Before native edit'),
      );
      await activate();
      await db.close();
      final native = sqlite.sqlite3.open(file.path);
      try {
        native.execute('UPDATE tasks SET title=? WHERE id=?', [
          'Native edit',
          task.id,
        ]);
      } finally {
        native.close();
      }
      db = AppDatabase(NativeDatabase(file));
      repository = LifeRepository(db);
      expect((await repository.tasks()).single.title, 'Native edit');
      final changes = (await pending())
          .where((r) => r['entity'] == 'tasks')
          .toList();
      expect(changes, hasLength(2));
      expect(changes.last['parent_id'], changes.first['operation_id']);
      expect(changes.last['workspace_id'], workspace);
    },
  );

  test(
    'managed bytes and deletion tombstones retain exact before values',
    () async {
      final task = await repository.addTask(
        const TaskDraft(title: 'With attachment'),
      );
      await activate();
      final attachment = File('${root.path}/fixture.bin')
        ..writeAsBytesSync([0, 1, 255, 4]);
      final resource = await repository.attachManagedFile(task.id, attachment);
      final entry = (await pending())
          .where((r) => r['entity'] == 'task_resources')
          .single;
      expect(
        ((jsonDecode(entry['after_json'] as String) as Map)['content']
            as Map)[r'$blob'],
        '0001FF04',
      );
      await db.customStatement('DELETE FROM task_resources WHERE id=?', [
        resource.id,
      ]);
      final deleted = (await pending())
          .where((r) => r['entity'] == 'task_resources')
          .last;
      expect(deleted['after_json'], isNull);
      expect(deleted['before_json'], entry['after_json']);
      expect(deleted['parent_id'], entry['operation_id']);
    },
  );

  test('restored journal is retained and quarantined before app use', () async {
    await repository.addTask(const TaskDraft(title: 'Source'));
    await activate();
    final service = BackupService(file);
    final snapshot = await service.createBackup(BackupKind.manual);
    final retained = await pending();
    await repository.addTask(const TaskDraft(title: 'Newer target work'));
    await service.scheduleRestore(
      snapshot,
      appSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    await db.close();
    final beforeRestore = await service.applyScheduledRestore(
      appSchemaVersion: AppDatabase.currentSchemaVersion,
    );
    expect(beforeRestore, isNotNull);
    db = AppDatabase(NativeDatabase(file));
    repository = LifeRepository(db);
    final context = await db
        .customSelect('SELECT * FROM sync_capture_context')
        .getSingle();
    expect(context.read<int>('capture_enabled'), 0);
    expect(context.read<int>('restore_quarantined'), 1);
    expect(await pending(), retained);
    await expectLater(activate(), throwsStateError);
    expect((await repository.tasks()).single.title, 'Source');
    final recovery = sqlite.sqlite3.open(
      beforeRestore!.file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(recovery.select('SELECT * FROM tasks'), hasLength(2));
    } finally {
      recovery.close();
    }
  });

  test(
    'device file references are excluded; HTTPS links are portable',
    () async {
      final task = await repository.addTask(
        const TaskDraft(title: 'Resources'),
      );
      final localFile = File('${root.path}/private-local-path.txt')
        ..writeAsStringSync('device only');
      await repository.addExternalResource(
        task.id,
        TaskResourceKind.externalFile,
        localFile.path,
      );
      await activate();
      expect(
        (await pending()).where((r) => r['entity'] == 'task_resources'),
        isEmpty,
      );
      await repository.addExternalResource(
        task.id,
        TaskResourceKind.externalFolder,
        root.path,
      );
      expect(
        (await pending()).where((r) => r['entity'] == 'task_resources'),
        isEmpty,
      );
      await repository.addExternalResource(
        task.id,
        TaskResourceKind.url,
        'https://example.test/portable',
      );
      expect(
        (await pending()).where((r) => r['entity'] == 'task_resources'),
        hasLength(1),
      );
    },
  );

  test('composite or primary-key moves retain an old-key tombstone', () async {
    final task = await repository.addTask(
      const TaskDraft(title: 'Moved identity fixture'),
    );
    await activate();
    const nextId = 'be18a3dd-d795-42be-beb5-5161c9c20f3e';
    await db.customStatement('UPDATE tasks SET id=? WHERE id=?', [
      nextId,
      task.id,
    ]);
    final entries = (await pending())
        .where((r) => r['entity'] == 'tasks')
        .toList();
    expect(entries, hasLength(3));
    expect(jsonDecode(entries[1]['record_key'] as String), {'id': task.id});
    expect(entries[1]['after_json'], isNull);
    expect(entries[1]['parent_id'], entries[0]['operation_id']);
    expect(jsonDecode(entries[2]['record_key'] as String), {'id': nextId});
    expect(entries[2]['before_json'], isNull);
    expect(entries[2]['parent_id'], isNull);
  });

  test('account rebinding refuses to discard queued operations', () async {
    await repository.addTask(const TaskDraft(title: 'Offline work'));
    await activate();
    final retained = await pending();
    await expectLater(
      repository.activateSyncCapture(
        workspaceId: workspace,
        accountId: 'other-account',
        deviceId: device,
        recovery: BackupService(file),
      ),
      throwsStateError,
    );
    expect(await pending(), retained);
    expect(
      await repository.pendingSyncChanges(
        workspaceId: workspace,
        accountId: 'other-account',
      ),
      isEmpty,
    );
  });
}
