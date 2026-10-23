import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/shared/event_color_picker.dart';
import 'package:life_manager/features/shared/weekdays.dart';

void main() {
  testWidgets(
    'event form keeps focused title label inside dialog and opens category below',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 750));
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      await repo.addCategory('Class');
      final controller = AppController(repo);
      await controller.refresh();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Dialog(
                    child: SizedBox(
                      width: 500,
                      height: 630,
                      child: EventEditor(
                        initialDay: DateTime(2026, 10, 25),
                        onClose: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final title = find.widgetWithText(TextField, 'Title *');
        expect(title, findsOneWidget);
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('Title *')).dy,
          greaterThan(tester.getTopLeft(find.byType(Dialog)).dy),
        );
        final trigger = find.byTooltip('Choose category');
        await tester.ensureVisible(trigger);
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(
          tester
              .getTopLeft(find.widgetWithText(PopupMenuItem<String>, 'Class'))
              .dy,
          greaterThan(tester.getTopLeft(trigger).dy),
        );
        await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Class'));
        await tester.pumpAndSettle();
        expect(find.text('Class'), findsOneWidget);
        await tester.tap(find.byTooltip('Add detail'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Room'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Room'),
          'Room 204',
        );
        await tester.enterText(title, 'Lecture');
        await tester.ensureVisible(find.text('Save event'));
        await tester.tap(find.text('Save event'));
        await tester.pumpAndSettle();
        expect(controller.events.single.details.single.value, 'Room 204');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('weekday selector fits seven equal controls in a narrow row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 300));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: WeekdayPickerRow(
                firstWeekday: DateTime.sunday,
                selected: const {7, 1},
                onSelected: (_, _) {},
              ),
            ),
          ),
        ),
      );
      final row = find.byType(WeekdayPickerRow);
      final cells = find.descendant(of: row, matching: find.byType(Expanded));
      expect(cells, findsNWidgets(7));
      final widths = cells
          .evaluate()
          .map((element) => tester.getSize(find.byWidget(element.widget)).width)
          .toList();
      expect(widths.every((width) => (width - widths.first).abs() < 1), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('custom color dialog closes without using a disposed field', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await chooseEventColor(context, 0xFF5365B5);
              },
              child: const Text('Choose color'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose color'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'HEX color'),
      '#12AB34',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
    expect(selected, 0xFF12AB34);
    expect(tester.takeException(), isNull);
  });
}
