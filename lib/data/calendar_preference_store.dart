import 'dart:convert';
import 'dart:io';

import 'app_database.dart';
import '../domain/models.dart';

class CalendarPreferenceStore {
  CalendarPreferenceStore(this.file);
  final File file;

  CalendarContent? _cached;
  DateTime? _cachedModified;

  void invalidateCache() {
    _cached = null;
    _cachedModified = null;
  }

  static Future<CalendarPreferenceStore> openDefault() async {
    final database = await AppDatabase.defaultFile();
    return CalendarPreferenceStore(
      File(
        '${database.parent.path}${Platform.pathSeparator}calendar-settings.json',
      ),
    );
  }

  Future<CalendarContent> load() async {
    if (!await file.exists()) {
      _cached = CalendarContent.both;
      _cachedModified = null;
      return _cached!;
    }
    final stat = await file.stat();
    if (_cached != null && _cachedModified == stat.modified) {
      return _cached!;
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'Calendar settings must be a JSON object: ${file.path}',
      );
    }
    _cached = CalendarContent.values.firstWhere(
      (item) => item.name == value['content'],
      orElse: () => CalendarContent.both,
    );
    _cachedModified = stat.modified;
    return _cached!;
  }

  Future<void> save(CalendarContent value) async {
    // Never overwrite a recoverable malformed or unreadable preference file.
    final current = await load();
    if (current == value && await file.exists()) return;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'content': value.name}),
      flush: true,
    );
    await temporary.copy(file.path);
    await temporary.delete();
    _cached = value;
    _cachedModified = (await file.stat()).modified;
  }
}
