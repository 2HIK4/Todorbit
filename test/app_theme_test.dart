import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/shared/app_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return (first > second ? first + .05 : second + .05) /
      (first > second ? second + .05 : first + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('${brightness.name} built-in text and action foregrounds meet AA', () {
      final palette = brightness == Brightness.dark
          ? ThemePalette.dark
          : ThemePalette.light;
      final theme = buildAppTheme(brightness, palette);
      for (final background in [
        theme.colorScheme.surface,
        theme.scaffoldBackgroundColor,
      ]) {
        expect(
          contrast(theme.textTheme.bodyMedium!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(theme.textTheme.bodySmall!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(theme.colorScheme.error, theme.colorScheme.onError),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  test('custom palettes retain their text, surface and action colors', () {
    final palette = ThemePalette.dark.withColor(
      'accent',
      const Color(0xffe0a030),
    );
    final theme = buildAppTheme(Brightness.dark, palette, android: true);
    expect(theme.colorScheme.primary, palette['accent']);
    expect(theme.textTheme.bodySmall!.color, palette['secondaryText']);
    expect(theme.dialogTheme.backgroundColor, palette['surface']);
    expect(
      contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
  });
}
