enum DesktopWidgetKind { tasks, calendar }

enum WidgetNavigationPosition { top, left, right, bottom }

enum WidgetNavigationDisplay { text, icons, both }

/// Theme-relative surfaces. Null colors follow the active light/dark palette.
class WidgetSurface {
  const WidgetSurface({
    this.color,
    this.opacity = 100,
    this.border = false,
    this.borderColor,
    this.textColor,
    this.placeholderColor,
    this.borderOpacity = 100,
    this.thickness = 1,
    this.radius = 8,
  });
  final String? color, borderColor, textColor, placeholderColor;
  final int opacity, borderOpacity;
  final bool border;
  final double thickness, radius;
  Map<String, dynamic> toJson() => {
    'color': color,
    'opacity': opacity,
    'border': border,
    'borderColor': borderColor,
    'textColor': textColor,
    'placeholderColor': placeholderColor,
    'borderOpacity': borderOpacity,
    'thickness': thickness,
    'radius': radius,
  };
  factory WidgetSurface.fromJson(dynamic value) {
    final m = value is Map ? value : const {};
    String? color(dynamic v) =>
        v is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v) ? v : null;
    double number(String k, double fallback, double max) =>
        m[k] is num && (m[k] as num).isFinite
        ? (m[k] as num).toDouble().clamp(0, max)
        : fallback;
    return WidgetSurface(
      color: color(m['color']),
      borderColor: color(m['borderColor']),
      textColor: color(m['textColor']),
      placeholderColor: color(m['placeholderColor']),
      opacity: number('opacity', 100, 100).round(),
      border: m['border'] == true,
      borderOpacity: number('borderOpacity', 100, 100).round(),
      thickness: number('thickness', 1, 8),
      radius: number('radius', 8, 32),
    );
  }
}

/// Versioned, independent configuration; native geometry remains device-local.
class WidgetConfiguration {
  WidgetConfiguration({
    this.enabled = false,
    this.showTitle = true,
    this.showOpenButton = true,
    this.layoutLocked = false,
    this.protectText = true,
    this.navigationPosition = WidgetNavigationPosition.top,
    this.navigationDisplay = WidgetNavigationDisplay.text,
    this.textScale = 1,
    List<String>? views,
    Map<String, WidgetSurface>? surfaces,
  }) : views = List.unmodifiable(
         views ?? const ['today', 'inbox', 'all', 'upcoming'],
       ),
       surfaces = Map.unmodifiable({...defaults, ...?surfaces});
  static const defaults = <String, WidgetSurface>{
    'shell': WidgetSurface(border: true, radius: 12),
    'content': WidgetSurface(),
    'input': WidgetSurface(border: true, radius: 7),
    'header': WidgetSurface(opacity: 0),
    'navigation': WidgetSurface(opacity: 0),
    'navigationButton': WidgetSurface(radius: 6),
    'calendarCell': WidgetSurface(opacity: 0, radius: 4),
    'agenda': WidgetSurface(),
    'selectedDate': WidgetSurface(radius: 4),
    'today': WidgetSurface(opacity: 0, border: true, thickness: 2, radius: 4),
  };
  final bool enabled, showTitle, showOpenButton, layoutLocked, protectText;
  final WidgetNavigationPosition navigationPosition;
  final WidgetNavigationDisplay navigationDisplay;
  final double textScale;
  final List<String> views;
  final Map<String, WidgetSurface> surfaces;
  bool get hasHeader => showTitle || showOpenButton;
  WidgetConfiguration copyWith({
    bool? enabled,
    bool? showTitle,
    bool? showOpenButton,
    bool? layoutLocked,
    bool? protectText,
    WidgetNavigationPosition? navigationPosition,
    WidgetNavigationDisplay? navigationDisplay,
    double? textScale,
    List<String>? views,
    Map<String, WidgetSurface>? surfaces,
  }) => WidgetConfiguration(
    enabled: enabled ?? this.enabled,
    showTitle: showTitle ?? this.showTitle,
    showOpenButton: showOpenButton ?? this.showOpenButton,
    layoutLocked: layoutLocked ?? this.layoutLocked,
    protectText: protectText ?? this.protectText,
    navigationPosition: navigationPosition ?? this.navigationPosition,
    navigationDisplay: navigationDisplay ?? this.navigationDisplay,
    textScale: textScale ?? this.textScale,
    views: views ?? this.views,
    surfaces: surfaces ?? this.surfaces,
  );

  /// Copies only compatible appearance, never lifecycle, geometry or task layout.
  WidgetConfiguration withSharedAppearance(WidgetConfiguration source) =>
      copyWith(
        showTitle: source.showTitle,
        showOpenButton: source.showOpenButton,
        textScale: source.textScale,
        protectText: source.protectText,
        surfaces: {
          ...surfaces,
          for (final key in ['shell', 'content', 'header'])
            key: source.surfaces[key] ?? defaults[key]!,
        },
      );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'enabled': enabled,
    'showTitle': showTitle,
    'showOpenButton': showOpenButton,
    'layoutLocked': layoutLocked,
    'protectText': protectText,
    'navigationPosition': navigationPosition.name,
    'navigationDisplay': navigationDisplay.name,
    'textScale': textScale,
    'views': views,
    'surfaces': surfaces.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory WidgetConfiguration.fromJson(Map<String, dynamic> m) {
    T choice<T extends Enum>(List<T> values, dynamic name) =>
        values.firstWhere((v) => v.name == name, orElse: () => values.first);
    return WidgetConfiguration(
      enabled: m['enabled'] == true,
      showTitle: m['showTitle'] != false,
      showOpenButton: m['showOpenButton'] != false,
      layoutLocked: m['layoutLocked'] == true,
      protectText: m['protectText'] != false,
      navigationPosition: choice(
        WidgetNavigationPosition.values,
        m['navigationPosition'],
      ),
      navigationDisplay: choice(
        WidgetNavigationDisplay.values,
        m['navigationDisplay'],
      ),
      textScale: m['textScale'] is num && (m['textScale'] as num).isFinite
          ? (m['textScale'] as num).toDouble().clamp(1, 1.6)
          : 1,
      views: m['views'] is List
          ? (m['views'] as List)
                .whereType<String>()
                .where(
                  (v) =>
                      const ['today', 'inbox', 'all', 'upcoming'].contains(v),
                )
                .toSet()
                .toList()
          : null,
      surfaces: {
        for (final entry in defaults.entries)
          entry.key:
              m['surfaces'] is Map && (m['surfaces'] as Map)[entry.key] is Map
              ? WidgetSurface.fromJson(m['surfaces'][entry.key])
              : entry.value,
      },
    );
  }
}
