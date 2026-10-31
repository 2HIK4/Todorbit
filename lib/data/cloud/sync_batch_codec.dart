import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/sync/causal_record.dart';

class SyncRecordOperation {
  const SyncRecordOperation({
    required this.entity,
    required this.recordKey,
    required this.revision,
  });
  final String entity, recordKey;
  final SyncRevision revision;
  Map<String, Object?> toJson() => {
    'entity': entity,
    'key': recordKey,
    'revision': revision.toJson(),
  };

  factory SyncRecordOperation.fromJson(Map<String, dynamic> value) {
    if (value.length != 3 ||
        value['entity'] is! String ||
        value['key'] is! String ||
        value['revision'] is! Map ||
        (value['entity'] as String).isEmpty ||
        (value['entity'] as String).length > 80 ||
        (value['key'] as String).isEmpty ||
        (value['key'] as String).length > 1024) {
      throw const FormatException('Invalid sync operation');
    }
    return SyncRecordOperation(
      entity: value['entity'] as String,
      recordKey: value['key'] as String,
      revision: SyncRevision.fromJson(
        (value['revision'] as Map).cast<String, dynamic>(),
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
  factory SyncWorkspaceKey.generate() => SyncWorkspaceKey._(
    List.unmodifiable(SecretKeyData.random(length: 32).bytes),
  );
  factory SyncWorkspaceKey.fromRecoveryCode(String code) {
    try {
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
  String exportRecoveryCode() => base64Url.encode(_bytes).replaceAll('=', '');
  SecretKey get secretKey => SecretKey(_bytes);
}

class SyncBatchCodec {
  static const protocol = 1;
  static const maxPlaintextBytes = 24 * 1024 * 1024;
  static const maxEncryptedBytes = 34 * 1024 * 1024;
  static const header = 'todorbit-sync:1:aes256gcm';

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
  }) async {
    final clear = utf8.encode(jsonEncode(batch.toJson()));
    if (clear.length > maxPlaintextBytes) {
      throw const FormatException(
        'Sync batch exceeds the encrypted protocol limit',
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
  }) async {
    if (encrypted.length > maxEncryptedBytes) {
      throw const FormatException(
        'Encrypted sync batch exceeds the protocol limit',
      );
    }
    try {
      final envelope = jsonDecode(utf8.decode(encrypted)) as Map;
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
      if (batch.schema != expectedSchema) throw const FormatException();
      return batch;
    } catch (_) {
      // Never include decrypted values, tokens or the recovery code in errors.
      throw const FormatException(
        'Sync batch could not be authenticated or is incompatible. Retain it and reconnect the correct workspace.',
      );
    }
  }
}
