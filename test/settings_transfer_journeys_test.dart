import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';
import 'package:life_manager/features/settings/settings_transfer_dialog.dart';

void main() {
  testWidgets(
    'settings export import preview Cancel Apply and restart persist selected categories',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('todorbit-b5-transfer-');
      final file = File('${root.path}/settings.json');
      final appearanceFile = File('${root.path}/appearance.json');
      final databaseFile = File('${root.path}/test.sqlite');
      AppDatabase? openDatabase;
      late AppController controller;
      Future<void> closeDatabase() async {
        await openDatabase?.close();
        openDatabase = null;
      }

      addTearDown(() => root.delete(recursive: true));
      addTearDown(closeDatabase);

      // Drift and the preference store create futures during construction.
      // Create and initialize them in the same real-async zone.
      await tester.runAsync(() async {
        final database = AppDatabase(NativeDatabase(databaseFile));
        openDatabase = database;
        controller = AppController(
          LifeRepository(database),
          appearanceStore: AppearancePreferenceStore(appearanceFile),
        );
        await controller.initialize().timeout(const Duration(seconds: 15));
        await controller.setTheme(ThemeModePreference.dark);
        await controller.setFirstWeekday(1);
        await controller.setTaskPanelWidth(440);
      });
      Future<void> mount() => tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: SettingsTransferDialog(
                chooseExport: () async => file,
                chooseImport: () async => file,
              ),
            ),
          ),
        ),
      );
      Future<void> finishIo() async {
        for (var index = 0; index < 100; index++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          final button = find.widgetWithText(TextButton, 'Import JSON');
          if (button.evaluate().isNotEmpty &&
              tester.widget<TextButton>(button).onPressed != null) {
            await tester.pumpAndSettle();
            return;
          }
        }
        final status = tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .whereType<String>()
            .join(' | ');
        fail('Settings transfer did not finish. Visible text: $status');
      }

      try {
        await mount();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export JSON'));
        await finishIo();
        expect(find.textContaining('Settings exported to'), findsOneWidget);
        expect(file.existsSync(), isTrue);
        final decoded = await tester.runAsync(
          () => SettingsTransfer.read(file),
        );
        expect(decoded!.categories.keys, contains(SettingsCategory.calendar));
        final contents = file.readAsStringSync();
        expect(contents, isNot(contains('life_manager.sqlite')));
        expect(contents, isNot(contains('taskPanelWidth')));
        await tester.runAsync(() async {
          await controller.setTheme(ThemeModePreference.light);
          await controller.setFirstWeekday(7);
        });
        await tester.tap(find.text('Import JSON'));
        await finishIo();
        expect(find.textContaining('Theme mode: dark'), findsOneWidget);
        // Keep the import scoped to Calendar; other categories retain current values.
        for (final category in SettingsCategory.values.where(
          (c) => c != SettingsCategory.calendar,
        )) {
          final tile = find.widgetWithText(CheckboxListTile, category.label);
          await tester.ensureVisible(tile);
          await tester.pumpAndSettle();
          await tester.tap(tile);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Apply selected'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(controller.firstWeekday, 7);
        await tester.tap(find.text('Apply selected'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply settings'));
        await finishIo();
        expect(find.text('Selected settings applied.'), findsOneWidget);
        expect(controller.firstWeekday, 1);
        expect(controller.theme, ThemeModePreference.light);
        await tester.pumpWidget(const SizedBox.shrink());
        final persisted = await tester.runAsync(() async {
          await closeDatabase();
          final reopenedDatabase = AppDatabase(NativeDatabase(databaseFile));
          final reopened = AppController(
            LifeRepository(reopenedDatabase),
            appearanceStore: AppearancePreferenceStore(appearanceFile),
          );
          try {
            await reopened.initialize().timeout(const Duration(seconds: 15));
            return (
              reopened.firstWeekday,
              reopened.theme,
              reopened.taskPanelWidth,
            );
          } finally {
            reopened.dispose();
            await reopenedDatabase.close();
          }
        });
        expect(persisted, (1, ThemeModePreference.light, 440));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
