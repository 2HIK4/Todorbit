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
| 016: Android Release build helper | Passed, 8 native libraries aligned | Signed universal APK, source `c11297e`; superseded by the later upward-continuation correction. Original local.properties bytes restored. |
| 019: isolated packaged native Release self-test | Passed | Child APPDATA/LOCALAPPDATA and resolved TodoPilot root logged beneath this task's native-profile. Native source unchanged by later Flutter correction; reuse only with matching final binary hash. |
| 020: Windows package identity preflight | Failed before packaging | Task-local harness incorrectly required numeric **string** FileVersion for Flutter main EXE. Verify numeric PE parts instead; main string legitimately retains beta/build identity. No app source change or output created. |
| 021: corrected Windows preflight + Inno/portable/checksums | Passed | Both EXEs product `1.0.19-beta.19+42`, numeric `1.0.19.42`; disabled Drive; compiler 7.1.0; source `c11297e` runtime inputs identical at `3d30d52`. Packages subsequently superseded by continuation fix. |
| 022: Android signature/identity/floor/manifest preparation | Passed | Production cert `00226d…74a99`, code42 > published41, universal APK and sidecars; subsequently superseded by continuation fix. |
| 023: boundary review, upward/cross-column continuation only | Failed | New edge assertion finds the first continuation correction still clamps negative visual offsets to zero. |
| 024: `dart format test/calendar_review_boundaries_test.dart` | Passed | Format new edge assertion only. |
| 025: boundary/controller/layout/gesture/history/shortcuts (7 files) | Passed: 50 | Final correction permits negative offsets only for already-clipped continuation movement; ordinary starts keep day bounds. Downward/upward/cross-column moves, history, duration, cancellation and notification checks pass. |
| Dart MCP `analyze_files`: interaction controller, layout engine, boundary review | Passed: no errors | Final continuation correction; prior controller/mobile/draft/CAS passes reused under unchanged boundaries. |

CI for intermediate sources: `43513284876`/`43513288019` cancelled after the
Sandbox helper change. `43514388959` cancelled after the upward continuation
correction. Android `43514390043`: host/APK job passed; on-device job failed to
start Dart Development Service before loading android_drive_updates_test
(zero tests executed). Emulator boot/build/install succeeded; no app-behavior
pass is claimed. Publication was blocked pending fresh final-source CI; that
later runner passed (see final evidence below). Detailed failure log retained.

Intermediate packages remain byte-for-byte under
`.buildlog/independent-review/superseded-3d30d52-packages`; they must not be
published. No old public tag/binary is altered. New Flutter code invalidates
prior Windows/Android AOT and package checks; both final rebuilds passed below.

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
has been opened or launched. Final Release GUI/Sandbox and emulator acceptance
are recorded below; physical keyboard/DPI/OEM acceptance remains unverified.

Release evidence discrepancy: Beta 17 tag Windows run `43475207925` failed with
866 passed, 8 failed, 9 skipped (seven pending-midnight-timer failures plus one
concurrent WAL setup failure). Beta 18 run `43506984173` completed with 881
passed, 1 failed, 9 skipped (same WAL fixture race). Receipts claiming all mandatory gates passed do not
establish release readiness. Existing published binaries/tags are preserved.

## Final-source verification and publication

Runtime source/tag `375729e064ba9a2c7af298fa4c40e60d51d14821`; fingerprint
`33b0a5039ea671d44d0cbe3174d993db045c6a3d882b297e72728bf7e208c6fd`
for tracked application/tests/tools/configuration used by the local logger.
Source unchanged after final builds; subsequent edits are documentation only.
Commands, times, source and fingerprint for each entry remain in its numbered
`.buildlog/independent-review/run-NNN.json`; paired `.log` contains output.
Temporary live-test/verification scripts are additionally hashed in later records.

| Invocation | Result | Scope / necessity |
| --- | --- | --- |
| 026: `pwsh -NoProfile -File tools/build-windows-release.ps1` | Passed | Final Windows Release after continuation correction; disabled Drive, CRT gates. |
| 027: task-local `launch-gui.ps1` | Passed | Final Release launched with verified task-owned APPDATA/LOCALAPPDATA. Pointer navigation/editor observed using Windows UI automation; helper text/key input inconclusive. Closed only this app. |
| 028: task-local `build-android.ps1` | Passed | Final signed universal Release, eight aligned native libraries; original local.properties bytes restored. Sequential with Windows build. |
| 029: task-local `verify-gui-profile.py` | Passed | Resolved isolated TodoPilot profile, schema 28, 54 tables, integrity OK, no FK violations, empty task table. |
| 030: task-local `package-windows.ps1` | Passed | Final PE versions, Inno 7.1.0 setup, portable ZIP and checksum outputs. |
| 031: task-local `verify-signing-continuity.ps1` | Passed | Downloaded actual Beta 18 production APK, checked GitHub digest and both certificates; no key change. |
| 032: task-local `prepare-android.ps1` | Passed | Canonical APK preparation, package/code/floor/signature, updater manifest and sidecars. |
| 033: task-local `verify-packages.py` | Passed | ZIP CRC, bundle configuration/private-file exclusion, all ten asset hashes and sidecar consistency. |
| 034: `tools/prepare-windows-sandbox-acceptance.ps1 -PackagesDirectory release/beta19` | Passed | Stage final packages, exact digests and beta display identity. |
| 035: task-local `launch-sandbox.ps1` plus acceptance result | Passed | Fresh Windows identity: installed/portable profiles, integrity/reopen, same-candidate setup preservation, uninstall/reinstall and native self-test. GUI/Google explicitly unverified. Only exact task-owned Sandbox session closed. |
| 036: `pwsh -NoProfile -File tools/dev/test-profile-journeys.ps1` | Passed: 15 | Separate opt-in startup/recovery/resource journeys; malformed appearance/calendar, corrupt/future schema, legacy upgrade, restore/restart, privacy/path/resource boundaries. Actual child profile paths recorded. |
| 037: task-local `stage-release.ps1` | Passed | Private prerelease staging, exact source, ten explicit assets. No publication yet. |
| 038: task-local `verify-draft.py` | Passed | All uploaded asset sizes/digests/state and intended source/classification. |
| 039: `tools/test-portable-update.ps1 -Package release/beta19/Todorbit-1.0.19-beta.19-win-x64-portable.zip` | Failed | Disposable main app did not close within 15 seconds. Held publication; do not infer a product cause from timeout. |
| 040: task-local `portable-diagnostic.ps1` with same package | Passed | Same positive assertions plus logging window handle/title/CloseMainWindow return and retained evidence. Swap, automatic restart, SQLite sentinel and widget settings preserved. Closure accepted; first timeout cause unverified. No app change/assertion relaxation. |
| 041: original portable harness/package, `-ExpectFailure` | Passed | Failure injection, rollback, automatic recovery restart and isolated profile preservation. |
| 042: task-local `verify-draft.py` | Passed | Fresh prepublication asset/source verification after acceptance. |
| `gh release edit v1.0.19-beta.19 --repo 2HIK4/Todorbit --draft=false --prerelease --latest=false` | Passed | Published 2026-11-14 02:42:50 UTC+03, release ID 444843364. Old tags/binaries untouched. |
| 043: task-local `verify-public.py` | Passed | Anonymous release API plus HTTP 200/length/digest checks for every public asset; downloaded and hashed small sidecars/manifests/notes. |
| 044: `flutter test --no-pub --concurrency=1 .buildlog/independent-review/public_updater_test.dart` | Compile failure | Temporary live harness passed null to non-nullable HttpOverrides; application unmodified, zero tests executed. |
| 045: same live updater command | Passed: 1 combined test | Empty concrete HttpOverrides restores real HTTP. Actual production Windows setup/portable and Android arm64/x64 updaters discover Beta 19 from Beta 18; Stable excludes it; Android code/digest verified. Isolated child APPDATA/LOCALAPPDATA. |
| 046: `python tools/dev/check-docs.py` | Passed: 0 errors | Final documentation links/map/catalog after publication receipt updates. |
| Final `git diff --check` and staged diff review | Passed | Documentation-only final handoff; no application rebuild/test repetition. |

Exact-source remote gates:

- [Windows 43516558494](https://github.com/2HIK4/Todorbit/actions/runs/43516558494):
  success; full analysis, 893 tests passed/9 opt-in skips, tooling, config, Release,
  CRT/portable/native writer/background barriers/self-test/installer/checksums.
- [Android 43516561285](https://github.com/2HIK4/Todorbit/actions/runs/43516561285):
  host/APK and on-device update integration both success. Supersedes the
  intermediate DDS startup blocker; no SDK workaround or skipped assertion.
- [Signed APK 16 KiB 43527857993](https://github.com/2HIK4/Todorbit/actions/runs/43527857993):
  exact production APK hash, 16,384-byte pages; stable baseline; rendered Flutter,
  create/restart/complete with no crash/ANR observed. Actual production Beta 18
  code 41-to-42 in-place upgrade retained task. `16k-evidence/receipt.json`.

Native run 019 reused only after matching final executable SHA-256
`a4f4c816ec581ffa485190721cc7a7bfa64590c2d74cec254fd7f632c41fa04a`.
Full local suite was not duplicated after passing exact-source Windows CI.
Earlier 58-pass shared controller/mobile/draft/CAS evidence remains valid because
the final continuation change touches only already-clipped desktop movement,
covered by the final 50-pass calendar run. No broad app rebuild or tests are
required for final documentation-only receipt edits.

Final live updater assertions passed after continuation of this chat at
08:55 UTC+03. Public asset checks and publication occurred earlier the same day.
[Publication receipt](TODORBIT_BETA_19_PUBLICATION.md) contains artifact hashes,
manual limits and the prioritized published-beta checklist. Physical keyboard/
DPI, Windows 10, Narrator/TalkBack, ARM64/OEM reminders and real Google account
flows remain unverified. Windows Sandbox's setup preservation used the same
candidate; a real Beta 18-to-19 Windows installation remains a manual check.
