import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'profile_paths.dart';

/// Device-only delivery switch. Portable alarm rules remain untouched.
class AlarmDeviceStore {
  AlarmDeviceStore(this.file);
  factory AlarmDeviceStore.active() => AlarmDeviceStore(
    File(path.join(ProfilePaths.activeDirectory().path, 'alarm-settings.json')),
  );
  final File file;
  Future<bool> enabled() async {
    if (!await file.exists()) return true;
    final value = jsonDecode(await file.readAsString()) as Map;
    if (value['version'] != 1 || value['enabled'] is! bool) {
      throw const FormatException(
        'Alarm device settings need review; retain this profile',
      );
    }
    return value['enabled'] as bool;
  }

  Future<void> save(bool enabled) async {
    await file.parent.create(recursive: true);
    final staging = File('${file.path}.tmp');
    await staging.writeAsString(
      jsonEncode({'version': 1, 'enabled': enabled}),
      flush: true,
    );
    await staging.rename(file.path);
  }
}
