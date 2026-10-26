import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'cancelled events stay readable and distinct in ${brightness.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final date = DateTime.now();
        final start = DateTime(date.year, date.month, date.day, 9);
        await repo.addEvent(
          EventDraft(
            title: 'Cancelled lecture',
            startsAt: start,
            endsAt: start.add(const Duration(hours: 1)),
            repeat: const EventRepeat(kind: EventRepeatKind.daily),
          ),
        );
        final event = (await repo.eventOccurrences(
          localDate(date),
          localDate(date),
        )).single;
        await repo.setEventOccurrenceCancelled(event, true);
        final controller = AppController(repo);
        await controller.refresh();
        final palette = brightness == Brightness.dark
            ? ThemePalette.dark
            : ThemePalette.light;
        final scheme =
            ColorScheme.fromSeed(
              seedColor: palette['accent'],
              brightness: brightness,
            ).copyWith(
              surface: palette['surface'],
              onSurface: palette['primaryText'],
              onSurfaceVariant: palette['secondaryText'],
            );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith((_) => controller),
              ],
              child: MaterialApp(
                theme: ThemeData(colorScheme: scheme),
                home: Scaffold(
                  body: CalendarView(
                    onTaskTap: (_) {},
                    onSmartReschedule: () {},
                    onAddTask: (_) {},
                  ),
                ),
              ),
            ),
          );
          for (final mode in ['Month', 'Day']) {
            await tester.tap(find.text(mode));
            await tester.pumpAndSettle();
            final title = tester
                .widgetList<Text>(find.text('Cancelled lecture'))
                .firstWhere(
                  (text) =>
                      text.style?.decoration == TextDecoration.lineThrough,
                );
            final ink = title.style!.color!;
            final background = scheme.surface;
            final contrast =
                (math.max(
                      ink.computeLuminance(),
                      background.computeLuminance(),
                    ) +
                    0.05) /
                (math.min(
                      ink.computeLuminance(),
                      background.computeLuminance(),
                    ) +
                    0.05);
            expect(contrast, greaterThanOrEqualTo(4.5));
            expect(ink, isNot(scheme.onSurfaceVariant));
            expect(tester.takeException(), isNull);
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await db.close();
        }
      },
    );
  }
}
