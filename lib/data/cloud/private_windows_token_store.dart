import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// No migration, fallback, or reference to the shared Windows credential store.
/// Native code scopes all operations, uses current-user DPAPI and atomic writes.
class PrivateWindowsTokenStore {
  PrivateWindowsTokenStore(String databasePath, this.key)
    : directory = p.join(p.dirname(databasePath), 'private-credentials');

  final String directory;
  final String key;
  static const channel = MethodChannel('life_manager/private_credentials');

  Future<String?> read() => _invoke<String>('read');
  Future<void> write(String value) => _invoke<void>('write', value);
  Future<void> delete() => _invoke<void>('delete');

  Future<T?> _invoke<T>(String method, [String? value]) async {
    if (!Platform.isWindows) throw UnsupportedError('Windows credentials only');
    return channel.invokeMethod<T>(method, {
      'directory': directory,
      'key': key,
      'value': ?value,
    });
  }
}
