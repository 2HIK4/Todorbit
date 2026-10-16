# Decisions

- **Windows-first offline Flutter:** reuse the working scaffold and leave Android as a future target.
- **Drift + SQLite:** use a background database isolate, explicit schema migrations, and a per-user support directory. The current `sqlite3` package bundles native SQLite; the end-of-life `sqlite3_flutter_libs` package is not used.
- **Riverpod:** keep shared UI state in one controller for the first milestone; split by feature as complexity grows.
- **Dates:** local date-only strings for planned days/deadlines; UTC instants for modification and completion. This avoids inventing times for date-only tasks.
- **Honest scope:** unavailable future views are documented rather than represented by fake screens or data.
- **Windows data path:** use the per-user `APPDATA` directory directly. This removes the path-provider plugin and its Windows symlink build requirement; Android data path will be revisited when Android development begins.
