import 'dart:io';

import 'package:flutter/services.dart';

class WindowsResourceDialog {
  const WindowsResourceDialog();
  static const _channel = MethodChannel('life_manager/file_dialog');

  Future<File?> chooseFile() async {
    if (!Platform.isWindows) throw UnsupportedError('Windows file picker only');
    final selected = await _channel.invokeMethod<String>('openFile');
    return selected == null ? null : File(selected);
  }

  Future<Directory?> chooseFolder() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows folder picker only');
    }
    final selected = await _channel.invokeMethod<String>('openFolder');
    return selected == null ? null : Directory(selected);
  }

  Future<void> open(String target) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows resource opening only');
    }
    await _channel.invokeMethod<void>('openResource', target);
  }
}
