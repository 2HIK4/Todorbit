# Integrated Windows widget

The packaged owner-drawn native companion passed manual acceptance on the
target Windows system, including continuous presentation, `Win + D`, Quick
Add, task editing, resizing, icons, views, theme synchronization, and main-app
lifecycle. Explorer hosting is still an undocumented Windows compatibility
dependency, so the regression checklist remains part of release verification.

## Build and launch

From the repository root:

```powershell
flutter build windows
build\windows\x64\runner\Release\life_manager.exe
build\windows\x64\runner\Release\life_manager_widget.exe --widget --app-exe build\windows\x64\runner\Release\life_manager.exe
```

For compatibility, this also launches the native companion and exits without
starting the old Flutter widget:

```powershell
build\windows\x64\runner\Release\life_manager.exe --widget
```

The app sidebar can show/hide the widget. Direct commands include:

```powershell
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command show
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command quick-add
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command view-upcoming
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command theme-system
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command exit
```

## Current behavior

- The persistent surface is a double-buffered native child of Explorer's
  existing `SHELLDLL_DefView`. It contains no persistent WinForms controls and
  is not topmost.
- Quick Add looks inline, but keyboard input is handled by a temporary
  borderless, activatable Life Manager top-level window placed exactly over the
  painted field. Enter validates and saves, Escape dismisses, and ordinary
  TextBox editing supplies selection, paste, Backspace, and Delete. The surface
  is destroyed after submit or dismissal.
- The Quick Add destination appears at the field's right edge. Today schedules
  for today, Upcoming schedules for tomorrow, and Inbox/All Tasks create an
  unscheduled inbox-compatible task.
- The checkbox completes a task. Clicking the title/row opens a compact native
  editor for title, notes, status, priority, category, project, scheduled day,
  and deadline. Saves use the existing schema-v3 database and reject stale or
  deleted records instead of silently overwriting them. **Open full details**
  starts Flutter with `--task-id <uuid>`.
- Today, Inbox, All Tasks, and Upcoming are selectable in the widget and tray.
  The selection is persisted in `%APPDATA%\Life Manager\widget-settings.json`.
- Header actions use owner-drawn refresh, open, and close icons with separate
  hit boxes and hover descriptions. Empty states and Quick Add destinations
  follow the selected view.
- Drag the empty title area to move. All four edges and four corners resize with
  matching cursors. Logical size is limited to 340x420 through 720x900, then
  scaled per monitor and clamped to the working area. Geometry persists.
- The app and widget share one authoritative
  `%APPDATA%\Life Manager\appearance-settings.json`. Both watch it using file
  notifications, so System/Light/Dark changes propagate without polling. A
  legacy widget-only theme is migrated once. Follow System also responds to
  Windows preference changes.
- SQLite/WAL changes are watched with a short debounce. Writes are
  transactional, use stable UUIDs and UTC timestamps, and the native repository
  refuses to create or migrate a production database.
- A mutex prevents duplicate companions. Closing Flutter leaves the widget
  running. Explorer recovery only recreates Life Manager's HWND with bounded
  retries and never changes or restarts Explorer.

The failed Flutter desktop-child prototype is retained only for explicit
diagnostic work through `life_manager.exe --legacy-flutter-widget`. It is not
used by the app, `--widget`, the tray, or optional sign-in registration.

## Automated checks

`life_manager_widget.exe --self-test` uses only a disposable database and
temporary settings. It covers create/edit/complete persistence, stale-edit
rejection, view filters and Quick Add destinations, settings/theme round trips,
resize/DPI/monitor geometry, mutex exclusion, pipe delivery, and bounded
Explorer recovery. Flutter tests cover application-side appearance persistence
and reloading plus the existing task/calendar/widget behavior.

These checks do not exercise physical keyboard activation, mouse dragging,
Explorer composition, or `Win + D`.

## Manual regression checklist

Record Pass/Fail plus Windows build, monitor topology, and scale:

1. Leave the widget visible for five minutes; confirm no black surface or
   capture-triggered repaint is needed.
2. Press `Win + D` twice; confirm the widget remains in/returns with the desktop.
3. Cover the widget with a normal app; confirm that app covers it and the widget
   is never always-on-top.
4. Click Quick Add. Type, select, paste, Backspace, Delete, press Escape, reopen,
   and press Enter. Confirm the editor looks inline and keeps reliable focus.
5. Add from Today and Inbox; confirm the main app updates immediately and the
   scheduled/unscheduled destination is correct.
6. Click a checkbox; confirm completion persists and the app updates.
7. Click a task title, edit each supported field, save, and reopen it. Also leave
   an editor open while changing/deleting the task elsewhere and confirm the
   stale save is rejected.
8. Use **Open full details** and confirm Flutter opens the requested task rather
   than a generic home screen.
9. Drag every supported edge/corner and the empty header. Confirm cursor shape,
   minimum layout, and button hit boxes remain correct.
10. Move and resize on each monitor, restart the widget, and confirm geometry
    persists within accessible bounds at each available DPI scale.
11. Exercise the refresh, open, and close icons; confirm their hover descriptions
    and that header dragging does not steal their clicks.
12. Switch Today, Inbox, All Tasks, and Upcoming in the widget; restart and
    confirm selection, filtering, ordering, counts/ranges, and empty states.
13. Select System, Light, and Dark from both processes, including with the other
    process closed; reopen both and confirm synchronized persistence and contrast.
14. Open and close Flutter three times. Confirm one widget process remains and
    task/database synchronization continues.
15. If user-approved, restart Explorer once and confirm bounded widget recovery
    without Explorer modification or a duplicate companion.

The initial promotion gate passed. Repeat this checklist when changing Windows
shell attachment, native input surfaces, rendering, DPI behavior, or packaging.
