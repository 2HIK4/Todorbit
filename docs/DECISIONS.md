# Decisions

- **Windows-first offline Flutter:** reuse the working scaffold and leave Android as a future target.
- **Drift + SQLite:** use a background database isolate, explicit schema migrations, and a per-user support directory. The current `sqlite3` package bundles native SQLite; the end-of-life `sqlite3_flutter_libs` package is not used.
- **Riverpod:** keep shared UI state in one controller for the first milestone; split by feature as complexity grows.
- **Dates:** local date-only strings for planned days/deadlines; UTC instants for modification and completion. This avoids inventing times for date-only tasks.
- **Honest scope:** unavailable future views are documented rather than represented by fake screens or data.
- **Windows data path:** use the per-user `APPDATA` directory directly. This removes the path-provider plugin and its Windows symlink build requirement; Android data path will be revisited when Android development begins.
- **Widget feasibility:** the separate `--widget` process uses documented `SetParent(GetDesktopWindow())`, but native traces and user testing show that this does not meet keyboard activation or `Win + D` requirements. The resulting `WS_CHILD` window belongs under the system desktop HWND, not an independently activatable Life Manager top-level window or Explorer's shell layer. Keep this as a failed prototype, not a completed widget. An Explorer `WorkerW`/`Progman` attachment could be evaluated only as an explicitly accepted, undocumented compatibility dependency with real Windows-version and Explorer-restart testing; do not silently substitute a floating or topmost window.
- **Fixed events:** store UTC instants, display in local time, and use interval overlap for multi-day calendar placement. Actual task deadlines remain independent date-only values.
- **Work sessions:** store planned UTC intervals and a manual outcome independently of tasks. A transition to “In progress” records an actual start; elapsed upcoming sessions remain upcoming until confirmed.
- **Scheduling engine:** compute immutable previews from local availability windows against UTC event/session intervals. Keep application of changes disabled until availability settings, transactional history, and conflict review are wired together.
