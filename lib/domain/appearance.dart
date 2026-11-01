import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme_json.dart';
export 'theme_json.dart' show ThemeModePreference;

/// Version 1 themes contain colors only. Theme JSON is data, never executable.
class ThemePalette {
  const ThemePalette(this.colors);
  final Map<String, Color> colors;

  static const keys = themePaletteKeys;

  static const light = ThemePalette({
    'background': Color(0xFFF8F7FC),
    'surface': Color(0xFFFFFFFF),
    'accent': Color(0xFF6D56BD),
    'primaryText': Color(0xFF211B35),
    'secondaryText': Color(0xFF665F78),
    'border': Color(0xFFDCD7E9),
    'success': Color(0xFF267A56),
    'warning': Color(0xFF9B5F16),
    'error': Color(0xFFB63B53),
  });
  static const dark = ThemePalette({
    'background': Color(0xFF171420),
    'surface': Color(0xFF252131),
    'accent': Color(0xFFB9A4F4),
    'primaryText': Color(0xFFF4F0FC),
    'secondaryText': Color(0xFFC8C0D5),
    'border': Color(0xFF4C435C),
    'success': Color(0xFF80D4AC),
    'warning': Color(0xFFF3C37C),
    'error': Color(0xFFFF9BB0),
  });
  static const ocean = ThemePalette({
    'background': Color(0xFFF4F9FA),
    'surface': Color(0xFFFFFFFF),
    'accent': Color(0xFF006E82),
    'primaryText': Color(0xFF182F35),
    'secondaryText': Color(0xFF4B676D),
    'border': Color(0xFFBCD2D7),
    'success': Color(0xFF267A56),
    'warning': Color(0xFF9B5F16),
    'error': Color(0xFFB63B53),
  });
  static const dusk = ThemePalette({
    'background': Color(0xFF181F2A),
    'surface': Color(0xFF263241),
    'accent': Color(0xFF89C6E2),
    'primaryText': Color(0xFFF0F6FA),
    'secondaryText': Color(0xFFC4D1DA),
    'border': Color(0xFF4D6272),
    'success': Color(0xFF80D4AC),
    'warning': Color(0xFFF3C37C),
    'error': Color(0xFFFF9BB0),
  });

  Color operator [](String key) => colors[key]!;

  ThemePalette withColor(String key, Color value) {
    if (!keys.contains(key)) throw FormatException('Unknown color: $key');
    return ThemePalette({...colors, key: value});
  }

  Map<String, String> toJson() => {
    for (final key in keys)
      key:
          '#${colors[key]!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
  };

  factory ThemePalette.fromJson(Object? source) => ThemePalette({
    for (final entry in normalizeThemePaletteJson(source).entries)
      entry.key: Color(int.parse('FF${entry.value.substring(1)}', radix: 16)),
  });

  double contrast(String foreground, String background) {
    double luminance(Color color) {
      double channel(int value) {
        final x = value / 255;
        return x <= 0.04045
            ? x / 12.92
            : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
      }

      final argb = color.toARGB32();
      return 0.2126 * channel((argb >> 16) & 255) +
          0.7152 * channel((argb >> 8) & 255) +
          0.0722 * channel(argb & 255);
    }

    final a = luminance(this[foreground]);
    final b = luminance(this[background]);
    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }
}

class ThemeCustomization {
  const ThemeCustomization({
    this.light = ThemePalette.light,
    this.dark = ThemePalette.dark,
    this.presets = const {},
    this.author,
    this.authorProfile,
    this.compact = false,
    this.textScale = 1,
    this.sidebarWidth = 238,
    this.openingScreen = 'today',
    this.calendarDefaultView = 'week',
    this.reducedMotion = false,
    this.widgetOpacity = 100,
  });
  final ThemePalette light;
  final ThemePalette dark;
  final Map<String, ThemePalette> presets;
  final String? author;
  final Uri? authorProfile;
  final bool compact;
  final double textScale;
  final int sidebarWidth;
  final String openingScreen;
  final String calendarDefaultView;
  final bool reducedMotion;
  final int widgetOpacity;

  ThemeCustomization copyWith({
    ThemePalette? light,
    ThemePalette? dark,
    Map<String, ThemePalette>? presets,
    bool? compact,
    double? textScale,
    int? sidebarWidth,
    String? openingScreen,
    String? calendarDefaultView,
    bool? reducedMotion,
    int? widgetOpacity,
  }) => ThemeCustomization(
    light: light ?? this.light,
    dark: dark ?? this.dark,
    presets: presets ?? this.presets,
    author: author,
    authorProfile: authorProfile,
    compact: compact ?? this.compact,
    textScale: textScale ?? this.textScale,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    openingScreen: openingScreen ?? this.openingScreen,
    calendarDefaultView: calendarDefaultView ?? this.calendarDefaultView,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    widgetOpacity: widgetOpacity ?? this.widgetOpacity,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'light': light.toJson(),
    'dark': dark.toJson(),
    'presets': {
      for (final entry in presets.entries) entry.key: entry.value.toJson(),
    },
    'author': ?author,
    if (authorProfile != null) 'authorProfile': authorProfile.toString(),
    'compact': compact,
    'textScale': textScale,
    'sidebarWidth': sidebarWidth,
    'openingScreen': openingScreen,
    'calendarDefaultView': calendarDefaultView,
    'reducedMotion': reducedMotion,
    'widgetOpacity': widgetOpacity,
  };

  factory ThemeCustomization.fromJson(Object? source) {
    final value = normalizeThemeCustomizationJson(source);
    return ThemeCustomization(
      light: ThemePalette.fromJson(value['light']),
      dark: ThemePalette.fromJson(value['dark']),
      presets: {
        for (final entry
            in (value['presets'] as Map<String, Map<String, String>>).entries)
          entry.key: ThemePalette.fromJson(entry.value),
      },
      author: value['author'] as String?,
      authorProfile: value['authorProfile'] == null
          ? null
          : Uri.parse(value['authorProfile'] as String),
      compact: value['compact'] as bool,
      textScale: value['textScale'] as double,
      sidebarWidth: value['sidebarWidth'] as int,
      openingScreen: value['openingScreen'] as String,
      calendarDefaultView: value['calendarDefaultView'] as String,
      reducedMotion: value['reducedMotion'] as bool,
      widgetOpacity: value['widgetOpacity'] as int,
    );
  }
}
