import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/widget_configuration.dart';

class WidgetConfigurationStore {
  WidgetConfigurationStore(this.directory);
  final Directory directory;
  File _file(DesktopWidgetKind kind) =>
      File(p.join(directory.path, 'widget-${kind.name}-configuration.json'));
  Future<WidgetConfiguration> load(DesktopWidgetKind kind) async {
    final file = _file(kind);
    if (await file.exists()) {
      if (await file.length() > 65536) {
        throw const FormatException(
          'Widget configuration exceeds 64 KiB. Original file preserved.',
        );
      }
      final value = jsonDecode(await file.readAsString());
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        throw const FormatException(
          'Unsupported widget configuration. Original file preserved.',
        );
      }
      return WidgetConfiguration.fromJson(value);
    }
    // Read legacy preferences without rewriting or discarding their geometry.
    final legacy = File(p.join(directory.path, 'widget-settings.json'));
    var config = WidgetConfiguration(enabled: kind == DesktopWidgetKind.tasks);
    if (kind == DesktopWidgetKind.tasks && await legacy.exists()) {
      final m = jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
      config = config.copyWith(
        enabled: true,
        layoutLocked: m['layoutLocked'] == true,
        surfaces: {
          ...config.surfaces,
          'shell': WidgetSurface(
            border: true,
            radius: 12,
            opacity: m['backgroundOpacity'] is int
                ? (m['backgroundOpacity'] as int).clamp(0, 100)
                : 100,
          ),
        },
      );
    }
    if (kind == DesktopWidgetKind.tasks) {
      final appearance = File(
        p.join(directory.path, 'appearance-settings.json'),
      );
      if (await appearance.exists()) {
        final value = jsonDecode(await appearance.readAsString());
        if (value is Map) {
          final opacity =
              value['widgetOpacity'] ??
              (value['customization'] is Map
                  ? value['customization']['widgetOpacity']
                  : null);
          if (opacity is int && opacity >= 0 && opacity <= 100) {
            config = config.copyWith(
              surfaces: {
                ...config.surfaces,
                'shell': WidgetSurface.fromJson({
                  ...config.surfaces['shell']!.toJson(),
                  'opacity': opacity,
                }),
              },
            );
          }
        }
      }
    }
    return config;
  }

  Future<void> save(DesktopWidgetKind kind, WidgetConfiguration config) async {
    await directory.create(recursive: true);
    final target = _file(kind);
    final temp = File(
      '${target.path}.$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsString(jsonEncode(config.toJson()), flush: true);
      await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}
