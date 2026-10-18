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
