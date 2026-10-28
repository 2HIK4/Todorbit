import 'dart:io';

import 'package:flutter/services.dart';

import '../../platform/android/android_platform.dart';

class WindowsDatabaseFileDialog {
  const WindowsDatabaseFileDialog();

  static const _channel = MethodChannel('life_manager/file_dialog');

  Future<File?> chooseImport() => _choose('openDatabase');
  Future<File?> chooseExport() => _choose('saveDatabase');

  Future<File?> _choose(String method) async {
    if (Platform.isAndroid && method == 'openDatabase') {
      return AndroidPlatform.importDocument();
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Database file dialogs are Windows only.');
    }
    final selected = await _channel.invokeMethod<String>(method);
    return selected == null ? null : File(selected);
  }
}
