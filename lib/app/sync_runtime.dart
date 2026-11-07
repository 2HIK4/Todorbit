import 'dart:io';

import '../data/private_test_environment.dart';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../data/cloud/google_drive_auth.dart';
import '../data/cloud/google_drive_provider.dart';
import '../data/cloud/sync_pairing_service.dart';
import '../platform/android/android_google_drive_auth.dart';
import '../platform/android/android_platform.dart';
import '../features/widget/native_widget_service.dart';
import 'app_controller.dart';
import 'privacy_manager.dart';
import 'sync_controller.dart';

SyncController createSyncRuntime(
  AppController controller,
  PrivacyManager privacy, {
  Future<void> Function(bool enabled)? scheduleBackground,
  Duration? timeBudget,
  Future<bool> Function()? canExchange,
  bool refreshController = true,
}) {
  final recovery = controller.backupService!;
  final profile = recovery.databaseFile.absolute.path;
  final client = http.Client();
  final auth = Platform.isAndroid
      ? AndroidGoogleDriveAuth(
          client: client,
          store: SecureCloudTokenStore(profile),
        )
      : GoogleDriveAuth(
          client: client,
          flow: LoopbackGoogleAuthorization(),
          store: SecureCloudTokenStore(profile),
          configurationStore: kDebugMode && Platform.isWindows
              ? SecureCloudTokenStore(profile, purpose: 'oauth-client')
              : null,
          clientId: GoogleDriveAuth.configuredClientId,
          clientSecret: GoogleDriveAuth.configuredClientSecret,
          enabled: GoogleDriveAuth.publicConnectionEnabled,
        );
  final storage = GoogleDriveProvider.sync(auth, client);
  var companionRequested = false;
  late final SyncController sync;
  sync = SyncController(
    timeBudget: timeBudget,
    canExchange: () async =>
        (!PrivateTestEnvironment.enabled ||
            PrivateTestEnvironment.syncApproved(auth.account?.id)) &&
        (canExchange == null || await canExchange()),
    repository: controller.repository,
    recovery: recovery,
    auth: auth,
    storage: storage,
    resetVault: SecureCloudTokenStore(profile, purpose: 'sync-reset-operation'),
    pairing: SyncPairingService(
      resetVault: SecureCloudTokenStore(
        profile,
        purpose: 'sync-reset-operation',
      ),
      storage: storage,
      vault: SecureCloudTokenStore(profile, purpose: 'sync-workspace-key'),
    ),
    isUnlocked: () => !privacy.locked,
    onApplied: () async {
      await controller.applyPortablePreferences();
      if (refreshController) await controller.refresh();
    },
    scheduleBackground:
        scheduleBackground ??
        (enabled) async {
          if (Platform.isAndroid) {
            await AndroidPlatform.channel.invokeMethod<void>('scheduleSync', {
              'enabled': enabled,
              'immediate': enabled,
            });
          } else if (Platform.isWindows && enabled && !companionRequested) {
            companionRequested = true;
            await NativeWidgetService().ensureRemindersRunning();
          }
        },
    closeTransport: () {
      privacy.removeListener(sync.privacyChanged);
      controller.onLocalChange = null;
      client.close();
    },
  );
  privacy.addListener(sync.privacyChanged);
  controller.onLocalChange = sync.localChanged;
  return sync;
}
