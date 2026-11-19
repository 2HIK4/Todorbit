# UIUX-05 / Beta 24 Integration & Publication Verification Report

Owner authorization conditionally permitted one experimental pre-release for Todorbit Beta 24 (`1.0.19-beta.24+47`), subject to mandatory CI, packaging, signing, and sync safety gates passing.

Status: **PUBLISHED (Experimental Pre-Release Live on GitHub)**
Branch: `feature/todorbit-release-p8`
Integrated Release Commit: `16de251cc0208ade5d54bbdebf26c60a278ac86f`
Release Tag: `v1.0.19-beta.24`
Release URL: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.24
Target Version: `1.0.19-beta.24+47` (versionName `1.0.19-beta.24`, versionCode `47`)

---

## 1. Executive Summary & Publication Decision

Codex completed the implementation of the four remaining release blockers on `fix/todorbit-beta24-release-blockers`. Gemini integrated the fixes into `feature/todorbit-release-p8` at commit `12d7e4624b455c17fae44ebae566110f0f4a8616` via a clean merge (0 conflicts).

All four P1 release blocker areas, two related fixes, and critical persistence/sync invariants were independently verified:
- **P1-01 (Sync Causal History)**: Verified. SQLite startup makes no destructive writes. Committed causal history, origin sequence, mutation groups, entity heads, and exact retry bytes are preserved.
- **P1-02 (Android Shared Inbox Native Integration)**: Verified. Unified `SharedInboxStorage` native worker serializes all mutations across activities and Flutter channels with checked `Os.fsync` and directory sync. Independent task attachments survive inbox deletion.
- **P1-03 (Unsaved Editor Navigation)**: Verified. Dialog guards await Save, Discard, or Keep editing before routing, search, timer navigation, or Escape in both Side Panel and Full Page modes.
- **P1-04 (Smart Reschedule Occurrences Projection)**: Verified. Apply validates recurring event occurrences, moved-in/moved-out exceptions, and existing sessions within the write transaction with atomic rollback.
- **Related Fixes**: Immediate Sync notification on local task/event commits and Calendar date loading mid-drag deferral were verified.

### Publication Decision: PUBLISHED
All mandatory release gates passed:
1. **GitHub Actions Windows CI Passed**: Run [44411095342](https://github.com/2HIK4/Todorbit/actions/runs/44411095342) (`windows-ci.yml`) passed in 33m55s (**1,178 passed, 0 failed, 9 skipped**). All 12 previously failing tests resolved.
2. **Windows Release Artifacts Generated**: Windows Release binary compiled, CRT verified, native sync writer and background sync verified, native companion self-test passed, portable package generated, and Inno Setup installer compiled with release checksums.
3. **Android Release Verification**: Production signed APK compiled locally with `tools/build-android.ps1 -Mode Release` (versionCode 47, 16-KiB page alignment verified), verified via `tools/prepare-android-release.py`, and verified on GitHub Actions [Run 44411102129](https://github.com/2HIK4/Todorbit/actions/runs/44411102129) (`android-ci.yml`, SUCCESS).
4. **Public GitHub Pre-Release Published**: Tag `v1.0.19-beta.24` pushed and pre-release published at https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.24 with all 10 Windows and Android assets.
5. **Updaters Verified**: Both Windows (`SoftwareUpdateService`) and Android (`AndroidUpdateService`) discovery contracts and file naming conventions verified.
6. **Stable Branch**: Untouched.

---

## 2. Codex Findings & Integration Review

| Finding | Area | Root Cause & Merged Resolution | Independent Verification |
|---|---|---|---|
| **P1-01** | Sync / Causal History | SQLite startup previously pruned legacy rows and deleted sync journal rows, causing causal sequence advancement and lost retry bytes. **Resolution**: `AppDatabase.open` makes zero compatibility writes. `detailPresentation` is excluded from initial sync enrollment and outgoing batches. Incompatible legacy payloads halt exchange with `SyncPreferenceCompatibilityException` while retaining exact bytes and links for reconciliation. | `test/sync_exchange_repository_test.dart` (11/11 PASS); `test/database_initialization_test.dart` (22/22 PASS); `test/sync_journal_test.dart` (9/9 PASS). |
| **P1-02** | Android Shared Inbox | Dual-owner manifest rewrites in Kotlin and Dart caused race conditions, file loss, and orphaned staging. **Resolution**: `SharedInboxWorker` single-thread executor serializes all operations. Native storage flushes file descriptors and directories (`Os.fsync`), publishes manifest before unlinking files, and safe recovery purges orphans using durable manifest. | `android/app/src/main/kotlin/io/github/hik4/todorbit/SharedInboxStorage.kt`; `test/shared_inbox_store_test.dart` (10/10 PASS); `test/shared_inbox_task_integration_test.dart` (5/5 PASS). |
| **P1-03** | Unsaved Editor Navigation | Sidebar search, Escape, and timer navigation bypassed unsaved editor guards in certain modes. **Resolution**: Shared `askUnsavedEditorDecision` (Save, Discard, Keep editing). `Workspace._withEditorNavigation` awaits the mounted editor decision. Save commits to SQLite before routing; failed saves preserve drafts. | `test/workspace_draft_safety_test.dart` (26/26 PASS across Side Panel & Full Page modes). |
| **P1-04** | Smart Reschedule | Apply checked event template timestamps rather than projected recurring occurrences, allowing collisions. **Resolution**: `LifeRepository.applyReschedule` projects recurring occurrences via `eventOccurrences`, respects cancelled/moved exceptions, checks work session intervals, and aborts atomically if stale collisions are detected. | `test/prompt4_smart_reschedule_test.dart` (20/20 PASS). |
| **Related** | Immediate Sync Signaling | Controller mutations previously only signaled sync during read refresh if recurring tasks were materialized. **Resolution**: All local controller mutations call `refreshAfterLocalChange()`, triggering immediate `onLocalChange?.call()` to notify Sync. | `test/beta24_calendar_sync_test.dart` (2/2 PASS). |
| **Related** | Calendar Interaction Mid-Drag | External date updates disrupted active drag/resize gestures. **Resolution**: `CalendarView` defers external date updates while `_handlingInteraction` or `isDragging` is true, resolving and loading recurrence window only upon interaction end. | `test/beta24_calendar_sync_test.dart` (2/2 PASS). |

---

## 3. Sync Compatibility Boundary & Decision

A thorough evaluation of the mixed-version sync boundary between Beta 23 and Beta 24 was conducted:

1. **Incompatible States in Public Beta 23 Profiles**:
   - **None.** `detailPresentation` was introduced only in Prompt 1 (`5fbce95`) during the Beta 24 development cycle. It never existed in tagged release `v1.0.19-beta.23` or earlier releases.
2. **States Produced by Experimental Pre-Release Builds**:
   - Profiles created or opened by unpublished Prompt 1–7 / early Prompt 8 development builds may contain `detailPresentation` rows in `portable_preferences` and journal entries.
3. **Standard Production Upgrade Safety (Beta 23 to Beta 24)**:
   - Upgrading an enrolled Beta 23 database to Beta 24 succeeds cleanly. Beta 24 makes no startup deletions. `detailPresentation` is maintained purely in local profile JSON and never queued for sync. Outgoing batches contain only standard portable preferences that Beta 23 accepts.
4. **Mixed-Version Sync (Beta 23 <-> Beta 24)**:
   - Devices on Beta 23 and Beta 24 sharing a cloud workspace exchange changes safely. Beta 24 strips `detailPresentation` from customization payloads, and Beta 23 validation accepts all Beta 24 preference operations without `FormatException`.
5. **Rollback Compatibility**:
   - Rollback from Beta 24 to Beta 23 is fully supported for standard upgrades because schema version remains at 29 and no unknown keys are written to `portable_preferences`.
   - Rollback for experimental dev profiles with previously queued incompatible envelopes is limited and requires restoring from the automatic Before-Upgrade / Before-Restore backup snapshot.
6. **Recovery Path for Blocked Historical Operations**:
   - If an experimental user has an incompatible staged envelope from an earlier dev build, `SyncPreferenceCompatibilityException` halts exchange safely, preserves all local SQLite records and causal history, and displays a user-facing recovery dialog.

---

## 4. Verification Matrix & Evidence

### Local Focused Verification
- **`test/sync_exchange_repository_test.dart`**: 11/11 PASS (reopen durability, retry byte matching, peer application, local presentation isolation).
- **`test/beta24_calendar_sync_test.dart`**: 2/2 PASS (calendar date mid-drag deferral, immediate sync signaling).
- **`test/prompt4_smart_reschedule_test.dart`**: 20/20 PASS (Smart Reschedule recurring event collision validation, Apply/Undo).
- **`test/workspace_draft_safety_test.dart`**: 26/26 PASS (unsaved editor guards, Save/Discard/Keep editing, SQLite save failure fallback).
- **`test/shared_inbox_store_test.dart`**: 10/10 PASS (Shared Inbox file ingestion, duplicate detection, atomic persistence).
- **`test/shared_inbox_task_integration_test.dart`**: 5/5 PASS (independent task copy semantics, surviving inbox deletion).
- **`test/database_initialization_test.dart`**: 22/22 PASS (Schema 29 forward compatibility, WAL mode, synchronous=FULL).
- **`test/sync_journal_test.dart`**: 9/9 PASS (causal record ancestry, transaction rollback, tombstone tracking).
- **Static Analysis**: `flutter analyze --no-pub` -> **0 issues found** (85.2s).
- **Whitespace / Diff Check**: `git diff --check` -> **Clean** (0 issues).
- **Native Companion (.NET 10)**:
  - `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`: Built with 0 warnings, 0 errors.
  - `dotnet run --project experiments/widget-shell-probe -c Release -- --self-test`: **PASS** (task revision safety, monotonic clocks, alarm projections, widget persistence).

### Android Release Build Verification
- **Compilation**: Compiled via `tools/build-android.ps1 -Mode Release` with JDK 21 and Android API 36.
- **Production Signing**: Signed with `android/key.properties` (versionCode 47, versionName `1.0.19-beta.24`, CN=Hussam Alkhatib, SHA-256 `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`).
- **Artifact**: `Todorbit-1.0.19-beta.24-android-universal.apk` (52.1 MB / 54,581,171 bytes).
- **SHA-256**: `659c816c43dedcf4cec327ee6bdf3db2e575c60fd69d0ef1842f52b2467ee488`.
- **16-KiB Native Alignment**: Verified with `tools/verify-android-artifact.py` across all 8 native `.so` libraries (`lib/arm64-v8a/*`, `lib/x86_64/*`).
- **Candidate Packaging**: Processed via `tools/prepare-android-release.py --apk-only` generating manifest `Todorbit-1.0.19-beta.24-android-update.json` and checksum records.

### Windows Release Build Verification
- **Compilation & Packaging**: Built on GitHub Actions runner via `windows-ci.yml`.
- **Installer Artifact**: `Todorbit-1.0.19-beta.24-win-x64-setup.exe` (48,039,839 bytes).
  - SHA-256: `0242e51f5302c93a047d500d369e8ea661ba05bdefe645b129b59adde502f693`.
- **Portable Artifact**: `Todorbit-1.0.19-beta.24-win-x64-portable.zip` (65,450,037 bytes).
  - SHA-256: `0dd8395a2d850861127453a0f1c91ada519541c81f4c2bac30cac0630a9d8db4`.
- **Checksums**: Verified against `Todorbit-1.0.19-beta.24-SHA256SUMS.txt`.

### GitHub Actions CI Verification
- **Android Validation**: [Run 44411102129](https://github.com/2HIK4/Todorbit/actions/runs/44411102129) -> **SUCCESS** (all unit, architecture, and emulator tests passed).
- **Windows Checks**: [Run 44411095342](https://github.com/2HIK4/Todorbit/actions/runs/44411095342) -> **SUCCESS** in 33m55s (**1,178 passed, 0 failed, 9 skipped**). All 12 previously failing tests resolved. Release compilation, CRT verification, native sync writer, background sync, widget self-test, installer compilation, and checksums all passed.

---

## 5. Outstanding Physical Acceptance Backlog

The following physical acceptance scenarios remain open and must be performed on physical hardware prior to a production/stable release:
1. **Android Share Sheet**: Share a PDF and multiple images simultaneously from external apps (e.g. Files by Google, Photos).
2. **Cold-Start Share Delivery**: Receive shared intents while Todorbit is terminated.
3. **Content URI Grants**: Verify permission persistence across process restarts.
4. **App Restart & Interrupted Import Recovery**: Force-kill during multi-file import and verify manifest recovery.
5. **Task Attachment Independence**: Verify attachments copied to tasks survive clearing the Shared Inbox.
6. **Physical Windows Focus & Keyboard**: Verify Escape, tab navigation, and focus transitions on physical Windows 11 hardware.
7. **Windows Screenshot & Hover**: Verify <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> clears hover state without stuck tooltips.
8. **Calendar Drag & Smart Reschedule**: Test touch/pointer event drag, resize, and Smart Reschedule review on live hardware.
9. **Cross-Device Sync**: Execute end-to-end sync between physical Windows 11 and physical Android devices using real Google Drive OAuth.
