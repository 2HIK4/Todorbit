import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_interaction_controller.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/timeline_grid.dart';

void main() {
  const config = CalendarAppearanceConfiguration(hourHeight: 60);
  final day = DateTime(2026, 11, 10);

  test('continuation moves earlier within its day and across day columns', () {
    for (final target in [day, DateTime(2026, 11, 11)]) {
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      interaction.startMove(
        item: CalendarItem(
          id: 'earlier',
          title: 'Overnight',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 9, 23),
          endsAt: DateTime(2026, 11, 10, 5),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 120),
        pointerTimelineY: 120,
      );
      interaction.updatePointer(const Offset(10, 60), target, 60);
      expect(
        interaction.proposedStartsAt,
        DateTime(target.year, target.month, target.day - 1, 22),
      );
      expect(
        interaction.proposedEndsAt,
        DateTime(target.year, target.month, target.day, 4),
      );
    }
  });

  test('bottom resize retains minimum duration at midnight', () {
    final interaction = CalendarInteractionController(config: config);
    addTearDown(interaction.dispose);
    interaction.startResizeBottom(
      item: CalendarItem(
        id: 'late',
        title: 'Late',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 10, 23, 45),
        endsAt: DateTime(2026, 11, 11),
      ),
      dayDate: day,
      pointerLocal: const Offset(10, 1440),
    );
    interaction.updatePointer(const Offset(10, 1420), day);
    expect(interaction.proposedEndsAt, DateTime(2026, 11, 11));
    expect(
      interaction.proposedEndsAt!.difference(interaction.proposedStartsAt!),
      const Duration(minutes: 15),
    );
  });

  test(
    'moving a continuation shifts the original start by the pointer delta',
    () {
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      interaction.startMove(
        item: CalendarItem(
          id: 'overnight',
          title: 'Overnight',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 9, 23),
          endsAt: DateTime(2026, 11, 10, 5),
        ),
        dayDate: day,
        pointerLocal: const Offset(10, 120),
        pointerTimelineY: 120,
      );
      interaction.updatePointer(const Offset(10, 180), day, 180);
      expect(interaction.proposedStartsAt, DateTime(2026, 11, 10));
      expect(interaction.proposedEndsAt, DateTime(2026, 11, 10, 6));
    },
  );

  testWidgets(
    'clipped segments expose handles only at actual event boundaries',
    (tester) async {
      final interaction = CalendarInteractionController(config: config);
      addTearDown(interaction.dispose);
      final item = CalendarItem(
        id: 'multi',
        title: 'Multi-day',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 9, 23),
        endsAt: DateTime(2026, 11, 11, 5),
      );
      for (final entry in [(9, 1, 0), (10, 0, 0), (11, 0, 1)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TimelineDayColumn(
                  dayDate: DateTime(2026, 11, entry.$1),
                  items: [item],
                  config: config,
                  interactionController: interaction,
                  onItemTap: (_) {},
                  onSlotSecondaryTap: (_, _) {},
                ),
              ),
            ),
          ),
        );
        expect(
          find.byTooltip('Drag to adjust start time'),
          findsNWidgets(entry.$2),
        );
        expect(
          find.byTooltip('Drag to adjust end time'),
          findsNWidgets(entry.$3),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
