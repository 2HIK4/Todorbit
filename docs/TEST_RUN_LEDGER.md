# Persistent test run ledger

## Prompt 2 task timer/composition (2026-11-17 20:38 +03:00)

Base `5803e52`, branch `feature/todorbit-task-ux`; [final source/assertion/config manifest](PROMPT2_TASK_UX_2026_11_17_SOURCE.json).
[Receipt](PROMPT2_TASK_UX_2026_11_17.md) retains exact commands and failed/debug
iterations. Serial Windows host/Flutter 3.47.7/Dart 3.13.5; disposable data only.
Final focused batch PASS43; final dialog callback follow-up PASS2 (one repeated,
one added) =44 distinct focused checks. Lifecycle/accounting PASS3; filtered adjacent PASS3 (two sync timer
ownership checks and one mobile row). Full relevant analysis + follow-up PASS,
22 changed Dart format PASS, diff check PASS. New `task-timers` gate plan resolves.
Changed timer/Trash/UI behavior invalidated prior receipts; unchanged assertions
are reused after the narrowly verified dialog callback follow-up. Physical/live,
full integration and release acceptance are pending, not inferred from host passes.

## UI-REL-03 (Prompt 3 Authoritative) — Calendar responsiveness, event metadata (categories & projects), color picker scrolling, and month navigation prefetch (2026-11-17, UTC+03:00)

Exact branch `feature/todorbit-calendar-events`, worktree `life_manager_worktrees/feature-todorbit-calendar-events`:
- `test/prompt3_calendar_events_test.dart`: 9/9 PASS (19s). Covers:
  1. Month cells showing meaningful first items and clickable `+N` or `+N more` count affordance on narrow window widths (420px, 520px, 680px) without disappearing or overflowing.
  2. Calendar content filter (Both / Events only / Tasks only) discoverability on narrow desktop widths without layout overflow.
  3. Event category and project selector assignment, raw SQLite column persistence (`fixed_events.category_id`, `fixed_events.project_id`).
  4. In-editor dynamic creation of new categories and projects (`+ New Category`, `+ New Project`) with immediate assignment.
  5. Old events without category/project remain valid with null assignments and display 'None / Inbox' and 'None'.
  6. Custom event color picker preserving steady scroll offset during user drag, palette switching (`ChoiceChip`), and hex editing without snapping back.
  7. Color picker dialog (`ColorPickerDialog`) maintaining steady scroll offset under touch/mouse wheel drag and text editing.
  8. Month navigation prefetch window (adjacent 3-month span `<= 93` days) showing events immediately with zero blank flicker.
  9. Rapid back/forward month navigation clicks guarded against race conditions or stale months.
- `test/event_editor_layout_test.dart`: 3/3 PASS (6s) verifying AnchoredSelectField category/project selectors and form layout.
- `test/calendar_test.dart`: 3/3 PASS (13s) verifying calendar conflict indicators, content filters, and event/session creation.
- `test/stage2_ui_regression_test.dart`: 18/18 PASS (35s) verifying mobile agenda, all-day boundaries, color dialogs, and IME layout.
- `test/repository_test.dart`: 8/8 PASS (10s) Level 2 critical persistence verification (Schema 29, event and task lifecycle, v1 migration).
- Static Analysis: `flutter analyze --no-pub` -> 0 issues found (12.7s).
- Total checks: 41 focused tests executed, 41 passed (0 failures). No beta publication.
