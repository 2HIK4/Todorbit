import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/recurrence.dart';

void main() {
  group('Recurrence Invariants & Property-Based Tests', () {
    test('dates are strictly monotonic across ordinals for all recurrence kinds', () {
      final rules = [
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: '2026-01-01',
          interval: 3,
        ),
        RecurrenceRule(
          kind: RecurrenceKind.weekly,
          startDate: '2026-01-05',
          interval: 2,
        ),
        RecurrenceRule(
          kind: RecurrenceKind.weekdays,
          startDate: '2026-01-05', // Monday
          weekdays: {1, 3, 5}, // Mon, Wed, Fri
          interval: 1,
        ),
        RecurrenceRule(
          kind: RecurrenceKind.monthly,
          startDate: '2026-01-31',
          interval: 1,
        ),
        RecurrenceRule(
          kind: RecurrenceKind.yearly,
          startDate: '2024-02-29', // Leap year
          interval: 1,
        ),
      ];

      for (final rule in rules) {
        String? previousDate;
        for (var i = 0; i < 24; i++) {
          final currentDate = rule.slotDateAtOrdinal(i);
          if (previousDate != null) {
            expect(
              currentDate.compareTo(previousDate) > 0,
              isTrue,
              reason: 'Rule ${rule.kind} violated monotonicity at ordinal $i: $currentDate <= $previousDate',
            );
          }
          previousDate = currentDate;
        }
      }
    });

    test('monthly recurrence on 31st clamps correctly to month boundaries', () {
      final rule = RecurrenceRule(
        kind: RecurrenceKind.monthly,
        startDate: '2026-01-31',
        interval: 1,
      );

      final expected = [
        '2026-01-31',
        '2026-02-28', // Non-leap year Feb
        '2026-03-31',
        '2026-04-30', // April has 30 days
        '2026-05-31',
        '2026-06-30', // June has 30 days
        '2026-07-31',
        '2026-08-31',
        '2026-09-30', // Sept has 30 days
        '2026-10-31',
        '2026-11-30', // Nov has 30 days
        '2026-12-31',
      ];

      for (var i = 0; i < expected.length; i++) {
        expect(rule.slotDateAtOrdinal(i), expected[i]);
      }
    });

    test('yearly recurrence starting on Feb 29 clamps on non-leap years and preserves Feb 29 on leap years', () {
      final rule = RecurrenceRule(
        kind: RecurrenceKind.yearly,
        startDate: '2024-02-29',
        interval: 1,
      );

      expect(rule.slotDateAtOrdinal(0), '2024-02-29'); // Leap year
      expect(rule.slotDateAtOrdinal(1), '2025-02-28'); // Non-leap year
      expect(rule.slotDateAtOrdinal(2), '2026-02-28'); // Non-leap year
      expect(rule.slotDateAtOrdinal(3), '2027-02-28'); // Non-leap year
      expect(rule.slotDateAtOrdinal(4), '2028-02-29'); // Leap year
    });

    test('between query results match slotDateAtOrdinal and lie strictly in date window', () {
      final rule = RecurrenceRule(
        kind: RecurrenceKind.weekdays,
        startDate: '2026-03-02', // Monday
        weekdays: {1, 3, 5}, // Mon, Wed, Fri
        interval: 1,
      );

      final slots = rule.between('2026-03-10', '2026-03-25');
      expect(slots, isNotEmpty);

      for (final slot in slots) {
        expect(slot.nominalDate.compareTo('2026-03-10') >= 0, isTrue);
        expect(slot.nominalDate.compareTo('2026-03-25') <= 0, isTrue);
        expect(rule.slotDateAtOrdinal(slot.ordinal), slot.nominalDate);
      }
    });

    test('maxOccurrences and endDate constraints are strictly enforced', () {
      final ruleWithMax = RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-06-01',
        maxOccurrences: 5,
      );
      final slotsMax = ruleWithMax.between('2026-06-01', '2026-12-31');
      expect(slotsMax.length, 5);
      expect(slotsMax.last.nominalDate, '2026-06-05');

      final ruleWithEnd = RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-06-01',
        endDate: '2026-06-04',
      );
      final slotsEnd = ruleWithEnd.between('2026-06-01', '2026-12-31');
      expect(slotsEnd.length, 4);
      expect(slotsEnd.last.nominalDate, '2026-06-04');
    });

    test('afterCompletion recurrence advances strictly by interval days', () {
      final rule = RecurrenceRule(
        kind: RecurrenceKind.afterCompletion,
        startDate: '2026-05-01',
        interval: 7,
      );

      expect(rule.nextAfterCompletion('2026-05-10'), '2026-05-17');
      expect(rule.nextAfterCompletion('2026-05-31'), '2026-06-07');
    });
  });
}
