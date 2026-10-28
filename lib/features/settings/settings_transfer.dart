import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../app/app_controller.dart';
import '../../domain/appearance.dart';
import '../../domain/hotkeys.dart';
import '../../domain/models.dart';
import '../../domain/task_view_preferences.dart';
import '../../data/widget_configuration_store.dart';

enum SettingsCategory {
  appearance,
  hotkeys,
  calendar,
  navigation,
  taskDisplay,
  widgets,
}

extension SettingsCategoryLabel on SettingsCategory {
  String get label => switch (this) {
    SettingsCategory.appearance => 'Appearance and themes',
    SettingsCategory.hotkeys => 'Hotkey presets',
    SettingsCategory.calendar => 'Calendar display',
    SettingsCategory.navigation => 'Sidebar and navigation',
    SettingsCategory.taskDisplay => 'Task display',
    SettingsCategory.widgets => 'Widget customization and presets',
  };
}

/// Allowlisted, versioned personalization. Database records and private policy
/// files are never read by this transfer path.
class SettingsTransfer {
  SettingsTransfer._(this.categories);

  static const maxBytes = 1500 * 1024;
  final Map<SettingsCategory, Map<String, dynamic>> categories;

  factory SettingsTransfer.fromController(AppController controller) {
    final appearance =
        Map<String, dynamic>.from(controller.customization.toJson())
          ..remove('author')
          ..remove('authorProfile');
    return SettingsTransfer._({
      SettingsCategory.widgets:
          controller.widgetStore?.exportBundle() ?? {'version': 1},
      SettingsCategory.appearance: {
        'mode': controller.theme.name,
        'customization': appearance,
      },
      SettingsCategory.hotkeys: {'presets': controller.hotkeys.toJson()},
      SettingsCategory.calendar: {
        'content': controller.calendarContent.name,
        'firstWeekday': controller.firstWeekday,
        'lastMode': controller.lastCalendarMode,
      },
      SettingsCategory.navigation: {
        'sidebarOrder': controller.sidebarOrder
            .map((item) => item.name)
            .toList(),
      },
      SettingsCategory.taskDisplay: {
        'newTaskPlannedDay':
            controller.taskViewPreferences.newTaskPlannedDay.name,
        'keepCompletedVisible':
            controller.taskViewPreferences.keepCompletedVisible,
        'spellCheckEnabled': controller.taskViewPreferences.spellCheckEnabled,
        'compositionTextDisplay':
            controller.taskViewPreferences.compositionTextDisplay.name,
      },
    });
  }

  String encode(Set<SettingsCategory> selected) {
    if (selected.isEmpty) {
      throw const FormatException('Select settings to export');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'todorbit-shareable-settings',
      'version': 1,
      'categories': {for (final item in selected) item.name: categories[item]},
    });
  }

  Future<void> exportTo(File file, Set<SettingsCategory> selected) async {
    if (path.extension(file.path).toLowerCase() != '.json') {
      throw const FormatException('Choose a .json file');
    }
    if (await file.exists()) {
      throw const FileSystemException('File already exists');
    }
    final content = encode(selected);
    if (utf8.encode(content).length > maxBytes) {
      throw const FormatException('Settings file is too large');
    }
    await file.writeAsString(content, flush: true);
  }

  static Future<SettingsTransfer> read(File file) async {
    if (!await file.exists()) {
      throw const FileSystemException('Settings file is missing');
    }
    if (await file.length() > maxBytes) {
      throw const FormatException('Settings file is too large');
    }
    return decode(await file.readAsString());
  }

  static SettingsTransfer decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('Settings file is too large');
    }
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic> &&
        decoded['version'] == 1 &&
        decoded.containsKey('light') &&
        decoded.containsKey('dark')) {
      final theme = ThemeCustomization.fromJson(decoded);
      return SettingsTransfer._({
        SettingsCategory.appearance: {'customization': theme.toJson()},
      });
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'todorbit-shareable-settings' ||
        decoded['version'] != 1 ||
        decoded['categories'] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported settings file');
    }
    final raw = decoded['categories'] as Map<String, dynamic>;
    if (raw.isEmpty) {
      throw const FormatException('Settings file has no categories');
    }
    final categories = <SettingsCategory, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      final category = SettingsCategory.values
          .where((item) => item.name == entry.key)
          .firstOrNull;
      if (category == null) {
        continue; // Future categories do not replace current settings.
      }
      if (entry.value is! Map<String, dynamic>) {
        throw FormatException('Invalid ${category.label} settings');
      }
      final value = entry.value as Map<String, dynamic>;
      _validate(category, value);
      categories[category] = value;
    }
    if (categories.isEmpty) {
      throw const FormatException('No supported settings categories');
    }
    return SettingsTransfer._(categories);
  }

  static void _validate(SettingsCategory category, Map<String, dynamic> value) {
    switch (category) {
      case SettingsCategory.widgets:
        WidgetConfigurationStore.validateBundle(value);
      case SettingsCategory.appearance:
        if (value['mode'] != null &&
            !ThemeModePreference.values.any(
              (item) => item.name == value['mode'],
            )) {
          throw const FormatException('Invalid theme mode');
        }
        ThemeCustomization.fromJson(value['customization']);
      case SettingsCategory.hotkeys:
        final raw = value['presets'];
        if (raw is! Map<String, dynamic> || raw['presets'] is! Map) {
          throw const FormatException('Invalid hotkey presets');
        }
        final names = raw['presets'] as Map;
        for (final name in names.keys) {
          if (name is! String ||
              name.trim().isEmpty ||
              name.length > 40 ||
              name == 'Default') {
            throw const FormatException('Invalid hotkey preset name');
          }
          final bindings = names[name];
          if (bindings is! Map) {
            throw const FormatException('Invalid hotkey assignments');
          }
          for (final entry in bindings.entries) {
            if (entry.key is! String ||
                !HotkeyAction.values.any((item) => item.name == entry.key) ||
                entry.value is! String ||
                HotkeyBinding.parse(entry.value as String) == null) {
              throw const FormatException('Invalid hotkey assignment');
            }
          }
        }
        final parsed = HotkeyPreferences.fromJson(raw);
        if (parsed.presets.length != names.length + 1 ||
            parsed.activePreset != raw['active']) {
          throw const FormatException(
            'Invalid or conflicting hotkey assignments',
          );
        }
      case SettingsCategory.calendar:
        if (!CalendarContent.values.any(
              (item) => item.name == value['content'],
            ) ||
            value['firstWeekday'] is! int ||
            (value['firstWeekday'] as int) < 1 ||
            (value['firstWeekday'] as int) > 7 ||
            (value['lastMode'] != null &&
                !const ['day', 'week', 'month'].contains(value['lastMode']))) {
          throw const FormatException('Invalid calendar display settings');
        }
      case SettingsCategory.navigation:
        final order = value['sidebarOrder'];
        if (order is! List ||
            order.length != AppController.defaultSidebarOrder.length ||
            order.toSet().length != order.length ||
            !order.toSet().containsAll(
              AppController.defaultSidebarOrder.map((item) => item.name),
            )) {
          throw const FormatException('Invalid sidebar order');
        }
      case SettingsCategory.taskDisplay:
        if (!NewTaskPlannedDay.values.any(
              (item) => item.name == value['newTaskPlannedDay'],
            ) ||
            value['keepCompletedVisible'] is! bool ||
            value['spellCheckEnabled'] is! bool ||
            !CompositionTextDisplay.values.any(
              (item) => item.name == value['compositionTextDisplay'],
            )) {
          throw const FormatException('Invalid task display settings');
        }
    }
  }

  Future<void> applyTo(
    AppController controller,
    Set<SettingsCategory> selected, {
    bool mergeHotkeys = false,
  }) async {
    for (final category in selected) {
      final value = categories[category];
      if (value == null) continue;
      switch (category) {
        case SettingsCategory.widgets:
          if (value.length == 1) break;
          if (controller.widgetStore == null) {
            throw StateError("Widget profile store unavailable");
          }
          await controller.widgetStore!.importBundle(value);
        case SettingsCategory.appearance:
          await controller.saveCustomization(
            ThemeCustomization.fromJson(value['customization']),
          );
          if (value['mode'] is String) {
            await controller.setTheme(
              ThemeModePreference.values.byName(value['mode'] as String),
            );
          }
        case SettingsCategory.hotkeys:
          final imported = HotkeyPreferences.fromJson(value['presets']);
          if (mergeHotkeys) {
            final combined = {...controller.hotkeys.presets};
            for (final entry in imported.presets.entries) {
              if (entry.key == 'Default') continue;
              var name = entry.key;
              var suffix = 2;
              while (combined.containsKey(name)) {
                final tail = ' ($suffix)';
                final base = entry.key
                    .substring(0, (40 - tail.length).clamp(0, entry.key.length))
                    .trimRight();
                name = '$base$tail';
                suffix++;
              }
              combined[name] = entry.value;
            }
            await controller.setHotkeys(
              HotkeyPreferences(
                activePreset: controller.hotkeys.activePreset,
                presets: combined,
              ),
            );
          } else {
            await controller.setHotkeys(imported);
          }
        case SettingsCategory.calendar:
          await controller.setCalendarContent(
            CalendarContent.values.byName(value['content'] as String),
          );
          await controller.setFirstWeekday(value['firstWeekday'] as int);
          if (value['lastMode'] is String) {
            await controller.setLastCalendarMode(value['lastMode'] as String);
          }
        case SettingsCategory.navigation:
          await controller.setSidebarOrder(
            (value['sidebarOrder'] as List)
                .cast<String>()
                .map(WorkspaceView.values.byName)
                .toList(),
          );
        case SettingsCategory.taskDisplay:
          await controller.setTaskViewPreferences(
            TaskViewPreferences(
              newTaskPlannedDay: NewTaskPlannedDay.values.byName(
                value['newTaskPlannedDay'] as String,
              ),
              keepCompletedVisible: value['keepCompletedVisible'] as bool,
              spellCheckEnabled: value['spellCheckEnabled'] as bool,
              compositionTextDisplay: CompositionTextDisplay.values.byName(
                value['compositionTextDisplay'] as String,
              ),
            ),
          );
      }
    }
  }
}
