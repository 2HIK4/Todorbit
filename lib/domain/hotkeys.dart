import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum HotkeyAction {
  newTask,
  quickSearch,
  advancedSearch,
  today,
  allTasks,
  calendar,
  anytime,
  settings,
  focus,
  refresh,
}

extension HotkeyActionInfo on HotkeyAction {
  String get label => switch (this) {
    HotkeyAction.newTask => 'Create new task',
    HotkeyAction.quickSearch => 'Quick Search',
    HotkeyAction.advancedSearch => 'Advanced Search',
    HotkeyAction.today => 'Navigate Today',
    HotkeyAction.allTasks => 'Navigate All Tasks',
    HotkeyAction.calendar => 'Navigate Calendar',
    HotkeyAction.anytime => 'Navigate Anytime',
    HotkeyAction.settings => 'Open Settings',
    HotkeyAction.focus => 'Start or stop Focus',
    HotkeyAction.refresh => 'Refresh current view',
  };

  String get group => switch (this) {
    HotkeyAction.newTask || HotkeyAction.focus => 'Tasks',
    HotkeyAction.quickSearch || HotkeyAction.advancedSearch => 'Search',
    HotkeyAction.settings || HotkeyAction.refresh => 'Application',
    _ => 'Navigation',
  };
}

class HotkeyBinding {
  const HotkeyBinding(this.key, {this.shift = false});
  final String key;
  final bool shift;

  static final supported = <String, LogicalKeyboardKey>{
    for (var index = 0; index < 26; index++)
      String.fromCharCode(65 + index): LogicalKeyboardKey(
        LogicalKeyboardKey.keyA.keyId + index,
      ),
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8,
    '9': LogicalKeyboardKey.digit9,
    '0': LogicalKeyboardKey.digit0,
  };

  SingleActivator get activator =>
      SingleActivator(supported[key]!, control: true, shift: shift);

  String get display => 'Ctrl+${shift ? 'Shift+' : ''}$key';
  String get encoded => '${shift ? 'Ctrl+Shift+' : 'Ctrl+'}$key';

  static HotkeyBinding? parse(String value) {
    final match = RegExp(r'^Ctrl\+(Shift\+)?([A-Z0-9])$').firstMatch(value);
    if (match == null) return null;
    final binding = HotkeyBinding(match[2]!, shift: match[1] != null);
    return binding.isSupported ? binding : null;
  }

  static HotkeyBinding? fromKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return null;
    }
    for (final entry in supported.entries) {
      if (entry.value == event.logicalKey) {
        final binding = HotkeyBinding(
          entry.key,
          shift: keyboard.isShiftPressed,
        );
        return binding.isSupported ? binding : null;
      }
    }
    return null;
  }

  bool get isSupported =>
      supported.containsKey(key) &&
      !(key == 'C' ||
          key == 'V' ||
          key == 'X' ||
          key == 'A' ||
          key == 'Z' ||
          key == 'Y');

  @override
  bool operator ==(Object other) =>
      other is HotkeyBinding && other.key == key && other.shift == shift;

  @override
  int get hashCode => Object.hash(key, shift);
}

class HotkeyPreferences {
  HotkeyPreferences({
    this.activePreset = 'Default',
    Map<String, Map<HotkeyAction, HotkeyBinding>>? presets,
  }) : presets = presets ?? {'Default': defaults};

  final String activePreset;
  final Map<String, Map<HotkeyAction, HotkeyBinding>> presets;

  static final defaults = <HotkeyAction, HotkeyBinding>{
    HotkeyAction.newTask: const HotkeyBinding('N'),
    HotkeyAction.quickSearch: const HotkeyBinding('K'),
    HotkeyAction.advancedSearch: const HotkeyBinding('F', shift: true),
    HotkeyAction.today: const HotkeyBinding('1'),
    HotkeyAction.allTasks: const HotkeyBinding('2'),
    HotkeyAction.calendar: const HotkeyBinding('3'),
    HotkeyAction.anytime: const HotkeyBinding('4'),
    HotkeyAction.settings: const HotkeyBinding('9'),
    HotkeyAction.focus: const HotkeyBinding('P', shift: true),
    HotkeyAction.refresh: const HotkeyBinding('R'),
  };

  Map<HotkeyAction, HotkeyBinding> get bindings =>
      presets[activePreset] ?? defaults;

  HotkeyPreferences withBinding(HotkeyAction action, HotkeyBinding binding) {
    if (!binding.isSupported) {
      throw const FormatException('Unsupported shortcut');
    }
    if (bindings.entries.any(
      (entry) => entry.key != action && entry.value == binding,
    )) {
      throw const FormatException('Shortcut already assigned');
    }
    final name = activePreset == 'Default' ? 'Custom' : activePreset;
    return HotkeyPreferences(
      activePreset: name,
      presets: {
        ...presets,
        name: {...bindings, action: binding},
      },
    );
  }

  HotkeyPreferences resetOne(HotkeyAction action) =>
      withBinding(action, defaults[action]!);

  HotkeyPreferences resetAll() =>
      HotkeyPreferences(activePreset: 'Default', presets: presets);

  HotkeyPreferences saveAs(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty ||
        cleaned == 'Default' ||
        presets.containsKey(cleaned)) {
      throw const FormatException('Choose a unique preset name');
    }
    return HotkeyPreferences(
      activePreset: cleaned,
      presets: {
        ...presets,
        cleaned: {...bindings},
      },
    );
  }

  HotkeyPreferences select(String name) {
    if (!presets.containsKey(name)) {
      throw const FormatException('Preset unavailable');
    }
    return HotkeyPreferences(activePreset: name, presets: presets);
  }

  HotkeyPreferences rename(String oldName, String newName) {
    if (oldName == 'Default' || !presets.containsKey(oldName)) {
      throw const FormatException('Default preset cannot be renamed');
    }
    final cleaned = newName.trim();
    if (cleaned.isEmpty ||
        (cleaned != oldName && presets.containsKey(cleaned))) {
      throw const FormatException('Choose a unique preset name');
    }
    final changed = {...presets}..remove(oldName);
    changed[cleaned] = presets[oldName]!;
    return HotkeyPreferences(
      activePreset: activePreset == oldName ? cleaned : activePreset,
      presets: changed,
    );
  }

  HotkeyPreferences delete(String name) {
    if (name == 'Default') {
      throw const FormatException('Default preset cannot be deleted');
    }
    final changed = {...presets}..remove(name);
    return HotkeyPreferences(
      activePreset: activePreset == name ? 'Default' : activePreset,
      presets: changed,
    );
  }

  Map<String, Object> toJson() => {
    'active': activePreset,
    'presets': {
      for (final entry in presets.entries)
        if (entry.key != 'Default')
          entry.key: {
            for (final binding in entry.value.entries)
              binding.key.name: binding.value.encoded,
          },
    },
  };

  factory HotkeyPreferences.fromJson(Object? value) {
    if (value is! Map) return HotkeyPreferences();
    final stored = value['presets'];
    final presets = <String, Map<HotkeyAction, HotkeyBinding>>{
      'Default': defaults,
    };
    if (stored is Map) {
      for (final entry in stored.entries) {
        if (entry.key is! String ||
            entry.key == 'Default' ||
            entry.value is! Map) {
          continue;
        }
        final bindings = {...defaults};
        for (final setting in (entry.value as Map).entries) {
          final action = HotkeyAction.values
              .where((item) => item.name == setting.key)
              .firstOrNull;
          final binding = setting.value is String
              ? HotkeyBinding.parse(setting.value as String)
              : null;
          if (action != null && binding != null) bindings[action] = binding;
        }
        if (bindings.values.toSet().length == bindings.length) {
          presets[entry.key as String] = bindings;
        }
      }
    }
    final active = value['active'];
    return HotkeyPreferences(
      activePreset: active is String && presets.containsKey(active)
          ? active
          : 'Default',
      presets: presets,
    );
  }
}
