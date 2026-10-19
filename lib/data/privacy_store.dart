import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'profile_paths.dart';

/// UI privacy only. The SQLite database is not encrypted.
class PrivacySettings {
  const PrivacySettings({
    this.enabled = false,
    this.salt = '',
    this.verifier = '',
    this.iterations = 210000,
    this.lockOnLaunch = true,
    this.inactivityMinutes = 5,
    this.lockOnInactive = false,
    this.hideNotifications = true,
  });

  final bool enabled;
  final String salt;
  final String verifier;
  final int iterations;
  final bool lockOnLaunch;
  final int inactivityMinutes;
  final bool lockOnInactive;
  final bool hideNotifications;

  PrivacySettings copyWith({
    bool? enabled,
    String? salt,
    String? verifier,
    int? iterations,
    bool? lockOnLaunch,
    int? inactivityMinutes,
    bool? lockOnInactive,
    bool? hideNotifications,
  }) => PrivacySettings(
    enabled: enabled ?? this.enabled,
    salt: salt ?? this.salt,
    verifier: verifier ?? this.verifier,
    iterations: iterations ?? this.iterations,
    lockOnLaunch: lockOnLaunch ?? this.lockOnLaunch,
    inactivityMinutes: inactivityMinutes ?? this.inactivityMinutes,
    lockOnInactive: lockOnInactive ?? this.lockOnInactive,
    hideNotifications: hideNotifications ?? this.hideNotifications,
  );

  factory PrivacySettings.fromJson(Map<String, dynamic> data) =>
      PrivacySettings(
        enabled: data['enabled'] == true,
        salt: data['salt'] is String ? data['salt'] as String : '',
        verifier: data['verifier'] is String ? data['verifier'] as String : '',
        iterations: data['iterations'] is int
            ? data['iterations'] as int
            : 210000,
        lockOnLaunch: data['lockOnLaunch'] != false,
        inactivityMinutes: data['inactivityMinutes'] is int
            ? (data['inactivityMinutes'] as int).clamp(1, 120)
            : 5,
        lockOnInactive: data['lockOnInactive'] == true,
        hideNotifications: data['hideNotifications'] != false,
      );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'salt': salt,
    'verifier': verifier,
    'iterations': iterations,
    'lockOnLaunch': lockOnLaunch,
    'inactivityMinutes': inactivityMinutes,
    'lockOnInactive': lockOnInactive,
    'hideNotifications': hideNotifications,
  };
}

class PrivacyStore {
  PrivacyStore(this.file);
  final File file;
  File get sessionFile =>
      File(path.join(file.parent.path, 'privacy-session.json'));
  File get attemptsFile =>
      File(path.join(file.parent.path, 'privacy-attempts.json'));

  Future<(int, DateTime?)> loadAttempts() async {
    if (!await attemptsFile.exists()) return (0, null);
    try {
      final decoded = jsonDecode(await attemptsFile.readAsString());
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final failures = decoded['failures'];
      final retryUtc = decoded['retryUtc'];
      if (failures is! int ||
          failures < 0 ||
          failures > 1000000 ||
          retryUtc is! String) {
        throw const FormatException();
      }
      return (failures, DateTime.parse(retryUtc));
    } catch (_) {
      return (5, DateTime.now().add(const Duration(minutes: 5)));
    }
  }

  Future<void> saveAttempts(int failures, DateTime? retryAfter) =>
      _atomicWrite(attemptsFile, {
        'failures': failures,
        'retryUtc':
            (retryAfter ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
                .toUtc()
                .toIso8601String(),
      });

  static Future<PrivacyStore> openDefault() async {
    return PrivacyStore(
      File(
        path.join(ProfilePaths.activeDirectory().path, 'privacy-settings.json'),
      ),
    );
  }

  Future<PrivacySettings> load() async {
    if (!await file.exists()) return const PrivacySettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return PrivacySettings.fromJson(decoded);
      }
    } catch (error) {
      // A damaged policy fails closed. Recovery requires repairing the file
      // from a trusted backup; never silently discard an enabled lock.
      throw StateError('Privacy settings could not be read: $error');
    }
    throw StateError('Privacy settings have an invalid format');
  }

  Future<void> save(PrivacySettings settings) async {
    await _atomicWrite(file, settings.toJson());
  }

  Future<void> setSession({required bool unlocked}) async {
    await _atomicWrite(sessionFile, {
      'pid': pid,
      'expiresUtc': unlocked
          ? DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 5))
                .toIso8601String()
          : DateTime.fromMillisecondsSinceEpoch(
              0,
              isUtc: true,
            ).toIso8601String(),
    });
  }

  static Future<void> _atomicWrite(
    File destination,
    Map<String, Object> data,
  ) async {
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.$pid.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    await temporary.rename(destination.path);
  }

  static String newSalt() {
    final random = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  static String derivePin(String pin, String encodedSalt, int iterations) {
    if (iterations < 210000 || iterations > 1000000) {
      throw StateError('Unsupported PIN verifier settings');
    }
    final salt = base64Decode(encodedSalt);
    if (salt.length != 16) throw StateError('Invalid PIN verifier salt');
    final hmac = Hmac(sha256, utf8.encode(pin));
    final block = Uint8List.fromList([...salt, 0, 0, 0, 1]);
    var current = hmac.convert(block).bytes;
    final output = Uint8List.fromList(current);
    for (var round = 1; round < iterations; round++) {
      current = hmac.convert(current).bytes;
      for (var index = 0; index < output.length; index++) {
        output[index] ^= current[index];
      }
    }
    return base64Encode(output);
  }

  static bool constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    for (var index = 0; index < max(a.length, b.length); index++) {
      difference |=
          (index < a.length ? a[index] : 0) ^ (index < b.length ? b[index] : 0);
    }
    return difference == 0;
  }
}
