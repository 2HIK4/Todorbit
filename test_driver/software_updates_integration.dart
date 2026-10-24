import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;

  setUpAll(() async => driver = await FlutterDriver.connect());
  tearDownAll(() async => driver.close());

  test('Software Updates opens and persists an automatic-check choice', () async {
    await driver.waitFor(find.text('Settings'));
    await driver.tap(find.text('Settings'));
    await driver.waitFor(find.text('Software Updates'));
    await driver.tap(find.text('Software Updates'));
    await driver.waitFor(find.text('Check for Updates'));
    await driver.waitFor(find.text('Installed version'));
    await driver.waitFor(find.text('Automatically check for updates'));
    await File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}todorbit-software-updates-ui.png',
    ).writeAsBytes(await driver.screenshot());
    final settings = File(
      '${Platform.environment['APPDATA']}${Platform.pathSeparator}TodoPilot${Platform.pathSeparator}update-settings.json',
    );
    final before =
        jsonDecode(await settings.readAsString()) as Map<String, dynamic>;
    await driver.tap(find.text('Automatically check for updates'));
    bool? savedValue;
    for (var attempt = 0; attempt < 30; attempt++) {
      final saved =
          jsonDecode(await settings.readAsString()) as Map<String, dynamic>;
      savedValue = saved['automaticChecks'] as bool?;
      if (savedValue != before['automaticChecks']) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(savedValue, !before['automaticChecks']);
    await driver.tap(find.byTooltip('Close Settings'));
    await driver.tap(find.text('Settings'));
    await driver.tap(find.text('Software Updates'));
    await driver.waitFor(find.text('Check for Updates'));
  });
}
