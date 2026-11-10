import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../domain/models.dart';
import 'calendar_config.dart';
import 'calendar_layout_engine.dart';
import 'calendar_models.dart';

enum CalendarGestureKind {
  none,
  move,
  resizeStart,
  resizeEnd,
  dateDrag,
}

enum CalendarUndoKind {
  event,
  session,
  task,
}

@immutable
class CalendarUndoRecord {
  const CalendarUndoRecord({
    required this.kind,
    required this.description,
    this.previousEvent,
    this.previousSession,
    this.previousTask,
    this.isOccurrence = false,
  });

  final CalendarUndoKind kind;
  final String description;
  final FixedEvent? previousEvent;
  final WorkSession? previousSession;
  final LifeTask? previousTask;
  final bool isOccurrence;
}

/// Coordinates interactive move, resize, drag, validation, cancellation, and undo.
class CalendarInteractionController extends ChangeNotifier {
  CalendarInteractionController({
    this.config = const CalendarAppearanceConfiguration(),
  }) : engine = CalendarLayoutEngine(config: config);

  CalendarAppearanceConfiguration config;
  CalendarLayoutEngine engine;

  void updateConfig(CalendarAppearanceConfiguration newConfig) {
    config = newConfig;
    engine = CalendarLayoutEngine(config: newConfig);
    notifyListeners();
  }

  // Active gesture state
  CalendarGestureKind gestureKind = CalendarGestureKind.none;
  CalendarItem? activeItem;
  DateTime? originStartsAt;
  DateTime? originEndsAt;
  DateTime? activeDayDate;

  // Proposed state during gesture
  DateTime? proposedStartsAt;
  DateTime? proposedEndsAt;
  DateTime? proposedDayDate;

  Offset? pointerStartLocal;
  Offset? pointerCurrentLocal;
  bool isDragging = false;

  // Undo stack
  final List<CalendarUndoRecord> _undoStack = [];
  bool get canUndo => _undoStack.isNotEmpty;

  void startMove({
    required CalendarItem item,
    required DateTime dayDate,
    required Offset pointerLocal,
  }) {
    if (!config.enableDragMove || !item.isTimed) return;
    gestureKind = CalendarGestureKind.move;
    activeItem = item;
    originStartsAt = item.startsAt;
    originEndsAt = item.endsAt;
    activeDayDate = dayDate;
    proposedStartsAt = item.startsAt;
    proposedEndsAt = item.endsAt;
    proposedDayDate = dayDate;
    pointerStartLocal = pointerLocal;
    pointerCurrentLocal = pointerLocal;
    isDragging = false;
    notifyListeners();
  }

  void startResizeTop({
    required CalendarItem item,
    required DateTime dayDate,
    required Offset pointerLocal,
  }) {
    if (!config.enableResize || !item.isTimed) return;
    gestureKind = CalendarGestureKind.resizeStart;
    activeItem = item;
    originStartsAt = item.startsAt;
    originEndsAt = item.endsAt;
    activeDayDate = dayDate;
    proposedStartsAt = item.startsAt;
    proposedEndsAt = item.endsAt;
    proposedDayDate = dayDate;
    pointerStartLocal = pointerLocal;
    pointerCurrentLocal = pointerLocal;
    isDragging = false;
    notifyListeners();
  }

  void startResizeBottom({
    required CalendarItem item,
    required DateTime dayDate,
    required Offset pointerLocal,
  }) {
    if (!config.enableResize || !item.isTimed) return;
    gestureKind = CalendarGestureKind.resizeEnd;
    activeItem = item;
    originStartsAt = item.startsAt;
    originEndsAt = item.endsAt;
    activeDayDate = dayDate;
    proposedStartsAt = item.startsAt;
    proposedEndsAt = item.endsAt;
    proposedDayDate = dayDate;
    pointerStartLocal = pointerLocal;
    pointerCurrentLocal = pointerLocal;
    isDragging = false;
    notifyListeners();
  }

  void startDateDrag({
    required CalendarItem item,
    required DateTime originDate,
  }) {
    if (!config.enableCrossDayMove) return;
    gestureKind = CalendarGestureKind.dateDrag;
    activeItem = item;
    activeDayDate = originDate;
    proposedDayDate = originDate;
    originStartsAt = item.startsAt;
    originEndsAt = item.endsAt;
    proposedStartsAt = item.startsAt;
    proposedEndsAt = item.endsAt;
    isDragging = true;
    notifyListeners();
  }

  void updatePointer(Offset pointerLocal, [DateTime? hoveredDayDate]) {
    if (gestureKind == CalendarGestureKind.none || activeItem == null) return;

    pointerCurrentLocal = pointerLocal;
    final totalDelta = pointerLocal - (pointerStartLocal ?? pointerLocal);

    if (!isDragging) {
      if (totalDelta.distance >= config.dragThreshold) {
        isDragging = true;
      } else {
        return;
      }
    }

    final targetDay = (config.enableCrossDayMove && hoveredDayDate != null)
        ? hoveredDayDate
        : (activeDayDate ?? hoveredDayDate ?? DateTime.now());
    proposedDayDate = targetDay;

    final origStart = originStartsAt!;
    final origEnd = originEndsAt!;
    final originalDuration = origEnd.difference(origStart);

    switch (gestureKind) {
      case CalendarGestureKind.move:
        // Calculate proposed start from delta Y
        final origStartY = engine.timeToY(origStart);
        final proposedY = origStartY + totalDelta.dy;
        final snappedStart = engine.yToTime(proposedY, targetDay);

        // Clamp so item does not extend past end of day
        final maxEnd = DateTime(targetDay.year, targetDay.month, targetDay.day, config.endHour == 24 ? 23 : config.endHour, config.endHour == 24 ? 59 : 0);
        var finalStart = snappedStart;
        var finalEnd = finalStart.add(originalDuration);

        if (finalEnd.isAfter(maxEnd)) {
          finalEnd = maxEnd;
          finalStart = finalEnd.subtract(originalDuration);
        }

        proposedStartsAt = finalStart;
        proposedEndsAt = finalEnd;
        break;

      case CalendarGestureKind.resizeStart:
        // Top edge: move start time, keep end time fixed
        final origStartY = engine.timeToY(origStart);
        final proposedY = origStartY + totalDelta.dy;
        final snappedStart = engine.yToTime(proposedY, targetDay);

        final minDuration = Duration(minutes: config.minItemDurationMinutes);
        final latestAllowedStart = origEnd.subtract(minDuration);

        final finalStart = snappedStart.isAfter(latestAllowedStart)
            ? latestAllowedStart
            : snappedStart;

        proposedStartsAt = finalStart;
        proposedEndsAt = origEnd;
        break;

      case CalendarGestureKind.resizeEnd:
        // Bottom edge: move end time, keep start time fixed
        final origEndY = engine.timeToY(origEnd, activeDayDate);
        final proposedY = origEndY + totalDelta.dy;
        final snappedEnd = engine.yToTime(proposedY, targetDay);

        final minDuration = Duration(minutes: config.minItemDurationMinutes);
        final earliestAllowedEnd = origStart.add(minDuration);

        final finalEnd = snappedEnd.isBefore(earliestAllowedEnd)
            ? earliestAllowedEnd
            : snappedEnd;

        proposedStartsAt = origStart;
        proposedEndsAt = finalEnd;
        break;

      case CalendarGestureKind.dateDrag:
        // Month view date drag: update target date while preserving clock time
        if (hoveredDayDate != null) {
          proposedDayDate = hoveredDayDate;
          final dayDiff = hoveredDayDate.difference(DateTime(activeDayDate!.year, activeDayDate!.month, activeDayDate!.day)).inDays;
          proposedStartsAt = origStart.add(Duration(days: dayDiff));
          proposedEndsAt = origEnd.add(Duration(days: dayDiff));
        }
        break;

      case CalendarGestureKind.none:
        break;
    }

    notifyListeners();
  }

  void cancel() {
    gestureKind = CalendarGestureKind.none;
    activeItem = null;
    originStartsAt = null;
    originEndsAt = null;
    activeDayDate = null;
    proposedStartsAt = null;
    proposedEndsAt = null;
    proposedDayDate = null;
    pointerStartLocal = null;
    pointerCurrentLocal = null;
    isDragging = false;
    notifyListeners();
  }

  /// Commits the in-progress gesture to the database through [AppController].
  ///
  /// Returns a description of the change for undo notifications, or null if no change was made.
  Future<String?> commit(AppController controller) async {
    if (gestureKind == CalendarGestureKind.none || activeItem == null || !isDragging) {
      cancel();
      return null;
    }

    final item = activeItem!;
    final nextStart = proposedStartsAt ?? originStartsAt;
    final nextEnd = proposedEndsAt ?? originEndsAt;
    final nextDate = proposedDayDate ?? activeDayDate;

    // Check if there is an actual change
    final bool hasTimeChange = nextStart != null &&
        nextEnd != null &&
        (nextStart != originStartsAt || nextEnd != originEndsAt);
    final bool hasDateChange = nextDate != null &&
        activeDayDate != null &&
        (nextDate.year != activeDayDate!.year ||
            nextDate.month != activeDayDate!.month ||
            nextDate.day != activeDayDate!.day);

    if (!hasTimeChange && !hasDateChange) {
      cancel();
      return null;
    }

    String? summary;

    try {
      if (item.event != null) {
        final event = item.event!;
        final previousEvent = event;
        final draft = EventDraft(
          title: event.title,
          notes: event.notes,
          startsAt: nextStart!.toUtc(),
          endsAt: nextEnd!.toUtc(),
          location: event.location,
          details: event.details,
          allDay: event.allDay,
          categoryId: event.categoryId,
          projectId: event.projectId,
          colorValue: event.colorValue,
          iconName: event.iconName,
          reminderMinutes: event.reminderMinutes,
          repeat: event.repeat,
        );

        if (event.nominalDate != null) {
          // Recurring occurrence: update single occurrence safely
          await controller.updateEventOccurrence(event, draft);
          _undoStack.add(
            CalendarUndoRecord(
              kind: CalendarUndoKind.event,
              description: 'Moved "${event.title}"',
              previousEvent: previousEvent,
              isOccurrence: true,
            ),
          );
        } else {
          await controller.updateEvent(event, draft);
          _undoStack.add(
            CalendarUndoRecord(
              kind: CalendarUndoKind.event,
              description: 'Moved "${event.title}"',
              previousEvent: previousEvent,
              isOccurrence: false,
            ),
          );
        }
        summary = 'Moved "${event.title}" to ${_formatTime(nextStart)}';
      } else if (item.session != null) {
        final session = item.session!;
        final previousSession = session;
        final draft = SessionDraft(
          taskId: session.taskId,
          startsAt: nextStart!.toUtc(),
          endsAt: nextEnd!.toUtc(),
          outcome: session.outcome,
        );

        await controller.updateSession(session, draft);
        _undoStack.add(
          CalendarUndoRecord(
            kind: CalendarUndoKind.session,
            description: 'Rescheduled session',
            previousSession: previousSession,
          ),
        );
        summary = 'Rescheduled work session to ${_formatTime(nextStart)}';
      } else if (item.task != null && nextDate != null) {
        final task = item.task!;
        final previousTask = task;
        final targetDateStr = _formatDateStr(nextDate);

        final draft = TaskDraft(
          title: task.title,
          notes: task.notes,
          status: task.status,
          priority: task.priority,
          categoryId: task.categoryId,
          projectId: task.projectId,
          scheduledDate: targetDateStr, // Update planned date only; deadline preserved!
          deadlineDate: task.deadlineDate,
          plannedDurationMinutes: task.plannedDurationMinutes,
          remainingWorkMinutes: task.remainingWorkMinutes,
          schedulingLocked: task.schedulingLocked,
          notification: task.notification,
        );

        await controller.updateTask(task, draft);
        _undoStack.add(
          CalendarUndoRecord(
            kind: CalendarUndoKind.task,
            description: 'Moved task "${task.title}"',
            previousTask: previousTask,
          ),
        );
        summary = 'Moved "${task.title}" to $targetDateStr';
      }
    } finally {
      cancel();
    }

    return summary;
  }

  /// Reverts the most recent committed calendar change.
  Future<String?> undo(AppController controller) async {
    if (!canUndo) return null;
    final record = _undoStack.removeLast();
    notifyListeners();

    switch (record.kind) {
      case CalendarUndoKind.event:
        final prev = record.previousEvent!;
        final draft = EventDraft(
          title: prev.title,
          notes: prev.notes,
          startsAt: prev.startsAt,
          endsAt: prev.endsAt,
          location: prev.location,
          details: prev.details,
          allDay: prev.allDay,
          categoryId: prev.categoryId,
          projectId: prev.projectId,
          colorValue: prev.colorValue,
          iconName: prev.iconName,
          reminderMinutes: prev.reminderMinutes,
          repeat: prev.repeat,
        );
        // Find current instance
        final current = controller.events.where((e) => e.id == prev.id).firstOrNull;
        if (current != null) {
          if (record.isOccurrence) {
            await controller.updateEventOccurrence(current, draft);
          } else {
            await controller.updateEvent(current, draft);
          }
        }
        return 'Reverted "${prev.title}"';

      case CalendarUndoKind.session:
        final prev = record.previousSession!;
        final draft = SessionDraft(
          taskId: prev.taskId,
          startsAt: prev.startsAt,
          endsAt: prev.endsAt,
          outcome: prev.outcome,
        );
        final current = controller.sessions.where((s) => s.id == prev.id).firstOrNull;
        if (current != null) {
          await controller.updateSession(current, draft);
        }
        return 'Reverted work session';

      case CalendarUndoKind.task:
        final prev = record.previousTask!;
        final draft = TaskDraft(
          title: prev.title,
          notes: prev.notes,
          status: prev.status,
          priority: prev.priority,
          categoryId: prev.categoryId,
          projectId: prev.projectId,
          scheduledDate: prev.scheduledDate,
          deadlineDate: prev.deadlineDate,
          plannedDurationMinutes: prev.plannedDurationMinutes,
          remainingWorkMinutes: prev.remainingWorkMinutes,
          schedulingLocked: prev.schedulingLocked,
          notification: prev.notification,
        );
        final current = controller.tasks.where((t) => t.id == prev.id).firstOrNull;
        if (current != null) {
          await controller.updateTask(current, draft);
        }
        return 'Reverted "${prev.title}"';
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDateStr(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
