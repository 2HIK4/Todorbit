import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/workspace/windows_resource_dialog.dart';
import 'package:life_manager/platform/platform_resource_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('life_manager/file_dialog');

  group('PlatformResourceDialog contract and backward compatibility', () {
    test('PlatformResourceDialog and WindowsResourceDialog are interchangeable', () {
      const platformDialog = PlatformResourceDialog();
      const legacyDialog = WindowsResourceDialog();
      expect(platformDialog, isA<PlatformResourceDialog>());
      expect(legacyDialog, isA<PlatformResourceDialog>());
      expect(platformDialog, isA<WindowsResourceDialog>());
    });

    test('chooseFile delegates to platform channel on Windows', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'openFile') return r'C:\test\sample.txt';
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      if (Platform.isWindows) {
        const dialog = PlatformResourceDialog();
        final file = await dialog.chooseFile();
        expect(file?.path, r'C:\test\sample.txt');
        expect(calls.single.method, 'openFile');
      }
    });

    test('chooseFolder delegates to platform channel on Windows', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'openFolder') return r'C:\test\folder';
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      if (Platform.isWindows) {
        const dialog = PlatformResourceDialog();
        final folder = await dialog.chooseFolder();
        expect(folder?.path, r'C:\test\folder');
        expect(calls.single.method, 'openFolder');
      }
    });

    test('open delegates openResource on Windows', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      if (Platform.isWindows) {
        const dialog = PlatformResourceDialog();
        await dialog.open('https://example.com');
        expect(calls.single.method, 'openResource');
        expect(calls.single.arguments, 'https://example.com');
      }
    });
  });
}
