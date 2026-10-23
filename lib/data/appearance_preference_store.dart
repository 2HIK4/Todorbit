import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/appearance.dart';
import '../domain/task_view_preferences.dart';
import '../domain/hotkeys.dart';
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

  Future<TaskViewPreferences> loadTaskViewPreferences() async {
    final data = await _read();
    return TaskViewPreferences(
      newTaskPlannedDay: data['newTaskPlannedDay'] == 'noDate'
          ? NewTaskPlannedDay.noDate
          : NewTaskPlannedDay.today,
      keepCompletedVisible: data['keepCompletedVisible'] == true,
      spellCheckEnabled: data['spellCheckEnabled'] != false,
      compositionTextDisplay: data['compositionTextDisplay'] == 'full'
          ? CompositionTextDisplay.full
          : CompositionTextDisplay.compact,
    );
  }

  Future<void> saveTaskViewPreferences(TaskViewPreferences value) async {
    await _write({
      ...await _read(),
      'newTaskPlannedDay': value.newTaskPlannedDay.name,
      'keepCompletedVisible': value.keepCompletedVisible,
      'spellCheckEnabled': value.spellCheckEnabled,
      'compositionTextDisplay': value.compositionTextDisplay.name,
    });
  }

  Future<HotkeyPreferences> loadHotkeys() async =>
      HotkeyPreferences.fromJson((await _read())['hotkeys']);

  Future<void> saveHotkeys(HotkeyPreferences value) async {
    await _write({...await _read(), 'hotkeys': value.toJson()});
  }

  Future<int> loadFirstWeekday() async {
    final value = (await _read())['firstWeekday'];
    return value is int && value >= 1 && value <= 7 ? value : 7;
  }

  Future<void> saveFirstWeekday(int value) async {
    if (value < 1 || value > 7) throw ArgumentError.value(value);
    await _write({...await _read(), 'firstWeekday': value});
  }

  Future<String?> loadLastCalendarMode() async {
    final value = (await _read())['lastCalendarMode'];
    return value is String && const ['day', 'week', 'month'].contains(value)
        ? value
        : null;
  }

  Future<void> saveLastCalendarMode(String value) async {
    if (!const ['day', 'week', 'month'].contains(value)) {
      throw ArgumentError.value(value);
    }
    await _write({...await _read(), 'lastCalendarMode': value});
  }

  Future<List<String>> loadSidebarOrder(List<String> defaults) async {
    final value = (await _read())['sidebarOrder'];
    if (value is! List) return List.of(defaults);
    final saved = value.whereType<String>().where(defaults.contains).toSet();
    return [...saved, ...defaults.where((item) => !saved.contains(item))];
  }

  Future<void> saveSidebarOrder(List<String> value) async {
    await _write({...await _read(), 'sidebarOrder': value});
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
