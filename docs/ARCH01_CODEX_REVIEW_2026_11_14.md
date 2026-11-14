# Independent ARCH-01 review — 2026-11-14

**APPROVED AFTER REPAIRS.** Calendar contracts and legacy imports are compatible;
the root/month/zoom cycle is removed. Repairs are confined to the Python boundary
checker and its regression fixtures. No Dart behavior, persistence, recurrence,
gesture, native, version, licensing or release change was made by Codex.

Baseline and unchanged HEAD: `9cfdd0c619abffd94f3dacef1a794cede12ba9d2`, branch
`codex/independent-beta-review`. Review performed from 20:25
on 2026-11-14, UTC+03:00, Windows x64, Dart 3.13.5 / Flutter 3.47.7,
Python 3.14.5. CI targets Ubuntu/Python 3.13; actual GitHub execution is pending.
Nothing committed, staged, pushed, built for release or published. Unrelated
untracked storage documents and the modular architecture audit were preserved.

## Findings, repairs and compatibility

- Exactly one `CalendarMode` declaration remains, in `calendar_contracts.dart`.
  Names/order `day, week, month` and the entire capacity function match HEAD's
  original definitions verbatim, including clamp/floor behavior and exceptional
  numeric inputs. The new library has no imports/exports or runtime dependencies.
- The root imports and explicitly re-exports the two original symbols. Exact
  normalized-source comparisons prove the root changed only by extraction and
  the month/zoom files only by replacing their root imports. No additional API
  or presentation behavior was introduced. Eight independently executed contract
  tests verify boundaries, enum identity/names and old-path compatibility.
- Both children's complete local import/export closure comprises nine files
  (listed in the manifest); neither reaches the root. External Flutter/package
  dependencies are terminal edges. Existing configuration/models remain shared.
- **Confirmed enforcement gaps:** the original scanner collected only the first
  conditional URI; mishandled nested comments, raw/triple/escaped strings and
  URI normalization; allowed `dart:ui`; and checked only direct child edges.
  Six regression methods first produced 14 failing subcases against the original
  implementation. The repaired stdlib scanner reads only library directives,
  ignores declarations/body strings, collects every conditional branch outside
  configuration expressions, handles metadata/comments/raw strings/escapes/BOM,
  and normalizes local package/relative/percent-encoded URIs. Final review also
  reproduced and fixed a false rejection of an allowed domain URI whose raw path
  passed through `features/..`; purity now uses only the resolved destination.
  Local child graphs
  are traversed with a visited set, including indirect export bridges.
- Fixtures now call the production boundary/purity functions instead of copying
  approximations of their logic. Final 18 tests include permitted multiline,
  aliased and conditional directives, nested comments, body/interpolated strings,
  metadata, diagnostic lines, forbidden imports/exports and cyclic/diamond graphs.
  This is a small directive scanner, not a general Dart parser; Flutter analysis
  remains the syntax/type authority.
- CI adds the check to the existing Ubuntu job using explicit Bash, whose
  `-e -o pipefail` behavior propagates failures through `tee`. A local inert-tool
  probe of the exact new command preserved exit 17. The new contract test is in
  the serial fast suite and the calendar feature plan. Existing release workflows,
  triggers, permissions, pins and acceptance gates are unchanged; changed YAML
  passed the already-provenanced local actionlint 1.7.12 binary.

## Source identity and reuse

[Reviewed source manifest](ARCH01_REVIEW_SOURCE_MANIFEST_2026_11_14.json):
22 exact working-tree byte hashes; combined SHA-256
`5e86d6b2c495a15c8f1e1a3554473982a504ae6816cf7998d135c750542c3fa1`.
It includes the child dependency closure, changed code/tooling, relevant tests,
verification helper, dependency/configuration files and root instructions.
Documentation is outside this execution manifest to avoid self-hashing.

The [previous calendar manifest](CALENDAR_REVIEW_SOURCE_MANIFEST_2026_11_14.json)
matches 49/52 Git-filtered source/assertion/dependency blobs. The other three are
the root/month/zoom libraries with their exact extraction-only changes proven
separately. Thus prior approved recurring-event, multi-day resize, history and
shared UI evidence in the [calendar receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md)
remains applicable to those unchanged boundaries. No Level 2 invariant changed.

Gemini's ledger reports 9 architecture, 8 contract, 5 zoom and 1 capacity tests,
plus tooling/analysis passes, without exact dirty-source fingerprints or raw-log
links. These remain **reported historical results**, not independent exact-source
passes. The tooling claim of 44/44 is qualified: the handoff reports one skipped
test. The current 8-test compatibility run fills the relevant new compilation/API
evidence gap; unchanged zoom/capacity behavior is additionally proven against
HEAD. No broad tooling/Flutter suite was rerun solely to refresh those reports.

## Executed verification

All commands ran from the repository root. Detailed outputs are ignored under
`.buildlog/arch01-review/`; numbers below identify their logs. Final source is the
manifest above. Earlier scanner iterations are explicitly distinguished; their
passes are not reused for the final scanner. Times are local UTC+03:00.

| Time / log | Invocation and purpose | Result / reason |
| --- | --- | --- |
| 20:25 / 01 | `python -m unittest discover -s tools -p test_architecture_boundaries.py`; six new regression methods against original scanner | Expected failure: 15 tests, 14 failing subcases; proves enforcement defects. |
| 20:26 / 02 | Same command after scanner repair | 15 passed; rerun because scanner changed. |
| 20:27 / 03 | Same command after production-checker fixtures, metadata and graph-cycle cases | 17 passed; expanded assertions. |
| 20:27 / 04 | `dart format --output=none --set-exit-if-changed lib/features/calendar/calendar_contracts.dart lib/features/calendar/calendar_view.dart lib/features/calendar/calendar_month_view.dart lib/features/calendar/calendar_zoom_controller.dart test/calendar_contracts_test.dart` | Exit 1: month view has existing formatting differences; other four files clean. No source files written. |
| 20:28 / month-formatted.txt, 05 | `dart format --output=show lib/features/calendar/calendar_month_view.dart`; compare formatted output; `dart format --output=none --set-exit-if-changed .buildlog/arch01-review/month-baseline.dart` on `git show HEAD:lib/features/calendar/calendar_month_view.dart` | Baseline also requires formatting (exit 1). Changes are unrelated body wrapping/spacing; left untouched. Exact import-only comparison independently passes in 12. |
| 20:28 / 06 | `flutter test --no-pub --concurrency=1 --reporter=expanded test/calendar_contracts_test.dart` | 8 passed; necessary new legacy-import/identity compilation evidence, no fingerprinted Gemini receipt available. |
| 20:28 / 07 | Python diagnostic calling existing `WorkflowShellTests.execute` with the exact CI architecture command and inert Python exit 17 | Passed: one selected command, output through tee, Bash returned 17. Local shell probe, not GitHub execution. |
| 20:28 / 08 | `.buildlog/infra01-review/actionlint.exe .github/workflows/ci.yml` | Exit 0; changed workflow only. |
| 20:28 / 09 | `./tools/dev/verify.ps1 -Feature calendar -Mode Feature -Plan`, then assert contract test appears once in the test step | Passed; no feature suite executed. |
| 20:29 / 10 | `flutter analyze --no-pub --no-fatal-infos lib/features/calendar/calendar_contracts.dart lib/features/calendar/calendar_view.dart lib/features/calendar/calendar_month_view.dart lib/features/calendar/calendar_zoom_controller.dart test/calendar_contracts_test.dart` | Exit 0, zero errors/warnings; one existing `curly_braces_in_flow_control_structures` info at root line 557, also present in HEAD. |
| 20:30 / 11 | Same architecture unittest command after BOM, multiline URI and decoded Flutter-URI cases | 17 passed in 0.199s; modified scanner/assertions justify rerun. |
| 20:31 / 12 | Python exact-source comparison, nine-file dependency-closure traversal and reviewed-source manifest generation | Passed; exact formula/import compatibility and no reverse path. |
| 20:32 / 13, 14 | Compare prior 52 Git-filtered manifest blobs via `git hash-object --path=...` | First diagnostic assertion incorrectly expected only root to differ; corrected expected list to all three reviewed import files. Then 49 unchanged / 3 expected differences passed. No product defect or source repair. |
| 20:34 / 17 | `python -m unittest tools.test_architecture_boundaries.BoundaryCheckerFixtureTests.test_normalized_domain_import_is_allowed_in_contract` | Expected failure: valid normalized domain import rejected by raw prefix. |
| 20:34 / 18 | `python -m unittest discover -s tools -p test_architecture_boundaries.py` after resolved-only purity fix | Final 18 passed in 0.209s; new assertion and confirmed defect justify rerun. |
| Final documentation / 15, 20 | `python tools/dev/check-docs.py docs/ARCH01_CODEX_REVIEW_2026_11_14.md docs/AI_REVIEW_QUEUE.md docs/AI_REVIEW_HISTORY.md docs/PROGRESS.md docs/TEST_RUN_LEDGER.md docs/DEFERRED_VERIFICATION.md` | Both passed, zero errors; second run covers subsequent final-result documentation edits. |
| Final identity / 19 | Python SHA-256 comparison of all 22 manifest entries, expected tracked-path set, new-file trailing whitespace and empty index checks | Passed; final source fingerprint current, unrelated paths/index preserved. |
| Patch hygiene / 16, 21, 22 | `git diff --check` | Passed; repeated only after additional documentation edits. Git emitted existing checkout LF/CRLF notices, no whitespace errors. |

Final documentation-link/catalog, manifest-currentness and whitespace checks are
also recorded in the ledger. Symbol search across non-generated Dart under `lib`
also found exactly one enum and capacity function declaration.

No full Flutter/Python regression, Windows/Android/native build, emulator,
production profile or real-account operation was performed. No Dart code was
edited by Codex, so hot reload was not required. Live UI/device/input acceptance
was not performed. Scope is Windows desktop calendar composition; Android's
`MobileWorkspace -> MobileCalendar` shell and native widgets are unchanged.
Implementation and experience inspections found no changed rendering, controls,
states, terminology, interaction or accessibility behavior. UX necessity outcome:
keep the existing user journey; a contract extraction needs no added UI.

## Instructions and Markdown actually read

Applied skills:

- [Todorbit Engineering Quality](../.agents/skills/todorbit-engineering-quality/SKILL.md),
  with [agent workflow efficiency](../.agents/skills/todorbit-engineering-quality/references/agent-workflow-efficiency.md).
- [Todorbit Regression](../.agents/skills/todorbit-regression/SKILL.md).
- [Ultimate UI/UX](../.agents/skills/ultimate-ui-ux/SKILL.md), with relevant
  [design/UX necessity standards](../.agents/skills/ultimate-ui-ux/references/design-standards.md).
- Flutter architecture: `C:/Users/User/.codex/plugins/cache/dart-flutter/dart-flutter/1.0.7/skills/flutter-apply-architecture-best-practices/SKILL.md`;
  layer separation and existing repositories/controllers applied without adding
  an architecture framework or changing Todorbit's authoritative directory rules.

Project Markdown, limited to applicable sections: [AGENTS](../AGENTS.md),
[modular architecture audit](TODORBIT_MODULAR_ARCHITECTURE_AUDIT.md) (calendar
problem/roadmap/ARCH-01 scope), [Architecture](ARCHITECTURE.md),
[Architecture Map](ARCHITECTURE_MAP.md), [Codex workflow](CODEX_WORKFLOW.md),
[Testing](TESTING.md), [AI Review Queue](AI_REVIEW_QUEUE.md),
[AI Review History](AI_REVIEW_HISTORY.md), [Test Run Ledger](TEST_RUN_LEDGER.md),
[Deferred Verification](DEFERRED_VERIFICATION.md), [Progress](PROGRESS.md),
[prior infrastructure receipt](INFRA_CODEX_REVIEW_2026_11_14.md),
and [prior calendar receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md).

## Remaining acceptance

ARCH-01 is complete as a local independent code review. [DEF-CI-CLOUD](DEFERRED_VERIFICATION.md#def-ci-cloud)
still requires the final authorized committed/pushed candidate, actual Ubuntu
execution including architecture/contract tests, failure artifacts and required
check migration. All existing calendar DST/input, real Drive, Windows packaging/
widget and Android acceptance entries remain pending. Existing formatting and
the informational lint are not introduced by this extraction. Approval does not
establish release readiness or authorize publication.

## Local checkpoint scope (2026-11-14)

The user subsequently authorized one local reviewed checkpoint, without push,
merge, PR or publication. Branch `codex/independent-beta-review`; parent remains
`9cfdd0c619abffd94f3dacef1a794cede12ba9d2`. Engineering Quality's Git/preservation
guidance and Regression's evidence-reuse policy apply; no new UI or code review
is needed for unchanged approved source. All 22 original byte fingerprints and
their combined identity above match at 20:57 UTC+03:00. No tests, analysis or
builds are rerun. The historical review and its known formatting/lint limits
remain unchanged.

Explicit checkpoint allowlist (15 paths):

```text
.github/workflows/ci.yml
lib/features/calendar/calendar_contracts.dart
lib/features/calendar/calendar_month_view.dart
lib/features/calendar/calendar_view.dart
lib/features/calendar/calendar_zoom_controller.dart
test/calendar_contracts_test.dart
tools/dev/features.json
tools/test_architecture_boundaries.py
docs/AI_REVIEW_HISTORY.md
docs/AI_REVIEW_QUEUE.md
docs/ARCH01_CODEX_REVIEW_2026_11_14.md
docs/ARCH01_REVIEW_SOURCE_MANIFEST_2026_11_14.json
docs/DEFERRED_VERIFICATION.md
docs/PROGRESS.md
docs/TEST_RUN_LEDGER.md
```

Excluded and preserved with pre-checkpoint byte hashes:
`docs/TODORBIT_MODULAR_ARCHITECTURE_AUDIT.md`,
`docs/STORAGE_CLEANUP_2026_11_04.md`, `docs/STORAGE_MAINTENANCE.md`.
No application behavior, licensing, versions, dependencies or release assets
changed during checkpoint preparation. New documentation only records scope,
evidence reuse and preservation. Commit identity is obtained from Git after
creation rather than inserted into its own contents.

Checkpoint audit trail: `.buildlog/arch01-checkpoint/`. `01-preflight.log` records
a diagnostic-only status-parser error (stripping the first status line's leading
space); `02-preflight-corrected.log` verifies the corrected parser, all approved
hashes, expected branch/parent, empty initial index and exact changed-path set.
`preflight.json` retains the allowlist and excluded-document byte hashes.
Subsequent staged/commit records retain expected Git blob identities, exact scope,
sensitive-content inspection, documentation-link checks, whitespace checks and
post-commit preservation. These are Git/documentation checks, not fresh runtime
test or release evidence. Existing deferred acceptance remains pending.
