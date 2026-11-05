import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/widget_configuration_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/hotkeys.dart';
import 'package:life_manager/domain/task_view_preferences.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/domain/widget_presets.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';
import 'package:life_manager/features/settings/theme_dialog.dart';

void main() {
  testWidgets('theme file preview Undo Redo Cancel export and saved reopen', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('todorbit-theme-journey-');
    final store = AppearancePreferenceStore(
      File('${root.path}/appearance.json'),
    );
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(
      LifeRepository(database),
      appearanceStore: store,
    );
    final imported = ThemeCustomization(
      light: ThemePalette.ocean,
      dark: ThemePalette.dusk,
      presets: {'Batch 6 custom': ThemePalette.ocean},
      reducedMotion: true,
    );
    final input = File('${root.path}/custom.json')
      ..writeAsStringSync(jsonEncode(imported.toJson()));
    final invalid = File('${root.path}/invalid.json')
      ..writeAsStringSync(jsonEncode({...imported.toJson(), 'version': 999}));
    final output = File('${root.path}/export.json');
    await tester.runAsync(() => controller.initialize());
    final original = controller.customization.toJson();

    Future<void> finishWhen(bool Function() done) async {
      for (var attempt = 0; attempt < 100 && !done(); attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(done(), isTrue);
      await tester.pumpAndSettle();
    }

    Future<void> transfer(String action, File file) async {
      await tester.scrollUntilVisible(
        find.text(action),
        350,
        scrollable: find
            .descendant(
              of: find.byType(ThemeDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), file.path);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        file.path,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    Future<void> open() async {
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
    }

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
                    builder: (_) => const ThemeDialog(),
                  ),
                  child: const Text('Customize'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await open();
      await transfer('Import JSON', input);
      await finishWhen(
        () => find
            .text('Theme imported. Save changes to apply it.')
            .evaluate()
            .isNotEmpty,
      );
      expect(controller.customization.toJson(), original);
      expect(find.text('Batch 6 custom'), findsOneWidget);
      await tester.tap(find.byTooltip('Undo setting (Ctrl+Z)'));
      await tester.pumpAndSettle();
      expect(find.text('Batch 6 custom'), findsNothing);
      await tester.tap(find.byTooltip('Redo setting (Ctrl+Shift+Z)'));
      await tester.pumpAndSettle();
      expect(find.text('Batch 6 custom'), findsOneWidget);
      await transfer('Export JSON', output);
      await finishWhen(
        () => find.text('Theme exported.').evaluate().isNotEmpty,
      );
      expect(
        ThemeCustomization.fromJson(jsonDecode(output.readAsStringSync()))
            .toJson(),
        imported.toJson(),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.customization.toJson(), original);
      expect(
        (await tester.runAsync(store.loadCustomization))!.toJson(),
        original,
      );

      await open();
      await transfer('Import JSON', invalid);
      await finishWhen(
        () => find.textContaining('Theme file:').evaluate().isNotEmpty,
      );
      expect(controller.customization.toJson(), original);
      expect(find.text('Batch 6 custom'), findsNothing);
      await transfer('Import JSON', input);
      await finishWhen(
        () => find
            .text('Theme imported. Save changes to apply it.')
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.text('Save changes'));
      await finishWhen(() => find.byType(ThemeDialog).evaluate().isEmpty);
      expect(controller.customization.toJson(), imported.toJson());
      expect(
        (await tester.runAsync(store.loadCustomization))!.toJson(),
        imported.toJson(),
      );
      await open();
      await tester.scrollUntilVisible(
        find.text('Batch 6 custom'),
        350,
        scrollable: find
            .descendant(
              of: find.byType(ThemeDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Batch 6 custom'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await open();
      final closingExport = File('${root.path}/closed-export.json');
      // Keep the actual transfer future so disposal can race IO without a
      // timing-based sleep; pump fake microtasks while observing completion.
      final pendingExport =
          (tester.state(find.byType(ThemeDialog)) as dynamic).transfer(false)
              as Future<void>;
      var exportFinished = false;
      pendingExport.then((_) => exportFinished = true);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), closingExport.path);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await finishWhen(() => exportFinished);
      expect(
        ThemeCustomization.fromJson(
          jsonDecode(closingExport.readAsStringSync()),
        ).toJson(),
        imported.toJson(),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.runAsync(() => root.delete(recursive: true));
    }
  });

  test('populated settings transfer preserves destination device state after database reopen', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-profile-transfer-',
    );
    final sourceDir = await Directory('${root.path}/source').create();
    final targetDir = await Directory('${root.path}/target').create();
    final sourceDb = AppDatabase(
      NativeDatabase(File('${sourceDir.path}/life.sqlite')),
    );
    var targetDb = AppDatabase(
      NativeDatabase(File('${targetDir.path}/life.sqlite')),
    );
    AppController create(AppDatabase database, Directory dir) => AppController(
      LifeRepository(database),
      appearanceStore: AppearancePreferenceStore(
        File('${dir.path}/appearance-settings.json'),
      ),
      calendarPreferenceStore: CalendarPreferenceStore(
        File('${dir.path}/calendar-settings.json'),
      ),
      widgetStore: WidgetConfigurationStore(dir),
    );
    final source = create(sourceDb, sourceDir);
    var target = create(targetDb, targetDir);
    try {
      await source.initialize();
      await target.initialize();
      await source.setTheme(ThemeModePreference.dark);
      await source.saveCustomization(
        ThemeCustomization(light: ThemePalette.ocean, dark: ThemePalette.dusk),
      );
      await source.setFirstWeekday(1);
      await source.setLastCalendarMode('month');
      await source.setSidebarOrder(source.sidebarOrder.reversed.toList());
      await source.setHotkeys(HotkeyPreferences().saveAs('Batch 6'));
      await source.setTaskViewPreferences(
        const TaskViewPreferences(
          newTaskPlannedDay: NewTaskPlannedDay.noDate,
          keepCompletedVisible: true,
          spellCheckEnabled: false,
          compositionTextDisplay: CompositionTextDisplay.full,
        ),
      );
      for (final kind in DesktopWidgetKind.values) {
        final configuration = WidgetConfiguration(
          enabled: true,
          layoutLocked: true,
          showTitle: kind == DesktopWidgetKind.calendar,
          textScale: kind == DesktopWidgetKind.tasks ? 1.2 : 1.4,
          calendarSplit: .35,
        );
        await source.widgetStore!.save(kind, configuration);
        await source.widgetStore!.savePresets(
          kind,
          WidgetPresets().put('Portable ${kind.name}', configuration, kind),
        );
        await target.widgetStore!.save(
          kind,
          WidgetConfiguration(enabled: false, layoutLocked: false),
        );
      }
      const deviceBytes =
          '{"x":123,"y":234,"width":420,"height":640,"launchAtSignIn":false}';
      final geometry = File('${targetDir.path}/widget-settings.json')
        ..writeAsStringSync(deviceBytes);
      final private = File('${targetDir.path}/privacy-policy.json')
        ..writeAsStringSync('synthetic device-only sentinel');
      final export = File('${root.path}/settings.json');
      await SettingsTransfer.fromController(source)
          .exportTo(export, SettingsCategory.values.toSet());
      final encoded = await export.readAsString();
      expect(encoded, isNot(contains('launchAtSignIn')));
      final bundle = jsonDecode(encoded)['categories']['widgets'];
      for (final kind in DesktopWidgetKind.values) {
        expect(
          bundle[kind.name]['configuration'].containsKey('layoutLocked'),
          isFalse,
        );
        expect(
          bundle[kind.name]['configuration'].containsKey('enabled'),
          isFalse,
        );
      }
      expect(encoded, isNot(contains('life.sqlite')));
      final transfer = await SettingsTransfer.read(export);
      await transfer.applyTo(target, SettingsCategory.values.toSet());
      target.dispose();
      await targetDb.close();
      targetDb = AppDatabase(
        NativeDatabase(File('${targetDir.path}/life.sqlite')),
      );
      target = create(targetDb, targetDir);
      await target.initialize();
      expect(target.theme, ThemeModePreference.dark);
      expect(target.customization.toJson(), source.customization.toJson());
      expect(target.firstWeekday, 1);
      expect(target.lastCalendarMode, 'month');
      expect(target.sidebarOrder, source.sidebarOrder);
      expect(target.hotkeys.activePreset, 'Batch 6');
      expect(
        target.taskViewPreferences.newTaskPlannedDay,
        NewTaskPlannedDay.noDate,
      );
      expect(target.taskViewPreferences.keepCompletedVisible, isTrue);
      expect(target.taskViewPreferences.spellCheckEnabled, isFalse);
      expect(
        target.taskViewPreferences.compositionTextDisplay,
        CompositionTextDisplay.full,
      );
      for (final kind in DesktopWidgetKind.values) {
        final saved = await target.widgetStore!.load(kind);
        final expected = (await source.widgetStore!.load(kind))
            .copyWith(enabled: false, layoutLocked: false);
        expect(saved.toJson(), expected.toJson());
        expect((await target.widgetStore!.loadPresets(kind)).custom.keys, [
          'Portable ${kind.name}',
        ]);
      }
      expect(await geometry.readAsString(), deviceBytes);
      expect(await private.readAsString(), 'synthetic device-only sentinel');
      expect(
        (await source.widgetStore!.load(DesktopWidgetKind.tasks)).enabled,
        isTrue,
      );
      final before = SettingsTransfer.fromController(target)
          .encode(SettingsCategory.values.toSet());
      final invalid = jsonDecode(encoded) as Map<String, dynamic>;
      invalid['categories']['calendar']['firstWeekday'] = 99;
      expect(
        () => SettingsTransfer.decode(jsonEncode(invalid)),
        throwsFormatException,
      );
      expect(
        SettingsTransfer.fromController(target)
            .encode(SettingsCategory.values.toSet()),
        before,
      );
    } finally {
      source.dispose();
      target.dispose();
      await sourceDb.close();
      await targetDb.close();
      await root.delete(recursive: true);
    }
  });
}
