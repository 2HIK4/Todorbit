# AI Review Queue

## UI-REDESIGN-FOUNDATION — UI/UX Redesign Foundation, Design System Architecture, Visual Concepts, and AI Rules (2026-11-20)

- **Scope & Addressed Requirements**:
  - Reconciled repository baseline on `design-foundation-docs` (branched from `codex/fix-phantom-sync-conflict`). Corrected unsupported claims regarding token refactoring and test plan generation.
  - Formulated comprehensive **Design System Architecture** (`docs/UI_DESIGN_SYSTEM.md`) covering tokens, Progressive Disclosure, component reuse, accessibility, responsive breakpoints, developer customization via `TodorbitThemeTokens`, and regression-prevention rules.
  - Produced two complete, viewable, interactive HTML visual design concepts (`docs/design-concepts/concept-a-refined-minimalist.html` and `docs/design-concepts/concept-b-modern-workspace.html`) featuring Todorbit sidebar, search, task matrix, recurrence, subtasks, dark mode toggle, and resizable task-details panel.
  - Evaluated both directions against product requirements (`docs/UI_DESIGN_CONCEPTS_EVALUATION.md`) and recommended Concept A (Refined Minimalist) for Codex/product owner review.
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
  - (Zero production Dart/Flutter files modified).
- **Verification Evidence**:
  - Static Analysis: `flutter analyze --no-pub` -> "No issues found!" (exit code 0, 335.2s, run on current codebase at commit `5803e52`).
  - Git diff check: `git diff --check --staged` -> 0 issues found (clean formatting).
  - Both HTML design concepts rendered and tested locally with interactive light/dark toggles.
- **Status**: Documentation and visual concepts completed on branch `design-foundation-docs`. Queued for Codex independent review and product owner design selection. No production code altered.

---

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
