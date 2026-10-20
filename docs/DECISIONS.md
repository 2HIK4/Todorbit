# Decisions

- **Public branch and existing tag (2026-10-20):** prepare `main` as a linear
  descendant of the reviewed development branch, preserving `master`, the
  development branch, and all history. Keep `v1.0.3` and its uploaded assets
  unchanged. The tag snapshot contains an incorrect README screenshot even
  though the application source and binary digests match; do not silently
  retag or replace packages to repair documentation.


- **Public name and license (2026-10-20):** the creator selected Todorbit and
  explicitly approved the proposed MIT text with copyright to Hussam Alkhatib.
  Preserve the orbit artwork, stable installer AppId, legacy TodoPilot and Life
  Manager profile paths, and native IPC identity. The name choice is not formal
  trademark clearance, and installed rebrand acceptance remains open.
- **Release package integrity:** derive the native widget's published version
  from Flutter's build version, and reject a bundled widget whose file version
  disagrees with `pubspec.yaml`. Bundle the applicable .NET runtime and
  SQLitePCLRaw license and third-party notices alongside Flutter's NOTICES.Z.

- **Feedback round 3:** keep nullable task planned/deadline dates in the
  existing schema; an undated task belongs in Anytime and remains visible in
  All Tasks. Persist Saved View sorting as an optional filter JSON value, so
  old views retain their current order without a migration. Use compile-time
  Material icon constants and verify the Release font cmap against the full
  registry. Keep calendar navigation in place for a day preview and reserve
  Day View for its explicit action. Apply Apple Design guidance on hierarchy,
  forms, popovers, typography, icons, and accessibility through Flutter while
  retaining Windows caption and context-menu behavior.

- **Feedback round 2 UI hierarchy:** preserve the existing Windows frame and
  indigo/lavender identity. Set shared Material typography, field focus,
  button, card, and dialog rules in the app theme. Keep task title, notes, and
  planned dates visible; make status/priority and effort protection discoverable
  expandable groups. Preserve the fixed Save action and allow extra scroll
  beyond lower controls. Do not change persistence or the native widget for a
  visual-only revision. Use actual event/session counts on Today and separate
  them from date-only tasks.
- **Event reminders (schema v20):** use the existing native tray companion
  for offline delivery. Project recurring event dates and exception payloads
  in the companion, then claim `(event, nominal date, start instant)` in SQLite
  before showing a balloon. Check only a five-minute recent window to avoid
  stale backlogs after sleep or a long shutdown. The companion must be running
  and Windows must permit tray notifications; the UI disables this control
  when the packaged companion is absent.
- **Progressive recurring plans (schema v19):** keep ordered study activities
  separate from static checklists and project sequences. A plan belongs to the
  recurrence family; each materialized occurrence stores a text snapshot and
  calculated step index. The default advances on scheduled dates. A skipped or
  unfinished occurrence can explicitly carry its activity forward; the user
  can manually assign a different step. Future untouched assignments are
  recalculated after plan or rule edits, while past, completed, and manual
  assignments retain their snapshots. Finishing the plan leaves later tasks
  without a study activity unless the user chooses repeat or adds steps.
- **Windows v1.0 privacy:** keep the optional lock outside SQLite as UI privacy,
  with a PBKDF2-HMAC-SHA256 PIN verifier in per-user settings and a short-lived
  process-bound session shared with the native companion. The companion
  independently blocks task reads/writes and paints no task data when the
  session is absent, expired, or unreadable. Wrong-attempt delays persist across
  launches. This does not encrypt user data; Windows Hello is deferred rather
  than represented as working.
- **Migration consent:** inspect `PRAGMA user_version` read-only before the
  startup backup and database open. Require an explicit in-app approval for
  older schemas, then retain the existing verified Before upgrade backup and
  migration path. Development and automated QA continue to use disposable
  databases only.
- **Windows installation:** use a per-user Inno Setup 7 project with the whole
  Flutter Release directory, including the self-contained native widget.
  Application files live separately from `%APPDATA%` data; normal uninstall
  retains personal data. Inno Setup 7.1.0 compiles the existing project;
  installed upgrade/uninstall acceptance remains open because no installer
  installation is authorized on the normal Windows profile.

- **Windows-first offline Flutter:** reuse the working scaffold and leave Android as a future target.
- **Drift + SQLite:** use a background database isolate, explicit schema migrations, and a per-user support directory. The current `sqlite3` package bundles native SQLite; the end-of-life `sqlite3_flutter_libs` package is not used.
- **Riverpod:** keep shared UI state in one controller for the first milestone; split by feature as complexity grows.
- **Dates:** local date-only strings for planned days/deadlines; UTC instants for modification and completion. This avoids inventing times for date-only tasks.
- **Honest scope:** unavailable future views are documented rather than represented by fake screens or data.
- **Windows data path:** use the per-user `APPDATA` directory directly. This removes the path-provider plugin and its Windows symlink build requirement; Android data path will be revisited when Android development begins.
- **Widget feasibility:** the separate `--widget` process uses documented `SetParent(GetDesktopWindow())`, but native traces and user testing show that this does not meet keyboard activation or `Win + D` requirements. The resulting `WS_CHILD` window belongs under the system desktop HWND, not an independently activatable Life Manager top-level window or Explorer's shell layer. Keep this as a failed prototype, not a completed widget. An Explorer `WorkerW`/`Progman` attachment could be evaluated only as an explicitly accepted, undocumented compatibility dependency with real Windows-version and Explorer-restart testing; do not silently substitute a floating or topmost window.
- **Native widget candidate:** keep the Flutter production prototype intact and evaluate a separate .NET companion. Parent only its display surface to Explorer's existing `SHELLDLL_DefView`; use a normal modal top-level quick-add window for keyboard input. This deliberately accepts an undocumented Explorer hierarchy dependency but avoids undocumented shell messages, focus loops, hooks, injection, and always-on-top behavior. The companion may access schema-v3 task rows through a guarded native repository, but it must not migrate or create the production database. Do not integrate it as production until the user manually verifies visibility, `Win + D`, layering, repeated input, and multi-monitor behavior.
- **Native rendering:** do not use a WinForms `Form` as the persistent shell child. Diagnostics show that the reparented Form processes `WM_PAINT` while its pixels remain black until capture, and a Form created with a foreign parent is subsequently moved into a hidden WinForms parking window. Use one directly created, owner-drawn native HWND with bounded invalidation after state changes; keep WinForms only for the activated Quick Add dialog. Retain the old Form host solely behind an explicit legacy diagnostic switch.
- **Native widget integration gate:** package the owner-drawn candidate as a self-contained sibling executable and expose it from the normal Flutter workspace, but label it as a candidate and preserve Flutter `--widget` as a development fallback until continuous visibility, `Win + D`, normal-window coverage, and Quick Add input are manually accepted. Do not merge this experimental branch before that gate passes.
- **Native widget promotion:** manual acceptance passed on 2026-10-17. The packaged owner-drawn companion is the supported widget, the Flutter workspace no longer labels it as a candidate, and `life_manager.exe --widget` delegates to `life_manager_widget.exe` before Flutter starts. Preserve the failed Flutter desktop-child only behind `--legacy-flutter-widget` for explicit diagnostics; never select it from normal UI or startup registration.
- **Widget lifecycle and synchronization:** the companion, not the main app, owns the widget process and tray icon. Use a named mutex plus a local named pipe for commands, and filesystem notifications with a short debounce for cross-process SQLite refresh. Closing Flutter must not close the companion. Explorer recovery may recreate only the Life Manager child HWND with bounded retries; it must never stop, restart, reposition, or inject into Explorer.
- **Windows reminders:** keep notification preferences in SQLite with opt-in defaults and local minute-of-day. The existing native tray companion checks due tasks and daily summary counts, including when Flutter is closed. It claims a unique type/day delivery row before showing one combined balloon to avoid repeats across restarts. A one-hour same-day window prevents stale backlogs; task dates remain date-only. The tray process must be running, and no sign-in registration is changed automatically.
- **Widget preferences and sign-in:** store geometry, monitor, and task view outside the task database in `%APPDATA%\Life Manager\widget-settings.json`. The optional per-user Run entry is changed only by an explicit tray-menu action and is disabled by default; development and automated tests must not enable it.
- **Shared appearance preference:** System/Light/Dark is authoritative in `%APPDATA%\Life Manager\appearance-settings.json`, watched by Flutter and the native companion without polling. Migrate the legacy widget theme once; keep geometry, selected task view, and sign-in choice in widget settings. A future widget-only override can be added explicitly without reintroducing two contradictory defaults.
- **Native widget editing surfaces:** preserve the owner-drawn Explorer child. Quick Add uses a temporary borderless activatable top-level surface aligned over the painted field; task editing uses a compact activatable dialog with optimistic concurrency. Do not add persistent child controls, keyboard hooks, focus timers, or synthetic input to the shell child.
- **Native widget views and geometry:** Today, Inbox, All Tasks, and Upcoming use the same schema-v3 semantics as Flutter. Dragging the empty header moves the child; custom hit testing supports all edges/corners, persisted logical bounds, per-monitor DPI scaling, and working-area clamping.
- **Fixed events:** store UTC instants, display in local time, and use interval overlap for multi-day calendar placement. Actual task deadlines remain independent date-only values.
- **Windows frame theme:** send the resolved Flutter surface and foreground
  colors to the runner and apply DWM caption attributes. Keep the standard
  non-client frame and system window buttons; the runner falls back to the
  Windows preference before Flutter's first frame.
- **Recurring events (schema v16):** extend the existing fixed-event records
  instead of adding a second calendar system. Keep UTC start/end instants and
  date-only local recurrence rules; project only the requested calendar window.
  Persist per-date cancellation or full override under the original nominal
  local date. Split a series into linked generations for future edits, moving
  future overrides transactionally while retaining earlier event details.
  The Calendar filter is a separate per-user preference and never mutates
  tasks, planned sessions, or event rows.
- **Task composition (schemas v17-v18):** built-in icon keys are SQLite data,
  not image files. Recurring task series may supply a default icon to generated
  occurrences, while an individual task can override it. Keep checklist items
  separate from task status and true child tasks. A one-level parent link lets
  children retain independent task metadata; hiding a parent hides its children
  in active Flutter and native views without deleting their records.
- **Work sessions:** store planned UTC intervals and a manual outcome independently of tasks. A transition to “In progress” records an actual start; elapsed upcoming sessions remain upcoming until confirmed.
- **Scheduling engine:** compute immutable previews from local availability windows against UTC event/session intervals. Keep application of changes disabled until availability settings, transactional history, and conflict review are wired together.
- **Smart Reschedule persistence:** schema v4 stores availability separately from
  focused operation/change history. Apply is one optimistic transaction checking
  both `updated_at` and reviewed scheduling values. Restore and undo append new
  operations and protect later manual schedules by comparing historical
  after-values; they never roll back completion, actual work, or unrelated fields.
- **No invented availability:** a migrated or new profile starts with no working
  windows. Repack is unavailable until the user configures weekly hours or date
  exceptions. Buffer defaults to zero and the minimum generated session is 15
  minutes.
- **Scheduling boundaries:** date-only task movement stays date-only; work
  sessions stay UTC intervals with local-time proposal generation. Dependencies,
  recurrence, and persistent sequences remain explicit future models. Current
  Push/Pull and Reorder operate only on the reviewed selection.
- **Native widget schema v4:** keep its repository narrow and non-migrating, but
  accept v4 and record a manual scheduling-history row transactionally when its
  task editor changes a planned date. Window hosting and lifecycle are unchanged.
- **Task relationships (schema v5):** named sequences and prerequisite edges are
  distinct tables. A task belongs to at most one sequence; moving it between
  categories or projects leaves sequence membership intact. Sequence membership
  edits replace the ordered list in one transaction with an optimistic sequence
  timestamp check. Prerequisite edits replace one task's edges transactionally
  and use a recursive query to reject cycles, including cross-project cycles.
  Completion does not follow prerequisite or sequence edges automatically.
  Smart Reschedule warns about unfinished prerequisites planned on or after the
  dependent's proposed day, using the prerequisite's proposed day when both
  move in one operation; a warning must be reviewed to apply that conflict.
  Prerequisite edits compare the loaded task revision, and manual Flutter date
  edits require an explicit override for each current prerequisite conflict.
  The native widget accepts schema v4 and v5 because its task columns are
  unchanged, but remains non-migrating. Its compact editor also asks for an
  explicit override when a schema-v5 planned date conflicts with prerequisites.
- **Quick Search:** use the already loaded workspace records for an immediate
  desktop search over tasks, notes, categories, and projects. It navigates to
  live records and does not persist stale result lists. Keep advanced filters,
  tags, and saved-view persistence for a later milestone.
- **Recurrence foundation (schema v6):** store a series rule and template apart
  from per-occurrence task rows. Persist an occurrence UUID, ordinal, and
  nominal local date so edits, reschedules, skips, and deleted-task tombstones
  cannot cause regeneration. Generate only a bounded date window when the task
  list or calendar needs it. Use UTC civil-date arithmetic for fixed rules and
  clamp missing month/year anniversary days to the last valid day. Store UTC
  completion instants; completion-based rules calculate the next local date
  from actual completion, then create at most one successor transactionally.
  The native widget accepts v6 and uses the same successor transaction.
  Editing a task occurrence leaves the series template unchanged. Defer
  future/all-series edits until the operation can preserve completed work,
  sessions, and dependencies and can ask about date collisions explicitly.
- **Completion-based skip:** skipping does not count as actual completion and
  therefore does not calculate the next day. The user can resume the series on
  a chosen planned day; that inserts one successor transactionally while the
  skipped occurrence stays in history.
- **Recurring series edits (schema v7):** link immutable rule generations with
  a family ID and active date boundaries. This and Future begins at the
  selected nominal occurrence; Entire Series begins at the earliest open
  materialized occurrence. Preserve completed, edited, rescheduled, skipped,
  and linked task rows. Remove only untouched generated rows that no longer
  fit. Reuse a compatible task/occurrence ID only by an explicit Combine
  choice. Keep Both creates two independent task rows; Skip New records a
  tombstone in the new generation. Compare series, occurrence, task, and link
  snapshots before transactional Apply and log the chosen actions. A new
  This and Future rule must anchor on or after the selected date so a count
  does not consume past occurrences.
- **Recurring Smart Reschedule collisions:** task moves remain occurrence
  specific. When a proposed planned day matches another task in the same
  family, require Keep Both or Skip Moved. Skip marks an unstarted, unlinked
  moved occurrence as skipped; linked or started work cannot be skipped here.
  Combining distinct tasks in scheduling has no safe semantics, so it is
  explicitly unavailable. Recompute the collision set at Apply and record
  each resolution under the scheduling operation.
- **Habits (schema v8):** store habits separately from task recurrence.
  Yes/No, minimum-target, and maximum-limit outcomes are date-only values.
  A missing log is unknown until its scheduled day passes; it never becomes a
  task. Rest days remove dates from progress denominators without fabricating
  successes. Retain entry logs when a rule changes, reject stale corrections,
  audit log changes, and keep archive reversible. The native widget continues
  task-only access and accepts the additive schema.
- **Goals (schema v9):** keep manual adjustments in an immutable signed ledger
  and derive linked contributions from current completed tasks and binary
  habit logs. Direct task links take precedence over project links so each
  task contributes once per goal. Milestones are thresholds and deliberate
  completion markers, not additive progress sources. Goal completion is an
  explicit choice independent of its numeric total; archive retains that
  state. Restrict habit links to Yes/No habits so later numeric target edits
  cannot silently reinterpret historical contributions.
- **Actual work (schema v10):** store timer intervals and manual logs apart
  from planned work sessions, which retain their own outcomes. One timer may
  be active at a time. Running timers checkpoint once a minute while the app
  is alive; a gap over two minutes requires an explicit keep-or-stop decision
  before further timer actions. Stopping at the checkpoint preserves only
  confirmed elapsed time. Manual log edits and clears retain an audit record;
  interval totals merge overlaps to prevent inflated actual time. The native
  widget only validates schema compatibility.
- **Templates (schema v11):** store versioned JSON recipes separate from live
  task/project rows. Capture the current recurrence definition for routine
  templates, not materialized occurrence history. Apply creates fresh UUIDs,
  resets task status, shifts date offsets from a user-selected anchor, and
  remaps only internal project prerequisites in one transaction. Surface
  omitted sessions and external dependencies to the user. A project with
  recurring tasks must save those as separate routine templates so its
  recurrence links are not silently lost. Compare the template revision at
  Apply and delete.
- **Saved views (schema v12):** store named, versioned filter definitions
  independently of tasks. Search reads the controller's current persisted task
  snapshot and matches relative dates when viewed, so a Today filter rolls
  forward. An empty status selection means any status. Keep Quick Search for
  category/project navigation; advanced search is task-focused. Compare the
  view revision for edits/deletion, and keep views with deleted category or
  project IDs visible as empty until the user edits them.
- **Automatic backups:** snapshot SQLite through `VACUUM INTO` instead of
  copying a live database/WAL pair. Verify source and snapshot integrity and
  create a snapshot before any migration. Refuse startup if that safety step
  fails. Keep 14 managed daily backups while retaining manual and pre-upgrade
  copies. A snapshot can be created while SQLite is open.
- **Reviewed restoration:** queue only managed, verified backup files and
  record their SHA-256 digest. On the next launch, close the native companion,
  create a Before restore rollback snapshot, then use SQLite's
  [online backup API](https://www.sqlite.org/backup.html) to replace the
  database with an exclusive destination connection. Verify integrity/schema
  before opening Drift. Keep the pending request on any failure, so the user
  can retry or cancel. Older snapshots migrate forward after replacement.
- **Portable database transfer:** use the same SQLite `VACUUM INTO` snapshot
  path for export and for staging an imported file. Validate the staged copy's
  integrity, compatible schema, expected Life Manager tables, and foreign
  keys before publishing it in managed backups. Export checks the same table
  and relationship constraints before publishing a portable file. The native
  Windows file dialog selects paths without changing the active database.
  Import then uses the
  existing reviewed next-launch restore and Before restore rollback mechanism;
  cancelling review leaves the staged snapshot available as a manual backup.
- **Task resources (schema v15):** keep managed attachment bytes inside SQLite
  with their task row, UUID, original filename, length, and SHA-256 digest.
  Limit each copied file to 16 MB and reject changes detected during reading.
  This keeps the existing versioned SQLite snapshot format complete for managed
  data; no separate archive extraction or second restore commit is needed.
  Verify attachment hashes and filenames before exporting, scheduling, or
  applying a restore. Store external file/folder paths and URLs as references
  only; never copy or delete external files. Each recurring occurrence owns its
  own resources. Archive/Trash retain rows, and permanent task purge cascades
  them. Task templates omit resources rather than copying outside references
  or potentially large bytes into every new task.
- **Recoverable Archive and Trash (schema v13):** archive task rows without
  changing completion or work history. A recurring occurrence can be archived
  or trashed independently; a whole family action marks every series version
  and stops materializing future occurrences until restored. Trash uses UTC
  deletion timestamps on tasks, projects, categories, fixed events, work
  sessions, and recurrence series. Deleting a parent hides its descendants
  without rewriting their own lifecycle markers, so restoring the parent
  reveals independently active children and keeps separately trashed children
  hidden. Restore checks parent availability in a transaction. Deleted names
  stay reserved until permanent deletion. The 30 day retention period is a
  default review window; startup never purges records automatically. Explicit
  permanent deletion is blocked by linked work, goals, dependencies, sessions,
  scheduling history, and other related records. An unlinked recurring task
  may be purged while retaining its occurrence slot; a series may be purged
  only after all occurrence tasks are resolved, with occurrence and series
  tombstones recorded for future synchronization. Active Flutter and native
  views exclude hidden items, while the data and history remain stored.
- **Statistics and reports:** calculate read-only, local-day reports from the
  persisted task, work, habit, and goal snapshots. Completed task counts use
  UTC completion instants converted to local days; planned counts use the
  independent date-only planned field. Archived tasks remain in history, while
  Trash and descendants of trashed parents or series are excluded. Work
  intervals are clipped to each local day and merged so overlaps count once;
  a timer awaiting recovery review ends at its last confirmed checkpoint.
  Habit rates use scheduled days and stored outcomes, including rest days.
  Goal counts are labeled as current state because historical goal snapshots
  are not stored. Reports never infer completion from missed plans.
- **TodoPilot public identity and upgrade compatibility (2026-10-19):** use
  TodoPilot for the visible name, executables, widget, tray, shortcuts, and
  installer, while preserving the existing `%APPDATA%\Life Manager` profile,
  SQLite filename, IPC identity, startup registration key, installer AppId, and
  installation directory. A rename must not create an empty second profile or
  strand an installed version. Production data is not migrated in development.
- **Orbit app icon (2026-10-19):** follow the user's white orbit-on-black
  screenshot. The shape matches Lucide's `orbit` pictogram, so retain its arc,
  center ring, and two satellites. Keep the scalable SVG, generate 16–256 px
  PNG-backed ICO sizes, and reproduce the source's ISC notice in
  `THIRD_PARTY_NOTICES.md` and both packages. Keep lavender as the default UI
  theme independently of the black app icon.
- **Theme picker and shared appearance (2026-10-19):** use the maintained
  `flex_color_picker` wheel and saturation/value square, plus TodoPilot's
  synchronized HEX field, live preview, and explicit picker confirmation.
  Save versioned, validated light/dark palettes and layout preferences to the
  existing appearance settings file. The native widget watches that file and
  uses its colors and opacity while the main app is closed. Theme imports are
  declarative JSON only; official Contributors remain a separate registry.
- **Widget opacity and geometry (2026-10-19):** retain Explorer child hosting
  and use per-pixel alpha for a configurable background while drawing content
  opaque. Minimum logical size is 260x230; the current monitor working area
  limits the maximum. Keep right-click actions and the layout lock in native
  settings. Actual alpha, hit testing, DPI, and Win+D behavior require target
  Windows GUI acceptance.
- **Layered child compatibility (2026-10-19):** declare Windows 8/8.1/10
  compatibility in the native companion manifest. Without it, Windows rejected
  `WS_EX_LAYERED` child-window creation in an isolated GUI launch even though
  the native self-test passed. Convert the desired screen position to Explorer
  parent-client coordinates for `UpdateLayeredWindow`; otherwise a two-monitor
  setup shifted the widget by one virtual-screen origin. A subsequent isolated
  launch created the Explorer child with `WS_EX_LAYERED` at the intended
  `(1520,24)` screen position. Pixel appearance and hit testing still need
  direct visual inspection.
- **TodoPilot 1.0.1 profile isolation (2026-10-19):** supersedes the earlier
  automatic legacy-profile selection. A fresh installer uses
  `%APPDATA%\TodoPilot`; each portable extraction selects a separate
  location-keyed subfolder there. The older `%APPDATA%\Life Manager` profile
  remains untouched and is offered through the reviewed import flow. Only an
  installer upgrade with the existing TodoPilot AppId, matching registration,
  installation directory, and no new database creates `legacy-profile.json`.
  The main app and native widget honor the same marker. Widget mutex and pipe
  names are scoped to the selected profile so simultaneous portable copies do
  not control each other. Uninstall leaves profile directories intact.
- **Windows icon surfaces (2026-10-19):** keep `IDI_APP_ICON` first and its ICO
  unchanged for executable, File Explorer, shortcuts, and installer. Add a
  transparent black-edged white orbit as `IDI_WINDOW_ICON` and assign both
  `ICON_SMALL` and `ICON_BIG` to the window, refreshing at DPI changes. Taskbar
  and pinned-shortcut choices vary by Windows shell state and need visual
  acceptance; the title bar was verified in an isolated Release UI.
- **In-app brand mark and 1.0.2 packaging (2026-10-19):** generate a 128 px
  transparent Flutter PNG from the outlined window-icon geometry and reference
  it through one `BrandMark` widget. Keep the black-tile executable and installer
  icon. Packaging rejects leftover `life_manager` executables; the installer
  version comes from `pubspec.yaml`. Disposable portable staging uses the OS
  temporary directory, and `release/` holds only the current candidate and its
  notices. The proposed license and public-name clearance remain creator
  decisions; no publication follows from building a candidate.
