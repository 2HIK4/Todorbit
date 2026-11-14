# Independent INFRA-01 review — 2026-11-14

**APPROVED AFTER REPAIRS — local implementation only.** Real GitHub execution,
branch-protection/ruleset configuration and runner timing remain PENDING in
[DEF-CI-CLOUD](DEFERRED_VERIFICATION.md#def-ci-cloud). No commit/push/dispatch,
version/tag/publication, product feature/schema/sync/licensing change authorized
or performed. Branch `codex/independent-beta-review`, HEAD
`8be2f048757348f7c2f522f048e23801e5dc749f` verified. Index remains untouched.

## Source and evidence

Baseline copies/manifest and raw diagnostics: ignored `.buildlog/infra01-review/`.
Final execution/instruction/dependency manifest: `final-source-hashes.json`,
SHA-256 `D7C522EE5EFD79B6DFC1D58AE1D71B41805C5FCDD49AEAD5C3DC7445E6B127F1` (18 paths).
The calendar checkpoint's 52 reviewed source/test/dependency byte hashes remain
identical; CAL-01 keeps its approved safety restrictions and all prior review
history. Unrelated STORAGE_CLEANUP_2026_11_04.md and STORAGE_MAINTENANCE.md remain
untracked and preserved. Metadata-only history/progress/ledger/receipt edits are
outside the execution manifest to avoid self-hashing; Git diff identifies them.

Gemini's 30 Python / 42 representative Flutter / seven parsed YAML / analysis /
docs summaries lack raw-log locations and dirty-source/dependency fingerprints.
They are reported evidence, not new independent passes. Unchanged helper/product
implementations and the committed calendar manifest allow bounded reuse of prior
source-fingerprinted receipts. No app test, full helper suite, Flutter analyzer,
Windows/Android/native build or device run was repeated. The newly added CI shell
contract tests are the only unit tests run in this review.

## Findings and repairs

- **P1: first Windows helper-suite failure hidden** (`windows-ci.yml`, developer
  helper step). Two native Python commands shared a PowerShell step. A first
  exit 7 followed by success yielded final exit 0; GitHub's shell wrapper only
  propagates the final native status. Added immediate exit checks after each,
  explicit pwsh and bounded host logs. A real synthetic failing Python suite
  now stops execution before the second suite; the release gate cannot falsely
  pass that earlier failure.
- **P2: empty/mis-scoped diagnostics** (manual host job). No tested commands
  wrote the promised logs; uploading all .buildlog could instead collect fixtures,
  databases/packages. Host commands now capture named logs through pipefail;
  automatic CI and Windows host checks have bounded diagnostics. Failure artifact
  patterns upload log files only (seven-day retention), never whole profiles.
  Windows source/host logs supplement native/package console output; no claim
  that every native subprocess has a separate file. Existing successful release
  candidate artifact/name and if-no-files-found:error remain.
- **P2: platform results missing from manual summary.** Original completion steps
  existed only in the host job. Added always-run selected-result job with explicit
  needs and result selection. Only the selected worker runs; non-success, including
  cancelled/skipped/invalid selection, cannot produce a passing result summary.
  GitHub remote orchestration is still unexecuted; local contracts use inert tools.
- **P2: critical/deferred instructions ambiguous.** Explicitly require the smallest
  checks covering changed critical invariants, with valid-pass reuse; do not run
  every migration/sync suite after a layout/docs edit. The test matrix is examples,
  not an unconditional bundle. Level 2 never moves to the deferred backlog.
- **P2: deferred procedures/claims inaccurate.** Preserved all six IDs/intent, added
  owner roles, target vs evidence rules, retained historical evidence on invalidation,
  and removed unsupported current-pass claims. Referenced paths actually exist;
  an early commentary assumption that they were missing was corrected after
  path validation. The Sandbox script has no -Installer interface and Sandbox is
  optional under owner guidance; corrected to the supported preparation route or
  ordinary disposable user/VM. Do not alter the personal host clock for DST tests.
  Separate live Sync from snapshot backup and desktop series-drag from Android
  agenda/editor support. Separate physical Flutter input from native companion DPI.
- **P2: mutable tags described as immutable/audited pins.** Verified current tags
  and commit objects via each upstream repository API, then pinned direct actions
  in ci/manual/windows to those exact 40-character SHAs. No hashes invented.
  Checkout credentials are not persisted; dependency resolution enforces lockfile.
  Nested pre-existing Android/release/Pages tag references remain an explicitly
  recorded transitive supply-chain limitation, not silently called immutable.
- **Policy/migration:** PR branch filters match base branches, not contribution
  prefixes. Automatic CI now covers all PR bases and main pushes. Removed Windows
  automatic triggers remain removed; owner must migrate any formerly required
  standalone windows check to the observed Fast Cross-Platform Checks context if
  that is the intended policy. Actual GitHub rules were not accessible/inspected;
  no setting was changed. Android comment claiming Windows runs every PR is fixed.

## Automatic CI selection and timing

Ubuntu, read-only token, unprivileged pull_request (no pull_request_target), no
signing secrets or self-hosted runner, stable Fast Cross-Platform Checks name,
PR supersession cancellation. SDK remains project-standard Flutter 3.47.7 stable /
Dart 3.13.5; local --version --machine and pub-get help confirm that pin and
--enforce-lockfile support. The installed Flutter AnalyzeOnce passes multiple
selected paths to Dart analysis; full lib plus selected tests are analyzed,
warnings remain fatal and existing no-fatal-infos policy remains. Comprehensive
and Windows workflows retain full analysis gates.

Twelve serial Flutter files keep database init/migrations/repository/CAS,
recurrence/series, codec/encryption, cross-platform backup, sync journal and
CAL-01 integrity; notification/contrast smoke tests remain. Broader mobile/
theme cases move to existing full manual regression, with Windows candidate
full suite retained. This adds missing journal/integrity coverage without
removing essential immediate safety verification. Python helper and five new
workflow-contract tests, default route/docs checker and deferred-doc links run.
No new Python package dependency: tests use stdlib plus available Bash/pwsh.

25-minute automatic and 60-minute comprehensive ceilings allow cold setup and
serial work; they are provisional budgets, not measured cloud performance.
Flutter action SDK/pub caches remain enabled; the exact locked dependency set
is enforced. PR cache isolation relies on GitHub's existing cache access model;
no privileged workflow consumes a PR-produced executable or signing cache.
Existing path-filtered Android automatic builds/AVD tests can still run alongside
new CI. INFRA-01 does not make all automatic workflows inexpensive. First cold/
warm Linux SDK availability, cache behavior and actual suite time remain pending.

## Manual selection and release compatibility

| Choice | Actual worker/scope |
| --- | --- |
| flutter-regression | Ubuntu full test/ directory only; no platform builds |
| calendar-recurrence | Ubuntu selected calendar/recurrence/integrity/history |
| persistence-sync | Ubuntu database/CAS/journal/apply/exchange/codec/backup plus series integrity |
| all-host | Ubuntu full analysis, default docs, all Python tooling and test/ |
| windows-verification | Reuses Windows-2022 full analysis/host/native/package gate |
| android-verification | Reuses existing Windows Android-host/debug-APK plus Ubuntu API-35 emulator update fixture |

Both called workflows declare workflow_call. No secret inheritance or permission
escalation is required. Android signed-candidate dependencies remain validate +
windows-regression before protected android-signing; no signing/deploy job can
be selected from manual verification. Windows Release/C++ runtime/portable,
native writer/background/self-test, installer and checksum steps all remain.
The separate API-36 16KiB artifact workflow is not called by generic Android
verification; candidate identity/hash and its existing trusted draft-asset write
permission remain isolated. Pages triggers/deployment approval and permissions
are unchanged. Android update AVD integration is not the workspace fixture and
not physical acceptance; DEF-AND-WORKFLOW remains. Both full host options have
the same test directory, while all-host additionally covers analysis/docs/Python;
Windows-only skipped fixtures do not become Linux/native/device passes.

## Validation ledger

All invocations use this unchanged HEAD plus recorded dirty working changes;
raw output stays under .buildlog/infra01-review. Independent checks are bounded
to workflow semantics, shell behavior and docs; no complete application rerun.

| Invocation / log | Actual result and reason |
| --- | --- |
| Original Git/status/diff/checkpoint and baseline manifest | Correct branch/HEAD; only infrastructure/docs dirty plus two unrelated storage files. Captured initial ten-path hashes/copies before editing. |
| actionlint download/provenance | Official rhysd/actionlint v1.7.12 Windows amd64 release, archive SHA-256 6e7241b51e6817ea6a047693d8e6fed13b31819c9a0dd6c5a726e1592d22f6e9 matches publisher checksum and GitHub asset digest. Downloaded/extracted only into ignored directory; no global install. actionlint-provenance.json. |
| 01: actionlint -shellcheck= -pyflakes= with all seven workflow paths | Exit 0 on Gemini baseline. Proves YAML/Actions expressions/call graph, not routing intent or cloud execution. Optional ShellCheck/Pyflakes unavailable/disabled, not claimed passed. |
| SDK metadata HTTP lookup | Official Linux release-metadata request returned HTTP 404; lookup failed and no release availability conclusion was drawn. Local version/help subsequently matched 3.47.7 / 3.13.5 and lockfile flag. Actual Linux download remains DEF-CI-CLOUD. |
| Native exit reproduction | Python exit 7 followed by success in one PowerShell step yields exit 0. Confirmed the missing intermediate checks. |
| Upstream action tag/commit API checks | Five upstream repositories verified; action-pins.json stores official URLs and resolved SHAs. Dependencies pinned without guessing. |
| 02: actionlint after first edits | Failed due to my summary printf escaping introducing unindented YAML lines. Corrected quoted newlines; preserved this failed intermediate validation, not a Gemini defect. |
| 03: INFRA_WORKFLOW_ROOT=<saved-baseline> python -m unittest discover -s tools -p test_ci_workflows.py | Expected baseline failure: 4 tests, 9 failed subcases and one missing-rollup error. Missing command logs, missing rollup and hidden first Python failure demonstrated with inert/synthetic fixtures. |
| 04: same unit command without baseline override | Four tests passed after corrections, 8.864s; host choice/logs/failure propagation and selected result states plus Windows native failure. |
| 05: actionlint all seven paths | Exit 0 after summary escaping repair and initial structural changes. |
| 06: five-test module after explicit routing assertion | One extractor error (overbroad indentation split), four other tests pass. Test helper corrected, no production change justified by it. |
| 07: five-test module | All pass, 8.406s. Python 3.14 warned about positional maxsplit; changed to keyword without altering extraction. |
| 08: python -m unittest discover -s tools -p test_ci_workflows.py | All five pass, 9.766s on final workflow shell bodies. Includes latest Windows log/exit checks and stronger proof that the second suite never ran. Other checks use inert Flutter/Python shims, not actual app suites. |
| 09: final actionlint all seven explicit workflow paths | Exit 0, final executable workflow content. Later documentation-only changes do not invalidate it. |

Actionlint command in rows 01/05/09 expands to:

```powershell
./.buildlog/infra01-review/actionlint.exe -shellcheck= -pyflakes= .github/workflows/ci.yml .github/workflows/manual-verification.yml .github/workflows/windows-ci.yml .github/workflows/android-ci.yml .github/workflows/android-release.yml .github/workflows/android-16k-runtime.yml .github/workflows/pages.yml
```

No cloud run has occurred. No GitHub branch-rule state, required checks, action
allowlist or signing environment was changed. [First execution instructions](TESTING.md#first-github-execution-and-required-check-migration)
cover authorized reviewed commit/push/PR, owner-required-check migration, default-
branch dispatch registration, all six exact-ref manual groups and a controlled
failure probe. Preserve all pending backlog items until actual matching evidence.

## Applied instructions and skills

Read AGENTS, Architecture Map, Codex Workflow, Testing, review queue/history,
latest test ledger/progress, Deferred Verification, relevant Release/Android
workflow/Pages/16KiB sources, Windows clean acceptance and isolated launch/update
fixture scripts. Applied Engineering Quality + Agent Workflow Efficiency and
Regression. Available/local installed skill names were searched: no dedicated
Security or CI/CD skill was installed; no missing mandatory named skill or new
plugin was required. This is infrastructure, with no product UI change/audit.

Primary references used to verify semantics/security: [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax),
[reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows),
[secure action use](https://docs.github.com/en/actions/reference/security/secure-use),
[official actionlint release](https://github.com/rhysd/actionlint/releases/tag/v1.7.12)
and [Flutter SDK archive](https://docs.flutter.dev/install/archive). API provenance
is retained separately; source/vendor behavior was not inferred from third-party
posts. No publication is part of this approval.


## Final documentation and preservation checks
Default developer route/catalog validation and changed review/backlog links both
passed with zero errors (10-docs-default.log, 11-docs-review.log). Referenced test/
tool paths exist. Eight unique deferred IDs remain PENDING, including all six
original IDs; no unperformed check became a pass. INFRA-01 is archived and removed
from pending review, while the complete previous history remains its prefix.
Two inline boundary validators initially failed the history-prefix assertion
because locale-default decoding disagreed with UTF-8 Git content; normalizing
newlines alone did not fix it. Explicit UTF-8 confirmed unchanged history; these
were checker errors, not product/history corruption. Details retained in
boundary-validation-diagnostics.txt. AGENTS level-range typography was normalized
to ASCII before the final manifest; no executable workflow/test changed afterward.
Final boundary/hash check passed (16-boundary-validation.log): all 18 final
manifest hashes and 52 approved product/dependency hashes match. Android signed
release, 16KiB runtime and Pages workflows have no diff; Android CI differs only
in its stale comment. Product/native/version/lockfile paths have no diff. Index
remains empty and HEAD unchanged; the two unrelated storage documents remain
untracked. git diff --check passed (13 and final 17; final metadata-only 18).
No further app/test/build/cloud action is required for this local review.

Invocation completion times (+03:00; raw logs identify exact outputs):

| Log | Completed |
| --- | --- |
| 01-actionlint-baseline.log | 2026-11-14 17:43:28 +03:00 |
| 02-actionlint-edit.log | 2026-11-14 17:47:20 +03:00 |
| 03-contracts-baseline.log | 2026-11-14 17:50:36 +03:00 |
| 04-contracts-corrected.log | 2026-11-14 17:51:01 +03:00 |
| 05-actionlint-corrected.log | 2026-11-14 17:51:02 +03:00 |
| 06-routing-contracts.log | 2026-11-14 17:56:17 +03:00 |
| 07-contracts-final.log | 2026-11-14 17:57:12 +03:00 |
| 08-contracts-windows-logging.log | 2026-11-14 17:58:35 +03:00 |
| 09-actionlint-final.log | 2026-11-14 17:59:47 +03:00 |
| 10-docs-default.log | 2026-11-14 18:03:05 +03:00 |
| 11-docs-review.log | 2026-11-14 18:03:05 +03:00 |
| 13-diff-check.log | 2026-11-14 18:04:30 +03:00 |
| 16-boundary-validation.log | 2026-11-14 18:06:12 +03:00 |
| 17-final-diff-check.log | 2026-11-14 18:06:12 +03:00 |

Row 02 actionlint checked ci/manual/windows only; rows 01/05/09 checked the
seven-path expansion above. Rows 04/06/07/08 use the same exact unittest discovery
command; each rerun followed the stated source/assertion correction. These shell
contracts are not a cloud runner or application-test timing benchmark.


## Reviewed INFRA-01 local Git checkpoint — 2026-11-14

The user subsequently authorized a descriptive local commit on the existing
`codex/independent-beta-review` branch from `8be2f04`. All 18 approved execution/
instruction/dependency hashes match source fingerprint
`D7C522EE5EFD79B6DFC1D58AE1D71B41805C5FCDD49AEAD5C3DC7445E6B127F1`.
The [portable manifest](INFRA_REVIEW_SOURCE_MANIFEST_2026_11_14.json) preserves the
exact original manifest text/fingerprint plus canonical Git blob identities and
the complete explicit 15-file staging allowlist. Its escaped original text can
reproduce the source manifest byte-for-byte, independent of checkout newlines.

Only checkpoint metadata was added to receipt/progress/ledger and the portable
manifest; no approved workflow, instruction, test or deferred specification was
edited during checkpoint preparation. Review queue/history remain exactly as
approved. CAL-01 restrictions and all pending cloud/device/release checks remain.
Both unrelated untracked storage documents are excluded and byte-preserved.
Application/schema/signing configuration/native/release inputs and licensing
have no changes. Build logs, local profiles/databases and tool downloads stay
ignored. No Flutter tests, builds, analyzer, cloud dispatch or dependency install
was repeated; prior exact-source actionlint/five-contract/doc evidence is reused.

Applied AGENTS, Codex Workflow, Testing, review queue/history, this receipt,
Progress/Test Run Ledger and Deferred Verification; Engineering Quality with
Agent Workflow Efficiency/Git Discipline and Regression skills. Installed skill
metadata/files were checked: no dedicated Git/security skill is installed, so
repository Git rules and the approved security review remain applicable. No new
architecture/security audit or skill installation. Staged checks and final local
commit audit follow the existing explicit-staging workflow. The commit containing
this entry identifies the checkpoint; its SHA is reported after verification.
No push, merge, PR, signing, version/tag/license change or publication authorized.

Checkpoint hygiene passed: exact 15-file staging scope; all 18 canonical reviewed
index blobs match; original approved manifest reconstructs at D7C522EE…6B127F1.
Staged whitespace, added-content credential/private-key patterns, path/mode and
local-link checks passed. Prior queue/history are byte-identical to checkpoint
start, receipt/progress/ledger retain their earlier records, and both excluded
storage files retain their initial hashes. Existing Git identity is configured;
no active commit hooks were present. Detailed staging/commit audits remain under
ignored `.buildlog/infra01-checkpoint/`. No test/build rerun was needed.

## Focused development PR and first cloud execution (2026-11-14)

Later user authorization permits publishing the reviewed development scope and
observing CI, while explicitly withholding historical integration into `main`.
`main` remains `a6d36dc7ed2863a40b7e9bc9c4cdbebc81f2c530`. Existing public remote
`codex/independent-beta-review` at `053fa0f2df16ddb8eefb7867f09562400a423837`
contains all 165 historical commits and is the exact ancestor of reviewed
`204b8d325c6957e9d7ffce0aeb998de05e72915e`. A range-diff proves the only new
commits are `8be2f04`, `9cfdd0c`, `204b8d3`; the initial focused diff is 56 files,
11,233 additions and 952 deletions. No historical code was cherry-picked onto
the older default branch. All 22 ARCH source hashes match; prior milestone
manifest comparisons remain valid. The three unrelated untracked documents are
unchanged and excluded.

To avoid advancing the base with the identically named local branch, published
the reviewed SHA under `codex/reviewed-calendar-ci-arch` using a normal explicit
refspec. [PR #1](https://github.com/2HIK4/Todorbit/pull/1) targets
`codex/independent-beta-review`, not `main`. Local repair work uses the matching
new head branch; original local reviewed branch/commits are preserved. No force
push, default-branch modification, protection/ruleset change or release dispatch.
Both main/development bases had no active protection/rulesets when inspected.

[First Lightweight CI run](https://github.com/2HIK4/Todorbit/actions/runs/43636796051)
on PR head `204b8d3` failed after about 46 seconds (job 42 seconds): Linux setup,
Flutter 3.47.7, Python 3.13.18 and enforced-lockfile dependency resolution passed.
Flutter SDK and pub caches both reported hits/restoration. Analysis then rejected
one unused local binding at `calendar_series_integrity_review_test.dart:327`;
14 informational diagnostics were nonfatal. Later Python/architecture/test steps
were skipped, not passed. Bounded failure artifact `lightweight-ci-43636796051-1`
(ID `14130630395`) was uploaded and downloaded successfully; it contains only
`analysis.log` and `dependencies.log`. Real failure propagation is observed.

Minimal repair removes that unused binding while preserving `await weekly()`
and every assertion; also removes an unnecessary test import. No product logic
or workflow gate changes. Applying the Dart static-analysis skill,
`flutter analyze --no-pub --no-fatal-infos test/calendar_series_integrity_review_test.dart`
passed with no issues (81.6 seconds locally). No local product tests or builds.
The repair commit is additional to the three approved checkpoints; a new cloud
run is required before this PR has passing verification.

The existing [Android validation run](https://github.com/2HIK4/Todorbit/actions/runs/43636795996)
started automatically from its pre-existing PR paths, not a manual dispatch.
Manual workflow registration and its file at `main` both return HTTP 404;
`manual-verification.yml` is present only on the development side. No expensive
manual platform/signing workflow or standalone bootstrap was created. Safest
future dispatch activation is a separately reviewed default-branch integration
path that preserves the historical backlog and release gates.

Git/scope/source and cloud records are retained in `.buildlog/ci-activation/`,
including `focused-pr-preflight.json`, first-run logs and the bounded artifact.
The earlier no-cloud statements above describe their original checkpoints.
`DEF-CI-CLOUD` remains incomplete; source/run conclusions and remaining manual
acceptance must be updated after the repaired run completes.

[Second automatic run](https://github.com/2HIK4/Todorbit/actions/runs/43637305743),
head `539d1df4a38b20d09f4adb693ae4d072810526d5`, passed analysis/docs and failed
after about 59 seconds in the developer-helper test (8 run, 2 Windows-fixture
skips). Linux PowerShell rendered the expected exception with ANSI colors and a
line break/gutter between `never` and `guessed`; the actual nonzero rejection
was correct, but the test's raw substring assertion was not portable. Repair is
test-only diagnostic normalization of ANSI styling, continuation gutters and
whitespace, with a focused plain/styled/unexpected-message regression fixture.
Nonzero-exit and semantic-message assertions remain required. The same handling
is used for the explicit disposable-emulator rejection. Production verification
scripts, test selections and workflow failure gates are unchanged.
`python -m unittest discover -s tools -p test_dev_verify.py` passed all 9 tests
locally in 15.512s. No product tests/builds were run. Original-head Android run
43636795996 was cancelled as superseded; replacement-head checks remain enabled.
