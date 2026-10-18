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
    try {
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return CalendarContent.values.firstWhere(
        (item) => item.name == value['content'],
        orElse: () => CalendarContent.both,
      );
    } catch (_) {
      return CalendarContent.both;
    }
  }

  Future<void> save(CalendarContent value) async {
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
