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
  Map<String, dynamic>? _cachedData;
  DateTime? _cachedModified;
  int? _cachedSize;
  Future<void> _pendingWrite = Future<void>.value();

  void invalidateCache() {
    _cachedData = null;
    _cachedModified = null;
    _cachedSize = null;
  }

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
    await _write({'theme': theme.name});
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
    } on FormatException catch (failure) {
      throw FormatException(
        'Appearance customization could not be read from ${file.path}: $failure',
      );
    }
  }

  Future<void> saveCustomization(ThemeCustomization value) async {
    await _write({
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
      detailPresentation: data['detailPresentation'] == 'fullPage'
          ? 'fullPage'
          : 'sidePanel',
      hiddenStandardCategories:
          (data['hiddenStandardCategories'] as List? ?? [])
              .cast<String>()
              .toSet(),
      hiddenStandardProjects: (data['hiddenStandardProjects'] as List? ?? [])
          .cast<String>()
          .toSet(),
    );
  }

  Future<void> saveTaskViewPreferences(TaskViewPreferences value) async {
    await _write({
      'newTaskPlannedDay': value.newTaskPlannedDay.name,
      'keepCompletedVisible': value.keepCompletedVisible,
      'spellCheckEnabled': value.spellCheckEnabled,
      'compositionTextDisplay': value.compositionTextDisplay.name,
      'detailPresentation': value.detailPresentation,
      'hiddenStandardCategories': value.hiddenStandardCategories.toList(),
      'hiddenStandardProjects': value.hiddenStandardProjects.toList(),
    });
  }

  Future<int?> loadTaskPanelWidth() async {
    final value = (await _read())['taskPanelWidth'];
    return value is int && value >= 320 && value <= 560 ? value : null;
  }

  Future<void> saveTaskPanelWidth(int width) async =>
      _write({'taskPanelWidth': width});

  Future<HotkeyPreferences> loadHotkeys() async =>
      HotkeyPreferences.fromJson((await _read())['hotkeys']);

  Future<void> saveHotkeys(HotkeyPreferences value) async {
    await _write({'hotkeys': value.toJson()});
  }

  Future<int> loadFirstWeekday() async {
    final value = (await _read())['firstWeekday'];
    return value is int && value >= 1 && value <= 7 ? value : 7;
  }

  Future<void> saveFirstWeekday(int value) async {
    if (value < 1 || value > 7) throw ArgumentError.value(value);
    await _write({'firstWeekday': value});
  }

  Future<String?> loadLastCalendarMode() async {
    final value = (await _read())['lastCalendarMode'];
    return value is String && const ['day', 'week', 'month'].contains(value)
        ? value
        : null;
  }

  Future<void> saveLastCalendarMode(String? value) async {
    if (value != null && !const ['day', 'week', 'month'].contains(value)) {
      throw ArgumentError.value(value);
    }
    await _write({'lastCalendarMode': value});
  }

  Future<List<String>> loadSidebarOrder(List<String> defaults) async {
    final value = (await _read())['sidebarOrder'];
    if (value is! List) return List.of(defaults);
    final saved = value.whereType<String>().where(defaults.contains).toSet();
    return [...saved, ...defaults.where((item) => !saved.contains(item))];
  }

  Future<void> saveSidebarOrder(List<String> value) async {
    await _write({'sidebarOrder': value});
  }

  Future<Map<String, dynamic>> loadNavigationState() async {
    final value = (await _read())['navigationState'];
    if (value == null) return {};
    if (value is! Map<String, dynamic> ||
        (value['hidden'] != null &&
            (value['hidden'] is! List ||
                (value['hidden'] as List).any((v) => v is! String))) ||
        (value['customOrder'] != null &&
            (value['customOrder'] is! List ||
                (value['customOrder'] as List).any((v) => v is! String))) ||
        (value['categoriesExpanded'] != null &&
            value['categoriesExpanded'] is! bool)) {
      throw const FormatException('Navigation settings could not be read');
    }
    return value;
  }

  Future<void> saveNavigationState(Map<String, dynamic> value) async =>
      _write({'navigationState': value});

  Future<Map<String, dynamic>> _read() async {
    if (!await file.exists()) {
      _cachedData = {};
      _cachedModified = null;
      _cachedSize = null;
      return _cachedData!;
    }
    final stat = await file.stat();
    if (_cachedData != null &&
        _cachedModified == stat.modified &&
        _cachedSize == stat.size) {
      return _cachedData!;
    }
    final value = jsonDecode(await file.readAsString());
    if (value is Map<String, dynamic>) {
      _cachedData = value;
      _cachedModified = stat.modified;
      _cachedSize = stat.size;
      return _cachedData!;
    }
    throw FormatException(
      'Appearance settings must be a JSON object. Repair or restore ${file.path} before retrying.',
    );
  }

  Future<void> _write(Map<String, dynamic> updates) {
    final write = _pendingWrite.then((_) => _writeUpdates(updates));
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Future<void> _writeUpdates(Map<String, dynamic> updates) async {
    final existing = await _read();
    final value = {...existing, ...updates};
    final encodedNew = const JsonEncoder.withIndent('  ').convert(value);
    final encodedExisting = const JsonEncoder.withIndent('  ')
        .convert(existing);
    if (encodedNew == encodedExisting && await file.exists()) {
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.dart.tmp');
    await temporary.writeAsString(encodedNew, flush: true);
    await temporary.copy(file.path);
    await temporary.delete();
    _cachedData = Map<String, dynamic>.from(value);
    final stat = await file.stat();
    _cachedModified = stat.modified;
    _cachedSize = stat.size;
  }
}
