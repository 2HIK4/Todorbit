# Todorbit Interactive Calendar Architecture & Configuration Guide

This document describes the modular architecture of the redesigned Todorbit interactive calendar, its central configuration parameters, and exact recipes for safely refining interactions and visuals in future iterations.

---

## 1. Modular Architecture Overview

The calendar is divided into single-responsibility, independently testable components:

| Component | File | Responsibility |
|---|---|---|
| **CalendarAppearanceConfiguration** | [`lib/features/calendar/calendar_config.dart`](../lib/features/calendar/calendar_config.dart) | Central registry of visual parameters (heights, widths, spacing), interaction flags, and snapping rules. |
| **CalendarModels** | [`lib/features/calendar/calendar_models.dart`](../lib/features/calendar/calendar_models.dart) | Unified calendar domain representation (`CalendarItem`) and computed layout output (`CalendarPlacement`). |
| **CalendarLayoutEngine** | [`lib/features/calendar/calendar_layout_engine.dart`](../lib/features/calendar/calendar_layout_engine.dart) | Coordinate mapping (`timeToY`, `yToTime`), connected collision cluster grouping, and greedy lane allocation. |
| **CalendarInteractionController** | [`lib/features/calendar/calendar_interaction_controller.dart`](../lib/features/calendar/calendar_interaction_controller.dart) | Move, top-edge resize, bottom-edge resize, date-drag, boundary validation, cancellation, and Undo stack. |
| **CalendarZoomController** | [`lib/features/calendar/calendar_zoom_controller.dart`](../lib/features/calendar/calendar_zoom_controller.dart) | View transitions (Month ↔ Week ↔ Day), wheel delta accumulation, and anchor date resolution. |
| **TimelineDayColumn** | [`lib/features/calendar/timeline_grid.dart`](../lib/features/calendar/timeline_grid.dart) | Shared vertical timeline renderer for a day column, ghost previews, live time chips, and auto-scroll. |
| **CalendarDayView** | [`lib/features/calendar/calendar_day_view.dart`](../lib/features/calendar/calendar_day_view.dart) | Day layout with an "All-day & Planned" header and the primary vertical timeline. |
| **CalendarWeekView** | [`lib/features/calendar/calendar_week_view.dart`](../lib/features/calendar/calendar_week_view.dart) | 7 synchronized day columns with cross-day dragging and responsive horizontal scroll. |
| **CalendarMonthView** | [`lib/features/calendar/calendar_month_view.dart`](../lib/features/calendar/calendar_month_view.dart) | Compact month grid with drag-and-drop between date cells and extended right-click/long-press context actions. |
| **CalendarView** | [`lib/features/calendar/calendar_view.dart`](../lib/features/calendar/calendar_view.dart) | Top-level coordinator: toolbar, keyboard shortcuts, undo toast, and legacy fallback switch. |

---

## 2. Configuration Reference & Future Adjustment Recipes

All key parameters are centralized in `CalendarAppearanceConfiguration` in [`calendar_config.dart`](../lib/features/calendar/calendar_config.dart).

### Common adjustment recipes:

- **"Make time rows taller / shorter"**:
  Edit `hourHeight` (default: `60.0`). For example, change to `75.0` or `80.0`.
- **"Change snapping from 15 minutes to 5 minutes"**:
  Edit `snapMinutes` (default: `15`). Change to `5` or `10`.
- **"Adjust dragging threshold (distinguish click vs drag)"**:
  Edit `dragThreshold` (default: `4.0` pixels).
- **"Change zoom sensitivity"**:
  Edit `zoomThreshold` (default: `120.0` units). Lower values make zooming more responsive.
- **"Adjust minimum card readable width in dense collisions"**:
  Edit `minItemWidth` (default: `50.0`).
- **"Disable a specific interaction during testing"**:
  Toggle boolean flags in configuration:
  - `enableDragMove`: center move
  - `enableResize`: top/bottom handles
  - `enableZoom`: Ctrl+wheel zoom
  - `enableCrossDayMove`: dragging across day columns in Week view
- **"Switch between redesigned timeline and legacy calendar"**:
  - In code: set `useLegacyCalendar: true`.
  - In UI: Click the legacy/timeline toggle icon button next to the Reschedule button in the calendar toolbar.

---

## 3. Overlap & Collision Layout Algorithm

The collision engine in [`calendar_layout_engine.dart`](../lib/features/calendar/calendar_layout_engine.dart) operates in stages:

1. **Filtering**: Selects items intersecting the local day bounds (`start < dayEnd && end > dayStart`).
2. **Interval Overlap**: Strictly overlapping items (`A.start < B.end && A.end > B.start`) form collision edges. Items touching only at endpoints (`11:00` and `11:00`) do not collide.
3. **Cluster Grouping**: Connected components of overlapping intervals form isolated clusters.
4. **Stable Lane Sorting**: Within each cluster, items are sorted: `start asc → duration desc → stable id`.
5. **Greedy Lane Allocation**: Items are allocated to the lowest available lane where the previous item has ended.
6. **Horizontal Expansion**: Items expand rightward into unoccupied adjacent lanes if no collision exists during their active interval.

---

## 4. Safety & Invariants

- **Recurring Events**: Modifying an occurrence (`nominalDate != null`) calls `controller.updateEventOccurrence(...)`, updating only that specific occurrence as an exception without moving the entire series. Single non-recurring events update via `controller.updateEvent(...)`.
- **Tasks & Deadlines**: Dragging a task on Month view updates only its planned date (`scheduledDate`), strictly preserving `deadlineDate`.
- **Work Sessions**: Updated via `controller.updateSession(...)`.
- **Undo / Redo**: Every committed move or resize records a `CalendarUndoRecord` in `CalendarInteractionController`. Pressing `Ctrl+Z` or clicking "Undo" on the bottom SnackBar restores the previous item state via the repository.
- **Alarms**: Event alarms remain connected to the event and recalculate relative to updated start times;tray reminders and OS notifications remain in sync.

---

## 5. Keyboard & Mouse Shortcuts

- **Ctrl+1**: Switch to Day view
- **Ctrl+2**: Switch to Week view
- **Ctrl+3**: Switch to Month view
- **T**: Jump to Today
- **Ctrl+Z**: Undo last calendar change
- **Escape**: Cancel active drag or resize gesture
- **Ctrl + Mouse Wheel Up**: Zoom in (Month → Week → Day anchored at pointer)
- **Ctrl + Mouse Wheel Down**: Zoom out (Day → Week → Month anchored at pointer)
