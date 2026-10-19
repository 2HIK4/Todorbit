import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/appearance.dart';
import 'profile_paths.dart';

class AppearancePreferenceStore {
  AppearancePreferenceStore(this.file);

  final File file;

  static Future<AppearancePreferenceStore> openDefault() async {
    final directory = ProfilePaths.activeDirectory();
    await directory.create(recursive: true);
    return AppearancePreferenceStore(
      File(path.join(directory.path, 'appearance-settings.json')),
    );
  }

  Future<ThemeModePreference> load() async {
    final name = (await _read())['theme']?.toString().toLowerCase();
    return ThemeModePreference.values.firstWhere(
      (item) => item.name == name,
      orElse: () => ThemeModePreference.system,
    );
  }

  Future<void> save(ThemeModePreference theme) async {
    await _write({...await _read(), 'theme': theme.name});
  }

  Future<ThemeCustomization> loadCustomization() async {
    final data = await _read();
    final value = data['customization'];
    try {
      final parsed = value == null
          ? const ThemeCustomization()
          : ThemeCustomization.fromJson(value);
      final opacity = data['widgetOpacity'];
      return opacity is int && opacity >= 0 && opacity <= 100
          ? parsed.copyWith(widgetOpacity: opacity)
          : parsed;
    } on FormatException {
      return const ThemeCustomization();
    }
  }

  Future<void> saveCustomization(ThemeCustomization value) async {
    await _write({
      ...await _read(),
      'customization': value.toJson(),
      'widgetOpacity': value.widgetOpacity,
    });
  }

  Future<Map<String, dynamic>> _read() async {
    if (!await file.exists()) return {};
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      // Interrupted writes leave safe defaults in memory.
    }
    return {};
  }

  Future<void> _write(Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.dart.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
    await temporary.copy(file.path);
    await temporary.delete();
  }
}
