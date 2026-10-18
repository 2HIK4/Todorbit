import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
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
}
