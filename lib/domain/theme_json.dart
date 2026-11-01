enum ThemeModePreference { system, light, dark }

const themePaletteKeys = <String>[
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

Map<String, String> normalizeThemePaletteJson(Object? source) {
  if (source is! Map<String, dynamic> ||
      source.length != themePaletteKeys.length ||
      source.keys.any((key) => !themePaletteKeys.contains(key))) {
    throw const FormatException(
      'Theme colors must contain the nine supported tokens',
    );
  }
  final colors = <String, String>{};
  for (final key in themePaletteKeys) {
    final raw = source[key];
    if (raw is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(raw)) {
      throw FormatException('Invalid $key color');
    }
    colors[key] = raw.toUpperCase();
  }
  return colors;
}

Map<String, Object> normalizeThemeCustomizationJson(Object? source) {
  if (source is! Map<String, dynamic> || source['version'] != 1) {
    throw const FormatException('Unsupported theme format');
  }
  final presetsRaw = source['presets'];
  if (presetsRaw is! Map<String, dynamic> || presetsRaw.length > 30) {
    throw const FormatException('Invalid theme presets');
  }
  final presets = <String, Map<String, String>>{};
  for (final entry in presetsRaw.entries) {
    if (entry.key.trim().isEmpty || entry.key.length > 60) {
      throw const FormatException('Invalid preset name');
    }
    presets[entry.key] = normalizeThemePaletteJson(entry.value);
  }
  final author = source['author'];
  if (author != null &&
      (author is! String || author.trim().isEmpty || author.length > 100)) {
    throw const FormatException('Invalid theme author');
  }
  final link = source['authorProfile'];
  final profile = link is String ? Uri.tryParse(link) : null;
  if (link != null &&
      (profile == null || profile.scheme != 'https' || profile.host.isEmpty)) {
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
      !textScale.isFinite ||
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
  return {
    'version': 1,
    'light': normalizeThemePaletteJson(source['light']),
    'dark': normalizeThemePaletteJson(source['dark']),
    'presets': presets,
    if (author != null) 'author': author as String,
    if (profile != null) 'authorProfile': profile.toString(),
    'compact': compact,
    'textScale': textScale.toDouble(),
    'sidebarWidth': sidebarWidth,
    'openingScreen': openingScreen,
    'calendarDefaultView': calendarDefaultView,
    'reducedMotion': reducedMotion,
    'widgetOpacity': widgetOpacity,
  };
}
