import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';

void main() {
  test('appearance persists and synchronizes between process stores', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-manager-appearance-test-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}appearance.json',
    );
    final firstDatabase = AppDatabase(NativeDatabase.memory());
    final first = AppController(
      LifeRepository(firstDatabase),
      appearanceStore: AppearancePreferenceStore(file),
    );
    try {
      await first.initialize();
      await first.setTheme(ThemeModePreference.dark);
      final secondProcessStore = AppearancePreferenceStore(file);
      expect(await secondProcessStore.load(), ThemeModePreference.dark);

      await secondProcessStore.save(ThemeModePreference.light);
      await first.reloadTheme();
      expect(first.theme, ThemeModePreference.light);
      expect(
        await AppearancePreferenceStore(file).load(),
        ThemeModePreference.light,
      );
    } finally {
      await firstDatabase.close();
      await directory.delete(recursive: true);
    }
  });
}
