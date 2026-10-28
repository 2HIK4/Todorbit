import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../platform/android/android_platform.dart';

class WindowsResourceDialog {
  const WindowsResourceDialog();
  static const _channel = MethodChannel('life_manager/file_dialog');

  Future<File?> chooseFile() async {
    if (Platform.isAndroid) return AndroidPlatform.importDocument();
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
    if (Platform.isAndroid) {
      if (File(target).isAbsolute && await File(target).exists()) {
        await AndroidPlatform.channel.invokeMethod<void>('openPrivateFile',target);
        return;
      }
      final uri = Uri.tryParse(target);
      if (uri == null ||
          !['https', 'http', 'mailto', 'tel', 'content'].contains(uri.scheme)) {
        throw UnsupportedError(
          'Relink this resource using an Android document or web link.',
        );
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No application can open this resource.');
      }
      return;
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows resource opening only');
    }
    await _channel.invokeMethod<void>('openResource', target);
  }
}
