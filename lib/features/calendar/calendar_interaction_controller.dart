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
    this.nextEventDraft,
    this.previousSession,
    this.nextSessionDraft,
    this.previousTask,
    this.nextTaskDraft,
    this.isOccurrence = false,
  });

  final CalendarUndoKind kind;
  final String description;
  final FixedEvent? previousEvent;
  final EventDraft? nextEventDraft;
  final WorkSession? previousSession;
  final SessionDraft? nextSessionDraft;
  final LifeTask? previousTask;
  final TaskDraft? nextTaskDraft;
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
  double? initialGrabOffsetY;
  bool isDragging = false;

  // History stacks
  final List<CalendarUndoRecord> _undoStack = [];
  final List<CalendarUndoRecord> _redoStack = [];
  bool _isHistoryBusy = false;

  bool get canUndo => _undoStack.isNotEmpty && !_isHistoryBusy && !isDragging;
  bool get canRedo => _redoStack.isNotEmpty && !_isHistoryBusy && !isDragging;
  bool get isHistoryBusy => _isHistoryBusy;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  void startMove({
    required CalendarItem item,
    required DateTime dayDate,
    required Offset pointerLocal,
    double? pointerTimelineY,
  }) {
    if (_isHistoryBusy || !config.enableDragMove || !item.isTimed) return;
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
    if (pointerTimelineY != null && item.startsAt != null) {
      initialGrabOffsetY = pointerTimelineY - engine.timeToY(item.startsAt!, dayDate);
    } else {
      initialGrabOffsetY = null;
    }
    isDragging = false;
    notifyListeners();
  }

  void startResizeTop({
    required CalendarItem item,
    required DateTime dayDate,
    required Offset pointerLocal,
    double? pointerTimelineY,
  }) {
    if (_isHistoryBusy || !config.enableResize || !item.isTimed) return;
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
    initialGrabOffsetY = null;
    isDragging = false;
    notifyListeners();
  }

  void startResizeBottom({
    required CalendarItem item,
    required DateTime dayDate,
    required Offset pointerLocal,
    double? pointerTimelineY,
  }) {
    if (_isHistoryBusy || !config.enableResize || !item.isTimed) return;
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
    initialGrabOffsetY = null;
    isDragging = false;
    notifyListeners();
  }

  void startDateDrag({
    required CalendarItem item,
    required DateTime originDate,
  }) {
    if (_isHistoryBusy || !config.enableCrossDayMove) return;
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

  void updatePointer(
    Offset pointerLocal, [
    DateTime? hoveredDayDate,
    double? pointerTimelineY,
  ]) {
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

    final origStart = originStartsAt;
    final origEnd = originEndsAt;
    final originalDuration = (origStart != null && origEnd != null)
        ? origEnd.difference(origStart)
        : Duration.zero;

    switch (gestureKind) {
      case CalendarGestureKind.move:
        if (origStart == null || origEnd == null) break;
        final double proposedY;
        if (pointerTimelineY != null && initialGrabOffsetY != null) {
          proposedY = pointerTimelineY - initialGrabOffsetY!;
        } else {
          final origStartY = engine.timeToY(origStart, activeDayDate);
          proposedY = origStartY + totalDelta.dy;
        }
        final snappedStart = engine.yToTime(proposedY, targetDay);

        // Clamp start time to day grid start boundary
        final minStart = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          config.startHour,
          0,
        );
        var finalStart = snappedStart;
        if (finalStart.isBefore(minStart)) {
          finalStart = minStart;
        }

        // Domain invariant: event duration MUST remain invariant under a move gesture.
        // Display clipping on day columns is handled by layout rendering; persisted
        // duration must never be truncated.
        final finalEnd = finalStart.add(originalDuration);

        proposedStartsAt = finalStart;
        proposedEndsAt = finalEnd;
        break;

      case CalendarGestureKind.resizeStart:
        if (origStart == null || origEnd == null) break;
        // Top edge: move start time, keep end time fixed
        final double proposedY;
        if (pointerTimelineY != null) {
          proposedY = pointerTimelineY;
        } else {
          final origStartY = engine.timeToY(origStart, activeDayDate);
          proposedY = origStartY + totalDelta.dy;
        }
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
        if (origStart == null || origEnd == null) break;
        // Bottom edge: move end time, keep start time fixed
        final double proposedY;
        if (pointerTimelineY != null) {
          proposedY = pointerTimelineY;
        } else {
          final origEndY = engine.timeToY(origEnd, activeDayDate);
          proposedY = origEndY + totalDelta.dy;
        }
        final snappedEnd = engine.yToTime(proposedY, targetDay);

        final minDuration = Duration(minutes: config.minItemDurationMinutes);
        final earliestAllowedEnd = origStart.add(minDuration);
        final maxEnd = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          config.endHour == 24 ? 23 : config.endHour,
          config.endHour == 24 ? 59 : 0,
        );

        var finalEnd = snappedEnd.isBefore(earliestAllowedEnd)
            ? earliestAllowedEnd
            : snappedEnd;
        if (finalEnd.isAfter(maxEnd)) {
          finalEnd = maxEnd;
        }

        proposedStartsAt = origStart;
        proposedEndsAt = finalEnd;
        break;

      case CalendarGestureKind.dateDrag:
        // Month view date drag: update target date while preserving clock time
        if (hoveredDayDate != null) {
          proposedDayDate = hoveredDayDate;
          if (origStart != null && origEnd != null) {
            proposedStartsAt = DateTime(
              hoveredDayDate.year,
              hoveredDayDate.month,
              hoveredDayDate.day,
              origStart.hour,
              origStart.minute,
              origStart.second,
              origStart.millisecond,
            );
            proposedEndsAt = proposedStartsAt!.add(originalDuration);
          }
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
    initialGrabOffsetY = null;
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

    final String actionDesc;
    switch (gestureKind) {
      case CalendarGestureKind.resizeStart:
        actionDesc = 'start time of "${item.title}"';
        break;
      case CalendarGestureKind.resizeEnd:
        actionDesc = 'end time of "${item.title}"';
        break;
      case CalendarGestureKind.dateDrag:
        final targetStr = nextDate != null
            ? _formatDateStr(nextDate)
            : _formatDateStr(nextStart!);
        actionDesc = 'moving "${item.title}" to $targetStr';
        break;
      case CalendarGestureKind.move:
      default:
        actionDesc = 'moving "${item.title}"';
        break;
    }

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
              description: actionDesc,
              previousEvent: previousEvent,
              nextEventDraft: draft,
              isOccurrence: true,
            ),
          );
        } else {
          await controller.updateEvent(event, draft);
          _undoStack.add(
            CalendarUndoRecord(
              kind: CalendarUndoKind.event,
              description: actionDesc,
              previousEvent: previousEvent,
              nextEventDraft: draft,
              isOccurrence: false,
            ),
          );
        }
        _redoStack.clear();
        notifyListeners();
        summary = gestureKind == CalendarGestureKind.resizeEnd
            ? 'Changed end time of "${event.title}" to ${_formatTime(nextEnd)}'
            : gestureKind == CalendarGestureKind.resizeStart
                ? 'Changed start time of "${event.title}" to ${_formatTime(nextStart)}'
                : hasDateChange
                    ? 'Moved "${event.title}" to ${_formatDateStr(nextStart)} ${_formatTime(nextStart)}'
                    : 'Moved "${event.title}" to ${_formatTime(nextStart)}';
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
            description: actionDesc,
            previousSession: previousSession,
            nextSessionDraft: draft,
          ),
        );
        _redoStack.clear();
        notifyListeners();
        summary = gestureKind == CalendarGestureKind.resizeEnd
            ? 'Changed end time of work session to ${_formatTime(nextEnd)}'
            : gestureKind == CalendarGestureKind.resizeStart
                ? 'Changed start time of work session to ${_formatTime(nextStart)}'
                : hasDateChange
                    ? 'Rescheduled work session to ${_formatDateStr(nextStart)} ${_formatTime(nextStart)}'
                    : 'Rescheduled work session to ${_formatTime(nextStart)}';
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
            description: actionDesc,
            previousTask: previousTask,
            nextTaskDraft: draft,
          ),
        );
        _redoStack.clear();
        notifyListeners();
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
    _isHistoryBusy = true;
    notifyListeners();
    final record = _undoStack.last;
    try {
      final summary = await _applyUndo(controller, record);
      _undoStack.removeLast();
      _redoStack.add(record);
      return summary;
    } finally {
      _isHistoryBusy = false;
      notifyListeners();
    }
  }

  /// Reapplies the most recent undone calendar change.
  Future<String?> redo(AppController controller) async {
    if (!canRedo) return null;
    _isHistoryBusy = true;
    notifyListeners();
    final record = _redoStack.last;
    try {
      final summary = await _applyRedo(controller, record);
      _redoStack.removeLast();
      _undoStack.add(record);
      return summary;
    } finally {
      _isHistoryBusy = false;
      notifyListeners();
    }
  }

  Future<String> _applyUndo(AppController controller, CalendarUndoRecord record) async {
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
        if (record.isOccurrence) {
          await controller.updateEventOccurrence(prev, draft);
        } else {
          final current = controller.events.where((e) => e.id == prev.id).firstOrNull;
          if (current != null) {
            await controller.updateEvent(current, draft);
          } else {
            throw StateError('Event "${prev.title}" was not found in database.');
          }
        }
        return 'Undid ${record.description}';

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
        } else {
          throw StateError('Work session was not found in database.');
        }
        return 'Undid ${record.description}';

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
        } else {
          throw StateError('Task "${prev.title}" was not found in database.');
        }
        return 'Undid ${record.description}';
    }
  }

  Future<String> _applyRedo(AppController controller, CalendarUndoRecord record) async {
    switch (record.kind) {
      case CalendarUndoKind.event:
        final nextDraft = record.nextEventDraft!;
        final prev = record.previousEvent!;
        if (record.isOccurrence) {
          await controller.updateEventOccurrence(prev, nextDraft);
        } else {
          final current = controller.events.where((e) => e.id == prev.id).firstOrNull;
          if (current != null) {
            await controller.updateEvent(current, nextDraft);
          } else {
            throw StateError('Event "${prev.title}" was not found in database.');
          }
        }
        return 'Redid ${record.description}';

      case CalendarUndoKind.session:
        final nextDraft = record.nextSessionDraft!;
        final current = controller.sessions.where((s) => s.id == record.previousSession!.id).firstOrNull;
        if (current != null) {
          await controller.updateSession(current, nextDraft);
        } else {
          throw StateError('Work session was not found in database.');
        }
        return 'Redid ${record.description}';

      case CalendarUndoKind.task:
        final nextDraft = record.nextTaskDraft!;
        final current = controller.tasks.where((t) => t.id == record.previousTask!.id).firstOrNull;
        if (current != null) {
          await controller.updateTask(current, nextDraft);
        } else {
          throw StateError('Task "${record.previousTask!.title}" was not found in database.');
        }
        return 'Redid ${record.description}';
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
