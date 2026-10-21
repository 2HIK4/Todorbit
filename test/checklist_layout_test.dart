import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/workspace/checklist_item_dialog.dart';
import 'package:life_manager/features/workspace/task_composition_section.dart';
import 'package:life_manager/domain/task_view_preferences.dart';

void main() {
  const longText =
      'Write a clear checklist sentence that stays readable in a narrow task panel and can be expanded to reveal all of its details.';

  testWidgets('checklist text can be selected and copied without editing', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    await tester.binding.setSurfaceSize(const Size(700, 400));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemRow(
            title: longText,
            display: CompositionTextDisplay.full,
            done: false,
            onChanged: (_) {},
            onEdit: () {},
            onMoveUp: null,
            onMoveDown: null,
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.longPress(find.text(longText));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(copied, isNotEmpty);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'checklist row stays readable and expands at narrow and wide widths',
    (tester) async {
      for (final width in [310.0, 700.0]) {
        await tester.binding.setSurfaceSize(Size(width, 500));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.5),
                  ),
                  child: ChecklistItemRow(
                    title: longText,
                    done: false,
                    onChanged: (_) {},
                    onEdit: () {},
                    onMoveUp: null,
                    onMoveDown: null,
                    onRemove: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(find.text(longText));
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(find.byType(SelectionArea), findsOneWidget);
        if (find.text('Show more').evaluate().isNotEmpty) {
          await tester.tap(find.text('Show more'));
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);
          await tester.ensureVisible(find.text('Show less'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Show less'));
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(find.text(longText)).maxLines, 2);
        }
        expect(
          find.byTooltip('Checklist actions for $longText'),
          findsOneWidget,
        );
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('full checklist preference shows all selectable text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(310, 500));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemRow(
            title: longText,
            display: CompositionTextDisplay.full,
            done: false,
            onChanged: (_) {},
            onEdit: () {},
            onMoveUp: null,
            onMoveDown: null,
            onRemove: () {},
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text(longText)).maxLines, isNull);
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'checklist editor width follows viewport and stays fixed while typing',
    (tester) async {
      for (final width in [340.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 600));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => editChecklistItem(
                    context,
                    title: 'Edit checklist item',
                    initialValue: 'Short',
                    spellCheckEnabled: false,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final surface = find.byKey(const ValueKey('checklist-dialog-surface'));
        final before = tester.getSize(surface).width;
        await tester.enterText(find.byType(TextField), longText);
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).width, before);
        expect(before, lessThan(width));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
