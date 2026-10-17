# Architecture

- Flutter Material 3 UI with a compact Fluent-inspired desktop layout.
- Riverpod owns application state. Feature widgets observe a controller, while data access stays in the repository.
- Drift opens SQLite in a background isolate. The repository owns SQL, migrations, transactions, and mapping to immutable domain objects. Initial schema uses explicit SQL to keep migration changes reviewable.
- SQLite lives in the per-user application-support directory. UUID identifiers and UTC modification fields prepare data for future synchronization; no synchronization is implemented.
- `lib/domain/`: entity models. `lib/data/`: SQLite and repository. `lib/features/`: screens and reusable controls. `lib/app/`: shell, state, theme.
- Windows widget and tray code live behind a separate native-companion boundary.

The integrated Windows widget is a separately packaged .NET companion,
implemented in `experiments/widget-shell-probe` and published beside
`life_manager.exe` as `life_manager_widget.exe`. Its persistent display is one owner-drawn
native HWND created directly as an Explorer `SHELLDLL_DefView` child, while
keyboard entry uses short-lived activated WinForms top-level surfaces. This avoids
both shell-child Flutter focus and post-paint WinForms reparenting. A
narrow native repository reads and writes only task fields already owned by
schema v3, validates the schema before opening, uses UUIDs/UTC timestamps and
transactions, rejects stale edits, and never creates or migrates the database.
A named-pipe command boundary lets Flutter show, hide, toggle, refresh, open
Quick Add, select Today/Inbox/All Tasks/Upcoming, or close the single native
instance. Both processes use
debounced filesystem events on the SQLite database/WAL rather than polling.
The companion owns its tray lifecycle, persists geometry/view separately from
the shared appearance preference, clamps placement to connected monitors, and
makes bounded recreation attempts if Explorer destroys its child HWND. Manual
acceptance on the target Windows system passed continuous visibility, `Win+D`,
input, editing, resizing, icons, views, theme synchronization, and independent
main-app lifecycle. Explorer hosting remains an undocumented compatibility
dependency and its diagnostics are retained.

`life_manager.exe --widget` is a compatibility entry point that launches the
packaged native companion and exits before creating a Flutter engine. The known
broken Flutter desktop-child implementation is reachable only through the
explicit diagnostic flag `--legacy-flutter-widget`; normal application and
widget controls never select it. The native companion is also directly
launchable as `life_manager_widget.exe --widget`.

Data integrity: foreign keys on, WAL, indexed common filters, schema versioning, and transactions for related writes. Date-only values use local calendar dates (`YYYY-MM-DD`); instants use UTC ISO 8601.

Schema v2 adds `fixed_events` with UTC start/end instants and a start-time index. The v1→v2 migration preserves task rows.

Schema v3 adds `work_sessions` with separate outcome and optional recorded start. Both v1→v3 and v2→v3 upgrade paths are supported. Session status does not drive parent task completion.
