import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/privacy_store.dart';
import '../platform/android/android_platform.dart';

class PrivacyManager extends ChangeNotifier {
  PrivacyManager(this.store, this.settings)
    : locked = settings.enabled && settings.lockOnLaunch {
    if (settings.enabled && !locked) _startSession();
  }

  final PrivacyStore store;
  PrivacySettings settings;
  bool locked;
  Timer? _heartbeat;
  bool _shutDown = false;
  Future<void> _sessionWrites = Future<void>.value();
  DateTime? _inactiveSince;
  DateTime _lastActivity = DateTime.now();
  Timer? _inactivityCheck;
  int _failedAttempts = 0;
  DateTime? _retryAfter;

  bool get enabled => settings.enabled;
  Duration? get retryDelay {
    final deadline = _retryAfter;
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<bool> verify(String pin) async {
    final attempts = await store.loadAttempts();
    _failedAttempts = attempts.$1;
    _retryAfter = attempts.$2;
    if (retryDelay != null) return false;
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) return false;
    final valid = PrivacyStore.constantTimeEquals(
      PrivacyStore.derivePin(pin, settings.salt, settings.iterations),
      settings.verifier,
    );
    if (!valid) {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        final seconds = 30 * (1 << (_failedAttempts - 5).clamp(0, 5));
        _retryAfter = DateTime.now().add(Duration(seconds: seconds));
      }
      await store.saveAttempts(_failedAttempts, _retryAfter);
      notifyListeners();
      return false;
    }
    _failedAttempts = 0;
    _retryAfter = null;
    await store.saveAttempts(0, null);
    return true;
  }

  Future<bool> unlock(String pin) async {
    if (!await verify(pin)) return false;
    locked = false;
    _inactiveSince = null;
    _lastActivity = DateTime.now();
    _startSession();
    notifyListeners();
    return true;
  }

  Future<bool> unlockWithAndroidCredential() async {
    if (!Platform.isAndroid || !enabled || !locked || retryDelay != null) {
      return false;
    }
    if (!await AndroidPlatform.authenticate()) return false;
    locked = false;
    _inactiveSince = null;
    _lastActivity = DateTime.now();
    _startSession();
    notifyListeners();
    return true;
  }

  Future<void> lock() async {
    if (!enabled || locked) return;
    locked = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    notifyListeners();
    await _writeSession(false);
  }

  Future<void> setup(String pin) async {
    if (enabled) throw StateError('App lock is already enabled');
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) {
      throw ArgumentError('Use a 6 to 12 digit PIN');
    }
    final salt = PrivacyStore.newSalt();
    final next = settings.copyWith(
      enabled: true,
      salt: salt,
      verifier: PrivacyStore.derivePin(pin, salt, settings.iterations),
    );
    await store.save(next);
    settings = next;
    locked = false;
    _lastActivity = DateTime.now();
    _startSession();
    notifyListeners();
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verify(oldPin)) return false;
    if (!RegExp(r'^\d{6,12}$').hasMatch(newPin)) {
      throw ArgumentError('Use a 6 to 12 digit PIN');
    }
    final salt = PrivacyStore.newSalt();
    final next = settings.copyWith(
      salt: salt,
      verifier: PrivacyStore.derivePin(newPin, salt, settings.iterations),
    );
    await store.save(next);
    settings = next;
    notifyListeners();
    return true;
  }

  Future<bool> remove(String pin) async {
    if (!await verify(pin)) return false;
    final next = const PrivacySettings();
    await store.save(next);
    settings = next;
    locked = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _writeSession(false);
    notifyListeners();
    return true;
  }

  Future<void> updateSettings(PrivacySettings next) async {
    await store.save(next);
    settings = next;
    notifyListeners();
  }

  void becameInactive() {
    if (enabled && !locked) _inactiveSince ??= DateTime.now();
  }

  void activity() => _lastActivity = DateTime.now();

  void startInactivityCheck() {
    _inactivityCheck ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (enabled &&
          !locked &&
          DateTime.now().difference(_lastActivity) >=
              Duration(minutes: settings.inactivityMinutes)) {
        unawaited(lock());
      }
    });
  }

  Future<void> resumed() async {
    final since = _inactiveSince;
    _inactiveSince = null;
    if (since == null || !enabled || locked) return;
    if (settings.lockOnInactive ||
        DateTime.now().difference(since) >=
            Duration(minutes: settings.inactivityMinutes)) {
      await lock();
    }
  }

  void _startSession() {
    _heartbeat?.cancel();
    if (!enabled || locked || _shutDown) return;
    unawaited(_writeSession(true));
    if (Platform.isAndroid) return;
    _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_writeSession(true));
    });
  }

  Future<void> _writeSession(bool unlocked) {
    _sessionWrites = _sessionWrites
        .catchError((Object _) {})
        .then((_) => store.setSession(unlocked: unlocked));
    return _sessionWrites;
  }

  Future<void> shutdown() async {
    _shutDown = true;
    _heartbeat?.cancel();
    _inactivityCheck?.cancel();
    await _writeSession(false);
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _inactivityCheck?.cancel();
    if (!_shutDown) unawaited(_writeSession(false));
    super.dispose();
  }
}
