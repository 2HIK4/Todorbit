import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/settings/theme_dialog.dart';

void main() {
  testWidgets(
    'palette reset selects Silver and preserves density and presets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final controller = AppController(LifeRepository(database));
      final savedPalette = ThemePalette.graphiteViolet;
      await controller.saveCustomization(
        ThemeCustomization(
          light: ThemePalette.ocean,
          dark: savedPalette,
          compact: true,
          presets: {'Saved violet': savedPalette},
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: ThemeDialog())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset both palettes'));
      await tester.pumpAndSettle();
      expect(controller.customization.dark, savedPalette);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final applied = controller.customization;
      expect(applied.light, ThemePalette.light);
      expect(applied.dark, ThemePalette.graphiteSilver);
      expect(applied.compact, isTrue);
      expect(applied.presets['Saved violet'], savedPalette);
    },
  );

  test('separate palettes and theme mode survive restart', () async {
    final directory = await Directory.systemTemp.createTemp('todopilot-theme-');
    addTearDown(() => directory.delete(recursive: true));
    final store = AppearancePreferenceStore(
      File('${directory.path}/appearance.json'),
    );
    await store.save(ThemeModePreference.dark);
    final customization = ThemeCustomization(
      light: ThemePalette.light.withColor('accent', const Color(0xFF123456)),
      dark: ThemePalette.dark.withColor('accent', const Color(0xFFABCDEF)),
      calendarDefaultView: 'month',
      reducedMotion: true,
    );
    await store.saveCustomization(customization);
    expect(await store.load(), ThemeModePreference.dark);
    final reloaded = await store.loadCustomization();
    expect(reloaded.light.toJson()['accent'], '#123456');
    expect(reloaded.dark.toJson()['accent'], '#ABCDEF');
    expect(reloaded.widgetOpacity, 100);
    expect(reloaded.calendarDefaultView, 'month');
    expect(reloaded.reducedMotion, isTrue);
    await store.saveCustomization(reloaded.copyWith(widgetOpacity: 35));
    expect((await store.loadCustomization()).widgetOpacity, 35);
    await store.save(ThemeModePreference.light);
    expect(
      (await store.loadCustomization()).dark.toJson()['accent'],
      '#ABCDEF',
    );
  });

  test('the stored Beta 27 dark palette retains its explicit colors', () {
    const prior = ThemeCustomization(
      dark: ThemePalette.beta27Dark,
      compact: true,
    );
    final restored = ThemeCustomization.fromJson(prior.toJson());
    expect(restored.dark.toJson(), ThemePalette.beta27Dark.toJson());
    expect(restored.dark.toJson(), isNot(ThemePalette.dark.toJson()));
    expect(restored.compact, isTrue);
  });

  test('built-in dark choices keep text and controls readable on surfaces', () {
    expect(const ThemeCustomization().dark, ThemePalette.dark);
    expect(
      ThemePalette.darkPresets['Graphite Neutral Silver'],
      ThemePalette.dark,
    );
    expect(ThemePalette.dark['accent'], const Color(0xFFC8CDD2));
    final violet = ThemePalette.darkPresets['Graphite Violet']!;
    expect(violet['accent'], const Color(0xFFB4ABEE));
    final stored = ThemeCustomization(dark: violet, compact: true);
    final restored = ThemeCustomization.fromJson(stored.toJson());
    expect(restored.dark.toJson(), violet.toJson());
    expect(restored.compact, isTrue);
    for (final entry in ThemePalette.darkPresets.entries) {
      final palette = entry.value;
      for (final background in ['background', 'surface']) {
        for (final foreground in [
          'primaryText',
          'secondaryText',
          'accent',
          'warning',
          'error',
        ]) {
          expect(
            palette.contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: $foreground on $background',
          );
        }
      }
      final label = palette['primaryText'].computeLuminance();
      final selection = Color.lerp(
        palette['surface'],
        palette['accent'],
        .24,
      )!.computeLuminance();
      expect(
        (label + .05) / (selection + .05),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key}: selected label',
      );
    }
  });

  test('theme import rejects malformed and unsupported content', () {
    final value = const ThemeCustomization().toJson();
    expect(
      ThemeCustomization.fromJson(jsonDecode(jsonEncode(value))).light.toJson(),
      ThemePalette.light.toJson(),
    );
    expect(
      () => ThemeCustomization.fromJson({...value, 'version': 2}),
      throwsFormatException,
    );
    final light = {...ThemePalette.light.toJson(), 'accent': 'javascript:bad'};
    expect(
      () => ThemeCustomization.fromJson({...value, 'light': light}),
      throwsFormatException,
    );
    expect(
      () => ThemeCustomization.fromJson({
        ...value,
        'calendarDefaultView': 'decade',
      }),
      throwsFormatException,
    );
  });

  test(
    'task panel width is device-local and keeps existing appearance',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'todorbit-panel-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/appearance.json');
      final store = AppearancePreferenceStore(file);
      expect(await store.loadTaskPanelWidth(), isNull);
      await Future.wait([
        store.save(ThemeModePreference.dark),
        store.saveCustomization(const ThemeCustomization(sidebarWidth: 260)),
        store.saveTaskPanelWidth(470),
      ]);

      final reopened = AppearancePreferenceStore(file);
      expect(await reopened.loadTaskPanelWidth(), 470);
      expect(await reopened.load(), ThemeModePreference.dark);
      expect((await reopened.loadCustomization()).sidebarWidth, 260);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(json['customization'], isNot(contains('taskPanelWidth')));
      await file.writeAsString(jsonEncode({...json, 'taskPanelWidth': -1}));
      expect(
        await AppearancePreferenceStore(file).loadTaskPanelWidth(),
        isNull,
      );
    },
  );

  test('contrast calculation warns for low contrast', () {
    final bad = ThemePalette.light.withColor(
      'primaryText',
      ThemePalette.light['surface'],
    );
    expect(bad.contrast('primaryText', 'surface'), closeTo(1, 0.01));
    expect(
      ThemePalette.light.contrast('primaryText', 'surface'),
      greaterThan(4.5),
    );
  });
}
