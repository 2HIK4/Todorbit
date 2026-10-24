import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;
  setUpAll(() async => driver = await FlutterDriver.connect());
  tearDownAll(() async => driver.close());

  test('Update Channel opens in a narrow Windows window', () async {
    await Future<void>.delayed(const Duration(seconds: 4));
    await driver.waitFor(find.text('Settings'));
    final executable = '${Directory.current.path}\\build\\windows\\x64\\runner\\Debug\\Todorbit.exe';
    final script = '''
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetWindowPos(System.IntPtr h, System.IntPtr after, int x, int y, int w, int hgt, uint flags);' -Name WindowApi -Namespace TodorbitTest
\$app = Get-Process -Name Todorbit | Where-Object { \$_.Path -eq '$executable' } | Select-Object -First 1
if (-not \$app -or \$app.MainWindowHandle -eq 0) { throw 'Isolated debug window not found.' }
if (-not [TodorbitTest.WindowApi]::SetWindowPos(\$app.MainWindowHandle, [IntPtr]::Zero, 100, 100, 700, 650, 0x0040)) { throw 'Could not resize window.' }
''';
    final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await File('${Directory.systemTemp.path}${Platform.pathSeparator}todorbit-narrow-window.png')
        .writeAsBytes(await driver.screenshot());
    await driver.runUnsynchronized(() async {
      await driver.tap(find.text('Settings'));
      await driver.tap(find.text('Software Updates'));
      await driver.tap(find.text('Stable'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await File('${Directory.systemTemp.path}${Platform.pathSeparator}todorbit-narrow-update-channel.png')
          .writeAsBytes(await driver.screenshot());
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
