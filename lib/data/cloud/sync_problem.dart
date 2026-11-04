import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'cloud_storage_provider.dart';

enum SyncProblemAction {
  retry,
  connect,
  unlock,
  conflicts,
  update,
  recovery,
  resume,
  cleanup,
  reconnect,
  storage,
  services,
}

/// Safe presentation selected from causes, never from exception/server text.
class SyncProblem {
  const SyncProblem(
    this.title,
    this.explanation,
    this.action,
    this.actionLabel,
    this.label,
  );
  final String title, explanation, actionLabel, label;
  final SyncProblemAction action;

  static SyncProblem from(Object error) {
    final kind = error is CloudFailure
        ? error.kind
        : error is SocketException || error is http.ClientException
        ? CloudFailureKind.offline
        : error is TimeoutException
        ? CloudFailureKind.temporary
        : error is FormatException
        ? CloudFailureKind.corrupt
        : CloudFailureKind.unknown;
    return switch (kind) {
      CloudFailureKind.authorization => const SyncProblem(
        'Google sign-in did not finish',
        'Authorization was canceled, declined or could not complete. Your local data and existing cloud workspace are unchanged. Reconnect when ready.',
        SyncProblemAction.connect,
        'Reconnect Google',
        'Sign in required',
      ),
      CloudFailureKind.services => const SyncProblem(
        'Google Play services required',
        'Google sign-in needs installed and up-to-date Google Play services on this Android device. Local data and backups remain available.',
        SyncProblemAction.services,
        'Open Play services',
        'Google sign-in unavailable',
      ),
      CloudFailureKind.offline => const SyncProblem(
        "You're offline",
        'Your changes are saved on this device. Check your connection, then retry.',
        SyncProblemAction.retry,
        'Retry sync',
        'Offline',
      ),
      CloudFailureKind.authentication => const SyncProblem(
        'Google sign-in required',
        'Your Google connection has expired or was revoked. Reconnect to continue.',
        SyncProblemAction.connect,
        'Reconnect Google',
        'Sign in required',
      ),
      CloudFailureKind.permission => const SyncProblem(
        'Google Drive access denied',
        "Todorbit can't access its sync data. Reconnect and allow access to application data.",
        SyncProblemAction.connect,
        'Reauthorize Google',
        'Permission required',
      ),
      CloudFailureKind.credentials => const SyncProblem(
        'Encrypted sync found',
        'Enter the original passphrase or recovery code. Google sign-in alone cannot unlock this data. Starting new sync does not recover cloud-only records.',
        SyncProblemAction.unlock,
        'Unlock sync',
        'Password required',
      ),
      CloudFailureKind.wrongCredential => const SyncProblem(
        'Sync could not be unlocked',
        'That credential could not unlock the cloud workspace. Try the original passphrase or use its recovery code. Nothing was replaced.',
        SyncProblemAction.unlock,
        'Try another credential',
        'Unlock failed',
      ),
      CloudFailureKind.account => const SyncProblem(
        'Different Google account',
        'This profile belongs to another Google account. Switch back to its original account; local changes are kept.',
        SyncProblemAction.connect,
        'Switch Google account',
        'Account mismatch',
      ),
      CloudFailureKind.stale => const SyncProblem(
        'This device needs to reconnect',
        'Another device replaced the cloud sync. Reconnect safely to merge this device’s current records into the new workspace. Its old journal and a recovery snapshot are kept.',
        SyncProblemAction.reconnect,
        'Reconnect safely',
        'Reconnect required',
      ),
      CloudFailureKind.incompatible => const SyncProblem(
        'Update Todorbit to continue',
        'This cloud sync uses an unsupported version. Keep your local data and update all devices before retrying.',
        SyncProblemAction.update,
        'Open update instructions',
        'Update required',
      ),
      CloudFailureKind.corrupt || CloudFailureKind.missing => const SyncProblem(
        'Cloud data could not be verified',
        'A cloud file is missing, damaged or inconsistent. Local records and retained history are kept. Review recovery options before changing the cloud.',
        SyncProblemAction.recovery,
        'View recovery options',
        'Recovery required',
      ),
      CloudFailureKind.conflict => const SyncProblem(
        'Changes need review',
        'Competing changes or sync generations need review. No version was silently selected. Review conflicts; if competing setups exist, finish recovery on the device that started them.',
        SyncProblemAction.conflicts,
        'Review conflicts',
        'Conflict needs review',
      ),
      CloudFailureKind.reset || CloudFailureKind.migrating => const SyncProblem(
        'New sync setup incomplete',
        'A replacement setup has not finished. Local changes and the recovery snapshot are kept. Resume on the device that started it; do not start another setup.',
        SyncProblemAction.resume,
        'Resume new sync',
        'New sync setup incomplete',
      ),
      CloudFailureKind.cleanup => const SyncProblem(
        'New sync active; cleanup incomplete',
        'The verified new workspace is active. Some old cloud files could not be removed. Retry cleanup on this device. Old devices may recreate isolated old files until updated.',
        SyncProblemAction.cleanup,
        'Retry cleanup',
        'Old cloud cleanup incomplete',
      ),
      CloudFailureKind.quota => const SyncProblem(
        'Google Drive storage is full',
        'Google Drive does not have enough storage to finish sync. Free space in your Google account, then retry. Your local changes are kept.',
        SyncProblemAction.storage,
        'Manage Google storage',
        'Storage full',
      ),
      CloudFailureKind.temporary => const SyncProblem(
        'Google Drive is temporarily unavailable',
        'The request could not finish. Your local changes are saved. Wait a moment, then retry.',
        SyncProblemAction.retry,
        'Retry sync',
        'Waiting for connection',
      ),
      CloudFailureKind.unknown => const SyncProblem(
        'Sync did not finish',
        'Your local changes and retained versions are saved. Retry from Sync settings. If it continues, keep your backups and report the phase and visible status.',
        SyncProblemAction.retry,
        'Retry sync',
        'Sync failed',
      ),
    };
  }
}
