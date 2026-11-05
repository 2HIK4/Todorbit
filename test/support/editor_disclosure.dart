import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/shared/settings_section.dart';

Future<void> expandEditorSection(
  WidgetTester tester,
  String label, {
  Type editor = TaskEditor,
}) async {
  final section = find.descendant(
    of: find.byType(editor).first,
    matching: find.byWidgetPredicate(
      (w) => w is SettingsSection && w.title == label,
    ),
  );
  await tester.scrollUntilVisible(
    section,
    160,
    scrollable: find
        .descendant(
          of: find.byType(editor).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  final visible = find
      .descendant(of: section, matching: find.text(label))
      .hitTestable()
      .first;
  if (!ExpansibleController.of(tester.element(visible)).isExpanded) {
    await tester.tap(visible);
    await tester.pumpAndSettle();
  }
}
