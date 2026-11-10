import 'calendar_view.dart';
import 'calendar_config.dart';

/// Manages zoom transitions (Month <-> Week <-> Day) and date-anchored navigation.
class CalendarZoomController {
  CalendarZoomController({
    this.config = const CalendarAppearanceConfiguration(),
  });

  CalendarAppearanceConfiguration config;
  double _accumulatedDelta = 0.0;
  DateTime? _lastScrollTime;

  /// Resolves the next calendar mode when zooming in (towards Day view).
  CalendarMode? zoomIn(CalendarMode current) {
    return switch (current) {
      CalendarMode.month => CalendarMode.week,
      CalendarMode.week => CalendarMode.day,
      CalendarMode.day => null,
    };
  }

  /// Resolves the next calendar mode when zooming out (towards Month view).
  CalendarMode? zoomOut(CalendarMode current) {
    return switch (current) {
      CalendarMode.day => CalendarMode.week,
      CalendarMode.week => CalendarMode.month,
      CalendarMode.month => null,
    };
  }

  /// Handles a scroll wheel or trackpad delta when Ctrl is held.
  ///
  /// Returns the target [CalendarMode] if threshold was crossed, or null.
  CalendarMode? handlePointerScroll({
    required double scrollDeltaY,
    required CalendarMode currentMode,
    required bool isControlPressed,
  }) {
    if (!config.enableZoom || !isControlPressed) return null;

    final now = DateTime.now();
    if (_lastScrollTime != null &&
        now.difference(_lastScrollTime!).inMilliseconds > 300) {
      _accumulatedDelta = 0.0;
    }
    _lastScrollTime = now;

    _accumulatedDelta += scrollDeltaY;

    if (_accumulatedDelta <= -config.zoomThreshold) {
      // Scrolled UP (negative in Flutter PointerScrollEvent) -> Zoom IN
      _accumulatedDelta = 0.0;
      return zoomIn(currentMode);
    } else if (_accumulatedDelta >= config.zoomThreshold) {
      // Scrolled DOWN -> Zoom OUT
      _accumulatedDelta = 0.0;
      return zoomOut(currentMode);
    }

    return null;
  }

  /// Resolves the anchor date in Week view from the horizontal pointer position.
  DateTime resolveWeekAnchorDate({
    required double localX,
    required double totalWidth,
    required DateTime weekStart,
  }) {
    if (totalWidth <= 0) return weekStart;
    final columnWidth = totalWidth / 7.0;
    final columnIndex = (localX / columnWidth).floor().clamp(0, 6);
    return DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + columnIndex,
    );
  }

  /// Resolves the anchor date in Month view from the pointer position.
  DateTime resolveMonthAnchorDate({
    required double localX,
    required double localY,
    required double gridWidth,
    required double gridHeight,
    required DateTime monthDate,
    required int firstWeekday,
  }) {
    if (gridWidth <= 0 || gridHeight <= 0) return monthDate;

    final first = DateTime(monthDate.year, monthDate.month, 1);
    final offset = (first.weekday - firstWeekday + 7) % 7;
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final cellCount = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final rowCount = cellCount ~/ 7;

    final cellWidth = gridWidth / 7.0;
    final cellHeight = gridHeight / rowCount;

    final col = (localX / cellWidth).floor().clamp(0, 6);
    final row = (localY / cellHeight).floor().clamp(0, rowCount - 1);
    final cellIndex = row * 7 + col;

    final targetDate = DateTime(
      first.year,
      first.month,
      first.day + cellIndex - offset,
    );
    return targetDate;
  }
}
