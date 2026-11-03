import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../backup_service.dart';
import '../life_repository.dart';
import '../sync_exchange_models.dart';
import 'cloud_storage_provider.dart';
import 'google_drive_provider.dart';
import 'sync_batch_codec.dart';

enum SyncPhase {
  disconnected,
  idle,
  syncing,
  pending,
  upToDate,
  needsAttention,
  offline,
  error,
}

class _SyncCycleYield implements Exception {
  const _SyncCycleYield();
}

class SyncEngineStatus {
  const SyncEngineStatus(
    this.phase, {
    this.pending = 0,
    this.conflicts = 0,
    this.lastSuccess,
    this.notice,
  });
  final SyncPhase phase;
  final int pending, conflicts;
  final DateTime? lastSuccess;
  final String? notice;
}

// Scheduling and authentication adapters call the same bounded exchange. It
// never owns a UI or opens a database; callers supply the active profile.
class SyncEngine {
  SyncEngine({
    required this.repository,
    required this.storage,
    required this.recovery,
    required this.loadKey,
    required this.isUnlocked,
    required this.verifyWorkspace,
    this.onRemoteApplied,
    this.timeBudget,
    this.canExchange,
    this.pollInterval = const Duration(minutes: 2),
    this.changeDebounce = const Duration(milliseconds: 750),
    this.foregroundInterval = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final LifeRepository repository;
  final SyncStorageProvider storage;
  final BackupService recovery;
  final Duration? timeBudget;
  final Future<bool> Function()? canExchange;
  final Duration pollInterval, changeDebounce, foregroundInterval;
  final DateTime Function() _now;
  final Future<SyncWorkspaceKey?> Function(SyncBinding) loadKey;
  final bool Function() isUnlocked;
  final Future<void> Function(SyncBinding, SyncWorkspaceKey) verifyWorkspace;
  final Future<void> Function()? onRemoteApplied;
  final _events = StreamController<SyncEngineStatus>.broadcast();
  Stream<SyncEngineStatus> get changes => _events.stream;
  SyncEngineStatus status = const SyncEngineStatus(SyncPhase.disconnected);
  Future<void>? _running;
  Timer? _poll, _debounce;
  bool _closed = false, _started = false, _foreground = true;
  bool _followup = false;
  bool _runningManual = false, _manualRequested = false;
  DateTime? _lastForegroundCheck;

  void _emit(SyncEngineStatus value) {
    status = value;
    if (!_closed) _events.add(value);
  }

  void start() {
    if (_closed || _started) return;
    _started = true;
    _startPolling();
    unawaited(syncNow());
  }

  void _startPolling() {
    if (!_foreground || _closed || !_started || _poll != null) return;
    _poll = Timer.periodic(pollInterval, (_) => unawaited(syncNow()));
  }

  void setForeground(bool active) {
    if (_closed) return;
    _foreground = active;
    if (!active) {
      _poll?.cancel();
      _poll = null;
      _debounce?.cancel();
      return;
    }
    _startPolling();
    final now = _now();
    if (_lastForegroundCheck == null ||
        now.difference(_lastForegroundCheck!) >= foregroundInterval) {
      _lastForegroundCheck = now;
      unawaited(syncNow());
    }
  }

  void localChanged() {
    if (_closed) return;
    if (_running != null) _followup = true;
    _debounce?.cancel();
    if (!_foreground) return;
    _debounce = Timer(
      changeDebounce,
      () => unawaited(syncNow(localOnly: true)),
    );
  }

  Future<void> syncNow({bool manual = false, bool localOnly = false}) {
    if (_closed) return Future.value();
    if (_running case final current?) {
      if (manual && !_runningManual) _manualRequested = true;
      return current;
    }
    final completed = Completer<void>();
    _running = completed.future;
    _runningManual = manual;
    unawaited(_exchangeRequested(completed, manual, localOnly));
    return completed.future;
  }

  Future<void> _exchangeRequested(
    Completer<void> completed,
    bool manual,
    bool localOnly,
  ) async {
    try {
      do {
        _manualRequested = false;
        _runningManual = manual;
        await _cycle(manual, localOnly: localOnly && !manual);
        manual = _manualRequested;
      } while (manual && !_closed);
    } catch (error, stack) {
      completed.completeError(error, stack);
    } finally {
      _running = null;
      if (!completed.isCompleted) completed.complete();
      if (_followup && !_closed) {
        _followup = false;
        localChanged();
      }
    }
  }

  Future<void> _cycle(bool manual, {bool localOnly = false}) async {
    final deadline = timeBudget == null
        ? null
        : DateTime.now().add(timeBudget!);
    Future<T> network<T>(Future<T> Function() operation) async {
      final remaining = deadline?.difference(DateTime.now());
      if (remaining != null && remaining <= Duration.zero) {
        throw const _SyncCycleYield();
      }
      if (remaining == null) {
        return operation().timeout(const Duration(minutes: 3));
      }
      return operation().timeout(
        remaining,
        onTimeout: () => throw const _SyncCycleYield(),
      );
    }

    SyncLease? lease;
    Timer? heartbeat;
    var ownershipLost = false;
    var heartbeatBusy = false;
    var remoteApplied = false;
    try {
      final local = await repository.syncExchangeStatus();
      // File watchers also observe leases/cursors and remote projection. They
      // must not turn every successful check into another network exchange.
      if (localOnly && local.pending == 0) return;
      final binding = local.binding;
      if (binding == null) {
        _emit(const SyncEngineStatus(SyncPhase.disconnected));
        return;
      }
      if (!isUnlocked() ||
          (canExchange != null && !await canExchange!()) ||
          local.quarantined ||
          !local.enabled ||
          (!manual &&
              (!_foreground ||
                  !local.automatic ||
                  (local.retryAt?.isAfter(DateTime.now().toUtc()) ?? false)))) {
        _emit(
          SyncEngineStatus(
            local.quarantined
                ? SyncPhase.needsAttention
                : local.automatic && local.retryAt != null
                ? SyncPhase.offline
                : SyncPhase.idle,
            pending: local.pending,
            conflicts: local.conflicts,
            lastSuccess: local.lastSuccess,
            notice: local.quarantined
                ? 'Reconcile this restored profile in Sync settings before exchanging changes.'
                : null,
          ),
        );
        return;
      }
      if (await recovery.hasScheduledRestore()) {
        _emit(
          SyncEngineStatus(
            SyncPhase.needsAttention,
            pending: local.pending,
            conflicts: local.conflicts,
            notice: 'Finish or cancel the scheduled restore before syncing.',
          ),
        );
        return;
      }
      if (storage.account?.id != binding.account) {
        _emit(
          SyncEngineStatus(
            SyncPhase.disconnected,
            pending: local.pending,
            conflicts: local.conflicts,
            notice: 'Reconnect the Google account paired with this profile.',
          ),
        );
        return;
      }
      final key = await loadKey(binding);
      if (key == null) {
        _emit(
          SyncEngineStatus(
            SyncPhase.needsAttention,
            pending: local.pending,
            conflicts: local.conflicts,
            notice:
                'Enter the original workspace recovery code in Sync settings.',
          ),
        );
        return;
      }
      lease = await repository.acquireSyncLease(binding);
      if (lease == null) {
        _emit(
          SyncEngineStatus(
            SyncPhase.pending,
            pending: local.pending,
            conflicts: local.conflicts,
            lastSuccess: local.lastSuccess,
            notice: 'Another sync check is running. Try again shortly.',
          ),
        );
        return;
      }
      final owned = lease;
      Future<void> guard() async {
        if (deadline != null && !DateTime.now().isBefore(deadline)) {
          throw const _SyncCycleYield();
        }
        if (_closed ||
            !isUnlocked() ||
            (canExchange != null && !await canExchange!()) ||
            storage.account?.id != binding.account ||
            ownershipLost ||
            await recovery.hasScheduledRestore() ||
            !await repository.renewSyncLease(owned)) {
          throw StateError('Sync ownership or restore barrier changed');
        }
      }

      heartbeat = Timer.periodic(const Duration(seconds: 8), (_) async {
        if (heartbeatBusy) return;
        heartbeatBusy = true;
        try {
          if (!await repository.renewSyncLease(owned)) ownershipLost = true;
        } catch (_) {
          ownershipLost = true;
        } finally {
          heartbeatBusy = false;
        }
      });
      _emit(
        SyncEngineStatus(
          SyncPhase.syncing,
          pending: local.pending,
          conflicts: local.conflicts,
          lastSuccess: local.lastSuccess,
        ),
      );
      await network(() => verifyWorkspace(binding, key));
      await guard();
      var bounded = false;
      // The immutable bytes are staged before HTTP. An ambiguous upload keeps
      // those exact bytes/ID for retry; duplicate remote copies are idempotent.
      for (var i = 0; i < 24; i++) {
        await guard();
        final pending = await repository.prepareNextSyncBatch(
          binding,
          key,
          lease: owned,
        );
        if (pending == null) break;
        final remote = await network(
          () => storage.upload(pending.bytes, pending.properties, (_, _, _) {}),
        );
        await guard();
        await repository.acknowledgeSyncBatch(pending, remote, lease: owned);
        if (i == 23) bounded = true;
      }
      var downloaded = 0;
      Future<bool> retain(List<CloudObject> objects) async {
        for (final object in objects) {
          await guard();
          if (object.properties['workspaceId'] != binding.workspace) {
            throw const FormatException(
              'A different encrypted workspace needs recovery',
            );
          }
          if (object.properties['kind'] == 'workspace') {
            await network(() => verifyWorkspace(binding, key));
            continue;
          }
          if (object.properties['kind'] != 'operations') {
            throw const FormatException('Unsupported sync object kind');
          }
          if (await repository.hasRetainedSyncObject(
            binding,
            object,
            lease: owned,
            protocol: key.isStandard ? '2' : '1',
          )) {
            continue;
          }
          if (downloaded >= 48) return false;
          final bytes = await network(
            () => storage.download(object, (_, _, _) {}),
          );
          await guard();
          await repository.retainIncomingSyncBatch(
            binding,
            key,
            object,
            bytes,
            lease: owned,
          );
          downloaded++;
        }
        return true;
      }

      var token = local.changeToken;
      try {
        if (token == null) {
          // Take the cursor BEFORE listing. Changes concurrent with the scan
          // are replayed rather than lost between list and startPageToken.
          final beginning = await network(storage.startChangeToken);
          if (await retain(await network(storage.list))) {
            await repository.commitSyncChangeToken(
              binding,
              beginning,
              lease: owned,
            );
            token = beginning;
          } else {
            bounded = true;
          }
        }
        if (token != null) {
          final seen = <String>{};
          for (var page = 0; page < 16; page++) {
            await guard();
            if (!seen.add(token!)) {
              throw const FormatException('Repeated Drive cursor');
            }
            final changes = await network(() => storage.changes(token!));
            if (!await retain(changes.objects)) {
              bounded = true;
              break;
            }
            await repository.commitSyncChangeToken(
              binding,
              changes.checkpoint,
              lease: owned,
            );
            token = changes.checkpoint;
            // Removed cloud objects are not user deletion operations. Their
            // authenticated journal and tombstones remain available locally.
            if (!changes.hasMore) break;
            if (page == 15) bounded = true;
          }
        }
      } on DriveCheckpointExpired {
        await repository.commitSyncChangeToken(binding, null, lease: owned);
        bounded = true;
      }
      await repository.advanceRetainedSyncHistory(binding, lease: owned);
      for (var i = 0; i < 128; i++) {
        await guard();
        final applied = await repository.applyNextSyncGroup(
          binding,
          lease: owned,
        );
        if (applied.state == SyncApplyState.applied) remoteApplied = true;
        // Continue past conflicts: a later group can supersede an original
        // branch, and unrelated safe groups must not be blocked by its popup.
        if (applied.state == SyncApplyState.idle ||
            applied.state == SyncApplyState.waiting) {
          break;
        }
        if (i == 127) bounded = true;
      }
      await guard();
      await repository.recordSyncExchange(binding, lease: owned, success: true);
      final after = await repository.syncExchangeStatus();
      _emit(
        SyncEngineStatus(
          after.conflicts > 0
              ? SyncPhase.needsAttention
              : bounded || after.pending > 0 || after.waiting > 0
              ? SyncPhase.pending
              : SyncPhase.upToDate,
          pending: after.pending,
          conflicts: after.conflicts,
          lastSuccess: after.lastSuccess,
        ),
      );
    } catch (error) {
      if (lease != null && error is! _SyncCycleYield && !_closed) {
        try {
          await repository.recordSyncExchange(
            lease.binding,
            lease: lease,
            success: false,
          );
        } catch (_) {
          /* Lost ownership must never overwrite another job's state. */
        }
      }
      SyncExchangeStatus? local;
      try {
        local = await repository.syncExchangeStatus();
      } catch (_) {
        // A closed/unavailable profile cannot prevent the job releasing its
        // ownership or surface as an unhandled timer error.
      }
      _emit(
        SyncEngineStatus(
          error is CloudFailure && error.kind == CloudFailureKind.authentication
              ? SyncPhase.disconnected
              : error is CloudFailure &&
                    {
                      CloudFailureKind.permission,
                      CloudFailureKind.incompatible,
                      CloudFailureKind.corrupt,
                      CloudFailureKind.conflict,
                      CloudFailureKind.migrating,
                    }.contains(error.kind)
              ? SyncPhase.needsAttention
              : error is _SyncCycleYield
              ? SyncPhase.pending
              : error is FormatException
              ? SyncPhase.needsAttention
              : error is CloudFailure ||
                    error is TimeoutException ||
                    error is SocketException ||
                    error is http.ClientException
              ? SyncPhase.offline
              : SyncPhase.error,
          pending: local?.pending ?? status.pending,
          conflicts: local?.conflicts ?? status.conflicts,
          lastSuccess: local?.lastSuccess ?? status.lastSuccess,
          notice: error is FormatException
              ? 'Cloud data could not be verified. Keep your recovery credentials and snapshots; pending work and competing history are retained.'
              : error is CloudFailure
              ? error.message
              : error is TimeoutException
              ? 'The connection timed out. Pending changes will be retried.'
              : error is SocketException || error is http.ClientException
              ? 'The connection was interrupted. Pending changes will be retried.'
              : error is _SyncCycleYield
              ? null
              : 'Sync stopped safely. Local data and pending versions are retained; retry from Sync settings.',
        ),
      );
    } finally {
      heartbeat?.cancel();
      try {
        if (lease != null) await repository.releaseSyncLease(lease);
        if (remoteApplied && !_closed) await onRemoteApplied?.call();
      } catch (_) {
        _emit(
          SyncEngineStatus(
            SyncPhase.error,
            pending: status.pending,
            conflicts: status.conflicts,
            lastSuccess: status.lastSuccess,
          ),
        );
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    _poll?.cancel();
    _debounce?.cancel();
    await _running;
    await _events.close();
  }
}
