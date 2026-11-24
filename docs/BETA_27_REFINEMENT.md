# Beta 27 UI and Calendar refinement

The source baseline is the published Beta 27, commit `7ede889`. This
development branch uses the same version, Schema 29 and profile contracts.

## Visual comparison

The 1920-pixel-wide Windows Profile baseline had 460 pixels of blank space
between navigation and the centered Upcoming content. The new leading inset
aligns the heading, controls and rows. The 1120 dp cap gives long task titles
and metadata room and keeps completion, priority, timer and trailing actions
within a bounded reading span. A full-width layout would increase the scan
distance from titles to actions. Upcoming adds planned-day headings in
Schedule sort and preserves row order. Planned dates and deadlines stay
explicit on each row.

The Flutter previews compared Beta 27's blue-green surfaces with neutral
graphite using muted violet or amber. Muted violet kept the accent visually
distinct from amber warning and priority states, and became the default.
Beta 27 Teal remains selectable. Saved custom palettes and density choices
retain their values. See the [research references](UI_DESIGN_SYSTEM.md#the-today-workspace)
for Today, scheduling and display preferences.

## Calendar performance

Profile mode ran in the normal Windows session with a disposable clone of the
same SQLite fixture for each pass. The fixture includes 132 standalone tasks,
12 recurring task series, subtask/checklist cases, 90 additional densely
overlapping events, a daily event, and a work session.

Baseline CPU samples found repeated item projection on 120 of 725 Month
samples and 60 of 411 Next Month samples. The old projection scanned every
filtered task for every visible day and repeatedly resolved parent IDs by
scanning the task data. The new projection groups planned and deadline entries
in one pass, resolves parents and session titles by ID, and shares timed items
across overlapping civil days. Existing cache keys and recurrence
materialization remain in the same owners. The mode crossfade retained and
composited two grids, and timeline traces recorded opacity work and budget
misses. The current view changes immediately and keeps zoom and gesture behavior.

The fixture is identical and each recorded run started from its own copy.
Windows runtime captures are 1920 × 1057 from the maximized client area.
Driver times include settling and RPC overhead. Zoom and scroll were
exercised independently of the date and mode controls.

| Windows Profile action | Settled driver time, ms | Worst UI frame, ms | Worst raster frame, ms |
| --- | ---: | ---: | ---: |
| First Calendar open | 659 → 569 | 263.5 → 177.3 | 25.4 → 29.0 |
| Week to Day | 736 → 448 | 181.3 → 58.9 | 54.2 → 46.6 |
| Day scroll | 455 → 464 | 1.6 → 1.8 | 21.2 → 26.7 |
| Day zoom | 428 → 424 | 30.3 → 29.2 | 15.8 → 21.8 |
| Day to Month | 1026 → 871 | 512.7 → 71.0 | 5.8 → 27.7 |
| Next Month | 576 → 411 | 536.7 → 45.5 | 15.3 → 37.9 |
| Previous Month | 549 → 435 | 498.2 → 40.0 | 18.5 → 26.0 |
| Month to Week | 1200 → 1094 | 198.0 → 115.5 | 29.9 → 22.9 |
| Six Calendar/list round trips | 6444 → 5798 | 263.7 → 171.0 | 26.8 → 28.1 |

The new projection was sampled once during Next Month out of 201 samples
and zero times during Month out of 389 samples. Recurrence still materializes
on demand when needed. The candidate rendered more frames during several interactions. Raster
budget misses and peak frame times are mixed. Dense scrolling remains
a raster performance concern. Heap usage before/after six round trips was
27.0/26.2 MB on baseline and 54.4/27.8 MB on the candidate. These are sampled
heap values subject to GC timing and establish no long-session memory trend.

## Evidence locations

- Windows before and after, both themes, in `.buildlog/refinement/{baseline,candidate}/report/`.
  Captures include Upcoming, All tasks and dense Day, Week and Month.
- Flutter preview alternatives and narrow/large-text captures in
  `.buildlog/refinement/alternatives/`.
- Selected captures copied to `Documents/Codex/Todorbit-beta27-refinement-renders/`
  on the development host.
- The same report folders retain `summary.json` and per-action CPU and
  timeline traces. The driver and fixture are documented in [Testing](TESTING.md#profile-calendar-and-capture-the-workspace).

## Verification and limits

- Final focused run passed 68 tests. It covers the new layout, preserved
  palette preferences, immediate single-canvas switches, zoom with and
  without reduced motion, series integrity, multi-day resize, saved views
  and draft safety. Earlier focused cases also passed for event move,
  persistence, undo/redo, Android date navigation and desktop hover.
- Changed-file analysis, 39 architecture checks, developer docs/catalog and
  Windows native Release companion self-test passed. The generated native
  orbit differs only at 16, 20 and 24 px.
- On the disposable API 35 x86-64 emulator, the Debug build displayed the
  seeded Today and Upcoming workspaces and Day, Week and Month at 320 dp
  and 150% system font size. The guest's System UI briefly stopped
  responding during startup. The final captures come from the recovered
  guest after verifying the synthetic SQLite copy. Android startup is
  outside the performance comparison.
- The test renderer independently exercised 800 dp Windows and 320 dp
  Android at 150% text. Native Windows title-bar DPI, physical devices,
  and long-duration memory behavior remain manual coverage.

Android screenshots and the emulator receipt are in
`.buildlog/refinement/android-runtime/`. The selected render folder includes
the populated Month and Upcoming captures.
