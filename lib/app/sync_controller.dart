import 'dart:async';

import '../data/private_test_environment.dart';

import 'dart:convert';
import 'dart:io';

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
import '../data/cloud/sync_batch_codec.dart';
import '../data/cloud/sync_reset_service.dart';
import '../data/cloud/sync_problem.dart';

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
    CloudTokenStore? resetVault,
    Duration? timeBudget,
    Future<bool> Function()? canExchange,
  }) {
    if (resetVault != null) {
      reset = SyncResetService(
        repository: repository,
        recovery: recovery,
        pairing: pairing,
        vault: resetVault,
        isUnlocked: isUnlocked,
        onStage: (stage) {
          resetStage = stage;
          if (!_disposed) notifyListeners();
        },
      );
    }
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
    _subscription = engine.changes.listen((value) {
      if (_disposed) return;
      if (_standardIntroPending &&
          value.lastSuccess != null &&
          value.notice == null &&
          (value.phase == SyncPhase.upToDate ||
              value.phase == SyncPhase.needsAttention)) {
        standardIntroduction = true;
      }
      if (_pendingDecisionNotice &&
          value.pending == 0 &&
          value.notice == null &&
          (value.phase == SyncPhase.upToDate ||
              value.phase == SyncPhase.needsAttention)) {
        _pendingDecisionNotice = false;
        if (message == null || message == _decisionsPending) {
          message = _decisionsSynced;
        }
      }
      notifyListeners();
    });
  }
  final LifeRepository repository;
  Future<void> _draftWrite = Future.value();
  File get _decisionDraft =>
      File('${recovery.databaseFile.parent.path}/sync-decision-draft.json');

  Future<Map<String, SyncResolutionChoice>> loadDecisionDraft(
    SyncConflictReview review,
  ) async {
    await _draftWrite;
    if (!await _decisionDraft.exists()) return {};
    final json = jsonDecode(await _decisionDraft.readAsString());
    if (json is! Map || json['token'] != review.token) return {};
    final saved = json['choices'];
    if (saved is! Map) return {};
    return {
      for (final record in review.records)
        if (saved.containsKey(record.id) &&
            (saved[record.id] == null ||
                record.remoteHeads.contains(saved[record.id])))
          record.id: saved[record.id] == null
              ? const SyncResolutionChoice.local()
              : SyncResolutionChoice.revision(saved[record.id] as String),
    };
  }

  Future<void> saveDecisionDraft(
    SyncConflictReview review,
    Map<String, SyncResolutionChoice> choices,
  ) {
    // Device-only IDs and a review fingerprint; no entity values or keys. Queue
    // rapid selections so an older disk write cannot replace a newer draft.
    final bytes = jsonEncode({
      'token': review.token,
      'choices': {
        for (final entry in choices.entries) entry.key: entry.value.revision,
      },
    });
    final operation = _draftWrite.catchError((Object _) {}).then((_) async {
      await _decisionDraft.parent.create(recursive: true);
      final temporary = File('${_decisionDraft.path}.tmp');
      await temporary.writeAsString(bytes, flush: true);
      await temporary.rename(_decisionDraft.path);
    });
    _draftWrite = operation;
    return operation;
  }

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
  bool needsRecoveryCode = false;
  bool reconnectingGeneration = false;
  bool recoveryReminder = false;
  bool? standardSync;
  bool standardIntroduction = false;
  bool _standardIntroPending = false;
  bool _pendingDecisionNotice = false;
  static const _decisionsPending =
      'Decisions saved on this device. Waiting to finish syncing.';
  static const _decisionsSynced =
      'Decisions synced. Other devices will receive them on their next check.';
  String? message;
  SyncResetService? reset;
  Map<String, dynamic>? resetState;
  String? resetStage;
  SyncProblem? _problem;
  SyncProblem? get problem =>
      _problem ??
      (resetState != null &&
              !{'review', 'complete'}.contains(resetState!['phase'])
          ? SyncProblem.from(
              CloudFailure(
                '',
                kind: resetState!['phase'] == 'cleanup'
                    ? CloudFailureKind.cleanup
                    : CloudFailureKind.reset,
              ),
            )
          : status.problem);
  bool get resetPending =>
      resetState != null && resetState!['phase'] != 'complete';
  SyncEngineStatus get status => engine.status;

  String get label =>
      problem?.label ??
      (auth.needsReconnect
          ? 'Reconnect Google Drive'
          : needsRecoveryCode
          ? 'Unlock sync to continue'
          : snapshot?.binding == null && auth.account != null
          ? 'Ready to set up sync'
          : switch (status.phase) {
              SyncPhase.disconnected => 'Sign-in required',
              SyncPhase.idle =>
                snapshot?.automatic == true
                    ? 'Sync paused'
                    : 'Automatic sync is off',
              SyncPhase.syncing => 'Syncing',
              SyncPhase.pending => 'Changes pending',
              SyncPhase.upToDate => 'Up to date',
              SyncPhase.needsAttention =>
                status.conflicts > 0
                    ? 'Conflict needs review'
                    : 'Recovery required',
              SyncPhase.offline => 'Waiting for connection',
              SyncPhase.error => 'Sync failed',
            });

  int get conflictCount => status.conflicts;

  void setForeground(bool active) => engine.setForeground(active);

  Future<void> initialize() async {
    try {
      snapshot = await repository.syncExchangeStatus();
      resetState = await reset?.state();
      try {
        await auth.load();
        final retained = await pairing.saved();
        standardSync = retained?.key.isStandard;
        _standardIntroPending =
            standardSync == true && retained?.introSeen == false;
        standardIntroduction =
            _standardIntroPending && snapshot?.lastSuccess != null;
        if (snapshot?.binding case final binding?) {
          needsRecoveryCode = await pairing.loadKey(binding) == null;
        }
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
    _problem = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _problem = SyncProblem.from(error);
      needsRecoveryCode =
          error is SyncRecoveryRequired ||
          (error is CloudFailure &&
              {
                CloudFailureKind.credentials,
                CloudFailureKind.wrongCredential,
              }.contains(error.kind));
    } finally {
      try {
        snapshot = await repository.syncExchangeStatus();
        resetState = await reset?.state();
        // Activation can succeed even when retired-cloud cleanup fails. Present
        // the active protected pairing, never the previous workspace's privacy
        // label or credential prompt. Staged/unverified operations stay blocked.
        if (resetState != null &&
            {'cleanup', 'complete'}.contains(resetState!['phase'])) {
          final active = await pairing.saved();
          if (active != null &&
              active.binding.workspace == snapshot?.binding?.workspace &&
              active.binding.account == snapshot?.binding?.account &&
              active.binding.device == snapshot?.binding?.device) {
            standardSync = active.key.isStandard;
            needsRecoveryCode = false;
          }
        }
      } catch (_) {}
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> reviewNewSync() => _action(() async {
    if (reset == null) throw StateError('Recovery service unavailable');
    await engine.pause();
    try {
      resetState = await reset!.review();
    } finally {
      engine.resume();
    }
  });

  Future<void> cancelNewSyncReview() => _action(() async {
    await reset?.cancelReview();
    resetState = await reset?.state();
  });

  Future<void> startNewSync({String? password, SyncWorkspaceKey? privateKey}) =>
      _action(() async {
        if (reset == null) throw StateError('Recovery service unavailable');
        await engine.pause();
        try {
          await reset!.confirm(password: password, privateKey: privateKey);
          await reset!.resume();
          needsRecoveryCode = false;
          standardSync = (await pairing.saved())?.key.isStandard;
          message = 'New sync is ready. Retired cloud data was removed. Other devices must reconnect. Your local recovery snapshot is kept.';
        } finally {
          engine.resume();
        }
        await _schedule(true);
        await engine.syncNow(manual: true);
      });

  Future<void> resumeNewSync() => _action(() async {
    if (reset == null) throw StateError('Recovery service unavailable');
    await engine.pause();
    try {
      await reset!.resume();
      needsRecoveryCode = false;
      standardSync = (await pairing.saved())?.key.isStandard;
      message =
          'Setup completed. Your local data and recovery snapshot are kept.';
    } finally {
      engine.resume();
    }
    await _schedule(true);
    await engine.syncNow(manual: true);
  });

  Future<void> reconnectGeneration({String? password, String? recoveryCode}) =>
      _action(() async {
        if (reset == null) throw StateError('Recovery service unavailable');
        reconnectingGeneration = true;
        await engine.pause();
        try {
          await reset!.reconnect(
            password: password,
            recoveryCode: recoveryCode,
          );
          needsRecoveryCode = false;
          reconnectingGeneration = false;
          standardSync = (await pairing.saved())?.key.isStandard;
        } finally {
          engine.resume();
        }
        await _schedule(true);
        await engine.syncNow(manual: true);
      });

  Future<void> connect() => _action(auth.connect);

  void connectionChanged() {
    if (_disposed) return;
    notifyListeners();
    unawaited(engine.syncNow());
  }

  Future<void> localChanged() async {
    try {
      final local = await repository.syncExchangeStatus();
      if (_disposed || local.pending == 0) return;
      engine.localChanged();
      if (local.automatic) await scheduleBackground?.call(true);
    } catch (_) {
      // The journal survives a transient read/scheduler failure. Periodic and
      // foreground opportunities retry without a file-watcher feedback loop.
    }
  }

  Future<void> activate({String? recoveryCode, String? password}) =>
      _action(() async {
        final local = await repository.syncExchangeStatus();
        if (local.binding != null && !local.quarantined) {
          await pairing.recoverKey(
            local.binding!,
            recoveryCode,
            password: password,
          );
          standardSync = (await pairing.saved())?.key.isStandard;
          needsRecoveryCode = false;
          await engine.syncNow(manual: true);
          return;
        }
        await _activate(recoveryCode: recoveryCode, password: password);
      });

  Future<void> _activate({
    String? recoveryCode,
    String? password,
    SyncWorkspaceKey? privateKey,
  }) async {
    if (PrivateTestEnvironment.enabled) {
      final retained = await pairing.saved();
      final private =
          privateKey != null ||
          password != null ||
          recoveryCode != null ||
          retained?.key.isStandard == false;
      if (!PrivateTestEnvironment.syncApproved(
        auth.account?.id,
        mode: private ? 'private' : 'standard',
        workspace:
            retained?.binding.workspace ??
            SyncPairingService.workspaceFor(auth.account?.id ?? ''),
      )) {
        throw const CloudFailure(
          'Verify the disposable account, mode and workspace before private-test Sync.',
        );
      }
    }
    final firstDevice = recoveryCode == null && await pairing.saved() == null;
    final prepared = await pairing.prepare(
      recoveryCode: recoveryCode,
      password: password,
      privateKey: privateKey,
    );
    if (!isUnlocked()) return;
    await repository.activateSyncCapture(
      workspaceId: prepared.binding.workspace,
      accountId: prepared.binding.account,
      deviceId: prepared.binding.device,
      recovery: recovery,
    );
    await repository.setAutomaticSync(prepared.binding, true);
    needsRecoveryCode = false;
    standardSync = prepared.key.isStandard;
    _standardIntroPending = prepared.key.isStandard && !prepared.introSeen;
    recoveryReminder = firstDevice && !prepared.key.isStandard;
    await _schedule(true);
    await engine.syncNow(manual: true);
  }

  Future<void> dismissStandardIntroduction() => _action(() async {
    await pairing.dismissIntroduction();
    standardIntroduction = false;
    _standardIntroPending = false;
  });

  Future<void> startPrivateSync(String password, SyncWorkspaceKey key) =>
      _action(() async {
        if ((await repository.syncExchangeStatus()).binding != null) {
          throw const CloudFailure(
            'Changing cloud encryption requires a safe migration. This workspace was not changed.',
          );
        }
        if (auth.account == null || auth.needsReconnect) await auth.connect();
        if (isUnlocked()) await _activate(password: password, privateKey: key);
      });

  Future<void> _schedule(bool enabled) async {
    try {
      await scheduleBackground?.call(enabled);
    } catch (_) {
      message = 'Background checks are unavailable. Sync still works while Todorbit is open.';
    }
  }

  Future<void> reconcileRestored({String? recoveryCode}) => _action(() async {
    final hadVault = await pairing.saved() != null;
    final original = await recovery.restorationRecoveryBackup();
    if (original == null && hadVault) {
      message = 'The original Before Restore receipt is unavailable. Keep the profile and recover that snapshot before reconnecting its pending sync history.';
      return;
    }
    if (original != null &&
        original.schemaVersion >= 23 &&
        !AppDatabase.compatibleSyncHistorySchemas.contains(
          original.schemaVersion,
        )) {
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
          AppDatabase.compatibleSyncHistorySchemas.contains(
            original.schemaVersion,
          )) {
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
    await _schedule(enabled);
    if (enabled) await engine.syncNow();
  });

  Future<void> reconnectAndSync() => _action(() async {
    await auth.connect();
    if (isUnlocked()) await _sync(true);
  });

  Future<void> syncNow({bool manual = false}) => _action(() => _sync(manual));

  Future<void> _sync(bool manual) async {
    if (resetPending && resetState?['phase'] != 'cleanup') {
      throw const CloudFailure(
        'Finish replacement setup first',
        kind: CloudFailureKind.reset,
      );
    }
    if (manual) {
      if (auth.account == null || auth.needsReconnect) {
        await auth.connect();
        if (!isUnlocked()) return;
      }
      final local = await repository.syncExchangeStatus();
      if (local.quarantined) {
        message = 'Review the restored profile before syncing.';
        return;
      }
      if (local.binding == null) {
        await _activate();
        return;
      }
      if (await pairing.loadKey(local.binding!) == null) {
        await pairing.recoverKey(local.binding!, null);
      }
      standardSync = (await pairing.saved())?.key.isStandard;
      needsRecoveryCode = false;
    }
    await engine.syncNow(manual: manual);
  }

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
      if (!isUnlocked()) return;
      if (engine.status.phase != SyncPhase.offline &&
          (engine.status.notice != null ||
              engine.status.phase == SyncPhase.disconnected ||
              engine.status.phase == SyncPhase.error)) {
        message = 'Refresh the review before applying decisions. All versions are retained.';
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
        _pendingDecisionNotice = true;
        message = _decisionsPending;
        await engine.syncNow(manual: true);
        if (engine.status.phase == SyncPhase.upToDate ||
            engine.status.phase == SyncPhase.needsAttention &&
                engine.status.notice == null &&
                engine.status.pending == 0) {
          _pendingDecisionNotice = false;
          message = _decisionsSynced;
        }
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
    final key = (await pairing.saved())?.key;
    return key == null || key.isStandard ? null : key.exportRecoveryCode();
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
