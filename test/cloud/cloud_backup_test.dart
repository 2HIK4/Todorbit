import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/cloud/cloud_backup_codec.dart';
import 'package:life_manager/data/cloud/cloud_backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/goals.dart';
import 'package:life_manager/domain/habits.dart';
import 'package:life_manager/domain/hotkeys.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'cloud_test_fakes.dart';

class _ManifestCodec extends CloudBackupCodec {
  _ManifestCodec(this.manifest);
  final Map<String, dynamic> manifest;
  @override
  Future<Map<String, dynamic>> decrypt(
    Uint8List bytes,
    String passphrase,
  ) async => manifest;
}

AppController controllerFor(
  AppDatabase db,
  Directory directory,
  BackupService service,
) => AppController(
  LifeRepository(db),
  backupService: service,
  appearanceStore: AppearancePreferenceStore(
    File('${directory.path}/appearance.json'),
  ),
  calendarPreferenceStore: CalendarPreferenceStore(
    File('${directory.path}/calendar.json'),
  ),
);

Map<String, List<Map<String, Object?>>> databaseRows(File file) {
  final db = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    final names = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return {
      for (final row in names)
        row['name'] as String: db
            .select('SELECT * FROM "${row['name']}" ORDER BY rowid')
            .map((r) => Map<String, Object?>.from(r))
            .toList(),
    };
  } finally {
    db.close();
  }
}

void main() {
  const passphrase = 'separate recovery phrase 2026';
  void progress(String stage, int done, int total) {}

  test(
    'future schema is rejected before staging or altering the local profile',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-cloud-future-',
      );
      final file = File('${root.path}/life.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      final provider = MemoryCloud();
      try {
        await LifeRepository(db).addTask(const TaskDraft(title: 'Keep local'));
        final schema = AppDatabase.currentSchemaVersion + 1;
        final object = await provider.upload(Uint8List.fromList([1]), {
          'backupId': 'id',
          'kind': 'full',
          'appVersion': 'future',
          'schema': '$schema',
        }, progress);
        final local = BackupService(file);
        final service = CloudBackupService(
          local: local,
          provider: provider,
          appVersion: 'test',
          codec: _ManifestCodec({
            'id': 'id',
            'kind': 'full',
            'appVersion': 'future',
            'schema': schema,
          }),
        );
        await expectLater(
          service.preview(object, 'unused', progress),
          throwsA(isA<CloudFailure>()),
        );
        expect((await LifeRepository(db).tasks()).single.title, 'Keep local');
        expect(await local.list(), isEmpty);
        expect(await local.hasScheduledRestore(), isFalse);
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );

  test('encrypted full backup round trip restores all SQLite tables and portable settings to a fresh profile', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-cloud-roundtrip-',
    );
    final first = await Directory('${root.path}/source').create();
    final fresh = await Directory('${root.path}/fresh').create();
    final sourceFile = File('${first.path}/life.sqlite');
    final targetFile = File('${fresh.path}/life.sqlite');
    final source = AppDatabase(NativeDatabase(sourceFile));
    var target = AppDatabase(NativeDatabase(targetFile));
    final sourceLocal = BackupService(sourceFile),
        targetLocal = BackupService(targetFile);
    final cloud = MemoryCloud();
    final controller = controllerFor(source, first, sourceLocal);
    AppController? restored;
    try {
      await controller.initialize();
      final repo = controller.repository;
      final category = await repo.addCategory('Test category');
      final project = await repo.addProject(category.id, 'Test project');
      final rule = RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-10-25',
        maxOccurrences: 3,
      );
      await repo.addRecurringTask(
        TaskDraft(
          title: 'Recurring test',
          categoryId: category.id,
          projectId: project.id,
          scheduledDate: '2026-10-25',
        ),
        rule,
      );
      await repo.ensureRecurringTasks('2026-10-25', '2026-10-31');
      await repo.addTaskWithComposition(
        const TaskDraft(title: 'Parent'),
        ['One', 'Two'],
        [const TaskDraft(title: 'Child')],
      );
      await repo.addEvent(
        EventDraft(
          title: 'Fixed event',
          startsAt: DateTime(2026, 10, 25, 9),
          endsAt: DateTime(2026, 10, 25, 10),
          categoryId: category.id,
        ),
      );
      await repo.addHabit(
        HabitDraft(
          title: 'Read',
          kind: HabitKind.binary,
          rule: RecurrenceRule(
            kind: RecurrenceKind.daily,
            startDate: '2026-10-25',
          ),
        ),
      );
      await repo.addGoal(
        const GoalDraft(title: 'Learn', target: 5, startDate: '2026-10-25'),
      );
      await controller.setTheme(ThemeModePreference.dark);
      await controller.setFirstWeekday(1);
      await controller.setHotkeys(HotkeyPreferences().saveAs('Writing'));
      final settings = SettingsTransfer.fromController(controller)
          .encode(SettingsCategory.values.toSet());
      final sourceService = CloudBackupService(
        local: sourceLocal,
        provider: cloud,
        appVersion: 'test-1',
      );
      final uploaded = await sourceService.backUp(
        kind: CloudBackupKind.full,
        settings: settings,
        passphrase: passphrase,
        progress: progress,
      );
      expect(
        utf8.decode(cloud.content[uploaded.id]!),
        isNot(contains('Recurring test')),
      );
      expect(
        utf8.decode(cloud.content[uploaded.id]!),
        isNot(contains(passphrase)),
      );
      final sourceSnapshot = (await sourceLocal.list()).single;
      final expected = databaseRows(sourceSnapshot.file);
      await LifeRepository(target)
          .addTask(const TaskDraft(title: 'Fresh sentinel'));
      final targetService = CloudBackupService(
        local: targetLocal,
        provider: cloud,
        appVersion: 'test-1',
      );
      await expectLater(
        targetService.preview(uploaded, 'wrong phrase here', progress),
        throwsA(isA<CloudFailure>()),
      );
      expect(
        (await LifeRepository(target).tasks()).single.title,
        'Fresh sentinel',
      );
      final preview = await targetService.preview(
        uploaded,
        passphrase,
        progress,
      );
      final transfer = SettingsTransfer.decode(
        preview.manifest['settings'] as String,
      );
      expect(preview.summary!.counts['tasks'], greaterThan(0));
      await targetService.scheduleRestore(preview);
      expect(
        (await LifeRepository(target).tasks()).single.title,
        'Fresh sentinel',
      );
      await target.close();
      final before = await targetLocal.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      expect(before!.kind, BackupKind.beforeRestore);
      expect(
        databaseRows(before.file)['tasks']!.single['title'],
        'Fresh sentinel',
      );
      expect(databaseRows(targetFile), expected);
      expect(await targetLocal.restoreStatus(), isNull);
      expect(
        await targetLocal.restoredPortableSettings(),
        preview.manifest['settings'],
      );
      target = AppDatabase(NativeDatabase(targetFile));
      restored = controllerFor(target, fresh, targetLocal);
      await restored.initialize();
      await transfer.applyTo(restored, transfer.categories.keys.toSet());
      await targetLocal.markRestoreOpened();
      expect(
        await targetLocal.restoreStatus(),
        contains('opened successfully'),
      );
      expect(restored.theme, ThemeModePreference.dark);
      expect(restored.firstWeekday, 1);
      expect(restored.hotkeys.activePreset, 'Writing');
      expect(
        (await restored.repository.tasks()).map((t) => t.id).toSet(),
        expected['tasks']!.map((row) => row['id']).toSet(),
      );
      expect(await targetLocal.restoredPortableSettings(), isNull);
      expect(await File('${fresh.path}/cloud-profile-id').exists(), isFalse);
    } finally {
      controller.dispose();
      restored?.dispose();
      await source.close();
      await target.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('settings-only encrypted round trip selectively applies and merges without database edits', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-cloud-settings-',
    );
    final file = File('${root.path}/life.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    final local = BackupService(file);
    final current = controllerFor(db, root, local);
    final cloud = MemoryCloud();
    final service = CloudBackupService(
      local: local,
      provider: cloud,
      appVersion: 'test-1',
    );
    try {
      await current.initialize();
      await current.repository.addTask(
        const TaskDraft(title: 'Private task sentinel'),
      );
      await current.setFirstWeekday(1);
      await current.setHotkeys(HotkeyPreferences().saveAs('Writing'));
      final encoded = SettingsTransfer.fromController(current)
          .encode({SettingsCategory.calendar, SettingsCategory.hotkeys});
      expect(encoded, isNot(contains('Private task sentinel')));
      final uploaded = await service.backUp(
        kind: CloudBackupKind.settings,
        settings: encoded,
        passphrase: passphrase,
        progress: progress,
      );
      expect(await local.list(), isEmpty);
      await current.setFirstWeekday(7);
      final before = databaseRows(file);
      final preview = await service.preview(uploaded, passphrase, progress);
      expect(preview.snapshot, isNull);
      expect(preview.manifest.containsKey('database'), isFalse);
      final settings = SettingsTransfer.decode(
        preview.manifest['settings'] as String,
      );
      await settings.applyTo(current, {
        SettingsCategory.hotkeys,
      }, mergeHotkeys: true);
      expect(
        current.hotkeys.presets.keys,
        containsAll(['Writing', 'Writing (2)']),
      );
      expect(current.firstWeekday, 7);
      await settings.applyTo(current, {SettingsCategory.calendar});
      expect(current.firstWeekday, 1);
      expect(databaseRows(file), before);
    } finally {
      current.dispose();
      await db.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('codec rejects tampering, future formats, changed checksums and short passphrases', () async {
    final codec = CloudBackupCodec();
    final manifest = <String, dynamic>{
      'format': 'todorbit-cloud-package',
      'version': 1,
      'id': 'id',
      'profileId': 'profile',
      'appVersion': 'test',
      'createdAt': '2026-10-25T09:00:00Z',
      'kind': 'settings',
      'schema': 21,
      'settings': '{}',
    };
    await expectLater(
      codec.encrypt(manifest, 'short'),
      throwsA(isA<CloudFailure>()),
    );
    final bytes = await codec.encrypt(manifest, passphrase);
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final ciphertext = base64Decode(envelope['ciphertext'] as String)..[0] ^= 1;
    envelope['ciphertext'] = base64Encode(ciphertext);
    await expectLater(
      codec.decrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
        passphrase,
      ),
      throwsA(isA<CloudFailure>()),
    );
    envelope['format'] = 'future-format';
    await expectLater(
      codec.decrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
        passphrase,
      ),
      throwsA(isA<CloudFailure>()),
    );
    expect(
      () => CloudBackupCodec.validateManifest({...manifest, 'version': 2}),
      throwsFormatException,
    );
    expect(
      () => CloudBackupCodec.validateManifest({
        ...manifest,
        'kind': 'full',
        'database': base64Encode([1]),
        'databaseBytes': 1,
        'databaseSha256': 'bad',
      }),
      throwsFormatException,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
