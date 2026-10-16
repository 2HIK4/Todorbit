# Architecture

- Flutter Material 3 UI with a compact Fluent-inspired desktop layout.
- Riverpod owns application state. Feature widgets observe a controller, while data access stays in the repository.
- Drift opens SQLite in a background isolate. The repository owns SQL, migrations, transactions, and mapping to immutable domain objects. Initial schema uses explicit SQL to keep migration changes reviewable.
- SQLite lives in the per-user application-support directory. UUID identifiers and UTC modification fields prepare data for future synchronization; no synchronization is implemented.
- `lib/domain/`: entity models. `lib/data/`: SQLite and repository. `lib/features/`: screens and reusable controls. `lib/app/`: shell, state, theme.
- Windows widget and tray code will live behind a separate integration boundary.

Data integrity: foreign keys on, WAL, indexed common filters, schema versioning, and transactions for related writes. Date-only values use local calendar dates (`YYYY-MM-DD`); instants use UTC ISO 8601.
