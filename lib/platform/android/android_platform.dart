import 'dart:io';

import 'package:flutter/services.dart';

/// Android-only device operations. No Windows IPC or database writes occur here.
class AndroidPlatform {
  static const channel = MethodChannel('todorbit/android');

  static Future<bool> requestNotifications() async =>
      await channel.invokeMethod<bool>('requestNotifications') ?? false;

  static Future<bool> notificationsAllowed() async =>
      await channel.invokeMethod<bool>('notificationsAllowed') ?? false;

  static Future<void> openNotificationSettings() =>
      channel.invokeMethod<void>('notificationSettings');

  static Future<File?> importDocument({String mime = '*/*'}) async {
    final selected = await channel.invokeMethod<String>('importDocument', mime);
    return selected == null ? null : File(selected);
  }

  static Future<bool> exportDocument(
    File source, {
    required String name,
    String mime = 'application/octet-stream',
  }) async =>
      await channel.invokeMethod<bool>('exportDocument', {
        'path': source.path,
        'name': name,
        'mime': mime,
      }) ??
      false;

  static Future<void> protectScreen(bool enabled) =>
      channel.invokeMethod<void>('protectScreen', enabled);

  static Future<bool> authenticate() async =>
      await channel.invokeMethod<bool>('authenticate') ?? false;
}
