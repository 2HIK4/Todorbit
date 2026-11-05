import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../backup_service.dart';
import '../life_repository.dart';
import '../sync_exchange_models.dart';
import 'cloud_storage_provider.dart';
import 'google_drive_auth.dart';
import 'google_drive_provider.dart';
import 'sync_batch_codec.dart';
import 'sync_workspace_format.dart';
import 'sync_generation.dart';

class SyncPairing {
  const SyncPairing(
    this.binding,
    this.key, {
    this.proof,
    this.introSeen = true,
  });
  final SyncBinding binding;
  final SyncWorkspaceKey key;
  final Uint8List? proof;
  final bool introSeen;
}

class SyncRecoveryRequired extends CloudFailure {
  const SyncRecoveryRequired()
    : super(
        'Unlock the existing encrypted workspace with its passphrase or recovery code.',
        kind: CloudFailureKind.credentials,
      );
}

class SyncPairingService {
  SyncPairingService({
    required this.storage,
    required this.vault,
    this.resetVault,
  });
  final CloudStorageProvider storage;
  final CloudTokenStore vault;
  final CloudTokenStore? resetVault;
  static const _proofFormat = 'todorbit-sync-workspace:1:aes256gcm';
  static const _uuid = Uuid();
  Future<SyncPairing>? _preparing;
  bool passwordAvailable = false;

  static String workspaceFor(String account) => _uuid.v5(
    '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
    'todorbit:sync:1:$account',
  );

  Future<SyncPairing?> saved() async {
    final raw = await vault.read();
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map;
      final standard =
          {2, 3}.contains(value['format']) && value['mode'] == 'standard';
      final modernPrivate =
          {2, 3}.contains(value['format']) && value['mode'] == 'private';
      if ((!standard && !modernPrivate && value['format'] != 1) ||
          value.length !=
              (standard
                  ? 6
                  : modernPrivate
                  ? 8
                  : 5) ||
          ({2, 3}.contains(value['format']) && value['introSeen'] is! bool) ||
          value['account'] is! String ||
          (value['workspace'] is! String ||
              !Uuid.isValidUUID(fromString: value['workspace'] as String) ||
              (value['format'] != 3 &&
                  value['workspace'] !=
                      workspaceFor(value['account'] as String))) ||
          value['device'] is! String ||
          !Uuid.isValidUUID(fromString: value['device'] as String)) {
        throw const FormatException();
      }
      return SyncPairing(
        SyncBinding(
          workspace: value['workspace'] as String,
          account: value['account'] as String,
          device: value['device'] as String,
        ),
        standard
            ? SyncWorkspaceKey.standard()
            : SyncWorkspaceKey.fromRecoveryCode(value['recovery'] as String),
        proof: modernPrivate ? base64Decode(value['proof'] as String) : null,
        introSeen: value['introSeen'] as bool? ?? true,
      );
    } catch (_) {
      throw const FormatException(
        'The protected sync credential is damaged. Retain it and use workspace recovery.',
      );
    }
  }

  Future<SyncWorkspaceKey?> loadKey(SyncBinding binding) async {
    final current = await saved();
    if (current == null) return null;
    if (current.binding.workspace != binding.workspace ||
        current.binding.account != binding.account ||
        current.binding.device != binding.device) {
      throw StateError(
        'This profile and its protected sync key belong to different bindings.',
      );
    }
    return current.key;
  }

  Future<void> saveReplacement(SyncPairing pairing) => _save(pairing);

  Future<void> _save(SyncPairing pairing) => vault.write(
    jsonEncode({
      'format':
          pairing.binding.workspace != workspaceFor(pairing.binding.account)
          ? 3
          : pairing.key.isStandard || pairing.proof != null
          ? 2
          : 1,
      'workspace': pairing.binding.workspace,
      'account': pairing.binding.account,
      'device': pairing.binding.device,
      if (!pairing.key.isStandard) 'recovery': pairing.key.exportRecoveryCode(),
      if (pairing.key.isStandard || pairing.proof != null) ...{
        'mode': pairing.key.isStandard ? 'standard' : 'private',
        'introSeen': pairing.introSeen,
      },
      if (pairing.proof != null) 'proof': base64Encode(pairing.proof!),
    }),
  );

  Future<void> dismissIntroduction() async {
    final current = await saved();
    if (current == null || !current.key.isStandard) return;
    await _save(SyncPairing(current.binding, current.key, introSeen: true));
  }

  Future<SyncPairing> prepare({
    String? recoveryCode,
    String? password,
    SyncWorkspaceKey? privateKey,
    bool joinGeneration = false,
  }) => _preparing ??= _prepare(
    recoveryCode,
    password,
    privateKey,
    joinGeneration: joinGeneration,
  ).whenComplete(() => _preparing = null);

  Future<SyncPairing> _prepare(
    String? recoveryCode,
    String? password,
    SyncWorkspaceKey? privateKey, {
    SyncBinding? retainedBinding,
    bool joinGeneration = false,
  }) async {
    if (!joinGeneration && resetVault != null) {
      final raw = await resetVault!.read();
      if (raw != null &&
          !{
            'complete',
            'cleanup',
          }.contains((jsonDecode(raw) as Map)['phase'])) {
        throw const CloudFailure(
          'Finish replacement setup first',
          kind: CloudFailureKind.reset,
        );
      }
    }
    final account = storage.account?.id;
    if (account == null) {
      throw const CloudFailure('Connect Google Drive before pairing.');
    }
    final retained = await saved();
    if (retained != null && retained.binding.account != account) {
      throw const CloudFailure(
        'This profile is paired with a different account. Its pending work and key are retained.',
        kind: CloudFailureKind.account,
      );
    }
    // Only a successful complete listing can establish an empty workspace.
    final objects = await storage.list();
    _checkAccount(account);
    final generation = await SyncGeneration.read(storage, account, objects);
    final workspace = generation.active ?? workspaceFor(account);
    if (joinGeneration && generation.active == null) {
      throw const CloudFailure(
        'No replacement generation to reconnect',
        kind: CloudFailureKind.stale,
      );
    }
    final previous = joinGeneration ? null : retained;
    if (!joinGeneration &&
        (previous?.binding.workspace ??
                retainedBinding?.workspace ??
                workspace) !=
            workspace) {
      throw const CloudFailure(
        'Workspace replaced',
        kind: CloudFailureKind.stale,
      );
    }
    if (objects.any(
      (o) =>
          o.accountId != account ||
          (generation.heads.isEmpty &&
              o.properties['workspaceId'] != workspace),
    )) {
      throw const CloudFailure(
        'Unfinished or unknown workspace setup',
        kind: CloudFailureKind.reset,
      );
    }
    final proofs = objects
        .where(
          (o) =>
              o.properties['kind'] == 'workspace' &&
              o.properties['workspaceId'] == workspace,
        )
        .toList();
    if (proofs.any((proof) => proof.properties['state'] == 'migrating')) {
      throw const CloudFailure(
        'Cloud encryption is being migrated. Retry later; local changes are retained.',
        kind: CloudFailureKind.migrating,
      );
    }
    final binding =
        previous?.binding ??
        (joinGeneration ? null : retainedBinding) ??
        SyncBinding(workspace: workspace, account: account, device: _uuid.v4());
    SyncWorkspaceKey? key = previous?.key;
    Uint8List? retainedProof = previous?.proof;
    if (privateKey != null && key?.isStandard == true) {
      throw const CloudFailure(
        'This Standard workspace cannot safely be converted in this version. Its data and mode are unchanged.',
      );
    }
    if (proofs.isEmpty) {
      if (retainedBinding != null) {
        throw const CloudFailure(
          'The original cloud workspace is missing. No replacement was initialized.',
        );
      }
      if (objects.isNotEmpty) {
        throw const CloudFailure(
          'Workspace proof is missing. Retain cloud history and recover the existing workspace.',
        );
      }
      if (recoveryCode != null ||
          (password != null && privateKey == null && previous == null)) {
        throw const CloudFailure(
          'The existing cloud workspace could not be found. Recovery will not initialize a replacement.',
        );
      }
      // Explicit private setup is optional; ordinary connection uses Standard.
      key ??= privateKey ?? SyncWorkspaceKey.standard();
      retainedProof ??= key.isStandard || password != null
          ? await SyncWorkspaceFormat.create(binding, key, password)
          : await _createProof(binding, key);
      final created = SyncPairing(
        binding,
        key,
        proof: key.isStandard
            ? null
            : (password != null || previous?.proof != null
                  ? retainedProof
                  : null),
        introSeen: previous?.introSeen ?? !key.isStandard,
      );
      // Persist the sole private key AND retryable wrapped proof before HTTP.
      await _save(created);
      await storage.upload(retainedProof, {
        'kind': 'workspace',
        'protocol': key.isStandard || created.proof != null ? '2' : '1',
        'workspaceId': workspace,
        'deviceId': binding.device,
        'batchId': _uuid.v4(),
      }, (_, _, _) {});
    } else {
      if (proofs.length > 64) {
        throw const CloudFailure(
          'Too many workspace proofs. Review cloud workspace recovery.',
        );
      }
      final first = proofs.first;
      if (first.properties['protocol'] == '2') {
        final bytes = await storage.download(first, (_, _, _) {});
        _checkAccount(account);
        final data = SyncWorkspaceFormat.read(bytes, binding);
        passwordAvailable = data['mode'] == 'private';
        if (data['mode'] == 'standard') {
          if (privateKey != null) {
            throw const CloudFailure(
              'Existing Standard Sync data was found. Encryption conversion is unavailable; the cloud was not changed. Connect normally to keep syncing.',
            );
          }
          if (key != null && !key.isStandard) {
            throw const CloudFailure(
              'Cloud encryption differs from this device. Its key and pending work are retained.',
            );
          }
          key = SyncWorkspaceKey.standard();
        } else {
          if (key?.isStandard == true) {
            throw const CloudFailure(
              'Cloud encryption changed. Keep this profile and recover the original workspace.',
            );
          }
          if (key == null) {
            if (recoveryCode != null) {
              key = _recoveryInput(recoveryCode);
            } else if (password != null) {
              try {
                key = await SyncWorkspaceFormat.unlock(data, binding, password);
              } catch (_) {
                throw const CloudFailure(
                  'The passphrase could not unlock this workspace. Try again or use its recovery code.',
                  kind: CloudFailureKind.wrongCredential,
                );
              }
            } else {
              throw const SyncRecoveryRequired();
            }
          }
          retainedProof = bytes;
        }
      } else if (first.properties['protocol'] == '1') {
        if (key?.isStandard == true) {
          throw const CloudFailure(
            'Cloud encryption differs from this device. Pending changes are retained.',
          );
        }
        if (key == null) {
          if (recoveryCode == null) throw const SyncRecoveryRequired();
          key = _recoveryInput(recoveryCode);
        }
      } else {
        throw const CloudFailure(
          'This cloud workspace needs a compatible Todorbit version. Nothing was replaced.',
          kind: CloudFailureKind.incompatible,
        );
      }
      if (recoveryCode != null &&
          !key.isStandard &&
          key.exportRecoveryCode() !=
              _recoveryInput(recoveryCode).exportRecoveryCode()) {
        throw const CloudFailure(
          'The entered code differs from the retained workspace key. Nothing was replaced.',
        );
      }
    }
    await verifyWorkspace(binding, key, ignoreReset: joinGeneration);
    _checkAccount(account);
    final result = SyncPairing(
      binding,
      key,
      proof: key.isStandard ? null : retainedProof,
      introSeen: previous?.introSeen ?? true,
    );
    // Keep the first-time Standard explanation pending until acknowledged.
    final stored = await saved();
    final finalResult = SyncPairing(
      binding,
      key,
      proof: result.proof,
      introSeen: stored?.introSeen ?? result.introSeen,
    );
    if (!joinGeneration) await _save(finalResult);
    return finalResult;
  }

  Future<void> recoverKey(
    SyncBinding binding,
    String? recoveryCode, {
    String? password,
  }) async {
    _checkAccount(binding.account);
    final previous = await saved();
    if (previous != null &&
        (previous.binding.workspace != binding.workspace ||
            previous.binding.account != binding.account ||
            previous.binding.device != binding.device)) {
      throw const CloudFailure(
        'The retained authorization differs. No key was replaced.',
      );
    }
    // Authenticate before persisting, keeping the retained SQL device identity.
    await (_preparing ??= _prepare(
      recoveryCode,
      password,
      null,
      retainedBinding: binding,
    ).whenComplete(() => _preparing = null));
  }

  Future<SyncPairing> activate(
    LifeRepository repository,
    BackupService recovery, {
    String? recoveryCode,
  }) async {
    final pairing = await prepare(recoveryCode: recoveryCode);
    _checkAccount(pairing.binding.account);
    await repository.activateSyncCapture(
      workspaceId: pairing.binding.workspace,
      accountId: pairing.binding.account,
      deviceId: pairing.binding.device,
      recovery: recovery,
    );
    return pairing;
  }

  Future<SyncPairing> freshRestoredDevice({String? recoveryCode}) async {
    final existing = await prepare(recoveryCode: recoveryCode);
    final binding = SyncBinding(
      workspace: existing.binding.workspace,
      account: existing.binding.account,
      device: _uuid.v4(),
    );
    // Write the new identity before SQL can commit it. The quarantined profile
    // cannot exchange in between; a failed SQL attempt retains both snapshots
    // and can retry with another unused identity without reusing old clocks.
    await _save(
      SyncPairing(
        binding,
        existing.key,
        proof: existing.proof,
        introSeen: existing.introSeen,
      ),
    );
    return SyncPairing(binding, existing.key);
  }

  SyncWorkspaceKey _recoveryInput(String value) {
    try {
      return SyncWorkspaceKey.fromRecoveryCode(value);
    } catch (_) {
      throw const CloudFailure(
        'Invalid entered recovery credential',
        kind: CloudFailureKind.wrongCredential,
      );
    }
  }

  void _checkAccount(String account) {
    if (storage.account?.id != account) {
      throw const CloudFailure(
        'Google account changed during pairing. No local data was paired.',
        kind: CloudFailureKind.account,
      );
    }
  }

  List<int> _aad(SyncBinding b) =>
      utf8.encode(jsonEncode([_proofFormat, b.workspace, b.account]));

  Future<Uint8List> _createProof(
    SyncBinding binding,
    SyncWorkspaceKey key,
  ) async {
    final encrypted = await AesGcm.with256bits().encrypt(
      utf8.encode(
        jsonEncode({
          'protocol': 1,
          'workspace': binding.workspace,
          'account': binding.account,
        }),
      ),
      secretKey: key.secretKey,
      aad: _aad(binding),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _proofFormat,
          'nonce': base64Encode(encrypted.nonce),
          'ciphertext': base64Encode(encrypted.cipherText),
          'tag': base64Encode(encrypted.mac.bytes),
        }),
      ),
    );
  }

  Future<void> verifyWorkspace(
    SyncBinding binding,
    SyncWorkspaceKey key, {
    bool ignoreReset = false,
  }) async {
    _checkAccount(binding.account);
    final provider = storage;
    final objects = await (provider is SyncStorageProvider
        ? provider.listWorkspaceProofs()
        : provider.list());
    _checkAccount(binding.account);
    final resetRaw = await resetVault?.read();
    if (!ignoreReset && resetRaw != null) {
      final reset = jsonDecode(resetRaw) as Map;
      if (!{'complete', 'cleanup'}.contains(reset['phase'])) {
        throw const CloudFailure(
          'Replacement pending',
          kind: CloudFailureKind.reset,
        );
      }
    }
    final generation = await SyncGeneration.read(
      storage,
      binding.account,
      objects,
    );
    final active = generation.active ?? workspaceFor(binding.account);
    if (active != binding.workspace) {
      throw const CloudFailure(
        'Workspace replaced',
        kind: CloudFailureKind.stale,
      );
    }
    if (objects.any(
      (o) =>
          o.accountId != binding.account ||
          (generation.heads.isEmpty &&
              o.properties['workspaceId'] != binding.workspace),
    )) {
      throw const CloudFailure(
        'Unfinished workspace setup',
        kind: CloudFailureKind.reset,
      );
    }
    final proofs = objects
        .where(
          (o) =>
              o.properties['kind'] == 'workspace' &&
              o.properties['workspaceId'] == binding.workspace,
        )
        .toList();
    if (proofs.isEmpty) {
      throw const CloudFailure(
        'Workspace proof missing',
        kind: CloudFailureKind.missing,
      );
    }
    await _verifyProofs(binding, key, proofs);
  }

  Future<void> _verifyProofs(
    SyncBinding binding,
    SyncWorkspaceKey key,
    List<CloudObject> proofs,
  ) async {
    if (proofs.length > 64) {
      throw const CloudFailure(
        'Too many workspace proofs. Review cloud workspace recovery.',
      );
    }
    for (final proof in proofs) {
      if (proof.properties['state'] == 'migrating') {
        throw const CloudFailure(
          'Cloud encryption is being migrated. Retry later; local changes are retained.',
          kind: CloudFailureKind.migrating,
        );
      }
      if (proof.accountId != binding.account ||
          proof.bytes > 8192 ||
          !{'1', '2'}.contains(proof.properties['protocol']) ||
          proof.properties['workspaceId'] != binding.workspace ||
          proof.properties['application'] != 'todorbit-sync') {
        throw const FormatException('Invalid workspace proof identity');
      }
      // A completed upload may lose its reply before the sender's readback
      // marker is written. The account-bound AES-GCM proof below is required
      // regardless of that mutable transport marker; never replace the key.
      final bytes = await storage.download(proof, (_, _, _) {});
      _checkAccount(binding.account);
      if (proof.properties['protocol'] == '2') {
        final data = SyncWorkspaceFormat.read(bytes, binding);
        try {
          await SyncWorkspaceFormat.verify(data, binding, key);
        } catch (_) {
          throw const CloudFailure(
            'Cloud mode or private credentials differ. All local data and keys are retained.',
            kind: CloudFailureKind.wrongCredential,
          );
        }
        continue;
      }
      if (key.isStandard) {
        throw const CloudFailure(
          'Encrypted cloud history requires its original recovery key. Nothing was replaced.',
        );
      }
      try {
        if (bytes.length > 4096) throw const FormatException();
        final data = jsonDecode(utf8.decode(bytes)) as Map;
        if (data.length != 4 || data['format'] != _proofFormat) {
          throw const FormatException();
        }
        final nonce = base64Decode(data['nonce'] as String),
            tag = base64Decode(data['tag'] as String);
        if (nonce.length != 12 || tag.length != 16) {
          throw const FormatException();
        }
        final clear = await AesGcm.with256bits().decrypt(
          SecretBox(
            base64Decode(data['ciphertext'] as String),
            nonce: nonce,
            mac: Mac(tag),
          ),
          secretKey: key.secretKey,
          aad: _aad(binding),
        );
        final value = jsonDecode(utf8.decode(clear)) as Map;
        if (value.length != 3 ||
            value['protocol'] != 1 ||
            value['workspace'] != binding.workspace ||
            value['account'] != binding.account) {
          throw const FormatException();
        }
      } catch (_) {
        throw const CloudFailure(
          'The recovery code cannot authenticate every workspace proof. Retain all keys/history and recover the original pairing.',
          kind: CloudFailureKind.wrongCredential,
        );
      }
    }
  }
}
