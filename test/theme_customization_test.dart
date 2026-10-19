import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/domain/appearance.dart';

void main() {
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
