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
      final appearance = AppearancePreferenceStore(
        File('${root.path}/appearance.json'),
      );
      final database = AppDatabase(NativeDatabase.memory());
      final controller = AppController(
        LifeRepository(database),
        appearanceStore: appearance,
      );
      await tester.runAsync(() async {
        await controller.initialize();
        await controller.setTheme(ThemeModePreference.dark);
        await controller.setFirstWeekday(1);
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
            break;
          }
        }
        await tester.pumpAndSettle();
      }

      try {
        await mount();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export JSON'));
        await finishIo();
        expect(file.existsSync(), isTrue);
        final decoded = await tester.runAsync(
          () => SettingsTransfer.read(file),
        );
        expect(decoded!.categories.keys, contains(SettingsCategory.calendar));
        expect(file.readAsStringSync(), isNot(contains('life_manager.sqlite')));
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
        expect(controller.firstWeekday, 1);
        expect(controller.theme, ThemeModePreference.light);
        final reopened = AppController(
          LifeRepository(database),
          appearanceStore: AppearancePreferenceStore(appearance.file),
        );
        try {
          await tester.runAsync(() => reopened.initialize());
          expect(reopened.firstWeekday, 1);
          expect(reopened.theme, ThemeModePreference.light);
        } finally {
          reopened.dispose();
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        root.deleteSync(recursive: true);
      }
    },
  );
}
