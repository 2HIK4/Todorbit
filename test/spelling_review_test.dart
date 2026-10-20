import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/shared/spelling_review_button.dart';

void main() {
  testWidgets('spelling review keeps text until a suggestion is selected',
      (tester) async {
    const channel = MethodChannel('life_manager/spell_check');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => [
        {'start': 0, 'length': 3, 'word': 'teh', 'suggestions': ['the']},
      ],
    );
    final field = TextEditingController(text: 'teh task');
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: SpellingReviewButton(controller: field, enabled: true),
      )));
      await tester.tap(find.byTooltip('Review spelling'));
      await tester.pumpAndSettle();
      expect(field.text, 'teh task');
      await tester.tap(find.text('Keep as written'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('the').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply selected'));
      await tester.pumpAndSettle();
      expect(field.text, 'the task');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      field.dispose();
    }
  });
}
