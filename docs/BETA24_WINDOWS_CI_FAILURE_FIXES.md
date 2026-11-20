# Beta 24 Windows CI failure fixes

The [Windows CI failure artifact](https://github.com/2HIK4/Todorbit/actions/runs/44390804115/artifacts/14471015284) and [job log](https://github.com/2HIK4/Todorbit/actions/runs/44390804115/job/135107602128) identify twelve failures at integrated commit `12d7e46fe47d4da761b13b1be995b8c7420e157c` for `1.0.19-beta.24+47`. The job reported **1,166 passed, 12 failed, 9 skipped**. Analysis passed. The failed test step blocked Windows installer and portable packaging.

The fix branch starts at `60b85413ec82eda4295c4542865f068f5d671db1`, the verified local and remote tip of `feature/todorbit-release-p8`. Its diff from the CI commit is documentation only. Public baseline `v1.0.19-beta.23` resolves to `ec94f68f3ff0f46d0314f5fcf769dce899ada4a0`. All twelve matching tests passed on that baseline and failed locally on the unpatched Beta 24 tip.

## Original failures

Assertion locations refer to the CI source.

| Test | Original file and assertion | Classification and correction |
| --- | --- | --- |
| calendar shows the assigned study activity and editor can change future steps | `progressive_plan_widget_test.dart:54` expected the Full Page heading `Task Details`. | **Outdated test.** The desktop default is Side Panel since the detail presentation preference was introduced. Select Full Page explicitly for this navigation test, check that the correct occurrence is selected, and retain the plan persistence assertion. The earlier [navigation decision](DECISIONS.md#2026-11-18-legacy-sync-settings-android-shared-inbox--beta-24-publication-gate) keeps this preference device-local. |
| All Tasks expands stable recurrence identities and filtered children stay independent | `refinement_ui_test.dart:291` expected the child hidden before filtering. | **Outdated test.** The integrated hierarchy initially shows children attached under their parent. Use the parent disclosure to collapse the child, then confirm the filter still finds the child independently with the parent absent. Retain recurrence identity, count and completion assertions. [Hierarchy decision](PROMPT6_FULL_UI_AUDIT_2026_11_18.md#3-confirmed-issues--repaired-defect-registry). |
| Advanced Search priority chips remain usable with large text | `remaining_dialog_layout_test.dart:134` tried to scroll to an element inside a closed group and threw `Bad state: No element`. | **Outdated test.** Open Priority and Sort Results through their disclosure headers and target the form's vertical scroller. Check the chip's geometry and selection through the resize. [Search checkpoint](PROGRESS.md#ui-rel-01-prompt-1-authoritative--search-ux-progressive-advanced-search-keyboard-insets-and-single-route-taskevent-detail-presentation-2026-11-17). |
| event color selection persists | `round3_calendar_test.dart:156` searched for the former `PopupMenuButton<int>` and threw `Bad state: No element`. | **Outdated test.** Open the Event editor's labeled anchored color selector, choose Ocean from its scrollable menu, and verify the same saved ARGB value. See the [anchored selection decision](DECISIONS.md#anchored-selection-and-widget-startup-2026-10-24). |
| S16-focus compact enlarged state retains usable layout | `secondary_surface_quality_test.dart:337` tried to scroll to `Start focus stopwatch` and threw `Bad state: No element`. | **Outdated test.** Follow the unified `Start task timer` action in the dialog. Retain the clock readability and persisted running and paused state assertions. [Timer decision](PROMPT2_TASK_UX_2026_11_17.md#verification). |
| narrow Settings switches categories without clipping | `settings_hub_test.dart:89` matched two anchored controls after Task Preferences gained a presentation selector. | **Test infrastructure.** Target the Settings section input by its label and the actual menu items. Keep the navigation and clipping checks through both category changes. |
| shared icon picker remains usable above IME at large text | `stage2_ui_regression_test.dart:219` captured a 4-pixel vertical RenderFlex overflow. | **Application regression.** The AlertDialog left its action footer outside the scroll view, exhausting the available height at 320 × 540, 200% text and a 240-pixel IME inset. While the keyboard is open, the shared dialog action bar scrolls with the picker. Strengthen the test by filtering and selecting an icon above the simulated IME. |
| Schedule History toolbar action has a visible themed icon and opens history | `workspace_toolbar_test.dart:51` could not find the Today description on the second theme. | **Application regression.** The read-only menu had no focused descendant for Escape. The first tap opened it, Escape left it open, and the next tap toggled it closed. Give the trigger a focus node and give the overlay keyboard focus so Material can handle dismissal. Verify that Escape closes it in each theme and that Schedule History still opens. |
| real process death after rows rolls back data, flags and domain triggers | `sync_apply_crash_recovery_test.dart:102` failed before the row-write barrier. | **Test infrastructure.** The standalone Dart worker failed compilation when `BackupService` imported Flutter solely for `visibleForTesting`. Import that annotation from the existing locked `meta` version as a direct dependency. |
| real process death after materialized rolls back data, flags and domain triggers | `sync_apply_crash_recovery_test.dart:102` failed before the materialization barrier. | **Test infrastructure.** Same import failure. The restored worker exercises transactional rollback and one successful retry. |
| real process death at uncommitted retains exact committed state | `sync_crash_recovery_test.dart:63` failed before the uncommitted-mutation barrier. | **Test infrastructure.** Same import failure. The restored worker exercises real forced process termination and validates committed state after reopening. |
| real process death at staged retains exact committed state | `sync_crash_recovery_test.dart:63` failed before the staged-batch barrier. | **Test infrastructure.** Same import failure. The restored worker verifies exact batch ID, digest and retry bytes after reopening. |

Both crash suites now share a barrier check that reports early child exit and
surfaces stdout and stderr on failure. The check requires successful forced
termination once the durable marker appears. The existing watchdog and all
post-crash SQLite and Sync assertions still apply.

## Verification

Executed on 2026-11-19, 00:13–00:33 UTC+03:00, on Windows 11 Pro 10.0.26200 with Flutter
3.47.7 (`abaf9c523780`) and Dart 3.13.5. Flutter child processes inherited
disposable `APPDATA` and `LOCALAPPDATA` roots. UI tests used in-memory task
data and Sync workers used temporary databases. The pure Dart dependency
resolver verified the lockfile offline. Both releases have the same resolved
`meta` 1.19.0 package. Its lockfile entry now identifies a direct dependency.

The verified source and assertion tree over the release tip is
`38b6aef9ccf4eacf29a2f0f1b987d29bac0106a4` before receipt edits. The corrected
`pubspec.lock` blob is `d8bcda914402d58613854dcce3b2e6ae6d461f76`. The CI
artifact's `windows-tests.log` SHA-256 is
`c8534292989bc28a8175a9d10852cece4eadf2ae9553c163c7a9ba57d83081c8`.
Local logs are under `.buildlog/verify/beta24-windows-ci/`.

Each local test command starts with
`flutter test --no-pub --concurrency=1 --reporter expanded`.
The original scope is the ten files in the table above. The named scope adds
`--name` with an anchored alternation of the twelve listed names.

| Invocation and purpose | Passed / failed / skipped | Source and evidence |
| --- | --- | --- |
| Original scope, all cases in the ten files | 63 / 12 / 0 | Release tip, fresh reproduction. `beta24-before.log`. |
| Named scope on public Beta 23 | 12 / 0 / 0 | Detached public tag, fresh baseline comparison. `beta23-target.log`. |
| `dart run test/support/sync_apply_crash_worker.dart` | Compiler exit 254 | Release tip. Standalone compilation identified `BackupService` → Flutter foundation → `dart:ui`. `worker-probe.log`. |
| Two instrumented widget cases for the icon picker and toolbar | Blocked on first launch, then 0 / 2 / 0 | Initial runner collided with the ongoing reproduction's loaded Windows SQLite DLL. Reran the probes against the release tip in a separate temporary checkout and captured the overflowing AlertDialog and the menu state across Escape. `ui-diagnostics.log`, `ui-diagnostics-isolated.log`. |
| Named scope after first correction | 11 / 1 / 0 | Both app regressions and all four forced process-death checks passed. Search's first revised scroll finder matched nested horizontal scrollers too. `beta24-candidate-target.log`. |
| Named Advanced Search and Settings cases from their two files | 2 / 0 / 0 | Final tree. Restricted Search to the vertical form scroller and targeted Settings at the input surface after the previous run reported missed text hit tests. `beta24-finder-rerun.log`. |
| Critical neighbors | 68 / 0 / 0 | Final tree. Schema 29 and WAL/FULL durability, backup snapshot/restore and cache validation, encrypted retry bytes, peer ancestry, Sync compatibility and journal rollback. `beta24-critical-nearby.log`. |
| Original eight widget files plus six UI and application neighbors | 131 / 0 / 0 | Final tree, including all eight original widget failures. `beta24-ui-nearby.log`. |

Critical neighbors were `test/database_initialization_test.dart`,
`test/backup_service_test.dart`, `test/prompt7_cache_correctness_test.dart`,
`test/sync_exchange_repository_test.dart` and `test/sync_journal_test.dart`.
The six UI and application neighbors were `test/advanced_search_widget_test.dart`,
`test/prompt1_search_and_detail_presentation_test.dart`,
`test/workspace_draft_safety_test.dart`, `test/round3_editor_test.dart`,
`test/prompt2_task_timer_test.dart` and `test/beta24_calendar_sync_test.dart`.
The final evidence covers **203 distinct passing tests**. That combines the
131-case batch, the 68 critical neighbors and the four crash tests whose
worker, harness, dependencies and assertions match the first correction run.

`flutter analyze --no-pub` reported zero issues in 33.4 seconds.
`dart format --output=none --set-exit-if-changed` checked all 14 changed Dart
files and found zero changes. `git diff --check` passed. [Testing policy](TESTING.md).

The initial `flutter pub get --offline --enforce-lockfile` invocations for both
checkouts resolved packages and wrote package configurations before exiting at
the Windows plugin symlink step. `dart pub get --offline --enforce-lockfile`
with `FLUTTER_ROOT` set passed for the corrected tree. No running debug target
was available through Dart Tooling Daemon. UI evidence comes from Flutter
widget tests. Physical Windows and Android keyboard acceptance remains pending.

## Release handoff

Production edits are limited to two shared Flutter controls and the
framework-independent testing annotation. The data checks revalidated Sync
causal history and exact retry bytes, Beta 23 compatibility, Schema 29 and
WAL/FULL durability, and backup and restore integrity. The widget batch covers
unsaved drafts, task and event navigation, timer and work logging, and Calendar
and Sync notifications. Smart Reschedule recurrence, Android Shared Inbox
serialization and resource ownership, alarms and reminders, and native
Windows companion behavior retain their prior integration evidence. [Integration ledger](TEST_RUN_LEDGER.md#beta-24-release-blocker-integration-verification-2026-11-18-utc0300).

Gemini owns integration and the full Windows workflow. A successful full run
and the existing Windows installer and portable acceptance gates are required
before publication. The [successful Android run](https://github.com/2HIK4/Todorbit/actions/runs/44390832263)
covers the integrated release source before this correction. [Deferred verification](DEFERRED_VERIFICATION.md#beta-24-windows-ci-correction-acceptance-2026-11-19).
