# Todorbit 1.0.19-beta.15 — Interactive Calendar Redesign

Experimental Windows and Android pre-release, build 38. Builds upon Beta 14 with a redesigned, professional interactive calendar experience across Day, Week, and Month views.

### Interactive Calendar Redesign
- **Vertical Time-Grid Layout**: Accurate timeline positioning in Day and Week views where blocks appear at their scheduled times and block heights reflect actual duration.
- **Intelligent Collision Layout**: Overlapping events and work sessions automatically allocate into balanced, side-by-side lanes with horizontal expansion and readable minimum widths.
- **Drag & Resize Interactions**:
  - Center drag moves the entire block, updating start and end times together while preserving duration.
  - Top-edge drag resizes the start time while keeping the end time fixed.
  - Bottom-edge drag resizes the end time while keeping the start time fixed.
  - 15-minute snapping by default with live start/end time chips and semi-transparent preview feedback.
- **Cross-Day & Month Navigation**:
  - Drag items across days in Week view.
  - Drag tasks and events onto days in Month view, preserving original clock times and durations.
  - Month view context menu with quick actions: Add Event, Add Task, Add Work Session, Show Day, and Show Week.
- **Cursor-Anchored Zoom Navigation**: Seamlessly transition between Month ↔ Week ↔ Day views using `Ctrl + Mouse Wheel` anchored directly at the pointer location, plus keyboard shortcuts (`Ctrl+1` Day, `Ctrl+2` Week, `Ctrl+3` Month, `T` Today, `Esc` Cancel).
- **Desktop-Grade Undo / Redo**:
  - `Ctrl + Z` undoes the last calendar reschedule or resize.
  - `Ctrl + Shift + Z` and `Ctrl + Y` redoes the undone change.
  - Calendar toolbar includes real-time Undo and Redo buttons.
  - Reversible SnackBar notifications provide instant Undo/Redo buttons.
  - Focus-aware: native text editing retains standard undo/redo without calendar shortcut interference.
  - Invalidation safety: any new edit after Undo cleanly purges invalidated Redo history.
- **Scheduling & Data Safety**:
  - Dragging scheduled tasks updates `scheduledDate` only; task deadlines are strictly preserved.
  - Editing recurring occurrences creates isolated single-occurrence overrides without modifying the parent recurrence rule or other occurrences.
  - Reversible legacy view toggle in the calendar toolbar allows instant switching between the interactive timeline and legacy calendar presentation.
- **Preserved Architecture**: Existing alarms, recurrence rules, Google Drive sync, backup snapshots, and privacy controls remain intact.

### Verification & Platform Status
- All 59 unit, widget, visual layout, and safety tests pass; `dart analyze` reports 0 issues.
- Windows Release package verified with CRT bundle and per-user Inno Setup installer.
- Android universal APK built with production signing key and 16 KB page-size compatibility.
- This is an experimental pre-release, excluded from the Stable update channel. Windows packages remain unsigned.
