import 'package:flutter/foundation.dart';

/// Centralized configuration for interactive calendar appearance and behavior.
///
/// Every parameter is documented so future revisions (e.g. changing row height,
/// snapping interval, resizing sensitivity, or overlap spacing) can be made
/// in a single targeted place.
@immutable
class CalendarAppearanceConfiguration {
  const CalendarAppearanceConfiguration({
    this.hourHeight = 60.0,
    this.snapMinutes = 15,
    this.minItemDurationMinutes = 15,
    this.minItemHeight = 24.0,
    this.minItemWidth = 50.0,
    this.overlapSpacing = 2.0,
    this.dragThreshold = 4.0,
    this.resizeHandleHeight = 10.0,
    this.touchHandleHitTarget = 24.0,
    this.autoScrollMargin = 48.0,
    this.autoScrollSpeed = 12.0,
    this.startHour = 0,
    this.endHour = 24,
    this.initialScrollHour = 7,
    this.zoomThreshold = 120.0,
    this.enableDragMove = true,
    this.enableResize = true,
    this.enableZoom = true,
    this.enableCrossDayMove = true,
    this.useLegacyCalendar = false,
  });

  /// Height in pixels for a single hour row in the timeline grid.
  final double hourHeight;

  /// Time snapping interval in minutes for moving and resizing (default: 15 min).
  final int snapMinutes;

  /// Minimum allowable duration in minutes when resizing an item.
  final int minItemDurationMinutes;

  /// Minimum vertical height in pixels for rendered items so very short events remain readable.
  final double minItemHeight;

  /// Minimum width in pixels for overlapping lane items before overflow handling applies.
  final double minItemWidth;

  /// Horizontal gap in pixels between side-by-side overlapping lanes.
  final double overlapSpacing;

  /// Pointer movement threshold in pixels to distinguish clicking from dragging.
  final double dragThreshold;

  /// Height of the top and bottom edge resize handles on desktop.
  final double resizeHandleHeight;

  /// Height/hit-target of resize handles on touch/mobile devices.
  final double touchHandleHitTarget;

  /// Distance from viewport edge in pixels to trigger auto-scrolling during drag.
  final double autoScrollMargin;

  /// Auto-scroll step speed in pixels per frame tick.
  final double autoScrollSpeed;

  /// Start hour of the timeline grid (0-23, default: 0 for full day).
  final int startHour;

  /// End hour of the timeline grid (1-24, default: 24 for full day).
  final int endHour;

  /// Initial hour to scroll into view when timeline is first mounted (e.g. 7 AM).
  final int initialScrollHour;

  /// Accumulated mouse-wheel / trackpad delta needed to trigger a view zoom transition.
  final double zoomThreshold;

  /// Whether moving items via center drag is enabled.
  final bool enableDragMove;

  /// Whether resizing items via edge drag is enabled.
  final bool enableResize;

  /// Whether date-anchored zoom (Ctrl+wheel / pinch) is enabled.
  final bool enableZoom;

  /// Whether dragging across day columns in Week view is enabled.
  final bool enableCrossDayMove;

  /// Temporary fallback switch to display the legacy calendar implementation.
  final bool useLegacyCalendar;

  int get totalHours => endHour - startHour;
  double get totalGridHeight => totalHours * hourHeight;

  CalendarAppearanceConfiguration copyWith({
    double? hourHeight,
    int? snapMinutes,
    int? minItemDurationMinutes,
    double? minItemHeight,
    double? minItemWidth,
    double? overlapSpacing,
    double? dragThreshold,
    double? resizeHandleHeight,
    double? touchHandleHitTarget,
    double? autoScrollMargin,
    double? autoScrollSpeed,
    int? startHour,
    int? endHour,
    int? initialScrollHour,
    double? zoomThreshold,
    bool? enableDragMove,
    bool? enableResize,
    bool? enableZoom,
    bool? enableCrossDayMove,
    bool? useLegacyCalendar,
  }) {
    return CalendarAppearanceConfiguration(
      hourHeight: hourHeight ?? this.hourHeight,
      snapMinutes: snapMinutes ?? this.snapMinutes,
      minItemDurationMinutes: minItemDurationMinutes ?? this.minItemDurationMinutes,
      minItemHeight: minItemHeight ?? this.minItemHeight,
      minItemWidth: minItemWidth ?? this.minItemWidth,
      overlapSpacing: overlapSpacing ?? this.overlapSpacing,
      dragThreshold: dragThreshold ?? this.dragThreshold,
      resizeHandleHeight: resizeHandleHeight ?? this.resizeHandleHeight,
      touchHandleHitTarget: touchHandleHitTarget ?? this.touchHandleHitTarget,
      autoScrollMargin: autoScrollMargin ?? this.autoScrollMargin,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      initialScrollHour: initialScrollHour ?? this.initialScrollHour,
      zoomThreshold: zoomThreshold ?? this.zoomThreshold,
      enableDragMove: enableDragMove ?? this.enableDragMove,
      enableResize: enableResize ?? this.enableResize,
      enableZoom: enableZoom ?? this.enableZoom,
      enableCrossDayMove: enableCrossDayMove ?? this.enableCrossDayMove,
      useLegacyCalendar: useLegacyCalendar ?? this.useLegacyCalendar,
    );
  }
}
