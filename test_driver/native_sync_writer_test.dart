import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/profile_paths.dart';
import 'package:life_manager/domain/appearance.dart';

void main() {
  test('native Release theme writes commit journal groups and fail before JSON projection', () async {
    final executable = File(
      Platform.environment['TODORBIT_NATIVE_SYNC_EXECUTABLE'] ?? '',
    );
    expect(
      executable.path,
      executable.absolute.path,
      reason: 'Supply the exact absolute Release executable through TODORBIT_NATIVE_SYNC_EXECUTABLE.',
    );
    expect(await executable.exists(), isTrue);
    final root = await Directory.systemTemp.createTemp('todorbit-native-sync-');
    final local = Directory('${root.path}/Local')..createSync();
    final profile = ProfilePaths.activeDirectoryIn(
      root.path,
      executablePath: executable.path,
    )..createSync(recursive: true);
    final database = AppDatabase(
      NativeDatabase(File('${profile.path}/life_manager.sqlite')),
    );
    final repository = LifeRepository(database);
    final appearance = AppearancePreferenceStore(
      File('${profile.path}/appearance-settings.json'),
    );
    try {
      await repository.savePortablePreference('theme', 'dark');
      await appearance.save(ThemeModePreference.dark);
      await repository.activateSyncCapture(
        workspaceId: '70390cf5-3f5b-4478-a381-a14fc7f4d50f',
        accountId: 'mock-native-writer',
        deviceId: 'f7d5bbfc-65fd-4abe-872d-1d491254b256',
        recovery: BackupService(File('${profile.path}/life_manager.sqlite')),
      );
      Future<ProcessResult> command(String value) => Process.run(
        executable.path,
        ['--widget-command', 'theme-$value'],
        environment: {
          'APPDATA': root.absolute.path,
          'LOCALAPPDATA': local.absolute.path,
        },
      );
      final baseline =
          (await database
                  .customSelect('SELECT COUNT(*) AS n FROM sync_journal')
                  .getSingle())
              .read<int>('n');
      expect((await command('light')).exitCode, 0);
      expect((await repository.portablePreferences())['theme'], 'light');
      expect(await appearance.load(), ThemeModePreference.light);
      final journal = await database
          .customSelect(
            'SELECT j.after_json,g.complete FROM sync_journal j JOIN sync_mutation_groups g ON g.id=j.mutation_group_id ORDER BY j.sequence DESC LIMIT 1',
          )
          .getSingle();
      expect(journal.read<int>('complete'), 1);
      expect(
        (jsonDecode(journal.read<String>('after_json')) as Map)['value_json'],
        '"light"',
      );
      expect(
        (await database
                .customSelect('SELECT COUNT(*) AS n FROM sync_journal')
                .getSingle())
            .read<int>('n'),
        baseline + 1,
      );
      expect((await command('light')).exitCode, 0);
      expect(
        (await database
                .customSelect('SELECT COUNT(*) AS n FROM sync_journal')
                .getSingle())
            .read<int>('n'),
        baseline + 1,
      );
      final originalJson = await appearance.file.readAsString();
      await database.customStatement(
        "CREATE TRIGGER block_native_preference BEFORE UPDATE ON portable_preferences BEGIN SELECT RAISE(ABORT,'Synthetic failure'); END",
      );
      expect((await command('dark')).exitCode, isNot(0));
      expect(await appearance.file.readAsString(), originalJson);
      expect((await repository.portablePreferences())['theme'], 'light');
      expect(
        (await database
                .customSelect('SELECT mutation_group FROM sync_capture_context')
                .getSingle())
            .data['mutation_group'],
        isNull,
      );
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        AppDatabase.currentSchemaVersion,
      );
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
