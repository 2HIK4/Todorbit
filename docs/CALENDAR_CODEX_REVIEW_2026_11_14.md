# Independent calendar/UI review — 2026-11-14

Baseline: `053fa0f`, branch `codex/independent-beta-review`, Gemini's dirty
implementation and six new tests. Unrelated storage documents are preserved.
No commit, version change, native change, publication or personal-profile access.
Initial tracked diff and test hashes: `.buildlog/calendar-independent-review/`.

## Scope and decisions

Review/fix the six queue entries, including repository recurrence validation,
history, desktop pointer gestures/rendering, shared transient notifications,
contrast, actual time-scale zoom and sidebar fades. Android uses
`MobileWorkspace -> MobileCalendar`, not the desktop time grid. Shared repository
and snackbar behavior apply there; desktop resize/zoom are not Android features.
Native widgets and release artifacts are unchanged.

Engineering Quality, Ultimate UI/UX and Regression skills apply; Flutter widget
testing and static-analysis skills supplement them. Project AGENTS.md,
Architecture Map/Architecture, Codex Workflow, Testing/Test Run Ledger/Progress,
AI Review Queue, Calendar Platform Architecture Recommendation, Design, Theming,
Android, Development and Release guidance were consulted. Relevant skill
references: data safety, design standards and Flutter engineering. No missing
required skill. No broad app redesign or extra dependency is needed.

Actual skill entry points used:

- [Engineering Quality](../.agents/skills/todorbit-engineering-quality/SKILL.md)
- [Ultimate UI/UX](../.agents/skills/ultimate-ui-ux/SKILL.md)
- [Regression](../.agents/skills/todorbit-regression/SKILL.md)
- Flutter widget tests: `C:/Users/User/.codex/plugins/cache/dart-flutter/dart-flutter/1.0.7/skills/flutter-add-widget-test/SKILL.md`
- Dart analysis: `C:/Users/User/.codex/plugins/cache/dart-flutter/dart-flutter/1.0.7/skills/dart-run-static-analysis/SKILL.md`
- Computer Use: `C:/Users/User/.codex/plugins/cache/openai-bundled/computer-use/26.1103.32239/skills/computer-use/SKILL.md`

UX necessity: preserve direct editing and existing view navigation; use explicit
time zoom controls and existing date/time editor for precise date changes.
Do not silently alter recurrence rules to make validation pass. Preserve modal
decisions/conflicts/recovery. Theme foregrounds retain hierarchy where contrast
permits. Coverage dimensions: desktop mouse/keyboard and Android entry boundary;
day/week/month; ordinary/recurring/overnight/multi-day records; light/dark/custom
colors; normal/compact/larger text; animation/reduced motion; SQLite/history/
projection/feedback. Physical platform and assistive technology are separate.

## Invocation ledger

All commands run from the repo root on Windows, sequentially; tests use
in-memory SQLite and `--no-pub --concurrency=1`. Detailed output stays ignored.
No dependency/config changes. Gemini's 36 passes/analyzer success have only
summary evidence in the queue/ledger, without an invocation source fingerprint
or identified final raw logs. They are reported evidence, not independent passes.
New behavioral assertions and changed dependencies justify focused executions.
Unchanged native, release, sync transport, migration and Android binaries do not
need rebuilds; historical release evidence does not validate this dirty UI.

| Local time (+03:00) | Command/action | Result and reason | Evidence |
| --- | --- | --- | --- |
| 11:23 | Dart MCP `dtd(listDtdUris)` | No debug/DTD processes; runtime inspection currently unavailable | Tool result in chat |
| 11:24 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_independent_review_test.dart` | Failed all five targeted assertions against Gemini: silent weekday mutation, gray-119 contrast <4.5, hidden all-day details in both themes, missing time zoom control | `01-prefixed-regressions.log`; initial patch/test hashes |
| 11:27 | Same command after initial repairs | 3 passed, 2 failed: discovered recurring-master history lookup used occurrence projection; fixture disposed a provider-owned controller twice | `03-corrections.log` |
| 11:28 | `flutter test --no-pub --concurrency=1 --reporter expanded` with `calendar_independent_review`, the eight Gemini candidate suites, `calendar_history_review`, `calendar_history_error_review`, `event_recurrence` (all under `test/`, suffix `_test.dart`) | 52 passed, 2 failed: actual pointer cancellation committed a second history entry; old history-error assertion expected persistence. Fixed raw pointer cancellation; changed obsolete persistence assertion to transient >=7 seconds | `05-focused.log` |
| 11:31 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_independent_review_test.dart test/notification_auto_dismiss_test.dart test/calendar_history_error_review_test.dart test/sync_conflicts_dialog_test.dart test/mobile_workspace_test.dart test/mobile_editors_test.dart` | 71 passed, 3 failed: Sync's accessible-navigation fixtures still asserted disappearance at four seconds. Added short/long message distinction and retained accessibility doubling; source assertions below resolve the failures | `07-boundaries.log`, `07-source.patch`, `07-source-hashes.json` |
| 11:34 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_independent_review_test.dart test/calendar_interactions_regression_test.dart test/calendar_multi_day_resize_test.dart test/calendar_card_contrast_test.dart test/notification_auto_dismiss_test.dart test/calendar_history_error_review_test.dart test/sync_conflicts_dialog_test.dart` | 69 passed, same 3 obsolete accessibility timeout assertions failed. All 14 independent calendar cases pass, including actual pointer cancellation, saved labels, alpha-composited contrast, monthly/yearly history, exception sync journal, animated scale/anchor and both reduced-motion settings. Corrected the three assertions to wait for actual duration and explicitly verify six accessible success seconds | `09-final-targeted.log`, `09-source.patch`, `09-source-hashes.json` |
| 11:36 | `flutter test --no-pub --concurrency=1 --reporter expanded test/sync_conflicts_dialog_test.dart --name 'first-device recovery\|routine sync feedback'` | All 3 passed. Only changed assertions rerun; other 32 Sync cases reused from 09 with identical source/fixtures/dependencies. This is an intentional reading-time accommodation, not weakened auto-dismiss coverage | `11-sync-reading-time.log`, `11-assertion-hash.txt` |
| 11:37–38 | Dart MCP `analyze_files` over changed source/tests | First attempt rejected because MCP roots were not registered; `roots(add, file:///D:/AI_Projects/life_manager)` then exact retry: **No errors**. No automatic fixes | Tool results in chat |
| 11:38–44 | `flutter run --no-pub -d windows -t .buildlog/calendar-independent-review/runtime_main.dart --verbose` | Debug build/start **passed**; child APPDATA/LOCALAPPDATA and resolved TodoPilot profile logged before synthetic SQLite access. Actual workspace/theme/calendar with overridden local controller/privacy; no account/Sync/native widget launch. The Windows build also compiled its normal native companion target; this is not native Release/self-test evidence | `13-runtime.log`, retained harness |
| 11:41–44 | Computer Use / actual Windows review | Dark week: metadata readable, sidebar dark shadow. Clicked time zoom: visible row spacing changes while 07:00 stays at top. Day transition/all-day location visible. Switched to Light through Settings; readable cards and subtle gray sidebar shadow. Scrolled sidebar to bottom: lower fade disappears, last items accessible. No claim of physical multi-day drag, Android, high-DPI or assistive-technology acceptance | `dark-week.jpg`, `dark-week-zoom.jpg`, `dark-day.jpg`, `light-day.jpg`, `light-sidebar-bottom.jpg` |
| 11:42 | Dart MCP VM-service connect then `hot_reload` | **Succeeded** for the isolated app. DTD auto-discovery returned no instances even after launch, so used the documented direct VM-service connection fallback | Tool results in chat |
| 11:43/44 | Dart MCP `get_runtime_errors` | **No runtime errors found** after reload and again after UI journeys | Tool results in chat |
| 11:41 | `git diff --check` | Passed; CRLF-conversion notices are informational. Final documentation check recorded below | Tool output in chat |

Formatting commands 02/04/06/08/10 are retained as numbered logs. They format
explicit changed Dart paths only; no verification pass is inferred from them.
Source before 07/09 is captured in patches and SHA-256 manifests. Earlier
diagnostic stages are baseline plus documented edits; final acceptance uses 09.

Evidence reuse: 05's event recurrence (7), occurrence move (1), mode animation
(3), sidebar fade (3), calendar history (4), keyboard/history (8) assertions
remain valid at their unchanged repository/controller/view boundaries or are
covered by stronger 09 gesture/contrast assertions. 07's mobile workspace (23)
and mobile editors (2) passed against the final mobile source. Subsequent changes
touch desktop saved labels/ghost color and shared duration for short messages;
mobile fixture scenarios and short info defaults are unchanged. No repeat of
these unchanged passing suites, full Flutter suite, schema migration gate,
native Release, signed Android build, Google request or packaging is justified.

## Findings and final evidence

Confirmed root causes and corrections:

- **CAL-01:** occurrence drafts incorrectly carried master recurrence through
  first-weekday validation. Gemini's repository/editor sanitization is sound.
  Its master workaround silently replaced one weekday (and collapsed `{Mon,Wed}`
  to `{Wed}` when moving Mon->Wed). Removed it: preserve the complete rule;
  disallow a master start on an unselected weekday with actionable guidance.
  A master moving to an already selected weekday is allowed. History now loads
  recurring masters from the repository because controller events are projected
  occurrences; undo/redo keep current non-time fields and rules. Monthly/yearly
  rules retain kind/interval/until, and intentional start-date edits change their
  anchor normally. No schema/task-validation/Sync-protocol change.
- **UX-01:** shared and calendar notices remain finite; explicit success/info/
  warning/error floors 3/4/5/7 seconds, long text receives reading time and
  accessible navigation doubles it. Shared mobile feedback replaces stale queued
  notices; mobile calendar errors use the error helper. Corrected a separate Sync
  status snackbar with an action that otherwise defaults to persistence; recovery
  remains accessible in Sync settings. Sync success is explicitly success type
  and remains deduplicated. Decisions/conflict/security dialogs are untouched.
  No custom timer to leak on disposal. Reading-time/device screen-reader behavior
  is not a comprehensive accessibility certification. Native notifications follow
  the OS, and existing ordinary framework snackbars elsewhere retain finite
  defaults; no claim that every old call site now uses typed styling.
- **CAL-02:** replaced unsafe luminance-cutoff fallback with the stronger black/
  white foreground, while preferring semantic text colors. Composite translucent
  card fills onto their actual opaque surface. Removed cancelled-title opacity;
  strike-through retains state. Fixed all-day metadata previously excluded by
  the all-day branch and used the same contrast selection. Ghost fills are opaque
  composites with readable text; original dragged cards remain deliberately faded
  beneath previews. Tests measure actual rendered foreground/backgrounds, alpha,
  metadata, cancelled and normal states in both themes. WCAG AA 4.5 is guaranteed
  by black/white selection on opaque colors; a universal 5.0 claim is impossible
  for some midtones (best black/white is approximately 4.58). Primary 5.0 remains
  a preference when attainable, not a false universal guarantee.
- **CAL-03:** real pointer tests confirmed visible cross-day hit resolution and
  one saved event split across ordinary rendered columns. Fixed pointer-cancel
  commits and misleading first/last-day time labels (e.g. `20:00–24:00 →`,
  `← 00:00–03:00`). Resize handles appear only on true endpoints. Calendar rows
  now use civil clock differences instead of 23/25-hour elapsed-day geometry;
  persistence still retains actual timestamps and elapsed move duration. Existing
  minimum duration/snap/undo tests pass. **Pending:** day-only and beyond-week
  resizing still resolve/clamp to visible columns, no horizontal week navigation
  or viewport-edge continuation. Use the existing event date/time editor for
  those dates; this is a workaround, not completion of the requested gesture.
  Safe continuation requires explicit navigation/preview design and tests, not
  arbitrary wraparound. Physical touch/Windows drag, rapid edge reversal and
  DST-zone runtime acceptance remain unobserved. Entry stays pending.
- **CAL-04:** Gemini animated view modes only. Added explicit time-slot zoom
  controls (30–120px/hour, 15px steps) with 160ms ease-out interpolation; repeated
  clicks retarget, both reduced-motion settings apply, and day/week preserve the
  top visible civil time while layout/controller use the same scale. Pointer
  down stops animation before editing; zoom is unavailable during active
  gestures. Ctrl+wheel retains existing debounced date-anchored view navigation
  and is consumed during active drags. Outgoing mode views cannot receive input
  or focus. No claim that Ctrl+wheel is time-scale zoom or that a profile/release
  performance benchmark was performed.
- **UI-01:** Gemini's opt-in shadow colors preserve shared defaults. Existing
  pointer transparency, top/bottom/no-overflow logic and sidebar dimensions are
  unchanged. Three independently executed shared fade tests passed; actual
  Windows light/dark appearance and bottom-scroll fade disappearance observed.

API check: explicit `persist: false` is required for transient snackbars with
actions in the installed Flutter generation; see the official
[Flutter behavior update](https://docs.flutter.dev/release/breaking-changes/snackbar-with-action-behavior-update).
The queue's attribution to Flutter 3.24+ was not used as authoritative history.

## Final source and disposition

`053fa0f` plus the reviewed working tree; no commit made. Final source/assertion/
dependency manifest: `.buildlog/calendar-independent-review/final-source-hashes.json`,
SHA-256 `9F801620E293125A40E119C8988F5410B2B2BDD0AEB7ABA4F73708B060F51108`.
Application code matches 09. Three timeout assertions changed afterward (11);
two additional pointer-span cases were added and passed in 16. Final targeted
analysis of that changed test file returned No errors (17).
The independently executed successful coverage is 69 final cases in 09 + the
3 corrected cases in 11 + 2 new pointer cases in 16, with non-overlapping
unchanged passes reused from 05/07
as explicitly scoped above. Do not add repeated counts or call either earlier
mixed run an all-pass execution.

**Partially approved:** UX-01, CAL-02 and CAL-04 approved after Codex fixes;
UI-01 approved as implemented. These four have permanent History entries before
removal from the active queue. CAL-01 remains pending: occurrence moves are
verified, but preserving weekday semantics currently blocks master moves to an
unselected weekday. That does not meet unrestricted master-move acceptance;
explicit series-move semantics/confirmation and corresponding history/override
coverage remain necessary. CAL-03 remains pending for safe beyond-visible-date
resize and further gesture/runtime acceptance. Normal exact-source CI/package/release gates are
still required when preparing a candidate; no release was requested or published.

Limits: host/widget tests and one isolated Windows Debug runtime, no actual
Android device/emulator run, physical touch/DPI/multi-monitor/screen reader,
live Google exchange, real DST-zone transition or Release frame-time profile.
Android retains its touch editor/calendar shell; no claim of new timeline gestures
there. General grid-gutter contrast and full app UI are outside this six-feature
review. A first occluded capture showed another foreground window and was not
accepted as app evidence; subsequent captures followed explicit target activation.
Two accessibility-index clicks were rejected as stale without applying input;
fresh screenshot-coordinate actions succeeded. These are tool limitations, not
application failures. Closing via the non-TTY command stdin was unavailable;
closed only the isolated Debug window through its title-bar close button.
At 11:46, window inventory confirmed no isolated Debug window and the retained
Flutter run log ended with exit code 0. Synthetic profile and evidence retained.

Exact 05 test argument expansion (following
`flutter test --no-pub --concurrency=1 --reporter expanded`):

```text
test/calendar_independent_review_test.dart test/calendar_event_move_recurrence_test.dart test/notification_auto_dismiss_test.dart test/calendar_card_contrast_test.dart test/calendar_multi_day_resize_test.dart test/calendar_zoom_animation_test.dart test/scroll_edge_fade_test.dart test/calendar_interactions_regression_test.dart test/calendar_undo_redo_shortcuts_test.dart test/calendar_history_review_test.dart test/calendar_history_error_review_test.dart test/event_recurrence_test.dart
```


| Local time (+03:00) | Final invocation | Result / reason / evidence |
| --- | --- | --- |
| 11:48 | `git diff --check` and inline Python local-link/queue-ID validation | Passed; `14-diff-check.log` plus tool output. Documentation only; no app retest. Final acceptance subsequently retained CAL-01 as pending too. |
| 11:49 | `dart format test/calendar_independent_review_test.dart` | Explicit new-assertion formatting; `15-format.log`. |
| 11:49 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_independent_review_test.dart --name 'pointer resize multiple columns\|pointer resize backward'` | Both passed; only new pointer cases executed, unchanged app source. Actual Monday->Thursday and Wednesday->Tuesday handles, persisted timestamps, single identity/history and four/two saved segments. `16-pointer-spans.log`, `16-new-assertions.txt`. |
| 11:50 | Dart MCP `analyze_files` on `test/calendar_independent_review_test.dart` only | No errors; new test declarations justify this bounded analysis. No app code changed/rebuild/reload needed after previous successful reload. |
| 11:53 | Final source-hash comparison, inline Python local-link/queue/history-ID checks and `git diff --check` | Passed. Application source is identical to 09; only the added independent assertions differ. Exactly four approved archive IDs and CAL-01/CAL-03 pending; local links resolve. Final whitespace result retained in `18-final-diff-check.log`. Documentation changed after 14, justifying this final check; no further app suite/build. |

Final acceptance correction: CAL-01 was initially considered approved after the
safe weekday guard. The final objective comparison found that the guard still
blocks an unselected-weekday master move, so it is retained pending; the occurrence
fix and all defect/evidence history remain permanent. Four completed entries,
two pending. No silent recurrence rewrite was reintroduced to improve counts.

## CAL-01/CAL-03 final independent continuation (2026-11-14, +03:00)

Current branch `codex/independent-beta-review`, HEAD still `053fa0f`; Gemini's
subsequent changes are uncommitted alongside the earlier review repairs. Canonical
queue is `docs/AI_REVIEW_QUEUE.md`; no duplicate receipt/queue created. Initial
patch, dialog copy and path/SHA-256 manifest are retained under ignored
`.buildlog/calendar-final-review/`. Existing storage documentation is preserved.
The previous four approved records remain intact. No version bump/publication.

Reapplied the previously loaded Engineering Quality/data safety, Ultimate UI/UX
(design/Flutter/accessibility), Regression, Flutter widget testing/static analysis
and Computer Use instructions. Read current AGENTS, Architecture Map, workflow,
testing/ledger, queue/history/progress and this prior receipt; architecture,
recurrence, platform split, theme/profile/release guidance remains applicable.
No required document or skill is unavailable. No new dependency/schema/protocol.

Gemini's 12+9+16+11 passes are reported summary evidence without a final source
fingerprint/raw log identity. Earlier source-fingerprinted passes are reusable
only at unchanged boundaries; the interaction-controller, new dialog, day/week
navigation and model-helper changes invalidate relevant interaction evidence.
Unchanged notification/style/native/Android/Drive/release binaries are not a
reason for broad builds/retests. Heavy commands run sequentially on the 16GB host.

Confirmed issues before repair:
- Weekday translation silently kept `{Mon,Wed}` unchanged for a Mon->Wed whole
  series move instead of showing/applying `{Wed,Fri}`.
- A no-op commit returned before resetting its committing guard, disabling later
  moves. Explicit cancel/Escape was ignored during navigation preservation.
- Existing nominal-key overrides/cancellations/alarms were not migrated. Merely
  retaining rows detached overrides or let a cancelled occurrence reappear.
- Parent/child completion could open duplicate dialogs; raw pointer ownership was
  not checked, allowing unrelated releases/cancels to affect an active gesture.
- Modulo day mapping and duplicate pointer updates could wrap into unrelated
  times. Content-based edge coordinates missed viewport boundaries/rapid input.
- Series history overwrote later rule edits; recurrence summaries omitted until
  dates and could show the dragged date rather than the actual master anchor.

Safe policy: entire-series calendar movement is refused, atomically, when edited,
cancelled or occurrence-alarm rows or historical split generations exist. UI
explains this and offers occurrence-only/editor paths. This prevents critical
exception detachment; it is not a claim of completed exception migration. CAL-01
must remain pending if its required exception-aware whole-series behavior is
still absent. No rows are deleted/rekeyed, no alarm IDs changed, and no unrelated
cloud/key architecture is introduced. Whole-pattern multi-weekday translations
must preserve ordinal/gap semantics; ambiguous interval or clamped-anchor moves
route to explicit editor customization. Historical series-wide changes are stated
in the confirmation, as is existing last-day clamping for monthly/yearly rules.

| Invocation (+03:00) | Command / purpose | Outcome / rerun reason / evidence |
| --- | --- | --- |
| 13:44 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart` | All 4 new regression assertions failed against Gemini; rule translation, no-op guard, navigation cancel, cancelled exception detachment. `01-prefixed.log`, initial manifest. |
| 13:46 | Same command after controller/repository repairs | All 4 passed; `03-corrections.log`. |
| 13:48 | Same command with four new real pointer edge-paging cases | 4 passed, 4 failed: rapid accepted pan reaching edge did not start dwell until another move. `05-gestures.log`. |
| 13:50 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'pointer survives'` | All 4 passed after day/week subscribed to actual gesture updates; explicit next-page mapping, one commit, stationary anti-runaway and cancellation in both views. `07-edges.log`. |
| 13:52 | `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart test/calendar_event_move_recurrence_test.dart test/calendar_multi_day_resize_test.dart test/calendar_independent_review_test.dart test/calendar_interactions_regression_test.dart test/calendar_history_review_test.dart test/event_recurrence_test.dart` | Pending affected shared-boundary check; `09-affected.log`, `09-source.patch`, `09-hashes.json`. New scope/lifecycle/persistence changes justify this set, not an unrelated full suite. |

Explicit formatting invocations 02/04/06/08 are retained as numbered logs, limited
to changed paths. Additional final results, reuse boundaries, runtime observations
and pending/approved dispositions will be appended before review closure.

Continuation invocation updates (same final-review log directory):

| Invocation (+03:00) | Outcome / cause / evidence |
| --- | --- |
| 13:52, 09 affected command above | 18 passed, 6 failures: missing extension access in CalendarView caused four suite-load failures; two old resize assertions treated explicit cancel as recognizer teardown. Added the controller read wrapper; tests now call the dedicated recognizer-teardown method. `09-affected.log`. |
| 13:54, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart test/calendar_event_move_recurrence_test.dart test/calendar_independent_review_test.dart test/calendar_interactions_regression_test.dart test/calendar_history_review_test.dart` | 47 passed, 6 failures: a safety check wrongly classified normal `active_from_date` as historical splitting. Changed it to actual sibling generations/end boundary and moved the normal activation anchor atomically with the master CAS update. `11-ui-history.log`. |
| 13:58, full 09 command again | **79 passed** after actual shared repository/gesture changes invalidated previous failed evidence. Added real backward/two-page gestures in both views, zero preview/cancel sync writes, one success write/history, stale-approved-master CAS refusal, and later-rule-edit history protection. `13-final-boundaries.log`. Format 10/12 logs retain explicit path invocations. |
| 14:01, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'off-viewport history'` | Both new ordinary/recurring assertions failed against the pre-fix history lookup after moving the controller window to another month. Only the history method was temporarily restored to its unpatched implementation for this reproduction; no unrelated work discarded. `14-history-prefixed.log`. |
| 14:03, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'off-viewport history\|series history\|stale data'` | All 4 passed after bounded repository history lookup correction. Two new window cases plus affected stale/series-history cases only. `16-history-corrected.log`, explicit format log 15. |
| 14:04, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_history_review_test.dart test/calendar_history_error_review_test.dart` | All 5 passed; required history dependency checks after lookup correction, including later metadata retention and unavailable/deleted record errors. `17-history-regression.log`. |
| 14:04–06, Dart MCP targeted `analyze_files` | No errors in changed controller/repository/model/calendar/dialog/tests. No auto-fixes; root already registered. Tool result retained in chat. |
| 14:06, `flutter run --no-pub -d windows -t .buildlog/calendar-final-review/runtime_main.dart --verbose` | Isolated Debug acceptance starting. Harness asserts child APPDATA/LOCALAPPDATA and resolved profile before synthetic SQLite access; existing real app not targeted. `19-runtime.log`. |

Intermediate pre-live lifecycle manifest is retained as
`.buildlog/calendar-final-review/checkpoint18-hashes.json`, SHA-256
`79535CEB255C572832E822C83B99C3DDA481E58F8B20648EBD5546D73733FF44`.
The final manifest below supersedes it for final source identity.
`final-source.patch` plus retained new source/tests identify the reviewed dirty
working tree. The 79-case run preceded the bounded history-lookup change; its
unchanged assertions/boundaries are reused with the focused 16/17 replacements,
not misrepresented as a fresh all-suite run on the final hash. Two new assertions
were added after 13. The earlier diagnostic-stage identities are working tree plus
recorded edits/logs; do not invent missing pre-invocation file manifests.

The final series guard checks related generations rather than the ordinary first
activation boundary. Unsplit series moves update `active_from_date` inside the
existing single CAS `UPDATE`/transaction, preserving one identity and one captured
master change. Full selected-weekday translation uses civil dates and rejects
unrepresentable multi-week interval gap changes. Confirmed master revision is
passed from the dialog through CAS, so changes during confirmation are refused.
Series history restores only its owned rule, rejects later rule changes and checks
exceptions again; ordinary/occurrence history preserves current non-time fields.
History lookup now survives month-window changes without unbounded projection.

CAL-03 now uses explicit civil day/week paging rather than modulo wraparound:
400ms dwell, stationary lock until deliberate movement/re-entry, direction reversal,
viewport-edge bounds, scrolling hidden week columns before paging, and scroll
reset to the newly opened day/week edge. Stationary pointer coordinates do not
silently change endpoints after paging. The original pointer retains ownership;
other releases/cancels are ignored. Only recognizer teardown is suppressible during
navigation; explicit cancel/Escape always clears pending state. Parent/child
completion is single-flight, and no-change commits release their guard. New real
pointer tests cover forward/backward, two pages, commits/cancels in both views,
preview persistence and exact Sync journal/history counts. Narrow/high-DPI/native
and real DST transitions remain separate runtime/manual acceptance dimensions.

Live input and final gesture corrections:

| Invocation (+03:00) | Result / evidence / reason |
| --- | --- |
| 14:08, format 20 + `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'recurring completion'` | 1 passed; added resolution-state freeze/recheck so an interrupted pending scope choice cannot apply to a new gesture. `21-choice-lifecycle.log`. |
| 14:09, format 22 + same test with replacement-gesture assertion | 1 passed; completed the start-gesture guards and explicitly asserted proposal cannot be replaced during choice resolution. `23-choice-guard.log`. |
| 14:09 onward, Computer Use / Dart VM / Driver | Isolated app observed. Native automation drags and Driver touch drags did not exercise resize; ordinary touch scrolled. Read-only live controller/handle diagnostics narrowed cause to the competing horizontal scroller at workspace width. Driver 5-second/default-timeout attempt timed out; retained as failed acceptance tooling, not a pass. No personal app targeted. |
| 14:17, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'narrow week resize'` | Fails: expected Tuesday 10:00, persisted Monday 11:00. New 600px Week fixture proved resizer pan lost the gesture arena to ancestor scrolling. `24-narrow-prefixed.log`. |
| 14:18, format 25 + `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'narrow week resize\|pointer survives'` | All 13 passed. Resize-handle-local gesture settings match the existing precision threshold and win before directional scrolling; background/body/Android agenda scrolling unchanged. Installed Flutter gesture-settings source checked through Dart MCP. `26-resize-arena.log`. |
| 14:19, hot reload + live Driver edge gesture | Reload succeeded. Week advanced and multi-day ghost visibly appeared in the running app. Driver frame-synchronization timeout left a captured gesture; actual keyboard Escape cleared preview. Diagnostic Driver timeout is retained, not misreported as a clean runtime result. |
| 14:21, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'explicit cancellation stops'` | New assertion fails: auto-scroll continues after explicit controller cancel. Confirmed lifecycle defect, not just Driver timeout. `27-scroll-cancel-prefixed.log`. |
| 14:21, format 28 + `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'explicit cancellation stops\|narrow week resize'` | Both passed. Timeline state observes cancellation, stops/clears timer and refuses restart on subsequent captured moves. Periodic scrolling uses current edge direction, preventing stale-direction reversal. `29-scroll-cancel.log`. |
| 14:23, `flutter test --no-pub --concurrency=1 --reporter expanded test/calendar_final_review_test.dart --name 'pointer survives\|explicit cancellation stops\|narrow week resize\|recurring completion'` | **All 15 passed**; `30-final-gestures.log`. This is a targeted replacement for affected 13/26 evidence, not another full suite. |

Runtime harness uses synthetic isolated SQLite and weekly/non-recurring cards.
Read-only VM diagnostics and a temporary in-memory trace listener contained only
synthetic gesture state. Driver timeouts are tooling errors, retained verbatim in
`19-runtime.log`; no claim of a zero-error run before those were resolved. Final
live Driver check must disable frame sync during captured edge auto-scroll and
restore it afterward; physical mouse/high-DPI/touch acceptance remains distinct.


### Final continuation result — 14:35 +03:00

**Partially approved: CAL-03 approved after repairs; CAL-01 remains pending.**
The earlier four approvals are preserved. No source commit/version bump/release.

Final source at HEAD `053fa0f` plus working tree is identified by
`.buildlog/calendar-final-review/final-source-hashes.json`, SHA-256
`A8DD9A84C88FBB6A4432DE92774B61C6C8E47E5C9CB886533601F92100DBB1FB`.
The retained patch, new dialog and test file, and manifests identify the source;
ignored compiled products are not committed. No test count is a release gate.

| Final verification (+03:00) | Actual result / evidence |
| --- | --- |
| 14:23–25, targeted Dart MCP analysis of final timeline/controller/view/test; hot restart | No errors; restart succeeded and installed cancellation subscriptions. Initial broad targeted analysis had passed before final bounded fixes. No repeated full analyzer/Release build. |
| 14:25–30, live Driver/Computer Use | Some high-frequency Driver gestures timed out and their failures remain in `19-runtime.log`. Source inspection of installed Driver showed per-move timers; one bounded lower-frequency (20Hz, 2sec, 20sec timeout) attempt **completed successfully**, with frame sync disabled only for the gesture. Waited for asynchronous confirmation/rendering instead of treating immediate transition screenshots as final. |
| 14:29–31, live combined CAL-01/CAL-03 journey | Actual Windows Debug week advanced, multi-day preview appeared, exactly one scope confirmation was observed, and native click on This occurrence only saved the resized occurrence. `resize-scope.jpg`, `saved-week-segments.jpg`. Read-only independent SQLite connection confirmed three synthetic masters and exactly one occurrence exception, nominal `2026-11-14`, saved start `2026-11-14T06:00Z`, end `2026-11-21T07:30Z`. Other masters/rule unchanged. Overlap lanes and ordinary saved intermediate/final segments observed. |
| 14:31, native toolbar Undo then Redo + isolated SQLite polling | Both **passed**. Undo restored end `2026-11-14T07:30Z`; Redo restored `2026-11-21T07:30Z`. One exception row and three original masters retained; no duplicate record. `final-redo-segments.jpg`; tool results retain independent readback. |
| 14:32, explicit projection format 31 + `flutter test --no-pub --concurrency=1 --reporter expanded test/event_recurrence_test.dart` | **7 passed**; `32-projection-regression.log`. Final projection uses next civil midnight and civil span lookback rather than elapsed 24h days, preventing DST-boundary clipping. This is source-invariant correction; a pre-fix real DST-zone reproduction is unavailable on this fixed-zone host and is not claimed. No migration or persisted timestamp conversion. |
| 14:33, Dart MCP analysis on `lib/data/event_repository.dart`, final hot reload | No errors; reload succeeded after the projection change. Current Amman runtime boundaries are equivalent, so prior observed UI/data readback remains applicable. |
| 14:33–34, Driver frame-sync restore and runtime diagnostics | Frame sync restored to true. Final `get_runtime_errors`: **No runtime errors found** after clear/reload. Historical Driver timeouts remain in the raw log; this is not a claim of an error-free entire session. |
| 14:35, isolated window close | Native title-bar close, Flutter run **exit 0**; fixture/evidence retained. Only the returned Debug window was targeted; the installed personal app was not used. |

CAL-03 acceptance is a code/feature review approval supported by real widget
pointer, in-memory persistence/journal/history, and actual running Windows
framework/native-button journeys. Physical mouse drag timing, high-DPI/multi-
monitor resize, real DST-zone transition, Android hardware, assistive technology
and Release frame-time profiling remain separate manual/platform acceptance.
Android still uses `MobileCalendar`/shared editor; desktop pan changes do not
claim new Android timeline gestures. No live Google exchange or full release
packages/CI were repeated; native source and signing/updater inputs are unchanged.

CAL-01 cannot be archived as complete: translating a series with existing edited,
cancelled, occurrence-alarm or historical-generation state still requires a
reviewed key/identity migration policy and undo/redo. The new atomic guard and UI
explanation prevent silent detachment; they are a safe restriction, not the full
requested feature. Nominal IDs, deterministic alarm IDs, orphan overrides,
historical boundaries, inverse history and Sync journal capture must be handled
together. Occurrence-only movement/resizing works; normal unexceptional series
transformation, until dates, intervals, master CAS and later-rule safety pass.

Evidence reuse: 13's unaffected 79-case boundaries remain valid with explicitly
replaced 16/17 history, 23 choice guard, 30 gesture and 32 projection checks.
No mixed failing run is called all-pass, and repeated assertions are not added
into a misleading total. The four previously approved features keep their
permanent records; relevant zoom/contrast interactions also passed in 13.

Safe checkpoint: keep the exact final manifest and this receipt with the current
focused branch. When a commit is requested, stage only the reviewed calendar/
repository/controller/model/tests and review documentation; inspect the staged
diff and exclude unrelated storage documents, builds and synthetic profiles.
All six improvements are **not** yet ready for a beta candidate as a completed
set because CAL-01 remains open; exact-source CI/platform/package gates are also
required before any future publication.

Final documentation verification (14:42 +03:00): inline Python validated 172
local documentation links, CAL-01 as the sole pending queue entry, all five
approved history records, and all 38 final source hashes. Preserved Gemini's
submitted queue record with an explicit historical-claims label. Reviewed final
repository/controller changes and documentation dispositions; `git diff --check`
passed (33-final-diff-check.log). These documentation edits do not invalidate
source test evidence; no app suite or build repeated.


## CAL-01 focused recurrence-integrity review — 2026-11-14 17:00 +03:00

**Verdict: APPROVED WITH LIMITATIONS after three confirmed repairs.** This
supersedes the earlier CAL-01 pending disposition; CAL-03 and the other four
approvals remain intact. Branch `codex/independent-beta-review`, HEAD `053fa0f`,
existing dirty work preserved. No commit/version/schema/protocol/release change.

Initial relevant source fingerprint: `3123DC3D…AC713B8` in
`.buildlog/cal01-integrity-review/baseline-hashes.json`; initial patch retained.
Final 15-path manifest: `.buildlog/cal01-integrity-review/final-hashes.json`,
SHA-256 `7CA1E1F46235FF58BCBB277379518F821AEBA971D4CF06D83AFE8BBCA063D8F1`. Raw logs and final patch remain ignored in that directory.
The prior 38-path receipt was compared: changed prior paths are AppController,
event repository, interaction controller, CalendarView and Gemini's two recurrence/
final-review tests. The new ordinal helper in recurrence.dart is reviewed as well.
Lockfile, database wrapper/triggers, day/week/grid, native and mobile paths remain
unchanged at the reviewed boundaries.

### Confirmed defects and fixes

- **P1 — Deleted/archived alarms reactivated** (`event_repository.dart:149,444`).
  Create an occurrence custom alarm; archive/delete its portable row; move its
  series. Gemini selected that row but reinserted only owner/config/timestamps,
  losing `deleted_at` and `archived_at`. Regression observed NULL instead of the
  original flags. Migration now preserves both fields, including through inverse
  mapping; the normal alarm reader still excludes the migrated inactive row.
- **P1 — Finite recurrence silently lost its last ordinary occurrence**
  (`event_repository.dart:195`). Move monthly Jan 31–Apr 30, 2026 back one day:
  old slots Jan31/Feb28/Mar31/Apr30 become a Jan30 rule ending Apr29, with only
  three slots. Leap-year Feb29,2024–Feb28,2025 moved back one day similarly loses
  the final yearly slot. Exception-only validation and the no-exception early
  return missed this. The repository now compares final ordinals for every finite
  series and rejects cardinality changes before writing. Only a bounded final
  interval is expanded, preventing full-series allocation in UI preflight. The
  existing dialog disables Entire series and displays the actionable reason;
  this restriction also applies atomically to bypass calls and history.
- **P1 — Starting from a timed override changed the master twice**
  (`calendar_interaction_controller.dart:442,480`). Master Mon10–11; override next
  Mon14–16; drag that override to Tue14–16 and choose Entire series. Observed
  master Tue14 instead of Tue10, with its default duration replaced by two hours;
  migrating the override then adds its original four-hour offset again. Master
  start and duration now use gesture deltas relative to the selected occurrence,
  preserving the original master duration for a move. The corrected persisted
  override remains Tue14–16 and the master Tue10–11.

### Implementation and experience inspection

`slotDateAtOrdinal` was checked against the generator, not merely the report:
UTC civil arithmetic; partial first weekday week; interval blocks; month-end and
leap-year clamping; strictly increasing unique dates and inverse ordinals. Old
nominals are validated with `between(date,date)` before mapping. End limits,
orphaned exception/alarm slots and historical splits reject before writes.
Payload metadata remains untouched; explicit timing offset and elapsed duration
are translated relative to each corresponding default slot. Custom alarm instants
use the same default-slot delta; relative alarm configuration is retained.
Deterministic UUIDv5 matches the canonical `saveAlarm` owner/nominal formula.
Unique owner/key constraints reject collisions and the transaction rolls back.

Inspected `AppDatabase.transaction`, `sync_schema.dart` INSERT/UPDATE/DELETE
triggers, and remote group materialization directly. The wrapper acquires its
writer lock and assigns one mutation group; old keys have captured deletions,
new keys captured insertions. Overlapping keys preserve their causal chain.
The real two-repository protocol/codec fixture applies the complete group and
matches all portable payload fields; recipient CAS timestamps intentionally differ.
No production sync implementation or trigger changed. Concurrent remote changes
still use the existing conflict/group-review protocol; this focused test does
not establish every multi-device conflict permutation or real Google exchange.

Master CAS uses the confirmed revision. Related rows are read and transformed
inside the same transaction. A forced INSERT failure after master/exception work
proved rollback of all rows, journal entries and group metadata. Controller
Undo/Redo reuses inverse ordinal mapping, preserving cancellation/override/alarm
keys and payloads; later rule changes are refused by existing rule checks.
Revision timestamps advance normally, so Gemini's literal bit-for-bit claim is
qualified: portable intent/identity/created timestamps round-trip, not updated_at.

UI scope remains necessary. Ordinary/single-occurrence paths are unchanged;
preflight receives the actual candidate draft, the disabled-button reason is
visible, and commit revalidates. Existing keyboard/scrollable-dialog, narrow/large
text and single-flight protections remain. Windows desktop exposes series drag;
Android uses MobileCalendar/shared editor, not this desktop timeline. This pass
inspected current source and reused prior rendering evidence only at unchanged
layout boundaries. No new runtime/physical UI acceptance is claimed.

### Verification, reuse and limits

Define I = `test/calendar_series_integrity_review_test.dart`,
S = `test/sync_apply_repository_test.dart`, E =
`test/calendar_event_move_recurrence_test.dart`. All commands run from repository
root with `flutter test --no-pub --concurrency=1 --reporter expanded`, appending
exact path/filter below. Completion times are +03:00; each row is a separate
invocation. In-memory SQLite or the existing disposable two-file sync fixture;
no personal profiles/accounts. New tests address uncovered risks; reruns follow
identified production changes or the stated assertion correction.

| Completed / exact test arguments | Result / purpose / log |
| --- | --- |
| 16:47, I | 4 pass / 3 fail: ordinal, history/journal/rollback controls pass; monthly/yearly count and inactive-alarm failures reproduced. `01-prefixed.log`. |
| 16:48, I | 7 pass after repository fixes. `03-corrected.log`; source changed from 01. |
| 16:49, I `--name 'timed override'` | 1 fail: wrong master clock reproduced. `04-override-prefixed.log`. |
| 16:50, I | 8 pass after gesture-delta fix; affected controller/history coverage retained. `06-integrity-final.log`. |
| 16:52, S `--name 'calendar series migration'` | Test assertion failed comparing updated_at: fixture intentionally uses receiver clock 2050. Group applied; production code unchanged. `07-sync-exchange.log`. |
| 16:53, same S/filter | 1 pass after excluding only independently advanced CAS timestamps from payload equivalence. Nine changes in one complete group; overlapping cancellations/overrides/two alarms materialize together; no pending work/re-export. `08-sync-exchange-corrected.log`. |
| 16:54, I `--name 'clamped exception'` | 2 new pass: actual monthly-end/yearly-leap exception and custom-alarm ordinal migration/inverse payloads. Earlier eight assertions reused. `10-clamped-mapping.log`. |
| 16:56, E `--name 'Moving entire\|Weekly recurrence\|Multi-weekday\|Monthly recurrence\|Yearly recurrence\|Exception preservation\|Occurrence-specific\|Multi-step'` | 8 pass: smallest existing group covering changed series/duration/history paths. `11-affected-series.log`. |
| 16:58, I `--name 'failure after master'` | 1 pass after strengthening assertion to require the forced-trigger error, proving the failure occurred at the intended late write. Other passing assertions reused. `13-rollback-cause.log`. |

Formatting: targeted `dart format` invocations 02 (repository/I), 05 (interaction
controller/I/S), 09 (I/S), 12 (I), each succeeded; logs retained. No formatting
of unrelated paths. Dart MCP `analyze_files` on repository, recurrence,
interaction controller, I/S: **No errors** on final production source (only test
additions/stronger assertion followed; they compiled in subsequent runs).
DTD `listDtdUris`: no debug/DTD processes. Hot reload/restart unavailable; no new
Windows/Android build launched solely to satisfy runtime tooling.

Gemini's latest 25/14/16/9/11 and analyzer reports were inspected as supporting
historical evidence, not silently counted as new independent passes: they lack
exact raw-log/source fingerprints and miss the reproduced defects. Reused prior
source-fingerprinted passes at unchanged dialog layout, ordinary/occurrence,
CAL-03 navigation/timer and earlier four-feature boundaries; those paths were
inspected and their relevant hashes/dependencies compared. No full five-suite
rerun, unrelated tests, Release/native/Android build or live Drive exchange.
Final distinct new coverage is ten integrity cases plus one sync case, alongside
eight selected existing regressions; intermediate failures/repetitions are not
summed into an inflated total.

Supported series moves now preserve ordinals, deliberate overrides/cancellations
and occurrence alarms. **Limits retained:** historical split generations,
nonrepresentable selected-ordinal/interval translations, orphaned keys, recurrence
kind/interval/cardinality changes and finite-end count changes require occurrence
scope or explicit editor review. Exception offsets/durations follow the stated
elapsed-offset policy; real DST-zone wall-clock acceptance is not established.
No physical Android, assistive-technology/high-DPI acceptance or live Google
cross-device test performed. Those and exact-source release gates remain future
acceptance, not claimed by this code-review approval.

Applied root AGENTS, Codex Workflow, Architecture Map, Testing/ledger, prior
receipt/queue/history/progress and Sync guidance; Engineering Quality/data-safety,
Ultimate UI/UX/design-standards/Flutter-verification, Regression, Dart unit-test
and static-analysis skills. No required document/skill unavailable. Preserve the
current focused branch and explicit manifests; no commit or publication authorized.

Final documentation/source checks (17:02 +03:00): 177 local Markdown links resolve,
all six dispositions and Gemini's full submitted CAL-01 record are preserved in
history, the pending queue is empty, and all 15 final source hashes match. Output:
`14-document-validation.log`. Reviewed the repository/controller changes and the
85-line sync-test addition; `git diff --check` passed (`15-diff-check.log`, final
documentation-only check `16-final-diff-check.log`). No test/build repeated for
documentation changes. Review complete; stop at this checkpoint.


## Safe post-review Git checkpoint — 2026-11-14

User explicitly authorized a local commit of the six reviewed improvements.
Existing branch `codex/independent-beta-review`, parent `053fa0f`; index initially
empty. No application functionality or tests changed during checkpoint preparation.
All three original manifest files match their recorded SHA-256 fingerprints.
Chronological overlay covers 52 source/test/dependency paths with zero worktree
mismatches. The [portable source manifest](CALENDAR_REVIEW_SOURCE_MANIFEST_2026_11_14.json)
retains reviewed byte hashes, canonical Git blob IDs and original provenance;
its `checkpointPaths` is the complete explicit staging allowlist: 19 application
sources, 12 tests and six documentation/manifest files. Older raw manifests,
patches, logs and synthetic profiles remain ignored, not staged.

CAL-01 remains **APPROVED WITH LIMITATIONS**: historical generations, orphaned
keys, ambiguous ordinal/interval transformations and finite-end count changes
are rejected; use occurrence scope or explicit editor review. All earlier review
records and Gemini's submitted history are preserved. This checkpoint is suitable
for the next development phase; physical/device/DST/live Drive and exact-source
release/package acceptance remain separate and do not authorize publication.

Unrelated `docs/STORAGE_CLEANUP_2026_11_04.md` and `docs/STORAGE_MAINTENANCE.md`
remain untracked and byte-preserved. No settings, database, secret, generated
artifact, version, installer, native runner or release tag is included.

Applied root AGENTS.md, Codex Workflow (explicit staging and commit review),
Architecture Map, Testing/ledger and review history/queue/receipt/progress;
Engineering Quality with Agent Workflow Efficiency/Git Discipline and Regression
skills. Available skill metadata and local skill filenames were searched: no
standalone Git/repository-management skill is installed; repository workflow and
Engineering Quality supply that guidance. No additional skill installed. Current
scope has no UI/functionality changes, so no new UI audit or runtime build.

Prior exact-source verification is reused as recorded above; no Flutter tests,
analyzer, app reload, platform builds or real accounts were run for Git bookkeeping.
Staging and final commit audits are recorded in the checkpoint validation below.

Checkpoint validation: all 37 explicitly allowed files staged; all 52 approved
source/dependency index blobs equal their canonical reviewed Git identities.
`git diff --cached --check` passed. Staged path/mode and added-content scans found
no unexpected artifacts or credential/private-key patterns. Local Markdown links
resolve; prior receipt/history/queue content and both excluded storage documents
are preserved. Index started empty, no mixed unreviewed source was found, no
custom commit hooks were present and the existing Git identity is configured.
Full staging audit and patch are retained under ignored
`.buildlog/review-checkpoint/`. The commit containing this record is the durable
checkpoint; its SHA and post-commit tree/index/worktree audit are reported on
completion. No push/tag/publication is part of this task.
