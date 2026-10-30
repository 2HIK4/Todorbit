// Run only with test_driver/android_update_app.dart on a disposable emulator.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['DART_VM_SERVICE_URL'],
  );
  try {
    await driver.waitUntilFirstFrameRasterized().timeout(
      const Duration(minutes: 3),
    );
    await driver.runUnsynchronized(() async {
      switch (args.single) {
        case 'seed':
          stdout.writeln(await driver.requestData('seed'));
        case 'prepare':
          stdout.writeln(await driver.requestData('fixture-update'));
          await driver.waitFor(find.text('Check for Updates'));
          await driver.tap(find.text('Check for Updates'));
          await driver.waitFor(find.text('Download Update'));
          await driver.scrollIntoView(find.text('Download Update'));
          await driver.tap(find.text('Download Update'));
          await driver.waitFor(
            find.text('Install Update'),
            timeout: const Duration(minutes: 2),
          );
        case 'install':
          await driver.scrollIntoView(find.text('Install Update'));
          await driver.tap(find.text('Install Update'));
        case 'permission':
          await driver.waitFor(find.text('Open Android settings'));
          await driver.tap(find.text('Open Android settings'));
        case 'state':
          stdout.writeln(await driver.requestData('state'));
        default:
          throw ArgumentError(
            'Expected seed, prepare, install, permission or state',
          );
      }
    });
  } finally {
    await driver.close();
  }
}
