import 'dart:ui' show PointerDeviceKind;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/app/privacy_manager.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/privacy_store.dart';
import 'package:life_manager/domain/task_view_preferences.dart';
import 'package:life_manager/features/settings/task_view_settings_dialog.dart';
import 'package:life_manager/features/settings/theme_dialog.dart';
import 'package:life_manager/features/settings/hotkeys_dialog.dart';
import 'package:life_manager/features/settings/notification_dialog.dart';
import 'package:life_manager/features/settings/privacy_dialog.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:life_manager/features/shared/color_picker_dialog.dart';
import 'package:life_manager/features/shared/desktop_tooltip_theme.dart';
import 'package:life_manager/features/shared/settings_section.dart';
import 'package:life_manager/features/shared/text_prompt_dialog.dart';
import 'package:life_manager/features/widget/native_widget_service.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'settings sections group controls and retain drafts ($brightness)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SettingsSection(
                    title: 'Typography',
                    description: 'Adjust the size of widget text.',
                    children: [
                      TextField(
                        decoration: InputDecoration(labelText: 'Text size'),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Surface',
                    children: [
                      SettingsHelperText('Change the shared background.'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('Typography'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '120%');
        final section = tester.getRect(find.byType(SettingsSection).first);
        final field = tester.getRect(find.byType(TextField));
        expect(field.left, greaterThan(section.left));
        expect(field.right, lessThan(section.right));
        expect(field.bottom, lessThan(section.bottom));
        await tester.tap(find.text('Typography'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Typography'));
        await tester.pumpAndSettle();
        expect(find.text('120%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('desktop tooltip waits and follows its palette ($brightness)', (
      tester,
    ) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            tooltipTheme: desktopTooltipTheme(scheme),
          ),
          home: const Scaffold(
            body: Center(
              child: Tooltip(
                message: 'Open the selected day',
                child: Icon(Icons.calendar_month),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(Icon)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Open the selected day'), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Open the selected day'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Open the selected day'));
      expect(text.style?.color, scheme.onSurface);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('Open the selected day'), findsNothing);
      await mouse.removePointer();
    });

    testWidgets(
      'theme and task preferences fit narrow scaled windows ($brightness)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 600));
        final database = AppDatabase(NativeDatabase.memory());
        final controller = AppController(LifeRepository(database));
        await controller.refresh();
        try {
          Future<void> show(Widget dialog) async {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appControllerProvider.overrideWith((_) => controller),
                ],
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!,
                  ),
                  home: Scaffold(body: Center(child: dialog)),
                ),
              ),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pumpAndSettle();
          }

          await show(const ThemeDialog());
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Opening screen'),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          final opening = find.byWidgetPredicate(
            (widget) =>
                widget is AnchoredSelectField<String> &&
                widget.initialValue == 'today',
          );
          await tester.ensureVisible(opening);
          await tester.pumpAndSettle();
          await tester.tap(opening);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(MenuItemButton, 'Calendar'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Save changes').hitTestable(), findsOneWidget);

          await show(const HotkeysDialog());
          expect(find.text('Done').hitTestable(), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'search');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await show(const TaskViewSettingsDialog());
          final checklist = find.byType(
            AnchoredSelectField<CompositionTextDisplay>,
          );
          await tester.scrollUntilVisible(
            checklist,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(checklist);
          await tester.pumpAndSettle();
          expect(checklist.hitTestable(), findsOneWidget);
          await tester.tap(checklist);
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(
              MenuItemButton,
              'Compact (two lines, expandable)',
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
          expect(
            controller.taskViewPreferences.compositionTextDisplay,
            CompositionTextDisplay.compact,
          );
          expect(find.text('Done').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);

          await show(
            NotificationDialog(
              service: NativeWidgetService(
                widgetExecutable: 'missing-companion.exe',
              ),
            ),
          );
          await tester.scrollUntilVisible(
            find.text('The packaged Windows tray companion is unavailable.'),
            120,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Save').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await database.close();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }

  testWidgets(
    'select keyboard skips disabled choices and keeps selection usable',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnchoredSelectField<String>(
              initialValue: 'one',
              items: const [
                DropdownMenuItem(value: 'one', child: Text('One')),
                DropdownMenuItem(
                  value: 'two',
                  enabled: false,
                  child: Text('Unavailable'),
                ),
                DropdownMenuItem(value: 'three', child: Text('Three')),
              ],
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'three');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'color dialog validates HEX and closes without disposed controllers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Color? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Edit color'),
                onPressed: () async {
                  result = await showDialog<Color>(
                    context: context,
                    builder: (_) => const ColorPickerDialog(
                      title: 'Background',
                      initialColor: Colors.white,
                      defaultColor: Colors.black,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit color'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '#bad');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '#12AB34');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(result, const Color(0xFF12AB34));
      expect(find.byType(ColorPickerDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('text prompt stays valid through keyboard submit and dismissal', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Name preset'),
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const TextPromptDialog(
                    title: 'Preset name',
                    initial: 'Lavender',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Name preset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ocean');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'Ocean');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lock screen keeps PIN and unlock reachable at larger text sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 480));
      final directory = Directory.systemTemp.createTempSync(
        'todorbit-lock-layout-',
      );
      final manager = PrivacyManager(
        PrivacyStore(File('${directory.path}/privacy-settings.json')),
        const PrivacySettings(enabled: true),
      );
      try {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [privacyManagerProvider.overrideWith((_) => manager)],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: const LockScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TextField));
          await tester.enterText(find.byType(TextField), '123456');
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Unlock'),
          );
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(FilledButton, 'Unlock').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expect(manager.locked, isTrue);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        manager.dispose();
        directory.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
