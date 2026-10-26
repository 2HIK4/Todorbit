# Integrated Windows widget

## Two-widget customization update

Settings > Widget has independent Tasks Widget and Calendar Widget controls.
Enable either widget, then use its Configure action. Right-click any part of a
widget and choose **Edit This Widget** to open its editor directly, including
when its header or task navigation is hidden. An unlocked widget can be dragged
from its header/grip and unoccupied background; controls keep their normal input.
The context menu provides centering, checked saved settings and layout lock.

The draft editor has per-surface color, opacity, border and radius controls,
title/Open button visibility, text size and transparent-text protection. Tasks
also has independent view visibility, four navigation positions and text/icon
modes. Calendar has month navigation, today/selection styles, date indicators and
an independently styled selected-date agenda. Month grid dots indicate existing
planned tasks, work sessions or events according to the saved calendar filter.
Agenda task/session entries open their task in Todorbit; event entries are
currently read-only. Week start follows the application's calendar preference.

**Apply** saves the selected widget and keeps its editor open. Changes preview
on the enabled desktop widget over the existing IPC channel without disk writes.
Cancel restores the latest saved baseline; Close/Escape offers Save Changes,
Discard Changes or Continue Editing when dirty. A lost application connection
expires its preview within eight seconds. **Apply to All Widgets** confirms copying
shared title/Open visibility, text size/readability and shell/header/content
appearance. Each widget keeps its visibility, geometry, layout lock, task
navigation/input and calendar agenda/cell/indicator settings. **Cancel** discards
the draft; previews do not write saved files or change another widget.
Reset customization restores defaults while preserving enabled state/layout lock.
New widget configuration is profile-local and survives ordinary bundle updates;
it is not included in shareable settings/cloud snapshots. Shared theme colors
continue to use `appearance-settings.json`.

Both HWNDs use one companion, tray icon, IPC channel and startup entry. Tasks
retains its legacy geometry/view/startup file; Calendar stores its own geometry.
At larger text sizes the minimum window height grows to keep controls readable.
The focused native TextBox stays opaque so selection, caret and keyboard entry
remain clear. A nominally transparent shell retains one alpha step for reliable
management hit testing. No content-wide window opacity is applied.

Calendar uses one rounded month grid above a dedicated selected-day agenda.
Date-cell height is bounded; extra height expands the agenda. Four-, five- and
six-week months use the same geometry. All selected-day items remain available
through continuous row scrolling, with a fixed date heading and scroll cue.
Mouse-wheel input over the grid does not scroll the agenda. Click an agenda row
for native full text/details without opening Todorbit. Legacy presentation keys
are ignored without resetting other settings. Week-start/content preferences
and repository projection remain shared with the application.
Text protection now adds a restrained glyph shadow, with no opaque per-label
rectangles. Theme-aware rounded tooltips wait 600 ms and never activate.
Minimum sizes stay 300×360 for Calendar and 260×230 for Tasks at 100% text;
the existing text-scale-aware minimum grows for larger text. Below 340 logical
pixels a side task navigation becomes an icon rail while retaining its setting.

Unlocked companion widgets snap nearby moving/resized edges within 10 physical
screen pixels, retaining alignment until 16 pixels away. Only the manipulated
widget changes. Exact same-DPI pixel dimensions survive restart; other display
scales use saved logical dimensions. Work-area/minimum constraints still apply.
The redundant tray/main-app widget Quick Add entries are removed; the actual
task-entry bar, keyboard shortcuts and compatibility command remain available.

Additional commands on the same executable/profile:

```powershell
TodorbitWidget.exe --widget-command calendar-show
TodorbitWidget.exe --widget-command calendar-hide
TodorbitWidget.exe --widget-command calendar-toggle
TodorbitWidget.exe --widget-command reload-configuration
TodorbitWidget.exe --lifecycle-self-test
TodorbitWidget.exe --capture-widgets <output-directory>
```

`--self-test` now includes configuration migration, per-widget routing, calendar
projection, moved/cancelled occurrences, chronology, opacity, compact layout and
offscreen scaling checks. `--lifecycle-self-test` uses a disposable profile and
actual Explorer child windows to check simultaneous visibility, independent
hide/show and restart. It does not drive physical input. `--capture-widgets`
renders synthetic fixtures offscreen; its images are not desktop screenshots.

Repeat the manual checklist below for **both** widgets, including hidden headers,
all task navigation modes/positions, calendar month/date selection, transparent
surfaces and concurrent operation. Physical DPI, Win+D, Explorer restart,
keyboard/screen-reader interaction and input focus still require manual checks.
See [development record](WIDGET_CUSTOMIZATION_UPDATE.md) for current evidence.

The Release app now registers the widget for Windows sign-in by default after the active profile opens. Settings > Widget can disable it. Registration uses one per-user Run value per profile, points directly to `TodorbitWidget.exe --widget`, and is refreshed on a later Release app launch after an update or folder move. The main app is not in the startup command. The native self-test checks toggle, persistence, stale-path repair, and duplicate registry values using a private test key; actual login, Explorer attachment, and physical input remain manual checks on an isolated Windows account.

Feedback round 4 movement fix: the layered paint path must use the current
HWND screen rectangle. The previous path passed saved `widget-settings.json`
coordinates to `UpdateLayeredWindow` during each drag repaint, reversing the
live `SetWindowPos` movement until mouse release. Geometry is saved only on
release or capture loss. The self-test now covers drag and corner resize math.
Repeat the manual drag, resize, lock, DPI, Win+D, Explorer attachment, and
task-input checklist below before release; the Explorer child could not be
mouse-driven by the available Computer Use helper in this checkpoint.

The packaged owner-drawn native companion passed manual acceptance on the
target Windows system, including continuous presentation, `Win + D`, Quick
Add, task editing, resizing, icons, views, theme synchronization, and main-app
lifecycle. Explorer hosting is still an undocumented Windows compatibility
dependency, so the regression checklist remains part of release verification.

## Build and launch

From the repository root:

```powershell
flutter build windows --release
build\windows\x64\runner\Release\Todorbit.exe
build\windows\x64\runner\Release\TodorbitWidget.exe --widget --app-exe build\windows\x64\runner\Release\Todorbit.exe
```

For compatibility, this also launches the native companion and exits without
starting the old Flutter widget:

```powershell
build\windows\x64\runner\Release\Todorbit.exe --widget
```

The app sidebar can show/hide the widget. Direct commands include:

```powershell
build\windows\x64\runner\Release\TodorbitWidget.exe --widget-command show
build\windows\x64\runner\Release\TodorbitWidget.exe --widget-command quick-add
build\windows\x64\runner\Release\TodorbitWidget.exe --widget-command view-upcoming
build\windows\x64\runner\Release\TodorbitWidget.exe --widget-command theme-system
build\windows\x64\runner\Release\TodorbitWidget.exe --widget-command exit
```

## Current behavior

- The persistent surface is a double-buffered native child of Explorer's
  existing `SHELLDLL_DefView`. It contains no persistent WinForms controls and
  is not topmost.
- Quick Add looks inline, but keyboard input is handled by a temporary
  borderless, activatable Todorbit top-level window placed exactly over the
  painted field. Enter validates and saves, Escape dismisses, and ordinary
  TextBox editing supplies selection, paste, Backspace, and Delete. The surface
  is destroyed after submit or dismissal.
- The Quick Add destination appears at the field's right edge. Today schedules
  for today, Upcoming schedules for tomorrow, and Inbox/All Tasks create an
  unscheduled inbox-compatible task.
- The checkbox completes a task. Clicking the title/row opens a compact native
  editor for title, notes, status, priority, category, project, scheduled day,
  and deadline. Saves use the existing schema-v4 database and reject stale or
  deleted records instead of silently overwriting them. **Open full details**
  starts Flutter with `--task-id <uuid>`.
- Today, Inbox, All Tasks, and Upcoming are selectable in the widget and tray.
  The selection is persisted in the active profile's `widget-settings.json`.
- The header has one visible Open Todorbit action. Refresh, Close Widget,
  opacity, and layout lock are in the right-click context menu. Empty states
  and Quick Add destinations follow the selected view.
- Drag the empty title area to move. All four edges and four corners resize with
  matching cursors. The minimum is 260x230 logical pixels and the maximum is
  the current monitor's working area. Geometry and lock state persist. Locking
  disables movement and resizing while keeping task controls active.
- Background opacity can be 0–100%, including fully transparent. The native
  layered window keeps text and controls opaque. Transparency, desktop behavior,
  DPI, and wallpaper contrast require manual checks on the target system.
  The companion manifest declares Windows 8+ compatibility, which Windows
  requires for a layered child window. An isolated startup confirmed a layered
  Explorer child at the intended monitor coordinates; pixel appearance remains
  unverified.
- The app and widget share one authoritative
  active profile's `appearance-settings.json`. Fresh installer profiles use
  `%APPDATA%\TodoPilot`; portable copies use separate location-keyed folders;
  marked upgrades retain `%APPDATA%\Life Manager`. Both watch the file using
  notifications, so System/Light/Dark changes propagate without polling. A
  legacy widget-only theme is migrated once. Follow System also responds to
  Windows preference changes.
- SQLite/WAL changes are watched with a short debounce. Writes are
  transactional, use stable UUIDs and UTC timestamps, and the native repository
  refuses to create or migrate a production database.
- A mutex prevents duplicate companions. Closing Flutter leaves the widget
  running. Explorer recovery only recreates Todorbit's HWND with bounded
  retries and never changes or restarts Explorer.

The failed Flutter desktop-child prototype is retained only for explicit
diagnostic work through `Todorbit.exe --legacy-flutter-widget`. It is not
used by the app, `--widget`, the tray, or optional sign-in registration.

## Automated checks

`TodorbitWidget.exe --self-test` uses only a disposable database and
temporary settings. It covers create/edit/complete persistence, stale-edit
rejection, view filters and Quick Add destinations, settings/theme round trips,
resize/DPI/monitor geometry, mutex exclusion, pipe delivery, and bounded
Explorer recovery. Flutter tests cover application-side appearance persistence
and reloading plus the existing task/calendar/widget behavior.

These checks do not exercise physical keyboard activation, mouse dragging,
Explorer composition, or `Win + D`.

## Manual regression checklist

For the native editor redesign, include dark, light, and a custom palette. At
regular and narrow widths, verify field stacking and scroll-to-focused-field
with Tab/Shift+Tab. Check the themed choice popups and calendar at screen edges,
date typing and independent clear buttons, Enter/Escape, validation text,
selection/paste, hover/pressed/disabled/focus colors, and a short monitor work
area. The offscreen render checks in `docs/ACCEPTANCE.md` do not replace these
physical Windows checks.

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
11. Exercise Open Todorbit and every right-click menu item. Check Refresh,
    Close Widget, opacity presets and slider, lock/unlock, and that header
    dragging does not steal menu or task clicks.
12. Switch Today, Inbox, All Tasks, and Upcoming in the widget; restart and
    confirm selection, filtering, ordering, counts/ranges, and empty states.
13. Select System, Light, and Dark from both processes, including with the other
    process closed; reopen both and confirm synchronized persistence and contrast.
    Edit separate light/dark colors with the wheel; confirm immediate native
    widget updates and persistence after restarting both processes.
14. Test 0, 30, 70, and 100% opacity over dark and light wallpapers. Confirm
    background transparency, opaque text/controls, and clickable tasks. Resize
    down to 260x230 and up to the working area; verify layout and hit targets.
15. Open and close Flutter three times. Confirm one widget process remains and
    task/database synchronization continues.
16. If user-approved, restart Explorer once and confirm bounded widget recovery
    without Explorer modification or a duplicate companion.

The initial promotion gate passed. Repeat this checklist when changing Windows
shell attachment, native input surfaces, rendering, DPI behavior, or packaging.

## Privacy regression (pending manual acceptance)

With an isolated `APPDATA` and `LOCALAPPDATA` profile, enable app lock in the
main app and check that the widget immediately hides task content, closes open
Quick Add/task editors, refuses checkbox/edit commands, and opens the main app
for PIN entry. Repeat with the main app closed, starting, exiting, and after a
crash; verify the companion locks when the main PID disappears. Check locked
notification suppression and the optional generic-only message. Then unlock,
change/remove the PIN, and verify the widget updates within one second. The
native self-test covers policy/session parsing and disposable APPDATA routing,
but does not prove these visual interactions or workstation lock behavior.
