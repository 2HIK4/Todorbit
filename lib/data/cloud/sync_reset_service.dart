import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../backup_service.dart';
import '../life_repository.dart';
import '../sync_exchange_models.dart';
import 'cloud_storage_provider.dart';
import 'google_drive_auth.dart';
import 'sync_batch_codec.dart';
import 'sync_generation.dart';
import 'sync_pairing_service.dart';
import 'sync_workspace_format.dart';

/// A secure, resumable local operation plus immutable cloud generation commit.
/// No old cloud content is deleted until a complete readable seed is committed.
class SyncResetService {
  SyncResetService({
    required this.repository,
    required this.recovery,
    required this.pairing,
    required this.vault,
    required this.isUnlocked,
    this.onStage,
  });
  final LifeRepository repository;
  final BackupService recovery;
  final SyncPairingService pairing;
  final CloudTokenStore vault;
  final bool Function() isUnlocked;
  final void Function(String)? onStage;
  CloudStorageProvider get storage => pairing.storage;

  Future<Map<String, dynamic>?> state() async {
    final raw = await vault.read();
    if (raw == null) return null;
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (value['format'] != 1 ||
        value['account'] is! String ||
        value['workspace'] is! String ||
        !Uuid.isValidUUID(fromString: value['workspace'] as String) ||
        value['device'] is! String ||
        !Uuid.isValidUUID(fromString: value['device'] as String) ||
        !{
          'review',
          'upload',
          'activating',
          'cleanup',
          'complete',
          'reconnect',
        }.contains(value['phase']))
      throw const FormatException('Invalid protected replacement operation');
    return value;
  }

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final lock = await File('${recovery.databaseFile.path}.sync-reset.lock')
        .open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      return await work();
    } finally {
      await lock.close();
    }
  }

  void _guard(String account) {
    if (!isUnlocked())
      throw const CloudFailure(
        'Unlock the app before continuing',
        kind: CloudFailureKind.reset,
      );
    if (storage.account?.id != account)
      throw const CloudFailure(
        'Account changed',
        kind: CloudFailureKind.account,
      );
  }

  Future<void> _save(Map<String, dynamic> operation) async {
    final raw = jsonEncode(operation);
    await vault.write(raw);
    if (await vault.read() != raw)
      throw StateError('Recovery state was not durably retained');
  }

  Future<String> _hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> _checkpoint(Map<String, dynamic> op) async {
    final file = File(op['backup'] as String);
    if (!path.isWithin(
          recovery.backupDirectory.absolute.path,
          file.absolute.path,
        ) ||
        await _hash(file) != op['backupHash'])
      throw StateError('Recovery checkpoint cannot be verified');
    if (await recovery.hasScheduledRestore())
      throw StateError('Finish pending restore first');
  }

  /// Read-only cloud inventory and verified manual snapshot, before confirmation.
  Future<Map<String, dynamic>> review() => _exclusive(() async {
    final previous = await state();
    if (previous != null &&
        !{'complete', 'activating'}.contains(previous['phase']))
      throw const CloudFailure(
        'An operation is already pending',
        kind: CloudFailureKind.reset,
      );
    final account = storage.account?.id;
    if (account == null)
      throw const CloudFailure(
        'Sign in required',
        kind: CloudFailureKind.authentication,
      );
    _guard(account);
    final local = await repository.syncExchangeStatus();
    if (local.quarantined ||
        (local.binding != null && local.binding!.account != account))
      throw const CloudFailure(
        'Resolve profile or account first',
        kind: CloudFailureKind.account,
      );
    onStage?.call('Inspecting the selected cloud workspace');
    final objects = await storage.list();
    _guard(account);
    final generation = await SyncGeneration.read(storage, account, objects);
    if (previous?['phase'] == 'activating' &&
        (generation.tips.length < 2 ||
            !generation.heads.containsKey(previous!['workspace']))) {
      throw const CloudFailure(
        'Resume the existing operation',
        kind: CloudFailureKind.reset,
      );
    }
    final known = {
      ...generation.heads.keys,
      SyncPairingService.workspaceFor(account),
    };
    for (final o in objects) {
      if (o.accountId != account ||
          o.properties['application'] != 'todorbit-sync' ||
          !known.contains(o.properties['workspaceId']) ||
          !{'workspace', 'operations', 'head'}.contains(o.properties['kind']) ||
          !{'1', '2', '3'}.contains(o.properties['protocol']) ||
          (o.properties['kind'] == 'head'
              ? o.properties['protocol'] != '3'
              : !{'1', '2'}.contains(o.properties['protocol'])))
        throw const CloudFailure(
          'Unknown or unfinished cloud generation',
          kind: CloudFailureKind.reset,
        );
    }
    onStage?.call('Creating and verifying your local recovery snapshot');
    final backup = await recovery.createBackup(BackupKind.manual);
    final op = <String, dynamic>{
      'prior': previous,
      'selected': generation.tips.isEmpty
          ? [SyncPairingService.workspaceFor(account)]
          : generation.tips.toList(),
      'format': 1,
      'phase': 'review',
      'account': account,
      'workspace': const Uuid().v4(),
      'device': local.binding?.device ?? const Uuid().v4(),
      'previous': local.binding?.workspace,
      'parents': generation.tips.toList()..sort(),
      'retired': known.toList()..sort(),
      'backup': backup.file.absolute.path,
      'backupHash': await _hash(backup.file),
      'oldPairings': [
        ...?previous?['oldPairings'] as List?,
        if (await pairing.vault.read() case final String old) old,
      ],
    };
    _guard(account);
    await _save(op);
    return op;
  });

  Future<void> cancelReview() => _exclusive(() async {
    final op = await state();
    if (op?['phase'] == 'review') {
      if (op!['prior'] == null) {
        await vault.delete();
      } else {
        await _save((op['prior'] as Map).cast<String, dynamic>());
      }
    }
  });

  Future<void> confirm({
    String? password,
    SyncWorkspaceKey? privateKey,
  }) => _exclusive(() async {
    final op = await state();
    if (op == null || op['phase'] != 'review')
      throw StateError('Review required');
    final account = op['account'] as String;
    _guard(account);
    await _checkpoint(op);
    final binding = _binding(op);
    final key = privateKey ?? SyncWorkspaceKey.standard();
    // Passphrase is never persisted. Only the protected key and wrapped proof.
    final proof = await SyncWorkspaceFormat.create(binding, key, password);
    _guard(account);
    op.remove('prior');
    op.addAll({
      'phase': 'upload',
      'standard': key.isStandard,
      'key': key.isStandard ? null : key.exportRecoveryCode(),
      'proof': base64Encode(proof),
    });
    await _save(op);
  });

  SyncBinding _binding(Map<String, dynamic> op) => SyncBinding(
    workspace: op['workspace'] as String,
    account: op['account'] as String,
    device: op['device'] as String,
  );
  SyncWorkspaceKey _key(Map<String, dynamic> op) => op['standard'] == true
      ? SyncWorkspaceKey.standard()
      : SyncWorkspaceKey.fromRecoveryCode(op['key'] as String);

  Future<void> resume() => _exclusive(() async {
    final op = await state();
    if (op == null || op['phase'] == 'review')
      throw const CloudFailure(
        'Confirm the new setup first',
        kind: CloudFailureKind.reset,
      );
    final binding = _binding(op), key = _key(op);
    _guard(binding.account);
    await _checkpoint(op);
    if (op['phase'] == 'reconnect') {
      await _finishReconnect(op, binding, key);
      return;
    }
    var objects = await storage.list();
    _guard(binding.account);
    var generation = await SyncGeneration.read(
      storage,
      binding.account,
      objects,
    );
    if (op['phase'] == 'upload' || op['phase'] == 'activating') {
      if (!generation.heads.containsKey(binding.workspace) &&
          !_same(
            generation.tips,
            (op['parents'] as List).cast<String>().toSet(),
          ))
        throw const CloudFailure(
          'Another replacement was started',
          kind: CloudFailureKind.conflict,
        );
      onStage?.call('Preparing a fresh copy of this device’s records');
      await repository.replaceSyncCapture(
        binding,
        expectedWorkspace: op['previous'] as String?,
      );
      await pairing.saveReplacement(
        SyncPairing(
          binding,
          key,
          proof: key.isStandard ? null : base64Decode(op['proof'] as String),
        ),
      );
      final proof = base64Decode(op['proof'] as String);
      var proofs = objects
          .where(
            (o) =>
                o.properties['kind'] == 'workspace' &&
                o.properties['workspaceId'] == binding.workspace,
          )
          .toList();
      if (proofs.isEmpty) {
        _guard(binding.account);
        await storage.upload(proof, {
          'kind': 'workspace',
          'protocol': '2',
          'workspaceId': binding.workspace,
          'deviceId': binding.device,
          'batchId': binding.workspace,
        }, (_, _, _) {});
      }
      onStage?.call('Uploading your current local data');
      final lease = await repository.acquireSyncLease(binding);
      if (lease == null)
        throw const CloudFailure(
          'Another sync is finishing',
          kind: CloudFailureKind.reset,
        );
      var ownershipLost = false, heartbeatBusy = false;
      final heartbeat = Timer.periodic(const Duration(seconds: 8), (_) async {
        if (heartbeatBusy) return;
        heartbeatBusy = true;
        try {
          if (!await repository.renewSyncLease(lease)) ownershipLost = true;
        } catch (_) {
          ownershipLost = true;
        } finally {
          heartbeatBusy = false;
        }
      });
      try {
        final deadline = DateTime.now().add(const Duration(minutes: 3));
        while (true) {
          _guard(binding.account);
          if (ownershipLost || !await repository.renewSyncLease(lease))
            throw StateError('Sync ownership changed');
          final batch = await repository.prepareNextSyncBatch(
            binding,
            key,
            lease: lease,
          );
          if (batch == null) break;
          if (DateTime.now().isAfter(deadline))
            throw const CloudFailure(
              'Continue uploading on resume',
              kind: CloudFailureKind.reset,
            );
          final remote = await storage.upload(
            batch.bytes,
            batch.properties,
            (_, _, _) {},
          );
          _guard(binding.account);
          // A long HTTP call may outlive the SQL lease; never acknowledge it
          // after losing ownership. Immutable bytes are retried on resume.
          if (ownershipLost || !await repository.renewSyncLease(lease))
            throw const CloudFailure(
              'Upload interrupted',
              kind: CloudFailureKind.reset,
            );
          await repository.acknowledgeSyncBatch(batch, remote, lease: lease);
        }
      } finally {
        heartbeat.cancel();
        await repository.releaseSyncLease(lease);
      }
      onStage?.call('Reading back and verifying the new cloud data');
      objects = await storage.list();
      _guard(binding.account);
      final expected = await repository.outgoingResetBatches(binding);
      final verified = <String>{};
      proofs = objects
          .where(
            (o) =>
                o.properties['kind'] == 'workspace' &&
                o.properties['workspaceId'] == binding.workspace,
          )
          .toList();
      if (proofs.isEmpty)
        throw const FormatException('New workspace proof missing');
      for (final p in proofs) {
        final data = await storage.download(p, (_, _, _) {});
        _guard(binding.account);
        await SyncWorkspaceFormat.verify(
          SyncWorkspaceFormat.read(data, binding),
          binding,
          key,
        );
        if (sha256.convert(data).toString() != sha256.convert(proof).toString())
          throw const FormatException('New workspace proof differs');
      }
      final codec = SyncBatchCodec();
      for (final object in objects.where(
        (o) =>
            o.properties['workspaceId'] == binding.workspace &&
            o.properties['kind'] == 'operations',
      )) {
        final row = expected
            .where((r) => r['id'] == object.properties['batchId'])
            .firstOrNull;
        // After an ambiguous activation another updated device may have joined.
        // Its independently authenticated ops are exchanged by the normal engine.
        if (row == null && generation.heads.containsKey(binding.workspace))
          continue;
        if (row == null)
          throw const FormatException('Unexpected staged operations');
        final bytes = await storage.download(object, (_, _, _) {});
        _guard(binding.account);
        if (sha256.convert(bytes).toString() != row['sha256'])
          throw const FormatException('Seed readback differs');
        final decoded = await codec.decrypt(
          bytes,
          key,
          workspace: binding.workspace,
          account: binding.account,
          expectedSchema: 26,
        );
        if (decoded.id != row['id'])
          throw const FormatException('Seed identity differs');
        verified.add(row['id'] as String);
      }
      if (verified.length != expected.length)
        throw const FormatException('Incomplete seed readback');
      final digest = sha256
          .convert(
            utf8.encode(
              expected.map((r) => '${r['id']}:${r['sha256']}').join('\n'),
            ),
          )
          .toString();
      // Retain the exact immutable commit before HTTP, including ambiguous reply.
      op['head'] ??= base64Encode(
        SyncGeneration.encode(
          account: binding.account,
          workspace: binding.workspace,
          parents: (op['parents'] as List).cast<String>(),
          batches: expected.length,
          digest: digest,
        ),
      );
      op['phase'] = 'activating';
      await _save(op);
      objects = await storage.list();
      _guard(binding.account);
      generation = await SyncGeneration.read(storage, binding.account, objects);
      if (!generation.heads.containsKey(binding.workspace)) {
        if (!_same(
          generation.tips,
          (op['parents'] as List).cast<String>().toSet(),
        ))
          throw const CloudFailure(
            'Concurrent replacements',
            kind: CloudFailureKind.conflict,
          );
        _guard(binding.account);
        onStage?.call('Activating the verified new workspace');
        await storage.upload(base64Decode(op['head'] as String), {
          'kind': 'head',
          'protocol': '3',
          'workspaceId': binding.workspace,
          'deviceId': binding.device,
          'batchId': binding.workspace,
        }, (_, _, _) {});
      }
      await _requireActive(binding);
      op['phase'] = 'cleanup';
      await _save(op);
      await repository.setAutomaticSync(binding, true);
    }
    // The new workspace remains usable if cleanup is interrupted or denied.
    op['phase'] = 'cleanup';
    await _save(op);
    onStage?.call('Removing the retired cloud workspace');
    try {
      await _checkpoint(op);
      await _requireActive(binding);
      objects = await storage.list();
      _guard(binding.account);
      final retired = (op['retired'] as List).cast<String>().toSet()
        ..remove(binding.workspace);
      final targets = objects
          .where(
            (o) =>
                retired.contains(o.properties['workspaceId']) &&
                o.properties['kind'] != 'head',
          )
          .toList();
      for (final object in targets) {
        _guard(binding.account);
        if (object.accountId != binding.account ||
            object.properties['application'] != 'todorbit-sync' ||
            !{'operations', 'workspace'}.contains(object.properties['kind']) ||
            !{'1', '2'}.contains(object.properties['protocol']))
          throw const FormatException('Unknown retired object');
        await _requireActive(binding);
        await storage.delete(object);
      }
      final remaining = await storage.list();
      _guard(binding.account);
      if (remaining.any(
        (o) =>
            retired.contains(o.properties['workspaceId']) &&
            o.properties['kind'] != 'head',
      ))
        throw const CloudFailure(
          'Old files remain',
          kind: CloudFailureKind.cleanup,
        );
      await _requireActive(binding);
      op['phase'] = 'complete';
      await _save(op);
      onStage?.call('New sync is ready. Retired cloud data was removed.');
    } on CloudFailure catch (error) {
      if ({
        CloudFailureKind.account,
        CloudFailureKind.stale,
        CloudFailureKind.conflict,
      }.contains(error.kind))
        rethrow;
      throw const CloudFailure(
        'New sync active; old cleanup incomplete',
        kind: CloudFailureKind.cleanup,
      );
    } catch (_) {
      throw const CloudFailure(
        'New sync active; old cleanup incomplete',
        kind: CloudFailureKind.cleanup,
      );
    }
  });

  bool _same(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
  Future<void> _requireActive(SyncBinding binding) async {
    _guard(binding.account);
    final local = await repository.syncExchangeStatus();
    // Reconnection checks the cloud before its SQL rebind; reset cleanup must
    // never continue against a restored, quarantined or changed local profile.
    final op = await state();
    if (local.quarantined ||
        (op?['phase'] != 'reconnect' &&
            (local.binding?.workspace != binding.workspace ||
                local.binding?.account != binding.account))) {
      throw const CloudFailure(
        'Local sync binding changed',
        kind: CloudFailureKind.stale,
      );
    }
    final objects = await storage.list();
    _guard(binding.account);
    final generation = await SyncGeneration.read(
      storage,
      binding.account,
      objects,
    );
    _guard(binding.account);
    if (generation.active != binding.workspace)
      throw const CloudFailure(
        'Workspace changed',
        kind: CloudFailureKind.stale,
      );
  }

  /// Explicit stale-device reconciliation: current rows become new-generation
  /// operations; old queued operations and conflict candidates stay untouched.
  Future<void> reconnect({
    String? password,
    String? recoveryCode,
  }) => _exclusive(() async {
    final previous = await state();
    if (previous != null && previous['phase'] != 'complete')
      throw const CloudFailure(
        'Finish pending operation',
        kind: CloudFailureKind.reset,
      );
    final local = await repository.syncExchangeStatus();
    if (local.binding == null || local.quarantined)
      throw StateError('Review restored profile first');
    _guard(local.binding!.account);
    final old = await pairing.vault.read();
    final backup = await recovery.createBackup(BackupKind.manual);
    // Joining verifies but does not persist the key. The complete reconnect
    // operation is durable before either SQL or the protected pairing changes.
    final next = await pairing.prepare(
      joinGeneration: true,
      password: password,
      recoveryCode: recoveryCode,
    );
    _guard(local.binding!.account);
    final op = <String, dynamic>{
      'format': 1,
      'phase': 'reconnect',
      'account': local.binding!.account,
      'workspace': next.binding.workspace,
      'device': next.binding.device,
      'previous': local.binding!.workspace,
      'backup': backup.file.absolute.path,
      'backupHash': await _hash(backup.file),
      'oldPairings': [
        ...?previous?['oldPairings'] as List?,
        if (old != null) old,
      ],
      'standard': next.key.isStandard,
      'key': next.key.isStandard ? null : next.key.exportRecoveryCode(),
      'proof': next.proof == null ? null : base64Encode(next.proof!),
    };
    await _save(op);
    await _finishReconnect(op, _binding(op), next.key);
  });

  Future<void> _finishReconnect(
    Map<String, dynamic> op,
    SyncBinding binding,
    SyncWorkspaceKey key,
  ) async {
    await _checkpoint(op);
    await _requireActive(binding);
    await repository.replaceSyncCapture(
      binding,
      expectedWorkspace: op['previous'] as String?,
    );
    await pairing.saveReplacement(
      SyncPairing(
        binding,
        key,
        proof: op['proof'] == null ? null : base64Decode(op['proof'] as String),
      ),
    );
    await repository.setAutomaticSync(binding, true);
    op['phase'] = 'complete';
    // Reconnection never authorizes deleting another device's cloud content.
    op['retired'] = <String>[];
    await _save(op);
  }
}
