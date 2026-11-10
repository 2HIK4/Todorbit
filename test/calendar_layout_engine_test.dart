import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_layout_engine.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';

void main() {
  const config = CalendarAppearanceConfiguration(
    hourHeight: 60.0,
    snapMinutes: 15,
    minItemHeight: 24.0,
    startHour: 0,
    endHour: 24,
  );
  const engine = CalendarLayoutEngine(config: config);
  final day = DateTime(2026, 11, 10);

  group('CalendarLayoutEngine coordinate conversion', () {
    test('timeToY converts hours and minutes to pixel offset', () {
      expect(engine.timeToY(DateTime(2026, 11, 10, 0, 0)), 0.0);
      expect(engine.timeToY(DateTime(2026, 11, 10, 1, 0)), 60.0);
      expect(engine.timeToY(DateTime(2026, 11, 10, 10, 30)), 630.0);
      expect(engine.timeToY(DateTime(2026, 11, 11, 0, 0), day), 1440.0);
    });

    test('yToTime converts pixel offset to snapped DateTime', () {
      // 630 px = 10.5h = 10:30
      final t1 = engine.yToTime(630.0, day);
      expect(t1.hour, 10);
      expect(t1.minute, 30);

      // 637 px ~ 10:37 -> snaps to 10:30 or 10:45 (10.616h -> 37m -> snaps to 30 or 45: 37/15=2.46 -> 30)
      final t2 = engine.yToTime(637.0, day);
      expect(t2.hour, 10);
      expect(t2.minute, 30);

      // 640 px ~ 10:40 -> snaps to 10:45 (40/15=2.67 -> 3 -> 45)
      final t3 = engine.yToTime(640.0, day);
      expect(t3.hour, 10);
      expect(t3.minute, 45);
    });
  });

  group('CalendarLayoutEngine overlap and lane layout', () {
    test('sequential items touching endpoints do not collide and use full width', () {
      final items = [
        CalendarItem(
          id: '1',
          title: 'Morning Meeting',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
        CalendarItem(
          id: '2',
          title: 'Lunch Prep',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 11, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
      ];

      final placements = engine.computePlacements(items, day);
      expect(placements.length, 2);

      // Neither has conflict
      expect(placements[0].hasConflict, isFalse);
      expect(placements[1].hasConflict, isFalse);

      // Both get full width (1.0) and lane 0
      expect(placements[0].lane, 0);
      expect(placements[0].totalLanes, 1);
      expect(placements[0].widthFraction, 1.0);

      expect(placements[1].lane, 0);
      expect(placements[1].totalLanes, 1);
      expect(placements[1].widthFraction, 1.0);
    });

    test('partial overlaps allocate 2 side-by-side lanes', () {
      final items = [
        CalendarItem(
          id: '1',
          title: 'A',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
        CalendarItem(
          id: '2',
          title: 'B',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 10, 30),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
      ];

      final placements = engine.computePlacements(items, day);
      expect(placements.length, 2);

      expect(placements[0].hasConflict, isTrue);
      expect(placements[1].hasConflict, isTrue);

      expect(placements[0].totalLanes, 2);
      expect(placements[1].totalLanes, 2);

      expect(placements[0].lane, 0);
      expect(placements[0].leftFraction, 0.0);
      expect(placements[0].widthFraction, 0.5);

      expect(placements[1].lane, 1);
      expect(placements[1].leftFraction, 0.5);
      expect(placements[1].widthFraction, 0.5);
    });

    test('nested overlaps allocate 2 lanes correctly', () {
      final items = [
        CalendarItem(
          id: 'long',
          title: 'Long Event',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 13, 0),
        ),
        CalendarItem(
          id: 'nested',
          title: 'Nested Event',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 11, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
      ];

      final placements = engine.computePlacements(items, day);
      expect(placements.length, 2);
      expect(placements[0].lane, 0);
      expect(placements[1].lane, 1);
      expect(placements[0].totalLanes, 2);
      expect(placements[1].totalLanes, 2);
    });

    test('re-uses lanes when previous item in lane has ended', () {
      // A: 10:00 - 11:00 (Lane 0)
      // B: 10:30 - 12:00 (Lane 1)
      // C: 11:00 - 12:00 (Lane 0, fits after A)
      final items = [
        CalendarItem(
          id: 'A',
          title: 'A',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 10, 0),
          endsAt: DateTime(2026, 11, 10, 11, 0),
        ),
        CalendarItem(
          id: 'B',
          title: 'B',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 10, 30),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
        CalendarItem(
          id: 'C',
          title: 'C',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 11, 0),
          endsAt: DateTime(2026, 11, 10, 12, 0),
        ),
      ];

      final placements = engine.computePlacements(items, day);
      expect(placements.length, 3);

      final pA = placements.firstWhere((p) => p.item.id == 'A');
      final pB = placements.firstWhere((p) => p.item.id == 'B');
      final pC = placements.firstWhere((p) => p.item.id == 'C');

      expect(pA.lane, 0);
      expect(pB.lane, 1);
      expect(pC.lane, 0); // Re-uses lane 0

      expect(pA.totalLanes, 2);
      expect(pB.totalLanes, 2);
      expect(pC.totalLanes, 2);
    });

    test('dense collision handles 5 simultaneous items', () {
      final items = List.generate(5, (i) => CalendarItem(
        id: 'dense_$i',
        title: 'Collision $i',
        kind: CalendarItemKind.event,
        startsAt: DateTime(2026, 11, 10, 14, 0),
        endsAt: DateTime(2026, 11, 10, 15, 0),
      ));

      final placements = engine.computePlacements(items, day);
      expect(placements.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(placements[i].totalLanes, 5);
        expect(placements[i].widthFraction, closeTo(0.2, 0.001));
      }
    });

    test('short items enforce minimum readable height', () {
      final items = [
        CalendarItem(
          id: 'quick',
          title: '5-minute sync',
          kind: CalendarItemKind.event,
          startsAt: DateTime(2026, 11, 10, 9, 0),
          endsAt: DateTime(2026, 11, 10, 9, 5),
        ),
      ];

      final placements = engine.computePlacements(items, day);
      expect(placements.length, 1);
      // Raw height for 5 mins would be 5.0 px; minItemHeight is 24.0
      expect(placements.first.height, 24.0);
    });
  });
}
