import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/workspace/checklist_item_dialog.dart';
import 'package:life_manager/features/workspace/task_composition_section.dart';

void main() {
  const longText =
      'Write a clear checklist sentence that stays readable in a narrow task panel and can be expanded to reveal all of its details.';

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
        final text = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(text.maxLines, 2);
        if (find.text('Show more').evaluate().isNotEmpty) {
          await tester.tap(find.text('Show more'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<SelectableText>(find.byType(SelectableText)).maxLines,
            isNull,
          );
          await tester.ensureVisible(find.text('Show less'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Show less'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<SelectableText>(find.byType(SelectableText)).maxLines,
            2,
          );
        }
        expect(
          find.byTooltip('Checklist actions for $longText'),
          findsOneWidget,
        );
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

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
