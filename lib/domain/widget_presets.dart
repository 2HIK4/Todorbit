import 'widget_configuration.dart';

/// Presets contain appearance/layout only; enabling and locking stay local.
class WidgetPresets {
  WidgetPresets([Map<String, WidgetConfiguration>? values])
    : custom = Map.unmodifiable(values ?? {});
  final Map<String, WidgetConfiguration> custom;
  static Map<String, WidgetConfiguration> builtIn(DesktopWidgetKind kind) {
    final base = WidgetConfiguration();
    return {
      'Default': base,
      if (kind == DesktopWidgetKind.tasks) ...{
        'Minimal': base.copyWith(
          showTitle: false,
          navigationDisplay: WidgetNavigationDisplay.icons,
        ),
        'Compact': base.copyWith(showTitle: false, views: ['today', 'all']),
        'Comfortable': base.copyWith(textScale: 1.3),
      } else ...{
        'Compact': base.copyWith(showTitle: false, calendarSplit: .45),
        'Agenda Focus': base.copyWith(calendarSplit: .25),
        'Calendar Focus': base.copyWith(calendarSplit: .75),
      },
      'Transparent': base.copyWith(
        surfaces: {
          ...base.surfaces,
          'shell': const WidgetSurface(opacity: 20, border: true, radius: 12),
          'content': const WidgetSurface(opacity: 0),
          'agenda': const WidgetSurface(opacity: 20),
        },
      ),
    };
  }

  static WidgetConfiguration apply(
    WidgetConfiguration preset,
    WidgetConfiguration current,
  ) => preset.copyWith(
    enabled: current.enabled,
    layoutLocked: current.layoutLocked,
  );
  WidgetPresets put(
    String name,
    WidgetConfiguration value,
    DesktopWidgetKind kind,
  ) {
    name = name.trim();
    if (name == 'Custom' ||
        name.isEmpty ||
        name.length > 60 ||
        builtIn(kind).containsKey(name) ||
        custom.containsKey(name) ||
        custom.length >= 30) {
      throw const FormatException(
        'Choose a unique preset name (1–60 characters; at most 30 custom presets).',
      );
    }
    return WidgetPresets({
      ...custom,
      name: value.copyWith(enabled: false, layoutLocked: false),
    });
  }

  WidgetPresets remove(String name) => WidgetPresets({...custom}..remove(name));
  Map<String, dynamic> toJson() => {
    'version': 1,
    'presets': custom.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory WidgetPresets.fromJson(
    Map<String, dynamic> json,
    DesktopWidgetKind kind,
  ) {
    if (json['version'] != 1 || json['presets'] is! Map) {
      throw const FormatException('Unsupported widget presets');
    }
    var result = WidgetPresets();
    for (final entry in (json['presets'] as Map).entries) {
      if (entry.key is! String ||
          entry.value is! Map<String, dynamic> ||
          entry.value['version'] != 1) {
        throw const FormatException('Invalid widget preset');
      }
      result = result.put(
        entry.key,
        WidgetConfiguration.fromJson(entry.value),
        kind,
      );
    }
    return result;
  }
}
