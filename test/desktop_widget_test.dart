import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/widget/desktop_widget.dart';

void main() {
  testWidgets('widget can add and complete a real task', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 480));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: DesktopWidgetApp(onExit: () async {}),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Plan tomorrow');
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      expect((await repository.tasks()).single.title, 'Plan tomorrow');
      expect(
        (await repository.tasks()).single.scheduledDate,
        localDate(DateTime.now()),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect((await repository.tasks()).single.status, TaskStatus.completed);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('widget input refocuses after repeated app launches', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 480));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    await controller.refresh();
    var launches = 0;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: DesktopWidgetApp(
            onExit: () async {},
            onOpenApp: () async {
              launches++;
            },
          ),
        ),
      );
      final input = find.byType(TextField);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Open main app'));
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.tap(find.byTooltip('Refresh'));
        await tester.pumpAndSettle();
        await tester.tap(input);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.enterText(input, 'Focus cycle $i');
        await tester.tap(find.byTooltip('Add task'));
        await tester.pumpAndSettle();
      }
      expect(launches, 3);
      expect((await repository.tasks()).map((task) => task.title), [
        'Focus cycle 2',
        'Focus cycle 1',
        'Focus cycle 0',
      ]);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
