import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ThemeModePreference { system, light, dark }

/// Version 1 themes contain colors only. Theme JSON is data, never executable.
class ThemePalette {
  const ThemePalette(this.colors);
  final Map<String, Color> colors;

  static const keys = <String>[
    'background',
    'surface',
    'accent',
    'primaryText',
    'secondaryText',
    'border',
    'success',
    'warning',
    'error',
  ];

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

  factory ThemePalette.fromJson(Object? source) {
    if (source is! Map<String, dynamic> ||
        source.length != keys.length ||
        source.keys.any((key) => !keys.contains(key))) {
      throw const FormatException(
        'Theme colors must contain the nine supported tokens',
      );
    }
    final colors = <String, Color>{};
    for (final key in keys) {
      final raw = source[key];
      if (raw is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(raw)) {
        throw FormatException('Invalid $key color');
      }
      colors[key] = Color(int.parse('FF${raw.substring(1)}', radix: 16));
    }
    return ThemePalette(colors);
  }

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
    if (source is! Map<String, dynamic> || source['version'] != 1) {
      throw const FormatException('Unsupported theme format');
    }
    final presetsRaw = source['presets'];
    if (presetsRaw is! Map<String, dynamic> || presetsRaw.length > 30) {
      throw const FormatException('Invalid theme presets');
    }
    final presets = <String, ThemePalette>{};
    for (final entry in presetsRaw.entries) {
      if (entry.key.trim().isEmpty || entry.key.length > 60) {
        throw const FormatException('Invalid preset name');
      }
      presets[entry.key] = ThemePalette.fromJson(entry.value);
    }
    final author = source['author'];
    if (author != null &&
        (author is! String || author.trim().isEmpty || author.length > 100)) {
      throw const FormatException('Invalid theme author');
    }
    final link = source['authorProfile'];
    final profile = link is String ? Uri.tryParse(link) : null;
    if (link != null &&
        (profile == null ||
            profile.scheme != 'https' ||
            profile.host.isEmpty)) {
      throw const FormatException('Invalid theme author profile');
    }
    final compact = source['compact'] ?? false;
    final textScale = source['textScale'] ?? 1;
    final sidebarWidth = source['sidebarWidth'] ?? 238;
    final openingScreen = source['openingScreen'] ?? 'today';
    final calendarDefaultView = source['calendarDefaultView'] ?? 'week';
    final reducedMotion = source['reducedMotion'] ?? false;
    final widgetOpacity = source['widgetOpacity'] ?? 100;
    if (compact is! bool ||
        textScale is! num ||
        textScale < 0.85 ||
        textScale > 1.5 ||
        sidebarWidth is! int ||
        sidebarWidth < 190 ||
        sidebarWidth > 330 ||
        openingScreen is! String ||
        !const [
          'today',
          'inbox',
          'calendar',
          'habits',
          'goals',
        ].contains(openingScreen) ||
        calendarDefaultView is! String ||
        !const ['day', 'week', 'month'].contains(calendarDefaultView) ||
        reducedMotion is! bool ||
        widgetOpacity is! int ||
        widgetOpacity < 0 ||
        widgetOpacity > 100) {
      throw const FormatException('Invalid layout preference');
    }
    return ThemeCustomization(
      light: ThemePalette.fromJson(source['light']),
      dark: ThemePalette.fromJson(source['dark']),
      presets: presets,
      author: author as String?,
      authorProfile: profile,
      compact: compact,
      textScale: textScale.toDouble(),
      sidebarWidth: sidebarWidth,
      openingScreen: openingScreen,
      calendarDefaultView: calendarDefaultView,
      reducedMotion: reducedMotion,
      widgetOpacity: widgetOpacity,
    );
  }
}
