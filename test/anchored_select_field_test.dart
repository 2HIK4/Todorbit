import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('select shows keyboard focus before opening ($brightness)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 600));
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
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AnchoredSelectField<int>(
                    initialValue: 1,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Personal')),
                    ],
                    onChanged: (_) {},
                  ),
                  TextButton(onPressed: () {}, child: const Text('Next')),
                ],
              ),
            ),
          ),
        ),
      );
      final decorator = find.byType(InputDecorator);
      expect(tester.widget<InputDecorator>(decorator).isFocused, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.widget<InputDecorator>(decorator).isFocused, isTrue);
      expect(find.byType(MenuItemButton), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.widget<InputDecorator>(decorator).isFocused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.widget<InputDecorator>(decorator).isFocused, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'select menu anchors below field and keeps it visible ($brightness)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(700, 600));
        String selected = 'one';
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness, useMaterial3: true),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    AnchoredSelectField<String>(
                      initialValue: selected,
                      decoration: const InputDecoration(
                        labelText: 'Update channel',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'one', child: Text('Stable')),
                        DropdownMenuItem(
                          value: 'two',
                          child: Text('Pre-release'),
                        ),
                      ],
                      onChanged: (value) => selected = value!,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final field = find.byType(AnchoredSelectField<String>);
        final fieldRect = tester.getRect(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        final menuItem = find.widgetWithText(MenuItemButton, 'Pre-release');
        expect(menuItem, findsOneWidget);
        expect(
          tester.getRect(menuItem).top,
          greaterThanOrEqualTo(fieldRect.bottom - 1),
        );
        expect(tester.getRect(menuItem).right, lessThanOrEqualTo(700));
        await tester.tap(menuItem);
        await tester.pumpAndSettle();
        expect(selected, 'two');
      },
    );
  }

  testWidgets('menu remains in viewport when field is near the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(350, 400));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 320, 16, 0),
            child: AnchoredSelectField<int>(
              initialValue: 1,
              externalLabel: 'Category',
              items: [
                for (var i = 0; i < 12; i++)
                  DropdownMenuItem(value: i, child: Text('Choice $i')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AnchoredSelectField<int>));
    await tester.pumpAndSettle();
    final menu = tester.getRect(find.byType(Scrollbar).last);
    final label = tester.getRect(find.text('Category'));
    expect(menu.top, greaterThanOrEqualTo(0));
    expect(menu.bottom, lessThanOrEqualTo(400));
    expect(menu.bottom <= label.top || menu.top >= label.bottom, isTrue);
  });

  testWidgets('select opens and chooses an option from the keyboard', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnchoredSelectField<String>(
            initialValue: 'one',
            items: const [
              DropdownMenuItem(value: 'one', child: Text('One')),
              DropdownMenuItem(value: 'two', child: Text('Two')),
            ],
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Two'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'two');
  });
}
