# Todorbit 1.0.19-beta.24 — Experimental Beta

Version 1.0.19-beta.24+47 for Windows x64 and Android GitHub distribution.

## Changes & Reliability Enhancements

- **Mixed-Version Sync & Rollback Compatibility**:
  - Isolated `detailPresentation` as a device-local preference in `deviceLocalThemeFields`, stripped it from cloud sync batches, and pruned legacy SQLite rows from `portable_preferences` table on database open. Ensures full backwards compatibility and sync interoperability with older devices (such as Beta 23).
- **Android Shared Inbox Multi-File & Security Hardening**:
  - Synchronized batch manifest updates during multi-file share receiver ingestion, accumulating entries to prevent overwriting earlier files in multi-stream intents.
  - Added atomic publish fallback if file rename fails across partitions or storage limits.
  - Enforced strict content scheme validation, rejecting non-content schemes and self-package URI paths.
- **Event Editor State Reuse & Navigation Protection**:
  - Keyed `EventEditor` instances by composite identity `(event.id, nominalDate, editorRevision)`.
  - Implemented `didUpdateWidget` and `_initFromEvent()` to prevent form field cross-contamination when switching events.
  - Exposed `attach()` / `detach()` on `TaskEditorController` and attached `confirmLeave()` unsaved edit protection when navigating away or switching views.
- **Full Page Task Details**:
  - Resolved wide desktop window (>= 1050px) New Task creation in Full Page mode by rendering `TaskEditor` full page in `_mainPanel`.
  - Guaranteed search result selection properly loads task details and navigates to the target view without modal conflicts.
- **Smart Reschedule Collision Detection**:
  - Prevented split sessions from overlapping fixed events (`ScheduleIssueKind.fixedEventCollision`) or existing scheduled sessions (`ScheduleIssueKind.sessionCollision`).
- **Calendar Navigation & Date Preservation**:
  - Preserved user-selected calendar dates across event edit and close transitions via `CalendarView.onDateSelected`.
- **Responsive Geometry & Touch Target Safety**:
  - Increased parent subtask expander pill trailing margin to 96dp to prevent overlapping the task timer button.
  - Added active timer status badges for child tasks ('Timer running', 'Timer paused').
- **Pointer Lifecycle & Window Blur Safety**:
  - Enhanced `PointerCancellationScope` to record mouse device kinds and dispatch proper `PointerExitEvent` and `PointerRemovedEvent` on window deactivation.
- **Task Details Active Duration**:
  - Added a lightweight 1-second periodic ticker in `TaskDetailsView` to update the recorded Work Log session duration while a timer is active.

## Data and Compatibility

- Database schema remains at **29** (identical to Beta 22 and Beta 23). No database migration is required.
- SQLite WAL mode configured with explicit `PRAGMA synchronous = FULL` for zero data-loss guarantees across unexpected shutdowns.
- Tasks, events, notes, checklist hierarchies, work sessions, attachments, and preferences are fully preserved.
- Android uses the established production package and signing identity (`io.github.hik4.todorbit`, version code 47).
- Windows packages remain unsigned under established policy. Stable releases unchanged (`prerelease: true`, `make_latest: false`).

### Sync & Rollback Compatibility Limitation
- Rollback from Beta 24 to Beta 23 is fully supported for standard upgrades because schema version remains at 29 and no unknown keys are written to portable preferences.
- Rollback for experimental developer profiles with previously queued incompatible envelopes from early dev builds requires restoring from the automatic Before-Upgrade / Before-Restore backup snapshot; universal rollback without snapshot restoration is not supported.

## Verification Summary

- Full Windows CI run passed with 1,178 tests passed, 0 failed, 9 skipped (Run 44411095342).
- Android CI validation passed across all unit, architecture, and emulator tests (Run 44411102129).
- Static analysis clean: 0 errors, 0 warnings.
- Native .NET 10 companion self-test passed (`dotnet run --project experiments/widget-shell-probe -- --self-test`).
- Android universal APK verified with 16-KiB page alignment across all 8 native `.so` libraries.

This is an experimental pre-release. Physical Windows keyboard/focus, real multi-file Android Share Sheet, and physical updater installation journeys remain pending manual beta acceptance.
