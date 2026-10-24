import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;
  setUpAll(() async => driver = await FlutterDriver.connect());
  tearDownAll(() async => driver.close());

  test('Habits, Goals, and Backup UI opens in an isolated GUI', () async {
    await Future<void>.delayed(const Duration(seconds: 4));
    await driver.waitFor(find.text('Habits'));
    await driver.tap(find.text('Habits'));
    await driver.runUnsynchronized(() async {
      await driver.tap(find.byTooltip('About this view'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await File('${Directory.systemTemp.path}${Platform.pathSeparator}todorbit-habits-about.png')
          .writeAsBytes(await driver.screenshot());
      await driver.tap(find.byTooltip('About this view'));
    });
    await driver.tap(find.text('Goals'));
    await driver.runUnsynchronized(() async {
      await driver.tap(find.byTooltip('About this view'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await File('${Directory.systemTemp.path}${Platform.pathSeparator}todorbit-goals-about.png')
          .writeAsBytes(await driver.screenshot());
      await driver.tap(find.byTooltip('About this view'));
    });
    await driver.tap(find.text('Backups'));
    await driver.waitFor(find.text('Backup & Restore'));
    await File('${Directory.systemTemp.path}${Platform.pathSeparator}todorbit-backups-spacing.png')
        .writeAsBytes(await driver.screenshot());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
