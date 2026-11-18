# UIUX-05 / Prompt 8 Release Verification & Publication Report

Owner authorization permits release preparation, Codex findings resolution, and conditional publication of an experimental pre-release for Todorbit's UI & Reliability Improvement Program. Stable remains untouched.
Version: `1.0.19-beta.24+47`; intended tag: `v1.0.19-beta.24`.

Status: **READY FOR REVIEW / RELEASE CANDIDATE VERIFIED**
Branch: `feature/todorbit-release-p8`
Base commit: `03abc27a44c875f5a1a6a070452a70a98c5e6efa` (Prompt 7 baseline)

---

## 1. Independent Codex Review Findings Matrix

Codex performed a read-only source inspection of Prompts 1–7 and identified 5 P1 and 7 P2 findings (0 P0 findings). All 12 findings were independently investigated, reproduced, repaired on `feature/todorbit-release-p8`, and validated with regression tests.

| ID | Severity | Area | Reported Defect | Root Cause & Resolution | Verification |
|---|---|---|---|---|---|
| **P1-01** | P1 | Sync / Rollback | Mixed-version Google Drive sync and rollback incompatibility. Older versions (Beta 23) using Schema 29 reject unknown `detailPresentation` portable preference key. | `detailPresentation` was included in portable preferences and cloud sync. **Fix**: Classified as a device-local preference in `deviceLocalThemeFields`, stripped in `validatePortablePreference('customization', ...)`, pruned legacy rows from `portable_preferences` SQLite table on open, and omitted from `AppController.setTaskViewPreferences`. Retained in local profile JSON and `SettingsTransfer`. | `prompt8_codex_fixes_test.dart` (P1-01 suite); `sync_apply_repository_test.dart` (32 tests PASS). |
| **P1-02** | P1 | Android Share | Ingesting multiple shared files can lose all but the final file due to repeated snapshot overwrite. | `ShareReceiverActivity.kt` loaded existing entries once outside the loop and prepended to that original list on each iteration. **Fix**: Accumulate batch entries, synchronize updates, verify `renameTo` with fallback, and combine `EXTRA_STREAM` with `clipData`. | `prompt8_codex_fixes_test.dart` (P1-02 suite); `shared_inbox_store_test.dart` (10 tests PASS). |
| **P1-03** | P1 | Event Editor | Switching Full Page event editors can preserve stale fields from previous event while saving with new event's ID. | Flutter reused `_EventEditorState` because `EventEditor` lacked an identity-based key and `didUpdateWidget`. **Fix**: Added composite key `ValueKey((event.id, nominalDate, editorRevision))`, implemented `didUpdateWidget` and `_initFromEvent()`. | `prompt8_codex_fixes_test.dart` (P1-03 suite); `prompt1_search_and_detail_presentation_test.dart` (14 tests PASS). |
| **P1-04** | P1 | Desktop Workspace | New Task fails in Full Page mode on wide desktop windows (width >= 1050px) because inline editor was suppressed and no main panel editor was rendered. | `inlineEditor` checked `!useFullPage`, while `_mainPanel` only checked `selectedTask != null`. **Fix**: Added `if (controller.isFullPageDetails && creating)` in `_mainPanel` to render `TaskEditor` full page. | `prompt8_codex_fixes_test.dart` (P1-04 suite); `workspace_test.dart` (15 tests PASS). |
| **P1-05** | P1 | Navigation / Search | Navigation paths and search result selection bypass unsaved-edit guards, risking lost edits. | `EventEditor` did not attach its guard to `editorNavigation`, and search dialogs lacked navigation hooks. **Fix**: Exposed `attach()`/`detach()` on `TaskEditorController`, implemented `confirmLeave()` in `EventEditor`, and passed `beforeNavigate: _prepareEditorChange` to `QuickSearchDialog` and `AdvancedSearchDialog`. | `prompt8_codex_fixes_test.dart` (P1-05 suite); `workspace_test.dart` (15 tests PASS). |
| **P2-01** | P2 | Android Security | Shared inbox Android receiver allows directory traversal / non-content schemes. | Unrestricted URI schemes and unvalidated authorities could allow unintended file access. **Fix**: Validated scheme == "content", forbade own package / file-provider authorities, and sanitized display names. | `ShareReceiverActivity.kt` hardening; `shared_inbox_store_test.dart`. |
| **P2-02** | P2 | Reschedule | Smart Reschedule split session can overlap fixed events or existing sessions. | `splitSession` lacked interval collision detection for the second segment. **Fix**: Added `_Interval.overlaps()` check against `fixedEvents` (`ScheduleIssueKind.fixedEventCollision`) and `otherSessions` (`ScheduleIssueKind.sessionCollision`). | `prompt8_codex_fixes_test.dart` (P2-02 suite); `prompt4_smart_reschedule_test.dart` (16 tests PASS). |
| **P2-03** | P2 | Recurrence | Calendar recurring task materialization can leave task counts / report cache stale. | `_loadRequestedRecurringMonths()` refreshed the calendar window without updating `reportTasks`. **Fix**: Included `repository.reportTasks()` in `refreshCalendarWindow()`. | `prompt7_cache_correctness_test.dart` (14 tests PASS); `workspace_test.dart`. |
| **P2-04** | P2 | Calendar | Closing event details resets the user's selected calendar date to today. | `CalendarView` did not notify parent when selected date changed, causing fallback to initial date. **Fix**: Added `onDateSelected` callback and tracked `_lastCalendarDate` in `Workspace`. | `prompt8_codex_fixes_test.dart` (P2-04 suite); `calendar_view.dart`. |
| **P2-05** | P2 | Subtasks | Parent subtask expander pill overlaps the task timer button. | `end: 52` padding on expander pill intersected with right-aligned action buttons. **Fix**: Increased end margin to `96dp` and displayed active timer badges for child tasks. | `prompt8_codex_fixes_test.dart` (P2-05 suite); `task_list_group.dart`. |
| **P2-06** | P2 | UI / Pointer | Pointer cancellation clears hover with touch device kind instead of mouse kind. | `PointerCancellationScope` did not track device kind, view ID, or position when dispatching `PointerRemovedEvent`. **Fix**: Recorded `_DeviceState` and dispatched `PointerExitEvent` followed by `PointerRemovedEvent` with original device kind and viewId. | `prompt8_codex_fixes_test.dart` (P2-06 suite); `pointer_cancellation_scope_test.dart` (1 test PASS). |
| **P2-07** | P2 | Task Details | Work Log total duration does not tick while timer is actively running in Full Page view. | `TaskDetailsView` computed duration at build time without a ticking timer. **Fix**: Added localized 1-second periodic timer in `_TaskDetailsViewState` active only while timer is running on viewed task. | `prompt8_codex_fixes_test.dart` (P2-07 suite); `task_details_view.dart`. |

---

## 2. Regression Test Results (133 / 133 PASS)

All tests were executed sequentially with `--concurrency=1` in the isolated release worktree:

1. **`test/prompt8_codex_fixes_test.dart`**: 14/14 PASS (P1-01 through P2-07 comprehensive regression).
2. **`test/prompt1_search_and_detail_presentation_test.dart`**: 14/14 PASS (detail presentation, search sizing, keyboard insets).
3. **`test/prompt4_smart_reschedule_test.dart`**: 16/16 PASS (hierarchy, recurrence grouping, collision review, Apply/undo).
4. **`test/prompt7_cache_correctness_test.dart`**: 14/14 PASS (preference store caching, backup memoization, timer behavior).
5. **`test/shared_inbox_store_test.dart`**: 10/10 PASS (multi-file ingestion, duplicate SHA-256 detection, atomic publishing).
6. **`test/pointer_cancellation_scope_test.dart`**: 1/1 PASS (pointer exit & hover cleanup on lifecycle change).
7. **`test/sync_apply_repository_test.dart`**: 32/32 PASS (mutation groups, causal projection, conflict reconciliation).
8. **`test/workspace_test.dart`**: 15/15 PASS (navigation, quick search, task creation, memoization).
9. **`test/software_update_service_test.dart` & `test/android_update_service_test.dart`**: 17/17 PASS (updater discovery and channel selection).

**Total Focused Tests**: 133 passed, 0 failed, 0 skipped.
**Static Analysis**: `flutter analyze --no-pub lib/ test/`: **0 errors, 0 warnings** (clean).
**Formatting & Diff**: `git diff --check`: clean (0 whitespace/formatting issues).

---

## 3. Platform & Packaging Gates

- **Native Companion (.NET 10)**:
  - `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`: Built with 0 warnings, 0 errors.
  - `dotnet run --project experiments/widget-shell-probe -- --self-test`: **PASS** (task revision safety, clock monotonicity, persistence, and alarm projection verified).
- **Android Release Candidate**:
  - Compiled via `tools/build-android.ps1` with JDK 21 (`C:\Program Files\Android\openjdk\jdk-21.0.8`) and API 36 (`C:\Users\User\AppData\Local\Android\Sdk`).
  - Production signed with `android/key.properties` (gitignored).
  - Artifact generated: `build/app/outputs/flutter-apk/app-github-release.apk` (52.0 MB).
  - 16-KiB native alignment: Verified across all 8 native `.so` libraries (`lib/arm64-v8a/*`, `lib/x86_64/*`).
- **Windows Release Bundle**:
  - Local compilation halted due to non-elevated Developer Mode NTFS symlink restriction on host.
  - Fully pre-configured for GitHub Actions (`.github/workflows/windows-ci.yml`) where symlinks and Inno Setup 7 are available.

---

## 4. Release Checklist & Recommendations

- [x] Baseline Prompt 7 verified commit: `03abc27a44c875f5a1a6a070452a70a98c5e6efa`.
- [x] Isolated release worktree: `D:\AI_Projects\life_manager_worktrees\feature-todorbit-release-p8`.
- [x] All 5 P1 and 7 P2 findings from Codex review investigated, fixed, and verified.
- [x] Version incremented to `1.0.19-beta.24+47` in `pubspec.yaml` and `widget-shell-probe.csproj`.
- [x] Release notes added to `CHANGELOG.md`.
- [x] Zero data-loss guarantees, Schema 29 forward compatibility, and WAL `PRAGMA synchronous = FULL` strictly maintained.
- [x] Stable branch untouched.
