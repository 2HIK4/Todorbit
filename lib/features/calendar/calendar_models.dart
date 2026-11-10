import 'package:flutter/foundation.dart';
import '../../domain/models.dart';

enum CalendarItemKind {
  event,
  session,
  task,
}

/// Unified representation of an item displayed on the calendar (event, session, or task).
@immutable
class CalendarItem {
  const CalendarItem({
    required this.id,
    required this.title,
    required this.kind,
    this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.event,
    this.session,
    this.task,
    this.parentTitle,
    this.colorValue,
    this.iconName,
    this.isCancelled = false,
    this.subtitle,
    this.detailsText,
  });

  final String id;
  final String title;
  final CalendarItemKind kind;

  /// Start time in local timezone (null for date-only items).
  final DateTime? startsAt;

  /// End time in local timezone (null for date-only items).
  final DateTime? endsAt;

  /// Whether this is an all-day event.
  final bool allDay;

  /// Underlying domain object if this represents a fixed event.
  final FixedEvent? event;

  /// Underlying domain object if this represents a work session.
  final WorkSession? session;

  /// Underlying domain object if this represents a life task.
  final LifeTask? task;

  /// Parent task title if applicable (e.g. for subtasks).
  final String? parentTitle;

  /// Custom color override (RGB int value).
  final int? colorValue;

  /// Icon identifier key.
  final String? iconName;

  /// Whether the event was cancelled.
  final bool isCancelled;

  /// Short secondary text (e.g. status or time).
  final String? subtitle;

  /// Detailed multiline or extra info string.
  final String? detailsText;

  /// A timed item has explicit start and end times and is not all-day.
  bool get isTimed => startsAt != null && endsAt != null && !allDay;

  /// Duration for timed items, or Duration.zero if not timed.
  Duration get duration => isTimed ? endsAt!.difference(startsAt!) : Duration.zero;

  CalendarItem copyWithTime({
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    return CalendarItem(
      id: id,
      title: title,
      kind: kind,
      startsAt: startsAt,
      endsAt: endsAt,
      allDay: allDay,
      event: event,
      session: session,
      task: task,
      parentTitle: parentTitle,
      colorValue: colorValue,
      iconName: iconName,
      isCancelled: isCancelled,
      subtitle: subtitle,
      detailsText: detailsText,
    );
  }
}

/// Computed visual layout placement for a timed item within a day column.
@immutable
class CalendarPlacement {
  const CalendarPlacement({
    required this.item,
    required this.top,
    required this.height,
    required this.leftFraction,
    required this.widthFraction,
    required this.lane,
    required this.totalLanes,
    this.hasConflict = false,
    this.conflictCount = 0,
  });

  final CalendarItem item;

  /// Vertical offset in pixels from top of the timeline grid.
  final double top;

  /// Height in pixels representing item duration.
  final double height;

  /// Horizontal offset fraction (0.0 to 1.0) within the column.
  final double leftFraction;

  /// Horizontal width fraction (0.0 to 1.0) within the column.
  final double widthFraction;

  /// Zero-based lane index within its collision cluster.
  final int lane;

  /// Total number of lanes in its collision cluster.
  final int totalLanes;

  /// Whether this item overlaps with any other timed item.
  final bool hasConflict;

  /// Total number of other items overlapping with this item.
  final int conflictCount;
}
