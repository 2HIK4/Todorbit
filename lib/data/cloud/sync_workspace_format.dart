import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../sync_exchange_models.dart';
import 'cloud_storage_provider.dart';
import 'sync_batch_codec.dart';

// This version is additive. Legacy AES-GCM proofs/batches remain readable.
class SyncWorkspaceFormat {
  static const standard = 'todorbit-sync-workspace:2:standard';
  static const private = 'todorbit-sync-workspace:2:private';
  static const wrapper = 'todorbit-sync-key:1:argon2id:19456:2:1:aes256gcm';
  static const schema = 26;

  static String? passwordError(String password) {
    if (password.runes.length < 12) {
      return 'Use at least 12 characters. A few unrelated words are easier to remember.';
    }
    if (utf8.encode(password).length > 4096) {
      return 'Use a passphrase of at most 4096 UTF-8 bytes.';
    }
    final compact = password.replaceAll(RegExp(r'\s'), '');
    if (compact.length < 12 ||
        RegExp(r'^\d+$').hasMatch(compact) ||
        compact.runes.toSet().length < 5 ||
        const {
          'passwordpassword',
          '123456789012',
          'abcdefghijkl',
          'qwertyuiopasdf',
        }.contains(compact.toLowerCase())) {
      return 'Choose a less predictable passphrase. Avoid repeated characters, common passwords and numeric PINs.';
    }
    return null;
  }

  static List<int> _aad(SyncBinding b, String purpose) =>
      utf8.encode(jsonEncode([purpose, b.workspace, b.account, schema]));

  static Future<SecretKey> _derive(String password, List<int> salt) => Argon2id(
    memory: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Map<String, Object?> _box(SecretBox box) => {
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(box.cipherText),
    'tag': base64Encode(box.mac.bytes),
  };

  static SecretBox _readBox(Map value, {required int maxCipher}) {
    final nonce = base64Decode(value['nonce'] as String);
    final tag = base64Decode(value['tag'] as String);
    final cipher = base64Decode(value['ciphertext'] as String);
    if (nonce.length != 12 || tag.length != 16 || cipher.length > maxCipher) {
      throw const FormatException('Invalid private sync credential');
    }
    return SecretBox(cipher, nonce: nonce, mac: Mac(tag));
  }

  static Future<Uint8List> create(
    SyncBinding b,
    SyncWorkspaceKey key,
    String? password,
  ) => Isolate.run(() => _create(b, key, password));

  static Future<Uint8List> _create(
    SyncBinding b,
    SyncWorkspaceKey key,
    String? password,
  ) async {
    final data = <String, Object?>{
      'format': key.isStandard ? standard : private,
      'protocol': 2,
      'schema': schema,
      'workspace': b.workspace,
      'account': b.account,
      'mode': key.isStandard ? 'standard' : 'private',
    };
    if (!key.isStandard) {
      final error = passwordError(password ?? '');
      if (error != null) throw CloudFailure(error);
      final salt = SecretKeyData.random(length: 16).bytes;
      final wrapped = await AesGcm.with256bits().encrypt(
        await key.secretKey.extractBytes(),
        secretKey: await _derive(password!, salt),
        aad: _aad(b, wrapper),
      );
      final envelope = {
        'format': wrapper,
        'salt': base64Encode(salt),
        ..._box(wrapped),
      };
      data['keyEnvelope'] = envelope;
      // Authenticate all public format/mode/KDF metadata with the workspace key.
      data['proof'] = _box(
        await AesGcm.with256bits().encrypt(
          utf8.encode('todorbit-workspace'),
          secretKey: key.secretKey,
          aad: utf8.encode(jsonEncode(data)),
        ),
      );
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }

  static Map<String, dynamic> read(Uint8List bytes, SyncBinding b) {
    if (bytes.length > 8192) {
      throw const FormatException('Workspace metadata is too large');
    }
    final data = (jsonDecode(utf8.decode(bytes)) as Map)
        .cast<String, dynamic>();
    final mode = data['mode'];
    if (data['protocol'] is! int || data['schema'] is! int) {
      throw const FormatException('Incomplete cloud workspace metadata');
    }
    if (data['protocol'] != 2 || data['schema'] != schema) {
      throw const CloudFailure(
        'This cloud workspace needs a compatible Todorbit version. Nothing was replaced.',
        kind: CloudFailureKind.incompatible,
      );
    }
    if (data['workspace'] != b.workspace ||
        data['account'] != b.account ||
        !((mode == 'standard' &&
                data['format'] == standard &&
                data.length == 6) ||
            (mode == 'private' &&
                data['format'] == private &&
                data.length == 8))) {
      throw const FormatException('Invalid cloud workspace metadata');
    }
    return data;
  }

  static Future<SyncWorkspaceKey> unlock(
    Map<String, dynamic> data,
    SyncBinding b,
    String password,
  ) => Isolate.run(() async {
    // Bound attacker-controlled work before invoking the fixed-cost KDF.
    if (utf8.encode(password).length > 4096) throw const FormatException();
    final envelope = data['keyEnvelope'] as Map;
    if (envelope.length != 5 || envelope['format'] != wrapper) {
      throw const FormatException();
    }
    final salt = base64Decode(envelope['salt'] as String);
    if (salt.length != 16) throw const FormatException();
    final box = _readBox(envelope, maxCipher: 32);
    final clear = await AesGcm.with256bits().decrypt(
      box,
      secretKey: await _derive(password, salt),
      aad: _aad(b, wrapper),
    );
    final key = SyncWorkspaceKey.fromRecoveryCode(
      base64Url.encode(clear).replaceAll('=', ''),
    );
    await verify(data, b, key);
    return key;
  });

  static Future<void> verify(
    Map<String, dynamic> data,
    SyncBinding b,
    SyncWorkspaceKey key,
  ) async {
    if ((data['mode'] == 'standard') != key.isStandard) {
      throw const CloudFailure(
        'Cloud encryption differs from this device. Pending work and credentials are retained.',
      );
    }
    if (key.isStandard) return;
    final header = Map<String, dynamic>.from(data)..remove('proof');
    final clear = await AesGcm.with256bits().decrypt(
      _readBox(data['proof'] as Map, maxCipher: 64),
      secretKey: key.secretKey,
      aad: utf8.encode(jsonEncode(header)),
    );
    if (utf8.decode(clear) != 'todorbit-workspace') {
      throw const FormatException();
    }
  }
}
