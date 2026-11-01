import 'dart:async';

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

class SyncEngineStatus {
  const SyncEngineStatus(
    this.phase, {
    this.pending = 0,
    this.conflicts = 0,
    this.lastSuccess,
  });
  final SyncPhase phase;
  final int pending, conflicts;
  final DateTime? lastSuccess;
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
    this.onRemoteApplied,
  });
  final LifeRepository repository;
  final SyncStorageProvider storage;
  final BackupService recovery;
  final Future<SyncWorkspaceKey?> Function(SyncBinding) loadKey;
  final bool Function() isUnlocked;
  final Future<void> Function()? onRemoteApplied;
  final _events = StreamController<SyncEngineStatus>.broadcast();
  Stream<SyncEngineStatus> get changes => _events.stream;
  SyncEngineStatus status = const SyncEngineStatus(SyncPhase.disconnected);
  Future<void>? _running;
  Timer? _poll, _debounce;
  bool _closed = false;

  void _emit(SyncEngineStatus value) {
    status = value;
    if (!_closed) _events.add(value);
  }

  void start() {
    if (_closed || _poll != null) return;
    _poll = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(syncNow()),
    );
    unawaited(syncNow());
  }

  void localChanged() {
    if (_closed) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 750),
      () => unawaited(syncNow()),
    );
  }

  Future<void> syncNow({bool manual = false}) {
    if (_closed) return Future.value();
    return _running ??= _cycle(manual).whenComplete(() => _running = null);
  }

  Future<void> _cycle(bool manual) async {
    SyncLease? lease;
    Timer? heartbeat;
    var ownershipLost = false;
    var heartbeatBusy = false;
    var remoteApplied = false;
    try {
      final local = await repository.syncExchangeStatus();
      final binding = local.binding;
      if (binding == null) {
        _emit(const SyncEngineStatus(SyncPhase.disconnected));
        return;
      }
      if (!isUnlocked() ||
          local.quarantined ||
          !local.enabled ||
          (!manual &&
              (!local.automatic ||
                  (local.retryAt?.isAfter(DateTime.now().toUtc()) ?? false)))) {
        _emit(
          SyncEngineStatus(
            local.quarantined ? SyncPhase.needsAttention : SyncPhase.idle,
            pending: local.pending,
            conflicts: local.conflicts,
            lastSuccess: local.lastSuccess,
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
          ),
        );
        return;
      }
      lease = await repository.acquireSyncLease(binding);
      if (lease == null) return;
      final owned = lease;
      Future<void> guard() async {
        if (_closed ||
            !isUnlocked() ||
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
      var bounded = false;
      // The encrypted bytes are staged before HTTP. An ambiguous upload keeps
      // those exact bytes/ID for retry; duplicate remote copies are idempotent.
      for (var i = 0; i < 24; i++) {
        await guard();
        final pending = await repository.prepareNextSyncBatch(
          binding,
          key,
          lease: owned,
        );
        if (pending == null) break;
        final remote = await storage
            .upload(pending.bytes, pending.properties, (_, _, _) {})
            .timeout(const Duration(minutes: 3));
        await guard();
        await repository.acknowledgeSyncBatch(pending, remote, lease: owned);
        if (i == 23) bounded = true;
      }
      var downloaded = 0;
      Future<bool> retain(List<CloudObject> objects) async {
        for (final object in objects) {
          await guard();
          if (object.properties['workspaceId'] != binding.workspace ||
              object.properties['kind'] != 'operations') {
            continue;
          }
          if (await repository.hasRetainedSyncObject(
            binding,
            object,
            lease: owned,
          )) {
            continue;
          }
          if (downloaded >= 48) return false;
          final bytes = await storage
              .download(object, (_, _, _) {})
              .timeout(const Duration(minutes: 3));
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
          final beginning = await storage.startChangeToken();
          if (await retain(await storage.list())) {
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
            final changes = await storage.changes(token);
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
      if (lease != null) {
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
          error is CloudFailure || error is TimeoutException
              ? SyncPhase.offline
              : SyncPhase.error,
          pending: local?.pending ?? status.pending,
          conflicts: local?.conflicts ?? status.conflicts,
          lastSuccess: local?.lastSuccess ?? status.lastSuccess,
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
