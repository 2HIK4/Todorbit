import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/goals/goal_dialogs.dart';
import 'package:life_manager/features/habits/habit_editor.dart';

void main() {
  for (final (label, editor) in [
    ('habit', const HabitEditorDialog()),
    ('goal', const GoalEditorDialog()),
  ]) {
    testWidgets(
      '$label editor keeps the draft and actions above the keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 740);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        final database = AppDatabase(NativeDatabase.memory());
        final controller = AppController(LifeRepository(database));
        await controller.refresh();
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith((ref) => controller),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: TargetPlatform.android),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => editor,
                      ),
                      child: const Text('Open editor'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
          final title = find.widgetWithText(TextField, 'Title *');
          const draft = 'A long title that wraps across several lines';
          await tester.enterText(title, draft);
          tester.view.viewInsets = const FakeViewPadding(bottom: 270);
          await tester.pumpAndSettle();
          final save = find.text('Create $label');
          expect(save.hitTestable(), findsOneWidget);
          expect(find.text('Cancel').hitTestable(), findsOneWidget);
          expect(tester.getBottomLeft(save).dy, lessThan(470));
          expect(tester.widget<TextField>(title).controller!.text, draft);
          expect(controller.habits, isEmpty);
          expect(controller.goals, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await database.close();
        }
      },
    );
  }
}
