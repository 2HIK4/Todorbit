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

class SyncPairing {
  const SyncPairing(this.binding, this.key);
  final SyncBinding binding;
  final SyncWorkspaceKey key;
}

class SyncRecoveryRequired extends CloudFailure {
  const SyncRecoveryRequired()
    : super(
        'Enter the recovery code from your other device to authorize this device once.',
      );
}

class SyncPairingService {
  SyncPairingService({required this.storage, required this.vault});
  final CloudStorageProvider storage;
  final CloudTokenStore vault;
  static const _proofFormat = 'todorbit-sync-workspace:1:aes256gcm';
  static const _uuid = Uuid();
  Future<SyncPairing>? _preparing;

  static String workspaceFor(String account) => _uuid.v5(
    '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
    'todorbit:sync:1:$account',
  );

  Future<SyncPairing?> saved() async {
    final raw = await vault.read();
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map;
      if (value['format'] != 1 ||
          value.length != 5 ||
          value['account'] is! String ||
          value['workspace'] != workspaceFor(value['account'] as String) ||
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
        SyncWorkspaceKey.fromRecoveryCode(value['recovery'] as String),
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

  Future<SyncPairing> prepare({String? recoveryCode}) =>
      _preparing ??= _prepare(recoveryCode)
          .whenComplete(() => _preparing = null);

  Future<SyncPairing> _prepare(String? recoveryCode) async {
    final account = storage.account?.id;
    if (account == null) {
      throw const CloudFailure('Connect Google Drive before pairing.');
    }
    final previous = await saved();
    if (previous != null && previous.binding.account != account) {
      throw const CloudFailure(
        'This profile is paired with a different account. Its pending work and key are retained.',
      );
    }
    final objects = await storage.list();
    _checkAccount(account);
    final workspace = workspaceFor(account);
    if (objects.any(
      (o) => o.accountId != account || o.properties['workspaceId'] != workspace,
    )) {
      throw const CloudFailure(
        'A different sync workspace is present. Reconcile it before creating or joining another.',
      );
    }
    final proofs = objects
        .where((o) => o.properties['kind'] == 'workspace')
        .toList();
    if (previous == null && recoveryCode == null && objects.isNotEmpty) {
      throw const SyncRecoveryRequired();
    }
    final supplied = recoveryCode == null
        ? null
        : SyncWorkspaceKey.fromRecoveryCode(recoveryCode);
    if (previous != null &&
        supplied != null &&
        previous.key.exportRecoveryCode() != supplied.exportRecoveryCode()) {
      throw const CloudFailure(
        'The entered code differs from this profile’s retained workspace key. Nothing was replaced.',
      );
    }
    final key = previous?.key ?? supplied ?? SyncWorkspaceKey.generate();
    final binding =
        previous?.binding ??
        SyncBinding(workspace: workspace, account: account, device: _uuid.v4());
    if (proofs.isEmpty) {
      if (objects.isNotEmpty) {
        throw const CloudFailure(
          'Workspace proof is missing. Retain cloud history and recover the existing workspace.',
        );
      }
      // Persist the new key before any upload can become externally visible.
      // An ambiguous creation must leave its only recovery key recoverable.
      if (previous == null) {
        await vault.write(
          jsonEncode({
            'format': 1,
            'workspace': workspace,
            'account': account,
            'device': binding.device,
            'recovery': key.exportRecoveryCode(),
          }),
        );
      }
      final proof = await _createProof(binding, key);
      await storage.upload(proof, {
        'kind': 'workspace',
        'protocol': '1',
        'workspaceId': workspace,
        'deviceId': binding.device,
        'batchId': _uuid.v4(),
      }, (_, _, _) {});
    } else {
      await _verifyProofs(binding, key, proofs);
    }
    // Check again after creation. Drive has no unique-file/CAS creation API.
    // Competing first-device keys therefore stop exchange instead of silently
    // accepting two independent encrypted histories for one account.
    await verifyWorkspace(binding, key);
    _checkAccount(account);
    if (previous == null) {
      await vault.write(
        jsonEncode({
          'format': 1,
          'workspace': workspace,
          'account': account,
          'device': binding.device,
          'recovery': key.exportRecoveryCode(),
        }),
      );
    }
    return SyncPairing(binding, key);
  }

  Future<void> recoverKey(SyncBinding binding, String recoveryCode) async {
    _checkAccount(binding.account);
    if (binding.workspace != workspaceFor(binding.account)) {
      throw const CloudFailure(
        'This profile needs recovery of its original encrypted data.',
      );
    }
    final previous = await saved();
    final key = SyncWorkspaceKey.fromRecoveryCode(recoveryCode);
    if (previous != null &&
        (previous.binding.workspace != binding.workspace ||
            previous.binding.account != binding.account ||
            previous.binding.device != binding.device ||
            previous.key.exportRecoveryCode() != key.exportRecoveryCode())) {
      throw const CloudFailure(
        'The retained authorization differs. No key was replaced.',
      );
    }
    await verifyWorkspace(binding, key);
    _checkAccount(binding.account);
    await vault.write(
      jsonEncode({
        'format': 1,
        'workspace': binding.workspace,
        'account': binding.account,
        'device': binding.device,
        'recovery': key.exportRecoveryCode(),
      }),
    );
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
    await vault.write(
      jsonEncode({
        'format': 1,
        'workspace': binding.workspace,
        'account': binding.account,
        'device': binding.device,
        'recovery': existing.key.exportRecoveryCode(),
      }),
    );
    return SyncPairing(binding, existing.key);
  }

  void _checkAccount(String account) {
    if (storage.account?.id != account) {
      throw const CloudFailure(
        'Google account changed during pairing. No local data was paired.',
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
    SyncWorkspaceKey key,
  ) async {
    _checkAccount(binding.account);
    final provider = storage;
    final objects = await (provider is SyncStorageProvider
        ? provider.listWorkspaceProofs()
        : provider.list());
    _checkAccount(binding.account);
    if (objects.any(
      (o) =>
          o.accountId != binding.account ||
          o.properties['workspaceId'] != binding.workspace,
    )) {
      throw const CloudFailure(
        'Multiple workspace identities need recovery. Pending changes are retained.',
      );
    }
    final proofs = objects
        .where((o) => o.properties['kind'] == 'workspace')
        .toList();
    if (proofs.isEmpty) {
      throw const CloudFailure(
        'The encrypted workspace proof is missing. Pending changes are retained.',
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
      if (proof.accountId != binding.account ||
          proof.bytes > 4096 ||
          proof.properties['protocol'] != '1' ||
          proof.properties['workspaceId'] != binding.workspace ||
          proof.properties['application'] != 'todorbit-sync' ||
          proof.properties['verified'] != 'true') {
        throw const FormatException('Invalid workspace proof identity');
      }
      final bytes = await storage.download(proof, (_, _, _) {});
      _checkAccount(binding.account);
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
        );
      }
    }
  }
}
