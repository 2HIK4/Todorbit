# Progress

## Prompt 2 — task timers and composition (2026-11-17)

Implemented the current authoritative task scope on `feature/todorbit-task-ux`,
base `5803e52`. Direct/idempotent timer entry is shared across Windows/Android;
explicit atomic switching keeps actual work and separates task status/plans.
Compact controls, checklist group menus/removal protection, one-level subtask
explanation and guarded planned-session Trash actions are in place. 44 distinct
focused tests plus 6 adjacent/lifecycle checks pass; analysis/format/diff checks pass.
[Receipt and limitations](PROMPT2_TASK_UX_2026_11_17.md); source hashes are attached.
Live/device/packaging acceptance remains tracked separately. No schema/version,
Stable, publication, merge/rebase or remote changes. Implementation awaits
independent integration review; older Gemini queue entries remain unchanged.

## UI-REL-03 (Prompt 3 Authoritative) — Calendar responsive display, event metadata, color picker scrolling, and month navigation prefetch (2026-11-17)

Implemented Prompt 3 of the Todorbit UI and Reliability Improvement Program on isolated worktree `feature/todorbit-calendar-events`:
- **Calendar Responsive Display (Screenshot 6)**: Implemented adaptive capacity calculations for `CalendarMonthView` and `_monthGrid` based on clamped cell height (>=90px) and cell width. On narrow desktop window widths (380px–680px), scheduled items remain visible with at least 1 item or a non-overflowing, clickable `+N` count affordance (`InkWell` invoking `onDayTap(date)`). Filter states (Both, Events only, Tasks only) stay discoverable and non-overflowing. Memoized month and week item maps (`_cachedMonthKey`, `_cachedWeekKey`) in `_CalendarViewState` to eliminate expensive O(days × items) synchronous recalculations on window resize frames.
- **Event Metadata (Categories & Projects Assignment & Persistence)**: Replaced raw popup menus in `EventEditor` with `AnchoredSelectField<String?>` for Category (supporting `None / Inbox`, choices, and dynamic `+ New Category` creation dialog) and Project (supporting `None`, category-scoped projects, and dynamic `+ New Project` creation dialog). Replaced color picker with `AnchoredSelectField<int?>` with backward-compatible tooltips. Full SQLite persistence to `fixed_events.category_id` and `project_id` (Schema 29) while preserving valid null state for legacy unassigned events.
- **Color Picker Steady Scroll & Lifecycle**: Replaced unmanaged `AlertDialog(scrollable: true)` with dedicated `ScrollController` in State and `PageStorageKey` for `_EventColorDialog` and `ColorPickerDialog`. Removed thrashing `key: ValueKey(picker)` from `ColorPicker`. Tested mouse wheel, pointer drag, palette switching, and hex typing: scroll offset remains steady and never snaps back to 0.0 or prior positions; save and cancel behaviors cleanly preserved.
- **Month Navigation Flicker Elimination**: Expanded `AppController.ensureRecurringMonth(date)` prefetch window to 90 days (`[first - 30 days, first + 60 days]`), covering adjacent months `[month - 1, month, month + 1]` strictly within `LifeRepository.ensureRecurringTasks` invariant (`span <= 93` days). Preloads adjacent events and recurrence in-memory so navigating back/forward shows events instantly on frame 1 with zero blank flicker. Guarded rapid back/forward clicks with `_monthNavigationRevision` counter to eliminate race conditions. Added lightweight 2px `LinearProgressIndicator` when loading distant months.
- **Verification Evidence**: 41 focused tests passed with zero failures across `test/prompt3_calendar_events_test.dart` (9/9), `test/event_editor_layout_test.dart` (3/3), `test/calendar_test.dart` (3/3), `test/stage2_ui_regression_test.dart` (18/18), and Level 2 critical persistence `test/repository_test.dart` (8/8). Static analysis `flutter analyze --no-pub` clean (0 issues). Skills updated in `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`. Queued in `docs/AI_REVIEW_QUEUE.md` and recorded in `docs/TEST_RUN_LEDGER.md`. No beta published.
