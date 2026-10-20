import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/main.dart';

import 'test_privacy.dart';

import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/domain/hotkeys.dart';

void main() {
  testWidgets('configured Settings shortcut opens a real dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Appearance & Themes'), findsWidgets);
      expect(find.text('Hotkeys'), findsWidgets);
      await tester.tap(find.text('Hotkeys').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit hotkeys'), findsOneWidget);
      await tester.tap(find.text('Edit hotkeys'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save as new preset'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  test('bindings validate conflicts and reserved editing keys', () {
    final defaults = HotkeyPreferences();
    expect(defaults.bindings[HotkeyAction.newTask]!.display, 'Ctrl+N');
    expect(HotkeyBinding.supported['N'], LogicalKeyboardKey.keyN);
    expect(HotkeyBinding.parse('Ctrl+C'), isNull);
    expect(HotkeyBinding.parse('Alt+Tab'), isNull);
    expect(
      () => defaults.withBinding(
        HotkeyAction.newTask,
        defaults.bindings[HotkeyAction.quickSearch]!,
      ),
      throwsFormatException,
    );
    final custom = defaults.withBinding(
      HotkeyAction.newTask,
      const HotkeyBinding('T', shift: true),
    );
    expect(custom.activePreset, 'Custom');
    expect(custom.bindings[HotkeyAction.newTask]!.display, 'Ctrl+Shift+T');
  });

  test(
    'named shortcut presets persist and can be renamed and deleted',
    () async {
      final directory = await Directory.systemTemp.createTemp('hotkeys-test-');
      final store = AppearancePreferenceStore(
        File('${directory.path}/appearance.json'),
      );
      try {
        final saved = HotkeyPreferences()
            .withBinding(HotkeyAction.newTask, const HotkeyBinding('T'))
            .saveAs('Writing');
        await store.saveHotkeys(saved);
        final loaded = await store.loadHotkeys();
        expect(loaded.activePreset, 'Writing');
        expect(loaded.bindings[HotkeyAction.newTask]!.display, 'Ctrl+T');
        final renamed = loaded.rename('Writing', 'Planning');
        expect(renamed.activePreset, 'Planning');
        expect(renamed.delete('Planning').activePreset, 'Default');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
