import 'package:flutter/material.dart';

import '../../domain/appearance.dart';
import 'desktop_tooltip_theme.dart';

ThemeData buildAppTheme(
  Brightness brightness,
  ThemePalette palette, {
  bool android = false,
  bool compact = false,
}) {
  // Custom colors replace the seed's tonal backgrounds. Select the stronger
  // black/white contrast for their foregrounds as well (at least 4.5:1).
  Color foregroundOn(Color background) {
    final luminance = background.computeLuminance();
    return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05)
        ? Colors.black
        : Colors.white;
  }

  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette['accent'],
        brightness: brightness,
      ).copyWith(
        surface: palette['surface'],
        surfaceContainerLowest: palette['background'],
        surfaceContainerLow: Color.lerp(
          palette['background'],
          palette['surface'],
          0.5,
        ),
        surfaceContainer: palette['surface'],
        surfaceContainerHigh: Color.lerp(
          palette['surface'],
          palette['secondaryText'],
          0.06,
        ),
        surfaceContainerHighest: Color.lerp(
          palette['surface'],
          palette['secondaryText'],
          0.1,
        ),
        onSurface: palette['primaryText'],
        onSurfaceVariant: palette['secondaryText'],
        primary: palette['accent'],
        onPrimary: foregroundOn(palette['accent']),
        outline: palette['border'],
        outlineVariant: palette['border'],
        error: palette['error'],
        onError: foregroundOn(palette['error']),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final typography = text.copyWith(
    headlineMedium: text.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.4,
    ),
    headlineSmall: text.headlineSmall?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleLarge: text.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleMedium: text.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleSmall: text.titleSmall?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: text.bodyMedium?.copyWith(
      fontSize: android ? 15 : 14,
      height: 1.45,
    ),
    bodySmall: text.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    ),
    labelSmall: text.labelSmall?.copyWith(
      fontSize: 12,
      height: 1.35,
      color: scheme.onSurfaceVariant,
    ),
  );
  return ThemeData(
    useMaterial3: true,
    visualDensity: !android && compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    colorScheme: scheme,
    materialTapTargetSize: android ? MaterialTapTargetSize.padded : null,
    iconButtonTheme: android
        ? IconButtonThemeData(
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          )
        : null,
    textButtonTheme: android
        ? TextButtonThemeData(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          )
        : null,
    tooltipTheme: desktopTooltipTheme(scheme),
    scaffoldBackgroundColor: palette['background'],
    textTheme: typography,
    listTileTheme: ListTileThemeData(
      titleTextStyle: typography.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: typography.bodySmall,
      iconColor: scheme.onSurfaceVariant,
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: typography.titleLarge,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      helperStyle: typography.bodySmall,
      helperMaxLines: 4,
      errorMaxLines: 4,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      childrenPadding: EdgeInsets.symmetric(vertical: 12),
      shape: Border(),
      collapsedShape: Border(),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette['surface'],
      titleTextStyle: typography.titleLarge,
      contentTextStyle: typography.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, android ? 48 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, android ? 48 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}
