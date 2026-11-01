import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../data/app_database.dart';

import '../data/backup_service.dart';
import '../data/life_repository.dart';
import '../data/sync_exchange_models.dart';
import '../data/cloud/google_drive_auth.dart';
import '../data/cloud/cloud_storage_provider.dart';
import '../data/cloud/google_drive_provider.dart';
import '../data/cloud/sync_engine.dart';
import '../data/cloud/sync_pairing_service.dart';

final syncControllerProvider = ChangeNotifierProvider<SyncController?>(
  (ref) => null,
);

class SyncController extends ChangeNotifier {
  SyncController({
    required this.repository,
    required this.recovery,
    required this.auth,
    required SyncStorageProvider storage,
    required this.pairing,
    required this.isUnlocked,
    required this.onApplied,
    this.scheduleBackground,
    this.closeTransport,
    Duration? timeBudget,
    Future<bool> Function()? canExchange,
  }) {
    engine = SyncEngine(
      repository: repository,
      storage: storage,
      recovery: recovery,
      loadKey: pairing.loadKey,
      verifyWorkspace: pairing.verifyWorkspace,
      isUnlocked: isUnlocked,
      onRemoteApplied: onApplied,
      timeBudget: timeBudget,
      canExchange: canExchange,
    );
    _subscription = engine.changes.listen((_) {
      if (!_disposed) notifyListeners();
    });
  }
  final LifeRepository repository;
  final BackupService recovery;
  final GoogleDriveAuth auth;
  final SyncPairingService pairing;
  final bool Function() isUnlocked;
  final Future<void> Function() onApplied;
  final Future<void> Function(bool enabled)? scheduleBackground;
  final VoidCallback? closeTransport;
  late final SyncEngine engine;
  StreamSubscription<SyncEngineStatus>? _subscription;
  SyncExchangeStatus? snapshot;
  bool busy = false, _disposed = false;
  String? message;
  SyncEngineStatus get status => engine.status;

  String get label => auth.needsReconnect
      ? 'Reconnect Google Drive'
      : switch (status.phase) {
          SyncPhase.disconnected => 'Connect Google Drive',
          SyncPhase.idle => 'Automatic sync is off',
          SyncPhase.syncing => 'Syncing',
          SyncPhase.pending => 'Changes pending',
          SyncPhase.upToDate => 'Up to date',
          SyncPhase.needsAttention => 'Needs attention',
          SyncPhase.offline => 'Waiting for connection',
          SyncPhase.error => 'Sync error',
        };

  Future<void> initialize() async {
    try {
      snapshot = await repository.syncExchangeStatus();
      try {
        await auth.load();
      } catch (_) {
        message = 'Reconnect Google Drive to resume. Local data, pending history and the workspace key are retained.';
      }
      engine.start();
    } catch (_) {
      message = 'Sync could not initialize. Local data and pending work are retained.';
    }
    if (!_disposed) notifyListeners();
  }

  void privacyChanged() {
    if (!isUnlocked()) auth.flow.cancel();
    if (!_disposed) notifyListeners();
    if (isUnlocked()) unawaited(syncNow());
  }

  Future<void> _action(Future<void> Function() action) async {
    if (busy || !isUnlocked() || _disposed) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      message = error is CloudFailure ? error.message : 'Sync needs attention. Local data, pending changes and competing versions are retained.';
    } finally {
      try {
        snapshot = await repository.syncExchangeStatus();
      } catch (_) {}
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> connect() => _action(auth.connect);

  void connectionChanged() {
    if (_disposed) return;
    notifyListeners();
    unawaited(engine.syncNow());
  }

  void localChanged() {
    engine.localChanged();
    if (snapshot?.automatic == true) {
      unawaited(
        scheduleBackground?.call(true).catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
  }

  Future<void> activate({String? recoveryCode}) => _action(() async {
    final prepared = await pairing.prepare(recoveryCode: recoveryCode);
    if (!isUnlocked()) return;
    await repository.activateSyncCapture(
      workspaceId: prepared.binding.workspace,
      accountId: prepared.binding.account,
      deviceId: prepared.binding.device,
      recovery: recovery,
    );
    await repository.setAutomaticSync(prepared.binding, true);
    await scheduleBackground?.call(true);
    await engine.syncNow(manual: true);
  });

  Future<void> reconcileRestored({String? recoveryCode}) => _action(() async {
    final hadVault = await pairing.saved() != null;
    final original = await recovery.restorationRecoveryBackup();
    if (original == null && hadVault) {
      message = 'The original Before Restore receipt is unavailable. Keep the profile and recover that snapshot before reconnecting its pending sync history.';
      return;
    }
    if (original != null &&
        original.schemaVersion >= 23 &&
        original.schemaVersion != AppDatabase.currentSchemaVersion) {
      message = 'This private prototype snapshot needs a reviewed schema conversion. Its immutable history and recovery files are retained.';
      return;
    }
    final prepared = await pairing.freshRestoredDevice(
      recoveryCode: recoveryCode,
    );
    if (!isUnlocked()) return;
    AppDatabase? source;
    try {
      if (original != null &&
          original.schemaVersion == AppDatabase.currentSchemaVersion) {
        source = AppDatabase(
          NativeDatabase.opened(
            sqlite.sqlite3.open(
              original.file.path,
              mode: sqlite.OpenMode.readOnly,
            ),
            enableMigrations: false,
          ),
        );
      }
      await repository.reconcileRestoredSync(
        binding: prepared.binding,
        recovery: recovery,
        beforeRestore: source,
      );
    } finally {
      await source?.close();
    }
    await onApplied();
    message = 'Restored records and retained pre-restore work are preserved as separate causal candidates. Automatic sync remains off. Use Sync Now to exchange and review conflicts.';
  });

  Future<void> setAutomatic(bool enabled) => _action(() async {
    final binding = (await repository.syncExchangeStatus()).binding;
    if (binding == null) throw StateError('Pair this profile first');
    await repository.setAutomaticSync(binding, enabled);
    await scheduleBackground?.call(enabled);
    if (enabled) await engine.syncNow();
  });

  Future<void> syncNow({bool manual = false}) => _action(() async {
    await engine.syncNow(manual: manual);
  });

  Future<SyncConflictReview?> reviewConflicts() async {
    if (!isUnlocked()) return null;
    final binding = (await repository.syncExchangeStatus()).binding;
    if (binding == null) return null;
    final lease = await repository.acquireSyncLease(binding);
    if (lease == null) return null;
    try {
      return await repository.reviewSyncConflicts(binding, lease: lease);
    } finally {
      await repository.releaseSyncLease(lease);
    }
  }

  Future<void> dismiss(SyncConflictReview review) async {
    final binding = (await repository.syncExchangeStatus()).binding;
    if (binding == null || !isUnlocked()) return;
    final lease = await repository.acquireSyncLease(binding);
    if (lease == null) return;
    try {
      await repository.dismissSyncConflicts(binding, review, lease: lease);
    } finally {
      await repository.releaseSyncLease(lease);
    }
  }

  Future<SyncApplyResult?> resolve(
    SyncConflictReview review,
    Map<String, SyncResolutionChoice> choices,
  ) async {
    SyncApplyResult? result;
    await _action(() async {
      // Fetch known cloud changes before accepting a popup's decisions. SQL
      // then revalidates every local/retained revision under its writer lock.
      await engine.syncNow(manual: true);
      if (!isUnlocked() ||
          engine.status.notice != null ||
          engine.status.phase == SyncPhase.disconnected ||
          engine.status.phase == SyncPhase.error ||
          engine.status.phase == SyncPhase.offline) {
        message = 'Reconnect and refresh the review before applying decisions.';
        return;
      }
      final binding = (await repository.syncExchangeStatus()).binding;
      if (binding == null) return;
      final lease = await repository.acquireSyncLease(binding);
      if (lease == null) {
        message = 'Another sync job is active. Try again shortly.';
        return;
      }
      try {
        result = await repository.resolveSyncConflicts(
          binding,
          lease: lease,
          reviewedToken: review.token,
          choices: choices,
        );
      } finally {
        await repository.releaseSyncLease(lease);
      }
      if (result?.state == SyncApplyState.applied) {
        await onApplied();
        message = 'Decisions saved on this device. Queued resolutions will upload when connected.';
        await engine.syncNow(manual: true);
      } else {
        message = result?.state == SyncApplyState.retry
            ? 'New changes arrived. Review the refreshed versions.'
            : 'These choices cannot yet be applied safely. Review the related records; all versions are retained.';
      }
    });
    return result;
  }

  Future<String?> recoveryCode() async {
    if (!isUnlocked()) return null;
    return (await pairing.saved())?.key.exportRecoveryCode();
  }

  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await engine.close();
    closeTransport?.call();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
