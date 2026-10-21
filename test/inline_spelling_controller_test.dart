import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/inline_spelling_controller.dart';

void main() {
  testWidgets(
    'inline spelling underlines reported word without editing input',
    (tester) async {
      final controller = InlineSpellingController(
        check: (text) async => [
          {'start': 6, 'length': 4, 'word': 'wrng'},
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Write wrng');
      await tester.pump(const Duration(milliseconds: 350));
      final context = tester.element(find.byType(TextField));
      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );
      final marked = span.children!.whereType<TextSpan>().singleWhere(
        (child) => child.text == 'wrng',
      );
      expect(marked.style?.decoration, TextDecoration.underline);
      expect(marked.style?.decorationColor, Colors.red);
      expect(controller.text, 'Write wrng');
      controller.enabled = false;
      expect(
        controller
            .buildTextSpan(context: context, withComposing: false)
            .children,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
