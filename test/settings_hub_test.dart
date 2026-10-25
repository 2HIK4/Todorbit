import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/settings/settings_hub_dialog.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';
import 'package:life_manager/main.dart';

import 'test_privacy.dart';

void main() {
  testWidgets('narrow workspace keeps sidebar search controls in bounds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 700));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Backups'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('narrow Settings switches categories without clipping', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 700));
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => MediaQuery(
                      data: const MediaQueryData(size: Size(600, 700)),
                      child: SettingsHubDialog(
                        nativeWidget: NativeWidgetService(
                          widgetExecutable: 'unavailable.exe',
                        ),
                        showDataProfile: () {},
                      ),
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsHubDialog), findsOneWidget);
      final sectionPicker = find.byWidgetPredicate(
        (widget) => widget is AnchoredSelectField,
      );
      expect(sectionPicker, findsOneWidget);
      await tester.tap(sectionPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task Preferences').last);
      await tester.pumpAndSettle();
      expect(find.text('Task display and defaults'), findsOneWidget);
      await tester.tap(sectionPicker);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Backups & Cloud').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backups & Cloud').last);
      await tester.pumpAndSettle();
      expect(find.text('Local Backups'), findsOneWidget);
      expect(find.text('Google Drive is disconnected.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
