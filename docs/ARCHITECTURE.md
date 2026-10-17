# Architecture

- Flutter Material 3 UI with a compact Fluent-inspired desktop layout.
- Riverpod owns application state. Feature widgets observe a controller, while data access stays in the repository.
- Drift opens SQLite in a background isolate. The repository owns SQL, migrations, transactions, and mapping to immutable domain objects. Initial schema uses explicit SQL to keep migration changes reviewable.
- SQLite lives in the per-user application-support directory. UUID identifiers and UTC modification fields prepare data for future synchronization; no synchronization is implemented.
- `lib/domain/`: entity models. `lib/data/`: SQLite and repository. `lib/features/`: screens and reusable controls. `lib/app/`: shell, state, theme.
- Windows widget and tray code will live behind a separate integration boundary.

The current integration candidate is a separate .NET/WinForms companion in
`experiments/widget-shell-probe`. Its persistent display is an Explorer
`SHELLDLL_DefView` child, while keyboard entry is an ordinary activated
top-level dialog. This avoids trying to focus a shell-child Flutter view. A
narrow native repository reads and writes only task fields already owned by
schema v3, validates the schema before opening, uses UUIDs/UTC timestamps and
transactions, and never performs migrations. Explorer hosting is an
undocumented compatibility dependency; the existing Flutter `--widget`
prototype remains unchanged until manual desktop acceptance succeeds.

Data integrity: foreign keys on, WAL, indexed common filters, schema versioning, and transactions for related writes. Date-only values use local calendar dates (`YYYY-MM-DD`); instants use UTC ISO 8601.

Schema v2 adds `fixed_events` with UTC start/end instants and a start-time index. The v1→v2 migration preserves task rows.

Schema v3 adds `work_sessions` with separate outcome and optional recorded start. Both v1→v3 and v2→v3 upgrade paths are supported. Session status does not drive parent task completion.
