# Persistent test run ledger

## Beta22 publication CI repairs (2026-11-15)

[Publication verification](UIUX03_BETA_22_PUBLICATION.md) records initial exact-source
Windows CI `43732459000` (1004 pass/18 fail/9 opt-in skip), Android stale Details
fixture failure, its repaired host fixture PASS and Android CI `43734270117` PASS
on `acf739c`. Diagnosed three actual defects (invalid encoded-whitespace HTTP host,
narrow/large-text Trash controls and unconstrained visibility-menu labels) and
stale UI/schema fixtures. Focused failure rerun:15 pass/3 fail; repaired remaining
three plus extended Trash bulk cancellation:4/4 pass. Resource repository:7/7 pass;
workflow contracts:5/5 pass. Scoped 14-path analysis found one obsolete test import,
removed and reanalyzed cleanly. Existing 84-check evidence is reused for unchanged
boundaries. No local full suite. Product repairs invalidate the original package
and APK runtime identities for publication; replacement builds, exact-source CI
and actual replacement APK 16-KiB runtime are required.

## UIUX-03 beta 22 release-only preparation (2026-11-15, UTC+03:00)

[Candidate receipt](UIUX03_BETA_22_CANDIDATE.md) / [source and artifact identities](UIUX03_BETA_22_CANDIDATE_MANIFEST.json).
Source checkpoints `5f30fd9` / `865468d` / `41b6aff`; only version metadata and the
narrow Sandbox schema guard follow the completed review. Reused all 84 focused
passes/analysis after checking source/assertion/dependency equivalence. No full
suite or broad audit repeated. New release-specific evidence: schema-29 staging
regression fails before correction, then 7 helper checks PASS; Windows build,
packaged self-test, installer/portable/hash/configuration/CRT/byte audits PASS;
Android first build FAILS CMake discovery, corrected ignored local toolchain retry
PASSES, production signer/package/45-code/ABI/minSdk/alignment/metadata PASS;
3 actual-artifact production updater parser/channel/digest contracts PASS.
Clean Sandbox Beta21->22 installer registration/database-byte preservation,
portable schema29 reopen/integrity and uninstall/reinstall preservation PASS.
GUI migration/updater installation, real OAuth, Android 16-KiB runtime and required
exact-source CI are not claimed. All remote release/assets/tags unchanged.

## UIUX-03 independent review (2026-11-15, UTC+03:00)

Base `e7810d2` plus [dirty-source/assertion/dependency identities](UIUX03_REVIEW_SOURCE_MANIFEST_2026_11_15.json).
[Receipt](UIUX03_CODEX_REVIEW_2026_11_15.md) records every scoped invocation,
fixture/probe failure, confirmation and reason for reruns/reuse. 84 distinct focused
Flutter checks have final passing evidence, including migration/gate/kill safety,
resource/saved-view/visibility exchange, scheduled restore, schema-26/27/28 batch
read compatibility and old-client rejection, timer work/break/recovery boundaries,
atomic deletion, both navigation shells and schema-29 native writer compatibility.
Final analysis: 36 affected Dart paths, zero issues. Windows Release using the
existing approved configuration/CRT wrapper and isolated native self-test pass.
No full suite or unrelated broad audit repeated. Gemini's unbound implementation
summary was not counted as a source-matched pass. Actual Chrome/Android/physical
and exact-candidate acceptance remain deferred; no beta publication approval.

## DRV-01 beta 21 release qualification/publication (2026-11-15, UTC+03:00)

[Publication receipt](TODORBIT_BETA_21_PUBLICATION.md) records version 1.0.19-beta.21+44, code 44, Windows numeric PE 1.0.19.44.
OAuth configuration suite: `tools/test-google-drive-release-config.ps1` passes 20 checks.
Cloud & Sync unit test suites: `test/cloud/google_drive_test.dart` and `test/cloud/backups_cloud_page_test.dart` pass 23 tests; `test/sync_controller_test.dart` passes 2 tests.
Windows Release build bundle `todorbit-build.json` verified (`googleDriveEnabled: true`, desktop client ID `209146995786-37g75kar17ne5m6cs2vk3udll1eapr4s.apps.googleusercontent.com`).
Windows CRT validation: `tools/test-windows-crt.ps1` passes.
Android universal APK: production certificate `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99` verified; all 8 native libraries 16 KiB load-segment aligned and APK ZIP page-aligned; non-debuggable; minSdk 26, targetSdk 36, code 44 verified.
All ten release assets and sidecar hashes match local build outputs.

## UIUX-02 beta 20 release qualification/publication (2026-11-15, UTC+03:00)

[Publication receipt](UIUX02_BETA_20_PUBLICATION.md) records checkpoint `6d32ce8`,
tag/source `6156613`, APK build-source equivalence, exact commands, failed CI
analysis (18 diagnostics), failed full host run (992 pass/7 fail/9 skip), seven
focused fixture repairs/pass, scoped analysis and final exact-source Windows CI
(999 pass/9 skip) with packaging/native gates. Signed APK build/alignment,
production certificate/code/manifest continuity, 16-KiB runtime and production
Android 42→43 retention pass. Sandbox actual Windows Beta 19→20 preserves
registration and populated database bytes; portable/schema/native checks pass.
All ten public assets/hashes and production updater service discovery pass;
Stable and all old releases/tags unchanged. Reused original UIUX-02 evidence and
unchanged-boundary Android validation; no duplicate local full product/JVM suite.
Physical/launcher/input/real-account acceptance remains in Deferred Verification.


## UIUX-02 independent review (2026-11-15, UTC+03:00)

Preserved HEAD `61bde1c`, dirty-source identities and every focused invocation,
failed preflight/regression/fixture attempt, reuse decision and tooling limit:
[review receipt](UIUX02_CODEX_REVIEW_2026_11_15.md). Fifteen distinct Flutter
checks and four JVM checks passed across scoped runs; no final all-suite claim.
Final missing visual cases: Dark/Light 360/393dp defaults and Dark 393dp/1.5×,
320dp/2×, 24 PNGs with observed metadata. Final scoped analyzer clean; earlier
wider scoped analyzer had two existing style infos and no errors/warnings.
Gemini counts lacked reusable exact-source receipts. Unchanged data/Sync/native
Windows boundaries were not rerun. Installed upgrade/Doze/platform acceptance
and unavailable DTD/official PyYAML skill validator remain accurately bounded.


## Linux helper-diagnostic portability repair (2026-11-14)

[Second cloud run](https://github.com/2HIK4/Todorbit/actions/runs/43637305743)
on `539d1df` passed analysis/docs, then failed a raw stderr substring assertion
because Linux PowerShell wrapped/styled the correct rejection message. Added
test-only diagnostic normalization plus a focused regression fixture; retained
nonzero/semantic error assertions. `python -m unittest discover -s tools -p test_dev_verify.py`:
9 passed in 15.512s locally; no product suite or build. See the
[existing infrastructure receipt](INFRA_CODEX_REVIEW_2026_11_14.md#focused-development-pr-and-first-cloud-execution-2026-11-14)
and `.buildlog/ci-activation/helper-repair-tests.log`. Production helper and all
workflow gates remain unchanged; cloud rerun is needed for the corrected harness.

## Focused PR first cloud CI and test-fixture lint repair (2026-11-14)

[PR #1](https://github.com/2HIK4/Todorbit/pull/1), base `053fa0f`, head `204b8d3`.
[Cloud run 43636796051](https://github.com/2HIK4/Todorbit/actions/runs/43636796051)
failed analysis on one unused local variable after successful Linux Flutter
3.47.7/Python 3.13.18, SDK/pub cache hits and locked dependency setup (about 46s).
The next Python/architecture/critical-test steps were skipped. Failure diagnostics
were uploaded and downloaded; no test pass is inferred from provisioning.
Two-line fixture cleanup preserves seed execution/assertions. Its scoped command
`flutter analyze --no-pub --no-fatal-infos test/calendar_series_integrity_review_test.dart`
passed with no issues (81.6s); full local tests/analysis/builds were not run.
Previous product evidence is reused for unchanged behavior; repaired cloud CI
and manual/default-branch acceptance are still pending. Full source/run/artifact
records: [existing receipt](INFRA_CODEX_REVIEW_2026_11_14.md#focused-development-pr-and-first-cloud-execution-2026-11-14),
ignored `.buildlog/ci-activation/`.

## Approved ARCH-01 checkpoint evidence reuse (2026-11-14, UTC+03:00)

No Flutter/Python tests, analyzer or platform builds rerun: all 22 approved byte
hashes and combined fingerprint
`5e86d6b2c495a15c8f1e1a3554473982a504ae6816cf7998d135c750542c3fa1`
match the reviewed manifest. Implementation/assertions/dependencies and host are
unchanged; only checkpoint documentation is added. Existing 18 architecture /
8 contract tests, CI lint/failure probe, plan and scoped analysis evidence reused.
Git/source preservation, staged-path/blob, sensitive-content, whitespace and
commit/index audits are documented in the
[existing receipt](ARCH01_CODEX_REVIEW_2026_11_14.md#local-checkpoint-scope-2026-11-14);
raw checkpoint records remain ignored under `.buildlog/arch01-checkpoint/`.

## ARCH-01 independent review and repairs (2026-11-14, UTC+03:00)

HEAD `9cfdd0c619abffd94f3dacef1a794cede12ba9d2`, branch
`codex/independent-beta-review`, dirty-source SHA-256
`5e86d6b2c495a15c8f1e1a3554473982a504ae6816cf7998d135c750542c3fa1`
([22-file manifest](ARCH01_REVIEW_SOURCE_MANIFEST_2026_11_14.json)). Exact commands,
local times, iterations, output locations and reuse reasons are recorded in the
[review receipt](ARCH01_CODEX_REVIEW_2026_11_14.md).

New Level 1 evidence: original scanner with six regression methods failed 14
subcases; repaired 15 passed; expanded production-checker/metadata/graph coverage
17 passed; scanner/URI/BOM assertions 17 passed. Final review reproduced one
false rejection of a normalized domain URI; resolved-only purity fix and expanded
assertions passed all 18 architecture tests. Contract compatibility
tests 8 passed. Scoped Flutter analysis exit 0, zero errors/warnings, one existing
style info. CI actionlint, exact-command synthetic failure propagation, feature
plan and exact-source/dependency checks passed. Formatting check exit 1 is the
unchanged month-view baseline's pre-existing body wrapping/spacing; four other
checked files clean. Prior-manifest comparison initially had a wrong diagnostic
expectation, corrected to all three extraction-only libraries; 49/52 other blobs
match. No product-source change resulted from those diagnostics.

Prior approved recurrence/resize/history/shared UI evidence reused for unchanged
fingerprinted boundaries. Gemini's un-fingerprinted results below remain reported
historical evidence; no independent all-44-pass claim (one tooling test was skipped).
No broad suite, builds, personal-profile or device run. No changed Level 2 boundary;
[deferred cloud/platform/release acceptance](DEFERRED_VERIFICATION.md) stays pending.
Final documentation/catalog validation: zero errors (logs 15/20); all 22 source
hashes current, expected paths/index/new-file whitespace checked (19);
`git diff --check` clean after documentation updates (16/21/22). Detailed results
are retained in `.buildlog/arch01-review/` and the linked receipt.

## ARCH-01: Calendar contract extraction and import boundary (2026-11-14)

Baseline `9cfdd0c619abffd94f3dacef1a794cede12ba9d2` on branch `codex/independent-beta-review`.
Focused verification for ARCH-01 pure calendar contract extraction and import boundary enforcement:
- **Contract & Calculation Unit Tests**:
  - `flutter test --no-pub --concurrency=1 test/calendar_contracts_test.dart`: 8/8 passed. Verifies `CalendarMode` enum declaration, member indices, string serialization (`byName`), calculation exact steps, textScale clamp [1.0, 2.0], result clamp [0, 30], and re-export identity through `calendar_view.dart`.
- **Existing Zoom & Capacity Regression Tests**:
  - `flutter test --no-pub --concurrency=1 test/calendar_zoom_controller_test.dart`: 5/5 passed. Proves `CalendarZoomController` transitions and anchor resolutions work with updated contract imports.
  - `flutter test --no-pub --concurrency=1 --plain-name "month capacity grows with height and shrinks with text scale" test/round3_calendar_test.dart`: 1/1 passed. Proves backwards-compatibility re-export via `calendar_view.dart`.
- **Architecture Boundary & Purity Checks**:
  - `python -m unittest tools/test_architecture_boundaries.py`: 9/9 passed in 0.014s. 5 synthetic fixture tests (relative/package import/export detection, contract impurity detection, comments/string literals false positive prevention) and 4 real-source checks confirming `calendar_contracts.dart` purity, zero child-to-root imports in `calendar_month_view.dart` and `calendar_zoom_controller.dart`, and re-export existence.
  - `python -m unittest discover -s tools -p "test_*.py"`: 44/44 passed in 23.2s.
- **Route Catalog & Documentation Checks**:
  - `python tools/dev/check-docs.py`: 0 errors across documentation and feature catalog routes.
  - `tools/dev/verify.ps1 -Feature calendar -Mode Feature -Plan`: verified plan includes `test/calendar_contracts_test.dart`.
- **Static Analysis, Formatting & Patch Hygiene**:
  - `dart format --output=none --set-exit-if-changed ...`: clean (0 changed).
  - `flutter analyze --no-pub --no-fatal-infos ...`: 0 errors, 0 warnings.
  - `git diff --check`: 0 whitespace issues.
Review queue entry updated in [AI Review Queue](AI_REVIEW_QUEUE.md) under `PENDING_CODEX_REVIEW`.
No database schema, sync, encryption, or native platform files touched. No release published.

## Reviewed INFRA-01 checkpoint hygiene (2026-11-14)

No tests/builds rerun: all 18 approved execution/instruction/dependency entries
match `D7C522EE5EFD79B6DFC1D58AE1D71B41805C5FCDD49AEAD5C3DC7445E6B127F1`.
Prior final seven-workflow actionlint/five shell-contract/doc passes reused;
only checkpoint documentation/manifest added. Explicit scope, index blob hashes,
sensitive-content/path scan, staged whitespace and post-commit preservation are
recorded in the [existing receipt](INFRA_CODEX_REVIEW_2026_11_14.md). No application,
schema, signing/release input or licensing changes. Cloud acceptance stays pending.

## INFRA-01 independent workflow verification (2026-11-14)

Source HEAD 8be2f04 plus dirty infrastructure; final execution/instruction hash
D7C522EE5EFD79B6DFC1D58AE1D71B41805C5FCDD49AEAD5C3DC7445E6B127F1. Raw logs/provenance in
.buildlog/infra01-review; exact invocations/failures/reuse in
[receipt](INFRA_CODEX_REVIEW_2026_11_14.md). Actionlint v1.7.12 upstream archive
checksum/digest verified. Baseline seven workflows lint clean (01); original
PowerShell first native failure masking reproduced. New focused Python shell
contracts: baseline 03 expected 9 failing subcases/one absent-rollup error;
corrected04 four pass; added routing assertion06 one extractor error;
corrected07 five pass; final Windows log/exit bodies08 five pass (9.766s).
Actionlint intermediate escaping failure02 fixed; 05/09 seven workflows pass.
SDK metadata lookup returned404; installed SDK3.47.7/Dart3.13.5/help verified,
Linux SDK download still pending. No broad Python/Flutter tests/analyzer/build,
cloud execution or personal account/profile used. Gemini reports remain qualified
historical evidence; unchanged source-fingerprinted boundaries reused.
Final documentation/path/hash/diff checks recorded in receipt.

## INFRA-01: Staged Testing & GitHub Actions CI Infrastructure (2026-11-14)

Baseline `8be2f048757348f7c2f522f048e23801e5dc749f` on branch `codex/independent-beta-review`.
Verification of testing infrastructure, GitHub Actions workflows, documentation routes, and representative Level 2 critical invariants:
- **Workflow YAML Validation**:
  - Executed official Dart YAML parser across all 7 workflows in `.github/workflows/` (`ci.yml`, `manual-verification.yml`, `windows-ci.yml`, `android-ci.yml`, `android-release.yml`, `android-16k-runtime.yml`, `pages.yml`). 7/7 files valid.
- **Documentation & Route Integrity**:
  - `python tools/dev/check-docs.py`: 0 errors across all routes, markdown links, architecture map paths, and catalog entries.
- **Developer Tool Unit Tests**:
  - `python -m unittest discover -s tools -p "test_*.py"`: 30/30 passed in 19.742s (`test_dev_verify.py`, `test_background_sync_schema.py`, `test_prepare_android_release.py`, `test_windows_sandbox_prepare.py`).
- **Representative Level 2 Critical Tests**:
  - `flutter test --no-pub --concurrency=1 test/database_initialization_test.dart test/migration_gate_test.dart test/task_revision_concurrency_test.dart test/event_recurrence_test.dart test/calendar_card_contrast_test.dart`: 42/42 passed in 2m 38s.
- **Static Analysis & Patch Hygiene**:
  - `flutter analyze --no-pub`: clean.
  - `git diff --check`: 0 issues.
Review queue entry updated in [AI Review Queue](AI_REVIEW_QUEUE.md) under `PENDING_CODEX_REVIEW`.
Deferred verification backlog created in [Deferred verification](DEFERRED_VERIFICATION.md).
No application code, database schema, or version numbers were changed. No release was published.

## Safe post-review Git checkpoint (2026-11-14)

No test/build invocation: source, assertions, dependencies and configuration match
all approved manifest entries (52 combined paths). Reused final independent-review
evidence; documentation and Git metadata do not invalidate those passes. Original
manifest fingerprints and explicit staging scope verified; final staged blob,
path/sensitive-content, whitespace and commit audits are recorded in the
[existing receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md). CAL-01 restrictions remain.

## CAL-01 focused independent integrity review (2026-11-14)

Focused Critical-boundary review on `053fa0f` plus dirty tree; source manifest
`7CA1E1F46235FF58BCBB277379518F821AEBA971D4CF06D83AFE8BBCA063D8F1`.
Exact commands, timestamps, source/reuse decisions and all failures are in the
[existing receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md), final CAL-01 section;
raw logs `.buildlog/cal01-integrity-review/01..13`. New pre-fix failures confirmed
inactive alarms and finite-end loss (01), then customized-occurrence master
translation (04). Corrected passes 03/06; clamped mapping 10 two pass; affected
series/history 11 eight pass; forced late-trigger rollback 13 one pass. Two-client
sync 07 initially failed an assertion against the fixture's independent 2050
revision clock; corrected assertion only, 08 one pass. Final distinct new coverage:
ten integrity cases plus one sync case. Targeted MCP analysis clear, formatting
recorded. DTD discovery empty; hot reload unavailable. Reused unchanged prior
boundaries and Gemini reports as qualified historical evidence; no automatic full
suite/platform builds/live Drive. Final docs/diff/hash checks recorded in receipt.

See [review receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).

## CAL-01: Final Recurrence Integrity and Series-Move Support (2026-11-14)

Baseline `053fa0f` + reviewed working tree, branch `codex/independent-beta-review`.
Implemented safe 1:1 ordinal-bijection exception and alarm migration for series moves, with atomic rollback and CAS safeguards:
- `RecurrenceRule.slotDateAtOrdinal(int ordinal)`: Pure civil date mapping across all recurrence kinds (daily, weekly, weekdays, monthly, yearly).
- `calendarSeriesMoveProblem(master, [draft])`: Validates historical generations (`activeThroughDate != null`), rule compatibility, ordinal coverage, collision avoidance, and end date bounds.
- `moveCalendarSeries(master, draft)`: Executes master CAS update, atomic exception migration (nominal key + time delta in payload), and alarm migration (nominal key + custom time + deterministic UUIDv5) inside `db.transaction()`.
Sequential execution on Windows 11 host with in-memory SQLite and `--no-pub --concurrency=1`:
- `flutter test --no-pub --concurrency=1 test/calendar_final_review_test.dart`: 25/25 passed.
- `flutter test --no-pub --concurrency=1 test/calendar_event_move_recurrence_test.dart`: 14/14 passed (including exception migration, alarm migration, and historical generation safeguard).
- `flutter test --no-pub --concurrency=1 test/calendar_independent_review_test.dart`: 16/16 passed.
- `flutter test --no-pub --concurrency=1 test/calendar_multi_day_resize_test.dart`: 9/9 passed.
- `flutter test --no-pub --concurrency=1 test/calendar_interactions_regression_test.dart`: 11/11 passed.
- `flutter analyze --no-pub`: Clean (0 errors, 0 warnings).
- `git diff --check`: Clean (0 issues).
Updated [docs/AI_REVIEW_QUEUE.md](AI_REVIEW_QUEUE.md) with `PENDING_CODEX_REVIEW`.
No version bump, commit, release, or personal-profile access performed.

## Final CAL-01/CAL-03 independent review (2026-11-14)

[Final CAL-01/CAL-03 continuation receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md),
HEAD `053fa0f` plus dirty tree; manifest `A8DD9A84…0DBB1FB`. Logs under
`.buildlog/calendar-final-review/`: pre-fix 01 four failures ->03 four passes;
05 four gesture failures ->07 four passes; 09 extension-load/cancel failures;
11 47 pass/6 over-broad safety-guard failures ->13 **79 pass**. New month-window
history 14 two failures ->16 four passes, 17 five history/error passes. Choice
lifecycle 21/23 one pass each; narrow arena 24 failure ->26 13 passes; cancel
scroll 27 failure ->29 two passes; final gestures30 **15 pass**. Final projection32
**7 pass**; targeted MCP analyses clear. Prior passing boundaries reused rather
than summing repeated assertions. Actual isolated Debug paging/scope/save/native
Undo/Redo and independent SQLite readback pass; Driver timeouts retained and one
lower-frequency attempt succeeded. Final reload/restart/diagnostics clear.
No unrelated full suite, Release/Android rebuild, live Drive or publication.
CAL-03 archived approved; CAL-01 still pending protected exception-aware movement.
Receipt owns exact commands, rerun reasons, source identities, limitations and
final documentation checks.

## CAL-03: Off-Viewport Multi-Day Calendar Resizing Completion (2026-11-14)

Baseline `053fa0f` + reviewed working tree, branch `codex/independent-beta-review`.
Sequential execution on Windows 11 host with in-memory SQLite and `--no-pub --concurrency=1`:
- `flutter test --no-pub --concurrency=1 test/calendar_multi_day_resize_test.dart`: 9/9 passed:
  1. Example A: Extend event bottom handle across midnight into next day (Monday 8 PM to Tuesday 3 AM).
  2. Example B: Extend event across multiple days (Monday 9 AM to Thursday 2 PM).
  3. Example C: Resize top handle backward into previous day (Wednesday 10 AM to Tuesday 6 PM).
  4. Minimum duration constraint prevents zero or inverted duration when dragging.
  5. Scenario A: Forward resize beyond visible week boundary (Sunday 8 PM to Tuesday 3 AM next week) with navigation preservation.
  6. Scenario B: Backward resize beyond visible week boundary (Monday 10 AM to Saturday 6 PM previous week) with navigation preservation.
  7. Scenario C: Day view extension past midnight into next day (Monday 8 PM to Tuesday 3 AM) without clamping.
  8. Scenario D: Multi-week several-day event extension.
  9. Scenario E: Cancellation after crossing boundary leaves state completely clean.
- `flutter test --no-pub --concurrency=1 test/calendar_event_move_recurrence_test.dart`: 12/12 passed (CAL-01 suite).
- `flutter test --no-pub --concurrency=1 test/calendar_independent_review_test.dart`: 16/16 passed (Codex review suite).
- `flutter test --no-pub --concurrency=1 test/calendar_interactions_regression_test.dart`: 11/11 passed (Regression suite).
- `flutter analyze --no-pub`: No issues found (0 errors, 0 warnings, 0 infos).
- `git diff --check`: 0 issues found.
Review queue entry updated in [docs/AI_REVIEW_QUEUE.md](AI_REVIEW_QUEUE.md) with `PENDING_CODEX_REVIEW`.
No version bump, commit, release, or personal-profile access performed.

## CAL-01: Recurring Event Movement Completion (2026-11-14)

Baseline `053fa0f` + reviewed working tree, branch `codex/independent-beta-review`.
Sequential execution on Windows 11 host with in-memory SQLite and `--no-pub --concurrency=1`:
- `flutter test --no-pub --concurrency=1 test/calendar_event_move_recurrence_test.dart`: 12/12 passed:
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
- `flutter test --no-pub --concurrency=1 test/calendar_independent_review_test.dart`: 16/16 passed.
- `flutter test --no-pub --concurrency=1 test/calendar_interactions_regression_test.dart`: 11/11 passed.
- `flutter analyze --no-pub`: No issues found (0 errors, 0 warnings, 0 infos).
- `git diff --check`: 0 issues found.
Review queue entry updated in [docs/AI_REVIEW_QUEUE.md](AI_REVIEW_QUEUE.md) with `PENDING_CODEX_REVIEW`.
No version bump, commit, release, or personal-profile access performed.

## Independent calendar/UI review (2026-11-14)

[Invocation/reuse receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md), `053fa0f` +
reviewed working tree, final SHA-256 manifest `9F801620…0F51108`. Pre-fix 01:
five reproduced failures; 03: 3 pass/2 diagnostic failures; 05: 52 pass/2 failures;
07: 71 pass/3 outdated accessibility timeout failures; 09: 69 pass/same 3 timeout
failures; 11: all three corrected assertions pass. No unresolved executed test
failure. 09/11 plus two new pointer cases in 16 establish 74 final cases; reused independent 05/07 passes cover
unchanged recurrence/history/mode/sidebar/mobile boundaries. No repeated counts.
Targeted Dart MCP analysis No errors after registering missing root; one isolated
Windows Debug build/run, actual light/dark/zoom/sidebar inspection, successful
VM-service hot reload and two clean runtime-error reads. Native/Android Release,
full suite, real Sync, physical device/DPI/DST and publication gates not run.
CAL-01 and CAL-03 remain pending. See receipt for every command, failure, rerun reason,
format/diff checks, exact final source identity and actual coverage limits.

## Gemini-reported calendar/UI evidence (2026-11-14)

Reported baseline `053fa0f`; final raw logs/source fingerprints were not identified.
Independent results supersede these summary claims above. Reported sequential execution on 16GB host with `--concurrency=1`.
- **CAL-01: Calendar Event Move Recurrence**:
  - `flutter test test/calendar_event_move_recurrence_test.dart`: 1/1 passed. (Confirmed pre-fix exception reproduction `ArgumentError: The first planned day must be selected` and post-fix pass).
- **UX-01: Notification Auto-Dismissal**:
  - `flutter test test/notification_auto_dismiss_test.dart`: 3/3 passed. (Verified 3s/4s/5s/7s durations, `persist: false`, and settled dismissals).
- **CAL-02: Event Card Contrast & Readability**:
  - `flutter test test/calendar_card_contrast_test.dart`: 3/3 passed. (Verified WCAG >= 4.5:1 on secondary text and >= 5.0:1 on titles).
- **CAL-03: Multi-Day Event Resizing**:
  - `flutter test test/calendar_multi_day_resize_test.dart`: 4/4 passed. (Verified Examples A, B, C, undo/redo, and min duration constraint).
- **CAL-04: Calendar Zoom & Mode Transition Animations**:
  - `flutter test test/calendar_zoom_animation_test.dart`: 3/3 passed. (Verified 200ms `Curves.easeOutCubic`, reduced-motion duration zero, and cross-fade).
- **UI-01: Sidebar Bottom Scroll Shadow**:
  - `flutter test test/scroll_edge_fade_test.dart`: 3/3 passed. (Verified dark/light overflow hints and custom `topFadeColor`/`bottomFadeColor` gradient decoration).
- **Regression Suites**:
  - `flutter test test/calendar_interactions_regression_test.dart`: 11/11 passed.
  - `flutter test test/calendar_undo_redo_shortcuts_test.dart`: 8/8 passed.
- **Static Analysis & Git Hygiene**:
  - `flutter analyze --no-pub`: 0 issues found.
  - `git diff --check`: 0 issues found.
- Detailed queue maintained in [docs/AI_REVIEW_QUEUE.md](AI_REVIEW_QUEUE.md) (`PENDING_CODEX_REVIEW`).

## Independent Beta 17/18 review (2026-11-14)

[Review and invocation receipt](INDEPENDENT_REVIEW_2026_11_14.md). Baseline
`a1ac5a5`; new boundary assertions first run against unpatched application code.
See the receipt for executions, fingerprints, evidence reuse and release gates.
Final source `375729e`: calendar 50 passes; unchanged shared controller/mobile/
draft/CAS coverage reused from 58 passes; Sandbox fixtures 6 passes; isolated
profile journeys 15 passes. Exact-source Windows CI: 893 passed, 9 opt-in skips;
Android host/on-device and exact signed APK 16 KiB upgrade runtime passed.
Portable first closure timed out; instrumented positive and original rollback
checks passed. Failures and their rerun reasons remain in the receipt.
[Beta 19 publication and acceptance limits](TODORBIT_BETA_19_PUBLICATION.md).

## Beta 18 Release Preparation and Verification (2026-11-13)

Branch `fix/calendar-interaction-regressions` (Schema 28, Version `1.0.19-beta.18+41`, Android versionCode 41).
Prepared and verified experimental Beta 18 local release packages across Windows x64 and Android:
- **Calendar Keyboard Shortcuts Restored**:
  - Acquired and retained focus on `_calendarFocusNode` across initial mount, post-interaction commit, and pointer down events within the calendar layout area.
  - Implemented modal route guard (`ModalRoute.of(context)?.isCurrent == true`) preventing pointer focus stealing when dialogs, popups, or menus are displayed.
  - Verified `EditableText` isolation in `onKeyEvent` so active text inputs retain native platform undo/redo and bypass calendar undo.
- **Notification Auto-Dismissal**:
  - Explicitly passed `persist: false` to `SnackBar` in `_showCalendarNotification` and sync announcement in `_SyncStatusButtonState`, fixing Flutter 3.24+ `persist` default when action buttons are present.
  - Edit notifications automatically dismiss after 4 seconds; sync announcements dismiss after 8 seconds; undo actions remain fully functional prior to timeout.
- **Test-Safe Midnight Rollover Scheduler**:
  - Added `@visibleForTesting static bool enableMidnightTimerInTests = false;` in `AppController` so widget/unit test suites bypass unmocked pending midnight timers by default, while preserving production midnight rollover at 00:00:01 local time.
- **Packaging Receipts & Checksums**:
  - Windows Setup: `Todorbit-1.0.19-beta.18-win-x64-setup.exe` (47,730,037 bytes)
    - SHA-256: `0fbdc50e92d67fce58ef3c22be91cfb5ed1199eac9d9658cf3ea1fbfd11cd9c9`
    - Inno Setup 7.1.0 compiler, numeric `VersionInfoVersion=1.0.19.41`, display `AppVersion=1.0.19-beta.18`.
    - Bundled with Microsoft Visual C++ runtime DLLs (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, `sqlite3.dll`).
  - Windows Portable: `Todorbit-1.0.19-beta.18-win-x64-portable.zip` (63,159,750 bytes)
    - SHA-256: `3698162969fe553c8eb2fc102e787269affaa9398b15fca9e02e8fa8b8db24ed`
    - Verified `Todorbit.exe` (`1.0.19-beta.18+41`) and `TodorbitWidget.exe` (FileVersion `1.0.19.41`, ProductVersion `1.0.19-beta.18+41`).
    - Validated native companion `--self-test` PASS.
  - Android Universal APK: `Todorbit-1.0.19-beta.18-android-universal.apk` (53,776,379 bytes)
    - SHA-256: `fc7702961ff74935c8cde741d79dda283e0d63e4e8a5d7f63a3667bb9d06e72a`
    - Verified package `io.github.hik4.todorbit`, versionCode 41, versionName `1.0.19-beta.18`, minSdk 26.
    - Verified production signature fingerprint: `00:22:6D:AD:75:AC:90:7A:C5:1C:86:DF:2C:50:11:F0:B6:E2:CE:82:91:99:41:03:97:5F:11:A8:EB:57:4A:99`.
    - Verified 16 KiB page alignment for 8 ELF native shared libraries across `arm64-v8a` and `x86_64`.
    - Verified `versionCode 41 > published_floor (40)`.
    - Manifest & sidecars: `Todorbit-1.0.19-beta.18-android-update.json`, `ANDROID-RELEASE-NOTES.md`, `ANDROID-SHA256SUMS.txt`, `Todorbit-1.0.19-beta.18-SHA256SUMS.txt`.
- Runs & Evidence:
  - `dart analyze lib test`: 0 issues found.
  - `flutter test test/calendar_undo_redo_shortcuts_test.dart test/calendar_interactions_regression_test.dart test/calendar_undo_redo_test.dart`: 30/30 passed.
  - `dotnet run --project experiments/widget-shell-probe -- --self-test`: PASS.
  - `powershell -File tools/test-windows-crt.ps1`: PASS.
  - `git diff --check`: PASS.

## Beta 17 Release Preparation and Verification (2026-11-13)

Branch `fix/calendar-interaction-regressions` (Schema 28, Version `1.0.19-beta.17+40`, Android versionCode 40).
Prepared and verified experimental Beta 17 local release packages across Windows x64 and Android:
- **Midnight Rollover Auto-Refresh (`AppController`)**:
  - Implemented `_scheduleMidnightTimer()` and `checkDateRollover()`: sets a single-shot timer targeting 00:00:01 local time.
  - Automatically invalidates `_cachedVisibleTasks` and `_cachedFilteredTasks` and calls `notifyListeners()`, causing Today views across desktop and mobile to rebuild with fresh day bounds without continuous polling or manual restart.
- **Android Acceptance Scope Boundary**:
  - Clarified and established testing scope: On Android, `lib/main.dart` mounts `MobileWorkspace`, not desktop `Workspace`/`TimelineGrid`.
  - Android acceptance comprises `MobileWorkspace` (navigation drawer, task list with overdue warning affordances, task detail sheet) and `MobileCalendar` (month grid, agenda list, event detail view).
  - Desktop multi-lane timeline dragging, resize edge handles, and desktop keyboard shortcuts (`Ctrl+S`, `Ctrl+Enter`, `Escape`) belong strictly to Windows verification.
- **Packaging Receipts & Checksums**:
  - Windows Setup: `Todorbit-1.0.19-beta.17-win-x64-setup.exe` (47,740,345 bytes)
    - SHA-256: `ca0b27e13270fe1f8de5797c43bfc74f0b2295cc3d33c51a5f576b5c2723889b`
    - Inno Setup 7.1.0 compiler, numeric `VersionInfoVersion=1.0.19.40`, display `AppVersion=1.0.19-beta.17`.
    - Bundled with Microsoft Visual C++ runtime DLLs (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, `sqlite3.dll`).
  - Windows Portable: `Todorbit-1.0.19-beta.17-win-x64-portable.zip` (63,158,969 bytes)
    - SHA-256: `430998c6562a090c0729be703415de43fc4a9dae3c8540954428a8e35b991879`
    - Verified `Todorbit.exe` (`1.0.19-beta.17+40`) and `TodorbitWidget.exe` (FileVersion `1.0.19.40`, ProductVersion `1.0.19-beta.17+40`).
    - Validated native companion `--self-test` PASS.
  - Android Universal APK: `Todorbit-1.0.19-beta.17-android-universal.apk` (53,776,379 bytes)
    - SHA-256: `07d97b9000ad96f475ac39a48d3ec6bd59650eb525190290fee213de8b875d16`
    - Verified package `io.github.hik4.todorbit`, versionCode 40, versionName `1.0.19-beta.17`, minSdk 26.
    - Verified production signature fingerprint: `00:22:6D:AD:75:AC:90:7A:C5:1C:86:DF:2C:50:11:F0:B6:E2:CE:82:91:99:41:03:97:5F:11:A8:EB:57:4A:99`.
    - Verified 16 KiB page alignment for 8 ELF native shared libraries across `arm64-v8a` and `x86_64`.
    - Verified `versionCode 40 > published_floor (39)`.
    - Manifest & sidecars: `Todorbit-1.0.19-beta.17-android-update.json`, `ANDROID-RELEASE-NOTES.md`, `ANDROID-SHA256SUMS.txt`.
- Runs & Evidence:
  - `test/workspace_test.dart` (15/15 PASS): Verified midnight rollover cache invalidation and notification trigger.
  - `dart analyze lib test`: 0 issues found.
  - `git diff --check`: 0 issues.
  - Status: Prepared locally for manual Windows and Android testing; zero push, zero tags, zero drafts published.

## Cross-Platform Settings, Sync and Recovery UX Verification (2026-11-13)

Branch `fix/calendar-interaction-regressions` (Schema 28). Resolves cross-platform user confusion around Google Drive Sync setup, Standard vs. Private Encrypted sync, and password/recovery entry:
- **Standard Sync Setup Clarity**: When Google Drive is connected but unpaired (`connected && !paired && !unlockRequired`), added a prominent `Standard Sync ready` informational status notice in `SyncSettingsPage` explaining that Standard Sync defaults to syncing through Google Drive with zero extra passwords required, and directing users to "Encryption options" only if client-side encryption is desired.
- **Demystified Private Encrypted Sync Unlock & Google Password Distinction**: When an existing encrypted workspace is detected (`unlockRequired`), added an explicit `Encrypted cloud workspace detected` card in `SyncSettingsPage` clearly stating that an encrypted workspace was found in Google Drive and instructing users to enter the Private Sync passphrase created on their other device (or switch to their 24-character recovery code). Added explicit helper text on the input field: `Enter the passphrase from your other device (not your Google password).` and renamed label to `Private Sync passphrase` to eliminate confusion with Google account credentials.
- **Visual Hierarchy & Redundant Action Elimination**: Moved problem status notices (`StatusNotice`) above the unlock inputs, providing immediate context before credential entry. Prevented duplicate/confusing `OutlinedButton` ('Unlock sync') from rendering below the primary `FilledButton` ('Authorize this device').
- **Private Sync Setup Accessibility & Guidance**: In `SyncEncryptionSetupDialog`, renamed label to `Private Sync passphrase`, updated guidance to clarify that passphrases are local to Todorbit and not the Google password, and wrapped recovery codes in `Semantics(label: 'Recovery code: ...')`.
- **TaskEditor Defensive Concurrency Guard**: Added `if (saving) return;` at the entry of `_save()` in `task_editor.dart` to guard against asynchronous re-entrance.
Runs & Evidence:
- `test/sync_conflicts_dialog_test.dart` (35/35 PASS): Added new test asserting Standard Sync ready notice, Private Sync passphrase label, recovery toggle, and helper text guidance. All 34 prior conflict and dialog tests pass.
- `test/cloud/sync_standard_mode_test.dart` (5/5 PASS): Verified Standard workspace joining, pairing service invariants, and passphrase validation.
- `test/smart_sync_controller_test.dart` (8/8 PASS): All 8 multi-device sync, offline decision convergence, and conflict tests pass.
- `dart analyze lib test`: 0 issues found.
- `git diff --check`: 0 whitespace errors.

## Application-Wide UI/UX Improvements Batch 2 Verification (2026-11-12)

Branch `fix/calendar-interaction-regressions` (Schema 28). Implements high-impact usability, accessibility, keyboard navigation, and platform parity improvements across Windows desktop and Android:
- **Timeline Item Semantics Correction**: Added `excludeSemantics: true` and `onTap: () => widget.onItemTap(item)` to `Semantics` in `TimelineDayColumn` (`timeline_grid.dart`), eliminating duplicate screen-reader announcements (outer label vs inner text nodes) and enabling direct assistive touch/click activation.
- **Desktop Task Editor Keyboard Shortcuts**: Wrapped `TaskEditor` (`task_editor.dart`) in `CallbackShortcuts` supporting `Ctrl+S` and `Ctrl+Enter` to save changes immediately from anywhere in the editor without tabbing through fields. Added `Escape` shortcut to cancel/close the editor pane, respecting unsaved changes confirmation (`confirmLeave`). Added `Escape` shortcut in `workspace.dart` so deselecting/closing open task panes via keyboard functions globally.
- **Task Editor Tooltips & Accessibility**: Added discoverable tooltips (`Save changes (Ctrl+S, Ctrl+Enter)`, `Create task (Ctrl+S, Ctrl+Enter)`) and enriched date button tooltips (`Change Scheduled day`, `Set Scheduled day`, `Change Deadline`, `Set Deadline`) with explicit semantic labels for screen readers.
- **Android Task List Overdue Highlighting & Visual Warning**: In `mobileTaskRow` (`mobile_workspace.dart`), added overdue detection (`isOverdue = t.isOpen && t.deadlineDate != null && t.deadlineDate!.compareTo(today) < 0`). Overdue tasks now render an amber warning icon (`Icons.warning_amber_rounded` with semantic label `Overdue`) in the trailing action bar, and display `'Overdue · Due [date]'` styled with `colorScheme.error` and `FontWeight.w600` in the subtitle, achieving visual parity with desktop urgency indicators.
Runs & Evidence:
- `test/calendar_interactions_regression_test.dart` (11/11 PASS): Scenario K verified with `excludeSemantics == true` and semantic `onTap` invocation.
- `test/mobile_workspace_test.dart` (23/23 PASS): Verified all existing mobile journeys plus new test asserting overdue tasks display the warning amber icon, semantic label, and error-colored subtitle on Android.
- `test/workspace_test.dart` (8/8 PASS): Verified all workspace tests plus new test confirming `Ctrl+S`, `Ctrl+Enter`, `Escape`, and date-row tooltips in `TaskEditor`.
- `dart analyze lib test`: 0 issues found.
- `git diff --check`: 0 whitespace errors.

## Cross-Platform UI/UX Refinement Batch 1 Verification (2026-11-12)

Branch `fix/calendar-interaction-regressions` (Schema 28). Implements high-impact usability, accessibility, and visual affordance improvements across Windows desktop and Android:
- **Timeline Item Semantics**: Wrapped placed timeline cards in `Semantics(label: ...)` exposing item title, start/end time range, alarm indicator, and overlap conflict count to screen readers (Narrator on Windows, TalkBack on Android).
- **Current-Time Indicator Tooltip Fix**: Corrected widget tree hierarchy in `_buildCurrentTimeLine` (`timeline_grid.dart`) so the time badge's tooltip is interactable on hover while the horizontal line remains click-through via `IgnorePointer`.
- **Resize Handle Affordance Tooltips**: Added discoverable tooltips (`Drag to adjust start time`, `Drag to adjust end time`) with 500ms hover delay to top and bottom edge handles in `timeline_grid.dart`.
- **Rich Month View Card Tooltips**: Updated `CalendarMonthView` (`calendar_month_view.dart`) to format full time ranges, parent project context, and details in tooltips across month cells.
- **Polished Mobile Calendar Empty State**: Replaced unstyled debug text in `MobileCalendar` (`mobile_calendar.dart`) with a centered, structured empty state featuring `event_available_outlined` icon, primary title, and tokenized secondary guidance.
Runs & Evidence:
- `test/calendar_interactions_regression_test.dart` (11/11 PASS): Scenarios A through J pass; new Scenario K verifies timeline item semantics, current-time tooltip hoverability, resize handle tooltips, and rich month view card tooltips.
  *(Note on historical attribution: Scenario K was introduced in this batch via commit `190516c`, expanding the regression suite from 10 to 11 tests. Prior commit `efe02b8` strictly verified 10/10 scenarios A through J).*
- `test/calendar_undo_redo_test.dart` (11/11 PASS reused).
- `dart analyze lib/features/calendar lib/features/mobile test/calendar_interactions_regression_test.dart`: 0 issues found.
- `git diff --check`: 0 whitespace errors.

## Urgent Calendar Event Duration Invariant Verification (2026-11-11)

Branch `fix/calendar-interaction-regressions` (Schema 28). Resolves P0 data truncation defect where Day/Week calendar move operations erroneously applied day-column visual bounds (`maxEnd = 23:59`) to domain event persistence, truncating events > 24 hours to at most 23h59m and shifting overnight events backward:
- **Root Cause & Fix**: Removed `finalEnd.isAfter(maxEnd)` clamping from `CalendarInteractionController.updatePointer` during `CalendarGestureKind.move`. Established domain invariant: `finalEnd = finalStart.add(originalDuration)`. Display clipping is handled by layout rendering (`CalendarLayoutEngine`); persisted duration is strictly invariant.
- **Auto-scroll & Cancellation Hygiene Intact**: Retained top auto-scroll tolerance (-10px) and complete gesture cancellation handlers (`onPanCancel`, `onVerticalDragCancel`).
Runs & Evidence:
- `test/calendar_interactions_regression_test.dart` (10/10 PASS):
  *(Note on historical attribution: Exact checkout verified 10/10 scenarios A through J; Scenario K was introduced subsequently in commit `190516c`).*
  - Scenario I replaced with comprehensive duration-preservation suite:
    1. Normal same-day event move (90 min duration preserved and persisted).
    2. Overnight event move (6 hours across midnight, 23:00 to 05:00 next day preserved and persisted without backward shift).
    3. Event lasting over 24 hours (26 hours duration preserved and persisted).
    4. 48-hour event move (48 hours duration preserved and persisted).
    5. Cross-day Week move (preserves 48-hour duration on target day column).
    6. Undo/Redo of multi-day event move (restores original 48h range and reapplies).
    7. Recurring occurrence move (preserves duration, updates single occurrence exception).
    8. Cancellation without database writes (clean reset, no draft committed).
    9. ResizeEnd within column still clamps to maxEnd (23:59).
  - Scenario J: Top auto-scroll buffer and cancellation resets state (PASS).
- `test/calendar_undo_redo_test.dart` (11/11 PASS): All history, text focus, and task deadline tests pass.
- `test/calendar_interaction_controller_test.dart` (4/4 PASS): Unit calculations for move, resizeTop, resizeBottom, and cancel pass.
- `dart analyze lib/features/calendar test/calendar_interactions_regression_test.dart`: 0 issues found.
- `git diff --check`: 0 whitespace errors.

## Calendar Boundary Clamping & Auto-Scroll Cancellation Verification (2026-11-11)

Branch `fix/calendar-interaction-regressions`, commit `4fd635b` (Schema 28). Hardens interactive calendar boundary handling, top-edge auto-scroll gesture tolerance, gesture cancellation lifecycle hygiene, and verifies domain alarm preservation invariants:
- **CAL-01 Invariant Verified**: `timeline_grid.dart` auto-scroll timer runs at 30ms interval with 12px speed (~400px/s velocity); provides smooth, responsive timeline scrolling without timer starvation or CPU thrashing on 60Hz/120Hz displays. Preserved intentional code.
- **CAL-02 Resolved**: Multi-day and long events exceeding the viewport now clamp with `minStart` (00:00) lower bound so dragging long events cannot push start dates into the previous day. Added `maxEnd` (23:59) upper-bound clamping to `resizeBottom` to prevent drag expansion past day bounds.
- **CAL-03 Resolved**: Top-edge auto-scroll tolerance expanded to `-10px` (`viewportY >= -10 && viewportY < margin`), preventing auto-scroll freeze when cursor drifts slightly into the column header area.
- **Gesture Lifecycle Hygiene**: Added `onPanCancel` and `onVerticalDragCancel` (top/bottom resize handles) to cancel `_autoScrollTimer`, clear pointer tracking, and invoke `interactionController.cancel()`, preventing orphaned periodic timers.
- **DATA-01 Invariant Verified**: In `CalendarInteractionController.dart`, `draft.alarm == null` is Todorbit's established repository convention for "preserve existing alarm rule without modification" (enforced by `AlarmRepository.replaceTaskAlarm`). Dynamic alarms continue to be recomputed by `AlarmPlanner` against the updated `scheduled_date`. Retained invariant.
Runs & Evidence:
- `test/calendar_interactions_regression_test.dart` (10/10 PASS): Scenarios A through H re-verified; Scenario I (boundary and resizeEnd clamping) and Scenario J (top-edge auto-scroll overshoot buffer and cancellation cleanup) pass.
- `test/calendar_undo_redo_test.dart` (11/11 PASS): Full LIFO history, text field isolation, and occurrence preservation pass.
- `dart analyze lib/features/calendar test/calendar_interactions_regression_test.dart`: 0 issues found.
- `git diff --check`: 0 whitespace errors.

## Calendar Interaction & UI Regression Verification (2026-11-11)

Branch `fix/calendar-interaction-regressions`, commit `82552a0` (tag `v1.0.19-beta.16`, build 39, Schema 28). Resolves 10 Beta 15 manual testing defects across viewport drag auto-scrolling, cross-day Week drag & drop, reactive toolbar Undo/Redo, compact floating notifications, Month card hitboxes with mobile touch protection, Ctrl+wheel zoom isolation, comfortable month density, unified toolbar pill, current-time indicator, and 32x32 native Windows widget navigation.
Runs & Evidence:
- `test/calendar_interactions_regression_test.dart` (8/8 PASS):
  1. A: Dragging Day-view event does NOT cause unexpected scrolling (viewport-relative distance with 48px margin).
  2. B: Edge resizing updates startsAt or endsAt accurately (top-edge start time and bottom-edge end time).
  3. C: Cross-day move in Week view commits to target day and supports Undo/Redo.
  4. D: Month view card drag hitboxes work at 10%, 25%, 50%, 75%, and 90% of card width (`HitTestBehavior.opaque`).
  5. E: Ctrl + Mouse Wheel zoom switches modes without scrolling timeline (`CalendarScrollPhysics`).
  6. F: Toolbar Undo/Redo buttons react dynamically to history changes (`ListenableBuilder`).
  7. G: Month view card readability dimensions match comfortable density (28-34px cards, 90px min cell, `ClampingScrollPhysics`).
  8. H: Android Month-view uses `LongPressDraggable` (250ms delay, haptic feedback) so touch scrolling does not conflict with dragging.
- `test/calendar_undo_redo_test.dart` (11/11 PASS reused from `ee55cb6`): LIFO undo/redo, text focus bypass, task deadline preservation, occurrence isolation.
- `test/interactive_calendar_redesign_test.dart` (5/5 PASS reused from `4f77010`): Day/Week/Month navigation, shortcuts, right-click actions, legacy fallback switch.
- `experiments/widget-shell-probe`: `dotnet run --project experiments/widget-shell-probe -- --self-test` (PASS, verified 32x32 hit bounds, `DrawCalendarArrow`, Fluent hover/pressed accents).
- Code Analysis: `dart analyze` reports 0 issues.
- Artifacts & Hashes: Verified in [TODORBIT_BETA_16_PUBLICATION.md](TODORBIT_BETA_16_PUBLICATION.md); Windows Inno Setup installer, portable ZIP, and production-signed Android universal APK (`db477a597fe1...`).
- Limits & Unverified: Physical Windows multi-monitor fractional DPI scaling and physical Android TalkBack/OEM gestures remain manual acceptance gates. Production Android UI exposes `MobileCalendar`, not `CalendarView`; mobile `CalendarMonthView` behavior is verified via widget tests with injected `TargetPlatform.android`.

## Calendar Undo & Redo Integration Verification (2026-11-11)

Feature branch `feature/interactive-calendar`. Complete Undo and Redo support for interactive calendar gestures and month drag & drop, with optimistic concurrency control, recurring occurrence isolation, task deadline preservation, editable text focus bypass, toolbar buttons, and reversible SnackBar actions.
Runs:
- `test/calendar_undo_redo_test.dart` (11/11 PASS):
  1. Move FixedEvent -> Undo -> Redo restores and reapplies exact startsAt/endsAt times.
  2. Resize top edge (startsAt) -> Undo -> Redo updates start time while fixing end time.
  3. Resize bottom edge (endsAt) -> Undo -> Redo on WorkSession.
  4. Month date drag & drop of task preserves deadlineDate across Undo & Redo while moving scheduledDate.
  5. Month date drag & drop of event preserves clock time across Undo & Redo.
  6. Multiple consecutive operations work in correct LIFO order across events and sessions.
  7. New edit after Undo cleanly invalidates and clears Redo history (`canRedo == false`, `redoCount == 0`).
  8. Cancelled gestures and no-op drops create zero history entries.
  9. Recurring occurrence Undo/Redo updates single occurrence without altering parent series recurrence rule or other occurrences.
  10. `SettingsHistoryScope` handles Ctrl+Z, Ctrl+Shift+Z, and Ctrl+Y when outside text fields.
  11. `SettingsHistoryScope` ignores calendar undo/redo shortcuts when an `EditableText` (TextField) is focused, retaining platform native text undo/redo.
- `test/calendar_safety_and_persistence_test.dart` (3/3 PASS): scheduled task deadline preservation, work session deadline preservation, recurring occurrence isolation.
- `test/calendar_eval_visual_verification_test.dart` (5/5 PASS): Day/Week/Month views, legacy preview switch, compact mobile rendering.
- `test/calendar_interaction_controller_test.dart` (4/4 PASS): drag move, resizeTop, resizeBottom, cancel/state reset.
- `test/interactive_calendar_redesign_test.dart` (5/5 PASS): Day/Week/Month navigation, shortcuts, right-click actions, legacy fallback.
- `dart analyze lib/features/calendar` (0 issues found).

## Interactive Calendar Redesign & Evaluation (2026-11-10)

Feature branch `feature/interactive-calendar`. Accurate vertical time-grid layout, side-by-side local collision lane allocation, drag-to-move, top/bottom edge resizing, cross-day Week dragging, Month date-drag with clock-time preservation, date-anchored zoom (Ctrl+wheel), shortcuts (Ctrl+1/2/3, T, Ctrl+Z, Esc), and reversible legacy preview toggle.
Runs:
- `test/calendar_safety_and_persistence_test.dart` (3/3 PASS): dragging scheduled tasks preserves deadline dates; dragging work sessions preserves parent task deadlines; moving/editing recurring event occurrences creates isolated single-occurrence exceptions via updateEventOccurrence without shifting parent recurrence rule or other occurrences in the series; undo reverses accurately.
- `test/calendar_eval_visual_verification_test.dart` (5/5 PASS): Day view time grid and 3-lane collision layout, Week view 7-column alignment, Month view grid, legacy presentation switch toggle, and mobile portrait (412x892) viewport rendering with ultra-compact collision protection.
- `test/calendar_layout_engine_test.dart` (8/8 PASS): coordinate conversions, snapping, touching endpoints, nested/dense collisions, minimum readable height.
- `test/calendar_interaction_controller_test.dart` (4/4 PASS): drag move, top-edge resize start, bottom-edge resize end, cancel/undo.
- `test/calendar_zoom_controller_test.dart` (5/5 PASS): view transitions (Month ↔ Week ↔ Day), wheel accumulation, week & month cursor anchor resolution.
- `test/interactive_calendar_redesign_test.dart` (5/5 PASS): day view timed placement, all-day & planned header, month right-click context menu (Show Day/Week), keyboard shortcuts, legacy fallback switch.
- `test/calendar_improvements_test.dart` (7/7 PASS): navigation persistence, month capacity, weekday headers.
- `test/calendar_test.dart` (3/3 PASS): conflict indicators, content filtering, event creation.
- `test/round3_calendar_test.dart` (8/8 PASS): subtasks, cancelled events, month preview, right-click creation.
- `test/event_recurrence_test.dart` (7/7 PASS): recurrence safety, occurrence vs series invariants.
- `test/cancelled_event_readability_test.dart` & `test/event_editor_layout_test.dart` (5/5 PASS): contrast and dialog layouts.
- `test/hotkeys_test.dart` (3/3 PASS): shortcut binding validation.
- `dart analyze lib/features/calendar test/...` (0 issues).
- Windows debug binary built at `build/windows/x64/runner/Debug/Todorbit.exe`. Verified in isolated disposable profile `%TEMP%\todorbit-calendar-eval` with representative synthetic database.
- Android debug APK built at `build/app/outputs/flutter-apk/app-github-debug.apk`. Verified with `python tools/verify-android-artifact.py` (7 native libraries pass ELF and APK ZIP alignment).
- Confirmed blocker fix: narrow-column cards (<44px width) in dense mobile collisions now render clean pill representation with tooltips and clipping, eliminating RenderFlex horizontal overflows.

## Alarm beta14 (2026-11-08)

[Compact checkpoint](ALARM_BETA_2026_11_08.md). New owner/config/planner/UI,
schema27 journal preservation, captured/applied new rule Standard/Private local
exchange, backup round-trip and native sound/snooze state boundaries. Logs under
.buildlog/alarms-beta-20261108; numbered failure/closure receipts retained.
Unchanged real Sync/recovery/beta13 installer/signed-APK evidence reused.
No full local suite or new cloud exchange. Final candidate CI/build/runtime open.

## Beta13 release verification (2026-11-07)

See [continuation receipt](FINAL_STABILIZATION_2026_11_07.md#beta13-release-verification-continuation-2026-11-07).
Exact artifact/source hashes reused; no builds/full suites/Sync matrices. New
config-fixture gate: initial failure then18 passes after fixture correction.
New background-schema helper:2 passes; exact installed guest worker barriers PASS.
Offline genuine Beta12-to13 installer/migration/uninstall/reinstall PASS. Signed
APK core/restart/native widgets PASS in separate clean API35 x64; protection041
unchanged. See result039; no rebuild/real Sync repeated.

## Beta13 stabilization follow-up (2026-11-07)

[Single receipt/inventory](FINAL_STABILIZATION_2026_11_07.md); detailed exact
commands, times/offsets, hashes, failures and closures in external evidence001-045.
New: isolated live wrong-code/unlock, GUI restore/reconciliation/decision readback,
automatic profile restart UI/startup, motion on/off and synthetic render captures;
final current analysis, packages/signing/alignment/versions and bounded native UI.
Reuse: real Standard and scoped Private43-table round trips, unchanged protocol/
crypto/retry/schema/native behavior, plus exact native self-test binary by hash.
No full Flutter suite, fresh workspace, cloud snapshot or publication. Failed
fixture settling/account omissions/frame-boundary assertions and corrected narrow
reruns remain recorded, including intermediate build supersession reasons.

## Final stabilization (2026-11-07)

[Current receipt](FINAL_STABILIZATION_2026_11_07.md). New checks 001, 005, 007, 008 and 009; exact logs/hashes outside Git. Reused Standard/Private matrices; GUI restore and final beta artifacts pending. Recovery app and emulator closed; recovery approval held.

Consult this index **before every test** with [Testing](TESTING.md#verification-ledger).
Keep existing detailed task receipts authoritative; add one linked receipt per
task, rather than another testing framework or copied historical outputs. Every
execution/failure/rerun and meaningful reuse/skip belongs in its receipt, including
timestamp/offset, source identity, command, scope, purpose, result and necessity.
Reuse requires unchanged relevant source, assertions, dependencies, configuration
and equivalent environment. A commit alone does not identify a dirty tree; use a
small manifest of SHA-256 hashes for the affected files, or a patch hash.

| Date / task | Source / scope | Receipt and reuse limits |
| --- | --- | --- |
| 2026-11-13, Prompt 10 Final Verification & Readiness | Commit `1b4c4ed`, branch `fix/calendar-interaction-regressions`; cache immutability, date rollover, task setter invalidation, TaskEditor composition/plans, benchmark profiling | Targeted sequential suite (16GB RAM limit, concurrency 1): 14/14 tests pass in `test/workspace_test.dart` (including new unmodifiable cache protection, tasks setter invalidation, and filteredTasks caching tests); 2/2 tests pass in `test/task_composition_widget_test.dart`; 1/1 tests pass in `test/progressive_plan_widget_test.dart`; benchmark profile measured 6.7x speedup on 500 tasks / 1000 queries (219.60 us down to 32.93 us); `dart analyze lib test` reports 0 issues; `git diff --check` clean. Prior duration invariant, sync recovery, and schema 28 passes reused under unchanged boundary rules. |
| 2026-11-13, Prompt 9 Engineering Quality & Performance | Branch `fix/calendar-interaction-regressions`; scoped `AppController` cache memoization and `TaskEditor` modular validation/preparation | Targeted sequential suite (16GB RAM limit, concurrency 1): 11/11 tests pass in `test/workspace_test.dart` (including new prerequisite conflict detection and memoization test groups); 14/14 tests pass in `test/workspace_draft_safety_test.dart`; 8/8 tests pass in `test/repository_test.dart`; 1/1 tests pass in `test/task_view_preferences_test.dart`; 2/2 tests pass in `test/advanced_search_widget_test.dart`; `dart analyze lib test` reports 0 issues; `git diff --check` passes cleanly. Prior calendar and sync passes reused under unchanged boundary rules. |
| 2026-11-07, Private cross-platform scoped closure | Same verified candidate/APK/source; corrected pinned Private scope | [REAL43-table/28-op/4-encrypted-batch round trip and retained-key restart PASS; OFFLINE actual-proof recovery/negative/backup key checks PASS](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#scoped-private-acceptance-outcome-2026-11-07). Native fixture/inspection timing failures retained, no full Standard matrix/build/suite repeat; live key-loss/GUI restore and CI remain unverified. |
| 2026-11-07, Android Private account/preflight | Same user10/PID/APK and corrected private workspace | [Stable ID match, actual Android read-only3-object metadata match, supported private unlock discovery](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#android-accountprivate-preflight-pass-unlock-required). No exchange/build/restart/repeated sign-in; two inspector corrections retained in receipt058, prior cipher proof reused. |
| 2026-11-07, real Private Windows / Android readiness | Existing corrected candidate/APK, unchanged product source | [Real proof/key-retention/ciphertext/rich fixture and exact bytes PASS; Android isolated native/DB ready at Google sign-in](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#real-windows-private-pass-android-authorization-boundary-2026-11-07). Readback verifier wrapper failure retained, corrected offline only; Standard/native/crypto evidence reused, no full suite/rebuild/repeated cloud download. |
| 2026-11-07, Private activation diagnosis | Current product format code in offline Windows Dart AOT; synthetic keys only | [AOT crypto PASS, wrong local UUID namespace confirmed, metadata corrected and workspace-only check PASS](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#p2-activation-failure-diagnosed-test-approval-namespace). No application build/Google request/full suite; crypto pass reused after correction. |
| 2026-11-07, Private recovery-code copy control | Two scoped UI/test files; hashes/argv in external020/021 | [Targeted analysis and3 copy/light/dark/privacy assertions PASS; one affected Windows build and isolated restart](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#recovery-code-copy-control-and-fresh-setup-2026-11-07). Mocked synthetic clipboard; no chat-secret reuse/cloud request/full suite/Android rebuild. |
| 2026-11-07, Private P1 / Windows account switch | Same signed-in isolated profile; two scoped UI/test files | [Distinct account, real read-only empty Sync preflight, unchanged Sync tables; desktop switch UI/auth pinning focused passes](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#p1-resolved-and-windows-account-switch-fix-2026-11-07). Fixture codepage failure/correction retained; affected Windows build only, no Android/full suite/Standard matrix repeat. |
| 2026-11-07, Private P1 identity gate | Same tested/built guard and isolated candidate | [BLOCKED: new account receipt matches Standard; zero Google requests; production18/protected3 match](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#p1-identity-stop-2026-11-07-1058-utc03). Reuse completed tests/build; manual selection of different spare account required. |
| 2026-11-07, Private acceptance P0 | `87e976f` + five scoped guard/test hashes; new Windows AOT, unchanged Android APK | [Six focused tests/analysis/build PASS, isolated live DPAPI/schema/path probe, secondary Android user, unchanged production/Standard hashes; sign-in boundary](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md). Prior crypto/native/Standard evidence reused; no Private cloud exchange or full suite. |
| 2026-11-07, Private Sync preparation only | `87e976f`; no implementation/config changes | [Source continuity, evidence reuse, profile/approval blockers and resumable gates](PRIVATE_SYNC_ACCEPTANCE_PLAN_2026_11_07.md). Documentation checks only; no tests/builds/launches or Google calls. No real Private acceptance claimed. |
| 2026-11-07, repository safety checkpoint | `e6a95ca`, `3e2e0e5`; unchanged verified source and artifacts | [Hash comparison, artifact continuity, staging/credential exclusion and local commit receipt](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#local-repository-checkpoint-2026-11-07). Existing tests/build/real-service passes reused; none rerun. Protected three docs excluded. |
| 2026-11-06/07, real Windows/Android Standard acceptance | `4dcda12` plus recorded dirty-source hashes, now secured in local implementation commits | [Final scoped PASS:383 operations/43 tables, corrected real restore, repeat checks and restart](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03). Historical failures/limits preserved; both corrected private artifacts verified. Physical/platform, Windows GUI restore and CI remain separate. |
| 2026-11-06, Android account / read-only Standard preflight | Same running emulator37.2.13/API35 and exact APK; unchanged app source | [Live account match, auth-only reconnect, REAL Android paginated Sync metadata GET:11 exact Windows object matches, unchanged proof/protocol2, private DB/WAL unchanged and18 production hashes preserved](ANDROID_DRIVE_READINESS_2026_11_06.md). External VM CastMap reader first misparsed empty metadata; failed log/source retained, backing-map correction and one justified read-only rerun pass. No Android pairing/exchange/writes/payload download, app rebuild, suite repeat or account interaction needed. Owner exchange authorization pending. |
| 2026-11-06, Android emulator/authentication readiness | Exact retained registered APK `01192d13…`, no app source change; retained Play API35 AVD; isolated official emulator37.2.13 replaces35.3.11 only for this trial | [Old native failures, offline userdata preservation, stable-component trial, retained Messaging boot ANR warning, native UI/storage/stage/install, schema27/private VM verification and owner auth boundary](ANDROID_DRIVE_READINESS_2026_11_06.md). Strict zero-historical-ANR gate remains false; bounded post-startup critical functions pass beyond15min. Direct expression inspector lacked compiler; field-only inspection passes. No Android exchange/account/workspace pass yet, no rebuild/full suite or production writes. |
| 2026-11-06, authorized REAL Standard Windows/Drive acceptance | Existing private candidate/main/AOT and20-file source manifest unchanged; new spare-account real-cloud environment only | [Fresh scoped approval, actual upload/readback,43-table independent desktop reconstruction, edits/deletes/conflict resolution, injected reply loss after real commit, restore/reconcile/resync and repeated exchanges](REAL_STANDARD_SYNC_2026_11_06.md). Helper guard/compilation/revision-comparison failures retained with diagnoses and passing corrections. Final81 immutable facts/12 expected task IDs; production18 paths/startup and recovery hashes unchanged. No candidate rebuild/full suite/Android/Private Sync/commit/publication. |
| 2026-11-06, real account/read-only cloud preflight | Exact isolated private candidate hashes unchanged; owner-confirmed spare/receipt ID match | [Actual paginated Google appData Sync listing:0 objects; paths/DB and18 production hashes verified](PRIVATE_CREDENTIAL_ISOLATION_2026_11_06.md). No Standard approval/activation/upload. Existing tests/build reused; account identity basis and namespace limits explicit. |
| 2026-11-06, approved private Windows credential isolation | `4dcda12` + scoped source manifest; dedicated enabled/private AOT/main hashes | [Implementation, native concurrency/failed-write fixture, 5 private and22 normal cases, targeted analysis, one private build and live DPAPI/schema probes](PRIVATE_CREDENTIAL_ISOLATION_2026_11_06.md). Initial headless fixture/style failures retained; quiescent production hashes/startup unchanged. No Android/full suite/real Sync; owner authorization pending. |
| 2026-11-06, authorized real Standard Sync environment | `4dcda12`, unchanged app/native inputs; exact enabled Windows/registered Android hashes | [Latest same-account reevaluation and historical runtime receipt](STANDARD_DRIVE_ACCEPTANCE_2026_11_06.md). Logical DB/token/account selection separates correctly; shared credential-file writes remain unresolved. Verified read-only recovery copies of two local DBs/settings (integrity OK, zero FK violations), no credential export or personal-record tests. Auth-only backup route identified. No launch/build/full suite/real OAuth or cloud pass; prior AVD/setup evidence retained. |
| 2026-11-06, owner-approved enabled Windows private build | Exact source archive `d8abbec`; outside-Git derived config; private artifact SHA-256 identities | [Enabled candidate validation and account boundary](PRIVATE_DRIVE_ENABLED_BUILD_2026_11_06.md). New config-specific Release compile, CRT/config/AOT guards, packaged native self-test and setup/portable checks pass; symlink/Unicode runner diagnostics retained. No account/Drive access or redundant unrelated suite/build. Prior outputs unchanged. |
| 2026-11-06, real Drive OAuth/configuration audit | Application unchanged from `2262ede`; starting tree `8ef2d98`, changed build/config-tool hashes under `.buildlog/real-drive-acceptance-20261106/` | [OAuth audit, outside-config guard checks and A–L real-cloud blockers](REAL_DRIVE_ACCEPTANCE_2026_11_06.md). Initial 15 checks pass; malformed-JSON privacy probe fails, generic-error correction passes 16 checks. Retained bundle guard/parsing pass; prior exact-artifact/host evidence reused. Zero real Drive requests, no actual enabled build or device acceptance. |
| 2026-11-06, final private acceptance | Application `2262ede` / unchanged `f26f6b0` implementation; exact artifact SHA-256 comparison; focused acceptance-harness/backup assertions | [Private package identities, reused evidence, actual Sandbox installer/schema smoke, new focused checks and account boundary](PRIVATE_ACCEPTANCE_2026_11_06.md). No full Flutter rerun, real Google request or native Android/physical GUI pass. |
| 2026-11-05/06, Sync and cross-platform refinement | `501e748` through implementation `f26f6b0`, per-boundary/final SHA-256 manifests; schema 27, conflicts, editors, filters, navigation, widgets | [Implementation and invocation receipt](REFINEMENT_2026_11.md). Analysis, corrected targeted closures, platform builds, isolated startup/IPC and live Windows Debug pass. Reused full-suite assertions remain scoped; real Drive, physical platform and release gates remain open. |
| 2026-11-04, UI quality beta12 publication | Published source/tag `31a70d1`, beta12/build35, six committed UI batches since `c8f1561`; explicit owner instruction to skip further tests | [Publication receipt and deliberate skips](UI_QUALITY_BETA_12_PUBLICATION.md). No new app/analyzer/CI/device/manual test pass claimed; previous scoped evidence retained. Build/package/signature/hash and public delivery integrity recorded separately. |
| 2026-11-04, final platform acceptance continuation | `227ecf8` plus FPA source/protected-file fingerprints; existing W01-W11/N01-N08/A01-A12 plan | [Capability, invocation and reuse receipt](UI_UX_PERMANENT_QUALITY_AUDIT.md#final-platform-acceptance-continuation), [platform outcomes and human procedures](UI_UX_PLATFORM_ACCEPTANCE.md#final-acceptance-session-2026-11-04). Human dark/100% attachment sequence includes add/viewer/return/Save-reopen/cold/removal/original preservation, with read-only ID/hash corroboration. External-link journey and other variants remain open; no whole ID complete. |
| 2026-11-04, UI quality Batch 6 | `824332e` plus per-invocation patch/file hashes; isolated API35 environment diagnosis, Windows theme/widget settings and populated cross-profile transfer | [Batch 6 outcomes and invocations](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-6-platform-acceptance-and-theme-transfer). Three targeted cases pass; path/lifecycle/preview-feedback fixes, actual Windows cold restart. Native OS input/readers and Android app acceptance remain open; [reproducible manual checklist](UI_UX_PLATFORM_ACCEPTANCE.md). |
| 2026-11-04, UI quality Batch 5 | `ec43e8e` plus per-invocation SHA-256 manifests; Resources, Templates, actual startup recovery and selective settings transfer | [Batch 5 findings, invocations and limits](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-5-resources-templates-and-startup-recovery). Includes data-preservation reproductions, controlled native adapters, real disposable schema-1 upgrade/recovery entry points, Windows Debug readback and isolated runner. Android runtime and physical Windows pickers remain blocked. |
| 2026-11-04, UI quality Batch 4 | `8842598` plus per-invocation SHA-256 manifests; advanced productivity dialogs, startup layout and disposable local restore | [Batch 4 findings, coverage and invocations](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-4-advanced-productivity-and-local-recovery). Includes reproduced failures, fixture corrections, populated journeys, all-column restore comparisons and isolated Windows runtime. Backend evidence reused only after unchanged-boundary comparison; remaining acceptance is explicit. |
| 2026-11-04, UI quality Batch 3 | `7a5d0ed` plus per-invocation dirty-source SHA-256 manifests; advanced editors, populated Calendar/recovery and isolated Windows/API35 emulator | [Batch 3 findings, exact invocations and limits](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-3-populated-workflows-and-platform-acceptance). Includes failures/fixture corrections, focused passes, analyzer fallback, Debug build environment retry, native Back/rotation and restart persistence. Unchanged data/Sync/native/release evidence reused only within its original scope; full platform acceptance remains open. |
| 2026-11-04, permanent UI quality | Initial `25874c0` pass committed as `c32329c`; continuation UI diff and per-invocation fingerprints | [Audit, coverage and invocation receipt](UI_UX_PERMANENT_QUALITY_AUDIT.md#continuation-high-use-workflows-and-remaining-surfaces). Draft/navigation preservation, enlarged Calendar/forms/settings/scheduling/reports/focus; 40-group coverage update, failures/corrected fixtures, actual Windows Driver and reuse limits. Native/device/live-cloud acceptance remains open. No release gate implied. |
| 2026-11-04, Start New Sync / beta 11 | `c8f1561`; published beta11+34 generation/reset/error/UI | [Safety, failures, corrected builds and publication receipt](SYNC_START_NEW.md). Targeted checks and public integrity/updater gates pass; reuse/source/asset identities recorded. No broad suites, emulators or live Drive; physical acceptance unverified. |
| 2026-11-04, experimental optional Sync encryption beta 10 | `ed23095` (implementation `06b9ded`); published beta10+33 | [Release receipt](SMART_SYNC_BETA_10_PUBLICATION.md). Owner explicitly requires minimal checks; broad CI/emulator runs skipped, package/signature/integrity/public-updater gates retained. |
| 2026-11-04, local manual Sync builds | `06b9ded`; Windows Release + one production-signed GitHub APK | [Build inputs, outcomes and owner checklist](SYNC_MANUAL_BUILDS.md). Builds explicitly authorized for this task; reuse implementation tests. No live Google traffic or publication. |
| 2026-11-04, optional sync encryption | `13e2734` plus feature diff; codec, pairing, controller, provider error states, Settings | [Implementation and invocation receipt](SYNC_OPTIONAL_ENCRYPTION.md). Prior passes do not cover changed Sync behavior. No live Drive acceptance or builds authorized. |
| 2026-11-04, experimental beta 9 publication | Exact release source `a69dd63`; signed Android and Windows artifacts | [Publication receipt](SMART_SYNC_BETA_9_PUBLICATION.md). Unchanged backup/native/packaging boundaries retained as historical baseline, not current Sync acceptance. |
| 2026-11-03, comprehensive Smart Sync verification | Per-invocation source/artifact identities in receipt | [Verification ledger](SMART_SYNC_VERIFICATION.md). Full host/adapter/runtime results cannot be reused for altered protocol or UI; unchanged feature evidence may be reused after boundary comparison. |
| 2026-11-03, Smart Sync redesign | Per-invocation source identities and rerun causes | [Redesign ledger](SMART_SYNC_REDESIGN.md). Preserve failures and interrupted runs; do not add overlapping test counts. |

Older feature receipts remain discoverable from [Progress](PROGRESS.md). Add their
links when relevant; no repository-wide scan or historical migration is required.

Final closure for this task: external043/044/046 record the post-motion packages
and source/bundle identity;047/048-050 record bounded final source hot restart,
user-unlock readiness correction and graceful network/profile preservation.051
protects production/startup/keys/docs;052 analyzes the corrected final fixture;
053 proves native staged-source continuity. Native030 is reused by exact binary
hash after043. No further full suite, signing/build or real exchange is justified
by the final documentation-only checkpoint.
