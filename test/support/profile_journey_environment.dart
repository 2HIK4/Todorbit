import 'dart:io';

/// The real startup/cache paths may write files, so these tests require an
/// explicitly disposable child environment rather than the developer profile.
bool get isolatedProfileJourneys {
  final roaming = Platform.environment['APPDATA'] ?? '';
  final local = Platform.environment['LOCALAPPDATA'] ?? '';
  final batch5 = roaming.contains('pass5') && roaming.contains('test-profiles');
  final runner =
      Platform.environment['TODORBIT_PROFILE_JOURNEYS'] == '1' &&
      Directory(roaming).uri.pathSegments.contains('profile-journeys') &&
      Directory(roaming).uri.pathSegments.contains('test-profiles');
  return Platform.isWindows &&
      (batch5 || runner) &&
      roaming.endsWith('Roaming') &&
      local.endsWith('Local') &&
      Directory(roaming).parent.path == Directory(local).parent.path;
}
