/// Pure Dart contracts for calendar presentation and layout.
///
/// This file has no dependencies on Flutter widgets, controllers,
/// persistence, or the calendar root view.
library;

/// The display modes available in the calendar.
enum CalendarMode { day, week, month }

/// Calculates the maximum number of event/task entries that fit in a month view cell.
///
/// [cellHeight] is the total height available for the day cell.
/// [textScale] scales the assumed row height (clamped between 1.0 and 2.0).
/// The result is clamped to between 0 and 30 items.
int monthEntryCapacity(double cellHeight, double textScale) {
  final rowHeight = 32.0 * textScale.clamp(1.0, 2.0);
  return ((cellHeight - 34) / rowHeight).floor().clamp(0, 30);
}
