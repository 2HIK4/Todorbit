import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// A fresh TodoPilot profile never selects Life Manager data by its presence.
/// The installer writes this marker only when upgrading an installed TodoPilot.
class ProfilePaths {
  static const markerName = 'legacy-profile.json';
  static const markerValue = 'todopilot-upgrade-v1';

  static String dataRoot() {
    if (Platform.isWindows) {
      return Platform.environment['APPDATA'] ??
          (throw StateError('Windows APPDATA directory is unavailable'));
    }
    final home = Platform.environment['HOME'];
    return Platform.environment['XDG_DATA_HOME'] ??
        (home == null
            ? throw StateError('User data directory is unavailable')
            : path.join(home, '.local', 'share'));
  }

  static Directory todoPilotDirectoryIn(String root) =>
      Directory(path.join(root, 'TodoPilot'));

  static Directory legacyDirectoryIn(String root) =>
      Directory(path.join(root, 'Life Manager'));

  static bool usesLegacyProfileIn(String root) {
    final marker = File(path.join(todoPilotDirectoryIn(root).path, markerName));
    if (!marker.existsSync()) return false;
    try {
      final value = jsonDecode(marker.readAsStringSync());
      return value is Map &&
          value['profile'] == markerValue &&
          File(path.join(legacyDirectoryIn(root).path, 'life_manager.sqlite'))
              .existsSync();
    } catch (_) {
      return false;
    }
  }

  static Directory activeDirectoryIn(String root) => usesLegacyProfileIn(root)
      ? legacyDirectoryIn(root)
      : todoPilotDirectoryIn(root);

  static Directory activeDirectory() => activeDirectoryIn(dataRoot());

  static File legacyDatabaseIn(String root) =>
      File(path.join(legacyDirectoryIn(root).path, 'life_manager.sqlite'));
}
