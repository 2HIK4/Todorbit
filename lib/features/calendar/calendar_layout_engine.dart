import 'dart:math' as math;
import 'calendar_config.dart';
import 'calendar_models.dart';

/// Pure layout engine that computes visual placements for timed calendar items.
///
/// Converts between dates/times and visual pixel offsets, groups overlapping items
/// into connected collision clusters, and allocates stable side-by-side lanes.
class CalendarLayoutEngine {
  const CalendarLayoutEngine({
    this.config = const CalendarAppearanceConfiguration(),
  });

  final CalendarAppearanceConfiguration config;

  /// Converts a [DateTime] into a vertical pixel Y offset within the day grid.
  /// If [baseDay] is provided, handles times extending to midnight or across day boundaries.
  double timeToY(DateTime time, [DateTime? baseDay]) {
    if (baseDay != null) {
      final base = DateTime(baseDay.year, baseDay.month, baseDay.day, config.startHour);
      final diff = time.difference(base);
      final hours = diff.inMilliseconds / 3600000.0;
      return (hours * config.hourHeight).clamp(0.0, config.totalGridHeight);
    }
    final hourFraction =
        (time.hour - config.startHour) +
        (time.minute / 60.0) +
        (time.second / 3600.0);
    return (hourFraction * config.hourHeight).clamp(0.0, config.totalGridHeight);
  }

  /// Converts a vertical pixel Y offset into a snapped [DateTime] on [dayDate].
  DateTime yToTime(double y, DateTime dayDate, {
    bool allowEndBoundary = false,
  }) {
    final clampedY = y.clamp(0.0, config.totalGridHeight);
    final totalHours = (clampedY / config.hourHeight) + config.startHour;
    final totalMinutes = (totalHours * 60).round();

    // Snap to nearest configured interval
    final snap = config.snapMinutes;
    final snappedMinutes = (totalMinutes / snap).round() * snap;

    final hour = (snappedMinutes ~/ 60).clamp(config.startHour, config.endHour);
    final minute = (snappedMinutes % 60);

    return DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
      hour == 24 && !allowEndBoundary ? 23 : hour,
      hour == 24 ? (allowEndBoundary ? 0 : 59) : minute,
    );
  }

  /// Computes visual placements for all timed items belonging to a single day column.
  List<CalendarPlacement> computePlacements(
    List<CalendarItem> items,
    DateTime dayDate,
  ) {
    final timed = items.where((item) => item.isTimed).toList();
    if (timed.isEmpty) return const [];

    // Filter to items that intersect with this day
    final dayStart = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final dayEnd = DateTime(dayDate.year, dayDate.month, dayDate.day + 1);

    final dayItems = timed.where((item) {
      return item.startsAt!.isBefore(dayEnd) && item.endsAt!.isAfter(dayStart);
    }).toList();

    if (dayItems.isEmpty) return const [];

    // Group items into connected collision clusters
    final clusters = _buildCollisionClusters(dayItems);

    final results = <CalendarPlacement>[];

    for (final cluster in clusters) {
      final clusterPlacements = _layoutCluster(cluster, dayDate);
      results.addAll(clusterPlacements);
    }

    return results;
  }

  /// Builds connected collision clusters where an edge exists if two items strictly overlap in time.
  List<List<CalendarItem>> _buildCollisionClusters(List<CalendarItem> items) {
    // Sort items by start time, duration desc, stable id
    final sorted = List<CalendarItem>.from(items)..sort((a, b) {
      final startCmp = a.startsAt!.compareTo(b.startsAt!);
      if (startCmp != 0) return startCmp;
      final durCmp = b.duration.compareTo(a.duration);
      if (durCmp != 0) return durCmp;
      return a.id.compareTo(b.id);
    });

    final clusters = <List<CalendarItem>>[];
    List<CalendarItem>? currentCluster;
    DateTime? clusterMaxEnd;

    for (final item in sorted) {
      if (currentCluster == null) {
        currentCluster = [item];
        clusterMaxEnd = item.endsAt!;
      } else {
        // Items overlap strictly if item.startsAt < clusterMaxEnd
        // Endpoints touching (startsAt == clusterMaxEnd) do NOT overlap.
        if (item.startsAt!.isBefore(clusterMaxEnd!)) {
          currentCluster.add(item);
          if (item.endsAt!.isAfter(clusterMaxEnd)) {
            clusterMaxEnd = item.endsAt!;
          }
        } else {
          clusters.add(currentCluster);
          currentCluster = [item];
          clusterMaxEnd = item.endsAt!;
        }
      }
    }

    if (currentCluster != null && currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    return clusters;
  }

  /// Computes lane assignments and visual bounds for a single connected collision cluster.
  List<CalendarPlacement> _layoutCluster(
    List<CalendarItem> cluster,
    DateTime dayDate,
  ) {
    if (cluster.isEmpty) return const [];

    if (cluster.length == 1) {
      final item = cluster.first;
      final top = timeToY(item.startsAt!, dayDate);
      final bottom = timeToY(item.endsAt!, dayDate);
      final rawHeight = bottom - top;
      final height = math.max(rawHeight, config.minItemHeight);

      return [
        CalendarPlacement(
          item: item,
          top: top,
          height: height,
          leftFraction: 0.0,
          widthFraction: 1.0,
          lane: 0,
          totalLanes: 1,
          hasConflict: false,
        ),
      ];
    }

    // Sort cluster items: start asc, duration desc, id
    final sorted = List<CalendarItem>.from(cluster)..sort((a, b) {
      final startCmp = a.startsAt!.compareTo(b.startsAt!);
      if (startCmp != 0) return startCmp;
      final durCmp = b.duration.compareTo(a.duration);
      if (durCmp != 0) return durCmp;
      return a.id.compareTo(b.id);
    });

    // Lane assignment: each lane holds a list of items placed in it
    final lanes = <List<CalendarItem>>[];
    final itemLanes = <String, int>{};

    for (final item in sorted) {
      int assignedLane = -1;
      for (var i = 0; i < lanes.length; i++) {
        final lastInLane = lanes[i].last;
        // Check if item can fit after last item in lane (endpoints touching is allowed!)
        if (!item.startsAt!.isBefore(lastInLane.endsAt!)) {
          assignedLane = i;
          lanes[i].add(item);
          break;
        }
      }

      if (assignedLane == -1) {
        assignedLane = lanes.length;
        lanes.add([item]);
      }

      itemLanes[item.id] = assignedLane;
    }

    final totalLanes = lanes.length;

    // Check actual pairwise conflicts within the cluster
    final conflictIds = <String>{};
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final a = sorted[i];
        final b = sorted[j];
        if (a.startsAt!.isBefore(b.endsAt!) && a.endsAt!.isAfter(b.startsAt!)) {
          conflictIds.add(a.id);
          conflictIds.add(b.id);
        }
      }
    }

    // For each item, compute leftFraction and determine if it can expand to adjacent empty lanes
    final placements = <CalendarPlacement>[];

    for (final item in sorted) {
      final lane = itemLanes[item.id]!;
      final top = timeToY(item.startsAt!, dayDate);
      final bottom = timeToY(item.endsAt!, dayDate);
      final rawHeight = bottom - top;
      final height = math.max(rawHeight, config.minItemHeight);

      // Determine how many adjacent lanes this item can expand into
      var colSpan = 1;
      for (var l = lane + 1; l < totalLanes; l++) {
        final laneItems = lanes[l];
        final hasOverlapInLane = laneItems.any((other) =>
            item.startsAt!.isBefore(other.endsAt!) &&
            item.endsAt!.isAfter(other.startsAt!));
        if (hasOverlapInLane) break;
        colSpan++;
      }

      final leftFraction = lane / totalLanes;
      final widthFraction = colSpan / totalLanes;

      final conflictCount = sorted.where((other) =>
          other.id != item.id &&
          item.startsAt!.isBefore(other.endsAt!) &&
          item.endsAt!.isAfter(other.startsAt!)).length;

      placements.add(
        CalendarPlacement(
          item: item,
          top: top,
          height: height,
          leftFraction: leftFraction,
          widthFraction: widthFraction,
          lane: lane,
          totalLanes: totalLanes,
          hasConflict: conflictCount > 0,
          conflictCount: conflictCount,
        ),
      );
    }

    return placements;
  }
}
