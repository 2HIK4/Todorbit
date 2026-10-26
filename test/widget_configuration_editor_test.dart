import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/settings/widget_settings_page.dart';

void main() {
  testWidgets('slow Apply blocks form edits until saved baseline is accepted', (
    tester,
  ) async {
    final pending = Completer<WidgetConfiguration>();
    final original = WidgetConfiguration(
      navigationPosition: WidgetNavigationPosition.right,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WidgetConfigurationEditor(
            kind: DesktopWidgetKind.tasks,
            initial: original,
            onApply: (_, _, _) => pending.future,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Layout & navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Layout & navigation'));
    await tester.pumpAndSettle();
    final field = find.byType(
      DropdownButtonFormField<WidgetNavigationPosition>,
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    await tester.tap(field, warnIfMissed: false);
    await tester.pump();
    expect(find.text('left'), findsNothing);
    pending.complete(original);
    await tester.pumpAndSettle();
    final dropdown = find.descendant(
      of: field,
      matching: find.byType(DropdownButton<WidgetNavigationPosition>),
    );
    expect(
      tester.widget<DropdownButton<WidgetNavigationPosition>>(dropdown).value,
      WidgetNavigationPosition.right,
    );
    expect(find.text('Changes saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'editor ${brightness.name} stages header changes, cancel and apply all',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(480, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final original = WidgetConfiguration(enabled: true);
        WidgetEditorResult? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<WidgetEditorResult>(
                      context: context,
                      builder: (_) => WidgetConfigurationEditor(
                        kind: DesktopWidgetKind.tasks,
                        initial: original,
                      ),
                    );
                  },
                  child: const Text('Configure'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Configure'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Show widget title'));
        await tester.ensureVisible(
          find.widgetWithText(SwitchListTile, 'Show widget title'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Show widget title'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Show Open App button'));
        await tester.tap(find.text('Show Open App button'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Use the top grip'), findsOneWidget);
        expect(original.hasHeader, isTrue);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(original.hasHeader, isTrue);
        await tester.tap(find.text('Configure'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply to All Widgets'));
        await tester.pumpAndSettle();
        expect(
          find.text('Apply shared appearance to both widgets?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(find.byType(WidgetConfigurationEditor), findsOneWidget);
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.byType(WidgetConfigurationEditor), findsOneWidget);
        expect(find.text('Changes saved'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'calendar editor narrow scaled footer and Escape (${brightness.name})',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => WidgetConfigurationEditor(
                      kind: DesktopWidgetKind.calendar,
                      initial: WidgetConfiguration(),
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
        expect(find.text('Apply').hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('Show widget title'));
        await tester.ensureVisible(
          find.widgetWithText(SwitchListTile, 'Show widget title'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Show widget title'),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Unsaved widget changes'), findsOneWidget);
        await tester.tap(find.text('Continue Editing'));
        await tester.pumpAndSettle();
        expect(find.text('Customize Calendar Widget'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Customize Calendar Widget'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('calendar editor omits task input and navigation settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WidgetConfigurationEditor(
          kind: DesktopWidgetKind.calendar,
          initial: WidgetConfiguration(),
        ),
      ),
    );
    expect(find.text('Layout & navigation'), findsNothing);
    expect(find.text('Quick-add input'), findsNothing);
    expect(find.text('Calendar cells'), findsOneWidget);
    expect(find.text('Selected date agenda'), findsOneWidget);
  });
}
