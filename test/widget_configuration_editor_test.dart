import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/features/settings/widget_settings_page.dart';

void main() {
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
        await tester.tap(find.text('Show widget title'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Show Open App button'));
        await tester.tap(find.text('Show Open App button'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Drag the outer margin'), findsOneWidget);
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
        expect(result!.allWidgets, isFalse);
        expect(result!.configuration.toJson(), original.toJson());
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
