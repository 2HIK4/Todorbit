import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/calendar/calendar_config.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/calendar_zoom_controller.dart';

void main() {
  const config = CalendarAppearanceConfiguration(zoomThreshold: 100.0);
  final controller = CalendarZoomController(config: config);

  group('CalendarZoomController transitions', () {
    test('zoomIn transitions Month -> Week -> Day', () {
      expect(controller.zoomIn(CalendarMode.month), CalendarMode.week);
      expect(controller.zoomIn(CalendarMode.week), CalendarMode.day);
      expect(controller.zoomIn(CalendarMode.day), isNull);
    });

    test('zoomOut transitions Day -> Week -> Month', () {
      expect(controller.zoomOut(CalendarMode.day), CalendarMode.week);
      expect(controller.zoomOut(CalendarMode.week), CalendarMode.month);
      expect(controller.zoomOut(CalendarMode.month), isNull);
    });

    test('requires Ctrl held and accumulates delta to threshold', () {
      // Without Ctrl: returns null
      expect(
        controller.handlePointerScroll(
          scrollDeltaY: -150.0,
          currentMode: CalendarMode.month,
          isControlPressed: false,
        ),
        isNull,
      );

      // With Ctrl: partial scroll below threshold returns null
      expect(
        controller.handlePointerScroll(
          scrollDeltaY: -60.0,
          currentMode: CalendarMode.month,
          isControlPressed: true,
        ),
        isNull,
      );

      // Accumulating past -100 threshold triggers zoomIn
      expect(
        controller.handlePointerScroll(
          scrollDeltaY: -50.0,
          currentMode: CalendarMode.month,
          isControlPressed: true,
        ),
        CalendarMode.week,
      );
    });
  });

  group('CalendarZoomController anchor date resolution', () {
    test('resolves week column date under pointer', () {
      final weekStart = DateTime(2026, 11, 9); // Monday
      // 700 px total width -> 100 px per column. Pointer at x=250 is column index 2 (Wednesday Nov 11)
      final anchor = controller.resolveWeekAnchorDate(
        localX: 250.0,
        totalWidth: 700.0,
        weekStart: weekStart,
      );
      expect(anchor.day, 11);
    });

    test('resolves month cell date under pointer', () {
      final month = DateTime(2026, 11, 1);
      // November 2026: Nov 1 is Sunday. If firstWeekday is Monday (1), offset = 6.
      // Grid width 700, height 500, row count ~ 6
      final anchor = controller.resolveMonthAnchorDate(
        localX: 350.0, // column 3 (Thursday)
        localY: 150.0, // row 1
        gridWidth: 700.0,
        gridHeight: 500.0,
        monthDate: month,
        firstWeekday: 1, // Monday
      );
      expect(anchor.month, 11);
    });
  });
}
