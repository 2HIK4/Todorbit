import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/inline_spelling_controller.dart';

void main() {
  testWidgets('Windows spelling channel marks text without autocorrecting', (
    tester,
  ) async {
    const channel = MethodChannel('life_manager/spell_check');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => [
        {
          'start': 0,
          'length': 3,
          'word': 'teh',
          'suggestions': ['the'],
        },
      ],
    );
    final field = InlineSpellingController(text: 'teh task');
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: field)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      final span = field.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );
      expect(span.children?.whereType<TextSpan>().first.text, 'teh');
      expect(
        span.children?.whereType<TextSpan>().first.style?.decorationColor,
        Colors.red,
      );
      expect(field.text, 'teh task');
      expect(find.byIcon(Icons.spellcheck), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      field.dispose();
    }
  });
}
