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
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/shared/anchored_select_field.dart';
import 'package:life_manager/features/shared/checklist_entry.dart';

void main() {
  testWidgets('custom action backgrounds retain readable foregrounds', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(database));
    await controller.refresh();
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
      for (final color in [
        Colors.white,
        Colors.black,
        Colors.yellow,
        const Color(0xFF777777),
        ThemePalette.light['accent'],
        ThemePalette.dark['accent'],
      ]) {
        await controller.saveCustomization(
          controller.customization.copyWith(
            light: ThemePalette.light
                .withColor('accent', color)
                .withColor('error', color),
            dark: ThemePalette.dark
                .withColor('accent', color)
                .withColor('error', color),
          ),
        );
        await tester.pumpAndSettle();
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        for (final theme in [app.theme!, app.darkTheme!]) {
          final scheme = theme.colorScheme;
          for (final pair in [
            (scheme.primary, scheme.onPrimary),
            (scheme.error, scheme.onError),
          ]) {
            final a = pair.$1.computeLuminance();
            final b = pair.$2.computeLuminance();
            final contrast = a > b
                ? (a + .05) / (b + .05)
                : (b + .05) / (a + .05);
            expect(contrast, greaterThanOrEqualTo(4.5));
            expect(pair.$1, color);
          }
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    }
  });

  testWidgets('new and edit forms clear headings and expanded section labels', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(database);
    final saved = await repo.addTask(
      const TaskDraft(title: 'Saved layout task'),
    );
    final controller = AppController(repo);
    await controller.refresh();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith((ref) => controller),
        privacyOverride,
      ],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LifeManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      for (final theme in [app.theme!, app.darkTheme!]) {
        for (final width in [380.0, 740.0]) {
          for (final task in <LifeTask?>[null, saved]) {
            await tester.binding.setSurfaceSize(Size(width, 700));
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: TaskEditor(key: UniqueKey(), task: task),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final entry = find.byType(ChecklistEntry);
            await tester.scrollUntilVisible(
              entry,
              180,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            final field = find.descendant(
              of: entry,
              matching: find.byType(TextField),
            );
            final heading = find.textContaining('Checklist').first;
            expect(
              tester.getRect(field).top - tester.getRect(heading).bottom,
              greaterThanOrEqualTo(12),
            );
            final add = find.descendant(
              of: entry,
              matching: find.byType(IconButton),
            );
            expect(tester.getRect(add).left - tester.getRect(field).right, 8);
            for (final text in [
              '',
              'A long checklist item that remains editable in a narrow form',
            ]) {
              await tester.enterText(field, text);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            FocusManager.instance.primaryFocus?.unfocus();
            final section = find.widgetWithText(
              ExpansionTile,
              'Status and priority',
            );
            await tester.ensureVisible(section);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Status and priority'));
            await tester.pumpAndSettle();
            final status = find.widgetWithText(
              AnchoredSelectField<TaskStatus>,
              'Status',
            );
            await tester.ensureVisible(status);
            await tester.pumpAndSettle();
            final subtitle = tester.getRect(
              find.text('Optional for a new task'),
            );
            expect(
              tester.getRect(status).top - subtitle.bottom,
              greaterThanOrEqualTo(12),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

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
