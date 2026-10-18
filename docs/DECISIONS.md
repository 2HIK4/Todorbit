# Decisions

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
- **Widget preferences and sign-in:** store geometry, monitor, and task view outside the task database in `%APPDATA%\Life Manager\widget-settings.json`. The optional per-user Run entry is changed only by an explicit tray-menu action and is disabled by default; development and automated tests must not enable it.
- **Shared appearance preference:** System/Light/Dark is authoritative in `%APPDATA%\Life Manager\appearance-settings.json`, watched by Flutter and the native companion without polling. Migrate the legacy widget theme once; keep geometry, selected task view, and sign-in choice in widget settings. A future widget-only override can be added explicitly without reintroducing two contradictory defaults.
- **Native widget editing surfaces:** preserve the owner-drawn Explorer child. Quick Add uses a temporary borderless activatable top-level surface aligned over the painted field; task editing uses a compact activatable dialog with optimistic concurrency. Do not add persistent child controls, keyboard hooks, focus timers, or synthetic input to the shell child.
- **Native widget views and geometry:** Today, Inbox, All Tasks, and Upcoming use the same schema-v3 semantics as Flutter. Dragging the empty header moves the child; custom hit testing supports all edges/corners, persisted logical bounds, per-monitor DPI scaling, and working-area clamping.
- **Fixed events:** store UTC instants, display in local time, and use interval overlap for multi-day calendar placement. Actual task deadlines remain independent date-only values.
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
