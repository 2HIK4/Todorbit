# Todorbit 1.0.19-beta.25 — Experimental Beta (Modular Architecture Refactor)

Version 1.0.19-beta.25+48 for Windows x64 and Android GitHub distribution.

> [!WARNING]
> This is an **experimental pre-release** for validation, testing, and feedback. Physical Windows keyboard/focus, multi-monitor DPI scaling, real multi-file Android Share Sheet, and physical updater installation journeys remain pending manual beta acceptance. Do not deploy to production environments without verified snapshot backups.

## Changes & Architectural Improvements (ARCH-02 through ARCH-09)

- **ARCH-02 PlatformResourceDialog Relocation**:
  - Relocated `PlatformResourceDialog` to `lib/platform/platform_resource_dialog.dart`.
  - Decoupled `workspace`, `contributors`, `settings`, and `support` features from platform UI internals, cleanly eliminating 4 feature-level import cycles.
- **ARCH-03 Settings & Shared Layer Decoupling**:
  - Refactored `SyncStatusButton` in `lib/features/shared/sync_status_button.dart` to eliminate direct imports of Settings dialogs (`DriveSyncDialog`, `StandardSyncDialog`, `LocalConflictDialog`).
  - Elevated dialog routing to caller-supplied callbacks (`onOpenSettings` and `onOpenConflicts`), breaking the circular dependency between `features/shared` and `features/settings`.
- **ARCH-04 Calendar & Workspace Boundary Decoupling**:
  - Eliminated bidirectional coupling between `features/calendar` and `features/workspace`.
  - Relocated `SessionEditor` from `lib/features/calendar/session_editor.dart` to `lib/features/scheduling/session_editor.dart`.
  - Introduced `EditorNavigationController` in `lib/features/shared/unsaved_editor_guard.dart` and enforced clean unidirectional boundaries between calendar presentation and workspace components.
- **ARCH-05 Strongly Typed AppRefreshSnapshot**:
  - Introduced strongly typed `AppRefreshSnapshot` in `lib/app/app_refresh_snapshot.dart`.
  - Refactored `AppController.refresh` to pass structured domain change snapshots, enabling fine-grained refresh reactions.
- **ARCH-06 State Encapsulation & Rebuild Optimization**:
  - Encapsulated mutable collections in Riverpod providers using unmodifiable wrappers (`UnmodifiableListView`, `UnmodifiableMapView`).
  - Added granular Riverpod selector equality to eliminate unnecessary widget subtree rebuilds.
  - Isolated periodic timer and stopwatch tickers to dedicated listeners, preventing parent view thrashing.
- **ARCH-07 Repository Transaction Encapsulation & Data Safety**:
  - Wrapped multi-table database mutations in atomic Drift transactions with automatic rollback on error.
  - Hardened CAS revision invariants (`task.revision`, `event.revision`) and causal sequence protection in sync journals.
- **ARCH-08 Optional Feature Modularity Evaluation**:
  - Completed a rigorous architectural evaluation of optional feature modularity and sync safety boundaries across core features (Calendar, Notes, Habits, Goals, Smart Reschedule, Cloud Sync).
  - Confirmed that modularity must strictly respect SQLite Schema 29 invariants and causal history without premature dynamic plugin abstraction.
- **ARCH-09 Architecture Documentation & Boundary Enforcement**:
  - Aligned `docs/ARCHITECTURE.md`, `docs/ARCHITECTURE_MAP.md`, and developer documentation with the verified modular architecture.
  - Enforced 39 automated architecture and layer dependency rules in `tools/test_architecture_boundaries.py` integrated into CI pipelines.

## Data and Compatibility

- Database schema remains strictly at **29** (identical to Beta 22, Beta 23, and Beta 24). No database migration is required.
- SQLite WAL mode configured with explicit `PRAGMA synchronous = FULL` to provide resilient crash safety across unexpected shutdowns.
- Tasks, events, notes, checklist hierarchies, work sessions, attachments, and preferences are preserved.
- Android uses the established production package and signing identity (`io.github.hik4.todorbit`, version code 48).
- Windows packages remain unsigned under established policy. Stable releases unchanged (`prerelease: true`, `make_latest: false`).

## Verification Summary

- Remote GitHub Actions Windows checks ([Run 44694169827](https://github.com/2HIK4/Todorbit/actions/runs/44694169827)): SUCCESS in 29m43s (1,180+ tests passed, CRT verified, native sync writer, background sync barriers, native widget self-test, Inno Setup installer compiled).
- Remote GitHub Actions Android validation ([Run 44694185735](https://github.com/2HIK4/Todorbit/actions/runs/44694185735)): SUCCESS in 9m55s (16-KiB alignment, debug APK, unit tests, and emulator update workflow tests passed).
- Remote GitHub Actions Android 16 KiB runtime ([Run 44699666409](https://github.com/2HIK4/Todorbit/actions/runs/44699666409)): SUCCESS in 3m41s (verified upgrade acceptance and persistence on 16 KiB page size emulator).
- Lightweight CI validated locally: 103 / 103 passed across 13 critical regression suites (3m02s).
- Architecture boundary enforcement: 39 / 39 passed (`tools/test_architecture_boundaries.py`).
- Static analysis: `flutter analyze --no-pub`: 0 issues found across entire codebase.
- Whitespace and formatting: `git diff --check`: clean (0 issues).
- Native .NET 10 companion self-test passed (`dotnet run --project experiments/widget-shell-probe -- --self-test`).
- Android universal APK verified with 16-KiB page alignment across all 8 native `.so` libraries.

This is an experimental pre-release. Physical Windows keyboard/focus, multi-monitor DPI scaling, real multi-file Android Share Sheet, and physical updater installation journeys remain pending manual beta acceptance.
