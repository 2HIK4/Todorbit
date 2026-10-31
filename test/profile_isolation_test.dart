import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/profile_paths.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  test(
    'a new data root starts empty while an existing root keeps its task',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'life-manager-profile-',
      );
      try {
        final existingFile = AppDatabase.fileInDataRoot(
          '${root.path}${Platform.pathSeparator}existing',
        );
        final cleanFile = AppDatabase.fileInDataRoot(
          '${root.path}${Platform.pathSeparator}clean',
        );
        await existingFile.parent.create(recursive: true);
        final oldDatabase = AppDatabase(NativeDatabase(existingFile));
        await LifeRepository(oldDatabase)
            .addTask(const TaskDraft(title: 'Personal task'));
        await oldDatabase.close();

        expect(await cleanFile.exists(), isFalse);
        await cleanFile.parent.create(recursive: true);
        final freshDatabase = AppDatabase(NativeDatabase(cleanFile));
        expect(await LifeRepository(freshDatabase).tasks(), isEmpty);
        expect(await LifeRepository(freshDatabase).events(), isEmpty);
        await freshDatabase.close();

        final reopened = AppDatabase(NativeDatabase(existingFile));
        expect(
          (await LifeRepository(reopened).tasks()).single.title,
          'Personal task',
        );
        await reopened.close();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('profile database path requires an absolute data root', () {
    expect(() => AppDatabase.fileInDataRoot('relative'), throwsArgumentError);
  });

  test('legacy data is ignored until an explicit TodoPilot upgrade marker', () async {
    final root = await Directory.systemTemp.createTemp('todopilot-profile-');
    try {
      final legacy = ProfilePaths.legacyDatabaseIn(root.path);
      await legacy.parent.create(recursive: true);
      final oldDb = AppDatabase(NativeDatabase(legacy));
      await LifeRepository(oldDb)
          .addTask(const TaskDraft(title: 'Older private task'));
      await oldDb.close();

      final fresh = AppDatabase.fileInDataRoot(root.path);
      expect(
        fresh.path,
        contains('${Platform.pathSeparator}TodoPilot${Platform.pathSeparator}'),
      );
      await fresh.parent.create(recursive: true);
      final newDb = AppDatabase(NativeDatabase(fresh));
      try {
        final tables = await newDb
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'schema_version'",
            )
            .get();
        for (final entry in tables) {
          final table = entry.read<String>('name');
          final row = await newDb
              .customSelect('SELECT COUNT(*) AS total FROM $table')
              .getSingle();
          if (table == 'sync_capture_context') {
            final context = await newDb
                .customSelect('SELECT * FROM sync_capture_context')
                .getSingle();
            expect(context.data, {
              'id': 1,
              'workspace_id': null,
              'account_id': null,
              'device_id': null,
              'capture_enabled': 0,
              'applying_remote': 0,
              'restore_quarantined': 0,
              'device_sequence': 0,
              'observed_json': '{}',
              'received_json': '{}',
              'automatic_sync': 0,
              'change_token': null,
              'last_success_utc': null,
              'failure_count': 0,
              'next_attempt_utc': null,
              'last_error_code': null,
              'mutation_group': null,
              'lease_owner': null,
              'lease_until_ms': null,
              'lease_heartbeat_ms': null,
              'suspended_for_restore': 0,
            });
            expect(row.read<int>('total'), 1);
          } else {
            expect(row.read<int>('total'), 0, reason: table);
          }
        }
      } finally {
        await newDb.close();
      }
      final retained = AppDatabase(NativeDatabase(legacy));
      expect(await LifeRepository(retained).tasks(), isNotEmpty);
      await retained.close();

      final marker = File(
        '${fresh.parent.path}${Platform.pathSeparator}${ProfilePaths.markerName}',
      );
      await marker.writeAsString(
        jsonEncode({'profile': ProfilePaths.markerValue}),
      );
      expect(AppDatabase.fileInDataRoot(root.path).path, legacy.path);
      await marker.writeAsString('{"profile":"other"}');
      expect(AppDatabase.fileInDataRoot(root.path).path, fresh.path);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('separate portable locations select independent per-user profiles', () async {
    final root = await Directory.systemTemp.createTemp('todopilot-portable-');
    try {
      final first = Directory('${root.path}${Platform.pathSeparator}copy one');
      final second = Directory('${root.path}${Platform.pathSeparator}copy two');
      await first.create();
      await second.create();
      for (final directory in [first, second]) {
        await File(
          '${directory.path}${Platform.pathSeparator}${ProfilePaths.portableMarkerName}',
        ).writeAsString('Todorbit portable profile');
      }
      final firstProfile = ProfilePaths.activeDirectoryIn(
        root.path,
        executablePath: '${first.path}${Platform.pathSeparator}Todorbit.exe',
      );
      final secondProfile = ProfilePaths.activeDirectoryIn(
        root.path,
        executablePath: '${second.path}${Platform.pathSeparator}Todorbit.exe',
      );
      expect(firstProfile.path, isNot(secondProfile.path));
      expect(
        ProfilePaths.activeDirectoryIn(
          root.path,
          executablePath: '${first.path}${Platform.pathSeparator}Todorbit.exe',
        ).path,
        firstProfile.path,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
}
