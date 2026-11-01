import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_view_preferences.dart';

void main() {
  test(
    'headless preference projection preserves local metadata and widget layout',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-sync-preferences-',
      );
      final database = AppDatabase(NativeDatabase.memory());
      final appearance = AppearancePreferenceStore(
        File('${root.path}/appearance.json'),
      );
      final calendar = CalendarPreferenceStore(
        File('${root.path}/calendar.json'),
      );
      final repository = LifeRepository(database);
      final controller = AppController(
        repository,
        appearanceStore: appearance,
        calendarPreferenceStore: calendar,
      );
      try {
        await appearance.saveCustomization(
          ThemeCustomization(
            author: 'Local author',
            authorProfile: Uri.parse('https://example.com/local'),
            sidebarWidth: 300,
            openingScreen: 'inbox',
            widgetOpacity: 72,
          ),
        );
        await appearance.saveLastCalendarMode('month');
        await repository.savePortablePreferences({
          'theme': 'dark',
          'customization': const ThemeCustomization(
            textScale: 1.2,
            sidebarWidth: 200,
            openingScreen: 'today',
            widgetOpacity: 20,
          ).toJson(),
          'calendarContent': 'tasksOnly',
          'lastCalendarMode': null,
        });
        await controller.applyPortablePreferences();
        expect(await appearance.load(), ThemeModePreference.dark);
        expect(await calendar.load(), CalendarContent.tasksOnly);
        expect(await appearance.loadLastCalendarMode(), isNull);
        final projected = await appearance.loadCustomization();
        expect(projected.textScale, 1.2);
        expect(projected.author, 'Local author');
        expect(projected.authorProfile.toString(), 'https://example.com/local');
        expect(projected.sidebarWidth, 300);
        expect(projected.openingScreen, 'inbox');
        expect(projected.widgetOpacity, 72);
        final wire =
            (await repository.portablePreferences())['customization'] as Map;
        expect(wire.keys, isNot(contains('author')));
        expect(wire.keys, isNot(contains('sidebarWidth')));
        expect(wire.keys, isNot(contains('widgetOpacity')));
      } finally {
        controller.dispose();
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );
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
      expect(
        first.taskViewPreferences.newTaskPlannedDay,
        NewTaskPlannedDay.today,
      );
      await first.setTaskViewPreferences(
        const TaskViewPreferences(
          newTaskPlannedDay: NewTaskPlannedDay.noDate,
          keepCompletedVisible: true,
          compositionTextDisplay: CompositionTextDisplay.full,
        ),
      );
      final persisted = await secondProcessStore.loadTaskViewPreferences();
      expect(persisted.newTaskPlannedDay, NewTaskPlannedDay.noDate);
      expect(persisted.keepCompletedVisible, isTrue);
      expect(persisted.compositionTextDisplay, CompositionTextDisplay.full);
      expect(await secondProcessStore.load(), ThemeModePreference.light);
    } finally {
      await firstDatabase.close();
      await directory.delete(recursive: true);
    }
  });
}
