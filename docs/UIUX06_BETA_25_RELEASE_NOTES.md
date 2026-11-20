# Todorbit 1.0.19-beta.25

Experimental beta candidate, build 48. Windows x64 and Android GitHub distribution.

## Changes & Architectural Enhancements (ARCH-02 through ARCH-09)

- **ARCH-02 Platform Resource Dialog Decoupling**:
  - Relocated `WindowsResourceDialog` to `lib/platform/windows_resource_dialog.dart`.
  - Decoupled `workspace`, `contributors`, `settings`, and `support` features from platform UI internals, cleanly eliminating 4 feature-level import cycles.
- **ARCH-03 Settings & Shared Layer Decoupling**:
  - Refactored `SyncStatusButton` in `lib/features/shared/sync_status_button.dart` to remove concrete imports of Settings dialogs (`DriveSyncDialog`, `StandardSyncDialog`, `LocalConflictDialog`).
  - Elevated dialog routing to caller-supplied callbacks (`onOpenDriveSync`, `onOpenStandardSync`, `onOpenConflictReview`), breaking the circular dependency between `features/shared` and `features/settings`.
- **ARCH-04 Domain & Data Boundary Enforcement**:
  - Hardened domain contracts, guaranteeing unidirectional dependencies where domain models and business logic never depend on Drift or SQLite persistence.
- **ARCH-05 Controller Interface Facades & Refresh Mappings**:
  - Introduced granular interface contracts and lifecycle refresh observers (`AppControllerRefreshMapping`), decoupling feature views and consumers from concrete controller implementations.
- **ARCH-06 State Encapsulation & Rebuild Optimization**:
  - Encapsulated mutable collections in Riverpod providers using unmodifiable wrappers (`UnmodifiableListView`, `UnmodifiableMapView`).
  - Added granular Riverpod selector equality to eliminate unnecessary widget subtree rebuilds.
  - Isolated timer and stopwatch periodic ticks to dedicated listeners, preventing parent view thrashing.
- **ARCH-07 Repository Transaction Encapsulation & Data Safety**:
  - Wrapped all multi-table database mutations in atomic Drift transactions with automatic rollback on error.
  - Hardened CAS revision invariants (`task.revision`, `event.revision`) and causal sequence protection in sync journals.
- **ARCH-08 Architecture Boundary Test Suite**:
  - Enforced 39 automated architecture and layer dependency rules in `tools/test_architecture_boundaries.py` integrated into CI pipelines.
- **ARCH-09 Architecture Documentation & Developer Map**:
  - Aligned `docs/ARCHITECTURE.md`, `docs/ARCHITECTURE_MAP.md`, and developer documentation with the verified modular architecture.

## Data and Compatibility

- Database schema remains strictly at **29** (no migration required).
- SQLite WAL mode configured with explicit `PRAGMA synchronous = FULL` for zero data-loss guarantees across unexpected shutdowns.
- Tasks, events, notes, checklist hierarchies, work sessions, attachments, and preferences are fully preserved.
- Android uses the established production package and signing identity (`io.github.hik4.todorbit`, version code 48).
- Windows packages remain unsigned under established policy. Stable releases unchanged (`prerelease: true`, `make_latest: false`).

## Verification Summary

- Remote GitHub Actions Windows checks ([Run 44688131094](https://github.com/2HIK4/Todorbit/actions/runs/44688131094)): SUCCESS in 35m11s (1,180+ tests passed, CRT verified, native sync writer, background sync barriers, native widget self-test, Inno Setup installer compiled).
- Remote GitHub Actions Android validation ([Run 44688229069](https://github.com/2HIK4/Todorbit/actions/runs/44688229069)): SUCCESS in 7m39s (16-KiB alignment and emulator updates passed).
- Lightweight CI validated locally: 103 / 103 passed across 13 critical regression suites (3m02s).
- Architecture boundary enforcement: 39 / 39 passed (`tools/test_architecture_boundaries.py`).
- Static analysis: `flutter analyze --no-pub`: 0 issues found across entire codebase.
- Whitespace and formatting: `git diff --check`: clean (0 issues).
