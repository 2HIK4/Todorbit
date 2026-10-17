import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/appearance.dart';

class AppearancePreferenceStore {
  AppearancePreferenceStore(this.file);

  final File file;

  static Future<AppearancePreferenceStore> openDefault() async {
    final basePath = Platform.isWindows
        ? Platform.environment['APPDATA']
        : Platform.environment['XDG_DATA_HOME'] ??
              (Platform.environment['HOME'] == null
                  ? null
                  : path.join(
                      Platform.environment['HOME']!,
                      '.local',
                      'share',
                    ));
    if (basePath == null) {
      throw StateError('User data directory is unavailable');
    }
    final directory = Directory(path.join(basePath, 'Life Manager'));
    await directory.create(recursive: true);
    return AppearancePreferenceStore(
      File(path.join(directory.path, 'appearance-settings.json')),
    );
  }

  Future<ThemeModePreference> load() async {
    if (!await file.exists()) return ThemeModePreference.system;
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is Map<String, dynamic>) {
        final name = value['theme']?.toString().toLowerCase();
        return ThemeModePreference.values.firstWhere(
          (item) => item.name == name,
          orElse: () => ThemeModePreference.system,
        );
      }
    } on FormatException {
      // A writer may have been interrupted. Preserve a safe default in memory.
    }
    return ThemeModePreference.system;
  }

  Future<void> save(ThemeModePreference theme) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.dart.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'theme': theme.name}),
      flush: true,
    );
    await temporary.copy(file.path);
    await temporary.delete();
  }
}
