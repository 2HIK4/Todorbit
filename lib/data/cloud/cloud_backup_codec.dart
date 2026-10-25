import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';

import 'cloud_storage_provider.dart';

/// Portable JSON envelope: PBKDF2-HMAC-SHA256 + AES-256-GCM, format 1.
/// The fixed authenticated header prevents unauthenticated KDF work factors.
class CloudBackupCodec {
  static const header =
      'todorbit-encrypted-backup:1:pbkdf2-sha256:600000:aes256gcm';
  static const maxPlaintextBytes = 70 * 1024 * 1024;
  static const maxEncryptedBytes = 128 * 1024 * 1024;

  Future<Uint8List> encrypt(Map<String, dynamic> package, String passphrase) =>
      Isolate.run(() => encryptInIsolate(package, passphrase));

  static Future<Uint8List> encryptInIsolate(
    Map<String, dynamic> package,
    String passphrase,
  ) async {
    if (passphrase.length < 12 || utf8.encode(passphrase).length > 1024) {
      throw const CloudFailure(
        'Use a recovery passphrase of 12–1024 characters.',
      );
    }
    final plaintext = utf8.encode(jsonEncode(package));
    if (plaintext.length > maxPlaintextBytes) {
      throw const CloudFailure(
        'This profile is too large for the cloud backup format (70 MiB package limit).',
      );
    }
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: key,
      aad: utf8.encode(header),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': header,
          'salt': base64Encode(salt),
          'nonce': base64Encode(box.nonce),
          'ciphertext': base64Encode(box.cipherText),
          'tag': base64Encode(box.mac.bytes),
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> decrypt(Uint8List bytes, String passphrase) =>
      Isolate.run(() => decryptInIsolate(bytes, passphrase));

  static Future<Map<String, dynamic>> decryptInIsolate(
    Uint8List bytes,
    String passphrase,
  ) async {
    if (bytes.length > maxEncryptedBytes ||
        passphrase.length < 12 ||
        utf8.encode(passphrase).length > 1024) {
      throw const CloudFailure(
        'Invalid encrypted backup or recovery passphrase.',
      );
    }
    try {
      final envelope = jsonDecode(utf8.decode(bytes)) as Map;
      if (envelope['format'] != header) throw const FormatException();
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final tag = base64Decode(envelope['tag'] as String);
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      if (salt.length != 16 ||
          nonce.length != 12 ||
          tag.length != 16 ||
          ciphertext.length > maxPlaintextBytes) {
        throw const FormatException();
      }
      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 600000,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: key,
        aad: utf8.encode(header),
      );
      final data = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      validateManifest(data);
      return data;
    } catch (_) {
      throw const CloudFailure(
        'Cannot open this backup. The passphrase is wrong, the file is damaged, or its format is unsupported.',
      );
    }
  }

  static void validateManifest(Map<String, dynamic> package) {
    if (package['format'] != 'todorbit-cloud-package' ||
        package['version'] != 1 ||
        package['id'] is! String ||
        package['profileId'] is! String ||
        package['appVersion'] is! String ||
        package['createdAt'] is! String ||
        DateTime.tryParse(package['createdAt'] as String) == null ||
        !CloudBackupKind.values.any((value) => value.name == package['kind']) ||
        package['settings'] is! String ||
        package['schema'] is! int) {
      throw const FormatException('Invalid backup manifest');
    }
    if (package['kind'] == 'full') {
      final bytes = base64Decode(package['database'] as String);
      if (package['databaseBytes'] != bytes.length ||
          package['databaseSha256'] !=
              digest.sha256.convert(bytes).toString()) {
        throw const FormatException('Database checksum mismatch');
      }
    } else if (package.containsKey('database')) {
      throw const FormatException('Settings backup contains database content');
    }
  }
}
