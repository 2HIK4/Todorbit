import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/sync/causal_record.dart';
import 'cloud_storage_provider.dart';

class SyncSchemaMismatch extends CloudFailure {
  const SyncSchemaMismatch()
    : super(
        'Update Todorbit on all devices before syncing this workspace. Local data and pending history are retained.',
        kind: CloudFailureKind.incompatible,
      );
}

class SyncMutationGroup {
  SyncMutationGroup({
    required this.id,
    required this.first,
    required this.last,
  }) {
    if (id.isEmpty || id.length > 128 || first < 1 || last < first) {
      throw const FormatException('Invalid sync mutation group');
    }
  }
  final String id;
  final int first, last;
  Map<String, Object?> toJson() => {'id': id, 'first': first, 'last': last};
  factory SyncMutationGroup.fromJson(Map<String, dynamic> json) {
    if (json.length != 3 ||
        json['id'] is! String ||
        json['first'] is! int ||
        json['last'] is! int) {
      throw const FormatException('Invalid sync mutation group');
    }
    return SyncMutationGroup(
      id: json['id'] as String,
      first: json['first'] as int,
      last: json['last'] as int,
    );
  }
}

class SyncRecordOperation {
  const SyncRecordOperation({
    required this.entity,
    required this.recordKey,
    required this.revision,
    this.group,
  });
  final String entity, recordKey;
  final SyncRevision revision;
  final SyncMutationGroup? group;
  Map<String, Object?> toJson() => {
    'entity': entity,
    'key': recordKey,
    'revision': revision.toJson(),
    if (group != null) 'group': group!.toJson(),
  };

  factory SyncRecordOperation.fromJson(Map<String, dynamic> value) {
    if (value.keys.toSet().difference({
          'entity',
          'key',
          'revision',
          'group',
        }).isNotEmpty ||
        value['entity'] is! String ||
        value['key'] is! String ||
        value['revision'] is! Map ||
        (value['entity'] as String).isEmpty ||
        (value['entity'] as String).length > 80 ||
        (value['key'] as String).isEmpty ||
        (value['key'] as String).length > 1024 ||
        (value['group'] != null && value['group'] is! Map)) {
      throw const FormatException('Invalid sync operation');
    }
    return SyncRecordOperation(
      entity: value['entity'] as String,
      recordKey: value['key'] as String,
      revision: SyncRevision.fromJson(
        (value['revision'] as Map).cast<String, dynamic>(),
      ),
      group: value['group'] == null
          ? null
          : SyncMutationGroup.fromJson(
              (value['group'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

class SyncBatch {
  SyncBatch({
    required this.id,
    required this.device,
    required this.schema,
    required Iterable<SyncRecordOperation> operations,
  }) : operations = List.unmodifiable(operations) {
    if (id.isEmpty ||
        id.length > 128 ||
        device.isEmpty ||
        device.length > 128 ||
        schema < 1 ||
        this.operations.isEmpty ||
        this.operations.length > 512 ||
        this.operations.any((op) => op.revision.device != device) ||
        this.operations.map((op) => op.revision.id).toSet().length !=
            this.operations.length ||
        this.operations.map((op) => op.revision.sequence).toSet().length !=
            this.operations.length) {
      throw const FormatException('Invalid per-device sync batch');
    }
    final groups = <String, String>{};
    for (final operation in this.operations) {
      if (schema >= 25 && operation.revision.visible == null) {
        throw const FormatException('Applied visibility is required');
      }
      final group = operation.group;
      if (schema >= 24 && group == null) {
        throw const FormatException('Sync mutation group is required');
      }
      if (group == null) continue;
      if (operation.revision.sequence < group.first ||
          operation.revision.sequence > group.last) {
        throw const FormatException(
          'Sync operation is outside its mutation group',
        );
      }
      final header = jsonEncode(group.toJson());
      if (groups.containsKey(group.id) && groups[group.id] != header) {
        throw const FormatException('Sync mutation group bounds differ');
      }
      groups[group.id] = header;
    }
  }
  final String id, device;
  final int schema;
  final List<SyncRecordOperation> operations;
  Map<String, Object?> toJson() => {
    'id': id,
    'device': device,
    'schema': schema,
    'operations': operations.map((op) => op.toJson()).toList(),
  };

  factory SyncBatch.fromJson(Map<String, dynamic> value) {
    if (value.length != 4 ||
        value['id'] is! String ||
        value['device'] is! String ||
        value['schema'] is! int ||
        value['operations'] is! List ||
        (value['operations'] as List).length > 512) {
      throw const FormatException('Invalid sync batch payload');
    }
    return SyncBatch(
      id: value['id'] as String,
      device: value['device'] as String,
      schema: value['schema'] as int,
      operations: (value['operations'] as List).map(
        (op) =>
            SyncRecordOperation.fromJson((op as Map).cast<String, dynamic>()),
      ),
    );
  }
}

// A high-entropy workspace recovery code is the 256-bit workspace key. It is
// generated randomly, never derived from a backup passphrase or uploaded. The
// platform credential adapter must keep it outside portable data and logs.
class SyncWorkspaceKey {
  SyncWorkspaceKey._(this._bytes);
  final List<int> _bytes;
  factory SyncWorkspaceKey.standard() => SyncWorkspaceKey._(const []);
  bool get isStandard => _bytes.isEmpty;
  factory SyncWorkspaceKey.generate() => SyncWorkspaceKey._(
    List.unmodifiable(SecretKeyData.random(length: 32).bytes),
  );
  factory SyncWorkspaceKey.fromRecoveryCode(String code) {
    try {
      if (code.length != 43) throw const FormatException();
      final bytes = base64Url.decode(base64Url.normalize(code));
      if (bytes.length != 32 ||
          base64Url.encode(bytes).replaceAll('=', '') != code) {
        throw const FormatException();
      }
      return SyncWorkspaceKey._(List.unmodifiable(bytes));
    } catch (_) {
      throw const FormatException('Enter the complete workspace recovery code');
    }
  }
  String exportRecoveryCode() {
    if (isStandard) throw StateError('Standard Sync has no recovery key');
    return base64Url.encode(_bytes).replaceAll('=', '');
  }

  SecretKey get secretKey {
    if (isStandard) throw StateError('Standard Sync has no encryption key');
    return SecretKey(_bytes);
  }
}

class SyncBatchCodec {
  static const protocol = 1;
  static const maxPlaintextBytes = 24 * 1024 * 1024;
  static const maxEncryptedBytes = 34 * 1024 * 1024;
  static const header = 'todorbit-sync:1:aes256gcm';
  static const standardHeader = 'todorbit-sync:2:standard';

  List<int> _aad(String workspace, String account) {
    if (workspace.isEmpty ||
        workspace.length > 128 ||
        account.isEmpty ||
        account.length > 256) {
      throw const FormatException('Invalid workspace identity');
    }
    return utf8.encode(jsonEncode([header, workspace, account]));
  }

  Future<Uint8List> encrypt(
    SyncBatch batch,
    SyncWorkspaceKey key, {
    required String workspace,
    required String account,
  }) => Isolate.run(
    () => _encrypt(batch, key, workspace: workspace, account: account),
  );

  Future<Uint8List> _encrypt(
    SyncBatch batch,
    SyncWorkspaceKey key, {
    required String workspace,
    required String account,
  }) async {
    final clear = utf8.encode(jsonEncode(batch.toJson()));
    if (clear.length > maxPlaintextBytes) {
      throw const FormatException(
        'Sync batch exceeds the encrypted protocol limit',
      );
    }
    if (key.isStandard) {
      _aad(workspace, account);
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': standardHeader,
            'workspace': workspace,
            'account': account,
            'batch': batch.toJson(),
          }),
        ),
      );
    }
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: key.secretKey,
      aad: _aad(workspace, account),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': header,
          'nonce': base64Encode(box.nonce),
          'ciphertext': base64Encode(box.cipherText),
          'tag': base64Encode(box.mac.bytes),
        }),
      ),
    );
  }

  Future<SyncBatch> decrypt(
    Uint8List encrypted,
    SyncWorkspaceKey key, {
    required String workspace,
    required String account,
    required int expectedSchema,
  }) => Isolate.run(
    () => _decrypt(
      encrypted,
      key,
      workspace: workspace,
      account: account,
      expectedSchema: expectedSchema,
    ),
  );

  Future<SyncBatch> _decrypt(
    Uint8List encrypted,
    SyncWorkspaceKey key, {
    required String workspace,
    required String account,
    required int expectedSchema,
  }) async {
    if (encrypted.length > maxEncryptedBytes) {
      throw const FormatException(
        'Encrypted sync batch exceeds the protocol limit',
      );
    }
    try {
      final envelope = jsonDecode(utf8.decode(encrypted)) as Map;
      if (key.isStandard) {
        _aad(workspace, account);
        if (envelope.length != 4 ||
            envelope['format'] != standardHeader ||
            envelope['workspace'] != workspace ||
            envelope['account'] != account ||
            encrypted.length > maxPlaintextBytes + 1024) {
          throw const FormatException();
        }
        final batch = SyncBatch.fromJson(
          (envelope['batch'] as Map).cast<String, dynamic>(),
        );
        if (batch.schema != expectedSchema &&
            !((expectedSchema == 27 && batch.schema == 26) ||
                (expectedSchema == 28 && {26, 27}.contains(batch.schema)))) {
          throw const SyncSchemaMismatch();
        }
        return batch;
      }
      if (envelope.length != 4 || envelope['format'] != header) {
        throw const FormatException();
      }
      final nonce = base64Decode(envelope['nonce'] as String);
      final tag = base64Decode(envelope['tag'] as String);
      final cipher = base64Decode(envelope['ciphertext'] as String);
      if (nonce.length != 12 ||
          tag.length != 16 ||
          cipher.length > maxPlaintextBytes) {
        throw const FormatException();
      }
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(tag)),
        secretKey: key.secretKey,
        aad: _aad(workspace, account),
      );
      final batch = SyncBatch.fromJson(
        (jsonDecode(utf8.decode(clear)) as Map).cast<String, dynamic>(),
      );
      if (batch.schema != expectedSchema &&
          !((expectedSchema == 27 && batch.schema == 26) ||
              (expectedSchema == 28 && {26, 27}.contains(batch.schema)))) {
        throw const SyncSchemaMismatch();
      }
      return batch;
    } on SyncSchemaMismatch {
      rethrow;
    } catch (_) {
      // Never include decrypted values, tokens or the recovery code in errors.
      throw const FormatException(
        'Sync batch could not be authenticated or is incompatible. Retain it and reconnect the correct workspace.',
      );
    }
  }
}
