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
- The All Tasks Schedule History toolbar action uses a reliable clock-arrow icon
  with explicit light/dark, hover, focus, and disabled-state colors.
- Schema v4 persists editable availability, task schedule protection, focused
  manual/Smart scheduling history, safe undo, and previous/original restoration.
  Stale previews are rejected and later manual schedules are protected.
- Schema v5 adds persistent named task sequences and cross-project prerequisite
  links. Sequence order can be edited with accessible move controls, and the
  sequence can be sent to Smart Reschedule in its stored order. Prerequisites
  are edited from task details, cycles are rejected transactionally, and
  incomplete prerequisites appear as blocked indicators. Smart Reschedule
  warns about proposals before unfinished prerequisites and rejects applies
  that gained an unreviewed conflict after preview.
- Recurrence foundation (schema v6): date-only rules support daily, weekly,
  selected weekdays, monthly, yearly, and interval-based schedules with end
  dates/counts. The task editor creates a series; fixed occurrences are created
  only for bounded task-list/calendar windows with stable UUIDs. Each is an
  independent task. Completion-based rules create the next pending occurrence
  from the actual local completion day in the same transaction; both Flutter
  and the native widget perform this write. Occurrence edits and reschedules
  are tracked separately from the series, and a selected occurrence can be
  explicitly skipped. Schema v7 extends this foundation with linked series
  versions and reviewed edits.
- Recurrence series editing (schema v7) previews This and Future or Entire
  Series changes from an explicit boundary. It preserves completed and
  individually changed occurrences and their links, reuses compatible task
  IDs, excludes only untouched generated occurrences, and requires a choice
  for each same-day collision. Apply rejects changed tasks, links, occurrences,
  or series revisions and writes the new version and audit record in one
  transaction. Smart Reschedule asks before moving an occurrence onto another
  date in its family; Keep Both and Skip Moved are supported, while Combine is
  unavailable for distinct scheduled tasks. The native widget accepts schema
  v7 and respects completion-series version boundaries.
- Habits (schema v8) are separate from recurring tasks. The Habits screen
  creates Yes/No, minimum-target, and maximum-limit habits with fixed custom
  schedules. Users can log or correct historical days, clear audited logs,
  mark and remove rest days, and archive or restore habits. Week/month/year
  rates and scheduled-day streaks derive from persisted values; missing days
  create no task backlog. Future outcomes are rejected. Habit reminders and
  native widget habit actions remain future integration work.
- Goals (schema v9) have targets, start days, deadlines, milestone checkpoints,
  manual adjustment history, linked task/project/binary-habit progress,
  explicit completion, and reversible archive. Direct and project links count
  each completed task once. The Goals screen exposes progress, links,
  milestones, history, and correction controls. Today links to unfinished goals
  due within seven days.
- Stale completion now rejects a newer task edit, and task duration input
  rejects invalid text instead of silently clearing the estimate. Prerequisite
  edits compare task revisions, and the narrow task editor keeps unsaved fields
  after saving prerequisites.
- Quick Search opens from the sidebar or Ctrl+K and searches persisted task
  titles/notes plus category and project names. Results navigate to the real
  task, category, or project. This is an in-memory search over the loaded
  workspace; advanced filters, tags, and saved views remain unfinished.
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
- `flutter test`: 82 passing tests, including engine, database, migration,
  stale-apply, undo/restoration, split, persistence, and preview/Apply coverage.
- Native Release build and disposable database/settings self-test: passing.
- Native dependency audit: no vulnerable packages reported.
- `flutter build windows` Release and Debug packages succeed and contain both
  `life_manager.exe` and `life_manager_widget.exe`.
- Packaged `life_manager_widget.exe --self-test`: passing.
- `flutter build windows --release`: passing at the previous checkpoint; package
  contains the main app and native companion.
- Manual visual check: the Release task-list entry point opened the themed Smart
  Reschedule workspace with the real current scope, selected tasks,
  Availability, Generate preview, Cancel, and disabled-until-preview Apply. It
  was closed without applying changes. Automated widget coverage verifies the
  preview and persisted Apply path.
- The native companion never creates or migrates the production database; it
  accepts schema v4-v9, enables foreign keys and a busy timeout, and uses
  parameterized transactional writes. Automated tests use an isolated database.
- Milestone B validation: focused v4→v5 migration, dependency-cycle/rollback,
  stale-editor, sequence persistence, and joint schedule-conflict tests pass.
  Native Release build and self-test pass for both accepted schema versions.
  `flutter analyze` is clean, `flutter test` passed 45 tests, and the Windows
  Release rebuild passed with the schema-v5-compatible widget companion.
  Quick Search and prerequisite editing have widget-level interaction tests.
  New GUI flows still need manual Windows acceptance testing.

- Recurrence foundation validation: v5-to-v6 and v4-to-v6 disposable
  migration tests pass; recurrence rules, repository behavior, native v6
  self-test, and task-editor creation have focused regression coverage.
  `flutter analyze`, all 54 Flutter tests at the first v6 checkpoint, the native Release build, the
  Windows Release build, and the packaged companion self-test pass. Manual
  recurrence UI acceptance has not been performed.
- Recurrence follow-up: the widget editor now preserves a completed task's
  original completion timestamp. Native self-test covers completion through
  both checkbox and editor. The recurrence rule snapshots selected weekdays
  and requires the first planned day to be one of them. Smart Reschedule has a
  regression test proving it moves one occurrence while leaving nominal dates
  and the rule intact. `flutter analyze`, all 56 Flutter tests, native Release
  build/self-test, Windows Release build, and packaged companion self-test pass.
- Completion-based skip recovery: a skipped occurrence remains in history and
  does not invent a completion time. Task details now offer an explicit resume
  day for that series, with a transactional successor and duplicate guard.
  Disposable restart and resume tests pass. `flutter analyze`, all 58 Flutter
  tests, Windows Release build, and packaged widget self-test pass. This
  control still needs manual Windows UI acceptance.
- Schema v7 validation: disposable v6-to-v7, v5-to-v7, and v4-to-v7 migrations,
  series splits, completed and linked history, collision choices, stale
  previews, and editor interactions pass. `flutter analyze` is clean; all 70
  Flutter tests pass. Native Release build and self-test, Windows Release
  build, and packaged companion self-test pass. The new GUI flows still need
  manual Windows acceptance.
- Schema v8 validation: disposable v7-to-v8 migration and restart persistence,
  historical correction, rest-day and streak calculations, archive safety, and
  a narrow-screen Habits widget flow pass. `flutter analyze`, all 77 Flutter
  tests, native Release build/self-test, Windows Release build, and packaged
  companion self-test pass. Manual Windows UI acceptance remains pending.
- Schema v9 validation: disposable v8-to-v9 migration, direct/project
  double-count prevention, binary-habit links, manual corrections, milestone
  editing, archive/completion, and Goals UI interactions pass. `flutter
  analyze` is clean; all 82 Flutter tests pass. Native Release build and
  self-test, Windows Release packaging, and packaged companion self-test pass.
  Manual Goals UI acceptance remains pending.

## In progress

- Milestone 3 follow-up: manual recurrence UI acceptance, richer
  multi-window availability editing,
  and drag-to-reorder sequence UX. Sequences currently use accessible up/down
  controls. A sequence owns at most one position per task, and a task can belong
  to one sequence.
- Reproduce the reported Windows task-row checkbox duplication and capture its
  first exception if it occurs again; widget tests remain stable.

## Not yet implemented

- Timer, templates, advanced search/saved views, backups, Trash,
  notifications, privacy controls, import/export, and installer packaging.

## Environment and data notes

- Android SDK command-line tools and licenses remain incomplete; Android is
  outside the current milestone.
- Existing task/category/project/event/session data is migrated forward in place;
  Smart Reschedule does not reset the production database.
- The existing production database is schema v4. A consistent SQLite online
  backup with integrity check `ok` was written to
  `%APPDATA%\Life Manager\backups\pre-schema-v7-20261018T052232Z.sqlite`.
  The production database was not migrated or modified during this checkpoint.
- Launch-at-sign-in remains disabled by default and changes only through the
  explicit tray action.
- Task and event deletion is permanent after confirmation; recoverable Trash is
  not implemented.

## Next action

Implement timer-based and manual actual work tracking, preserving planned
sessions and their independent outcomes. Then continue templates,
templates, backups/Trash, and the remaining Windows V1.0 roadmap. Manually
exercise the recurrence editor, Smart Reschedule collision choices, and Habits
screen on an isolated Windows profile before opening the production schema-v4
database. Time-of-day recurrence is outside the current date-only task model;
planned work sessions retain their own UTC times. Re-run the native widget
regression checklist in
`docs/windows-widget.md` whenever shell attachment, native input, rendering,
DPI behavior, process lifecycle, or packaging changes.
