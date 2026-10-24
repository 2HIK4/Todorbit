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
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsWidgets);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      await controller.setHotkeys(
        HotkeyPreferences().withBinding(
          HotkeyAction.settings,
          const HotkeyBinding('T', shift: true),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
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
      expect(find.byTooltip('Duplicate preset'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Reset Create new task'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await controller.setHotkeys(
        controller.hotkeys.withBinding(
          HotkeyAction.newTask,
          const HotkeyBinding('T'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Reset Create new task'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Reset Create new task'));
      await tester.pumpAndSettle();
      expect(
        controller.hotkeys.bindings[HotkeyAction.newTask],
        HotkeyPreferences.defaults[HotkeyAction.newTask],
      );
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Reset Create new task'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
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
