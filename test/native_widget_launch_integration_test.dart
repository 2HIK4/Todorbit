import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/widget_configuration_store.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

void main() {
  final companion = Platform.environment['TODORBIT_NATIVE_SERVICE_EXE'];
  test(
    'first calendar launch and Apply reload return while companion stays alive',
    () async {
      final roaming = Platform.environment['APPDATA']!;
      // This opt-in integration test must never run against a real user profile.
      expect(
        p.isWithin(
          p.join(
            Directory.current.path,
            '.buildlog',
            'widget-customization',
            'native-service-profile',
          ),
          roaming,
        ),
        isTrue,
      );
      final file = await AppDatabase.defaultFile();
      final db = AppDatabase(NativeDatabase(file));
      await db.customSelect('PRAGMA user_version').get();
      await db.close();
      final service = NativeWidgetService(
        widgetExecutable: companion,
        appExecutable: 'unused-test-app.exe',
      );
      final config = File(
        p.join(file.parent.path, 'widget-calendar-configuration.json'),
      );
      expect(
        await config.exists(),
        isFalse,
        reason: 'Use a fresh disposable profile for a first-launch check.',
      );
      try {
        await service
            .setWidgetVisible(DesktopWidgetKind.calendar, true)
            .timeout(const Duration(seconds: 5));
        final deadline = DateTime.now().add(const Duration(seconds: 8));
        while (!await config.exists() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          await config.exists(),
          isTrue,
          reason: 'The detached companion must finish startup.',
        );
        final store = WidgetConfigurationStore(file.parent);
        await store.save(
          DesktopWidgetKind.tasks,
          WidgetConfiguration(enabled: true),
        );
        final tasksFile = File(
          p.join(file.parent.path, 'widget-tasks-configuration.json'),
        );
        final tasksBytes = await tasksFile.readAsBytes();
        final calendarBytes = await config.readAsBytes();
        // Main app reopen/restart while the companion remains alive forwards
        // restore through the same profile mutex/pipe and exits promptly.
        for (var i = 0; i < 3; i++) {
          final forwarded = await Process.run(companion!, [
            '--widget-command',
            'restore',
            '--app-exe',
            'unused-test-app.exe',
          ]).timeout(const Duration(seconds: 8));
          expect(forwarded.exitCode, 0);
        }
        await service.close().timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(await tasksFile.readAsBytes(), tasksBytes);
        expect(await config.readAsBytes(), calendarBytes);
        await service.restoreEnabledWidgets().timeout(
          const Duration(seconds: 5),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        final forwarded = await Process.run(companion!, [
          '--widget-command',
          'restore',
          '--app-exe',
          'unused-test-app.exe',
        ]).timeout(const Duration(seconds: 8));
        expect(
          forwarded.exitCode,
          0,
          reason: 'Restarted companion must own the shared mutex and accept forwarding.',
        );
        expect(await tasksFile.readAsBytes(), tasksBytes);
        expect(await config.readAsBytes(), calendarBytes);
        await service.reloadConfiguration().timeout(const Duration(seconds: 5));
        await service
            .setWidgetVisible(DesktopWidgetKind.calendar, false)
            .timeout(const Duration(seconds: 5));
      } finally {
        await service.close().timeout(const Duration(seconds: 5));
      }
    },
    skip: companion == null
        ? 'Opt-in real companion check requires an explicitly isolated profile.'
        : false,
  );
}
