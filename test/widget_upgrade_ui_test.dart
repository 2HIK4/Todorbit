import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/settings/widget_settings_page.dart';
import 'package:life_manager/features/shared/settings_history_scope.dart';
import 'package:life_manager/data/widget_configuration_store.dart';
import 'package:life_manager/domain/widget_presets.dart';

class PresetMemoryStore extends WidgetConfigurationStore {
  PresetMemoryStore() : super(Directory('unused-widget-upgrade-test'));
  WidgetPresets library = WidgetPresets();
  @override
  Future<WidgetPresets> loadPresets(DesktopWidgetKind kind) async => library;
  @override
  Future<void> savePresets(DesktopWidgetKind kind, WidgetPresets value) async {
    library = value;
  }
}

void main() {
  testWidgets(
    'custom presets stay draft until Apply and Cancel discards a duplicate',
    (tester) async {
      final store = PresetMemoryStore();
      WidgetConfiguration? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => WidgetConfigurationEditor(
                    kind: DesktopWidgetKind.tasks,
                    initial: WidgetConfiguration(),
                    store: store,
                    onApply: (value, _, _) async {
                      saved = value;
                      return value;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save as Preset'));
      await tester.tap(find.text('Save as Preset'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Study');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(store.library.custom, isEmpty);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(store.library.custom.keys, contains('Study'));
      expect(saved!.presetName, 'Study');
      await tester.ensureVisible(find.byTooltip('Manage preset'));
      await tester.tap(find.byTooltip('Manage preset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate preset'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Copy');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.library.custom.containsKey('Copy'), false);
      expect(find.text('Customize Tasks Widget'), findsNothing);
    },
  );
  testWidgets(
    'text-field focus keeps native text undo out of settings history',
    (tester) async {
      var settingsUndo = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsHistoryScope(
              undo: () => settingsUndo++,
              redo: () {},
              child: const TextField(autofocus: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Text has its own history',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(settingsUndo, 0);
    },
  );
  testWidgets(
    'reorder hidden navigation with keyboard buttons and undo/redo, then Apply',
    (tester) async {
      WidgetConfiguration? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetConfigurationEditor(
              kind: DesktopWidgetKind.tasks,
              initial: WidgetConfiguration(views: ['today', 'all']),
              onApply: (value, _, _) async {
                saved = value;
                return value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Layout & navigation'));
      await tester.tap(find.text('Layout & navigation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Move Inbox up'));
      await tester.tap(find.byTooltip('Move Inbox up'));
      await tester.pumpAndSettle();
      var rows = tester
          .widgetList<Row>(find.byType(Row))
          .where(
            (row) =>
                row.key is ValueKey<String> &&
                (row.key as ValueKey<String>).value.startsWith('view-'),
          )
          .toList();
      expect(rows.first.key, const ValueKey('view-inbox'));
      await tester.ensureVisible(find.byTooltip('Undo setting (Ctrl+Z)'));
      await tester.tap(find.byTooltip('Undo setting (Ctrl+Z)'));
      await tester.pumpAndSettle();
      rows = tester
          .widgetList<Row>(find.byType(Row))
          .where(
            (row) =>
                row.key is ValueKey<String> &&
                (row.key as ValueKey<String>).value.startsWith('view-'),
          )
          .toList();
      expect(rows.first.key, const ValueKey('view-today'));
      await tester.tap(find.byTooltip('Redo setting (Ctrl+Shift+Z)'));
      await tester.pumpAndSettle();
      final handle = find.descendant(
        of: find.byKey(const ValueKey('view-inbox')),
        matching: find.byType(ReorderableDragStartListener),
      );
      await tester.ensureVisible(handle);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(saved!.navigationOrder.first, 'today');
      expect(saved!.views.contains('inbox'), false);
    },
  );
  testWidgets(
    'one slider gesture is one keyboard Undo; new change clears Redo',
    (tester) async {
      WidgetConfiguration? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetConfigurationEditor(
              kind: DesktopWidgetKind.tasks,
              initial: WidgetConfiguration(),
              onApply: (value, _, _) async {
                saved = value;
                return value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Typography'));
      await tester.tap(find.text('Typography'));
      await tester.pumpAndSettle();
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(slider);
      final drag = await tester.startGesture(
        Offset(bounds.left + 24, bounds.center.dy),
      );
      await drag.moveBy(Offset(bounds.width * .25, 0));
      await tester.pump();
      await drag.moveBy(Offset(bounds.width * .2, 0));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, greaterThan(1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, greaterThan(1));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(saved!.textScale, greaterThan(1));
    },
  );
}
