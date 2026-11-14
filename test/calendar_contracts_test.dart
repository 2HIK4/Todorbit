import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/calendar/calendar_contracts.dart';
import 'package:life_manager/features/calendar/calendar_view.dart'
    as calendar_view;

void main() {
  group('CalendarMode contract', () {
    test('declares expected enum members in stable order', () {
      expect(CalendarMode.values, const [
        CalendarMode.day,
        CalendarMode.week,
        CalendarMode.month,
      ]);
      expect(CalendarMode.values.length, 3);
      expect(CalendarMode.day.index, 0);
      expect(CalendarMode.week.index, 1);
      expect(CalendarMode.month.index, 2);
    });

    test('preserves string serialization names', () {
      expect(CalendarMode.day.name, 'day');
      expect(CalendarMode.week.name, 'week');
      expect(CalendarMode.month.name, 'month');

      expect(CalendarMode.values.byName('day'), CalendarMode.day);
      expect(CalendarMode.values.byName('week'), CalendarMode.week);
      expect(CalendarMode.values.byName('month'), CalendarMode.month);
      expect(() => CalendarMode.values.byName('year'), throwsArgumentError);
    });

    test(
      'is re-exported identically by calendar_view for backwards compatibility',
      () {
        expect(
          identical(CalendarMode.day, calendar_view.CalendarMode.day),
          isTrue,
        );
        expect(
          identical(CalendarMode.week, calendar_view.CalendarMode.week),
          isTrue,
        );
        expect(
          identical(CalendarMode.month, calendar_view.CalendarMode.month),
          isTrue,
        );
      },
    );
  });

  group('monthEntryCapacity calculation', () {
    test('matches round3 baseline behavior', () {
      expect(monthEntryCapacity(95, 1), lessThan(monthEntryCapacity(190, 1)));
      expect(monthEntryCapacity(190, 2), lessThan(monthEntryCapacity(190, 1)));
      expect(monthEntryCapacity(45, 1), 0);
    });

    test('calculates exact step boundaries at standard textScale 1.0', () {
      // rowHeight = 32.0
      // cellHeight <= 34 yields 0
      expect(monthEntryCapacity(0, 1.0), 0);
      expect(monthEntryCapacity(34.0, 1.0), 0);
      expect(monthEntryCapacity(65.9, 1.0), 0);
      // exactly 1 row available: 34 + 32 = 66
      expect(monthEntryCapacity(66.0, 1.0), 1);
      expect(monthEntryCapacity(97.9, 1.0), 1);
      // exactly 2 rows available: 34 + 64 = 98
      expect(monthEntryCapacity(98.0, 1.0), 2);
      // 190 -> (190 - 34) / 32 = 156 / 32 = 4.875 -> 4
      expect(monthEntryCapacity(190.0, 1.0), 4);
    });

    test('clamps textScale between 1.0 and 2.0', () {
      // Below 1.0 is clamped to 1.0 (rowHeight 32.0)
      expect(monthEntryCapacity(98.0, 0.5), monthEntryCapacity(98.0, 1.0));
      expect(monthEntryCapacity(98.0, 0.9), monthEntryCapacity(98.0, 1.0));

      // Above 2.0 is clamped to 2.0 (rowHeight 64.0)
      expect(monthEntryCapacity(190.0, 2.5), monthEntryCapacity(190.0, 2.0));
      expect(monthEntryCapacity(190.0, 3.0), monthEntryCapacity(190.0, 2.0));

      // At scale 2.0, (190 - 34) / 64 = 156 / 64 = 2.4375 -> 2
      expect(monthEntryCapacity(190.0, 2.0), 2);
    });

    test('clamps result between 0 and 30 items', () {
      // Negative / zero / tiny cell heights clamp to 0
      expect(monthEntryCapacity(-100.0, 1.0), 0);
      expect(monthEntryCapacity(10.0, 1.0), 0);

      // Huge cell height (e.g. 2000px) clamps to maximum 30 entries
      expect(monthEntryCapacity(2000.0, 1.0), 30);
      expect(monthEntryCapacity(5000.0, 1.0), 30);
    });

    test(
      'is re-exported identically by calendar_view for backwards compatibility',
      () {
        expect(
          calendar_view.monthEntryCapacity(190.0, 1.0),
          monthEntryCapacity(190.0, 1.0),
        );
        expect(
          calendar_view.monthEntryCapacity(45.0, 1.0),
          monthEntryCapacity(45.0, 1.0),
        );
      },
    );
  });
}
