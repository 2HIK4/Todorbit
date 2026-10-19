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
      for (final table in [
        'tasks',
        'fixed_events',
        'goals',
        'habits',
        'work_sessions',
      ]) {
        final row = await newDb
            .customSelect('SELECT COUNT(*) AS total FROM $table')
            .getSingle();
        expect(row.read<int>('total'), 0, reason: table);
      }
      await newDb.close();
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
}
