# AI Review Queue

## TDAT-SAFETY-GATE-01 — TDAT Final Safety Gate, CI Enforcement, and Runtime Reclassification (2026-11-25)

- **Scope & Addressed Requirements**:
  - Hardened `Impact.psm1` (committed/staged/unstaged/deleted/renamed/untracked handling, reverse Dart dependency graph, broad conservative fallback, real `-Execute` shadow verification + rule-gap logging).
  - Hardened `Evidence.psm1`, `Registry.psm1`, `verify.ps1`, and `dev.ps1` so `dev verify changed` saves/reuses passing receipts, rejects mid-execution source mutations, preserves `Ineligible` status across `dev registry --refresh`, and routes Python checks separately from `flutter test`.
  - Fixed `Doctor.psm1` bare `flutter`/`dart` calls, added `ANDROID_HOME\platform-tools` to PATH, added Windows Developer Mode check, and completed `time-tracking` in `feature_contexts.json` (23/23 features).
  - Reclassified `dev runtime windows` honestly as Flutter test-harness SQLite persistence, added `test_driver/windows_runtime_workflow_test.dart` for `-LiveApp` two-process UI restart, and verified `BLOCKED` reporting for disabled Developer Mode and missing Android 16 KiB emulator/APK.
  - Enforced `tools/test_registry_sync.py` and `tools/test_process_invocation_safety.py` in `.github/workflows/ci.yml`, plus full TDAT safety suites in `.github/workflows/windows-ci.yml`.
- **Status**: Implemented and locally verified on `feature/todorbit-developer-toolkit`; queued for Codex review.

## UI-SETTINGS-UPDATE-SYNC-03 — Settings Hub, Software Updates, and Sync Progressive Disclosure (2026-11-20)

- **Scope & Addressed Requirements**:
  - Refined existing Settings Hub, Software Updates, and Sync Settings interfaces to enforce consistency, clarity, progressive disclosure, and responsive keyboard adaptability without touching underlying SQLite schemas, sync protocols, or cloud/encryption architecture.
  - **Settings Hub Dialog Viewport & Keyboard Adaptability**:
    - Accounted for `MediaQuery.viewInsetsOf(context).bottom` in `SettingsHubDialog` (`availableHeight = size.height - insets.bottom - 48`) and bounded height with `math.max(320, math.min(720, availableHeight))`, ensuring complete compliance with UI Quality Gate 1 (Keyboard-Inset & Viewport-Aware Dialogs) on short landscape viewports or when virtual keyboards appear.
    - Assigned explicit `ValueKey('settings-section-picker')` to `AnchoredSelectField<_SettingsPage>` to disambiguate the section picker from internal section-level select fields in automated tests and accessibility trees.
  - **Sync Settings Progressive Disclosure & Card Harmonization**:
    - Replaced raw, unstyled `ExpansionTile` widgets in `SyncSettingsPage` with canonical `SettingsSection` cards for `Safe diagnostic details`, `Encryption options`, `Advanced`, and `Recovery` (replace cloud sync).
    - Added `expansionKey` support to `SettingsSection` to permit dynamic programmatic expansion/collapse resets across controller updates (e.g. `resetPending`, `encryptionExpanded`) without getting trapped by stale `PageStorageKey` entries.
    - Preserved exact section ordering, titles, Standard Sync vs Private Encrypted Sync domain options, CAS concurrency tokens, reset flows, and recovery code entry.
  - **Software Updates Clarity & Accessibility**:
    - Added explicit `semanticsLabel: 'Update download progress'` to `LinearProgressIndicator` in `SoftwareUpdatesPage` for screen reader accessibility.
    - Preserved the strict vertical presentation ordering required by desktop and Android update workflows: `'Installed version'`, `'Update status'`, `'Available update'`, `'Last checked'`, `'Automatically check for updates'`, `'Update channel'`, `'Check for Updates'`, `'Download update'`, and collapsible `'Details'`.
  - **Skill Strengthening**:
    - Updated `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md` documenting `SettingsSection` card harmonization and `expansionKey` pattern for progressive disclosure.
- **Source Paths Modified / Created**:
  - `lib/features/shared/settings_section.dart`
  - `lib/features/settings/settings_hub_dialog.dart`
  - `lib/features/settings/sync_settings_page.dart`
  - `lib/features/settings/software_updates_page.dart`
  - `test/settings_hub_test.dart`
  - `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`
  - `docs/AI_REVIEW_QUEUE.md`
  - `docs/PROGRESS.md`
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub lib/features/settings lib/features/shared test/settings_hub_test.dart` -> "No issues found!" (exit 0).
  - Focused Settings, Update & Sync Suites:
    - `test/settings_hub_test.dart` -> 2/2 passed.
    - `test/software_updates_page_test.dart` -> 2/2 passed.
    - `test/sync_conflicts_dialog_test.dart` -> 44/44 passed.
    - `test/settings_ui_quality_test.dart` -> 10/10 passed.
    - `test/android_software_updates_page_test.dart` -> 4/4 passed.
  - Regression Suites (Foundation & Task Rows):
    - `test/app_task_row_test.dart` -> 7/7 passed.
    - `test/task_editor_ui_consistency_test.dart` -> 4/4 passed.
    - `test/workspace_draft_safety_test.dart` -> 14/14 passed.
    - Total Passing Tests: 87 tests.
- **Status**: Production Flutter code implemented and verified. Queued for Codex independent review.

## UI-FOUNDATION-TASK-ROW-02 — Shared AppTaskRow Component & Task Editor Polish (2026-11-20)

- **Scope & Addressed Requirements**:
  - Implemented reusable production `AppTaskRow` in `lib/features/shared/app_task_row.dart`, eliminating duplicated task-row presentation code across desktop (`workspace.dart`) and mobile (`mobile_workspace.dart`).
  - **Shared Contract & Presentation Encapsulation**:
    - Centralized task completion checkbox, title 2-line clamping with natural wrapping, line-through decoration and dimming when completed, planned date vs deadline distinction, overdue warning presentation, priority token color coding, alarm indicator, and subtask/checklist progress badges.
    - Kept business logic, database transactions, SQLite writes, and navigation handling strictly outside the presentation widget; callers provide domain models (`LifeTask`), pre-resolved progress numbers, and callbacks (`onTap`, `onToggleComplete`, `onLongPress`, `quickStartAction`, `trailingActions`).
  - **Platform-Appropriate Variants**:
    - Desktop: Min-height 52dp, `Card` + `InkWell`, hover/selection background tinting, task icon, `Wrap` badges for metadata (subtasks, checklist, focus, plan, due, blocked by prerequisites), priority flag icon with semantic tokens, inline timer/quick-start button, and desktop popup action menu.
    - Mobile: Min-height 56dp, `Card` + `ListTile`, rich text subtitle with ` · ` delimiters (priority, status, planned date, overdue due date, category, project), warning amber icon + red due text on overdue tasks, alarm indicator, long-press bottom sheet trigger, and trailing more-actions button.
  - **Task Editor Microcopy Polish**:
    - Removed redundant helper descriptions ("Optional for a new task", "Optional planning details") in `task_editor.dart` when editing existing tasks (`widget.task != null`), eliminating visual clutter.
  - **AI Skill Strengthening**:
    - Updated `AGENTS.md` and `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md` to document `AppTaskRow` inspection and usage, shared presentation component patterns, and deduplication principles.
- **Source Paths Modified / Created**:
  - `lib/features/shared/app_task_row.dart` (new)
  - `lib/features/shared/app_theme_tokens.dart` (added `colorForPriority` helper)
  - `lib/features/workspace/task_editor.dart`
  - `lib/features/workspace/workspace.dart`
  - `lib/features/mobile/mobile_workspace.dart`
  - `test/app_task_row_test.dart` (new)
  - `AGENTS.md`
  - `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`
  - `docs/PROGRESS.md`
  - `docs/AI_REVIEW_QUEUE.md`
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub` -> "No issues found!" (exit 0).
  - Dedicated Component Tests: `test/app_task_row_test.dart` -> 7/7 passed (desktop layout, subtasks/checklist/priority badges, overdue error styling, completed decoration, mobile layout with ListTile, overdue warning amber icon, narrow layout and 1.5x text scaling).
  - Integration & Regression Suites:
    - `test/workspace_test.dart` -> 15/15 passed.
    - `test/mobile_workspace_test.dart` -> 23/23 passed.
    - `test/task_editor_ui_consistency_test.dart` -> 4/4 passed.
    - `test/workspace_draft_safety_test.dart` -> 14/14 passed.
    - Total Passing Tests: 63 tests.
- **Status**: Production Flutter code implemented and verified. Queued for Codex independent review.

## UI-FOUNDATION-PILOT-01 — Flutter UI Foundation & Task Create/Edit Consistency Pilot (2026-11-20)

- **Scope & Addressed Requirements**:
  - Implemented production Flutter UI foundation and Task Create/Edit consistency pilot on `design-foundation-docs`.
  - **Token & Layout Centralization**: Extended `lib/features/shared/app_spacing.dart` with `AppLayout` providing centralized responsive breakpoints (`breakpointCompact=600`, `breakpointMedium=1050`, `breakpointWide=1200`), side-panel sizing (`panelDefaultWidth=370`, `panelWideWidth=440`), modal dialog bounds (`dialogDefaultWidth=520`, `dialogWideWidth=600`, `dialogDefaultHeight=620`, `dialogMaxHeight=680`), minimum accessible tap target (`minTapTarget=48`), and standard page insets. Replaced magic numbers in `workspace.dart` and `task_editor.dart`.
  - **ThemeExtension Design Tokens**: Created `TodorbitThemeTokens` in `lib/features/shared/app_theme_tokens.dart` implementing semantic priority colors (none, low, medium, high) and status colors (notStarted, inProgress, waiting, onHold, completed, cancelled) with dark and light theme factories and lerp/copyWith support; integrated into `buildAppTheme` (`app_theme.dart`).
  - **Responsive Modal Abstraction**: Created `AppModalShell` and `showAppModal` in `lib/features/shared/app_modal_shell.dart`, unifying dialog sizing constraints, keyboard avoidance (`media.viewInsets.bottom`), and animation style across desktop and tablet modal dialogs. Replaced ad-hoc dialog builders in `workspace.dart` and `task_details_view.dart`.
  - **Task Create/Edit Consistency & In-Place Validation**: Refactored `TaskEditor` in `lib/features/workspace/task_editor.dart`:
    - Added in-place field error feedback on `title` TextField (`errorText: titleError`) that appears immediately upon save attempts with an empty title and clears upon typing.
    - Replaced raw unstyled `ExpansionTile` with structured `SettingsSection` cards for Status and priority, Estimates and schedule protection, and Prerequisites, delivering visual rhythm, borders, and progressive disclosure consistency across sections.
    - Enforced minimum accessible hit targets (48dp) on icon buttons and date clear actions.
    - Preserved draft safety, dirty state tracking, unsaved-edit guards, recurrence rules, alarms, subtasks, dependencies, and Riverpod controller contracts.
  - **Search Navigation Draft Safety**: Wired `beforeNavigate: _prepareEditorChange` in `QuickSearchDialog` to protect active drafts during search result navigation.
  - **AI Skill Strengthening**: Updated `AGENTS.md`, `.agents/skills/ultimate-ui-ux/SKILL.md`, `design-standards.md`, and `flutter-engineering.md` with explicit mandates for shared component/token inspection and reuse, in-place error presentation, and responsive modal dialog bounding.
- **Source Paths Modified / Created**:
  - `lib/features/shared/app_spacing.dart`
  - `lib/features/shared/app_theme_tokens.dart` (new)
  - `lib/features/shared/app_modal_shell.dart` (new)
  - `lib/features/shared/app_theme.dart`
  - `lib/features/workspace/task_editor.dart`
  - `lib/features/workspace/workspace.dart`
  - `lib/features/workspace/task_details_view.dart`
  - `test/task_editor_ui_consistency_test.dart` (new)
  - `test/workspace_draft_safety_test.dart`
  - `AGENTS.md`
  - `.agents/skills/ultimate-ui-ux/SKILL.md`
  - `.agents/skills/ultimate-ui-ux/references/design-standards.md`
  - `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`
  - `docs/PROGRESS.md`
  - `docs/AI_REVIEW_QUEUE.md`
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub` across the entire repo -> "No issues found!" (exit 0, 159.3s).
  - Component & Layout Tests: `test/task_editor_ui_consistency_test.dart` -> 4/4 passed (Theme tokens, in-place error validation, AppModalShell constraints, SettingsSection grouping).
  - Polish & Schedule Tests: `test/task_editor_ui_polish_test.dart` -> 3/3 passed.
  - Schedule Layout Tests: `test/task_editor_schedule_layout_test.dart` -> 1/1 passed.
  - Draft Safety Tests: `test/workspace_draft_safety_test.dart` -> 14/14 passed (desktop draft survival, escape handling, dialogs, resize, discard).
  - Workspace Integration Tests: `test/workspace_test.dart` -> 15/15 passed (recurrence, creation, duration, shortcuts, memoization).
  - Total Passing Pilot Tests: 37 tests.
- **Status**: Production Flutter code implemented and verified. Queued for Codex independent review.

## UI-REDESIGN-FOUNDATION — UI/UX Redesign Foundation, Design System Architecture, Visual Concepts (Iteration 2 Refinement), and AI Rules (2026-11-20)

- **Scope & Addressed Requirements**:
  - Reconciled repository baseline on `design-foundation-docs` (branched from `codex/fix-phantom-sync-conflict`). Corrected unsupported claims regarding token refactoring and test plan generation.
  - Formulated comprehensive **Design System Architecture** (`docs/UI_DESIGN_SYSTEM.md`) covering tokens, Progressive Disclosure, component reuse, accessibility, responsive breakpoints, developer customization via `TodorbitThemeTokens`, and regression-prevention rules.
  - Produced initial Concepts A & B (`concept-a-refined-minimalist.html`, `concept-b-modern-workspace.html`), followed by **Concept C (Adaptive Productivity Workspace)**. Preserved v1 as `concept-c-adaptive-workspace.v1.html` and finalized UX refinement in `docs/design-concepts/concept-c-adaptive-workspace.html`.
  - Concept C Refinements: Fixed task title truncation via 2-line flexible wrapping; removed card nesting in details editor; added realistic academic/errand/appointment sample data; integrated Today's fixed events timeline and active focus session banner; added multi-viewport simulation (1440, 1100, 820, 390), text scaling (100%, 125%, 150%), and empty state preview.
  - Preserved Todorbit's actual domain model: Priorities (0=None, 1=Low, 2=Med, 3=High), TaskStatuses, and dual schedule roles (Planned Date vs Deadline).
  - Specified the first safe implementation pilot (`docs/UI_IMPLEMENTATION_STRATEGY.md`) covering `AppTaskRow` and `AppTaskDetailPanel`, identifying ARCH-02/03/04/07 on `feature/todorbit-release-p8` as prerequisites.
  - Established permanent AI coding quality standards in `docs/AI_UI_DEVELOPMENT_RULES.md`.
- **Source Paths Modified / Created**:
  - `docs/UI_FOUNDATION_HANDOFF.md`
  - `docs/UI_DESIGN_SYSTEM.md`
  - `docs/UI_IMPLEMENTATION_STRATEGY.md`
  - `docs/UI_DESIGN_CONCEPTS_EVALUATION.md`
  - `docs/AI_UI_DEVELOPMENT_RULES.md`
  - `docs/design-concepts/concept-a-refined-minimalist.html`
  - `docs/design-concepts/concept-b-modern-workspace.html`
  - `docs/design-concepts/concept-c-adaptive-workspace.v1.html`
  - `docs/design-concepts/concept-c-adaptive-workspace.html`
  - (Zero production Dart/Flutter files modified).
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub` -> "No issues found!" (exit code 0, 335.2s, run on current codebase at commit `5803e52`).
  - Git diff check: `git diff --check --staged` -> 0 issues found (clean formatting).
  - Prototype Verification: All 5 preview states (Desktop Wide, Desktop Medium, Narrow, Mobile, Empty State, Text Scaling, Accordion Disclosures, Drag-to-Resize) tested offline in browser environment.
- **Status**: Documentation and visual concepts completed on branch `design-foundation-docs`. Queued for Codex independent review and product owner design selection. No production code altered.

---

## Beta 25 Architecture Program Integrated & Published (2026-11-20)

- **Branch**: `feature/todorbit-release-p8`
- **Release Commit**: `6b75a559a1b7d3f9d849ba9ed27c7a291124d554`
- **Target Version**: `1.0.19-beta.25+48` (versionName `1.0.19-beta.25`, versionCode `48`, tag `v1.0.19-beta.25`)
- **Published Release URL**: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.25
- **Remote CI Verification**:
  - **Windows checks** ([Run 44694169827](https://github.com/2HIK4/Todorbit/actions/runs/44694169827)): **SUCCESS** in 29m43s (1,180+ tests passed, CRT verified, native sync writer, background sync barriers, native widget self-test, Inno Setup installer compiled, portable zip generated).
  - **Android validation** ([Run 44694185735](https://github.com/2HIK4/Todorbit/actions/runs/44694185735)): **SUCCESS** in 9m55s (`android` and `android-workflow` both green; 16-KiB alignment and emulator updates verified).
  - **Android 16 KiB runtime** ([Run 44699666409](https://github.com/2HIK4/Todorbit/actions/runs/44699666409)): **SUCCESS** in 3m41s on `google_apis_ps16k` API 36 emulator.
- **Lightweight CI**: Validated locally across all Python checks, 39 architecture boundary checks, and 13 critical regression test suites (103/103 passed in 3m02s) with zero errors.
- **Architecture Program Scope (ARCH-02 through ARCH-09)**:
  - ARCH-02: Platform resource dialog refactoring (`lib/platform/platform_resource_dialog.dart`), eliminating 4 feature import cycles.
  - ARCH-03: `SyncStatusButton` decoupling from `features/settings` via `onOpenSettings` and `onOpenConflicts`.
  - ARCH-04: Calendar and Workspace boundary decoupling via `SessionEditor` relocation to `features/scheduling` and `EditorNavigationController`.
  - ARCH-05: Strongly typed `AppRefreshSnapshot` in `lib/app/app_refresh_snapshot.dart` and `AppController.refresh` refactoring.
  - ARCH-06: State encapsulation (unmodifiable collections, selector equality, timer isolation).
  - ARCH-07: Atomic Drift transactions, CAS revision protection, and sync sequence preservation.
  - ARCH-08: Optional feature modularity and sync safety evaluation.
  - ARCH-09: Architecture documentation and 39 boundary checks in CI.
- **Release Assets**: All 10 Windows and Android assets uploaded and verified with SHA-256 checksums; updaters verified.
- **Safety**: Schema remains at 29; zero schema migrations; crash resilience preserved; Stable untouched.
- **Status**: **PUBLISHED (Experimental Pre-Release)**. See [Publication Report](UIUX06_BETA_25_PUBLICATION.md).

## Beta 24 Windows CI corrections integrated & published (2026-11-19)

- **Merged branch**: `fix/todorbit-beta24-windows-ci` (commit `f568820e894ef6772cc39399bccfdbe8517132ae`) into `feature/todorbit-release-p8` at merge commit `16de251cc0208ade5d54bbdebf26c60a278ac86f` (0 conflicts).
- **Windows CI**: [Run 44411095342](https://github.com/2HIK4/Todorbit/actions/runs/44411095342) passed in 33m55s (**1,178 passed, 0 failed, 9 skipped**). All 12 previously failing tests resolved.
- **Android CI**: [Run 44411102129](https://github.com/2HIK4/Todorbit/actions/runs/44411102129) passed.
- **Published**: GitHub pre-release `1.0.19-beta.24+47` (tag `v1.0.19-beta.24`) live at https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.24. All 10 Windows and Android release assets verified.
- [Failure and verification receipt](BETA24_WINDOWS_CI_FAILURE_FIXES.md); [Publication report](UIUX05_BETA_24_PUBLICATION.md).

## Beta 24 release-blocker integration review (2026-11-18)

**INTEGRATION VERIFIED; PUBLICATION BLOCKED BY WINDOWS CI GATE.**
- **Merged commit** `12d7e46fe47d4da761b13b1be995b8c7420e157c` on `feature/todorbit-release-p8`.
- **Merged Branch**: `fix/todorbit-beta24-release-blockers` (commit `cfde5b3b85d2cbc460be8fcf06075707c7481283`, base `253bc54eb74300505793cf0a6e5328a3858f23da`).
- **Codex Findings Verified**:
  - P1-01: Sync causal history preserved. Zero SQLite startup deletions. Exact retry byte preservation and peer envelope application verified.
  - P1-02: Android Shared Inbox native worker synchronization, checked `Os.fsync`, atomic manifest publication before unlinking. Task attachments survive inbox clear.
  - P1-03: Workspace unsaved editor guard awaits Save/Discard/Keep editing across Side Panel and Full Page modes. Failed saves preserve drafts.
  - P1-04: Smart Reschedule validates recurring occurrences, moved/cancelled exceptions, and existing sessions in the transaction.
  - Related: Immediate Sync signaling on commits and Calendar external date mid-drag deferral verified.
- **Verification Summary**:
  - 107 focused host tests PASS (100% pass across critical suites).
  - Static analysis: `flutter analyze --no-pub` -> 0 issues (clean).
  - Diff check: `git diff --check` -> clean.
  - Native Companion: .NET 10 Release build and `--self-test` PASS.
  - Android Release APK: Compiled via `tools/build-android.ps1`, production signed, 16-KiB native alignment verified (SHA-256 `107BDBD497455AE80444D17C5DB33CF9DCE05287D2BE6A91C654BA5DD373DAE7`).
  - GitHub Actions Android CI ([Run 44390832263](https://github.com/2HIK4/Todorbit/actions/runs/44390832263)): SUCCESS (8m29s).
  - Windows CI failed at `Run Flutter tests` before installer and portable packaging. The twelve failures include two application regressions, five outdated tests and five test-infrastructure failures. [Run 44390804115](https://github.com/2HIK4/Todorbit/actions/runs/44390804115), [failure receipt](BETA24_WINDOWS_CI_FAILURE_FIXES.md).
- **Status**: Publication BLOCKED per mandatory release gates 2, 3, and 8. See [Beta 24 Verification & Publication Report](UIUX05_BETA_24_PUBLICATION.md).

## Historical Prompt 8 — Final Release Verification (2026-11-18)

- **Branch**: `feature/todorbit-release-p8`
- **Worktree**: `D:\AI_Projects\life_manager_worktrees\feature-todorbit-release-p8`
- **Base Commit**: `03abc27a44c875f5a1a6a070452a70a98c5e6efa` (Prompt 7 verified baseline)
- **Codex Findings Evaluated & Repaired (5 P1s, 7 P2s)**:
  - **P1-01 (Mixed-version Sync & Rollback Compatibility)**: Fixed in `lib/domain/sync/portable_preferences.dart`, `lib/app/app_controller.dart`, and `lib/data/app_database.dart`. Added `detailPresentation` to `deviceLocalThemeFields`, removed from `validatePortablePreference` and `AppController.setTaskViewPreferences`, pruned legacy rows from SQLite `portable_preferences` table on open. Retained in local profile JSON and settings transfer.
  - **P1-02 & P2-01 (Android Shared Inbox Multi-File & Security Hardening)**: Fixed in `android/app/src/main/kotlin/io/github/hik4/todorbit/ShareReceiverActivity.kt` and `lib/data/shared_inbox_store.dart`. Synchronized batch manifest updates, accumulated entries to prevent overwriting earlier files in multi-stream intents, verified `renameTo` with fallback, combined `EXTRA_STREAM` and `clipData`, rejected non-content schemes and self-package URI paths.
  - **P1-03 & P1-05 (EventEditor State Reuse & Unsaved Navigation Guards)**: Fixed in `lib/features/calendar/event_editor.dart`, `lib/features/workspace/task_editor.dart`, `lib/features/workspace/workspace.dart`, `lib/features/workspace/quick_search.dart`, and `lib/features/search/advanced_search_dialog.dart`. Attached `key: ValueKey((event.id, nominalDate, editorRevision))`, implemented `didUpdateWidget` and `_initFromEvent()`, exposed `attach()`/`detach()` on `TaskEditorController`, attached `confirmLeave()` unsaved guard, and wired `beforeNavigate: _prepareEditorChange` before search navigation.
  - **P1-04 (New Task in Full Page on Wide Windows)**: Fixed in `lib/features/workspace/workspace.dart`. Rendered full-page `TaskEditor` in `_mainPanel` when `controller.isFullPageDetails && creating`. Reset `newTaskInitialDate = null` on close.
  - **P2-02 (Smart Reschedule Split Session Collision Detection)**: Fixed in `lib/domain/scheduling_engine.dart` and `lib/features/scheduling/smart_reschedule.dart`. Added fixed event and session overlap detection via `overlaps()`, flagging `ScheduleIssueKind.fixedEventCollision` and `ScheduleIssueKind.sessionCollision`.
  - **P2-03 (Calendar Recurring Materialization Stale Stats/Sync)**: Fixed in `lib/app/app_controller.dart`. Included `repository.reportTasks()` in `refreshCalendarWindow()`.
  - **P2-04 (Closing Event Details Resetting Calendar Date)**: Fixed in `lib/features/calendar/calendar_view.dart` and `lib/features/workspace/workspace.dart`. Added `onDateSelected` callback and tracked `_lastCalendarDate`.
  - **P2-05 (Parent Expander Pill Overlapping Timer Button)**: Fixed in `lib/features/shared/task_list_group.dart` and `lib/features/workspace/workspace.dart`. Increased trailing end margin to 96dp and added active timer state badges for child tasks.
  - **P2-06 (Pointer Cancellation Clearing Hover with Mouse Kind)**: Fixed in `lib/features/shared/pointer_cancellation_scope.dart`. Tracked mouse device kind, view ID, and position; dispatched both `PointerExitEvent` and `PointerRemovedEvent`.
  - **P2-07 (Work Log Duration Ticker in TaskDetailsView)**: Fixed in `lib/features/workspace/task_details_view.dart`. Ran a localized 1-second periodic ticker while the timer is actively running on the viewed task.
- **Verification Evidence**:
  - `test/prompt8_codex_fixes_test.dart`: 14/14 PASS.
  - `test/prompt1_search_and_detail_presentation_test.dart`: 14/14 PASS.
  - `test/prompt4_smart_reschedule_test.dart`: 16/16 PASS.
  - `test/prompt7_cache_correctness_test.dart`: 14/14 PASS.
  - `test/shared_inbox_store_test.dart`: 10/10 PASS.
  - `test/pointer_cancellation_scope_test.dart`: 1/1 PASS.
  - `test/sync_apply_repository_test.dart`: 32/32 PASS.
  - `test/workspace_test.dart`: 15/15 PASS.
  - `test/software_update_service_test.dart` & `test/android_update_service_test.dart`: 17/17 PASS.
  - Total focused regression tests: 133/133 PASS.
  - Static analysis: `flutter analyze --no-pub lib/ test/`: 0 errors, 0 warnings.
  - Native companion self-test: `dotnet run --project experiments/widget-shell-probe -- --self-test`: PASS.
  - Android universal release APK: compiled via `tools/build-android.ps1` with JDK 21 and API 36; production signed; all 8 native libraries verified with 16-KiB page alignment.
  - Git diff check: `git diff --check` clean.
- **Status**: Superseded by the Beta 24 release-blocker integration review above.

## Prompt 7 — Evidence-Based Startup, Memory & Performance Optimization (2026-11-18)

- **Branch**: `feature/todorbit-performance-p7`
- **Worktree**: `D:\AI_Projects\life_manager_worktrees\feature-todorbit-performance-p7`
- **Base Commit**: `016537ff32715b200a14be1e0a01595cf71b6cd3` (Prompt 6 verified base)
- **Scope & Implementation Summary**:
  - **Eliminated Active Timer Full-Page Rebuilds**: Removed the redundant 1-second `_clock` timer in `Workspace`, which was triggering full-page `setState(() {})` every second during active timers. Reduced 3-second active timer test workload by 59.3% (1839.41 ms -> 749.44 ms). Verified in `test/prompt7_cache_correctness_test.dart` that `CompactTaskTimer` ticks independently and task rows reflect status transitions ('Timer running', 'Timer paused') via controller state notifications without any UI drift.
  - **SQLite Durability Preserved at FULL**: Enforced explicit `PRAGMA synchronous = FULL;` in WAL mode on `AppDatabase.openDefault()`, strictly maintaining zero-data-loss guarantees across power cuts and OS crashes without compromising data safety for benchmarks.
  - **Preference Stores Caching & Write Idempotency**: Added in-memory map caching in `AppearancePreferenceStore` and `CalendarPreferenceStore` with dual `(stat.modified, stat.size)` freshness validation. Skipped `_write` when serialized content matches disk, eliminating redundant disk writes on startup.
  - **Snapshot Schema Memoization & Mandatory Validation on Restore**: Added `_hasRecentAutomaticBackup` in `BackupService` using filename timestamps and file stats. Memoized verified snapshot schemas in `_schemaCache` for listing in UI; strictly preserved isolated `PRAGMA quick_check` and complete schema validation for all restore and import flows.
  - **Targeted Calendar Window Refreshes**: Replaced monolithic 29-table `refresh()` during month navigation with targeted `refreshCalendarWindow()` querying only 4 collections (`events`, `todayEvents`, `tasks`, `taskParents`).
  - **Task List Projection Memoization**: Memoized `projectTaskList` in `task_list_projection.dart` for identical input lists and parent maps across both desktop and mobile shells.
  - **Single-Mount Startup Pipeline**: Removed intermediate `StartupPage` pre-mount in `main.dart`, eliminating double widget tree construction and the ~100ms loading flicker.
  - **Disposal Safety Guards**: Added `if (_disposed) return;` at the top of `notifyListeners()` and `select()` in `AppController` to prevent assertions when async operations finish after teardown.
  - **Comprehensive Benchmark & Correctness Suites**: Created `test/performance_benchmark_test.dart` (15 scenarios) and `test/prompt7_cache_correctness_test.dart` (14 cache & timer tests). Disclosed test runner variance and synthetic execution boundaries.
  - **Receipt**: [PROMPT7_PERFORMANCE_OPTIMIZATION_2026_11_18.md](PROMPT7_PERFORMANCE_OPTIMIZATION_2026_11_18.md).
- **Status**: IMPLEMENTED & SAFETY-AUDITED — AWAITING INDEPENDENT INTEGRATION REVIEW. No beta publication, no release tag, Stable untouched.

---

## Prompt 6 — Full App-Wide UI Audit, Coherent Design System & Interaction Polish (2026-11-18)

- **Branch**: `feature/todorbit-full-ui-audit`
- **Worktree**: `D:\AI_Projects\life_manager_worktrees\feature-todorbit-full-ui-audit`
- **Base Commit**: `b95474f11bba577f59d48cb6f6375419f24fdcb8`
- **Scope & Implementation Summary**:
  - **Task Hover & Focus Coherence**: Resolved bright rectangular hover boxes by configuring subtle hover tokens (`hoverColor = onSurface.withValues(alpha: 0.04)`), distinct high-contrast keyboard focus indicators (`focusColor = primary.withValues(alpha: 0.14)`), `cardTheme.clipBehavior = Clip.antiAlias`, and `listTileTheme.shape = RoundedRectangleBorder(borderRadius: 10)` in `app_theme.dart`.
  - **Pointer Cancellation & Window Blur Cleanup**: Implemented `PointerCancellationScope` (`lib/features/shared/pointer_cancellation_scope.dart`) listening to `AppLifecycleState.inactive`, cancelling in-flight pointers and flushing hovered mouse annotations to eliminate stuck hover/pressed highlights after Windows screenshot capture (<kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd>).
  - **Task Row Width Normalization**: Normalized outer margins (`only(bottom: 8)` desktop, `symmetric(h: 16, v: 4)` mobile) and corner radii on recurring task group containers, eliminating the 8px width discrepancy between recurring and ordinary task rows.
  - **Subtask Hierarchy Redesign**: Removed heavy standalone decorative cards from subtasks. Redesigned `TaskListGroupView` to render clean interactive child rows with 24dp indentation, a 2px vertical connector line, and an integrated parent expand/collapse toggle pill.
  - **Destructive Confirmation Clarity**: Standardized error styling (`FilledButton.styleFrom(backgroundColor: error, foregroundColor: onError)`) and safe Cancel/<kbd>Esc</kbd> defaults across `_confirm`, `_confirmPurge`, `PlannedSessionDelete`, `_remove`, and `_removeResource`.
  - **Shared Files Retention Clarity**: Added clear on-device storage tooltips and empty-state messaging in `SharedInboxScreen` and `SharedInboxPickerDialog` explaining that unattached files remain local and are excluded from cloud sync until attached to a task.
  - **Skills Updated**: Strengthened `.agents/skills/ultimate-ui-ux/references/design-standards.md` with Section 4 covering coherent visual states, pointer lifecycle, geometry, and hierarchy.
  - **Receipt**: [PROMPT6_FULL_UI_AUDIT_2026_11_18.md](PROMPT6_FULL_UI_AUDIT_2026_11_18.md).
- **Status**: IMPLEMENTED — AWAITING INDEPENDENT INTEGRATION REVIEW. No beta publication, no release tag, Stable untouched.

---

## Prompts 4/5 integration checkpoint (2026-11-18)

- **Branch**: `integration/ui-reliability-p4-p5`
- **Worktree**: `D:\AI_Projects\life_manager_worktrees\integration-ui-p4-p5`
- **Integrated Commits**:
  - Prompt 4 (Smart Reschedule): `5a0e836437ce2c3831541d3221163843a8e47fae`
  - Prompt 5 (Android Share Inbox): `3b9867867b931f7689c9f66680b52cee3657fcef`
- **Scope & Independent Review Summary**:
  - **Prompt 4 (Smart Reschedule)**: Verified parent/subtask connectivity (`aa` and `1`), recurrence grouping by family identity (`OS quiz 15`), complete-proposal eligibility enforcement, grouped collision decisions, unsupported Combine/skipNew restrictions, preview invalidation, and async/write re-entry guards.
  - **Prompt 5 (Android Share Inbox)**: Audited synchronous I/O vs UI isolate performance. Enhanced `SharedInboxStore` to stream SHA-256 and copies for large files up to 32 MiB without holding full byte arrays in Dart heap. Provided non-blocking asynchronous APIs (`load()`, `save()`, `addFile()`, `addBytes()`) while preserving synchronous methods for zero-jank frame-1 hydration and deterministic test execution. Added `RefreshIndicator` to `SharedInboxScreen`.
  - **Cross-Feature Regression**: Executed 203 sequential tests across Smart Reschedule (20), Shared Inbox (23), Task Resources (10), Composition/Subtasks (24), Calendar/Events (15), Focus/Navigation/Workspace (18), Persistence & Concurrency (38), and Sync/Backup (55). 203/203 passed with 0 failures.
  - **Receipt**: [INTEGRATION_P4_P5_2026_11_17.md](INTEGRATION_P4_P5_2026_11_17.md).
- **Status**: Integrated and independently reviewed development checkpoint established for Prompt 6. No beta publication, no release tag, Stable untouched.

---

## Prompt 4 — Smart Reschedule (2026-11-17)

**IMPLEMENTED — AWAITING INDEPENDENT INTEGRATION REVIEW.** Codex implementation /
self-review on `feature/todorbit-smart-reschedule`, base `4d9292c`. Review hierarchy
and recurrence grouping by identity, complete-proposal eligibility, collision
choices, unsupported skip/Combine restrictions, invalidation and async/write
re-entry guards. [Receipt](PROMPT4_SMART_RESCHEDULE_2026_11_17.md) / [source manifest](PROMPT4_SMART_RESCHEDULE_2026_11_17_SOURCE.json):
64 distinct host tests PASS / 0 final FAIL / 0 SKIP, full analysis/format/doc/diff
checks PASS. No self-approval or approval of unrelated entries; prior History
unchanged. Physical/device/packaging remains in Deferred Verification.

---

## UI-REL-05 (Prompt 5) — Android Shared Files Inbox & Task Resource Integration (2026-11-18)

- **Branch & Base**: `feature/todorbit-android-share-inbox` descending from `4d9292c`.
- **Scope & Addressed Requirements**:
  - **Android Intent Ingestion Subsystem (`ShareReceiverActivity`)**: Dedicated native lightweight activity (`android/app/src/main/kotlin/io/github/hik4/todorbit/ShareReceiverActivity.kt`) with `@style/TranslucentShareTheme`, `noHistory="true"`, and `excludeFromRecents="true"`. Ingests `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intents safely and atomically via `ContentResolver` into app-private staging storage (`TodoPilot/shared_inbox/files/`) before temporary URI grants lapse. Displays minimal Toast confirmation ("File saved to Shared Inbox in Todorbit") and immediately finishes back to the sending app without forced task interface navigation. Cold-start safe: does not boot the Flutter engine. If Flutter engine is warm, notifies `MainActivity` via MethodChannel `sharedInboxUpdated`.
  - **Durable Local-Only Inbox Storage (`SharedInboxStore`)**: Preserves SQLite Schema 29 without any database migration. Maintains `shared_inbox.json` manifest with stable UUIDs, original display names, MIME types, file sizes, SHA-256 digests, and UTC timestamps. Implements atomic temporary-file writes (`.tmp` -> rename), 32 MiB size limits, content-addressable SHA-256 duplicate detection, filename sanitization, and orphan staging cleanup. Unattached inbox files remain strictly local-only on the device (zero Google Drive sync bloat, zero cloud exposure).
  - **Shared Files Screen (`SharedInboxScreen`)**: Accessible directly from the Android navigation drawer (`MobileWorkspace`). Features responsive list layout, category filter chips (All, PDFs, Images, Docs, Other), instant search, file metadata display, preview/open via `WindowsResourceDialog` and secure `FileProvider` (`attachment_paths.xml`), single file deletion with explicit confirmation dialog (`ISS-C11`), and multi-select batch deletion.
  - **Task Resources Integration (`From Shared Inbox`)**: Added `From Shared Inbox` action button to `UnifiedResourcesSection` for both draft new tasks (`UnifiedResourcesSection.draft`) and persisted tasks (`UnifiedResourcesSection.persisted`). Opens `SharedInboxPickerDialog` allowing multi-file selection with badge indicators for already-attached files (SHA-256 comparison) and oversized files (>16 MiB). Attaching copies bytes into SQLite `task_resources` as independent managed attachments with original display labels. Independent copy semantics: deleting a task attachment never touches the inbox original; deleting an inbox entry never breaks an existing task resource. Cancelling draft task creation leaves zero database records and leaves inbox originals untouched.
- **Source Paths Modified / Created**:
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/main/kotlin/io/github/hik4/todorbit/MainActivity.kt`
  - `android/app/src/main/kotlin/io/github/hik4/todorbit/ShareReceiverActivity.kt`
  - `android/app/src/main/res/values/styles.xml`
  - `android/app/src/main/res/xml/attachment_paths.xml`
  - `lib/data/shared_inbox_store.dart`
  - `lib/domain/shared_inbox_entry.dart`
  - `lib/features/mobile/mobile_workspace.dart`
  - `lib/features/shared_inbox/shared_inbox_picker_dialog.dart`
  - `lib/features/shared_inbox/shared_inbox_screen.dart`
  - `lib/features/workspace/unified_resources_section.dart`
  - `lib/platform/android/android_platform.dart`
  - `.agents/skills/todorbit-engineering-quality/references/cross-platform-architecture.md`
  - `docs/TODORBIT_UI_RELIABILITY_PROGRAM.md`
  - `docs/AI_REVIEW_QUEUE.md`
  - `docs/TEST_RUN_LEDGER.md`
  - `test/shared_inbox_store_test.dart`
  - `test/shared_inbox_screen_test.dart`
  - `test/shared_inbox_task_integration_test.dart`
  - `test/shared_inbox_mobile_navigation_test.dart`
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub lib/ test/` -> 0 issues found (12.4s).
  - `test/shared_inbox_store_test.dart` -> 10/10 passed (1s).
  - `test/shared_inbox_screen_test.dart` -> 7/7 passed (6s).
  - `test/shared_inbox_task_integration_test.dart` -> 5/5 passed (8s).
  - `test/shared_inbox_mobile_navigation_test.dart` -> 1/1 passed (2s).
  - `test/task_resources_test.dart` + `test/task_resources_widget_test.dart` -> 10/10 passed (27s).
  - `test/repository_test.dart` -> 8/8 passed (12s).
  - Total focused Level 1/2 tests executed: 41/41 passed with zero failures.
- **Status**: Unreviewed implementation queued for Codex independent review. No beta release or deployment performed.

---

## Prompts 2/3 integration checkpoint (2026-11-17)

Scoped review is complete; both submissions moved to [Review History](AI_REVIEW_HISTORY.md).
[Integration receipt](INTEGRATION_P2_P3_2026_11_17.md) records the fixes, 122 passed /
0 failed selected checks and remaining acceptance. No unrelated entry below is
approved by this task. Physical/release gates remain in Deferred Verification.

## UI-REL-01 (Prompt 1 Authoritative) — Search UX, progressive advanced search, keyboard insets, and single-route task/event detail presentation (2026-11-17)

- **Scope & Addressed Requirements**:
  - **Search UX Token & Interaction Unification**: Unified desktop sidebar and Android mobile header search bar layout and interactions (height 38–42px, focus ring with primary border, minimum 30dp icon touch targets, clear text affordance, responsive placeholder text, and preserving all existing search operators, saved views, and shortcuts).
  - **Advanced Search Progressive Disclosure**: Redesigned `AdvancedSearchDialog` with compact header, quick Reset action, lightweight one-time explanation for combination logic ("Filters combine with AND; options within each filter combine with OR."), and collapsible filter groups with human-readable summary badges. Preserved multi-select semantics, task match counter, and Save as Custom View.
  - **Android IME Keyboard Insets in Filters**: Fixed `AdvancedSearchDialog` height computation (`media.viewInsets.bottom` subtraction), smooth scrolling, stable scroll controller (chip taps do not jump to top or dismiss the keyboard), and auto-wrapping sticky footer via `DialogActionBar`.
  - **Single-Route Detail Presentation**: Replaced competing detail navigation with ONE route/state decision derived from persisted user Preferences (`ThemeCustomization.detailPresentation`):
    - `sidePanel` (default): Opens task/event editor in desktop side panel; main view remains visible.
    - `fullPage` (alternative): Opens task in `TaskDetailsView` or event in `EventEditor` in the main view; side panel is hidden.
    - Zero Stale Editors: Closing via Back, Cancel, or <kbd>Esc</kbd> atomically clears active selection, active event, and detail flags. Resolved shortcut bubbling in `CalendarView` and `EventEditor` so <kbd>Esc</kbd> reliably dismisses the active editor without revealing a dormant editor underneath.
  - **Action Button Hit-Testing**: Removed disruptive Scaffold-level SnackBar from task editor prerequisite saving that was intercepting hit-tests on bottom-docked action buttons in narrow/side-panel layouts.
- **Source Paths Modified**:
  - `lib/domain/task_view_preferences.dart`
  - `lib/domain/sync/portable_preferences.dart`
  - `lib/data/appearance_preference_store.dart`
  - `lib/app/app_controller.dart`
  - `lib/features/settings/task_view_settings_dialog.dart`
  - `lib/features/settings/settings_hub_dialog.dart`
  - `lib/features/settings/settings_transfer.dart`
  - `lib/domain/appearance.dart`
  - `lib/domain/theme_json.dart`
  - `lib/features/calendar/calendar_view.dart`
  - `lib/features/calendar/event_editor.dart`
  - `lib/features/workspace/workspace.dart`
  - `lib/features/mobile/mobile_workspace.dart`
  - `lib/features/search/advanced_search_dialog.dart`
  - `lib/features/workspace/task_editor.dart`
  - `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`
  - `docs/TODORBIT_UI_RELIABILITY_PROGRAM.md`
  - `test/prompt1_search_and_detail_presentation_test.dart`
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub lib/ test/prompt1_search_and_detail_presentation_test.dart` -> 0 issues found (13.2s).
  - `test/prompt1_search_and_detail_presentation_test.dart` -> 14/14 passed (27s).
  - `test/workspace_test.dart` -> 15/15 passed (30s).
  - `test/mobile_workspace_test.dart` -> 23/23 passed (41s).
  - `test/advanced_search_widget_test.dart` -> 2/2 passed (6s).
  - Level 2 Critical Persistence: `test/repository_test.dart` + `test/task_revision_concurrency_test.dart` + `test/database_initialization_test.dart` -> 38/38 passed (1m 43s).
  - Total Level 1/2 tests executed: 92/92 passed with zero failures.
- **Status**: Unreviewed implementation queued for Codex independent review. No beta release or deployment performed.

---

## UI-REL-00-PRE (Prompt 0.5 Foundation) — Viewport constraints, IME keyboard insets, responsive text scaling, and standardized card geometry (2026-11-17)

- **Scope & Addressed Issues**:
  - `ISS-C01`: Dialog & Sheet keyboard inset (IME) overflow. Fixed in `lib/features/workspace/workspace.dart`, `lib/features/calendar/calendar_view.dart`, `lib/features/workspace/checklist_item_dialog.dart`, `lib/features/workspace/sequence_dialog.dart`, and `lib/features/time_tracking/time_tracking_dialog.dart`. Clamped heights against `media.size.height - media.viewInsets.bottom - margin` and ensured scrollable wrappers prevent `RenderFlex overflowed` when software keyboard appears.
  - `ISS-C05` & `ISS-C06`: Standardized card geometry and responsive chips. Enforced `minHeight: 52` on desktop task rows and `minHeight: 56` with `maxLines: 2` on mobile task rows (`lib/features/mobile/mobile_workspace.dart`), ensuring optical checkbox alignment and eliminating list jumping when tasks gain or lose metadata.
  - `ISS-B02`: Calendar header responsiveness under narrow viewports (320dp) and 2.0× text scaling.
  - `ISS-B04`: Localized card clipping avoiding overlay clipping.
  - `ISS-B05`: Calendar agenda card geometry alignment.
  - `ISS-A01`: Alarm option label wrap constraints under high text scaling.
  - `ISS-C14`: Arabic BiDi text input alignment in task and event editors.
- **Source Paths Modified**:
  - `lib/features/workspace/workspace.dart`
  - `lib/features/calendar/calendar_view.dart`
  - `lib/features/workspace/checklist_item_dialog.dart`
  - `lib/features/workspace/sequence_dialog.dart`
  - `lib/features/time_tracking/time_tracking_dialog.dart`
  - `lib/features/mobile/mobile_workspace.dart`
  - `docs/TODORBIT_UI_RELIABILITY_PROGRAM.md`
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub lib/ test/` -> 0 issues found.
  - `test/workspace_test.dart` -> 15/15 passed (35s).
  - `test/task_editor_schedule_layout_test.dart` -> 1/1 passed (5s).
  - `test/mobile_workspace_test.dart` -> 23/23 passed (49s).
  - `test/calendar_test.dart` -> 3/3 passed (15s).
  - `test/checklist_layout_test.dart` + `test/remaining_dialog_layout_test.dart` + `test/time_tracking_widget_test.dart` -> 7/7 passed (18s).
  - `test/alarm_field_test.dart` + `test/task_editor_ui_polish_test.dart` -> 5/5 passed (18s).
  - Total Level 1/2 tests executed: 54/54 passed (0 failures).
- **Status**: Unreviewed implementation queued for Codex independent review. No beta release or deployment performed.

---

## SYNC-01 / UIUX-04 — Phantom sync conflict elimination, Focus timer rebuild optimization, and TaskDetails lifecycle safety (2026-11-17)

- **Scope & Problem**:
  1. **Phantom sync conflicts**: `syncExchangeStatus()` previously counted raw `blocked_reason IS NOT NULL` in `sync_mutation_groups`, causing conflict badges to display even when descendant mutations superseded earlier conflicting edits or when the review projection had zero conflicts needing user decisions. Additionally, unhandled `StateError` on large groups was uncontained.
  2. **Review Dialog & Status presentation**: `SyncConflictsDialog` showed an empty "Keep this device for all (0)" dialog or ambiguous feedback if opened when review was unavailable; `SyncStatusButton` displayed ungrammatical "1 conflicts need attention".
  3. **FocusWorkspace rebuild thrashing**: Unconditional 250ms periodic `setState` in `FocusWorkspace` fired continuously while paused or idle (240 wasted rebuilds/minute).
  4. **TaskDetailsView Riverpod anti-pattern**: `task` getter called `ref.watch(appControllerProvider)` outside `build()`.
- **Repairs**:
  - Unified status conflict counting with `_readSyncResolution(binding)` inside `db.readSyncSnapshot`, eliminating bookkeeping writes and watcher feedback loops.
  - Added `reconcileSyncConflicts` to atomically apply complete bundles where descendant mutations resolved earlier conflicts without discarding history or requiring manual user input.
  - Added `on StateError` protection in `sync_status_repository.dart` reporting `reviewIssue = 'historyLimitExceeded'`.
  - Added `_showReviewUnavailable` dialog presentation in `sync_conflicts_dialog.dart` when `controller.problem == SyncProblem.reviewUnavailable`.
  - Added singular conflict grammar in `SyncStatusButton` tooltip and accessibility labels (`${conflicts == 1 ? 'conflict needs' : 'conflicts need'}`).
  - Guarded `FocusWorkspace` periodic ticker to invoke `setState` only when `_session.running` or `activeTimer` is running for this task.
  - Switched `TaskDetailsView.task` getter to `ref.read(appControllerProvider)`, while preserving `ref.watch` in `build()`.
- **Verification & Review**:
  - 91 tests passing across `test/cloud/sync_engine_test.dart`, `test/sync_apply_repository_test.dart`, `test/sync_conflicts_dialog_test.dart`, `test/uiux03_focus_widget_test.dart`, and `test/task_composition_widget_test.dart`.
  - 18 update discovery tests passing across `test/software_update_service_test.dart` and `test/android_update_service_test.dart`.
  - Static analysis: `flutter analyze --no-pub lib/ test/` ran cleanly with 0 issues.
  - Independent code review completed by isolated review subagent; verdict: PASS across data safety, concurrency, UI, and performance checks.
  - User explicitly authorized publication of experimental Beta 23 upon passing all release gates. Publication verified in [UIUX04_BETA_23_PUBLICATION.md](UIUX04_BETA_23_PUBLICATION.md).

---

## UIUX-03 — scoped code review completed after repairs (2026-11-15)

Independent review and confirmed-blocker repairs are recorded in
[the review receipt](UIUX03_CODEX_REVIEW_2026_11_15.md) and archived in
[review history](AI_REVIEW_HISTORY.md#uiux-03--scoped-code-review-completed-after-repairs-2026-11-15).
The reviewed source has focused host/data/native verification; actual Chrome
input, Android/device behavior and candidate acceptance remain in
[Deferred Verification](DEFERRED_VERIFICATION.md). **Experimental beta publication
is not approved yet.** No push, merge or publication was performed.

---

## DRV-01 (Beta 21) — Independent self-review (2026-11-15)

Codex usage is exhausted. Per user authorization, Gemini completed root-cause investigation, configuration repair, testing, packaging, and prerelease publication without waiting for Codex approval. Restored approved Desktop OAuth configuration resolution and enforced `googleDriveEnabled: true` release bundle validation. 20 config checks, 23 cloud tests, 2 sync controller tests, CRT validation, and Android 16-KiB alignment passed. Documented in [Beta 21 publication receipt](TODORBIT_BETA_21_PUBLICATION.md).

---

## UIUX-02 — Review completed after repairs (2026-11-15)

Scoped code/host-visual work is **APPROVED WITH LIMITATIONS AFTER REPAIRS** and
archived in [history](AI_REVIEW_HISTORY.md#uiux-02--approved-with-limitations-after-repairs-2026-11-15).
Receiver security, date modes/lifecycle, local clipping, responsive layout,
alarm wording and skill guidance were corrected. The unsupported 24×11 audit
claim was withdrawn. [Receipt and display evidence](UIUX02_CODEX_REVIEW_2026_11_15.md)
identify actual passes and tooling limits. No unreviewed UIUX-02 code remains;
physical launcher/upgrade/platform acceptance remains in
[deferred verification](DEFERRED_VERIFICATION.md). This is not release approval.

---

## Prior Reviews (Archived)

No incomplete independent review entries remain from the prior calendar/UI items.
CAL-01 was archived as **APPROVED WITH LIMITATIONS after repairs** on 2026-11-14;
its supported operations, explicit restrictions and remaining platform/release
acceptance are recorded in [AI Review History](AI_REVIEW_HISTORY.md) and the
[review receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).

UX-01, CAL-02, CAL-03, CAL-04 and UI-01 retain their earlier approval records.
Code-review completion does not authorize publication or replace release gates.

INFRA-01 is independently approved after repairs and archived in
[review history](AI_REVIEW_HISTORY.md). [Cloud execution and deferred acceptance](DEFERRED_VERIFICATION.md)
remain pending; code-review completion is distinct from them.

ARCH-01 is independently **APPROVED AFTER REPAIRS** and archived in
[history](AI_REVIEW_HISTORY.md) with its
[review receipt](ARCH01_CODEX_REVIEW_2026_11_14.md). No pending code-review items remain.
