import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/life_repository.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import 'calendar_config.dart';
import 'calendar_layout_engine.dart';
import 'calendar_models.dart';

enum CalendarGestureKind { none, move, resizeStart, resizeEnd, dateDrag }

enum CalendarUndoKind { event, session, task }

enum CalendarRecurringMoveScope { thisOccurrence, entireSeries }

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
    this.isSeriesMove = false,
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
  final bool isSeriesMove;
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
  bool _isCommitting = false;
  bool resolvingChoice = false;
  int? _pointerId;
  Offset? _navigationAnchor;
  void trackPointer(int pointer) {
    if (gestureKind == CalendarGestureKind.none && !_isCommitting) {
      _pointerId = pointer;
    }
  }

  bool ownsPointer(int pointer) =>
      _pointerId == pointer && gestureKind != CalendarGestureKind.none;

  // History stacks
  final List<CalendarUndoRecord> _undoStack = [];
  final List<CalendarUndoRecord> _redoStack = [];
  bool _isHistoryBusy = false;

  bool get canUndo =>
      _undoStack.isNotEmpty &&
      !_isHistoryBusy &&
      !_isCommitting &&
      !resolvingChoice &&
      !isDragging;
  bool get canRedo =>
      _redoStack.isNotEmpty &&
      !_isHistoryBusy &&
      !_isCommitting &&
      !resolvingChoice &&
      !isDragging;
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
    if (_isHistoryBusy ||
        _isCommitting ||
        resolvingChoice ||
        !config.enableDragMove ||
        !item.isTimed) {
      return;
    }
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
      initialGrabOffsetY =
          pointerTimelineY - engine.timeToY(item.startsAt!, dayDate);
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
    if (_isHistoryBusy ||
        _isCommitting ||
        resolvingChoice ||
        !config.enableResize ||
        !item.isTimed) {
      return;
    }
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
    if (_isHistoryBusy ||
        _isCommitting ||
        resolvingChoice ||
        !config.enableResize ||
        !item.isTimed) {
      return;
    }
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
    if (_isHistoryBusy ||
        _isCommitting ||
        resolvingChoice ||
        !config.enableCrossDayMove) {
      return;
    }
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

    if (_navigationAnchor != null && pointerLocal == _navigationAnchor) return;
    _navigationAnchor = null;
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
        // A continuation card begins at the visible grid boundary, while the
        // event itself began earlier. Move that visible segment by the pointer
        // delta without resetting the event's original date/time to this day.
        final originDay = activeDayDate ?? targetDay;
        final originGridStart = DateTime(
          originDay.year,
          originDay.month,
          originDay.day,
          config.startHour,
        );
        final hiddenDuration = origStart.isBefore(originGridStart)
            ? originGridStart.difference(origStart)
            : Duration.zero;
        // Continuations are already clipped. Their pointer delta can be
        // negative; clamping that delta to the visual grid makes upward moves
        // no-ops. Ordinary starts retain the configured day-grid bounds.
        final finalStart = engine
            .yToTime(
              proposedY,
              targetDay,
              clampToGrid: hiddenDuration == Duration.zero,
            )
            .subtract(hiddenDuration);

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

        final snappedStart = engine.yToTime(
          proposedY,
          targetDay,
          clampToGrid: true,
        );

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

        final snappedEnd = engine.yToTime(
          proposedY,
          targetDay,
          allowEndBoundary: true,
          clampToGrid: true,
        );

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

  bool isPreservingGestureOnNavigation = false;

  void beginNavigation() {
    isPreservingGestureOnNavigation = true;
    _navigationAnchor = pointerCurrentLocal;
  }

  void endNavigation() {
    isPreservingGestureOnNavigation = false;
  }

  void forceCancel() {
    cancel();
  }

  void cancelFromRecognizer() {
    if (!isPreservingGestureOnNavigation) cancel();
  }

  void cancel() {
    if (_isCommitting) return;
    isPreservingGestureOnNavigation = false;
    _pointerId = null;
    _navigationAnchor = null;
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

  bool get hasPendingChange {
    if (gestureKind == CalendarGestureKind.none ||
        activeItem == null ||
        !isDragging) {
      return false;
    }
    final nextStart = proposedStartsAt ?? originStartsAt;
    final nextEnd = proposedEndsAt ?? originEndsAt;
    final nextDate = proposedDayDate ?? activeDayDate;

    final bool hasTimeChange =
        nextStart != null &&
        nextEnd != null &&
        (nextStart != originStartsAt || nextEnd != originEndsAt);
    final bool hasDateChange =
        nextDate != null &&
        activeDayDate != null &&
        (nextDate.year != activeDayDate!.year ||
            nextDate.month != activeDayDate!.month ||
            nextDate.day != activeDayDate!.day);

    return hasTimeChange || hasDateChange;
  }

  /// Calculates the updated [EventRepeat] rule when moving an entire event series.
  DateTime proposedSeriesStart(
    FixedEvent master,
    DateTime origin,
    DateTime target,
  ) {
    final days = RecurrenceRule.daysBetween(
      localDate(origin),
      localDate(target),
    );
    final start = master.startsAt.toLocal();
    return DateTime(
      start.year,
      start.month,
      start.day + days,
      start.hour + target.hour - origin.hour,
      start.minute + target.minute - origin.minute,
      start.second + target.second - origin.second,
      start.millisecond + target.millisecond - origin.millisecond,
      start.microsecond + target.microsecond - origin.microsecond,
    );
  }

  EventDraft proposedSeriesDraft(
    FixedEvent master,
    DateTime origin,
    DateTime target, {
    DateTime? targetEnd,
    EventRepeat? customRepeat,
  }) {
    final proposedRepeat =
        customRepeat ??
        calculateProposedSeriesRepeat(
          master: master,
          proposedStart: target,
          originStart: origin,
        );
    final proposedMasterStart = proposedSeriesStart(master, origin, target);
    final defaultDuration = master.endsAt.difference(master.startsAt);
    final duration = targetEnd != null && originEndsAt != null
        ? defaultDuration +
              targetEnd.difference(target) -
              originEndsAt!.difference(origin)
        : defaultDuration;
    final proposedMasterEnd = proposedMasterStart.add(duration);
    return EventDraft(
      title: master.title,
      notes: master.notes,
      startsAt: proposedMasterStart.toUtc(),
      endsAt: proposedMasterEnd.toUtc(),
      location: master.location,
      details: master.details,
      allDay: master.allDay,
      categoryId: master.categoryId,
      projectId: master.projectId,
      colorValue: master.colorValue,
      iconName: master.iconName,
      reminderMinutes: master.reminderMinutes,
      repeat: proposedRepeat,
    );
  }

  String? seriesTransformationProblem(
    FixedEvent master,
    DateTime origin,
    DateTime target,
  ) {
    final repeat = master.repeat;
    if (repeat == null) {
      return 'The recurring series no longer exists. Reopen it.';
    }
    final next = calculateProposedSeriesRepeat(
      master: master,
      originStart: origin,
      proposedStart: target,
    )!;
    final nextStart = proposedSeriesStart(master, origin, target);
    RecurrenceRule rule(EventRepeat r, DateTime start) => RecurrenceRule(
      kind: RecurrenceKind.values.byName(r.kind.name),
      startDate: localDate(start),
      interval: r.interval,
      weekdays: r.weekdays,
      endDate: r.untilDate,
    );
    final oldRule = rule(repeat, master.startsAt.toLocal());
    final newRule = rule(next, nextStart);
    bool matches(String oldDate) {
      final shifted = RecurrenceRule.shiftDate(
        oldDate,
        RecurrenceRule.daysBetween(localDate(origin), localDate(target)),
      );
      final before = oldRule.between(oldDate, oldDate).firstOrNull;
      final after = newRule.between(shifted, shifted).firstOrNull;
      return before != null && after != null && before.ordinal == after.ordinal;
    }

    if (!matches(localDate(origin))) {
      return 'This move cannot preserve the selected occurrence with the proposed anchor. Customize the recurrence in the editor.';
    }
    if (repeat.kind == EventRepeatKind.weekdays && repeat.interval > 1) {
      final start = localDate(master.startsAt.toLocal());
      final through = RecurrenceRule.shiftDate(start, 14 * repeat.interval + 7);
      if (oldRule
          .between(start, through)
          .any((slot) => !matches(slot.nominalDate))) {
        return 'This interval and weekday translation changes the gaps between occurrences. Customize the schedule in the editor.';
      }
    }
    return null;
  }

  EventRepeat? calculateProposedSeriesRepeat({
    required FixedEvent master,
    required DateTime proposedStart,
    required DateTime originStart,
  }) {
    if (master.repeat == null) return null;
    final repeat = master.repeat!;
    final dayDelta = RecurrenceRule.daysBetween(
      localDate(originStart),
      localDate(proposedStart),
    );

    String? updatedUntilDate = repeat.untilDate;
    if (updatedUntilDate != null && dayDelta != 0) {
      updatedUntilDate = RecurrenceRule.shiftDate(updatedUntilDate, dayDelta);
    }

    switch (repeat.kind) {
      case EventRepeatKind.weekdays:
        if (repeat.weekdays.length == 1) {
          return repeat.copyWith(
            weekdays: {proposedStart.weekday},
            untilDate: updatedUntilDate,
          );
        } else {
          // Whole pattern translation: shift every selected weekday by dayDelta
          final shifted = repeat.weekdays.map((day) {
            var s = (day - 1 + dayDelta) % 7;
            if (s < 0) s += 7;
            return s + 1;
          }).toSet();
          return repeat.copyWith(
            weekdays: shifted,
            untilDate: updatedUntilDate,
          );
        }
      case EventRepeatKind.weekly:
      case EventRepeatKind.daily:
      case EventRepeatKind.monthly:
      case EventRepeatKind.yearly:
        return repeat.copyWith(untilDate: updatedUntilDate);
    }
  }

  /// Commits the in-progress gesture to the database through [AppController].
  ///
  /// Returns a description of the change for undo notifications, or null if no change was made.
  Future<String?> commit(
    AppController controller, {
    CalendarRecurringMoveScope scope =
        CalendarRecurringMoveScope.thisOccurrence,
    EventRepeat? customRepeat,
    FixedEvent? approvedSeriesMaster,
  }) async {
    if (_isCommitting ||
        gestureKind == CalendarGestureKind.none ||
        activeItem == null ||
        !isDragging) {
      if (!_isCommitting) {
        cancel();
      }
      return null;
    }
    final item = activeItem!;
    final nextStart = proposedStartsAt ?? originStartsAt;
    final nextEnd = proposedEndsAt ?? originEndsAt;
    final nextDate = proposedDayDate ?? activeDayDate;

    // Check if there is an actual change
    final bool hasTimeChange =
        nextStart != null &&
        nextEnd != null &&
        (nextStart != originStartsAt || nextEnd != originEndsAt);
    final bool hasDateChange =
        nextDate != null &&
        activeDayDate != null &&
        (nextDate.year != activeDayDate!.year ||
            nextDate.month != activeDayDate!.month ||
            nextDate.day != activeDayDate!.day);

    if (!hasTimeChange && !hasDateChange) {
      cancel();
      return null;
    }
    _isCommitting = true;
    isDragging = false;

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
        final isOccurrence = event.nominalDate != null;

        if (scope == CalendarRecurringMoveScope.entireSeries &&
            (event.repeat != null || isOccurrence)) {
          final FixedEvent master;
          if (approvedSeriesMaster != null) {
            if (approvedSeriesMaster.id != event.id) {
              throw StateError('Series selection changed. Reopen the event.');
            }
            master = approvedSeriesMaster;
          } else if (event.nominalDate == null) {
            master = event;
          } else {
            final masters = await controller.repository.events();
            master = masters.firstWhere((e) => e.id == event.id);
          }

          final originStart = originStartsAt ?? event.startsAt.toLocal();
          final newStart = nextStart!.toLocal();
          final newEnd = nextEnd!.toLocal();
          final problem = seriesTransformationProblem(
            master,
            originStart,
            newStart,
          );
          if (problem != null) throw StateError(problem);

          final masterDraft = proposedSeriesDraft(
            master,
            originStart,
            newStart,
            targetEnd: newEnd,
            customRepeat: customRepeat,
          );

          await controller.moveCalendarSeries(master, masterDraft);
          _undoStack.add(
            CalendarUndoRecord(
              kind: CalendarUndoKind.event,
              description: 'moving series "${master.title}"',
              previousEvent: master,
              nextEventDraft: masterDraft,
              isOccurrence: false,
              isSeriesMove: true,
            ),
          );
          _redoStack.clear();
          notifyListeners();
          summary = 'Moved event series "${master.title}"';
        } else {
          final draftRepeat = isOccurrence ? null : event.repeat;
          if (draftRepeat?.kind == EventRepeatKind.weekdays &&
              !draftRepeat!.weekdays.contains(nextStart!.toLocal().weekday)) {
            throw ArgumentError(
              'Move one occurrence, or edit the series repeat days before moving '
              'its start to an unselected weekday.',
            );
          }

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
            repeat: draftRepeat,
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
              ? (_isSameDay(nextStart, nextEnd)
                    ? 'Changed end time of "${event.title}" to ${_formatTime(nextEnd)}'
                    : 'Changed end time of "${event.title}" to ${_formatDateStr(nextEnd)} ${_formatTime(nextEnd)}')
              : gestureKind == CalendarGestureKind.resizeStart
              ? (_isSameDay(nextStart, nextEnd)
                    ? 'Changed start time of "${event.title}" to ${_formatTime(nextStart)}'
                    : 'Changed start time of "${event.title}" to ${_formatDateStr(nextStart)} ${_formatTime(nextStart)}')
              : hasDateChange
              ? 'Moved "${event.title}" to ${_formatDateStr(nextStart)} ${_formatTime(nextStart)}'
              : 'Moved "${event.title}" to ${_formatTime(nextStart)}';
        }
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
          scheduledDate:
              targetDateStr, // Update planned date only; deadline preserved!
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
      _isCommitting = false;
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

  Future<String> _applyUndo(
    AppController controller,
    CalendarUndoRecord record,
  ) async {
    switch (record.kind) {
      case CalendarUndoKind.event:
        final prev = record.previousEvent!;
        final current = await _currentHistoryEvent(
          controller,
          prev,
          otherStart: record.nextEventDraft?.startsAt,
        );
        final draft = EventDraft(
          title: current.title,
          notes: current.notes,
          startsAt: prev.startsAt,
          endsAt: prev.endsAt,
          location: current.location,
          details: current.details,
          allDay: current.allDay,
          categoryId: current.categoryId,
          projectId: current.projectId,
          colorValue: current.colorValue,
          iconName: current.iconName,
          reminderMinutes: current.reminderMinutes,
          repeat: record.isOccurrence
              ? null
              : record.isSeriesMove
              ? prev.repeat
              : current.repeat,
        );
        if (record.isOccurrence) {
          await controller.updateEventOccurrence(current, draft);
        } else {
          if (record.isSeriesMove) {
            final expected = record.nextEventDraft!.repeat;
            if (!_sameRepeat(current.repeat, expected)) {
              throw StateError(
                'Series rule changed elsewhere. Review it before using calendar history.',
              );
            }
            await controller.moveCalendarSeries(current, draft);
          } else {
            await controller.updateEvent(current, draft);
          }
        }
        return 'Undid ${record.description}';

      case CalendarUndoKind.session:
        final prev = record.previousSession!;
        final current = controller.sessions
            .where((s) => s.id == prev.id)
            .firstOrNull;
        if (current != null) {
          await controller.updateSession(
            current,
            SessionDraft(
              taskId: current.taskId,
              startsAt: prev.startsAt,
              endsAt: prev.endsAt,
              outcome: current.outcome,
            ),
          );
        } else {
          throw StateError('Work session was not found in database.');
        }
        return 'Undid ${record.description}';

      case CalendarUndoKind.task:
        final prev = record.previousTask!;
        final current = controller.tasks
            .where((t) => t.id == prev.id)
            .firstOrNull;
        if (current != null) {
          await controller.updateTask(
            current,
            _taskAtDate(current, prev.scheduledDate),
          );
        } else {
          throw StateError('Task "${prev.title}" was not found in database.');
        }
        return 'Undid ${record.description}';
    }
  }

  Future<String> _applyRedo(
    AppController controller,
    CalendarUndoRecord record,
  ) async {
    switch (record.kind) {
      case CalendarUndoKind.event:
        final nextDraft = record.nextEventDraft!;
        final prev = record.previousEvent!;
        final current = await _currentHistoryEvent(
          controller,
          prev,
          otherStart: record.nextEventDraft?.startsAt,
        );
        final draft = EventDraft(
          title: current.title,
          notes: current.notes,
          startsAt: nextDraft.startsAt,
          endsAt: nextDraft.endsAt,
          location: current.location,
          details: current.details,
          allDay: current.allDay,
          categoryId: current.categoryId,
          projectId: current.projectId,
          colorValue: current.colorValue,
          iconName: current.iconName,
          reminderMinutes: current.reminderMinutes,
          repeat: record.isOccurrence
              ? null
              : record.isSeriesMove
              ? nextDraft.repeat
              : current.repeat,
        );
        if (record.isOccurrence) {
          await controller.updateEventOccurrence(current, draft);
        } else {
          if (record.isSeriesMove) {
            final expected = record.previousEvent!.repeat;
            if (!_sameRepeat(current.repeat, expected)) {
              throw StateError(
                'Series rule changed elsewhere. Review it before using calendar history.',
              );
            }
            await controller.moveCalendarSeries(current, draft);
          } else {
            await controller.updateEvent(current, draft);
          }
        }
        return 'Redid ${record.description}';

      case CalendarUndoKind.session:
        final nextDraft = record.nextSessionDraft!;
        final current = controller.sessions
            .where((s) => s.id == record.previousSession!.id)
            .firstOrNull;
        if (current != null) {
          await controller.updateSession(
            current,
            SessionDraft(
              taskId: current.taskId,
              startsAt: nextDraft.startsAt,
              endsAt: nextDraft.endsAt,
              outcome: current.outcome,
            ),
          );
        } else {
          throw StateError('Work session was not found in database.');
        }
        return 'Redid ${record.description}';

      case CalendarUndoKind.task:
        final nextDraft = record.nextTaskDraft!;
        final current = controller.tasks
            .where((t) => t.id == record.previousTask!.id)
            .firstOrNull;
        if (current != null) {
          await controller.updateTask(
            current,
            _taskAtDate(current, nextDraft.scheduledDate),
          );
        } else {
          throw StateError(
            'Task "${record.previousTask!.title}" was not found in database.',
          );
        }
        return 'Redid ${record.description}';
    }
  }

  bool _sameRepeat(EventRepeat? a, EventRepeat? b) =>
      a?.kind == b?.kind &&
      a?.interval == b?.interval &&
      a?.untilDate == b?.untilDate &&
      (a?.weekdays.length ?? 0) == (b?.weekdays.length ?? 0) &&
      (a?.weekdays.every((day) => b!.weekdays.contains(day)) ?? true);

  // Calendar history owns dates/times only. Reusing a complete historical draft
  // with a fresh CAS token would silently overwrite edits made in another editor.
  TaskDraft _taskAtDate(LifeTask task, String? date) => TaskDraft(
    title: task.title,
    notes: task.notes,
    status: task.status,
    priority: task.priority,
    categoryId: task.categoryId,
    projectId: task.projectId,
    scheduledDate: date,
    deadlineDate: task.deadlineDate,
    plannedDurationMinutes: task.plannedDurationMinutes,
    remainingWorkMinutes: task.remainingWorkMinutes,
    schedulingLocked: task.schedulingLocked,
    notification: task.notification,
  );

  Future<FixedEvent> _currentHistoryEvent(
    AppController controller,
    FixedEvent previous, {
    DateTime? otherStart,
  }) async {
    // Recurring masters are not in the controller's occurrence projection.
    final candidates = previous.nominalDate == null
        ? await controller.repository.events()
        : controller.events;
    var current = candidates
        .where(
          (event) =>
              event.id == previous.id &&
              event.nominalDate == previous.nominalDate &&
              !event.cancelled,
        )
        .firstOrNull;
    if (current == null && previous.nominalDate != null) {
      for (final start in [
        previous.startsAt,
        ?otherStart,
      ]) {
        final date = localDate(start.toLocal());
        final occurrences = await controller.repository.eventOccurrences(
          date,
          date,
        );
        current = occurrences
            .where(
              (event) =>
                  event.id == previous.id &&
                  event.nominalDate == previous.nominalDate &&
                  !event.cancelled,
            )
            .firstOrNull;
        if (current != null) break;
      }
    }
    if (current == null) {
      throw StateError(
        'Event "${previous.title}" is unavailable. Reopen its calendar date.',
      );
    }
    return current;
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
