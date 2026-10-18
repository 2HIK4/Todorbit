import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('one task stays one row and checkbox through repeated hover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    await controller.refresh();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const LifeManagerApp(),
        ),
      );
      await tester.tap(find.text('All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Hover target',
      );
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await mouse.moveTo(tester.getCenter(checkbox));
        await tester.pump(const Duration(milliseconds: 600));
        expect(checkbox, findsOneWidget);
        expect(find.text('Hover target'), findsOneWidget);
        await mouse.moveTo(tester.getCenter(find.text('Hover target').first));
        await tester.pump(const Duration(milliseconds: 100));
        await mouse.moveTo(tester.getCenter(find.byTooltip('Task actions')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(checkbox, findsOneWidget);
        await mouse.moveTo(const Offset(1000, 600));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(tester.takeException(), isNull);
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('category creation remains stable while add control is hovered', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    await controller.refresh();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const LifeManagerApp(),
        ),
      );
      final add = find.byTooltip('Add category');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await mouse.moveTo(tester.getCenter(add));
        await tester.pump(const Duration(milliseconds: 600));
        await mouse.moveTo(const Offset(1000, 600));
        await tester.pump(const Duration(milliseconds: 150));
      }
      await mouse.moveTo(tester.getCenter(add));
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'University',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('University'), findsOneWidget);
      expect((await repository.categories()).single.name, 'University');
      expect(tester.takeException(), isNull);
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
