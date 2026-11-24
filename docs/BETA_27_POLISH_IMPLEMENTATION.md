# Beta 27 polish engineering evidence

Baseline `05ada82`. Changes are on `feature/todorbit-beta27-refinement`.
The [critic's handoff and independent re-review](BETA_27_POLISH_CRITIQUE.md)
capture the visual decisions. Production defaults, data and version remain
compatible with the refinement checkpoint.

## Implementation

- Upcoming gives the matching planned-day heading ownership of the redundant
  visual date. The shared task row retains its semantic planned date and its
  visible deadline, including equal planned and deadline values. Other sorts
  and rows without matching context keep their visual date.
- Compact Android Calendar moves the standalone filter into workspace
  actions. The current filter remains indicated, editable and clearable.
  The normal-width Calendar continues to show its inline filter.
- Appearance exposes Graphite Violet, Neutral Silver, Amber, Sage, Beta 27
  Teal and Dusk in the existing dark palette picker. Violet remains the
  current default. The user chooses any new default.
- Timed Calendar grids paint hour rules in two batched canvas draws per
  column. The existing slot interaction layer, viewport geometry,
  recurrence projection and single-grid mode changes remain in place.

## Windows Profile comparison

Both runs used a separate disposable copy of the same SQLite fixture, a
maximized 1920 × 1057 Windows client and the same Profile instrumentation.
Flutter Vsync samples reported approximately 120.05 Hz, averaging an 8.33 ms
budget. Windows lists both a 120 Hz integrated adapter and a 60 Hz discrete
adapter. Percentages below count stages exceeding the recorded Flutter
budget. They are stage sample rates, not a combined missed-vsync rate.
Driver elapsed time includes the UI settle, input RPC and navigation.

| Scene | Driver elapsed before → after, ms |
| --- | ---: |
| First Calendar open | 540 → 470 |
| Week → Day | 1010 → 1019 |
| Dense Day scroll | 463 → 433 |
| Day zoom | 456 → 447 |
| Day → Month | 459 → 797 |
| Next Month | 481 → 423 |
| Previous Month | 459 → 422 |
| Month → Week | 608 → 1118 |
| Six Calendar round trips | 6448 → 5733 |

**UI frames**. Each cell gives median / p95 / p99 / worst in ms.

| Scene | Before | After | Over budget before → after |
| --- | ---: | ---: | ---: |
| First Calendar open | 1.59 / 32.86 / 133.28 / 158.39 | 1.40 / 3.54 / 82.50 / 102.24 | 11% → 5% |
| Week → Day | 2.54 / 36.52 / 47.05 / 47.85 | 2.71 / 27.44 / 40.72 / 55.98 | 22% → 18% |
| Dense Day scroll | 0.94 / 1.30 / 1.48 / 1.53 | 0.54 / 1.20 / 1.33 / 1.37 | 0% → 0% |
| Day zoom | 3.45 / 27.86 / 30.35 / 30.97 | 2.15 / 29.66 / 32.48 / 33.45 | 33% → 22% |
| Day → Month | 2.89 / 67.35 / 109.92 / 120.57 | 5.84 / 34.78 / 52.96 / 58.65 | 13% → 26% |
| Next Month | 2.44 / 75.10 / 100.64 / 107.03 | 1.93 / 30.33 / 42.13 / 44.89 | 17% → 9% |
| Previous Month | 2.57 / 41.10 / 60.52 / 65.37 | 2.04 / 35.94 / 51.51 / 55.41 | 11% → 14% |
| Month → Week | 1.51 / 151.06 / 217.84 / 234.54 | 1.83 / 69.45 / 129.95 / 157.01 | 17% → 24% |
| Six Calendar round trips | 1.38 / 14.14 / 219.89 / 247.02 | 1.15 / 3.97 / 101.56 / 174.65 | 6% → 3% |

**Raster frames**. Each cell gives median / p95 / p99 / worst in ms.

| Scene | Before | After | Over budget before → after |
| --- | ---: | ---: | ---: |
| First Calendar open | 17.45 / 24.87 / 25.31 / 25.42 | 16.34 / 19.01 / 20.40 / 20.75 | 100% → 100% |
| Week → Day | 14.11 / 17.47 / 24.06 / 29.65 | 10.40 / 12.90 / 13.15 / 13.33 | 98% → 92% |
| Dense Day scroll | 17.40 / 20.00 / 28.31 / 30.62 | 10.06 / 11.09 / 15.86 / 18.23 | 100% → 80% |
| Day zoom | 9.77 / 24.11 / 26.36 / 26.93 | 9.58 / 16.65 / 16.82 / 16.88 | 80% → 69% |
| Day → Month | 18.44 / 29.90 / 30.34 / 30.45 | 13.25 / 17.93 / 21.52 / 21.88 | 100% → 100% |
| Next Month | 19.85 / 48.54 / 56.39 / 58.35 | 14.10 / 21.51 / 32.97 / 35.84 | 100% → 100% |
| Previous Month | 19.27 / 25.14 / 26.65 / 27.03 | 14.25 / 22.40 / 24.20 / 24.66 | 100% → 100% |
| Month → Week | 26.90 / 30.20 / 30.34 / 30.38 | 18.66 / 24.55 / 26.66 / 27.57 | 100% → 100% |
| Six Calendar round trips | 19.15 / 28.02 / 34.13 / 48.43 | 12.43 / 23.67 / 26.19 / 28.76 | 94% → 79% |

Dense Day scroll traces initially put more time in Impeller encoding and
compositor presentation than Flutter layer painting. The timed slot rows
each issued their own hour border paint. Batching those rules reduced the
paint commands used for the same grid. Measured mean Impeller encoding was
4.27 → 3.34 ms and mean compositor presentation was 9.58 → 3.90 ms for this
scroll trace. Raster missed-budget rate fell from 100% to 80%. Other scenes
also moved without a corresponding hour-paint change, so these runs show
the combined result on this host. The display compositor still dominates
some heavy scenes. Day-to-Month and Month-to-Week elapsed times increased in
this pair. The data supports keeping the narrower paint optimization and
leaves broader latency improvement unproven.

Dart heap usage sampled before and after six round trips was 27.53 → 26.29 MB
on the baseline and 52.94 → 28.33 MB on the candidate. These are point
samples subject to GC timing. Retention over long sessions remains open.

The maintained driver writes refresh, latency, UI/raster distribution,
memory, CPU sample and timeline evidence. Raw data is under
`.buildlog/refinement/{polish-before,polish-after}/report/`.

## Traceability

| Finding | Implementation and verification | Independent disposition |
| --- | --- | --- |
| UI-01 | Existing Upcoming grouping supplies matched date context to `AppTaskRow`. Focused tests cover subsequent rows, equal-date deadlines, semantic date and another sort. | Resolved |
| UI-02 | Reduced competing metadata in Upcoming within the shared row. Kept existing Android metadata and recurring-series density. | Partially resolved |
| UI-03 | Compact `MobileWorkspace` uses the shared filter dialog from Workspace actions. Tests exercise apply, active indicator, clear and target size. API 35 runtime shows the compact menu and dialog and the ordinary inline filter. | Resolved |
| UI-04 | Kept event cards and geometry. Batched static hour lines and ran focused slot, drag, resize and undo coverage. | Event-card typography intentionally deferred |
| UI-05 | Dark preset picker reuses the stored palette and theme controls. Contrast tests and five fixture-matched renders support the user's decision. | Comparison resolved, default pending user choice |
| UI-06 | Kept the established orbit and icon family. Windows Profile and Android screenshots provide complete-screen context. | Further icon changes intentionally deferred |

## Verification and readiness

- 73 distinct focused tests passed across nine files. The first run had 72
  passes and a stale test-only context lookup after sort. The corrected
  workspace file passed both tests. The focused run covers Calendar slot
  input, recurrence, persistence, undo/redo, zoom, filter apply and clear,
  contextual dates and palette contrast.
- Changed-file analysis, formatter checks, 39 architecture checks, and
  the developer catalog and document links passed. Comparable opt-in
  Flutter capture tests passed before and after.
- The populated API 35 Debug runtime used the existing disposable emulator
  and fixture. It displayed Day, Week, Month and the compact filter menu and
  dialog at 320 dp and 150% text, plus the inline filter at 393 dp and 100%.
  UI automation temporarily lacked a root during startup and recovered
  before capture. This run is visual and interaction evidence.
- The engineering capture harness and existing Windows Profile driver are
  reusable. Keep the compact filter, Upcoming grouping, palette comparison
  and timed-grid scenarios available for Developer Automation Toolkit
  registration. Its worktree remains separate.
- Selected captures are in
  `Documents/Codex/Todorbit-beta27-polish-renders/` on this host. The raw
  equal-size Flutter pairs are in `.buildlog/polish/{before-flutter,after-flutter}/`.
  The candidate Android runtime receipt and captures are in `.buildlog/polish/after-android/`.

The independent visual verdict supports Beta 28 preparation. Confirm the
default accent with the user and retain the separate physical-device,
assistive and release gates. No version change, release or toolkit merge
was made.
