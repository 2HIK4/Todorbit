# Independent Beta 17/18 review (2026-11-14, UTC+03)

Baseline: `a1ac5a555c4863dc866cad25c5b46aba88ea2aa0`, published Beta 18,
`1.0.19-beta.18+41`, schema 28. Review branch: `codex/independent-beta-review`.
Two pre-existing untracked storage-maintenance documents are excluded.

Scope: Beta 14 source `3e0efe7` through Beta 18, concentrating on Beta 16..18
changes and their calendar/history, task-editor,
controller/cache/lifecycle, Sync presentation, mobile-shell and packaging callers.
Desktop mounts Workspace/CalendarView; Android mounts MobileWorkspace/MobileCalendar.
Native widgets, alarms, persistence and cloud protocols are inspected only at
changed boundaries; unchanged historical acceptance is not a current runtime pass.

## Verification evidence

Read TESTING.md, TEST_RUN_LEDGER.md and Beta 17/18 receipts before execution.
Existing calendar tests do not assert minimum duration at midnight, continuation
movement or clipped resize handles. New focused assertions require execution
against the unpatched source, then the correction. Logs and machine-readable
command/time/source/SHA-256 fingerprints: `.buildlog/independent-review/run-*.json`.
Each invocation below refers to that exact command record, including failures.

| Invocation | Result | Purpose / necessity |
| --- | --- | --- |
| 001: `flutter test --no-pub --concurrency=1 test/calendar_review_boundaries_test.dart` | Failed: all 3 new assertions | Pre-fix reproduction of minimum duration, continuation date shift and clipped handles. Logger console encoding failed after recording the exit/log; fixed UTF-8 output, no test rerun for logging. |
| 002: `flutter test --no-pub --concurrency=1 test/controller_date_rollover_review_test.dart` | Failed: Today event missing | Pre-fix reproduction: midnight notification invalidates lists but never reloads the narrow Today event projection. |
| 003: `dart format` eight changed files (exact paths in JSON) | Passed | Format edits; restore unrelated formatting to keep diff focused. |
| 004: boundary/rollover, interaction/layout, calendar regressions/history/shortcuts, workspace (8 files) | Passed: 61 | First post-fix check. Subsequent history changes invalidate affected history tests only. |
| 005: history review test | Failed: task title overwritten | New pre-fix assertion. |
| 006: history review test, expanded event assertions | Compile failure | Incorrect model constructor in new test; correct to existing `EventRepeat`. No application change. |
| 007: history review test, constructor corrected | Failed: 3 | Task, ordinary event and recurring occurrence all overwrite later edits. |
| 008: history review, existing undo/redo and safety/persistence (3 files) | Passed: 17 | Post-fix history plus LIFO/recurrence/deadline invariants. |
| 009: history error review test | Failed | Deleted event + toolbar Undo throws without visible error; pre-fix reproduction. |
| 010: history error, shortcuts and lease repository (3 files) | Passed: 15 | Persistent/closeable errors, four-second success dismissal and lease semantics after fixture fix. Expected Drift multiple-engine diagnostic retained. |
| 011: history review, `--plain-name 'session history preserves a later outcome change'` | Failed | Undo changes skipped session back to upcoming; sibling stale-snapshot defect. |
| 012: `dart format` ten changed files (exact paths in JSON) | Passed | Format new edits; restore unchanged original token spans, including optional trailing commas. |
| 013: `flutter analyze --no-pub` | Failed: one unnecessary import in new history test | Full project diagnostic; remove unused Material import. A targeted final analysis must validate the correction; exact candidate CI remains mandatory. |
| 014: history/rollover review + draft safety/mobile/recurrence/task revision concurrency (6 files) | Passed: 58 | Final changed-history and timer-disposal assertions, shared controller consumers, draft protection, compact/RTL/dark/large-text mobile checks, real in-memory SQLite/CAS assertions. |
| Dart MCP `analyze_files`: history review test, interaction controller, calendar view | Passed: no errors | Verify final import/brace correction; full project analysis found no other issue. Initial attempt reported no configured roots; root-add with incorrect `roots` key rejected, then `uris` succeeded. |
| DTD discovery / `hot_reload` | Blocked: no debug app/DTD | No running app exists to reload; no personal process was attached. Release runtime acceptance remains separate. |
| `git diff --check` (2026-11-14 00:38 UTC+03) | Passed | Diff whitespace validation; only Git line-ending notices. |
| 015: `pwsh -NoProfile -File tools/build-windows-release.ps1` | Passed | Windows Release build, disabled Drive bundle consistency, Microsoft-signed CRT staging; source `c11297e`. |
| 016a (`fixture-pre.json`): `python -m unittest tools.test_windows_sandbox_prepare.SandboxPreparationTest.test_prerelease_assets_and_installer_display_keep_beta_identity` | Failed as expected | Corrected contract assertion reproduces stale numeric-only installer display version in the Sandbox helper. |
| 017: `python -m unittest tools.test_windows_sandbox_prepare` | Passed: 6 | Corrected beta display contract plus stable identity, digest rejection and schema safety. |
| 018: `python tools/dev/check-docs.py` | Passed: 0 errors | Current link/map/catalog validation. |

Logger correction: run 016 Android build did not reserve its number until it
finished, so the lightweight pre-fix helper test reused its log. Preserve that
test's command/fingerprint/result in `fixture-pre.json` and observed failure in
the tool transcript/`fixture-pre.log`; Android's dependency-resolution log prefix
was overwritten, while subsequent Gradle output and final result remain available.
The logger now reserves numbers atomically before execution. No app build/test
is rerun merely to restore log formatting; package identity/signature checks
independently validate the final artifact.

## Findings and corrections

No Critical finding was established.

| Severity | Confirmed cause | Correction |
| --- | --- | --- |
| High | Complete old calendar history drafts use fresh revision tokens, overwriting later titles, notes, deadlines, task status and session outcomes. Present since initial interactive history. | Apply only calendar-owned dates/times to current records; match occurrences by ID and nominal date; retain failed history. `calendar_interaction_controller.dart`. |
| High | A continuation's clamped visual start replaces the true start during movement; clipped segments expose handles for boundaries outside the day. | Preserve hidden start offset; expose handles only at actual boundaries. Interaction controller and `timeline_grid.dart`. |
| Medium | Bottom resize applies a 23:59 clamp after enforcing minimum duration; old test expects 23:50–23:59. | Allow exact midnight end and preserve 15-minute minimum. Layout engine/controller and corrected assertion. |
| Medium | Midnight notification never reloads narrow Today event projection or expands recurring tasks. | Await normal refresh, advance date after success, retain data/retry failed timer refresh, ignore late refresh after disposal. `app_controller.dart`. |
| Medium | Async calendar edit/history errors escape toolbar/shortcut callbacks. | Show persistent closeable error; keep four-second success notices. `calendar_view.dart`. |
| Medium | Beta 17/18 receipts/changelog claim mandatory gates passed despite failed CI; RELEASE.md names an old beta as current. | Correct documentation, preserving published binaries/tags. |
| Low | Lease fixture races journal-mode negotiation before testing lease acquisition. | Enable persistent WAL once before competing engines; retain concurrent acquisition/exclusivity assertions. `sync_lease_repository_test.dart`. |
| Medium | Beta 17 changes Inno AppVersion/DisplayVersion to retain the beta suffix, but Sandbox staging and its test still require the numeric core. | Keep full beta identity in the acceptance manifest; retain numeric PE identity separately. `prepare-windows-sandbox-acceptance.ps1`, `test_windows_sandbox_prepare.py`. |

## Inspection and coverage limits

Implementation inspection: actual desktop/mobile entry points and Git changes.
No data/repository/schema, Android native adapter, backup, reminder or Sync
protocol changes exist between Beta 14 and Beta 18. The only native code diff
is Windows date-navigation hitboxes/painting. TaskEditor extraction retains
validation/composition/persistence order and re-entrance protection. Production
navigation/filter/sort/preferences mutations and refresh invalidate task caches;
no additional cache defect was established.

Experience / UX necessity: retain Undo/Redo, editor access, independent date/time
concepts and Sync recovery decisions. Hide misleading resize boundaries; full
span editing remains available in dialogs. Errors require attention; success
notices expire. No new account steps, controls or broad redesign are justified.

Seven dimensions: desktop Day/Week/Month and Android tasks/agenda; normal,
drag/cancel/history/error/draft states; host Windows/mobile layouts; pointer,
keyboard and touch-oriented widget journeys; move/edit/undo/redo/date refresh;
overnight/multiday/recurring/concurrent/missing records; functionality,
preservation, feedback, accessibility and usability. Runtime, physical input/DPI,
Narrator/TalkBack, OEM alarms and installer approval are separate acceptance.

67-category applicability: interaction/state/preservation/evidence categories
1–10, 21–35, 40, 44–49, 51–53, 56–60 and 62–67 apply to the review. Presentation
and environment categories 11–20, 36–38, 41–43 and 50 are inspected only at
changed boundaries; comprehensive visual/accessibility acceptance is not claimed.
39 (web app) is not applicable. 54–55 (privacy/auth) and 61 (native integrations)
are source-inspected where recent changes touch them, without new live acceptance. Unchanged
features and historical platform receipts are not newly validated passes.

Live tooling discovery: DTD reports no running debug app. No personal profile
has been opened or launched. Physical Windows/Android acceptance is not tested.

Release evidence discrepancy: Beta 17 tag Windows run `43475207925` failed with
866 passed, 8 failed, 9 skipped (seven pending-midnight-timer failures plus one
concurrent WAL setup failure). Beta 18 run `43506984173` completed with 881
passed, 1 failed, 9 skipped (same WAL fixture race). Receipts claiming all mandatory gates passed do not
establish release readiness. Existing published binaries/tags are preserved.
