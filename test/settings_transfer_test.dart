import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/hotkeys.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';

void main() {
  test(
    'shareable settings export is allowlisted and imports selected categories',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'todorbit-settings-',
      );
      final db = AppDatabase(NativeDatabase.memory());
      final appearance = AppearancePreferenceStore(
        File('${directory.path}/appearance.json'),
      );
      final calendar = CalendarPreferenceStore(
        File('${directory.path}/calendar.json'),
      );
      final controller = AppController(
        LifeRepository(db),
        appearanceStore: appearance,
        calendarPreferenceStore: calendar,
      );
      try {
        await controller.initialize();
        await controller.setHotkeys(
          HotkeyPreferences()
              .saveAs('Writing')
              .withBinding(HotkeyAction.newTask, const HotkeyBinding('T')),
        );
        await controller.setFirstWeekday(1);
        final transfer = SettingsTransfer.fromController(controller);
        final encoded = transfer.encode(SettingsCategory.values.toSet());
        expect(encoded, isNot(contains('pinHash')));
        expect(encoded, isNot(contains('life_manager.sqlite')));
        expect(encoded, isNot(contains('tasks":')));
        final file = File('${directory.path}/settings.json');
        await transfer.exportTo(file, {
          SettingsCategory.hotkeys,
          SettingsCategory.calendar,
        });
        final loaded = await SettingsTransfer.read(file);
        expect(loaded.categories.keys, {
          SettingsCategory.hotkeys,
          SettingsCategory.calendar,
        });
        await controller.setHotkeys(HotkeyPreferences());
        await controller.setFirstWeekday(7);
        await loaded.applyTo(controller, {SettingsCategory.hotkeys});
        expect(controller.hotkeys.activePreset, 'Writing');
        expect(controller.firstWeekday, 7);
        await loaded.applyTo(controller, {SettingsCategory.calendar});
        expect(controller.firstWeekday, 1);
        expect((await appearance.loadHotkeys()).activePreset, 'Writing');
        expect(await appearance.loadFirstWeekday(), 1);
        await loaded.applyTo(controller, {
          SettingsCategory.hotkeys,
        }, mergeHotkeys: true);
        expect(controller.hotkeys.presets.containsKey('Writing (2)'), isTrue);
        expect(controller.hotkeys.activePreset, 'Writing');
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('settings import rejects newer, malformed, and oversized files', () {
    expect(() => SettingsTransfer.decode('{'), throwsFormatException);
    expect(
      () => SettingsTransfer.decode(
        '{"format":"todorbit-shareable-settings","version":2,"categories":{}}',
      ),
      throwsFormatException,
    );
    expect(
      () => SettingsTransfer.decode('x' * (SettingsTransfer.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test('legacy theme JSON imports as appearance only', () {
    final theme = ThemeCustomization(
      light: ThemePalette.ocean,
      dark: ThemePalette.dusk,
    );
    final transfer = SettingsTransfer.decode(jsonEncode(theme.toJson()));
    expect(transfer.categories.keys, {SettingsCategory.appearance});
    expect(transfer.categories[SettingsCategory.appearance]!['mode'], isNull);
  });
}
