import 'dart:io';

import 'package:flutter/services.dart';

import '../../platform/android/android_platform.dart';

class WindowsSettingsFileDialog {
  const WindowsSettingsFileDialog();

  static const _channel = MethodChannel('life_manager/file_dialog');

  Future<File?> chooseImport() => _choose('openSettings');
  Future<File?> chooseExport() => _choose('saveSettings');

  Future<File?> _choose(String method) async {
    if (Platform.isAndroid && method == 'openSettings') {
      return AndroidPlatform.importDocument(mime: 'application/json');
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Settings file dialogs are Windows only.');
    }
    final selected = await _channel.invokeMethod<String>(method);
    return selected == null ? null : File(selected);
  }
}
