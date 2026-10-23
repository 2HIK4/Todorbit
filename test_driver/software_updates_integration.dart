import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart' hide find;

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
    await driver.tap(find.text('Automatically check for updates'));
    final settings = File(
      '${Platform.environment['APPDATA']}${Platform.pathSeparator}TodoPilot${Platform.pathSeparator}update-settings.json',
    );
    final saved =
        jsonDecode(await settings.readAsString()) as Map<String, dynamic>;
    expect(saved['automaticChecks'], isFalse);
    await driver.tap(find.byTooltip('Close Settings'));
    await driver.tap(find.text('Settings'));
    await driver.tap(find.text('Software Updates'));
    await driver.waitFor(find.text('Check for Updates'));
  });
}
