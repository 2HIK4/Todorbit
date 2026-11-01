import 'dart:convert';

import '../theme_json.dart';
import '../models.dart';
import '../task_view_preferences.dart';

const deviceLocalThemeFields = {
  'author',
  'authorProfile',
  'sidebarWidth',
  'openingScreen',
  'widgetOpacity',
};

Object? validatePortablePreference(String key, Object? value) {
  final valid = switch (key) {
    'theme' =>
      value is String && ThemeModePreference.values.any((v) => v.name == value),
    'calendarContent' =>
      value is String && CalendarContent.values.any((v) => v.name == value),
    'firstWeekday' => value is int && value >= 1 && value <= 7,
    'lastCalendarMode' =>
      value == null || const ['day', 'week', 'month'].contains(value),
    'keepCompletedVisible' || 'spellCheckEnabled' => value is bool,
    'newTaskPlannedDay' =>
      value is String && NewTaskPlannedDay.values.any((v) => v.name == value),
    'compositionTextDisplay' =>
      value is String &&
          CompositionTextDisplay.values.any((v) => v.name == value),
    'customization' => value is Map,
    _ => false,
  };
  if (!valid || utf8.encode(jsonEncode(value)).length > 1500 * 1024) {
    throw const FormatException('Unsupported portable preference');
  }
  if (key == 'customization') {
    final normalized = normalizeThemeCustomizationJson(value);
    normalized.removeWhere((key, _) => deviceLocalThemeFields.contains(key));
    return normalized;
  }
  return value;
}
