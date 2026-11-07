import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;

/// Opt-in acceptance build only. Never changes normal profile selection.
class PrivateTestEnvironment {
  static const enabled = bool.fromEnvironment('TODORBIT_PRIVATE_DRIVE_TEST');
  static const marker = 'TODORBIT-PRIVATE-DRIVE-TEST';

  static void requireAuthorizationReady() {
    final file = File(p.join(validate().path, 'AUTHORIZATION-READY'));
    if (!file.existsSync() ||
        file.readAsStringSync().trim() != 'verified-private-profile-v1') {
      throw StateError('Private profile verification is pending.');
    }
  }

  static bool syncApproved(
    String? account, {
    String mode = 'standard',
    String? workspace,
  }) {
    if (account == null || !{'standard', 'private'}.contains(mode)) {
      return false;
    }
    try {
      final value = jsonDecode(
        File(
          p.join(
            validate().path,
            mode == 'private'
                ? 'PRIVATE-SYNC-APPROVED.json'
                : 'STANDARD-SYNC-APPROVED.json',
          ),
        ).readAsStringSync(),
      );
      return value is Map &&
          value['account'] == account &&
          value['mode'] == mode &&
          (mode != 'private' ||
              (workspace != null &&
                  workspace.isNotEmpty &&
                  value['workspace'] == workspace)) &&
          value['workspaceVerifiedDisposable'] == true;
    } catch (_) {
      return false;
    }
  }

  static Directory validate() {
    if (!Platform.isWindows) {
      throw StateError('Private Drive acceptance requires Windows.');
    }
    final root = Platform.environment['TODORBIT_PRIVATE_TEST_ROOT'];
    if (root == null || !p.isAbsolute(root)) {
      throw StateError('A dedicated private test root is required.');
    }
    final directory = Directory(p.normalize(root));
    if (File(p.join(directory.path, marker)).readAsStringSync().trim() !=
        'todorbit-private-drive-test-v1') {
      throw StateError('Private test root marker is invalid.');
    }
    for (final entry in {
      'APPDATA': 'Roaming',
      'LOCALAPPDATA': 'Local',
      'TEMP': 'Temp',
      'TMP': 'Temp',
    }.entries) {
      if (!p.equals(
        Platform.environment[entry.key] ?? '',
        p.join(directory.path, entry.value),
      )) {
        throw StateError('Private test environment is not isolated.');
      }
    }
    // Resolving links must not escape the directory selected by the launcher.
    if (!p.equals(
      directory.resolveSymbolicLinksSync(),
      directory.absolute.path,
    )) {
      throw StateError('Private test root must not be a link.');
    }
    return directory;
  }
}
