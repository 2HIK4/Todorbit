import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/recurrence.dart';

void main() {
  List<String> dates(RecurrenceRule rule, String from, String through) =>
      rule.between(from, through).map((slot) => slot.nominalDate).toList();

  test('daily and weekly intervals preserve nominal dates across DST', () {
    final daily = RecurrenceRule(
      kind: RecurrenceKind.daily,
      startDate: '2026-03-07',
    );
    expect(dates(daily, '2026-03-08', '2026-03-10'), [
      '2026-03-08',
      '2026-03-09',
      '2026-03-10',
    ]);
    expect(daily.between('2026-03-08', '2026-03-08').single.ordinal, 1);

    final weekly = RecurrenceRule(
      kind: RecurrenceKind.weekly,
      startDate: '2026-03-08',
      interval: 2,
    );
    expect(dates(weekly, '2026-03-01', '2026-04-06'), [
      '2026-03-08',
      '2026-03-22',
      '2026-04-05',
    ]);
  });

  test('selected weekdays honor start date, week interval and count', () {
    final rule = RecurrenceRule(
      kind: RecurrenceKind.weekdays,
      startDate: '2026-10-14', // Wednesday
      interval: 2,
      weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      maxOccurrences: 5,
    );
    final slots = rule.between('2026-10-01', '2026-12-31');
    expect(slots.map((slot) => slot.nominalDate), [
      '2026-10-14',
      '2026-10-16',
      '2026-10-26',
      '2026-10-28',
      '2026-10-30',
    ]);
    expect(slots.map((slot) => slot.ordinal), [0, 1, 2, 3, 4]);
    expect(dates(rule, '2026-10-27', '2026-11-30'), [
      '2026-10-28',
      '2026-10-30',
    ]);
  });

  test('monthly and yearly recurrence clamp invalid anniversary days', () {
    final monthly = RecurrenceRule(
      kind: RecurrenceKind.monthly,
      startDate: '2024-01-31',
    );
    expect(dates(monthly, '2024-01-01', '2024-04-30'), [
      '2024-01-31',
      '2024-02-29',
      '2024-03-31',
      '2024-04-30',
    ]);
    final yearly = RecurrenceRule(
      kind: RecurrenceKind.yearly,
      startDate: '2024-02-29',
      endDate: '2028-02-28',
    );
    expect(dates(yearly, '2024-01-01', '2030-01-01'), [
      '2024-02-29',
      '2025-02-28',
      '2026-02-28',
      '2027-02-28',
    ]);
  });

  test('completion-based recurrence uses actual completion date', () {
    final rule = RecurrenceRule(
      kind: RecurrenceKind.afterCompletion,
      startDate: '2026-10-01',
      interval: 3,
    );
    expect(rule.nextAfterCompletion('2026-10-17'), '2026-10-20');
    expect(rule.between('2026-10-01', '2026-12-31'), isEmpty);
  });

  test('rejects invalid rules and dates', () {
    expect(
      () => RecurrenceRule(kind: RecurrenceKind.daily, startDate: '2026-02-30'),
      throwsArgumentError,
    );
    expect(
      () => RecurrenceRule(
        kind: RecurrenceKind.weekdays,
        startDate: '2026-01-01',
      ),
      throwsArgumentError,
    );
    expect(
      () => RecurrenceRule(
        kind: RecurrenceKind.weekdays,
        startDate: '2026-01-01',
        weekdays: {DateTime.monday},
      ),
      throwsArgumentError,
    );
    expect(
      () => RecurrenceRule(
        kind: RecurrenceKind.monthly,
        startDate: '2026-01-01',
        interval: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-01-01',
        maxOccurrences: 0,
      ),
      throwsArgumentError,
    );
  });

  test('selected weekday rule keeps an immutable snapshot', () {
    final chosen = {DateTime.monday};
    final rule = RecurrenceRule(
      kind: RecurrenceKind.weekdays,
      startDate: '2026-10-19',
      weekdays: chosen,
    );
    chosen.add(DateTime.friday);
    expect(dates(rule, '2026-10-19', '2026-10-25'), ['2026-10-19']);
    expect(() => rule.weekdays.add(DateTime.tuesday), throwsUnsupportedError);
  });
}
