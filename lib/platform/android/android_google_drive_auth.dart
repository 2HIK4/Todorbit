import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/cloud/cloud_storage_provider.dart';
import '../../data/cloud/google_drive_auth.dart';
import 'android_platform.dart';

class _AndroidAuthorizationFlow implements GoogleAuthorizationFlow {
  void Function()? onCancel;
  @override
  Future<Map<String, String>> authorize(Uri Function(String) build) =>
      throw UnsupportedError(
        'Android authorization uses Google Identity Services.',
      );
  @override
  void cancel() {
    onCancel?.call();
    unawaited(
      AndroidPlatform.channel
          .invokeMethod<void>('googleCancel')
          .catchError((Object _) {}),
    );
  }
}

/// Google Play services owns short-lived token acquisition. No Desktop OAuth
/// client secret or refresh token is used on Android.
class AndroidGoogleDriveAuth extends GoogleDriveAuth {
  AndroidGoogleDriveAuth({
    required super.client,
    required super.store,
    super.enabled = const bool.fromEnvironment(
      'GOOGLE_DRIVE_ANDROID_ENABLED',
      defaultValue: true,
    ),
  }) : super(flow: _AndroidAuthorizationFlow(), clientId: 'android-platform') {
    (flow as _AndroidAuthorizationFlow).onCancel = () => _generation++;
  }
  String? token;
  DateTime? expires;
  Future<String>? acquiring;
  int _generation = 0;
  Future<void> _identityWrites = Future.value();
  Future<void> _writeIdentity(Future<void> Function() action) {
    final operation = _identityWrites.then((_) => action());
    _identityWrites = operation.catchError((Object _) {});
    return operation;
  }

  @override
  bool get canConnect => enabled;

  @override
  Future<void> load() async {
    if (!enabled) return;
    final saved = await store.read();
    if (saved == null) return;
    try {
      final value = jsonDecode(saved) as Map;
      if (value['version'] != 1 ||
          value['id'] is! String ||
          value['label'] is! String) {
        throw const FormatException();
      }
      account = CloudAccount(value['id'] as String, value['label'] as String);
    } catch (_) {
      needsReconnect = true;
      throw const CloudFailure(
        'Saved Android account is invalid. Disconnect and reconnect.',
      );
    }
  }

  Future<String> acquire({
    required bool interactive,
    bool force = false,
  }) async {
    if (!canConnect) {
      throw const CloudFailure(
        'Android Google Drive is not configured in this build. Local backups remain available.',
      );
    }
    final generation = _generation;
    String? value;
    try {
      value = await AndroidPlatform.channel
          .invokeMethod<String>('googleAuthorize', {
            'interactive': interactive,
            'force': force,
            'account': account?.label,
          })
          .timeout(const Duration(minutes: 3));
    } on PlatformException catch (failure) {
      if (failure.code == 'reconnect') needsReconnect = true;
      throw CloudFailure(
        failure.message ?? 'Google authorization unavailable. Try again.',
      );
    } on TimeoutException {
      flow.cancel();
      needsReconnect = true;
      rethrow;
    }
    if (value == null || value.isEmpty) {
      needsReconnect = true;
      throw const CloudFailure('Google backup access requires reconnection.');
    }
    final verified = await identity(value);
    if (generation != _generation) {
      throw const CloudFailure('Google connection changed. Connect again.');
    }
    if (account != null && verified.id != account!.id) {
      needsReconnect = true;
      throw const CloudFailure(
        'A different Google account was selected. Disconnect before switching accounts.',
      );
    }
    await _writeIdentity(() async {
      if (generation != _generation) {
        throw const CloudFailure('Google connection changed. Connect again.');
      }
      final previous = await store.read();
      if (generation != _generation) {
        throw const CloudFailure('Google connection changed. Connect again.');
      }
      await store.write(
        jsonEncode({'version': 1, 'id': verified.id, 'label': verified.label}),
      );
      if (generation != _generation) {
        if (previous == null) {
          await store.delete();
        } else {
          await store.write(previous);
        }
        throw const CloudFailure('Google connection changed. Connect again.');
      }
      account = verified;
      needsReconnect = false;
      token = value;
      expires = DateTime.now().add(const Duration(minutes: 50));
    });
    return value;
  }

  @override
  Future<void> connect() async {
    await acquire(interactive: true);
  }

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    if (account == null) {
      throw const CloudFailure('Connect Google Drive first.');
    }
    if (!forceRefresh &&
        !needsReconnect &&
        token != null &&
        expires!.isAfter(DateTime.now())) {
      return token!;
    }
    if (acquiring case final current?) return current;
    final current = acquire(interactive: false, force: forceRefresh);
    acquiring = current;
    try {
      return await current;
    } finally {
      acquiring = null;
    }
  }

  @override
  Future<void> disconnect() async {
    flow.cancel();
    await _writeIdentity(store.delete);
    token = null;
    expires = null;
    account = null;
    needsReconnect = false;
    // Local disconnect must also work offline or without Play services.
    try {
      await AndroidPlatform.channel.invokeMethod<void>('googleDisconnect');
    } on PlatformException {
      /* Local identity is already removed. */
    }
  }
}
