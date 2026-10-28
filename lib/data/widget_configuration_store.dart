import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/widget_configuration.dart';
import '../domain/widget_presets.dart';

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

  File _presets(DesktopWidgetKind kind) =>
      File(p.join(directory.path, 'widget-${kind.name}-presets.json'));
  Future<WidgetPresets> loadPresets(DesktopWidgetKind kind) async {
    final file = _presets(kind);
    if (!await file.exists()) return WidgetPresets();
    if (await file.length() > 512 * 1024) {
      throw const FormatException('Widget presets exceed 512 KiB');
    }
    return WidgetPresets.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      kind,
    );
  }

  Future<void> savePresets(DesktopWidgetKind kind, WidgetPresets value) async {
    await directory.create(recursive: true);
    final file = _presets(kind), temp = File('${_presets(kind).path}.$pid.tmp');
    try {
      await temp.writeAsString(jsonEncode(value.toJson()), flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  /// Portable appearance/layout only. Visibility, geometry and startup stay local.
  Map<String, dynamic> exportBundle() {
    final result = <String, dynamic>{'version': 1};
    for (final kind in DesktopWidgetKind.values) {
      final config = _file(kind), presets = _presets(kind);
      final value = <String, dynamic>{};
      if (config.existsSync()) {
        if (config.lengthSync() > 65536) {
          throw const FormatException('Widget configuration too large');
        }
        final json =
            jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Unsupported widget configuration');
        }
        value['configuration'] = WidgetConfiguration.fromJson(json).toJson()
          ..remove('enabled')
          ..remove('layoutLocked');
      }
      if (presets.existsSync()) {
        if (presets.lengthSync() > 512 * 1024) {
          throw const FormatException('Widget presets too large');
        }
        value['presets'] = WidgetPresets.fromJson(
          jsonDecode(presets.readAsStringSync()) as Map<String, dynamic>,
          kind,
        ).toJson();
      }
      if (value.isNotEmpty) result[kind.name] = value;
    }
    return result;
  }

  static void validateBundle(Map<String, dynamic> bundle) {
    if (bundle['version'] != 1 ||
        utf8.encode(jsonEncode(bundle)).length > 1200 * 1024) {
      throw const FormatException('Unsupported widget personalization');
    }
    for (final kind in DesktopWidgetKind.values) {
      final value = bundle[kind.name];
      if (value == null) continue;
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid widget personalization');
      }
      if (value['configuration'] != null) {
        final config = value['configuration'];
        if (config is! Map<String, dynamic> || config['version'] != 1) {
          throw const FormatException('Invalid widget configuration');
        }
        WidgetConfiguration.fromJson(config);
      }
      if (value['presets'] != null) {
        WidgetPresets.fromJson(
          Map<String, dynamic>.from(value['presets'] as Map),
          kind,
        );
      }
    }
  }

  Future<void> importBundle(Map<String, dynamic> bundle) async {
    validateBundle(bundle);
    final previous = <File, String?>{};
    try {
      for (final kind in DesktopWidgetKind.values) {
        final value = bundle[kind.name] as Map<String, dynamic>?;
        if (value == null) continue;
        for (final file in [_file(kind), _presets(kind)]) {
          previous[file] = await file.exists()
              ? await file.readAsString()
              : null;
        }
        if (value['configuration'] != null) {
          final current = await load(kind);
          await save(
            kind,
            WidgetConfiguration.fromJson(
              Map<String, dynamic>.from(value['configuration'] as Map),
            ).copyWith(
              enabled: current.enabled,
              layoutLocked: current.layoutLocked,
            ),
          );
        }
        if (value['presets'] != null) {
          await savePresets(
            kind,
            WidgetPresets.fromJson(
              Map<String, dynamic>.from(value['presets'] as Map),
              kind,
            ),
          );
        }
      }
    } catch (_) {
      for (final entry in previous.entries) {
        if (entry.value == null) {
          if (await entry.key.exists()) await entry.key.delete();
        } else {
          await entry.key.writeAsString(entry.value!, flush: true);
        }
      }
      rethrow;
    }
  }
}
