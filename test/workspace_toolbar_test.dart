import 'dart:ui' show PointerDeviceKind;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets(
    'Schedule History toolbar action has a visible themed icon and opens history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(database));
      await controller.refresh();
      try {
        for (final preference in [
          ThemeModePreference.light,
          ThemeModePreference.dark,
        ]) {
          controller.theme = preference;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith((ref) => controller),
              ],
              child: const LifeManagerApp(),
            ),
          );
          await tester.pumpAndSettle();

          final buttonFinder = find.byKey(
            const ValueKey('schedule-history-button'),
          );
          expect(buttonFinder, findsOneWidget);
          expect(find.byTooltip('Schedule History'), findsOneWidget);
          expect(find.byIcon(Icons.restore_rounded), findsOneWidget);

          final button = tester.widget<IconButton>(buttonFinder);
          expect(button.onPressed, isNotNull);
          final style = button.style!;
          final enabled = style.foregroundColor!.resolve({});
          final disabled = style.foregroundColor!.resolve({
            WidgetState.disabled,
          });
          final hovered = style.overlayColor!.resolve({WidgetState.hovered});
          final focused = style.overlayColor!.resolve({WidgetState.focused});
          expect(enabled, isNotNull);
          expect(disabled, isNotNull);
          expect(hovered?.a, greaterThan(0));
          expect(focused?.a, greaterThan(0));

          final theme = Theme.of(tester.element(buttonFinder));
          expect(
            _contrast(enabled!, theme.colorScheme.surface),
            greaterThan(3),
          );

          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer();
          await mouse.moveTo(tester.getCenter(buttonFinder));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await mouse.removePointer();

          await tester.tap(buttonFinder);
          await tester.pumpAndSettle();
          expect(find.text('Schedule history'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.close).last);
          await tester.pumpAndSettle();
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}

double _contrast(Color first, Color second) {
  final light = first.computeLuminance();
  final dark = second.computeLuminance();
  final lighter = light > dark ? light : dark;
  final darker = light > dark ? dark : light;
  return (lighter + 0.05) / (darker + 0.05);
}
