import 'dart:io';

import 'test_privacy.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets(
    'task input keeps themed border and visible bounds in both modes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(database));
      await controller.refresh();
      controller.theme = ThemeModePreference.light;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
              privacyOverride,
            ],
            child: const LifeManagerApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('All tasks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New task'));
        await tester.pumpAndSettle();
        for (final mode in [
          ThemeModePreference.light,
          ThemeModePreference.dark,
        ]) {
          if (mode == ThemeModePreference.dark) {
            await controller.setTheme(mode);
            await tester.pumpAndSettle();
          }
          final input = find.widgetWithText(TextField, 'Title *');
          expect(input, findsOneWidget);
          final theme = Theme.of(tester.element(input));
          final palette = mode == ThemeModePreference.light
              ? ThemePalette.light
              : ThemePalette.dark;
          expect(theme.colorScheme.primary, palette['accent']);
          expect(theme.colorScheme.onSurface, palette['primaryText']);
          final focused =
              theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
          expect(focused.borderSide.color, palette['accent']);
          final rect = tester.getRect(input);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(1280));
          expect(rect.bottom, lessThanOrEqualTo(800));
          expect(tester.takeException(), isNull);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('native caption receives light and dark app theme colors', (
    tester,
  ) async {
    if (!Platform.isWindows) return;
    const channel = MethodChannel('life_manager/window_theme');
    final calls = <List<String>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'set') {
        calls.add((call.arguments as List<dynamic>).cast<String>());
      }
      return null;
    });
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
    controller.theme = ThemeModePreference.light;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.last[0], 'light');
      expect(calls.last[1], hasLength(6));
      await controller.setTheme(ThemeModePreference.dark);
      await tester.pumpAndSettle();
      expect(calls.last[0], 'dark');
      expect(calls.last[1], hasLength(6));
      expect(calls.last[1], isNot(calls.first[1]));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await database.close();
    }
  });
}
