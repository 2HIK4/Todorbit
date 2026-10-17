# Progress

## Completed

- Windows-first offline Flutter foundation with Riverpod, Drift/SQLite,
  per-user storage, schema migrations, UUID identifiers, UTC modification
  timestamps, categories, projects, and task CRUD.
- Today, Inbox, All, Upcoming, Overdue, Waiting, Completed, category, and
  project task views with sorting, details editing, completion, and confirmed
  permanent deletion.
- Calendar day/week/month views backed by real tasks, deadlines, and fixed
  events. Schema v2 migration preserves v1 tasks.
- Planned work sessions with independent outcomes and actual-start tracking.
  Schema v3 supports upgrades from v1 and v2 without resetting user data.
- Deterministic, non-mutating scheduling preview logic with availability
  windows, exceptions, fixed-event/session blocking, buffers, no-slot reasons,
  and deadline warnings.
- Smart Reschedule integrated into task lists, task actions, project/category
  scopes, and Calendar sessions. Move, Shift, Push, Pull, Swap, Reorder, Repack,
  and Split generate reviewable proposals and persist only after explicit Apply.
- Schema v4 persists editable availability, task schedule protection, focused
  manual/Smart scheduling history, safe undo, and previous/original restoration.
  Stale previews are rejected and later manual schedules are protected.
- Category-dialog lifetime and task-row hover regressions covered by widget
  tests. The previously reported Windows-only checkbox duplication has not been
  reproduced in automated tests.
- Native widget architecture investigation documented the failed Flutter
  desktop-child activation path, Explorer hierarchy behavior, WinForms black
  composition failure, and the successful direct owner-drawn HWND approach.
  Opt-in diagnostics and guarded shell probes remain available for regression
  investigation.
- Integrated native Windows widget packaged as the self-contained
  `life_manager_widget.exe` beside `life_manager.exe`. It owns its independent
  process/tray lifecycle, uses a named mutex and named pipe, watches SQLite/WAL
  changes without polling, and performs bounded recovery of only its own HWND
  after Explorer changes.
- Widget UX includes inline-positioned activatable Quick Add, transactional
  view-aware task creation, compact optimistic-concurrency task editing,
  task-specific Flutter handoff, vector header controls, separate checkbox/row
  targets, Today/Inbox/All Tasks/Upcoming selection, empty states, scrolling,
  header dragging, all-edge/corner resizing, persisted monitor-aware geometry,
  and per-monitor DPI scaling.
- System/Light/Dark appearance is authoritative in
  `%APPDATA%\Life Manager\appearance-settings.json`, migrates the former widget
  setting, persists across restarts, and synchronizes between Flutter and the
  native companion through debounced file notifications.
- Manual acceptance passed for continuous visibility, `Win+D`, Quick Add,
  task editing, resizing, header icons, view switching, theme synchronization,
  and independent main-application lifecycle.
- Promotion finalized: normal app controls and optional sign-in registration
  launch the native companion. `life_manager.exe --widget` delegates to the
  packaged companion before Flutter starts. The failed Flutter widget is
  retained only behind the explicit `--legacy-flutter-widget` diagnostic flag.

## Current validation

- Flutter 3.47.7 / Dart 3.13.5; Windows toolchain healthy.
- `flutter analyze`: clean.
- `flutter test`: 33 passing tests, including engine, database, migration,
  stale-apply, undo/restoration, split, persistence, and preview/Apply coverage.
- Native Release build and disposable database/settings self-test: passing.
- Native dependency audit: no vulnerable packages reported.
- `flutter build windows` Release and Debug packages succeed and contain both
  `life_manager.exe` and `life_manager_widget.exe`.
- Packaged `life_manager_widget.exe --self-test`: passing.
- `flutter build windows --release`: passing; package contains the main app and
  schema-v4-compatible native companion.
- Manual visual check: the Release task-list entry point opened the themed Smart
  Reschedule workspace with the real current scope, selected tasks,
  Availability, Generate preview, Cancel, and disabled-until-preview Apply. It
  was closed without applying changes. Automated widget coverage verifies the
  preview and persisted Apply path.
- The native companion never creates or migrates the production database; it
  requires schema v4, enables foreign keys and a busy timeout, and uses
  parameterized transactional writes. Automated tests use an isolated database.

## In progress

- Milestone 3 follow-up: dependency and persistent-sequence models, recurrence,
  richer multi-window availability editing, and drag-to-reorder sequence UX.
- Reproduce the reported Windows task-row checkbox duplication and capture its
  first exception if it occurs again; widget tests remain stable.

## Not yet implemented

- Habits, goals, timer, templates, search/saved views, backups, Trash,
  notifications, privacy controls, and import/export.

## Environment and data notes

- Android SDK command-line tools and licenses remain incomplete; Android is
  outside the current milestone.
- Existing task/category/project/event/session data is migrated forward in place;
  Smart Reschedule does not reset the production database.
- Launch-at-sign-in remains disabled by default and changes only through the
  explicit tray action.
- Task and event deletion is permanent after confirmation; recoverable Trash is
  not implemented.

## Next action

Add dependency and persistent-sequence models before claiming dependency
ordering or saved sequence scheduling. Recurrence should target occurrence IDs
without changing recurrence rules by default. Re-run the native widget regression
checklist in `docs/windows-widget.md` whenever shell attachment, native input,
rendering, DPI behavior, process lifecycle, or packaging changes.
