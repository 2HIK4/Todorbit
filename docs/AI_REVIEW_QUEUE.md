# AI Review Queue

## Prompt 2 — Codex task timer/composition implementation (2026-11-17)

Awaiting independent integration review. Current assigned scope overrides the old
program allocation. Review atomic timer switching/idempotency, distinct task status,
countdown/break/recovery/remote behavior, shared Windows/Android entry/compact UI,
checklist confirmation/history, one-level child explanation and revision-guarded
planned-session Trash actions. [Receipt, changed files and evidence](PROMPT2_TASK_UX_2026_11_17.md)
with [final fingerprints](PROMPT2_TASK_UX_2026_11_17_SOURCE.json).
44 focused tests and 6 adjacent/lifecycle checks pass; analysis clean. Level 3/4 and live
runtime limitations remain in Deferred Verification. No self-approval, publication
or approval of unrelated Gemini changes is claimed.

## UI-REL-03 (Prompt 3 Authoritative) — Calendar responsive display, event metadata (categories & projects), color picker scrolling, and month navigation prefetch (2026-11-17)

- **Scope & Addressed Requirements**:
  - **Calendar Responsive Display (Screenshot 6)**:
    - Month cells in `CalendarMonthView` adaptively calculate row capacity based on clamped cell height (>=90px) and width.
    - Prevents scheduled items from disappearing on narrow Windows window widths (380px–680px) and varied text scales.
    - Displays at least the first item or a clearly clickable `+N` or `+N more` count affordance (`InkWell` calling `onDayTap`) without causing `RenderFlex` overflow.
    - Tooltip on each month item provides full title and parent hierarchy.
    - Added responsive display and memoized item calculations (`_cachedMonthKey`, `_cachedWeekKey`) in `CalendarView` to eliminate expensive O(days × items) synchronous recalculations on window resize frames.
    - Added lightweight 2px `LinearProgressIndicator` when navigating outside cached event windows.
  - **Event Metadata (Categories & Projects Assignment & Persistence)**:
    - Implemented full category and project assignment capabilities in `EventEditor` using `AnchoredSelectField<String?>`, matching task editor semantics.
    - Category dropdown supports `None / Inbox`, existing categories, and in-dialog creation via `+ New Category`.
    - Project dropdown supports `None`, category-filtered projects, and in-dialog creation via `+ New Project` (dynamically enabled when category is selected).
    - Replaced raw popup menu with `AnchoredSelectField<int?>` for custom and palette color selection while retaining backward-compatible tooltips.
    - Full database persistence: validates and writes `category_id` and `project_id` to `fixed_events` SQLite table (Schema 29).
    - Preserved full backward/forward compatibility: existing events with null category/project remain valid with null assignments.
  - **Color Picker Steady Scroll & Lifecycle**:
    - Replaced unmanaged `AlertDialog(scrollable: true)` in `_EventColorDialog` and `ColorPickerDialog` with explicit `ScrollController` management in `State`.
    - Bound `SingleChildScrollView` to dedicated `PageStorageKey` (`event_color_dialog_scroll` / `color_picker_dialog_scroll`).
    - Removed thrashing `key: ValueKey(picker)` from `ColorPicker` widget to avoid reconstructing child state.
    - Tested mouse wheel, pointer drag, palette chip switching, and hex typing: scroll offset remains steady and never snaps back to initial position; save and cancel behaviors cleanly preserved.
  - **Month Navigation Flicker Elimination & Recurrence Prefetching**:
    - Expanded `ensureRecurringMonth(date)` prefetch window in `AppController` to 90 days (`[first - 30 days, first + 60 days]`, covering adjacent months `[month - 1, month, month + 1]`), strictly within the `LifeRepository.ensureRecurringTasks` invariant (`span <= 93` days).
    - Adjacent month events and recurring occurrences are preloaded into memory, rendering instantly on frame 1 with zero blank flicker during back/forward navigation.
    - Added `_monthNavigationRevision` counter to eliminate race conditions from rapid back/forward clicks, ensuring out-of-order async completions do not overwrite current view state or show mislabelled prior months.
- **Source Paths Modified**:
  - `lib/app/app_controller.dart`
  - `lib/features/calendar/calendar_month_view.dart`
  - `lib/features/calendar/calendar_view.dart`
  - `lib/features/calendar/event_editor.dart`
  - `lib/features/shared/color_picker_dialog.dart`
  - `lib/features/shared/event_color_picker.dart`
  - `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`
  - `test/event_editor_layout_test.dart`
  - `test/prompt3_calendar_events_test.dart` (new comprehensive suite)
- **Verification Evidence**:
  - `test/prompt3_calendar_events_test.dart`: 9/9 passed (19s).
  - `test/event_editor_layout_test.dart`: 3/3 passed (6s).
  - `test/calendar_test.dart`: 3/3 passed (13s).
  - `test/stage2_ui_regression_test.dart`: 18/18 passed (35s).
  - `test/repository_test.dart`: 8/8 passed (10s) Level 2 critical persistence verification.
  - `flutter analyze --no-pub`: 0 issues found (12.7s).
  - Total Level 1/2 tests executed: 41/41 passed with zero failures.
- **Status**: Unreviewed implementation queued for Codex independent review. No beta release or deployment performed.

---
