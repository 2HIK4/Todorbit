import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  final phase = Platform.environment['TODORBIT_RUNTIME_PHASE'] ?? 'create';
  final sentinel =
      Platform.environment['TODORBIT_RUNTIME_SENTINEL'] ??
      'Runtime Restart Sentinel';

  late FlutterDriver driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect(timeout: const Duration(seconds: 45));
  });

  tearDownAll(() async {
    await driver.close();
  });

  test(
    'Windows live app runtime ($phase): UI interaction and process restart persistence',
    () async {
      await driver.waitFor(
        find.text('New task'),
        timeout: const Duration(seconds: 30),
      );

      if (phase == 'create') {
        await driver.tap(find.text('New task'));
        final titleField = find.byValueKey('task-title-field');
        await driver.waitFor(titleField, timeout: const Duration(seconds: 15));
        await driver.tap(titleField);
        await driver.enterText(sentinel);
        await driver.waitFor(
          find.text('Create task'),
          timeout: const Duration(seconds: 10),
        );
        await driver.tap(find.text('Create task'));
        await driver.waitFor(
          find.text(sentinel),
          timeout: const Duration(seconds: 15),
        );

        final appData = Platform.environment['APPDATA'];
        expect(appData, isNotNull);
        final dbFile = File(
          '$appData${Platform.pathSeparator}TodoPilot${Platform.pathSeparator}life_manager.sqlite',
        );
        expect(
          await dbFile.exists(),
          isTrue,
          reason:
              'Isolated SQLite database must be created in disposable APPDATA',
        );
      } else if (phase == 'verify') {
        await driver.waitFor(
          find.text(sentinel),
          timeout: const Duration(seconds: 20),
        );
      } else {
        fail('Unsupported TODORBIT_RUNTIME_PHASE: $phase');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
