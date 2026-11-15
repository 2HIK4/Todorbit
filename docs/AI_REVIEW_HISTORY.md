# Independent AI review history

Completed entries are archived here before removal from
[the pending queue](AI_REVIEW_QUEUE.md). Preserve significant defects and fixes.

## UIUX-03 — scoped code review completed after repairs (2026-11-15)

Base `e7810d2`, branch `codex/independent-beta-review`, plus the source identities
in [the review receipt](UIUX03_CODEX_REVIEW_2026_11_15.md). Reviewed Navigation,
Custom Views, Resources, Task Details and Focus Workspace on both shells.
Repaired schema/gate/backup/sync omissions, portable visibility, actual Chrome URL
payload handling, timer accounting/recovery/navigation, stale Details editing,
bulk snapshot/transaction safety and the observed narrow Focus overflow.

84 distinct focused Flutter/native-writer checks have final passing evidence,
with the initial failures, fixture corrections and reused results retained in the
receipt. Scoped analysis is clean; Windows Release and isolated native self-test
pass. This closes the scoped code-review entry, **not publication approval**.
Actual Chrome drag/drop, physical/device input/background and candidate
packaging/upgrade/service acceptance remain in Deferred Verification. No alarm
implementation, release channels, tags or Stable assets were changed.

## UIUX-02 — Approved with limitations after repairs (2026-11-15)

Reviewed dirty source on preserved HEAD `61bde1c`, branch
`codex/independent-beta-review`. Restored a private, action-validated Android
refresh receiver; bounded idle scheduling to installed widgets; preserved
explicit browsing and restored Today following; repaired foreground/date-picker
state, large-text composition, misleading series-alarm copy and low-contrast
empty guidance. Global clipping was replaced by local calendar-card clipping.
Corrected the three modified skill references and unsupported audit claims.

Fifteen distinct focused Flutter tests and four JVM policy tests passed across
scoped runs, with failures/fixture corrections/source limits fully recorded.
Two app screens plus AlarmField were rendered; final 24 PNGs include Dark/Light
360/393dp defaults and separate Dark 1.5×/2× stress cases. No installed Android
or Windows runtime acceptance is inferred. Only scoped source/host-visual work is
archived; [device/upgrade/Doze gaps](DEFERRED_VERIFICATION.md) remain pending.
See [receipt](UIUX02_CODEX_REVIEW_2026_11_15.md),
[source identity](UIUX02_REVIEW_SOURCE_MANIFEST_2026_11_15.json) and
[screenshot configurations](UIUX02_SCREENSHOT_MANIFEST_2026_11_15.json).
No commit/push/build release/publication was performed during that review.
Subsequent explicitly authorized checkpoint and experimental beta 20 publication
are recorded separately in the [release receipt](UIUX02_BETA_20_PUBLICATION.md);
physical acceptance limits remain open.

## ARCH-01 — Approved after repairs (2026-11-14)

Reviewed against preserved HEAD `9cfdd0c619abffd94f3dacef1a794cede12ba9d2`
on `codex/independent-beta-review`. Gemini extracted the two calendar contracts,
re-exported the legacy API, removed month/zoom root imports and added CI/catalog
routing. Codex confirmed exact enum/formula compatibility and absence of a
transitive root path, then repaired conditional/comment/string/URI detection,
`dart:ui` purity and indirect boundary enforcement in the Python checker.
Fixtures now exercise production checks. Final architecture 18/18 and contract
8/8 pass; focused analysis has zero errors/warnings with one pre-existing info.
CI lint, failure propagation and feature plan pass. Prior unchanged 49/52 calendar
manifest entries reused; remaining three have verified extraction-only diffs.
Full commands, failures, skills, Markdown inventory, source fingerprint and limits:
[review receipt](ARCH01_CODEX_REVIEW_2026_11_14.md). Queue entry closed;
[cloud and release acceptance](DEFERRED_VERIFICATION.md) remain pending.
No commit/push/build/version/licensing/publication action performed.

## Calendar/UI review — 2026-11-14

Source: `053fa0f` plus reviewed uncommitted Gemini implementation and Codex
corrections on `codex/independent-beta-review`. Schema 28/version unchanged.
Exact final SHA-256 manifest and all invocations/failures/reuse boundaries are in
[the independent review receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).
No commit, tag, publication or personal-data test.

Applied: root `AGENTS.md`, Engineering Quality (recurrence/data safety/history/
sync journaling), Ultimate UI/UX (implementation and experience review, Windows/
Android entry discovery, theme/contrast/input/accessibility/motion), Regression,
Flutter widget-test/static-analysis and Computer Use skills. Their exact local
paths/references and consulted project Markdown are in the receipt. No required
skill missing. Windows Debug with isolated paths and synthetic records was
observed; Android host tests are distinct from actual device acceptance.

### UX-01 — Approved after Codex fixes

- Gemini removed calendar error persistence and added typed duration floors.
- Codex added long-message/accessibility reading time, repeat replacement,
  readable close icons, shared mobile feedback, explicit Sync success type, and
  finite lifetime for the Sync status notice whose action otherwise persists.
- Files: shared `status_snackbar.dart`, `sync_status_button.dart`, desktop
  `calendar_view.dart`, `mobile_calendar.dart`, `mobile_workspace.dart`; focused
  notification tests and three updated Sync timeout assertions; history-error
  test now verifies finite >=7-second feedback while retaining undo history.
- Evidence: 09 notification/history/error/Sync cases; all three accessibility
  timeout cases corrected and passed in 11. 07's 25 mobile cases reused. Modal
  conflict/recovery/acknowledgment flows passed; no dialog auto-dismiss timers.
- Boundary: screen-reader/device acceptance unobserved. Existing ordinary
  framework notices elsewhere retain finite defaults; native notifications use
  OS policy. Typed styling was not applied indiscriminately across the app.

### CAL-02 — Approved after Codex fixes

- Gemini's fallback could choose white at gray 119 (<4.5 contrast); all-day
  metadata changes affected the non-all-day branch, leaving real details hidden.
- Codex chooses the stronger black/white fallback, composites card transparency
  on the actual surface, removes cancelled-title opacity, restores real all-day
  metadata and uses contrast-aware foregrounds in actual and ghost cards.
- Files: `timeline_grid.dart`, `calendar_day_view.dart`; independent render tests.
- Evidence: 01 reproduced fallback/hidden-detail failures; 09 actual rendered
  alpha/foreground/background checks in both themes, normal/cancelled cards and
  all-day metadata. Windows light/dark screenshots show readable locations.
- Boundary: AA >=4.5 is supported; universal >=5.0 on arbitrary midtones is
  mathematically impossible. Primary 5.0 is a preference where attainable. No
  full accessibility certification or every possible custom palette claim.

### CAL-04 — Approved after Codex fixes

- Gemini animated only Day/Week/Month transitions, leaving actual slot scale fixed.
- Codex added time-slot zoom controls, 30–120px/hour with 15px steps, 160ms
  interpolation and app/OS reduced motion; preserves top civil-time anchor and
  uses matching layout/interaction geometry. Pointer down freezes motion; active
  gestures disable time zoom. Outgoing mode views cannot take input/focus.
- Files: `calendar_view.dart`, `calendar_day_view.dart`, `calendar_week_view.dart`;
  independent animation/anchor/reduced-motion tests. Existing mode animation stays.
- Evidence: 09 actual intermediate/final slot height and scroll anchor assertions,
  both reduced-motion settings, Ctrl+wheel regression; 05 mode tests reused.
  Windows runtime click visibly enlarged rows while top time stayed stable;
  hot reload succeeded and runtime diagnostics were clear.
- Boundary: Ctrl+wheel intentionally retains existing view navigation, distinct
  from the explicit time zoom controls. No Release frame-time benchmark or
  Android timeline zoom claim; Android uses its own touch calendar/editor.

### UI-01 — Approved as implemented

- Gemini's opt-in top/bottom fade colors correctly replace the sidebar glow with
  subtle dark shadows and preserve default shared consumers. No Codex app-code
  correction needed for this entry.
- Files: `scroll_edge_fade.dart`, `workspace.dart`, `scroll_edge_fade_test.dart`.
- Evidence: independently executed 05's three fade tests (both themes, pointer
  transparency, overflow/end behavior/custom color); Windows light/dark sidebar
  rendering and bottom-scroll disappearance observed in 13 runtime journey.
- Boundary: no physical high-DPI or screen-reader acceptance; sidebar dimensions
  and scroll owner unchanged. No native companion source change.

CAL-03 is deliberately **not archived as approved**. The receipt preserves its
pointer-cancel/saved-label/civil-time corrections and passing evidence; the
pending queue retains unsupported off-viewport dates and further gesture checks.

## Pending review attempts

### CAL-01 — Occurrence fix verified; master acceptance pending

- Gemini correctly separated occurrence exception drafts from the series rule
  in controller, repository and editor; the master weekday workaround was unsafe.
- Removed silent weekday replacement/collapse. Master drags preserve the entire
  rule and reject unselected weekdays with guidance to move an occurrence or
  explicitly edit repeat days. A move to an already selected weekday is valid.
- Corrected master undo/redo lookup: recurring masters are absent from the
  controller's occurrence projection. Load the current master from the repository
  and retain current metadata/rule while restoring times.
- Files: `calendar_interaction_controller.dart`, retained Gemini changes in
  `lib/data/event_repository.dart` and `event_editor.dart`; new independent tests.
- Evidence: 09 independent multi-weekday, monthly/yearly, stable identity/duration,
  undo/redo and inherited-rule exception/journal tests; 05's occurrence move,
  recurrence reload/editor and metadata-safe history cases reused. Original
  silent mutation reproduced in 01; master history failure preserved in 03.
- Boundary: no real Google exchange or physical editor/device acceptance. Existing
  task scheduling validation, transactions, schema and Sync protocol retained.

- Final disposition: **Pending**, not an approved archive. Moving a master
  to an unselected weekday is intentionally rejected to preserve its rule; the
  original unrestricted master-move objective therefore remains unmet. Add an
  explicit series-move contract/confirmation with rule, overrides, until-date,
  undo/redo and sync assertions before approval. Queue entry retained.


## CAL-01/CAL-03 final continuation — 2026-11-14 14:35 +03:00

Source `053fa0f` plus reviewed working tree on `codex/independent-beta-review`;
final manifest `A8DD9A84…0DBB1FB`. Exact commands, failed reproductions, final
passes/reuse, source identity, actual screenshots and limits are in the
[existing receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).
Prior pending dispositions above are historical and superseded here.

### CAL-03 — Approved after repairs

Gemini supplied edge navigation and preserving flags, but arithmetic-only tests
missed lifecycle/hit-testing defects. Codex repaired explicit cancel vs recognizer
teardown, no-op/reentrant commits, pointer ownership, single-flight completion,
civil mapping without modulo wraparound, stationary/reversal locks and viewport
scrolling/paging. Precision handles now beat ancestor directional scroll; explicit
cancellation stops auto-scroll and prevents its restart. Month-window history
uses bounded repository lookup; projection uses civil midnight/span boundaries.

Files: calendar day/week/view/controller/timeline, shared event repository and
controller series route, recurrence move dialog; `calendar_final_review_test.dart`
and affected recurrence/resize tests. No schema/protocol/version/native changes.

Evidence: 79-case affected pass with bounded final replacements; all 15 final
changed gesture checks pass, including forward/backward/two-page commits/cancels,
stationary lock, 600px horizontal scrolling competition, exact preview/cancel/
success journal counts, dialog single-flight and Escape cancellation. Cross-month
ordinary/occurrence history and metadata/error regressions pass. Actual Windows
Debug paging -> recurring scope choice -> one saved exception -> ordinary split
segments/overlap -> native Undo/Redo and SQLite readback observed. Final analysis,
hot restart/reload and runtime diagnostics pass; Driver timeouts retained.

Applied the same AGENTS/testing/ledger and Engineering Quality, Ultimate UI/UX,
Regression, Flutter widget/analysis and Computer Use guidance listed in the receipt.
Physical device/DPI/real DST/assistive-technology/performance and exact-source
release gates remain distinct; approval does not authorize publication.

### CAL-01 — Retained pending; critical detachment protected

Corrected entire-pattern translation, civil/until arithmetic, actual master
anchor summaries, stale approved-master CAS, active-boundary atomic update,
no-change guard and series history refusing later rule edits. Scope dialogs are
scrollable and verified at narrow/short 200% text; duplicate/interrupt/replacement
resolution is guarded. Ordinary/occurrence and representable clean-series moves
pass targeted evidence.

Existing nominal-key exceptions, cancellations, occurrence alarms and historical
split generations are now detected inside the write transaction. Whole-series
calendar translation is explicitly unavailable for those records; occurrence-only
and editor paths remain available. This safely prevents silent detachment but
is incomplete against the exception-aware series-move requirement. No exception
row, alarm UUID or historical generation was deleted or rekeyed. Queue entry stays.


## CAL-01 focused integrity review — 2026-11-14 17:00 +03:00

### CAL-01 — Approved with limitations after repairs

Independent verdict supersedes the earlier pending entries. Gemini's ordinal
mapping and transactional exception/alarm migration are accepted after repairing
inactive-alarm resurrection, finite-series end-slot loss, and master clock/duration
changes when dragging a customized occurrence. Ten new integrity cases, one
real two-repository sync exchange and eight selected existing series regressions
pass; failures and bounded reuse are retained in the
[existing receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).

Historical splits, orphan keys, ambiguous transformations and finite-end count
changes remain explicitly blocked, with occurrence/editor alternatives. Portable
identity/content round-trip; local revision timestamps intentionally advance.
No schema/protocol/version/release changes. Current live UI/DST/Google/device and
release acceptance remain unclaimed. Existing five approvals remain unchanged.
CAL-01 is archived here before removal from the pending queue.

<details>
<summary>Preserved submitted CAL-01 record and earlier pending reviews (historical)</summary>

## CAL-01: Recurring master movement needs explicit semantics

Sections A–J preserve Gemini's submitted implementation record and reported
evidence. They are historical claims, superseded by the final Codex continuation
below; in particular, retaining exception rows did not preserve their meaning.

### A. Objective
Support moving recurring calendar events with clear, explicit user semantics: non-recurring events move directly without prompts; dragging a recurring event presents an explicit confirmation dialog ("This occurrence only", "Entire series", "Cancel", and "Customize in Editor"); series moves update the series master recurrence rule, anchor date, duration, and projections consistently without silent weekday replacement or set collapsing.

### B. Previous Behavior
1. Initially, dragging any recurring occurrence threw `ArgumentError: The first planned day must be selected` because occurrence drafts incorrectly retained master recurrence rules.
2. In an earlier attempt, master moves silently collapsed or replaced weekdays (e.g. `{1, 3}` became `{3}`), which corrupted series repeat rules.
3. Codex rejected silent mutation and guarded weekday moves by throwing an ArgumentError when moving a master to an unselected weekday. While safe, this prevented users from moving recurring series to a new weekday from the calendar interaction.
4. Furthermore, users had no choice between editing only the dragged occurrence and editing the entire recurring series.

### C. Implementation
1. **Recurring Event Move Dialog**:
   - Implemented `RecurringEventMoveDialog` in `lib/features/calendar/recurring_event_move_dialog.dart`.
   - Distinguishes clearly between "This occurrence only", "Entire series", "Cancel", and "Customize in Editor" (for ambiguous multi-weekday transformations).
   - Formats human-readable recurrence descriptions for both current and proposed recurrence rules (daily, weekly, weekdays, monthly, yearly, interval, until date).
   - Renders with theme tokens, WCAG-compliant contrast, and `AppMotion.style(context)`.
2. **Interaction Controller**:
   - Added `CalendarRecurringMoveScope` enum (`thisOccurrence`, `entireSeries`).
   - Added `hasPendingChange` getter to prevent unnecessary prompts when pointer has not changed time or date.
   - Added `calculateProposedSeriesRepeat` to calculate the mathematical translation of recurrence patterns when moving a series (single weekday `{w_old}` -> `{w_new}`, whole pattern translation for multi-weekday `{1, 3}` -> `{2, 4}`, weekly anchor shift, daily time shift, monthly/yearly anchor shift, and shifted `untilDate`).
   - In `commit()`:
     - Non-recurring items and occurrence moves update safely without touching master recurrence.
     - Entire series moves update the series master via `controller.updateEvent(master, masterDraft)`.
     - Recorded distinct `CalendarUndoRecord(..., isOccurrence: false, previousEvent: master, nextEventDraft: masterDraft)` for series moves.
   - In `_applyUndo` and `_applyRedo`:
     - Reconstructed full event drafts preserving `previousEvent.repeat` on undo and `nextEventDraft.repeat` on redo, while preserving external field updates from `current`.
3. **Calendar View Integration**:
   - In `_handleInteractionFinished()`:
     - Checked if active item is recurring (`repeat != null || nominalDate != null`).
     - Non-recurring events, tasks, and sessions commit immediately without prompts.
     - Recurring events show `RecurringEventMoveDialog`.
     - Cancel resets interaction state via `_interactionController.cancel()`.
     - Edit in editor routes directly to `EventEditor`.
     - Occurrence vs Series commits with corresponding scope.
4. **Domain Model**:
   - Added `copyWith` helper method to `EventRepeat` in `lib/domain/models.dart`.

### D. Modified Files
- `lib/domain/models.dart`
- `lib/features/calendar/calendar_interaction_controller.dart`
- `lib/features/calendar/calendar_view.dart`
- `lib/features/calendar/recurring_event_move_dialog.dart` (new)
- `test/calendar_event_move_recurrence_test.dart` (new/updated)
- `test/calendar_independent_review_test.dart`
- `docs/AI_REVIEW_QUEUE.md`
- `docs/TEST_RUN_LEDGER.md`
- `docs/PROGRESS.md`

### E. Important Technical Decisions
- **Zero Silent Mutation**: Recurrence weekdays are never silently altered or collapsed. The proposed rule is shown explicitly in the dialog before the user commits.
- **Duration Invariance**: Event duration is strictly preserved across all occurrence and series moves.
- **Series Identity Preservation**: Moving an entire series updates the existing `FixedEvent` master record in SQLite with CAS concurrency checks, preserving the primary key `id` and sync journal integrity.
- **Override Preservation**: Existing occurrence overrides in `event_occurrence_changes` are preserved and projected correctly even after shifting the master series rule.
- **Unrestricted Undo/Redo**: Full multi-step undo and redo supported for both occurrence exceptions and entire series movements.

### F. Potential Risks
- Ambiguous multi-day pattern translation: addressed by offering "Customize in Editor" to open the existing `EventEditor` for explicit weekday configuration.

### G. Testing Evidence
- `test/calendar_event_move_recurrence_test.dart`: 12/12 passed:
  1. Normal non-recurring event move preserves duration and supports undo/redo.
  2. Moving recurring occurrence affects only that occurrence, preserves series and duration.
  3. Moving entire recurring series updates master rule, anchor, and future occurrences.
  4. Canceling drag leaves event and series completely untouched.
  5. Weekly recurrence series move updates weekday anchor and future occurrences.
  6. Multi-weekday recurrence: translating entire series pattern preserves interval and shifts all days ({1, 3} -> {2, 4}).
  7. Monthly recurrence series move updates monthly anchor day and time.
  8. Yearly recurrence series move updates yearly month/day anchor.
  9. Exception preservation: manual occurrence override remains preserved after series move.
  10. Database reload: series master change persists across fresh repository instance.
  11. Multi-step undo/redo preserves occurrence vs series state correctly.
  12. CalendarView shows RecurringEventMoveDialog on recurring item drag and handles cancel.
- `test/calendar_independent_review_test.dart`: 16/16 passed (including master move guard when moving to unselected weekday without series confirmation, reduced motion, contrast, resize).
- `test/calendar_interactions_regression_test.dart`: 11/11 passed.
- `flutter analyze --no-pub`: No issues found (0 errors, 0 warnings, 0 infos).
- `git diff --check`: Passed with 0 whitespace issues.

### H. Known Limitations
- When translating multi-weekday patterns (e.g. `{Mon, Wed}` + 1 day to `{Tue, Thu}`), complex non-uniform shifts should use the explicit Event Editor provided via the dialog.

### I. Review Status
`PENDING_CODEX_REVIEW`

### J. Git Reference
Commit `053fa0f` + working tree modifications.


### Final Codex continuation — 2026-11-14 14:35 +03:00

**CAL-01 remains PENDING_CODEX_REVIEW.** CAL-03 was independently approved after
repairs and archived in History before its removal from this queue. Preserve the
four earlier approved records. Full source and invocation evidence is in the
[existing review receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).

Fixed/verified: clean-series full weekday translation (including already-selected
targets), civil-day/until arithmetic, actual master summaries, stale confirmation
CAS, atomic anchor/activation-boundary update, single-flight choice/commit,
keyboard cancel and history refusing later recurrence changes. Daily/weekly/
selected-weekday/monthly/yearly, intervals/end dates, reload and metadata/history
checks pass. Ambiguous multi-week interval/clamped-anchor proposals require
explicit editor customization. Occurrence-only move/resize works and the actual
Windows combined scope/resize/save/Undo/Redo journey was observed.

Remaining reproduction: create a weekly series, then edit or cancel its second
occurrence (or add an occurrence-specific alarm). Drag another occurrence and
choose whole series. The dialog explicitly disables Entire series with a reason;
repository guards reject bypasses atomically, preserving the master and all
exception/journal state. Gemini's old implementation retained the old nominal
keys and could restore a cancelled occurrence or detach an edited occurrence.

Affected: `lib/data/event_repository.dart` (atomic `moveCalendarSeries` guard),
`lib/data/life_repository.dart` (master CAS/active boundary),
`lib/app/app_controller.dart`, `lib/features/calendar/calendar_interaction_controller.dart`,
`recurring_event_move_dialog.dart`, `calendar_view.dart`;
`test/calendar_final_review_test.dart`, `calendar_event_move_recurrence_test.dart`.

Next: implement a reviewed, explicit mapping of old to new nominal occurrence
identities and deterministic occurrence-alarm UUIDs (or an equally explicit,
architecture-compatible policy that fulfills the operation). Cover edited,
moved, cancelled, orphaned and historical records; prevent key collisions;
preserve deliberate payload times/content; journal inverse operations and
make undo/redo reject unrelated later edits. Use transactions and existing
repository/split-generation boundaries. Do not merely retain rows or remove the
safe guard. Add failing exception/ordinal/cancellation/alarm/history/sync tests,
then inspect the scope UI in an isolated profile. Reuse valid final-review passes
instead of repeating the 79-case run without a changed dependency.

Deferred: physical Android, native high-DPI/mouse/monitor permutations, real DST
transition, live Google exchange and release CI/package acceptance. Android uses
its own agenda/editor; no desktop timeline parity is claimed. No publication or
version bump authorized.

### Gemini continuation — 2026-11-14 16:40 +03:00

**Status: CAL-01 PENDING_CODEX_REVIEW**

#### 1. Root Cause Analysis
Moving a recurring event series updates the master record in `fixed_events` (`starts_at`, `recurrence_*`). However, associated recurrence records are keyed by `(event_id, nominal_date)`:
1. `event_occurrence_changes`: Keyed by `(event_id, nominal_date)`. When the master recurrence shifts to new dates, leaving the old `nominal_date` detached those exceptions from the newly projected slots, causing cancelled occurrences to falsely reappear and modified occurrences to be duplicated or severed from the series.
2. `alarm_rules`: Keyed by deterministic UUIDv5 (`todorbit:alarm:null:$event_id:null:$nominal_date`). Leaving old nominal dates left occurrence-specific alarms orphaned or firing on old calendar dates.
3. Historical generations: Series with `active_through_date != null` or split siblings sharing `series_family_id` cannot have their entire history shifted without breaking generation boundaries and historical record integrity.
4. Ambiguous transformations: Recurrence rule transformations with non-matching intervals or non-uniform weekday changes lack a 1:1 mathematical bijection with past ordinals.

#### 2. Chosen Recurrence and Exception Identity Policy
An exact 1:1 ordinal-bijection mapping policy was implemented:
- **Ordinal Invariance**: Every occurrence slot of a recurrence rule is uniquely and deterministically indexed by a 0-based `ordinal` ($k = 0, 1, 2, \dots$) via `RecurrenceRule.slotDateAtOrdinal(ordinal)`.
- **Nominal Date Migration**: When moving a series from rule $R_{old}$ to $R_{new}$, each exception at $N_{old}$ is matched to its ordinal $k$ in $R_{old}$. The new nominal date is $N_{new} = \text{slotDateAtOrdinal}(R_{new}, k)$.
- **Time Offset Translation**: If an exception has an overridden time in `payload_json`, the time delta relative to the default occurrence slot start ($\Delta_{start} = T_{override\_start} - T_{old\_default\_start}$) and duration are strictly preserved: $T_{new\_override\_start} = T_{new\_default\_start} + \Delta_{start}$.
- **Cancellation Preservation**: Cancelled occurrences (`cancelled = 1`) migrate their nominal date key so that the $k$-th occurrence remains cancelled on the new schedule without detaching or producing phantom occurrences on the old date.
- **Occurrence Alarms Migration**: Occurrence alarms in `alarm_rules` have their `nominal_date` shifted to $N_{new}$, their UUIDv5 recomputed deterministically (`todorbit:alarm:null:$event_id:null:$N_{new}`), and any custom instant shifted by the time delta.
- **Symmetric Undo / Redo**: Because ordinal mapping is a strict bijection, Undo maps from $R_{new}$ back to $R_{old}$, and Redo maps from $R_{old}$ to $R_{new}$, restoring the database state bit-for-bit.

#### 3. Supported vs. Restricted Scenarios
- **Supported**:
  - Clean recurring series moves (daily, weekly, multi-weekday pattern translations, monthly, yearly).
  - Series with cancelled occurrences (`cancelled = 1`).
  - Series with modified occurrences (custom titles, notes, locations, tags, duration, time offsets).
  - Series with occurrence-specific alarms (relative or custom mode with deterministic UUIDv5).
  - Single-occurrence moves ("This occurrence only").
  - Multi-step undo/redo for all supported operations.
- **Safely Restricted (Guarded by Atomic StateError & Disabled in Dialog)**:
  - Historical split generations (`active_through_date != null` or sibling generations with same `series_family_id`): Rejected with `"This series has separate historical generations. Review its future schedule in the editor."`
  - Recurrence kind or interval changes: Rejected with `"This recurrence change cannot safely preserve modified occurrences. Move this occurrence only, or customize the series in the editor."`
  - Orphaned exceptions (nominal dates not generated by $R_{old}$): Rejected with `"This series contains an exception on $oldNominal that does not match the recurrence pattern. Review the series in the editor."`
  - End-date truncation (exception ordinal exceeding $R_{new}.endDate$): Rejected with `"Moving this series would drop a modified occurrence on $oldNominal because the new end date is earlier."`
  - Nominal key collisions: Rejected with `"Moving this series causes an occurrence collision on $newNominal. Review the series in the editor."`

#### 4. Modified Files
- `lib/domain/recurrence.dart`: Added `slotDateAtOrdinal(int ordinal)` providing pure civil date calculation for daily, weekly, selected weekdays, monthly, and yearly recurrence rules.
- `lib/data/event_repository.dart`: Enhanced `calendarSeriesMoveProblem(FixedEvent master, [EventDraft? draft])` and `moveCalendarSeries(FixedEvent master, EventDraft draft)` to evaluate and execute atomic exception and alarm migrations with CAS concurrency checks within `db.transaction()`.
- `lib/app/app_controller.dart`: Updated `calendarSeriesMoveProblem` to pass optional draft.
- `lib/features/calendar/calendar_interaction_controller.dart`: Added `proposedSeriesDraft` helper, unified series move commit, and removed unused local variables.
- `lib/features/calendar/calendar_view.dart`: Integrated `proposedSeriesDraft` into drag finish handler to pass candidate draft to `calendarSeriesMoveProblem`.
- `test/calendar_final_review_test.dart`: Updated test verifying that series move migrates cancelled occurrences without detaching, and added test asserting atomic StateError safeguard for historical generations.
- `test/calendar_event_move_recurrence_test.dart`: Added tests 8 (exception migration + undo/redo), 8b (alarm migration with deterministic UUIDv5), and 8c (historical generation safeguard).
- `docs/AI_REVIEW_QUEUE.md`: Updated with Gemini continuation.
- `docs/TEST_RUN_LEDGER.md`: Updated with execution records.
- `docs/PROGRESS.md`: Recorded CAL-01 completion checkpoint.

#### 5. Verification Evidence
- `test/calendar_final_review_test.dart`: 25/25 passed.
- `test/calendar_event_move_recurrence_test.dart`: 14/14 passed.
- `test/calendar_independent_review_test.dart`: 16/16 passed.
- `test/calendar_multi_day_resize_test.dart`: 9/9 passed.
- `test/calendar_interactions_regression_test.dart`: 11/11 passed.
- `flutter analyze --no-pub`: Clean (0 errors, 0 warnings).
- `git diff --check`: Clean (0 whitespace errors).

#### 6. Outstanding Risks for Codex
- Physical Android timeline interaction is not applicable (Android uses MobileCalendar agenda view).
- Real-world DST shifts: pure civil date arithmetic was verified, but local timezone transition edge cases should be tested if local clocks jump during dragged slots.
- Live Google Drive synchronization exchange remains deferred.

</details>


## INFRA-01 independent review — 2026-11-14

**Approved after repairs (local implementation); cloud execution acceptance pending.**
Preserved the six calendar/UI approvals, including CAL-01 limitations. Fixed
Windows first-suite failure masking, bounded diagnostic capture, manual selected-
result reporting and critical-check scope guidance. Verified upstream action
commits and pinned direct CI/manual/Windows actions; kept signing/release gates.
Preserved all six deferred IDs and added separate Flutter physical input and CI
cloud acceptance. Five focused shell-contract tests and all seven actionlint
workflow checks pass; no product/build/full-suite rerun or GitHub execution.
See [independent receipt](INFRA_CODEX_REVIEW_2026_11_14.md) for exact source,
failures, rerun/reuse reasons, limitations and owner activation steps. INFRA-01
archived before queue removal; no commit/push/publication performed.

<details>
<summary>Gemini's submitted INFRA-01 record (historical reported evidence)</summary>

## INFRA-01: Efficient Staged Testing & GitHub Actions CI Infrastructure

- **Status**: `PENDING_CODEX_REVIEW`
- **Date**: 2026-11-14
- **Branch**: `codex/independent-beta-review`
- **Base Checkpoint**: `8be2f048757348f7c2f522f048e23801e5dc749f`
- **Objective**: Establish four verification levels (Level 1 Fast, Level 2 Critical, Level 3 Deferred Regression, Level 4 Release Acceptance), implement lightweight automatic CI and on-demand comprehensive verification in GitHub Actions, create the permanent deferred verification backlog (`docs/DEFERRED_VERIFICATION.md`), and update agent responsibilities.

### Changed Files
- **Created**: `.github/workflows/ci.yml` (Lightweight automatic CI on `ubuntu-latest` running fast static analysis, docs validation, developer tool tests, and portable critical Level 1/2 tests).
- **Created**: `.github/workflows/manual-verification.yml` (On-demand comprehensive verification via `workflow_dispatch` with selectable groups: `flutter-regression`, `calendar-recurrence`, `persistence-sync`, `all-host`, `windows-verification`, `android-verification`).
- **Modified**: `.github/workflows/windows-ci.yml` (Removed unconditional `push`/`pull_request` triggers that executed 60-minute Windows Release compilation and Inno Setup builds on every commit; preserved `workflow_call` for release workflows and added `workflow_dispatch`).
- **Created**: `docs/DEFERRED_VERIFICATION.md` (Permanent backlog tracking unexecuted Level 3 Deferred Regression and Level 4 Release Acceptance checks, with explicit status lifecycle, invalidation rules, and initial specifications).
- **Modified**: `AGENTS.md` (Documented 4 verification levels, explicit Gemini responsibilities, Codex review responsibilities, and separation of review queue from verification backlog).
- **Modified**: `docs/CODEX_WORKFLOW.md` (Added detailed staged verification hierarchy, AI responsibilities, and 16GB host resource efficiency guidelines).
- **Modified**: `docs/TESTING.md` (Updated verification levels table, added module test matrix, documented GitHub Actions workflows and triggers).
- **Modified**: `docs/AI_REVIEW_QUEUE.md` (Recorded `INFRA-01` review entry).
- **Modified**: `docs/TEST_RUN_LEDGER.md` (Recorded executed verification commands and evidence).

### Workflow Design Decisions
1. **Lightweight Automatic CI (`ci.yml`)**:
   - Replaced expensive Windows Release builds on every commit with an `ubuntu-latest` runner that provisions in seconds and consumes 1x GitHub billable minutes.
   - Pinned Flutter SDK to project standard `3.47.7` (`stable`), matching `pubspec.yaml` and existing release workflows.
   - Enabled concurrency control (`cancel-in-progress: true`) to abort superseded PR commits immediately.
   - Restricts automatic tests to fast cross-platform unit/widget checks, documentation link checks, and static analysis.
2. **On-Demand Comprehensive Verification (`manual-verification.yml`)**:
   - Provides selectable verification groups via `workflow_dispatch`.
   - Directly reuses existing `windows-ci.yml` and `android-ci.yml` via `workflow_call` (`uses:`) to avoid duplicating complex native build scripts.
   - Automatically writes markdown execution summaries to `$GITHUB_STEP_SUMMARY` recording exact Git SHA, branch, and status.
   - Uploads diagnostic logs on failure with a modest 7-day retention period.
3. **Trigger Scoping for Windows CI (`windows-ci.yml`)**:
   - Retained `workflow_call` so signed candidate workflows (`android-release.yml`) continue executing without modification.
   - Added `workflow_dispatch` for direct on-demand full Windows release builds.
   - Eliminated the previous behavior of compiling the full C++ runner and Inno Setup installer on every commit/PR.

### Test Classification Choices
- **Level 1 (Fast)**: Immediate feedback during coding; syntax, contracts, formatting, and unit behavior.
- **Level 2 (Critical)**: Inviolable data-safety, persistence, CAS tokens, schema migrations, sync journals, and recurrence logic. Run immediately whenever affected subsystem changes; **never deferred**.
- **Level 3 (Deferred Regression)**: Broader host test suites, cross-platform regression, multi-module integration, helper tests, and release toolchain tests. Batched and tracked in `docs/DEFERRED_VERIFICATION.md`.
- **Level 4 (Release Acceptance)**: Packaging, installer upgrades in clean sandbox, physical native hardware checks, Android 16 KiB runtime, and real Google OAuth. Tracked in `docs/DEFERRED_VERIFICATION.md`; mandatory before release.

### Security Decisions
- Enforced least-privilege permissions: `permissions: contents: read` across all test workflows.
- Zero secrets used in pull request or manual host test workflows.
- No `pull_request_target` used, protecting against malicious PR execution from forks.
- Pinned all actions to official, audited versions (`actions/checkout@v4`, `actions/setup-python@v5`, `subosito/flutter-action@v2`, `actions/upload-artifact@v4`).
- Maintained signing secrets isolation strictly in `android-release.yml`.

### Validation Performed
- Official Dart YAML parser validated all 7 workflow files in `.github/workflows/` (0 errors).
- `python tools/dev/check-docs.py` validated all developer documentation links, mapped architecture paths, and feature catalog items (0 errors).
- `python -m unittest discover -s tools -p "test_*.py"` executed 30 unit tests (30 passed in 19.7s).
- Representative Level 2 critical tests executed: `database_initialization_test.dart`, `migration_gate_test.dart`, `task_revision_concurrency_test.dart`, `event_recurrence_test.dart`, `calendar_card_contrast_test.dart` (42 passed in 2m 38s).
- `git diff --check` confirmed clean patch hygiene with 0 whitespace issues.

### Potential Risks & Limitations
- Workflows cannot run on GitHub Actions until pushed to the remote repository. Remote runner timing and network caching remain unmeasured locally.
- In GitHub Actions, `workflow_dispatch` workflows only become visible in the Actions tab once merged into the default branch.
- No application code, database schema, or version numbers were changed. No release was published.

</details>
