import 'dart:convert';
import 'dart:io';

import 'app_database.dart';
import '../domain/models.dart';

class CalendarPreferenceStore {
  CalendarPreferenceStore(this.file);
  final File file;

  static Future<CalendarPreferenceStore> openDefault() async {
    final database = await AppDatabase.defaultFile();
    return CalendarPreferenceStore(
      File(
        '${database.parent.path}${Platform.pathSeparator}calendar-settings.json',
      ),
    );
  }

  Future<CalendarContent> load() async {
    if (!await file.exists()) return CalendarContent.both;
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw FormatException(
        'Calendar settings must be a JSON object: ${file.path}',
      );
    }
    return CalendarContent.values.firstWhere(
      (item) => item.name == value['content'],
      orElse: () => CalendarContent.both,
    );
  }

  Future<void> save(CalendarContent value) async {
    // Never overwrite a recoverable malformed or unreadable preference file.
    await load();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'content': value.name}),
      flush: true,
    );
    await temporary.copy(file.path);
    await temporary.delete();
  }
}
