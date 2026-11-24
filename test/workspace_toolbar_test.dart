import 'test_privacy.dart';

import 'dart:ui' show PointerDeviceKind;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/shared/task_date_label.dart';
import 'package:life_manager/main.dart';

void main() {
  testWidgets('Upcoming day context removes only matching planned labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final controller = AppController(repository);
    final next = DateTime.now().add(const Duration(days: 1));
    final date = localDate(next);
    await repository.addTask(
      TaskDraft(
        title: 'First handoff',
        scheduledDate: date,
        deadlineDate: date,
      ),
    );
    await repository.addTask(
      TaskDraft(title: 'Second handoff', scheduledDate: date),
    );
    await controller.refresh();
    controller.navigate(WorkspaceView.upcoming);
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
      final first = find.text('First handoff');
      final second = find.text('Second handoff');
      final context = tester.element(first);
      final label = 'Planned ${taskDateLabel(context, date)}';
      final due = 'Due ${taskDateLabel(context, date)}';
      final heading = MaterialLocalizations.of(context).formatFullDate(next);
      expect(find.text(heading), findsOneWidget);
      expect(find.text(label), findsNothing);
      expect(find.text(due), findsOneWidget);
      expect(tester.widget<Text>(first).semanticsLabel, contains(label));
      expect(tester.widget<Text>(second).semanticsLabel, contains(label));

      controller.setSort(TaskSort.title);
      await tester.pumpAndSettle();
      expect(find.text(heading), findsNothing);
      expect(find.text(label), findsNWidgets(2));
      expect(find.text(due), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

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
                privacyOverride,
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
          final info = find.byKey(const ValueKey('view-info-button'));
          expect(info, findsOneWidget);
          await tester.tap(info);
          await tester.pumpAndSettle();
          final description = find.textContaining(
            'Tasks planned for today. Deadlines',
          );
          expect(description, findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(description, findsNothing);

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
