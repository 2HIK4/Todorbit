# Prompt 2 — Task timers and task composition (2026-11-17)

## Scope and identity

Codex implementation on `feature/todorbit-task-ux`, assigned worktree only.
Started clean at `5803e52e017d2a1a69d8d42e239296d61dd75588`; verified directory,
branch and HEAD before editing. The current user assignment overrides the older
prompt numbering/agent allocation in the program tracker. No merge, rebase, push,
publication, release/version/schema change, Stable modification or personal-profile
access. Schema remains 29. Unrelated pending Gemini review entries are preserved.

[Source/assertion/config fingerprints](PROMPT2_TASK_UX_2026_11_17_SOURCE.json) bind
this receipt to the final implementation; the containing commit binds documentation.
Host: Windows, Flutter 3.47.7 (`abaf9c5237`), Dart 3.13.5, serial host tests,
in-memory/disposable SQLite. Recorded 2026-11-17 20:38 +03:00.

## Root causes and behavior

- `TimeRepository.startTimer` rejected any active run, including the same task;
  the pre-fix assertion reproduced `Bad state: Pause or stop the existing timer first`.
  It now returns the same running/paused run inside the transaction without a new
  interval. New starts return their own run before leaving the transaction.
- Desktop quick-start added a redundant status-versus-focus decision. Shared
  `openTaskTimer` now starts the selected task flow directly or opens the existing
  session. Windows list/details, Android details/actions/compact bar, Focus controls
  and actual-work dialog use it. Repeated entry is coalesced in UI and controller.
- Other-task entry offers Cancel, Open existing timer, or Stop and switch. The
  switch uses the reviewed run/revision, recovery/ownership guards and one
  transaction; destination failure rolls back the stop. A Pomodoro break creates
  no work interval. Cancellation preserves the Android Details route.
- Focus starts no longer implicitly write task status. Task status remains editable
  independently; stopping/pausing timers does not complete or reschedule tasks.
  Planned sessions and existing work logs are untouched. Paused entry stays paused;
  stopped entry starts a new run; remote/recovered sessions require existing review
  controls. Countdown/Pomodoro phase state remains process-local; restart uses the
  persisted run and existing checkpoint recovery, not an invented recovered phase.
- Shared compact timer has task title/navigation, reliable running/paused/review
  state, confirmed elapsed work, quick pause/resume and Stop menu. Remote/recovered
  elapsed work is capped at the checkpoint; refresh pauses stale process-local focus.
- Keep both named `New checklist` groups and inline ungrouped checklist items.
  `Add item` inside an expanded group targets that group. Group rename/reorder/remove
  use a compact header menu; group/item removal requires confirmation. Existing
  group/item identities, CAS removal guards, completion state and restart history
  are reused. Redundant Details edit/focus controls were removed.
- Repository intentionally supports one subtask level. Child details explain that
  limit; editor/detail resource assignment no longer offers a failing nested-child
  creator. Independent task identities, schedules and parent/child counts remain.
- Planned-session row deletion appears in editor and Details for upcoming,
  unstarted sessions. Confirmation uses existing Trash/restoration. A transaction
  checks revision/outcome/actual start before deletion, protecting a session that
  changed while confirmation was open. Completed work, tasks and actual logs remain.

## Changed files

Implementation:

- `lib/app/app_controller.dart`
- `lib/data/life_repository.dart`, `lib/data/time_repository.dart`
- `lib/features/time_tracking/{task_timer_intent,compact_task_timer,focus_workspace,time_tracking_dialog}.dart`
- `lib/features/workspace/{workspace,task_details_view,task_editor,task_composition_section,checklist_groups_section,planned_session_delete,unified_resources_section}.dart`
- `lib/features/mobile/mobile_workspace.dart`

Assertions/gates:

- `test/prompt2_task_timer_test.dart` (13 focused state-machine/repository/widget cases)
- `test/{focus_quick_start,refinement_ui,task_composition_widget,time_tracking_repository,time_tracking_widget,uiux03_navigation}_test.dart`
- `tools/dev/features.json` (`task-timers` reusable focused gate)

Skills/tracking:

- `.agents/skills/todorbit-engineering-quality/references/data-safety-and-persistence.md`
- `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`
- This receipt/source manifest, program tracker, Progress, AI Review Queue,
  Test Run Ledger and Deferred Verification.

## Verification

The final batch command (log `.buildlog/prompt2/final-tests.log`) was:

```powershell
flutter test --no-pub --concurrency=1 test/prompt2_task_timer_test.dart test/time_tracking_repository_test.dart test/time_tracking_widget_test.dart test/focus_session_test.dart test/focus_quick_start_test.dart test/uiux03_focus_widget_test.dart test/uiux03_navigation_test.dart test/task_composition_test.dart test/task_composition_widget_test.dart test/refinement_ui_test.dart test/checklist_layout_test.dart
```

PASS **43/43**, 106 seconds. It includes 12 new Prompt 2 tests, desktop direct
start/compact controls, actual Android shell navigation, recovery review,
countdown completion semantics, atomic switch rollback, duplicate starts, planned
session Trash/restore and changed/completed-session protection, checklist group
creation/rename/removal, reorder/history/CAS guards, one-level subtask policy and
database close/reopen. Existing layout checks cover selectable checklist text at
narrow/wide widths. The compact timer is tested at 280dp.

Diff review then found a no-op Open existing timer callback in the actual-work
dialog. Corrected that callback, labeled entry as Start task timer to reflect the selected
mode, and added a thirteenth Prompt 2 test. The smallest
invalidated check was rerun (log `.buildlog/prompt2/dialog-entry-followup.log`):

```powershell
flutter test --no-pub --concurrency=1 test/prompt2_task_timer_test.dart test/time_tracking_widget_test.dart --name 'actual work dialog'
```

PASS **2/2**, including the new existing-session navigation assertion and the
previous actual-work journey. This gives **44 distinct focused tests** with valid
matching evidence; unchanged assertions/surfaces from the 43-test batch are reused.

Adjacent safety check:

```powershell
flutter test --no-pub --concurrency=1 test/workspace_test.dart test/mobile_workspace_test.dart test/sync_apply_repository_test.dart --name 'timer|focus|Focus|task row|details'
```

PASS **3/3**: Android overdue-row check and both imported-timer ownership / checkpoint
transfer checks. The filter matched no desktop workspace tests; desktop entry is
covered by `focus_quick_start_test.dart`, not claimed from this filtered invocation.
Sync protocol code is unchanged; unrelated sync/recurrence/alarm/backup suites
were not rerun merely for a fresh receipt.

Additional lifecycle/accounting check (log `.buildlog/prompt2/lifecycle-accounting.log`):

```powershell
flutter test --no-pub test/uiux03_review_test.dart --name 'bounded work|countdown completion|short restart'
```

PASS **3/3**: work intervals stop exactly at the countdown/Pomodoro deadline,
breaks never enter the ledger, and even short restart requires an explicit
checkpoint review. Total distinct checks: **50** (44 focused + 6 adjacent/lifecycle).
An initial filter without spaces was misinterpreted by the Windows batch wrapper;
it ran no tests. The quoted multiword filter above resolved that invocation issue.

Analysis:

```powershell
flutter analyze --no-pub lib/ test/prompt2_task_timer_test.dart test/focus_quick_start_test.dart test/refinement_ui_test.dart test/task_composition_widget_test.dart test/time_tracking_repository_test.dart test/uiux03_navigation_test.dart
flutter analyze --no-pub lib/features/time_tracking/time_tracking_dialog.dart test/prompt2_task_timer_test.dart test/time_tracking_widget_test.dart
```

Both PASS, no issues; second invocation covers the follow-up.
Changed Dart files: `dart format --output=none --set-exit-if-changed` PASS (22 files).
`git diff --check` PASS. `tools/dev/verify.ps1 -Mode Feature -Feature task-timers -Plan`
resolves the new gate; the plan is not represented as an executed test pass.

### Retained diagnostic history

- Initial `flutter test --no-pub test/time_tracking_repository_test.dart --plain-name 'timer pause, resume, and stop preserve distinct actual intervals'`
  could not resolve tests before dependencies were restored. `flutter pub get`
  resolved pinned packages, then reported missing Windows native symlink support.
  No dependency/lockfile changes are included. The same focused command then
  failed on the original timer exception, establishing the pre-fix reproduction.
- First repaired repository/composition/time-widget/focus batch: 15 PASS. Final
  batch above supersedes it for changed boundaries.
- Intermediate `flutter test --no-pub --concurrency=1 test/prompt2_task_timer_test.dart test/focus_quick_start_test.dart test/refinement_ui_test.dart test/uiux03_navigation_test.dart test/task_composition_widget_test.dart`
  exposed fake heartbeat timers/double-disposal in the new fixture and an old
  composition fixture assuming full-page Details despite Prompt 1's side-panel
  default. Fixture now owns/disposes the provider during widget execution, and
  full-page behavior is explicitly selected in that existing test.
- Subsequent `flutter test --no-pub --concurrency=1 test/prompt2_task_timer_test.dart test/task_composition_widget_test.dart`
  exposed a self-await in the newly added future-coalescing cleanup; changed the
  cleanup callback to return void. A later rerun isolated the remaining fixture
  heartbeat leak (the intent harness had not instantiated its lazy provider);
  it now reads the provider before disposal. The final batch passes these cases.
- Analyzer iterations removed a missing enum import and style lints. Final clean
  analysis is above. Drift emits its multiple-database warning in the independent
  file-reopen fixture; those databases use different executors/files, and all are
  closed. It is not a test failure or evidence of production data access.

## Review and remaining acceptance

Implementation correctness inspected separately from experience: direct entry,
meaningful conflict/cancel behavior, status/time/plan terminology, nested groups,
visible functional actions and narrow compact controls. Confirmed edge cases have
repository/widget evidence; no claim of exhaustive UX or physical-device coverage.
This is Codex implementation/self-review, awaiting independent integration review;
no unrelated Gemini review entry is approved or archived by this task.

**NOT TESTED / pending Level 3:** wider application integration, 2x text/light/dark/
RTL matrix for the new controls, broader desktop/mobile permutations.
**BLOCKED live tooling:** no DTD/debug app exists; `dtd listDtdUris` and requested
hot reload reported no app. Native plugin launch requires Windows Developer Mode
symlink support. No personal profile or peer worktree was launched to bypass it.
**PENDING Level 4:** isolated Windows mouse/keyboard/DPI and Android physical Back,
TalkBack, background/kill/restart journeys; Release packaging/installer/update,
16-KiB runtime and real service acceptance before any later release. No packages
were built or beta published. See [Deferred verification](DEFERRED_VERIFICATION.md).
