# Progress

## Feedback Round 3 implementation checkpoint (2026-10-19)

- Implemented the icon registry and Release font verification, explicit Saved
  View creation/editing with sorting and zero-result saves, anchored named
  event colors, calendar right-click creation and day preview, tinted event
  blocks, cancelled title strikethrough, adaptive Month entry counts, Anytime,
  in-editor category/project creation, task-panel hierarchy and scrolling, and
  parent/subtask calendar presentation. No schema migration or native-widget
  source change was needed; schema remains v20.
- The supplied `docs/feedback/round-3/` markdown and eight named screenshots
  were absent, so the written requirements and isolated Release UI provided
  the visual reference. The prior packaged Material font lacked 25 of 30
  picker glyphs. The rebuilt Release font contains all 30. The Saved Views `+`
  previously opened generic Advanced Search and required a second hidden
  naming dialog, which made the creation path unclear. It now opens a labeled
  form with its name and Create action visible.
- `flutter analyze` found no issues; all 184 Flutter tests pass. The Windows
  Release build, packaged widget persistence self-test, and Release icon-font
  coverage check pass. Inno Setup 7.1.0 compiled
  `release/LifeManager-1.0.0-win-x64-setup.exe`, SHA-256
  `B14D64048D83C0070C1468DDDB9FF414AB2B63E7B4B2F1DA382415B7E4AB9976`.
- Disposable-profile Release UI inspection at 1266x713 covered dark and light
  themes, icon choices, task title placement and persistence, Saved View
  creation with zero matches, Month/Week calendar blocks and right-click menu,
  event color menu, and the final compact Month day preview. Narrow restored
  window, DPI scaling, populated busy-day overflow, and installed upgrade and
  native widget behavior still require manual acceptance. No installation or
  production database access occurred.

## Feedback Round 2 installer checkpoint (2026-10-19)

- The verified Windows Release bundle for commit `8fd380f` was packaged with
  `D:\vs code\Inno Setup 7\ISCC.exe` (Inno Setup 7.1.0). The compiled Dart
  payload contains the Feedback Round 2 task-editor, Today, focus, and work-log
  text, tying the Release bundle to the current UI checkpoint.
- Inno Setup compressed all 15 files in the Release bundle, including
  `life_manager.exe`, `life_manager_widget.exe`, `flutter_windows.dll`,
  `sqlite3.dll`, `data/app.so`, ICU data, Flutter assets, fonts, manifests,
  notices, and shaders. The packaged widget persistence self-test and targeted
  profile-isolation, native-widget-service, and Windows-theme tests pass.
- The source bundle contains no SQLite database, WAL/SHM file, personal
  settings file, log, or backup. The installer source also excludes those
  file types and packages only the Release directory; no personal profile was
  opened or modified during this checkpoint.
- The rebuilt artifact is
  `release/LifeManager-1.0.0-win-x64-setup.exe` (45,845,619 bytes), SHA-256
  `7DBB6DD5EF1A2E09F59C45381401D7BA6131DA82F67CE9ABC8737CE5AB0C7195`.
  Its file and product versions are 1.0.0. Installation, upgrade, and uninstall
  were not run and remain final manual acceptance work.

## Feedback Round 2 UI refinement checkpoint (2026-10-19)

- A Windows Release baseline was inspected at 1266×713 with a verified
  disposable APPDATA/LOCALAPPDATA profile. The personal database was not
  opened. The dark-theme Today, new-task, Calendar, task-row, running focus,
  stopped focus, live mini-timer, and work-log states were inspected in the
  rebuilt app. Light-theme Today and its task row were also inspected with
  readable contrast and synchronized native caption colors. Populated secondary
  screens, DPI scaling, and the native desktop widget remain manual visual
  acceptance work.
- Shared Material styling now defines restrained typography, 40 px button
  targets, consistent 10 px field/button corners, semantic field outlines and
  focus treatment, quiet dialog surfaces, and common divider/card treatment.
  Page headings use weight 600. The existing indigo/lavender accent, Windows
  frame, dark/light color schemes, and native caption synchronization remain.
- The task editor now keeps title, notes, scheduled day, deadline, category,
  and project in the primary path. Status/priority and estimates/schedule
  protection are labeled expandable groups which open when editing nondefault
  values. New-task resource guidance was removed, notes are more compact, and
  lower controls can scroll clear of the fixed Create/Save action. Task,
  subtask, and planned-session dialogs clamp to the available viewport.
- Today shows persisted counts for planned tasks, fixed events, and work
  sessions with direct Calendar actions and a more specific empty state. The
  sidebar timer has a distinct compact surface with truncation protection.
  The focus dialog clamps to the viewport, makes HH:MM:SS the visual center,
  uses explicit running/paused/stopped/review states, and separates recorded
  total from readable source/timestamp log rows. A disposable Release session
  visibly advanced from `00:00:00` to `00:00:06`, then stopped at `00:00:14`;
  the mini timer updated at the same time.
- Calendar week highlights today; month distinguishes event/session/task rows
  with icons, marks the selected date, adjusts preview density at narrower
  widths, and retains full labels in tooltips. Advanced Search keeps its result
  count visible outside the scrolling filter list. Advanced Search and Smart
  Reschedule clamp their large dialogs to the viewport.
- No domain model, schema, repository, personal settings, installer rules, or
  native-widget source changed. The first full test run found three test-flow
  regressions after editor grouping and one hidden Advanced Search result
  count; those were corrected without suppressing errors. Final validation is
  clean: `flutter analyze`, all 172 Flutter tests, the Windows Release build,
  the native Release build with zero warnings/errors, and both the packaged
  and native widget persistence self-tests pass.

## Feedback Round 1 checkpoint (2026-10-19)

- Profile audit found no startup sample seeding. Runtime SQLite resolves to the
  current user's `%APPDATA%\Life Manager\life_manager.sqlite`, while the
  installer targets `%LOCALAPPDATA%\Programs\Life Manager`. The previously
  recorded personal schema-v4 database can therefore reappear after an install
  for that Windows user. No personal database was opened, reset, or migrated.
  Settings now shows the active profile location; installer rules exclude SQLite
  files and the build script refuses a bundle containing them. Disposable tests
  verify a clean root starts empty while an existing root retains its task.
- Schema v16 extends existing fixed events with location, all-day, category,
  color/icon references, reminder metadata, and date-only recurrence. A bounded
  calendar projection uses the existing recurrence arithmetic; only changed or
  cancelled dates use extra rows. Users can set selected weekdays and an end
  date, edit one date, split from this and future, edit the remaining series,
  restore a cancelled date, end a series at a selected date, duplicate, or move
  all series generations to Trash. Historical dates and manual future overrides
  survive a series split. Day/week/month share an immediate persisted Events /
  Tasks / Both filter; planned sessions remain distinct from events.
- Schema v20 enables event reminder choices in the packaged Windows app. The
  existing tray companion checks one-off and recurring events, cancellation
  exceptions, and moved occurrences, and uses an atomic per-occurrence claim
  to avoid repeat balloons. It checks a five-minute recent window to prevent
  stale backlogs; Windows notification delivery still needs manual acceptance.
  The control is disabled if the native companion is missing. Event icons and
  calendar overlap indicators are available. Whole-family Trash restoration
  and manual Windows GUI acceptance remain open.
- New event, recurrence, cancellation, split, migration, profile-isolation,
  calendar-filter, and conflict-indicator tests pass.
- Task rows now offer Start Task (status only), End Work (on hold), and Start
  Focus Session (one transactional timer plus In Progress status). Focus opens a
  live HH:MM:SS stopwatch dialog with Pause/Resume/Stop, recorded total, and
  second-level work-log timestamps. The sidebar mini timer shows the active
  task, live elapsed time, and Pause/Resume/Stop actions. Stopping a timer never
  completes its task. Focus and sub-minute repository tests and a row-action
  widget test pass; manual Windows timer UI acceptance is still needed.
- The Flutter light/dark surface and foreground colors now pass through a
  runner MethodChannel to supported DWM caption attributes. The native
  minimize/maximize/close frame and Snap behavior remain Windows-owned. A
  widget test observes both color changes, and the Windows Release build passes.
  Actual maximized/restored, DPI, and keyboard behavior still need manual
  Windows acceptance.
- Schema v17 stores built-in icon keys for tasks, recurring task series,
  categories, and projects; event icons use the v16 event field. A searchable
  compact picker supports selection and reset. Task rows, category/project
  sidebar entries, editor, and calendar events render those keys with defaults.
  SQLite backups and portable exports carry the keys; database triggers remove
  keys only when the owning record is permanently deleted. Icon persistence
  tests pass. Native task widget keeps its own established vector icons.
- Schema v18 adds independent task checklist items and one-level parent links
  for true subtasks. Checklist add/edit/remove/reorder/toggle and progress are
  in task details; child tasks keep their own schedule, status, notes, and
  priority. Parent rows expand/collapse children and show progress. Parent
  Trash/restore hides and reveals children without deleting their rows; native
  widget filters children of hidden parents. Repository persistence/restore and
  task-detail widget tests pass.
- Schema v19 adds progressive recurring task plans separate from static
  checklists. New recurring tasks can define ordered activities in the editor;
  existing scheduled series can edit a plan in task details. Assignments are
  stored per occurrence and shown in Calendar. Users can carry an unfinished
  or skipped step, choose a step manually, add/remove/reorder future steps, or
  explicitly repeat after the last step. Past, completed, and manual snapshots
  survive future plan and recurrence-rule edits. Repository tests cover skips,
  plan changes, rule splits, persistence, and v18 migration; a widget test
  covers Calendar and editor access.
- Final automated checkpoint: `flutter analyze` clean; all 172 Flutter tests
  pass, including a visible two-second stopwatch update and mini timer
  navigation/controls. The Windows Release build passes on schema v20. The
  native Release build has zero warnings/errors; its source and packaged
  persistence/reminder self-tests pass. Inno Setup 7.1.0 compiled the installer
  from that bundle, with no SQLite file included. Disposable v18→v20 and
  v19→v20 migrations preserve records and pass `PRAGMA integrity_check`.
  Manual Windows GUI and tray notification acceptance remain pending. No
  production database was opened or migrated.
- Next: use the isolated-profile manual acceptance checklist in
  `docs/ACCEPTANCE.md`. Whole-family event Trash restoration remains a
  possible follow-up; individual cancellation and restoration work now.

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
- Actual work (schema v10) stores timer runs and UTC work intervals separately
  from planned sessions. Task details offer start, pause, resume, stop, and
  historical manual logs with audited corrections. A running timer has a
  sidebar control and minute checkpoints. After a gap of over two minutes,
  users explicitly keep elapsed time or stop at the last checkpoint;
  unreviewed time is not added to the displayed total. Overlapping intervals
  count once in the displayed total. The native widget accepts schema v10
  without editing time records.
- Templates (schema v11) save standalone tasks, current recurring rule
  definitions, and project task collections as reusable snapshots. Applying
  one creates new task, project, and recurrence IDs and does not copy
  completion or work history. Project templates copy internal prerequisite
  edges with new task IDs; external links and planned sessions are disclosed
  as omitted. Relative planned/deadline dates shift from a chosen anchor day,
  while undated tasks stay undated. Project creation rolls back fully on a
  conflict; stale/deleted template revisions are rejected. The Templates
  manager previews the destination and generated task dates before Apply.
- Advanced task search and saved views (schema v12) filter persisted tasks by
  text, status, category, project, priority, relative planned/deadline dates,
  recurrence, and unfinished prerequisites. Matching tasks preview before a
  view is saved. Named views have no count limit, appear in the sidebar,
  recalculate from current records, and support editing and deletion with
  stale-revision rejection. Quick Search still locates categories and
  projects. Saved views below Categories retain the category creation
  control's reachability in compact windows; closed-only selections cannot
  launch Smart Reschedule.
- Automatic backups create standalone SQLite snapshots from the live WAL
  database with `VACUUM INTO`, then verify SQLite integrity before publication.
  Startup takes a backup before any schema upgrade and refuses to open or
  migrate the database if that safety step fails. While running, the app
  checks daily backup eligibility every six hours and on resume. The latest
  14 automatic snapshots are retained; manual and pre-upgrade copies are
  preserved. A Backups dialog lists verification state and allows a manual
  snapshot. Restore is reviewed and scheduled for the next launch. The
  selected file is integrity checked and hashed; startup closes the native
  companion, saves a Before restore rollback snapshot, replaces SQLite data
  through its backup API, verifies the result, and migrates an older snapshot
  forward. A changed snapshot or busy database leaves the restore pending;
  the startup error screen can cancel that request and retry the current
  database.
  Recoverable Trash is implemented in schema v13.
- Schema v13 adds recoverable task archiving and Trash for tasks, projects,
  categories, fixed events, planned sessions, individual recurring occurrences,
  and whole recurring families. Parent deletion hides descendants without
  changing their own state. Archive and Trash can restore records, including
  completed work and linked history, in transactions. Future recurring
  occurrences stop materializing while their family or parent is hidden. The
  native widget excludes archived and trashed records on v13. Explicit
  permanent deletion checks relationships first and records tombstones; it
  never purges automatically at startup. Unlinked occurrence tasks can be
  purged while retaining their series slots. A series can be purged only after
  its occurrence tasks and edit history are resolved.
- Statistics and reports calculate actual task completions, creations, planned
  dates, recorded work, habit outcomes, and project completion counts over
  last-7, last-30, last-90, or custom local-day ranges. Work is clipped to
  days and overlaps count once; unreviewed timer time ends at the last
  checkpoint. Archived task history is included, Trash is excluded. Goal
  counts are explicitly labeled as current rather than historical. The
  Reports view reads current persisted snapshots and never fabricates data.
- Schema v14 adds opt-in Windows tray notifications for open due/overdue tasks
  and a daily planned/due summary at a chosen local time. Both are off by
  default. The native companion can start in a background tray mode without
  showing the desktop widget, continues after the main window closes, and
  checks every 30 seconds. A unique per-type/local-day delivery record avoids
  duplicates after restart. Delivery occurs only in the first hour after the
  selected time while the companion is running; no missed-day backlog is sent.
  Archived, trashed, completed, and cancelled tasks are excluded. The dialog
  exposes the opt-in and time controls; the app starts the companion at launch
  when notifications are enabled. Windows notification visibility still needs
  manual acceptance on an isolated profile.
- Import/export publishes a standalone SQLite snapshot at a chosen `.sqlite`
  path and stages an external Life Manager database in managed backups. Import
  checks integrity, supported schema, required tables, and foreign keys.
  Export also checks required tables and foreign keys before publication.
  The restore preview shows source, schema, and size; replacement requires an
  explicit choice and occurs only on the next launch through the existing
  Before restore rollback flow. Cancelling either picker or the preview leaves
  the active database unchanged.
- Schema v15 adds task resources: managed attachments, external file and folder
  references, and website/application URLs. Managed attachment bytes live in
  SQLite with stable UUIDs, original filenames, size, and SHA-256 digest. The
  attachment limit is 16 MB per file. This makes automatic backups, manual
  snapshots, Before restore backups, and portable SQLite exports complete for
  managed attachments without a second archive or arbitrary extraction path.
  External file and folder contents are never copied into backups. The task
  editor supports adding, opening, renaming, editing URLs, availability display,
  and confirmed removal. Files opened from managed storage are verified and
  placed in an app-owned cache; executable/shortcut extensions are blocked.
  Task archive and Trash retain resource rows; permanent task purge cascades
  them. Resource changes are not copied by task templates or recurrence rules:
  each task or occurrence owns only its explicitly added resources.
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
- `flutter test`: 138 passing tests, including engine, database, migration,
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
- Schema v10 validation: disposable v9-to-v10 migration and restart,
  timer state transitions, recovered-timer decision, manual log correction,
  overlap accounting, and dialog interactions pass. `flutter analyze` is clean;
  all 88 Flutter tests, native Release build/self-test, Windows Release build,
  and packaged companion self-test pass. Manual Windows UI acceptance remains
  pending.
- Schema v11 validation: disposable v10-to-v11 migration and restart,
  standalone and recurring template creation, project dependency remapping,
  date shifts, atomic rollback on project-name conflict, and manager UI flows
  pass. `flutter analyze` is clean; all 94 Flutter tests and native Release
  build/self-test, Windows Release build, and packaged companion self-test
  pass. Manual Windows UI acceptance remains pending.
- Schema v12 validation: disposable v11-to-v12 migration and restart,
  combined relative-date/project/blocker filtering, unlimited persisted views,
  stale edits, and search/save UI pass. `flutter analyze` is clean and all 98
  Flutter tests, native Release build/self-test, Windows Release build, and
  packaged companion self-test pass. Manual Windows UI acceptance remains
  pending.
- Backup validation: live WAL snapshot isolation, independent later writes,
  pre-upgrade schema preservation, automatic retention, and manual creation
  pass on disposable databases. `flutter analyze` is clean; all 101 Flutter
  tests, the Windows Release build, and packaged companion self-test pass.
  The Backups dialog still needs manual Windows UI acceptance.
- Restore validation: disposable round trips preserve a rollback snapshot,
  reject changed size or content digest, wait for an active reader, and
  upgrade an older restored schema. `flutter analyze` is clean; all 106
  Flutter tests, Windows Release build, and packaged companion self-test
  pass. The restore dialog and next-launch flow still need manual Windows
  UI acceptance on an isolated profile.
- Trash validation: disposable v12-to-v13 and realistic v4-to-v13 migrations,
  parent restoration order, linked-record purge rejection, occurrence identity,
  family archive/Trash, 30 day retention without automatic purge, event/session
  restore, foreign key checks, and Archive/Trash widget restore flow pass.
  `flutter analyze` is clean; all 122 Flutter tests, native Release self-test,
  and Windows Release build pass. Manual UI acceptance is pending.
- Report validation: range bounds, midnight clipping, overlapping intervals,
  unreviewed timer checkpoint, archived versus trashed task inclusion, and
  date-span UI interaction pass. `flutter analyze` and all 122 Flutter tests
  pass. Windows Release build and packaged widget self-test pass. Manual UI
  acceptance is pending.
- Notification validation: disposable v13-to-v14 migration, default-off
  settings, invalid-time rejection, dialog opt-in and companion launch,
  native due/summary claim timing, duplicate suppression, disabled settings,
  and trashed-task exclusion pass. `flutter analyze` is clean and all 125
  Flutter tests pass. Native Release self-test, Windows Release build, and
  packaged companion self-test pass. On an isolated
  Windows profile, the Notifications dialog showed both toggles off, Archive
  and Trash tabs rendered, a task archived and restored through the UI, and
  Reports rendered persisted empty counts. Actual tray balloon visibility,
  notification opt-in via Windows UI, Trash restoration, and populated Reports
  remain manual acceptance work.
- Import/export validation: on disposable databases, a live WAL export is
  consistent and independent of later writes; import and reviewed restore
  preserve task IDs, categories, projects, and relationships; Before restore
  contains the replaced database. Invalid SQLite, truncated data, newer
  schema, missing tables, and broken foreign keys are rejected without
  changing the active database or publishing a managed backup. Existing export
  files are retained; exports with broken relationships publish no file;
  cancelled pickers and cancelled restore review perform
  no replacement. Dialog tests verify preview details and disabled controls
  while a picker is pending. `flutter analyze` is clean; all 131 Flutter tests,
  Windows Release build, and packaged widget self-test pass. Native Windows
  file picker interaction and next-launch restore remain manual acceptance.
- Task resources validation: disposable v14-to-v15 migration preserves tasks;
  managed bytes survive source-file removal, archive, Trash, and restoration,
  while permanent task deletion removes the association. Duplicate filenames
  get distinct UUIDs; invalid URLs, missing paths, oversized files, and a
  source changed during copying leave no resource row. Portable export/import
  restores managed bytes and rejects corrupted content or unsafe original
  filenames. A blocked restore retains the live attachment and pending request
  until the lock clears. Widget tests cover attach, rename, confirmed removal,
  and a missing external file remaining visible. `flutter analyze` is clean;
  all 138 Flutter tests, Windows Release build,
  and packaged widget self-test pass. The native widget self-test checks v15
  compatibility. Native Windows picker/opening flows still need manual
  acceptance on an isolated profile.

## In progress

- Milestone 3 follow-up: manual recurrence UI acceptance, richer
  multi-window availability editing,
  and drag-to-reorder sequence UX. Sequences currently use accessible up/down
  controls. A sequence owns at most one position per task, and a task can belong
  to one sequence.
- Reproduce the reported Windows task-row checkbox duplication and capture its
  first exception if it occurs again; widget tests remain stable.

## Not yet implemented

- Windows Hello and complete settings/preferences coverage. Habit and
  session-specific reminders remain future work.

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
- The production schema-v4 database has not been opened or migrated during the
  v13 implementation. Only disposable databases were upgraded in automated
  tests. Before eventual production upgrade, the startup backup must verify a
  consistent snapshot.
- V14 automated tests and the successful manual UI launch used disposable
  databases. An initial manual launcher did not inherit the intended APPDATA
  override and was stopped before UI interaction. The production SQLite main
  file and WAL modification times were unchanged when checked afterward; no
  production migration was observed. A later launcher set APPDATA explicitly
  in the child process and its isolated SQLite file was verified before UI
  interaction.
- The manual UI acceptance profile is left at
  `%LOCALAPPDATA%\Temp\life-manager-v14-manual-20261018` after its window was
  closed; automated cleanup was rejected by command review. It contains only
  disposable test data and can be removed later.
- PID 19828 was absent on inspection; its executable path and command line
  therefore could not be verified. The isolated profile above was left in
  place. No production database or settings were used for import/export tests.
- Trash retains records indefinitely unless the user explicitly confirms
  permanent deletion. The displayed 30 day date is a retention guide, not an
  automatic purge date. Records with linked history can remain nonpurgeable
  until those links are safely resolved. Deleted category/project names remain
  reserved while in Trash.

## Windows v1.0 finalization checklist (2026-10-18)

- [x] Shared Flutter/native app-lock implementation, PIN lifecycle, locked
  notification policy, and process-bound widget session. Automated checks pass;
  real two-process Windows acceptance remains pending.
- [ ] Persisted Windows settings audit and completion.
- [x] Per-user installer compiled with Inno Setup 7.1.0. Installed
  upgrade/uninstall checks remain in the acceptance matrix.
- [ ] Disposable migration audit: v4-to-v15 fixture preserves task, project,
  category, event, session, scheduling history, IDs, foreign keys, and resource
  index. Broader historical data fixtures and corruption cases remain.
- [ ] Backup, restore, import/export, and attachment portability regression coverage.
- [ ] Integrated UI, native companion, accessibility, and performance review.
- [x] Full Flutter analysis/tests and Windows Release/native self-tests at this
  checkpoint, plus the native package vulnerability audit. Repeat after
  subsequent source edits.
- [ ] Isolated Windows manual acceptance. Status matrix in `ACCEPTANCE.md`.
- [x] Draft release instructions, notes, limitations, and acceptance record in
  `RELEASE.md` and `ACCEPTANCE.md`; finalize after installer and acceptance.

## Finalization checkpoint

An explicit read-only schema gate now stops automatic v4-to-v15 migration until
the user approves a verified Before upgrade backup and migration in the app.
Automated checks did not open the personal schema-v4 database. The rebuilt
Release app was launched twice with verified isolated APPDATA and LOCALAPPDATA
directories; the default-disabled Privacy dialog rendered at 1266×713 and
was closed without changing settings. The latest full suite before the final
migration/icon edits passed 142 tests; the targeted migration-gate and v4-to-v15
tests passed separately. Final `flutter analyze` is clean, all 146 Flutter
tests pass, the Windows Release build and packaged widget self-test pass,
and the native dependency audit reports no vulnerable packages from the
configured sources. The final Release app opened on an isolated profile;
a disposable task was created and shown after a full restart. The native
companion now honors the explicit APPDATA override (the .NET special folder
had resolved the real profile), with a self-test guarding this isolation.
Inno Setup 7.1.0 compiled the existing project successfully. The final
installer is `release/LifeManager-1.0.0-win-x64-setup.exe` (45,791,473 bytes;
SHA-256 `51672ABA224E95762C9FBD82C7ED1671E0DE2C195F421348FF55961CF13C5FBC`).
Both setup version fields report 1.0.0. The 15-file Release bundle contains
both executables and no database or log file. The installer is unsigned.
The installer configuration audit found a stable AppId, per-user privileges,
an installation path outside `%APPDATA%`, no install/uninstall deletion section,
and no widget auto-start registration. These static checks do not replace an
installed upgrade/uninstall test.
After compilation, all 146 Flutter tests passed, `flutter analyze` was clean,
the packaged widget self-test passed with an isolated profile, and the native
dependency audit found no vulnerable packages in the configured sources.
An initial parallel `flutter analyze` attempt hit a Flutter SDK cache race;
its sequential retry passed. No installer installation was attempted on the
normal Windows profile, so installed upgrade/uninstall behavior remains
unverified. No production database was opened or migrated.

Next: verify the installer in a disposable Windows installation or with user
approval for an installed acceptance test, then manually verify
task resource selection/opening through native Windows dialogs on an isolated
profile. Manually verify
import/export through the native Windows file picker and the reviewed
next-launch restore using the isolated profile. Manually verify a due reminder and daily summary
through the Windows tray on an isolated profile, including after closing the
main window. Manually
exercise Archive, Trash, and Reports on an isolated profile. Manually
exercise the recurrence editor, Smart Reschedule collision choices, and Habits
screen on an isolated Windows profile before opening the production schema-v4
database. Time-of-day recurrence is outside the current date-only task model;
planned work sessions retain their own UTC times. Re-run the native widget
regression checklist in
`docs/windows-widget.md` whenever shell attachment, native input, rendering,
DPI behavior, process lifecycle, or packaging changes.
