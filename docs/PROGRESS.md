# Progress

## Urgent Calendar Event Duration Invariant Restored (2026-11-11)

Branch `fix/calendar-interaction-regressions`.
Resolved P0 data-integrity defect where Day/Week calendar move operations erroneously clamped event end times to `maxEnd` (23:59) of the target day:
- **Duration Invariant Restored**: In `CalendarInteractionController.updatePointer` for `CalendarGestureKind.move`, removed single-day `maxEnd` clamping. Event duration is now strictly invariant under move operations (`finalEnd = finalStart.add(originalDuration)`).
- **Multi-day & Overnight Events Safe**: Dragging 26-hour, 48-hour, or overnight events (e.g. 23:00 to 05:00 next day) no longer truncates duration or shifts start time backward.
- **Auto-scroll & Cancellation Hygiene Retained**: Preserved top auto-scroll buffer (-10px) and complete gesture cancellation handlers (`onPanCancel`, `onVerticalDragCancel`).
- **Verification**: Updated Scenario I in `test/calendar_interactions_regression_test.dart` to comprehensively test normal, overnight, 26h, 48h, cross-day, recurring occurrence, undo/redo, persistence, and cancellation (10/10 PASS). All 11 tests in `test/calendar_undo_redo_test.dart` and 4 tests in `test/calendar_interaction_controller_test.dart` pass; `dart analyze` reports 0 issues.


## Interactive Calendar Boundary Clamping & Cancellation Hygiene (2026-11-11)

Branch `fix/calendar-interaction-regressions`.
Hardened interactive calendar boundary safety and gesture lifecycle hygiene based on Prompt 3 engineering investigations:
- **Boundary clamping for long/multi-day events (CAL-02)**: Added lower-bound `minStart` clamping in `CalendarInteractionController` so dragging events with duration >= 24h cannot push `finalStart` into the previous day when clamped to `maxEnd`. Added `maxEnd` (23:59) upper-bound clamping to bottom edge resizing (`resizeEnd`).
- **Top auto-scroll tolerance (CAL-03)**: Added `-10px` overshoot tolerance (`viewportY >= -10 && viewportY < margin`) in `TimelineDayColumn`, preventing auto-scroll from stalling when mouse cursor drifts slightly into the header.
- **Gesture cancellation hygiene**: Added `onPanCancel` and `onVerticalDragCancel` callbacks across item and resize handles in `TimelineDayColumn` to immediately cancel `_autoScrollTimer` and invoke `interactionController.cancel()`, preventing dangling background timers.
- **Domain alarm invariant verified (DATA-01)**: Confirmed that `draft.alarm == null` in `CalendarInteractionController` correctly preserves existing alarm rules in `AlarmRepository`, while `AlarmPlanner` re-evaluates schedules on date changes.
- **Auto-scroll cadence invariant verified (CAL-01)**: Confirmed 30ms interval / 12px step (~400px/s) provides optimal smooth scrolling without CPU thrashing.
- **Verification**: All 10 regression tests in `test/calendar_interactions_regression_test.dart` passed; all 11 tests in `test/calendar_undo_redo_test.dart` passed; `dart analyze` reports 0 issues.


## Beta 16 experimental release published (2026-11-11)

Tag `v1.0.19-beta.16` (version `1.0.19-beta.16+39`, Schema 28).
Published experimental GitHub pre-release with Windows installer, portable ZIP,
production-signed Android universal APK, update metadata, and SHA-256 checksums:
- Refined interactive calendar resolving all 10 manual testing defects from Beta 15.
- Fixed unexpected upward scrolling on pickup with viewport-relative distance and smooth 16ms auto-scroll ticking.
- Full cross-day Week drag & drop with live ghost preview across day columns and atomic commit.
- Dynamic toolbar Undo/Redo reactivity, autofocus node, and keyboard shortcuts (<kbd>Ctrl</kbd>+<kbd>Z</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd>, <kbd>Ctrl</kbd>+<kbd>Y</kbd>).
- Compact 420px floating notification with automatic 4-second dismissal.
- Full-width Month view card drag hitboxes (10% to 90% width) with `LongPressDraggable` on mobile to protect touch scrolling.
- Isolated <kbd>Ctrl</kbd> + Mouse Wheel zoom eliminating simultaneous timeline scrolling, with 350ms transition debounce.
- Comfortable Month view card typography and density (28–34px height, 11pt font, 12pt icons).
- Unified atomic toolbar pill grouping Undo, Redo, divider, and presentation toggle.
- Intentional primary-accent current-time indicator with live time badge and tooltip.
- Upgraded native Windows Tasks widget navigation buttons to 32×32 hit bounds with matching chevrons and Fluent hover outlines.
- All 8 end-to-end regression tests in `test/calendar_interactions_regression_test.dart` and 16 existing tests passed; `dart analyze` reports 0 issues.
- Full receipt recorded in [TODORBIT_BETA_16_PUBLICATION.md](TODORBIT_BETA_16_PUBLICATION.md).


## Calendar Interaction & UI Regression Fixes (2026-11-11)

Branch `fix/calendar-interaction-regressions`.
Addressed manual testing defects identified in the Beta 15 Interactive Calendar:
- **Auto-scroll upward on drag start**: Resolved root cause in `TimelineDayColumn` where card-relative coordinates triggered spurious auto-scroll; converted to viewport-relative distance (`localInColumn.dy - scroller.offset`) with 48px margin and continuous auto-scroll ticking.
- **Undo / Redo live reactivity**: Ensured toolbar Undo/Redo buttons react immediately to history changes using `ListenableBuilder(listenable: _interactionController)`, with dedicated calendar autofocus node and keyboard shortcut bindings (`Ctrl+Z`, `Ctrl+Shift+Z`, `Ctrl+Y`).
- **Compact auto-dismiss notifications**: Replaced persistent full-width banners with floating, compact 420px notifications auto-dismissing after 4 seconds and cleanly replacing prior notices without stacking.
- **Week view cross-day dragging**: Implemented `_resolveDayAt` coordinate mapping with dynamic ghost preview in target day column and atomic date/time commit.
- **Month view card drag hitboxes**: Replaced nested gesture handlers with `Draggable<CalendarItem>` with `HitTestBehavior.opaque` and full-width hit targets, verified at 10%, 25%, 50%, 75%, and 90% widths.
- **Ctrl + Mouse Wheel zoom isolation**: Added `CalendarScrollPhysics.shouldAcceptUserOffset` returning false when Ctrl is pressed and registered pointer signals with `pointerSignalResolver`, eliminating simultaneous timeline scrolling during zoom; added 350ms transition debounce to prevent multi-mode skipping.
- **Month view card readability**: Restored comfortable visual density matching design tokens (28-34px height, 11pt font, 12pt icons, 90px min cell height).
- **Toolbar layout grouping**: Grouped Undo, Redo, divider, and presentation toggle into an atomic rounded pill container to prevent awkward wrapping and orphaned buttons.
- **Current time indicator**: Replaced unlabelled pink line with an intentional primary-colored line, left pip, live time badge, and tooltip.
- **Native Windows Tasks widget navigation**: Updated `WidgetDateNavigation.cs` earlier/later buttons with 32x32 hit bounds, matching chevrons, and accent hover outlines consistent with the Calendar widget.
- **Verification**: All 7 regression scenarios in `test/calendar_interactions_regression_test.dart` passed; existing suites `test/calendar_undo_redo_test.dart` and `test/interactive_calendar_redesign_test.dart` (16 tests) passed; `dotnet run --project experiments/widget-shell-probe -- --self-test` passed; `dart analyze` reports 0 issues.


## Beta 15 experimental release published (2026-11-11)

Tag `v1.0.19-beta.15` (commit `931f71b`, version `1.0.19-beta.15+38`, Schema 28).
Published experimental GitHub pre-release with Windows installer, portable ZIP,
production-signed Android APK, update metadata, and SHA-256 checksums:
- Redesigned interactive calendar with accurate Day and Week time grids, collision avoidance lanes, 15-minute snapping, live drag & resize feedback.
- Cross-day dragging in Week view and date dragging in Month view with context actions.
- Cursor-anchored zoom transitions (Month ↔ Week ↔ Day) and complete keyboard navigation.
- Desktop-grade bidirectional Undo/Redo (Ctrl+Z / Ctrl+Shift+Z / toolbar / SnackBar) with text-focus bypass and safe Redo invalidation.
- Legacy calendar toggle switch preserved in calendar toolbar for instant reversible fallback.
- Mandatory GitHub Actions CI passed: `Windows checks` run 43042071223 (19m26s), `Android validation` run 43027408713 (9m39s), `Website preview checks` run 43042071045 (9s).
- Full receipt recorded in [TODORBIT_BETA_15_PUBLICATION.md](TODORBIT_BETA_15_PUBLICATION.md).

## Calendar Undo & Redo Integration Complete (2026-11-11)

Feature branch `feature/interactive-calendar`.
Implemented complete desktop-grade Undo and Redo system for calendar interactions:
- Full bidirectional history stack: <kbd>Ctrl</kbd>+<kbd>Z</kbd> to undo, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd> and <kbd>Ctrl</kbd>+<kbd>Y</kbd> to redo.
- Toolbar integration: dynamic Undo and Redo icon buttons in the Calendar toolbar reflecting history availability in real time.
- SnackBar integration: reversible notification with immediate "Redo" action on undo, and "Undo" action on redo.
- Gesture coverage: moving items in Day/Week view, top-edge start time resizing, bottom-edge end time resizing, and Month view date drag & drop.
- Invalidation guarantee: performing a new edit after Undo cleanly clears invalidated Redo history (`_redoStack.clear()`).
- Atomic history entries: pointer movements during dragging/resizing generate zero history entries; a single entry is recorded only upon commit.
- No-op and cancellation safety: cancelled gestures (Escape) or drops returning to original time/date record zero history entries.
- Text focus preservation: wrapped with `SettingsHistoryScope` so that when any `EditableText` (e.g. search fields, editor inputs) is focused, keyboard undo/redo operates natively on text without calendar interference.
- Concurrency & race condition protection: added `_isHistoryBusy` guard to prevent corrupting history stacks or racing against SQLite during rapid keystrokes.
- Recurring occurrence isolation: undoing/redoing occurrence edits targets individual occurrences via `updateEventOccurrence` without altering parent series recurrence rules or other occurrences.
- Task deadline protection: scheduled date moves and restorations preserve task deadline dates intact.
- Comprehensive test coverage: 11 focused integration tests in `test/calendar_undo_redo_test.dart` pass completely alongside existing safety, layout, and regression suites.

## Interactive Calendar Redesign (2026-11-10)

Feature branch `feature/interactive-calendar`.
Implemented modular interactive calendar redesign for Windows and Android:
- Accurate vertical time-grid layout for Day and Week views with real time positioning and duration heights.
- Intelligent side-by-side collision layout resolving overlapping intervals into stable local lanes with horizontal expansion and readable minimum widths.
- Move (center-drag) and resize (top-edge start time, bottom-edge end time) with 15-minute snapping, live time chips, semi-transparent ghost preview, and auto-scrolling.
- Cross-day Week drag & drop and Month view date drag & drop preserving clock time and duration.
- Month view extended right-click context menu (Add Event, Add Task, Add Work Session, Show Day, Show Week).
- Date-anchored zoom navigation (Month ↔ Week ↔ Day) via Ctrl+wheel and keyboard shortcuts (Ctrl+1, Ctrl+2, Ctrl+3, T, Ctrl+Z, Esc).
- Modular architecture with centralized configuration (`CalendarAppearanceConfiguration`), layout engine (`CalendarLayoutEngine`), interaction controller (`CalendarInteractionController`), and zoom controller (`CalendarZoomController`).
- Reversible fallback switch in toolbar allowing instant toggling between interactive timeline and legacy calendar presentation.
- Undo/redo support via Ctrl+Z and bottom SnackBar action.
- Recurring occurrence safety (`nominalDate != null` updates single occurrence exception), task deadline preservation (modifies `scheduledDate` only), and alarm synchronization preserved.
- All 48 unit, widget, visual layout, and safety tests pass; `dart analyze` reports 0 issues.
- Verified Windows debug build in isolated profile `%TEMP%\todorbit-calendar-eval` with synthetic data (events, work sessions, recurring items, 3-lane collision clusters).
- Verified Android test APK `build/app/outputs/flutter-apk/app-github-debug.apk` with `verify-android-artifact.py`.
- Resolved confirmed blocker: narrow collision columns (<44px width) on mobile viewports now use ultra-compact pill representation with tooltip, eliminating RenderFlex horizontal overflows.

## Beta14 experimental release published (2026-11-10)

Tag `v1.0.19-beta.14` (commit `3e0efe7`, version `1.0.19-beta.14+37`, Schema 28).
Published experimental GitHub pre-release with Windows installer, portable ZIP,
production-signed Android APK, update metadata, and SHA-256 checksums.
All GitHub Actions CI gates passed (`Windows checks` run 42711845466 in 27m54s,
`Android validation` run 42711898319 in 9m57s). Local native widget self-tests,
migration/sync codec tests, and package verifications passed. Beta 13 remains an
unpublished private checkpoint.

## Beta13 private-review candidate complete (2026-11-07)

[Final results, exact artifacts and remaining gates](FINAL_STABILIZATION_2026_11_07.md#final-outcome-and-owner-review).
Source `7783af8`; schema27/version13+36. Compact themed transient Sync/copy feedback
honors reduced motion; owner-confirmed automatic local restore restart passes.
Real independent Private recovery, GUI restore/reconciliation/decision ciphertext
readback pass. Final Windows public/private and production-signed Android packages
pass scoped gates. Current live debug-source Android hot restart/runtime pass;
production/Standard profiles, keys, recovery copies and protected docs verified.
All task apps/emulator/Gradle/SDK attachment closed; held approval/quarantine retained.
Documentation checkpoint records the completed implementation and scoped evidence. No push/tag/release; exact CI, signed APK
runtime/installer upgrade and physical checks remain explicit owner-review gates.

## Beta13 final polish checkpoint: recovery/restore/UI pass (2026-11-07)

[Durable evidence and remaining final-package steps](FINAL_STABILIZATION_2026_11_07.md).
Local source `7783af8`: scoped Private approval, account/copy UI, compact success,
automatic reviewed local-restore restart and explicit reduced-motion handling.
Live independent key recovery and Private GUI restore/reconcile/decision upload
pass; final Release automatic restart confirmed by owner and verified locally.
Native version wiring fixed `bb9749b`; exact companion self-test reused by hash.
Retained AVD healthy; changed-source offline native UI/input/Back checks pass,
28 Private operations and Standard user0 DB/WAL unchanged. AVD/apps closed and
network preferences restored. New motion tests/captures pass. Windows refresh043
completed; Android refresh044 running with child heap2GiB/workers2. Preserve all
prior packages; no additional Sync, account, source redesign or full-suite run.
Next: audit044 artifacts, final current-source hot reload if available, production/
protected-file hashes, documentation/local commits. No push/tag/publication.

## Live Private GUI restore/reconciliation PASS; automatic restart requested (2026-11-07)

[Stabilization checkpoint](FINAL_STABILIZATION_2026_11_07.md#live-gui-restore-and-new-automatic-restart-request).
User recovery-code unlock, synthetic GUI restore, Before Restore, quarantine,
retained-key reconciliation, conflict choice and decision clock/upload pass.
Recovery app/emulator closed, approval held. New Apply replacement automatic
restart is under focused verification; intermediate beta13 builds are preserved,
but predate this requested change. No publication or repeated Sync matrix.

## Final stabilization: live isolated Private recovery PASS (2026-11-07)

[Current receipt](FINAL_STABILIZATION_2026_11_07.md). New checks 001, 005, 007, 008 and 009; exact logs/hashes outside Git. Reused Standard/Private matrices; GUI restore and final beta artifacts pending. Recovery app and emulator closed; recovery approval held.

## Scoped Private round trip PASS; recovery limits explicit (2026-11-07)

- [Real/offline/reused results and remaining limits](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#scoped-private-acceptance-outcome-2026-11-07).
- Actual passphrase Android pairing, representative Windows graph/attachment and
  native Android completion returned to Windows PASS:43 tables/28 immutable ops/
  4 encrypted batches equal, no pending/conflicts/integrity issues. Key restarts pass.
- Offline actual-proof code recovery/wrong-credential rejection and real local
  backup key exclusion/history decrypt PASS. Not live key-loss/full GUI restore.
- Native text fixture attempts did not persist; synthetic draft discarded; final
  completion verified after frame settling. Harness failures retained, no app
  defect asserted. No new suite/build/AVD restart; source evidence unchanged.
- Production18/startup/protected3/Standard user0 DB-WAL match. Both apps closed,
  signed-in user10 emulator retained. Receipt075; next scoped local checkpoint.


## Android Private identity/preflight PASS; user unlock required (2026-11-07)

- [Existing private workspace verified; exact next action](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#android-accountprivate-preflight-pass-unlock-required).
- User10 account matches Windows Private; actual read-only listing of3 objects
  matches verified private proof/batches. Native setup detects encryption and asks
  for passphrase, still unpaired/automatic off/pending0. No new workspace/write.
- Next user enters SAME Windows Private passphrase only in Android and taps
  Authorize this device. No restart/rebuild/sign-in repeat or secret capture.
  Production18/protected3 match; Windows remains closed. Receipt058 resumes here.


## Windows Private real readback PASS; Android Google sign-in waiting (2026-11-07)

- [Current Private-only evidence and next user action](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#real-windows-private-pass-android-authorization-boundary-2026-11-07).
- Real proof/private batch authentication, retained-key restart and one rich
  fixture encrypted upload/readback PASS, including canary and exact managed bytes.
  Verifier blob-wrapper mistake corrected OFFLINE with retained ciphertext.
- Android user10 UID/path and empty schema27 verified; Google sign-in open.
  Windows closed; Standard user0 DB/WAL, production18 and protected3 unchanged.
- Next: user completes Google/Drive consent with SECOND Private account, returns
  connected. Verify IDs/workspace before Android pairing/exchange; no secret capture.


## Private activation gate corrected; user setup retry required (2026-11-07)

- [Cause and next action](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#p2-activation-failure-diagnosed-test-approval-namespace):
  operator's local approval used DNS UUID namespace; product uses URL namespace.
  App rejected safely before pairing; no confirmed crypto/application defect.
- Offline Windows AOT actual crypto create/verify/unlock PASS; workspace comparison
  independently failed, corrected local scope026 and workspace-only recheck PASS.
  No Google request, application rebuild/full suite or credential inspection.
- Next: reopen private setup, enter passphrase locally, save NEW code and connect.
  No restart or sign-in needed. Historical wrong scope/approval retained unchanged.


## Private setup copy icon loaded; fresh local credentials required (2026-11-07)

- [Copy control, focused evidence and current build](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#recovery-code-copy-control-and-fresh-setup-2026-11-07).
- Icon copies exact displayed recovery code; light/dark large-text and privacy
  closure PASS3, targeted analysis clean. Affected Windows build only; unchanged
  Android/native/crypto/Standard evidence reused, originals preserved.
- User cancelled old unsaved setup; updated owned PID32004 keeps same isolated
  signed-in profile. Scoped approval held/restored unchanged; no cloud requests.
- Next: fresh setup/passphrase and NEW recovery code handled only inside app,
  then Connect with encryption. No chat-posted credential values stored/reused.


## Private P2 ready: Windows fix loaded, user passphrase/code required (2026-11-07)

- [Latest candidate and required private setup](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#current-user-boundary-p2-private-setup-ready).
- Real read-only preflight passed for distinct new account; no Sync objects or
  local Sync-table change. Desktop switch fix tested/built/launched; same signed-in
  isolated profile retained. Production18/protected3 and Standard artifacts match.
- Local Private approval pins account/mode/planned workspace only. No cloud
  workspace/write yet. Next: user chooses passphrase, privately saves generated
  recovery code and Connect with encryption. No secret values/captures requested.


## Private P1 passed; desktop account-switch UX corrected (2026-11-07)

- [Account/preflight and focused switch fix](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#p1-resolved-and-windows-account-switch-fix-2026-11-07):
  new account differs from Standard; actual read-only Sync listing empty, Sync
  tables unchanged. No workspace created during preflight.
- Windows now exposes existing confirmed Switch Google account and clarifies
  Reconnect current account. Focused cancel/switch/new-label and auth-pinning
  regressions pass; one fixture encoding correction retained in evidence.
- Affected Windows UI build only; Android/native/crypto/Standard evidence reused.
  Next: private passphrase/recovery handling; no secrets in chat/logs/captures.


## Private P1 stopped at account mismatch (2026-11-07)

- [Identity gate/next user action](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md#p1-identity-stop-2026-11-07-1058-utc03):
  new private receipt matches Standard account ID; no Google preflight/request,
  approval or workspace created. Production18/protected3 match; no test/build.
- User must Disconnect/Connect only NEW Windows private profile and select a
  different unused disposable account. Local disconnect has no remote revoke.


## Private Sync: local readiness complete, second-account sign-in pending (2026-11-07)

- [Private-only scope, exact artifacts, fresh tests and resume state](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md).
- Private account/mode/workspace approval guard added; six focused tests and
  targeted analysis pass. One affected Windows build; Standard source/bundle
  restored byte-identical, Android APK/native/crypto/Standard evidence reused.
- New persistent Windows root verified empty/schema27/native DPAPI; auth-only
  enabled, both Sync approvals absent. Production18/startup/Standard Android
  DB/WAL unchanged. Android user10 installed but dormant, user0 preserved.
- Next user action: Connect Google Drive in new Windows candidate with second
  unused disposable account. No passphrase/Private workspace or exchange yet.


## Private Sync acceptance prepared, not executed (2026-11-07)

- Base `87e976f`; [resumable plan, reusable assets and authorization gates](PRIVATE_SYNC_ACCEPTANCE_PLAN_2026_11_07.md).
- Source/config continuity and protected documents match; binaries/OAuth/SDK and
  Standard evidence reused. No test/build/launch/Google request/account switch.
- Pending: second disposable account and separate profiles; Windows approval gate
  currently accepts only the Standard contract. Review a minimal Private-specific
  guard before cloud work; inspect Android secondary-user support when authorized.
- Next: owner authorization for this setup; preserve Standard profiles/workspace.


## Verified implementation secured locally (2026-11-07)

- `e6a95ca`: private Windows encrypted credential/profile isolation and
  startup, companion, updater and authorization guards, with existing regressions.
- `3e2e0e5`: Android recovery file identity and network scheduling permission,
  dismissible Sync status, restored decision clocks and focused regressions.
- [Source continuity and checkpoint receipt](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#local-repository-checkpoint-2026-11-07):
  all 27 changed application/test files match verified manifests. Windows private
  inputs/shared fixes are byte-identical; 188 runtime Dart files match content,
  with 53 unchanged files differing only by line endings. Four artifact hashes pass.
- Reused completed acceptance/regression evidence; only hash/staged-file/secret
  exclusion and diff checks run. No builds, tests, emulator launch or cloud call.
  Three unrelated storage-document changes preserved; no push/tag/version change.
- Next: remaining Windows GUI restore and physical/platform acceptance, then
  exact-candidate CI before wider distribution. Private Sync remains unauthorized.

## Real Windows/Android Standard Sync acceptance complete within scope (2026-11-07)

- [Final scenario results, failures, artifacts and limits](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03).
  Real bidirectional rich records/deletions, reviewed offline conflict, interrupted
  retry, corrected local restore/reconciliation, post-restore recurring completion,
  repeated checks and restart converge at383 operations/all43 portable tables.
- Recovery identity aliases, network-job permission, persistent status Close,
  and retained received clocks corrected. Host regressions plus real corrected
  Android replay pass. Both private candidates include corrections; old artifacts
  retained. No full-suite rerun, dependency/version change or installer build.
- Same spare account/workspace/proof, no new sign-in. Approved checkpoint switch
  preserves failed210-operation/seven-invalid-decision profile and original AVD.
  No immutable rewriting or cloud cleanup. Corrected metadata helper proves no
  startup exchange; earlier side effect is disclosed in receipt.
- Production18 paths/startup/protected3 docs and20 isolation inputs match. Original
  cloud11 metadata unchanged; final26 objects unchanged across no-op checks.
  Windows closed, authenticated SSD emulator retained with automatic Sync off.
- Ready for controlled private Standard testing, not public release. Physical/OEM,
  corrected Windows GUI restore, installer and exact-candidate CI remain separate.
  No Private Sync/cloud snapshot test, commit, push, tag or publication.

## Android spare account / existing Standard workspace verified read-only (2026-11-06)

- [Latest account and real metadata receipt](ANDROID_DRIVE_READINESS_2026_11_06.md).
  Owner Google sign-in complete; auth-only reconnect completed with no new prompt.
  Actual Android account ID matches Windows spare receipt. Runtime remains same
  AVD/app/server; no restart/reinstall/rebuild/full-suite repeat.
- Real Android production Sync provider GET listing returns11 unchanged objects:
  proof +10 operation objects/9 unique batches, all expected workspace/protocol2.
  Every ID/size/MD5/property matches Windows inventory, including known duplicate.
  Standard proof identity unchanged; bodies not downloaded/materialized yet.
- Android DB/WAL byte-identical to pre-auth: schema27/integrity/FK pass,0 tasks/
  events/journal, binding absent, capture/automatic disabled. Production18 hashes
  unchanged. Initial VM CastMap-reader guard failure corrected in external helper;
  no actual cloud mismatch, product change or write. Failed evidence retained.
- Ready for explicit owner authorization of first Android Standard exchange and
  synthetic cross-platform tests. No activation/approval/cloud writes; Private
  Sync and cloud snapshots out of scope. Windows candidate remains closed.

## Android authentication readiness after emulator correction (2026-11-06)

- [Scoped results, warning and next owner action](ANDROID_DRIVE_READINESS_2026_11_06.md).
  Retained Google Play API35 AVD/userdata preserved offline; no wipe/new AVD.
  Existing35.3.11 still fails native UI/UiAutomation before APK. Official stable
  emulator37.2.13 downloaded/verified outside Git; existing SDKs/image unchanged.
- Same2GiB/two-core/host-GPU AVD: critical services, Settings/Play/UIAutomation,
  4MiB storage and148MB APK hashes, install and actual Todorbit navigation pass.
  Server PID572 stable beyond15min; no new ANR/crash after initial sample. Strict
  zero-ANR flag stays false due one retained Messaging SIM startup ANR. No broad
  guest-clean/physical-platform claim; app defect not demonstrated.
- Exact registered debug APK reused; schema27/integrity/FK and zero tasks/events/
  journal verified at actual Android private path. Live VM confirms no account,
  no workspace binding, Sync disabled. Native auth-only route prepared; owner
  spare-account sign-in/consent is required. Then compare live account and existing
  Standard workspace read-only before requesting Android exchange authorization.
- Production18 paths/startup, frozen20 source files and protected3 docs unchanged;
  Windows private candidate closed normally for sequential RAM use. No app rebuild,
  full suite, phone access, Android Sync, Private/snapshot test, commit or release.

## Authorized real Standard Windows / Drive acceptance passed (2026-11-06)

- Owner-authorized spare-account/fresh-workspace approval follows another real
  zero-object preflight. Exact existing private candidate used;20-file source
  manifest/main/AOT unchanged. No candidate rebuild, full suite, commit or push.
- [Real results and remaining acceptance](REAL_STANDARD_SYNC_2026_11_06.md):
  upload/readback, independent desktop reconstruction/reverse edits, deletion,
  explicit causal conflict/resolution, real committed upload with injected reply
  loss/retry, local restore of downloaded data with retained pending work and
  real resync, then four unchanged exchanges. All43 portable tables and81
  immutable operations agree after final candidate restart;12 expected task IDs,
  including2 intentional soft deletions, no unexplained/duplicate tasks.
- 18 production paths/startup unchanged;2 recovery profiles/15 files unchanged;
  protected3 storage documents unchanged. App open PID16828, ~269MiB at checkpoint.
  No cloud files deleted, Start New Sync, account/mode switch or production writes.
- Android/emulator, physical UI, Private Sync, real cloud snapshot restore and
  token-expiry/revocation remain open. Windows scoped acceptance passes; original
  unfamiliar-task cause remains unproven. Keep synthetic cloud history for the
  next Windows/Android phase; do not reset it. No release approval/publication.

## Real spare-account read-only Drive preflight passed (2026-11-06)

- Owner completed private sign-in and explicitly confirmed unused spare account.
  Google-verified receipt ID pinned to that confirmation; no production-token
  comparison/decryption. Exact existing build/main/AOT and paths reused.
- Normal owned restart into existing read-only preflight succeeds without another
  sign-in. Actual complete appDataFolder `todorbit-sync`, non-trashed metadata
  listing returns0 objects. Snapshot-backup/personal Drive namespaces not scanned.
- Private schema27/integrity/empty DB pass; no binding, capture disabled, Standard
  approval absent. All18 production baseline paths and startup values unchanged.
  Owned PID15404 remains open, connected, ~222.5MiB. No build/test/VM/Android rerun.
- [Current receipt and next authorization](PRIVATE_CREDENTIAL_ISOLATION_2026_11_06.md).
  Ready for owner authorization of first Windows-to-Drive Standard workspace
  creation/exchange using synthetic data. No upload, activation or approval record
  created; no existing cloud data touched. Source/protected work preserved.

## Approved private Windows credential isolation implemented (2026-11-06)

- Normal-account, explicit test-build flag; fixed marked persistent test profile,
  independent per-purpose DPAPI files, atomic commit/cross-process locks and no
  production fallback/migration. Companion/global startup/updates disabled;
  unchanged companion omitted from private package. No new OS user/VM/emulator.
- Native OS-process/failed-write/corruption/isolation fixture passes after
  headless harness correction; five private-mode Dart cases and22 compatibility
  cases pass. Targeted analysis clean. Private Release build passes (163.2s),
  signed CRT/config/AOT guards pass, source/old recovery hashes preserved.
- Actual built app native round trip and schema27/empty DB checks pass for smoke
  and intended Runtime. After owner closed production apps/widgets, all18
  production DB/settings/encrypted-file hashes and startup values stay unchanged.
- [Exact files, build/ZIP identities, receipts and next action](PRIVATE_CREDENTIAL_ISOLATION_2026_11_06.md).
  App PID12564 remains open at Backups & Cloud; owner selects only the spare
  account. Auth-readiness verified; Standard gate absent until account/workspace
  verification. No real Sync or release claim. Version and production OAuth unchanged.

## Same-account practical Drive acceptance reevaluation (2026-11-06)

- Corrected earlier overbroad isolation claim: portable DB/profile keys prevent
  normal personal-token selection; OAuth explicitly prompts for account choice.
  Separate Windows user is not inherently necessary for those guarantees.
- Unchanged binary still rewrites a shared DPAPI map with process-local locking
  and can clean global HKCU startup entries. Normal-account token/configuration
  write isolation is not achieved by an APPDATA launcher; no app launched.
- Created verified read-only recovery copies of both existing fixed-name local
  DBs plus stable top-level JSON files under private `Recovery/20261106-152133`.
  Both copied DBs integrity OK / zero FK violations. No token export or cloud
  access; personal processes untouched. No test against personal records.
- [Current findings and smallest proposed same-user change](STANDARD_DRIVE_ACCEPTANCE_2026_11_06.md#latest-reevaluation-normal-windows-account-preferred-1525-utc03).
  Recommend narrowly scoped profile-local DPAPI/test startup isolation, using
  existing auth-only backup connect before identity/workspace verification.
  No rebuild, new account, VM/emulator or source implementation performed.

## Persistent low-RAM Drive acceptance strategy (2026-11-06)

- Sandbox closed before owner authorization. Available logs show VM/network
  teardown around 14:53, without a matching WER/OOM event; cause remains unproven.
  No Sandbox reopened. Host ~15.74GiB RAM; ~4.16GiB free after task guests close.
- [Current isolation audit and owner action](STANDARD_DRIVE_ACCEPTANCE_2026_11_06.md#current-checkpoint-persistent-low-ram-strategy-1510-utc03): APPDATA alone cannot isolate secure storage (Known Folders/shared map), default browser or native HKCU startup behavior. Same-user launch refused; no personal token/profile read.
- Verified portable extracted under `D:\AI_Projects\TodorbitPrivateBuilds\standard-acceptance-20261106\Windows\app\Todorbit`.
  Prepared owner-reviewed standard-user setup/guarded launcher outside Git.
  Session is non-elevated; separate `TodorbitDriveTest` identity is not created.
  Owner administrator setup is the next boundary, before Google OAuth.
- One fresh persistent solo Play AVD (2GiB/two cores/720p/SwiftShader) boots, then
  system_server aborts with ART suspend timeout before APK installation. Synthetic
  8MiB transfer/hash passes; app/Sync remain untested. Closed only this task AVD,
  retained all userdata/diagnostics. No new build, suite, cloud or release action.

## Authorized real Standard Sync setup and emulator blocker (2026-11-06)

- From `4dcda12`, reused exact Drive-enabled Windows and registered debug APK
  hashes; no app rebuild, full-suite rerun, code/version change or cloud reset.
  Three unrelated storage-document changes remain preserved.
- Enabled Windows Release runs in fresh Sandbox identity/profile: empty tasks,
  schema27, integrity OK. Scoped `wsb` CLI works despite unavailable native UI
  pipe. Keep Sandbox `bf33024b-2444-481e-93ac-11e626c8597e` open for owner sign-in.
- New Play API35 AVD initially passes separated health samples, then Android's
  installer write stalls and watchdog kills system_server during streamed
  APK installation. File-based preparation also times out. Closed only this
  failed new emulator, preserving userdata/logs; old AVD and phone untouched.
- [Execution receipt and exact minimum sign-in/resume steps](STANDARD_DRIVE_ACCEPTANCE_2026_11_06.md).
  Standard/account selection is now authorized; owner still completes actual
  Google sign-in/consent. Android needs a working environment. No real cloud
  result, original unfamiliar-task reproduction or application defect claimed.

## Owner-approved Drive-enabled private Windows candidate (2026-11-06)

- Owner confirms project/API/scope/audience and Android debug registration; branding
  stays outstanding, production consent unchanged. Only the explicitly approved
  Desktop JSON was read locally; installed structure/client/project validate.
  Converted strict three-field build config remains outside Git with protected ACLs.
- Built exact `d8abbec` in a separate private source archive. Existing outputs,
  profiles, version, tracked disabled config and unrelated storage docs remain
  unchanged. Plugin-junction and UTF-8 log-runner issues were handled without
  changing OS settings or repeating the completed 237.7s Release compilation.
- Enabled config/AOT, signed CRT, packaged native self-test and private
  setup/portable checks pass. No app launch/account/Drive request occurred;
  no Android rebuild, full-suite rerun, publication, push or tag.
- [Exact private paths, identities, validation and owner next steps](PRIVATE_DRIVE_ENABLED_BUILD_2026_11_06.md).
  Await a named approved disposable account/mode and isolated test environments
  before owner-performed Google account selection/consent and A–L execution.

## Real Drive OAuth audit and authorization boundary (2026-11-06)

- Continued `feature/sync-ux-refinement` from `8ef2d98`; application source,
  tracked disabled OAuth configuration, version and private artifact hashes remain
  unchanged. Reused exact-APK package/signature evidence and previous test passes.
- Audited Desktop PKCE/loopback, Android GIS, secure token storage/refresh,
  pairing, error/recovery UI and current official Google setup guidance. Console
  project/client registration and named disposable accounts are not verified.
  Standard is readable JSON; Private encrypts payloads. Both-mode real testing
  without replacing a workspace needs separate fresh approved accounts, one per
  mode and shared across Windows/Android within that mode.
- Build and package guards accept an optional outside-Git OAuth config path;
  defaults, receipt checks and tracked config remain unchanged. A synthetic probe
  confirmed malformed JSON errors could echo field contents; generic parser/read
  errors now prevent that. Sixteen focused fixture/config checks pass, alongside
  the retained default-bundle guard and five script parses.
  Tooling commit: `cdc7229`; documentation follows separately.
  No app build/full Flutter suite/emulator boot was repeated; ADB has no device.
- Real scenarios A–L are BLOCKED before authorization: no Google sign-in, Drive
  request, upload, account data access, reset or cleanup occurred. Existing
  unfamiliar-task incident remains not reproduced. No publication/push/tag.
- [Verified facts, current Console checks, secure private configuration,
  artifact identities, test matrix and exact owner action](REAL_DRIVE_ACCEPTANCE_2026_11_06.md).

## Final private acceptance (2026-11-06)

- Continued `feature/sync-ux-refinement` at `2262ede`; application source and all
  prior artifact identities match. Reused unchanged host, Sync, UI, native and
  live Windows Debug passes; no full Flutter suite or app rebuild repeated.
- Prepared private Windows setup/portable and Android debug APK with SHA-256
  sidecars. Actual clean Sandbox setup/registration, installed/portable schema 27
  (53 tables), integrity, packaged native self-test, in-place setup and
  uninstall/reinstall database preservation pass. No host installer execution.
- Fixed stale Sandbox table-count expectation (26:52, 27:53; unknown schemas
  fail closed). Five harness tests pass; extended two-profile backup round trip
  passes for event projects, named groups/items, attachment bytes and return task.
  No application defect or production-code change was required.
  Acceptance-only commit: `6ba6d81`; binaries retain application source `2262ede`.
- Native Windows automation still reports missing pipe; no Android device.
  Physical input/launcher/IME/accessibility remain open. Windows Release OAuth
  is disabled/empty; Android debug certificate/account registration needs owner
  confirmation. Real Drive testing stops before account authorization/configuration.
  No production profile/cloud, version, tag, push or publication changed.
- [Private artifacts, workflow coverage, acceptance logs, manual checklist and
  exact owner actions](PRIVATE_ACCEPTANCE_2026_11_06.md). Local isolated testing is
  ready; a private beta release claiming full Sync/platform acceptance is not.

## Sync and cross-platform refinement (2026-11-05/06)

- Branch `feature/sync-ux-refinement`, baseline `501e748`. Implements compact
  durable Sync decisions; safe identical-deletion handling; additive schema 27
  for event projects/named checklists; draft attachments, shared filters,
  recurrence/subtask disclosure, navigation visibility and mobile Settings/home.
  Both widget implementations gain date navigation; shared motion and scroll
  treatments retain existing palettes/accessibility preferences.
- No production profile/cloud, release version, tags or publication changed.
  Three unrelated storage documents remain untouched and excluded.
- Full serial integration: 751 passed, 24 failed, 3 opt-in skipped; all 24 failures
  now have passing focused follow-ups. Current analysis is clean; final event/mobile
  batch passes all 50. Reuse unchanged full-suite assertions, with exact invalidation
  and correction evidence in the receipt. Additive migration/journal, Standard/Private
  replay and draft preservation checks pass.
- Windows Release, standalone/packaged native self-tests, isolated startup/resource
  journeys (14) and actual packaged companion launch/reload IPC (1) pass.
  Android Debug (arm64/x64, seven-library alignment) and isolated live Windows
  create/URL-resource/theme/filter journey pass. Live hot reload succeeds with no
  subsequent runtime errors; read-only SQLite confirms schema 27 and saved records.
  Physical Windows/Android and real Drive acceptance stay separate. Computer Use
  initialization fails on missing kernel assets, os error 3; ADB has no device.
- Implementation commits: `9fd95b5` (data/Sync), `6ca103a` (UI/journeys),
  `f26f6b0` (widget date navigation). Source is unchanged since final checks.
  Ready for isolated private testing; release remains gated on physical acceptance,
  real authorized cloud recovery/exchange, exact-candidate CI and release packaging.
  The local Windows Release uses the existing Drive-disabled configuration.
- [Implementation, capability matrix, compatibility, audit and invocation receipt](REFINEMENT_2026_11.md)
  owns the continuation. Resume against its latest source manifest, not dated
  beta12 or earlier platform receipts. Do not publish.

## UI quality beta12 published; further tests skipped (2026-11-04)

- Owner explicitly requests skipping further tests and publishing any new app
  changes. Published coordinated Windows + Android experimental beta12/build35,
  source/tag `31a70d1`, on `feature/ui-quality-beta12`. It includes the six UI
  batches after beta11; the release stays in Pre-release, without latest Stable promotion.
- Skip new test/analyzer/CI/manual/device execution under this candidate's explicit
  owner exception. Preserve prior scoped evidence and all unresolved native/Drive
  acceptance. Retain artifact identity, signing, packaging and checksum integrity.
- [Release notes](UI_QUALITY_BETA_12_RELEASE_NOTES.md) and
  [publication receipt](UI_QUALITY_BETA_12_PUBLICATION.md) record scope, skips,
  commands and actual outcomes. Windows Setup/portable and production-signed
  universal ARM64/x64 APK are built; nine uploaded sizes/digests matched before
  publication. Three unrelated storage documents stay excluded and unchanged.

## Final platform acceptance: environment blocker and guided W01 (2026-11-04; local)

- Continues `227ecf8` on `feature/final-platform-acceptance`. Existing W01-W11,
  N01-N08 and A01-A12 remain the authoritative plan; no repeated generic audit,
  redesign or new product defect/fix. Three unrelated storage documents preserved.
- Native Windows Computer Use still fails on missing pipe. Current-source Debug
  launches in a verified disposable profile; VM environment, Drift, displayed
  path and read-only SQLite agree. `B6 Today` is prepared, with no runtime errors.
  Human subsequently confirms the profile, actual Windows picker, resource
  addition and unsaved title preservation. A subsequent dark/100% report confirms
  correct Notepad content, physical Alt+Tab return, title preservation and visible
  caret, with no issues. User reports Save/editor-reopen passed, then closed the
  app. Readback confirms title/resource, but kind is managed Attachment rather
  than an external link. User confirms Attach a copy was used and cold title/
  resource/kind/viewer checks pass, as expected. Exact focused control is unreported.
  Same binary/profile cold-started as PID30008. User confirms attachment removal/
  editor-reopen and intact original; read-only resource absence/hash corroborate.
  Actual external-link journey is next; no whole W01 pass.
  Personal installed app/companion are untouched. Other native keyboard/Narrator/picker/widget/shell/
  DPI variants remain open; no whole acceptance ID completed.
- Retained Batch6 AVD initially passes two healthy service samples >2 minutes
  apart and actual launcher input. Closed it for resource-safe compilation of a
  current-source x64 development APK; build/native alignment pass, hash retained.
  Its resumed boot then aborts system_server on WifiScanningSer **before install**;
  boot1 coexists with missing package/input/IME/activity services. Failed separated
  preflight stops installation. Guest stopped, data/logs/APK retained, no third
  launch, wipe, uninstall, system workaround or product compensation.
- Compared 417 source/assertion/dependency files with Batch6 manifests: unchanged;
  scoped passes reused without new host suites/native Release/release gates.
  Android `local.properties` restored byte-for-byte. No version/tag/push/release
  or cloud operation; real Drive cross-device acceptance remains separate.
- [Final continuation receipt](UI_UX_PERMANENT_QUALITY_AUDIT.md#final-platform-acceptance-continuation)
  and [outcomes plus active guided W01](UI_UX_PLATFORM_ACCEPTANCE.md#final-acceptance-session-2026-11-04)
  retain failures, exact evidence and remaining manual procedures. Windows is
  awaiting native observations; Android is environment-blocked. App-wide
  acceptance remains **incomplete**.

## UI quality Batch 6: platform acceptance and theme transfer (2026-11-04; local)

- Based on `824332e`, branch `feature/ui-quality-batch6`; protected storage docs
  preserved/excluded. Fixed reproduced Windows theme path truncation at 60 chars
  and asynchronous feedback after dialog disposal. Corrected widget preview
  wording when enabled but its companion is not running; no native behavior change.
- Three focused host cases pass: theme import/Undo/Redo/Cancel/export/save/reopen/
  disposal, populated portable settings across separate on-disk profiles with
  nondefault task display and independent widget device state, and preview
  reconnect/no-write feedback. Scoped analysis clean; unchanged evidence reused.
- Live Windows Driver verifies custom import/Cancel/Save and widget Apply/Cancel/
  Apply-to-All, actual isolated companion start/exit and cold app restart retaining
  appearance/configuration. OS-native picker/physical keyboard/Narrator/DPI/shell
  acceptance remains blocked by missing Computer Use pipe. No physical preview claim.
- Fresh API35 AVD uses separate userdata/host graphics, preserving the original.
  WHPX works; API30 is incomplete. New guest eventually boots/package services
  recover, but offline periods and repeated Bluetooth/HciHal crashes prevent a
  reliable-environment pass in the bounded attempt. No app install/build/wipe;
  original userdata/local.properties preserved, owned processes stopped.
- [Batch 6 receipt and 40-group coverage](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-6-platform-acceptance-and-theme-transfer)
  and [exact human acceptance procedures](UI_UX_PLATFORM_ACCEPTANCE.md) preserve
  failures, blockers and evidence limits. Next: stable Android IME/SAF/Calendar/
  TalkBack, Windows native input/pickers/readers/widgets, then DPI/OEM breadth.
  No push, version/tag/release, personal profile or cloud operation. App-wide
  UI/UX acceptance remains **in progress**.

## UI quality Batch 5: Resources, Templates and startup recovery (2026-11-04; local)

- Continued from `ec43e8e` on `feature/ui-quality-batch5`; the three unrelated
  storage documents remain byte-identical and excluded. Resource URL/label and
  template name prompts now retain input through validation/write failures and
  guard repeated saves. Template creation guards draft approval before awaiting,
  rejects unsupported/incomplete previews, and keeps errors/lists/actions usable
  at 200% text. Duplicate names give a correction instead of raw SQLite details.
- Malformed appearance/calendar JSON and invalid customization stop startup
  without overwriting recoverable bytes. Profile/preflight/privacy failures use
  bounded recovery with Retry; the database path is available for recovery.
  Migration algorithms, schema, backup formats and Sync remain unchanged.
- Disposable fixtures exercise the real startup entry point, schema-1 approval
  and Before upgrade backup, relationships/preferences/integrity, corruption,
  future schema, inaccessible profile and malformed preferences. Existing
  unchanged transaction-interruption evidence is reused. The repeatable Windows
  runner is `tools/dev/test-profile-journeys.ps1`; ordinary runs skip profile-writing
  cases unless explicitly isolated. Resource originals survive reference removal;
  template/routine copies use independent IDs with explicit exclusions.
- [Batch 5 evidence and coverage](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-5-resources-templates-and-startup-recovery)
  distinguishes source, automated, live Windows and blocked physical acceptance.
  Windows Debug URL correction/template save/apply/restart and read-only integrity
  pass. A separate actual corrupted-profile launch and Retry preserve the exact
  damaged bytes and render actionable recovery. API35 system_server again crashed before installation; native Windows
  computer-use pipe is absent. No personal profile, cloud operation, release,
  version bump, tag or push. The initiative remains **in progress**.

## UI quality Batch 4: advanced productivity and recovery (2026-11-04; local)

- Continued from `8842598` on `feature/ui-quality-batch4`, preserving the three
  unrelated storage documents. Goal/Habit editors and linked-work selection now
  protect unsaved changes. Failed link loading cannot submit empty relationships;
  Retry reloads the original selections. Linked progress fits short enlarged views.
- Shared numeric progress/log entry and the milestone editor validate in the
  dialog, retain drafts on write failure, and close only after successful saving.
  Existing calculation rules and repository APIs remain unchanged. Backup history
  failures offer Retry; replacement review scrolls and remains explicit. Startup
  preparation has an opening indicator; upgrade/recovery content scrolls safely.
  Synchronous activation guards prevent duplicate pending saves/review dialogs.
- Populated habit correction/history/rest/archive and goal completion/archive/
  linked-progress checks pass. A synthetic representative database round-trip and
  actual Windows create/cancel/schedule/process-restart restore pass structural
  comparison; all 46 product tables in the live sample match, with the changed
  state retained in Before Restore. SQLite integrity and foreign keys pass.
- Exact invocations, failures, reused evidence, platform observations and updated
  40-group coverage are in the [Batch 4 receipt](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-4-advanced-productivity-and-local-recovery).
  The initiative remains **in progress**: resource picker/open/relink failure and
  template/routine workflows, actual legacy/interrupted migration recovery and
  wider accessibility/device acceptance remain for the next coherent batch.
  Android Debug compilation succeeded, but system_server/package-service crashes
  prevented installation on the disposable API35 emulator. No app-runtime pass;
  overlay stopped and original local.properties restored byte-for-byte.
  No cloud account/data action, publication, version bump or schema change.

## UI quality Batch 3: populated workflows (2026-11-04; local)

- Continued from `7a5d0ed` on `feature/permanent-ui-quality`. Fixed nested subtask
  and recurring-series draft loss, protected occurrence edits before series Apply,
  and cleared only successfully saved prerequisite changes from dirty tracking.
  Submitted snapshots keep edits made during a pending prerequisite save dirty.
- Corrected short enlarged subtask validation, recurring-form viewport, dense Week
  readability, overnight continuation labels on both Calendar adapters and long
  Trash confirmation scrolling. Existing components, tokens and safety decisions
  retained; no data model, repository, scheduling, Sync or backup protocol changes.
- Eight advanced task cases and five populated Calendar/recovery cases pass.
  Explicit approved-series/composition/Calendar regressions and six parent
  navigation cases pass. Focused eight-file CLI analysis passes; the connected
  analyzer attempt was interrupted without a result. Detailed failures, fixture
  corrections, source hashes and reused evidence are in the
  [existing audit receipt](UI_UX_PERMANENT_QUALITY_AUDIT.md#batch-3-populated-workflows-and-platform-acceptance).
- Actual isolated Windows Driver created a parent and nested child; read-only
  SQLite `quick_check=ok` and parent link verified. Located the retained SDK/JDK
  and ran an API35 Android emulator with a read-only temporary AVD overlay.
  Native Back, rotation, Calendar modes, enlarged text, dark theme and task/theme
  persistence through Debug rebuild/restart observed. Debug Driver entry points
  now forward Android background workers; no production entry-point change.
  Native launcher Tasks configuration/Apply/populated rendering and task-title
  deep link observed; Calendar launcher widget remains unbound/untested.
- Initiative remains **in progress**. Next: populated goal/habit/resource/template,
  startup recovery and successful disposable backup/restore journeys, plus the
  outstanding platform matrix. Windows physical keyboard/DPI/Narrator/native
  widgets and Android physical devices/IME typing/TalkBack remain unaccepted.
  No push, tag, release or version bump. Unrelated storage work preserved.

## Comprehensive UI quality continuation (2026-11-04; local checkpoint)

- Verified and committed the prior 20 task files as `c32329c` on
  `feature/permanent-ui-quality`; all three unrelated storage documents preserved.
  Permanent skill routing/reference and unchanged Sync evidence reused.
- Implemented draft protection across desktop close/navigation/task/search/view/
  template/deletion paths and retained inline drafts across resize. Enabled
  Calendar/nested editor guards and contextual task completion semantics.
- Corrected enlarged Calendar labels/period, event/session date controls, Smart
  Reschedule/availability, Task Preferences, sidebar reorder names, report metrics/
  range/dates, Focus clock and schedule-history heading/close name. Reused current
  typography, palette and action bars; shared DateTimeButtonRow uses AppSpacing.
  No schema/protocol/repository/native/backup changes, push, build publication or
  version bump.
- [Existing audit ledger](UI_UX_PERMANENT_QUALITY_AUDIT.md#continuation-high-use-workflows-and-remaining-surfaces)
  now contains per-finding fixes, 40-group progress/remaining samples, exact
  invocations and source identities. New geometry/behavior checks and focused
  existing regressions pass across recorded scopes; actual isolated Windows
  Driver preserves/saves a draft, toggles/undoes settings and starts/pauses/stops
  the timer. Reused passes are distinguished from reruns.
- Comprehensive objective remains **in progress**. Next coherent batch: populated
  composition/resources/series/goal/habit/history/transfer flows and isolated
  startup-recovery short-window reproduction. P3 shell brand wrapping remains.
  Physical Windows keyboard/Narrator/DPI/native widgets, Android device/launcher/
  IME/TalkBack and disposable-account two-device Drive are unverified; computer-use
  native pipe and adb-on-PATH were unavailable. Widget editor offscreen footer
  capture is intermittent despite passed bounds/tap assertions; inspect live
  before claiming paint stability. Do not rerun unchanged passing gates or treat
  this checkpoint as complete app/release acceptance.

## Permanent UI quality and Sync usability (2026-11-04; local)

- Branch `feature/permanent-ui-quality`, baseline `25874c0`; unrelated storage
  documentation preserved. Root routing now mandates the canonical UI skill for
  direct/indirect UX impact and recognizes approved Drive Sync separately from
  snapshots. Expanded skill: 67 actionable categories, UX Necessity Review,
  implementation/experience inspections, seven coverage dimensions and local-first
  recovery guidance; small tasks load relevant references only.
- Cohesive Sync pass corrects Android's encryption claim and code-only unlock
  label, prioritizes routine controls, discloses replacement under Recovery with
  automatic pending-review expansion, and reuses secondary text roles. Existing
  guards/crypto/conflicts/data protocols remain; no version change or publication.
- [Audit, 40-group inventory, routing scenarios and exact invocation ledger](UI_UX_PERMANENT_QUALITY_AUDIT.md):
  focused widget/analysis and isolated Windows Debug/Driver/hot reload/restart
  evidence, including failures/corrected fixtures and reuse. Physical Android,
  native widget/input/DPI/reader and live two-device Drive acceptance remain open.
  Next: paired disposable-account runtime acceptance, then populated advanced
  forms/native widgets. No full-app polish/accessibility claim or release.

## Experimental Start New Sync beta 11 published (2026-11-04)

- Published [v1.0.19-beta.11](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.11), experimental/prerelease, not Latest Stable; version `1.0.19-beta.11+34`, source/tag `c8f1561`, branch `feature/start-new-sync-beta11`.
- Start New Sync preserves current local records/history and a verified backup, uploads/readback-verifies a fresh Standard/private workspace, commits isolated generations and only then removes selected retired cloud content. Durable resume, stale-device reconnect, fork detection and cleanup retry; typed errors/actions and shared narrow/large-text UI.
- Focused safety/legacy/controller/UI/production-adapter/Android error checks pass. A stalled UI harness was corrected; a reproduced privacy-label-after-cleanup-failure regression required replacement platform builds. Only corrected-source binaries uploaded. Nine anonymous hashes/metadata/Range checks and updater beta10->beta11/Stable exclusion pass; prior releases, private draft and tags unchanged.
- [Release notes](SMART_SYNC_BETA_11_RELEASE_NOTES.md), [receipt, exact checksums, commands and manual checklist](SYNC_START_NEW.md). Full suites/broad CI/emulators deliberately skipped; live Drive/physical upgrades remain unverified. Original three storage documents preserved/excluded; no main merge or website deployment.

## Experimental optional Sync encryption beta 10 published (2026-11-04)

- Published [v1.0.19-beta.10](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.10), experimental/prerelease and not Latest Stable, version `1.0.19-beta.10+33`, source/tag `ed23095` based on `06b9ded`. Branch `maintenance/smart-sync-beta10-release`; original three storage documents preserved and excluded.
- First Windows/Android builds PASS; nine assets, Android production signature/code33, exact ZIP/runtime/licensing, updater beta9->beta10 selection/Stable exclusion and all anonymous full-download hashes PASS. Prior releases/tags unchanged. Three helper cases passed; one updater preview fixture was corrected and passed. A final historical comparison decoding error was diagnosed without repeating passed downloads. Owner explicitly skips broad CI/full suites/emulators; no live Drive or physical upgrade acceptance claimed.
- [Release notes](SMART_SYNC_BETA_10_RELEASE_NOTES.md) and [publication receipt](SMART_SYNC_BETA_10_PUBLICATION.md) record actual outcomes and limitations, including unavailable mode conversion/passphrase changes.

## Local Sync manual builds (2026-11-04)

- Application source stays `06b9ded` on `feature/sync-optional-encryption`; no version, signing configuration, conversion or cloud change. Three paused-cleanup documents preserved.
- Owner authorized one Windows Release bundle and one production-signed GitHub APK, reusing existing toolchains/caches and implementation test evidence. No unit/integration/emulator/live Drive tests or publication.
- Both first build invocations PASS: Windows Release bundle and production-signed GitHub universal APK (ARM64/x64), unchanged beta-9 version/code 32. Existing signing/OAuth source configuration preserved; no app launched or installed. [Receipt, exact artifact paths, safe profile/install instructions and owner checklist](SYNC_MANUAL_BUILDS.md).

## Standard and optional private Sync (2026-11-04; local feature)

- Branch `feature/sync-optional-encryption`, baseline `13e2734`; paused storage cleanup documentation preserved and excluded. No version, package, release or push.
- New Standard workspaces use no extra password; shared Windows/Android pairing detects mode/schema, preserves legacy encrypted recovery and reuses causal merge/outboxes/backups. Optional **new workspace** private setup adds Argon2id-wrapped random keys, passphrase/recovery unlock and recovery acknowledgment.
- **Mode conversion and passphrase changes remain unavailable**, explicitly shown in Settings; current immutable journal protocol lacks a remote generation fence. No unsafe conversion, cloud deletion or migration-success claim.
- [Implementation, verification receipt, limits and owner checklist](SYNC_OPTIONAL_ENCRYPTION.md); [persistent pre-test ledger](TEST_RUN_LEDGER.md) now routes future sessions to prior evidence and prevents unjustified reruns.
- Real Google Drive/physical-device acceptance is deferred to the owner. Targeted analysis passes; corrected controller/adapter/UI checks pass, with earlier failures and justified reuse recorded. No full suite/build requested.

## Experimental Smart Sync beta 9 published (2026-11-04)

- Published [v1.0.19-beta.9](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.9),
  version `1.0.19-beta.9+32`, tag/app source `a69dd63523f530ca69e547e5439725dbb8ed80aa`.
  Includes `e7eedc1`, `9fe20f5`, `292175c`; prerelease only, `--latest=false`.
  Schema 26/protocol 1/encryption/backups/signing/profile identities unchanged.
- Exact-source Windows CI PASS full analysis/635 tests/one existing skip/native/
  Release/packages. Android CI PASS 72 host checks/two emulator integrations;
  only an SDK corrupt-download job was rerun. Local enabled Windows Release,
  native writer/workers/CRT/self-test, production APKs/private AAB and integrity pass.
- Actual beta 8 -> beta 9 Windows installed/portable upgrades retain tasks/theme,
  integrity, repeated startup and uninstall data. Guest theme fixture was corrected
  to seed both SQLite and its JSON cache; no product/assertion weakening. Actual
  production Android 16 KiB upgrade code 31 -> 32 retains task/completion/restart,
  no crash/ANR observed. Receipts/screenshots checked.
- All 11 public assets fully downloaded anonymously and SHA-256 verified;
  previous releases/assets/tags unchanged. Production public updater selects
  beta 9 from beta 8 for Windows modes/Android ABIs and excludes Stable.
- Real Drive end-to-end exchange is NOT VERIFIED; no disposable account/profile
  used. Windows unsigned, physical ARM64/OEM/Windows input/DPI/reader and OS
  background acceptance remain open. Preserve backup/recovery code and test
  disposable data on both updated devices before considering broader promotion.
- [Publication ledger, CI, hashes and limits](SMART_SYNC_BETA_9_PUBLICATION.md),
  [release notes and short manual checklist](SMART_SYNC_BETA_9_RELEASE_NOTES.md).

## Smart Sync comprehensive verification (2026-11-03; local fixes)

- Branch `maintenance/smart-sync-verification`, baseline `4987a46`; published
  beta 8 application remains `dd36189`. No push, merge, version/tag change or
  new release. App fix `e7eedc1`, Sandbox harness `9fe20f5` are local only.
- Confirmed two beta-8 defects using the real Drive adapter over synthetic HTTP:
  interrupted completed uploads leave an absent readback marker that blocks
  receivers/proof setup, and socket/HTTP exceptions incorrectly block durable
  offline decisions. Fixed authentication/receipt handling and transport-state
  classification; encryption, identity/causal checks and outgoing acknowledgements
  remain required. No observed data loss; no real account/profile accessed.
- Current-source full serial suite **635 PASS/one existing skip**, 1180.43s;
  four-root direct analysis clean, 313-file format clean. Seven new contracts
  cover both-direction CRUD/preferences, interrupted/retried exchanges, wrong
  code/tamper rejection, offline/restarted bulk decisions and new divergence.
  Python helpers pass eight/11/three plus the focused Full-plan gate assertion.
- Actual published Windows Sandbox install/portable/startup/native self-test,
  populated upgrade/uninstall preservation/reinstall PASS. Actual published
  API-35 Android APK fresh install/home/Sync light/dark/200% text/Close inspected.
  Prior production-signed 16 KiB upgrade remains valid evidence. Corrected-source
  Windows Debug build/startup and real hot reload/restart PASS; Driver inspects
  Sync dark/light and retained theme, no runtime errors. Native UI automation
  kernel is unavailable; physical keyboard/DPI/reader acceptance remains open.
- Measured ~90.3 GB repository, 63.1 GB in `.buildlog`; USB D flush latency and
  severe RAM contention observed. Isolated C checkout/temp and sequential heavy
  checks used; no cleanup/security changes. Flutter analyzer wrapper still stalls;
  direct analysis succeeds. No unsupported speedup/antivirus-cause claim.
- No disposable Google account available: **real Drive exchange remains NOT
  TESTED**. Beta 8 is not ready for broader promotion; fixes are not shipped.
  [Complete report, coverage, manual procedure and download-count commands](SMART_SYNC_VERIFICATION.md).

## Experimental Smart Sync beta 8 published (2026-11-03)

- Published [v1.0.19-beta.8](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.8)
  at 17:45:51 UTC, version `1.0.19-beta.8+31`, application/tag source
  `dd36189c74548b14ed49fea8b12344ba4d0966fe`; prerelease only, not latest Stable.
  All five Smart Sync commits are included. Schema 26/protocol 1 remain unchanged.
- Windows exact-source CI: 628 passes/one existing opt-in skip, analysis, native
  checks, Release and packaging. Android exact-source CI and production APK/AAB
  signing gates passed. Enabled Windows local build and isolated schema-26
  startup passed. Eleven public assets passed integrity and anonymous checks.
- Production beta 7 code 30 upgraded in place to beta 8 code 31 on the 16 KiB
  Android guest; a synthetic task survived, completed and survived cold restart.
  First runtime job failed on transient UIAutomator capture before candidate
  upgrade. Harness-only `4ce4d37` fixes bounded capture/retry without changing
  app bytes or weakening assertions; rerun passed with screenshots inspected.
- Public production updater selectors accept beta 8 from beta 7 for Windows
  installed/portable and Android ordered ABIs/universal fallback; Stable excludes
  it. Previous published releases/assets/tags remain unchanged.
- Real Drive end-to-end exchange and full physical Windows/Android acceptance
  remain pending. No owner profile/account was used; Windows is unsigned.
  Next task: comprehensive acceptance using disposable profiles and test data.
- [Publication receipt, invocation ledger, hashes and limits](SMART_SYNC_BETA_8_PUBLICATION.md),
  [release notes](SMART_SYNC_BETA_8_RELEASE_NOTES.md).


## Smart Sync implementation checkpoint (2026-11-03; before beta 8 publication)

- Branch `feature/smart-sync-redesign`, baseline `0dcfb5a` / published beta 7
  runtime `2919551`. Audit `4b26af5`, orchestration `eee62a6`, UI `c9784cf`,
  final orchestration/metadata corrections `f718cbe`.
  No version/schema/protocol change, release, push or merge.
- Sign-in continues into secure setup/exchange; additional devices authorize
  once with the retained recovery key. Startup/resume/active polling/local
  debounce share existing incremental exchange. Offline decisions remain causal
  journal operations. Main Sync is compact, with advanced recovery and counted
  nonmodal conflict attention, individual/bulk review and final confirmation.
- Final focused regression: 38 PASS (engine, pairing, controller, 21 UI cases and
  both subprocess crash rollbacks). Final orchestration: 18 PASS, including
  manual intent during automatic checks, in-flight edits, metadata-only/native
  scheduling gates and offline/concurrent two-device resolution. Counts overlap.
  Real-file fixtures use production background/WAL execution and genuine backup
  gates. Original AppController refresh notifications/API are preserved.
- Sixteen host PNGs and an actual isolated Windows dark dialog/Driver inspected;
  two hot reloads passed. These do not establish real OAuth/provider or physical
  Windows/Android acceptance. No real Drive account or owner profile used.
- All four source roots pass direct Dart analysis; format passes for 312 files.
  Python preparation/helper checks pass 11/eight; changed-document links and
  feature catalog have zero errors. Final Full attempts
  `20261103-175447-3675` and `20261103-180243-8677` stopped during silent Flutter
  analysis startup. Direct full serial tests stopped after two passes and over
  four minutes loading the next unchanged file. No aggregate Full pass claimed.
- Task TEMP/TMP/JVM temp is on D:. The initial C: 20–70 MiB/memory constraint
  later eased; only this task's verified stopped compiler output was archived
  intact. No user files/shared caches deleted. Initial Android builds stopped
  under pressure and are not APK acceptance evidence. Synthetic profiles remain
  isolated under `.buildlog/smart-sync/`.
- Current Windows Release attempts reached CMake/MSBuild/Flutter compilation
  but did not finish; no new binary accepted. Owned process trees were stopped.
  Android runtime, real Drive, physical Windows focus/DPI/accessibility and full
  aggregate gates remain pending. No final-source live reload pass: app closed.
- Remaining integration outcomes and real-provider/manual acceptance are in
  [Smart Sync ledger](SMART_SYNC_REDESIGN.md). Do not repeat valid unaffected
  evidence or use an owner's profile/Drive account.

## UI quality beta 7 published (2026-11-03)

- Published [v1.0.19-beta.7](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.7) at
  `2026-11-03T10:35:16Z`, runtime/tag source `2919551`, version
  `1.0.19-beta.7+30`, schema 26. Prerelease only; previous public releases/tags
  preserved. The rejected beta 6 draft remains private and unchanged.
- Mandatory 16 KiB beta 6 runtime found code-5 startup locking. Added the existing
  bounded five-second wait to startup schema/backup read connections. Real-lock
  tests reproduce before correction and pass after; persistent locks still fail
  without replacing data or bypassing integrity checks. Focused startup,
  migration and backup regressions: 39 pass.
- Fresh exact-source Windows CI: 601 pass/one existing opt-in skip, eight helper
  checks and all native/package gates. Android CI: 72 host/11 preparation/two
  emulator integrations. Exact final signed APK passes the original 16 KiB
  save/cold-reopen/completion/no-crash checks.
- Enabled Windows Release, CRT, native self-test, writer/worker, Setup and
  portable gates pass. Production-signed universal/ARM64/x64 APKs and private AAB
  pass identity/alignment; signer retained. All eleven public files pass
  integrity, anonymous delivery and actual production updater selection,
  including Windows modes, Android ABIs/universal and Stable exclusion.
- [Receipt, hashes and invocation ledger](UI_UX_STAGE2_PUBLICATION.md),
  [notes](UI_UX_STAGE2_RELEASE_NOTES.md), [audit/manual checklist](UI_UX_STAGE2_AUDIT.md).
  Original shaking remains unreproduced; wider launcher/IME, physical Windows
  input/DPI and assistive-technology acceptance remain explicit manual gaps.
  No owner-profile test, installer execution, Sandbox or Play publication.

## Rejected beta 6 preparation history (2026-11-03)

- User explicitly authorized publication after the Stage 2.1 local verification
  checkpoint `9240364`. Selected unused `1.0.19-beta.6+29` after public release
  and remote-tag inspection; schema 26 and production signer remain unchanged.
- [Release checkpoint and mandatory gates](UI_UX_STAGE2_PUBLICATION.md),
  [candidate notes](UI_UX_STAGE2_RELEASE_NOTES.md). Publication is pending exact
  candidate CI, production artifacts, integrity, runtime and delivery gates.
- Runtime candidate `e8419c7` pushed. Exact Windows CI `41584177622` passes full
  analysis, 597 tests/one existing skip, eight helper checks and native/package
  gates. Android CI `41584178103` passes 72 host/11 preparation checks and two
  real emulator integrations. Local enabled/signed artifacts and final 16 KiB
  runtime/draft/public delivery gates remain pending.

## Stage 2.1 targeted UI follow-up (2026-11-03)

- Clean baseline `41cd34f`; branch `fix/stage2-1-ui-verification`.
- Fixed Windows calendar agenda projection/painting of per-event colors and
  built-in icons, including inherited/occurrence styles and old-column defaults.
  Embedded 5 KB subset of the existing Flutter font; no package/schema/settings
  format changes. Release build/self-test and live HWND style watcher/recreation
  checks pass. Light/dark icon atlases inspected.
- Expanded Android footer geometry/glyph/density harness and added focused
  IME/error probes; see the
  [Stage 2.1 ledger](UI_UX_STAGE2_AUDIT.md#stage-21-follow-up--2026-11-03).
  Original shaking is not reproduced; no speculative Flutter patch. Eighteen
  host cases pass across scoped runs; direct test-source analysis is clean.
  Inline movement is one 9 px caret reveal, then stationary.
- Windows physical input automation remains blocked by missing kernel assets.
  Native rendering/lifecycle do not certify physical DPI, input or Win+D.
  No data reset, version bump, release or remote operation.
- Native implementation checkpoint `49f8df0`; host probe checkpoint `3b61eb1`.
  Windows full local Release helper passed (18m57s, signed CRT/Drive metadata
  checks), and packaged native self-test passed. Added explicit distribution of
  the attributed font license. A later optional font-cache refinement was
  discarded after an unsuccessful rerun/diagnostic; the restored packaged
  self-test passed (exit 0). Final artifact hashes/version metadata recorded.
  Packaging checkpoint `f6fc308`; Android probe checkpoint `1523d7e`.
- Original Android footer PNGs re-inspected at full size: both action labels
  are complete; withdraw the original sample-specific clipping interpretation.
  Expanded 192-case harness compiled (6m39s) but did not execute. Retained guest
  suffered system-service death/ANRs and install broken pipe; fresh API35 guest
  never reached ADB. Incomplete API30 image was not replaced. No speculative
  Android product patch. Task guests stopped, files retained and original AVD
  hardware configuration restored; original IME preference restored.
- Native keyboard/error, OEM launcher placement/resizing, TalkBack, Narrator,
  physical DPI/multi-monitor and companion-process relaunch remain manual.
  Prior Android bootstrap APK predates `69acf07`; prepare a fresh acceptance
  APK for a stable phone/emulator. Stage 2's unchanged broader host evidence is
  reused. No claim that all acceptance checks or all reported issues are closed.
- Local Stage 2.1 verification is complete within the documented tooling limits.
  The user subsequently authorized publication; release versioning, exact-source
  CI and package gates are a separate checkpoint and must pass before publishing.

## Windows/Android UI audit, Stage 2 (2026-11-02)

- Branch `fix/stage2-ui-quality`, clean baseline `f7954d4`. Inventoried 39
  surface families and applied the updated Ultimate UI/UX audit references.
- Eleven grouped repairs cover mobile event icon/color rendering, anchored
  settings selectors, shared select refresh, symmetric mobile editor gutters, draft interval
  assistance, inclusive all-day End picker, and overflowing color/timer dialogs.
  Added accurate More selection for drawer views and readable habit interval
  guidance. No version/schema/backup/cloud behavior or release changes.
- Main fixes committed as `cc20582`: 593 host tests pass / one existing opt-in
  skip, full analysis clean. Follow-up `69acf07`: clean targeted analysis,
  24 regression tests plus narrow navigation label/touch-target checks pass.
  Isolated companion self-test and 72 native Android render/capability captures
  pass their assertions; visual sample limitations remain separate.
- Actual Windows debug and fresh Android API-35 UI samples include saved event
  color, duration-preserving date change, native keyboard at 200% text and final
  More selection. [Full inventory, root causes, commands and gaps](UI_UX_STAGE2_AUDIT.md).
  Original shaking sequence remains un-reproduced; Windows native event-color
  parity and suspected native Android footer clipping are tracked separately.
  Physical shell/DPI/OEM/assistive-tech and real accounts remain unverified.
- Evidence and synthetic profiles stay under ignored `.buildlog/verify/stage2-ui/`.
  Personal data/previous AVDs were not opened/reset. No remote push or publication.

## UI quality engineering skill, Stage 1 (2026-11-02)

- Upgraded repository-local `ultimate-ui-ux` on baseline `3bb6e8b`; retained all
  28 categories/303 original symptom-repair entries and added diagnostic,
  verification and shared-regression guidance. Added audit inventory/coverage,
  Flutter Android/Windows engineering and targeted verification references.
- Kept the entrypoint concise with section-based loading. Added configured-color,
  dependent-date, overlay, validation/scroll and proactive related-consumer rules;
  preserved Todorbit tokens, Fluent/platform/data safety and native evidence gates.
- Documentation/skill validation and limitations are recorded in the
  [upgrade ledger](UI_SKILL_INTEGRATION.md#stage-1-ui-quality-engineering-upgrade).
  Standard validator still lacks PyYAML; strict metadata/reference/preservation
  checks are used. No application audit, fixes, builds, data/version or release
  changes. A future Stage 2 audit remains a separate task requiring instruction.

## Primary UI/UX skill integrated (2026-11-02)

- Installed the user-provided `ultimate-ui-ux` package unchanged in
  `.agents/skills/ultimate-ui-ux/`. Root guidance requires it for every UI task;
  the workflow applies checks proportionally across Windows/Android.
- Removed redundant project-local UI review skill, preserved its Todorbit
  constraints in the workflow, and retained regression tooling and global skills.
  Updated AGENTS, Codex workflow, Testing and Decisions; no app/data/version or
  release changes. [Installation and verification ledger](UI_SKILL_INTEGRATION.md).
- Package equality, metadata/reference/routing and documentation checks passed.
  Standard validator lacks PyYAML; the fallback checks the manifest's simple
  YAML subset. Fresh-session skill-selector invocation remains unobserved; use
  the documented read-only discovery check and restart only if needed.

## UI hierarchy beta 5 published (2026-11-02)

- Published [v1.0.19-beta.5](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.5)
  for Windows + Android, version `1.0.19-beta.5+28`, Android code 28, schema 26,
  runtime/tag `1cef226`. Previous releases/tags/assets remain unchanged.
- Shared typography/semantic surfaces, quieter settings, field-first conflict
  review, grouped restore guidance, scrollable progress dialogs and flexible event
  colors. Recovery input stays visible above Android IME at 200% text.
- Windows CI: 578 pass/one existing skip; Android: 71 host/11 preparation/two
  integrations; exact production APK real 16 KiB runtime passed. Package/signing,
  portable swap/rollback, retained Android data/widgets and anonymous updater gates pass.
- Actual Windows debug and Android Release observations are distinguished from
  offscreen/widget and source-only review. No real Drive sync E2E, physical shell,
  DPI/OEM/TalkBack acceptance is claimed. Windows remains unsigned.
- The completed Windows guest was confirmed closed when the owner requested no
  Sandbox use; no subsequent Sandbox launch or use. No personal data, secrets or private logs were committed.
- [Audit, skill application, before/after images and full invocation ledger](UI_HIERARCHY_AUDIT.md).
  [Publication receipt, downloads, hashes, reruns/reuse and limits](UI_HIERARCHY_PUBLICATION.md).

## Encrypted sync beta 4 published (2026-11-02)

- Published [v1.0.19-beta.4](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.4)
  for Windows + Android, version `1.0.19-beta.4+27`, Android code 27, schema 26,
  exact source `67b265d`. Existing releases, signer/AppId/profile/IPC identities remain.
- Full engine powers Sync Now, encrypted recovery-code pairing, automatic exchange,
  durable consolidated conflicts and bounded platform workers. Restore retains
  pre-restore queues/ciphertext and uses a fresh device identity. Portable settings
  preserve local controls; imported running timers have explicit ownership.
- Exact-source CI passes: 568 host tests, one opt-in skip, full analysis, native,
  worker and packaging checks. Real 16 KiB artifact runtime, signed Android gates,
  retained emulator upgrade, clean Windows installation/data retention, portable
  swap/rollback and final package SHA-256/updater/anonymous delivery checks pass.
- Clean-machine acceptance found missing Microsoft C++ runtime deployment. Final
  packages include signed runtime DLLs with audited receipt and packaging gates;
  a fresh unchanged-package Sandbox acceptance passed.
- Drive uses mocks only. Physical ARM64/OEM/Windows interaction, Windows 10 and
  Android system-installer approval remain unobserved; owner performs final
  physical/UI acceptance after publication. Real Drive authorization was not used.
- [Publication receipt and all hashes](DRIVE_SYNC_BETA_4_PUBLICATION.md),
  [pairing/manual guide](GOOGLE_DRIVE_SYNC.md),
  [complete implementation and failed/rerun ledger](DRIVE_SYNC_RECOVERY_CHECKPOINT.md).

## Sync button preview published (2026-11-01)

- Published [v1.0.19-beta.3](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.3)
  for Windows + Android, build/code 26, source `c47be13`, schema 22.
- Sync opens Coming soon; full synchronization is not enabled. The unfinished
  engine and schema 23-25 migrations remain separate and unpublished.
- Tests/CI were explicitly waived by the owner for this button-only release.
  Builds, package signatures/identity/alignment and all 11 public asset hashes
  passed. No live UI, installation or real Drive acceptance is claimed.
- [Publication receipt and exact assets](SYNC_BUTTON_PREVIEW_PUBLICATION.md).
  Full sync work resumed after this publication; see the current checkpoint above.

## Drive sync and restore implementation in progress (2026-10-31 to 2026-11-01)

- Branch `feature/drive-sync-recovery`, baseline `f62cd7b`; coordinated release
  authorized only after all gates. Owner currently permits mocked Drive only.
- Restore staging no longer performs fallible cloud-history work after committing
  its restart marker. Baselines travel with applied/opened receipts. Interrupted
  finalization recognizes exact restored contents and retains the original Before
  Restore copy; subsequent edits are protected. Original phone exception remains
  unmeasured; this fixes a reproducible matching lifecycle defect.
- Embedded backups now scroll with Settings; pending restart/cancellation passes
  compact light/dark at 1.5x text. Initial 69 focused checks passed; later local
  retry/data checks and final eight UI checks retained per the ledger.
- Commits `b0b254a` (restore), `dcb578a` (causal/encrypted primitives) and `c0037a3`
  (isolated Drive batches/change feed) are local and unpublished. Fifteen causal/
  codec checks and 17 mocked transport checks pass.
- Source schema 23 adds inactive SQLite capture for 41 portable tables. Nine
  journal checks cover verified activation, native-connection capture, rollback,
  replay ancestry, key moves, managed bytes, device path exclusion, restore
  quarantine and the public schema-22 upgrade. The broader affected pass has 104
  checks. Full host run: 480 pass/one opt-in skip/five stale assertions; all five
  corrected in a 55-test follow-up, with unaffected passes retained. Native
  Release/self-test and actual native-repository capture against a Dart-created
  synthetic schema-23 database pass; no duplicate completion journal entry.
- Draft schema24 now persists encrypted batch retries/receipts and transaction
  group bounds across wire batches. Incoming history is authenticated and
  retained without changing visible data. Native recurring completion capture
  and duplicate delivery pass against an isolated actual-schema fixture.
  Received history remains separate from visible observations. Latest detailed
  verification and the lazy-reopen fix are recorded in the linked ledger.
- Draft schema25 adds exact applied visibility intervals and merged visible
  parents. The schema24 migration retains/requeues original operations while
  archiving their old ciphertext. Portable review separates modification metadata
  from user-value decisions. Focused migration/crash/backup/lease checks and actual
  native recurring capture with visibility pass. Full host integration: 524 pass,
  one existing opt-in skip; full analysis/format and Python/docs checks pass.
  Final helper diff failure was one catalog EOF blank line, corrected separately
  without repeating runtime checks. Details and limits remain in the ledger.
- Controlled remote-apply fixtures now pass (14), plus killed-apply/incoming/lease
  regressions (16). Original groups merge/apply atomically, related conflicts stay
  retained, recurrence is not replayed, and stale editor/local-file races are
  protected. This is not connected to the app's network or startup lifecycle.
- Sync is not operational. Pending: completed exchange/checkpoints, model-wide
  acceptance, persistent conflict resolution, pairing/UI, portable preferences,
  active-timer ownership, platform workers, completed restore reconciliation and
  exact-source release gates. No version/tag/release or personal data changed.
- [Implementation boundary and every verification/rerun](DRIVE_SYNC_RECOVERY_CHECKPOINT.md).

## Android beta 2 published; testing policy finalized (2026-10-31)

- Published [v1.0.19-beta.2](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.2),
  code 25, at 16:18:52 UTC / 19:18:52 Amman. Tag/source `500a9a8`; unchanged signed
  ARM64/x64/universal 25.53/27.05/51.61 MB packages, metadata/notes/checksums only.
  All 16 previous releases/assets, beta 1 and Windows unchanged; no tag moved.
- Runtime hold cleared on official API 36, 16 KiB revision 7, Linux/KVM, Emulator 37.2.13:
  [41218583203](https://github.com/2HIK4/Todorbit/actions/runs/41218583203) passed
  healthy no-app baseline, exact APK render, SQLite task restart/completion and
  no crash/ANR. API-35 r05 guests failed without Todorbit on Windows and Linux;
  precise upstream cause unestablished. No application fix/rebuild was needed.
- Reused exact-source Windows CI 451 tests/one opt-in skip, Android CI 71 host/two
  integrations, signing/alignment/private AAB/security and preservation evidence.
  No full suite, OAuth, Sandbox or broad widget acceptance repeated. Every new
  diagnostic/runtime/distribution invocation and rerun reason has a ledger.
- Anonymous public downloads/checksums, ABI selection/fallback, Stable exclusion,
  actual public beta 1 → beta 2 app download/native verification/system approval pass.
  All 45 tables, attachment/backups/preferences/widget config retained. Installed
  APK matches public x64 hash/certificate. Emulators stopped, test data retained.
- `ac9a884` persists receipt-first testing, evidence reuse, Quick/Feature/Critical/
  Release levels and per-invocation ledger in AGENTS/Testing/Codex workflow.
  Artifact-only runtime harness `d642fe5` is separate from immutable package source.
- Physical phone/OEM/ARM64 16 KiB and Windows/Android Drive interoperability remain
  owner testing limits. [Publication receipt](ANDROID_BETA_2_PUBLICATION.md),
  [phone guide](ANDROID_BETA_2_PHONE_TESTING.md),
  [investigation ledger](ANDROID_BETA_2_RELEASE_CHECKPOINT.md).

## Android beta 2 prepared; runtime publication hold (2026-10-31)

- Candidate `500a9a8` on `feature/android-mobile`: `1.0.19-beta.2+25`, fresh
  signed ARM64/x64/universal APKs and private Play AAB. No code-24 artifact reuse.
  Both exact-source CI workflows passed: Windows `41213677399` (451 tests,
  one opt-in skip, Release/native/package gates); Android `41213677390`
  (71 host checks, two emulator integrations). Signer/identity/alignment/bundle,
  five JVM signing tests and 940-entry credential audit passed.
- Populated production beta 1 code 23 passed native verification and actual
  Android installer approval to final beta 2 code 25. Play Protect scan reported
  the app safe. All 45 tables, attachments, existing backups, settings and widget
  configuration compare identical. Public discovery/download upgrade is pending.
- **Publication stopped:** the mandatory 16 KiB runtime guest showed system-wide
  and Todorbit crashes; cold boot also failed with system death. Alignment and
  later task/reopen observations cannot substitute for a valid runtime pass.
  Cause remains unresolved. Do not publish draft ID `430022327` as-is; ARM64
  and universal uploads were interrupted. Both emulators stopped/data retained.
- Next: diagnose the retained 16 KiB guest/lifecycle failure or validate in a
  healthy supported environment, then complete/reconcile draft assets and run
  public verification after authorized publication. All 16 existing releases,
  including beta 1 and every Windows asset, remain unchanged. No tag moved.
  [Exact artifacts, evidence, pending gates and signing guidance](ANDROID_BETA_2_RELEASE_CHECKPOINT.md).

## Update recovery, decimal sizes and ABI delivery (2026-10-31)

- Implementation `57d8d59` on `feature/android-mobile`, unpublished. Shared
  persisted Range/If-Range downloads retain exact partial bytes through
  navigation/restart/process death; Pause/Resume and explicit Discard on both
  updater screens. Full hash/length and native install checks remain mandatory.
  Decimal sizes/progress/speed use 1000-byte units and at most one fractional digit.
- Signed ARM64/x64/universal private code-24 APKs measure 25,533,723 / 27,051,703 /
  51,611,607 bytes. ARM64 saves 50.4% against public beta 1. Common code, approved
  production signer, exact ABIs and 16 KiB ELF/ZIP gates pass. The universal
  build excludes unsupported dependency-only 32-bit libraries. Windows packages
  measured 47,243,956-byte Setup / 62,421,403-byte portable; no speculative change.
- Final Feature pass: 50 host tests, focused analysis/format, 11 release-validator
  tests; 8 developer-helper tests, docs/catalog and diff checks pass. Five native
  signing-policy JVM tests pass. Actual signed universal-23 to x64-24 emulator
  package update succeeds; original first-install timestamp retained. It is not
  a populated-data/in-app approval audit. Emulator stopped, test data retained.
- Phone signer remains unmeasured; read-only certificate diagnostics and verified
  backup-first development-to-production migration instructions are documented.
  Modern installed-signer APIs, production pin and distinct errors are implemented.
  Android lock/Doze/force-stop can interrupt execution; bytes survive for manual
  resume. Physical phone/OEM/ARM64 acceptance remains pending. Emulator System UI
  startup ANR limits GUI evidence; Dart MCP had no running debug app to reload.
- No release/tag/asset, production signing identity, schema, profile or Drive
  behavior changed. No full unrelated suites or widget/Drive acceptance repeated.
  Next beta still needs a new synchronized version/code and mandatory exact-source
  release gates. [Measurements, tests, changed boundaries and recovery](UPDATE_DOWNLOAD_RECOVERY.md).

## Android beta 1 published and verified (2026-10-31)

- Published [v1.0.19-beta.1](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.1),
  code 23, as a public pre-release at 11:19:47 UTC / 14:19:47 Asia/Amman.
  Tag/source `b48d7a7`; safety fixes `57d7c4d`, `afe5241`. No tag moved.
- Exact-source Windows CI `41195345642` and Android CI `41195345616` pass:
  434 full host tests, 69 Android host checks, two emulator integration tests,
  Release/native/package/config gates. Deliberate opt-in companion launch skip
  remains explicit; local and packaged native self-tests pass.
- Anonymous downloads, all four public asset sizes/digests/checksums, production
  signature and tag/source verify. APK SHA-256:
  `eeb140b1ee574689c890bd52e2e078f547a3fc5533a5197c4d066eb8828c5d6b`.
- Normal production build 22 discovers 23 on Pre-release and excludes it on Stable.
  Actual public download/native verification/system installation succeeds; all
  45 tables, attachment/backups/preferences/widget IDs/config survive. Identical
  APK passes 16 KiB runtime and delayed-widget safety checks. Drive remains enabled;
  completed real-account OAuth/encrypted recovery acceptance retained unchanged.
- Windows/Android Drive restoration remains owner-deferred/unverified; owner phone
  procedure is ready. Existing Windows release identities/assets unchanged.
  Emulators/server stopped, development/personal profiles preserved.
- [Full publication receipt](ANDROID_BETA_1_PUBLICATION.md) and
  [phone installation/Windows backup test](ANDROID_PHONE_BETA_TESTING.md).

## Stale-widget safety fix under release verification (2026-10-31)

- Frozen-clock reproduction produces the exact stale-action test failure before
  the fix. Direct wall-clock `updated_at` could be reused; native completion also
  lacked an expected snapshot token. See [task revision safety](TASK_REVISION_SAFETY.md).
- Task revisions now strictly advance using the existing UTC token, with exact
  stored-text CAS and transactional completion/recurrence revalidation. Native
  widget paths carry expected revisions. Duplicate completion is a no-op.
  Schema remains 22 and backup format is unchanged; no data migration or reset is introduced.
- Focused Dart tests including unchanged recurrence assertions: 18 pass. Full
  analysis/formatting, connected diagnostics and 15 release/helper tests pass.
  Native Release build and isolated persistence/revision self-test pass.
  Final full suite: 434 pass, one deliberate skip. Windows CI `41179574454`
  passes on `afe5241`; Android CI `41179298416` passes on Android-equivalent
  `57d7c4d`. Final publication-ref CI, replacement signed artifacts and affected
  device acceptance were pending at the implementation checkpoint. Rebuilt APK/AAB
  now pass strict preparation and credential review. APK SHA-256:
  `eeb140b1ee574689c890bd52e2e078f547a3fc5533a5197c4d066eb8828c5d6b`.
- Fresh disposable C: guest repeated actual production 22-to-23 update; all 45
  tables, attachment/backup bytes, settings and widget IDs/themes survived.
  Normal widget completion/reopen passed. A real delayed capability after a UI
  edit made no database change (45 tables identical). Identical-APK 16 KiB runtime
  and persistent SQLite/widget actions pass, no app crash/ANR recorded there.
  Both guests stopped; baseline snapshot retained for public checks. Cleared only
  unused task-owned RAM/download caches to fit the fresh guest; no profiles reset.
- Final publication-ref CI and refreshed draft/public verification remain pending.
- Keep beta draft unpublished until those gates pass. Retain completed Android
  OAuth/encrypted recovery acceptance and owner cross-platform deferral; do not
  reopen Windows Sandbox or touch development/personal profiles.

## Final OAuth acceptance resumed; interoperability deferred by owner (2026-10-31)

- Owner explicitly accepts deferring Windows/Android Drive discovery/restore
  until after the first Android beta publication and will test a Windows backup
  on Android. It remains unverified; start with disposable data and external
  backups before replacement. No further Windows app testing is authorized.
- Real disposable-account OAuth revocation/reauthorization passed: owner revoked
  access, refresh detected revoked grant, fresh Google consent appeared, owner
  reauthorized, and both existing backups were rediscovered. All 45 local tables,
  attachment/backups/preferences/widget settings remained identical. No app
  crash/ANR observed; stopped emulator with data retained. No OAuth bug found.
- New mandatory safety blocker: Windows CI `41176493080` accepted the command in
  `stale completion cannot overwrite an edit`, contrary to its expected rejection.
  Following CI `41176579454` passed, and a local 100-edit revision probe found no
  collisions; neither explains the failure. No assertions/runtime code changed.
  Per owner's stop-on-another-gate instruction, keep the draft unpublished until
  diagnosed and any required rebuild/reacceptance completes.
- Existing APK and application source remain unchanged. Signing/artifact/16 KiB
  preparation and credential audit were revalidated. Exact phone instructions:
  [phone beta testing](ANDROID_PHONE_BETA_TESTING.md).
- Publication is authorized only after this test passes and other mandatory
  gates remain satisfied. No signing, integrity, CI or migration gates are waived.
- Updated the existing [unpublished draft](https://github.com/2HIK4/Todorbit/releases/tag/untagged-5d37eaf3644b4e6ac064)
  (ID `429762923`) to source `01215d7`, with the completed OAuth result, owner
  deferral and new CI hold. Refreshed notes/checksum assets; all four remote
  sizes/digests match. APK/JSON unchanged; AAB stays private. Existing Windows
  release identities/assets are unchanged. No public beta tag/download exists;
  postpublication updater checks remain unrun. This receipt only changes docs.

## Production Android beta prepared; publication held (2026-10-31)

- Proposed `1.0.19-beta.1+23` remains unused publicly; normal unpublished
  production baseline code 22 and candidate APK/AAB code 23 built. Owner signing
  identity/recovery attestations recorded; private-key access and both public
  fingerprints verified without exposing credentials.
- Application source is unchanged from `313b7a7`. `220cec2` fixes current aapt2
  minimum-SDK labels (seven tests pass); `7224076` strengthens tampered-newer-APK
  rejection. Android CI `41134977565` and Windows CI `41134977577` passed on
  `7224076`, including real-emulator verification and Windows Release/self-test.
- Strict artifact preparation passed APK/AAB signer, identity/version/SDK/ABIs,
  Play permission/provider separation, native alignment, bundle 16 KiB config,
  monotonic-code/checksum/metadata checks. Credential scan passed 723 tracked
  files/archive entries. Verified assets are under ignored
  `.buildlog/android-production-beta/prepared/`; AAB stays unpublished.
- Actual in-app production update 22 to 23 passed download cancel/retry,
  permission denial/grant, installer cancel/retained-download retry and approved
  installation after Play Protect scan. All 45 database tables, attachment bytes,
  backup, preferences and widget IDs/settings survived. Widget completion and
  reopening worked after updating.
- Production native Google authorization, encrypted upload/read-back verification,
  wrong-phrase rejection, preview, scheduled restore/reopen and success receipt
  passed on synthetic data. All 45 tables and the Before Restore database match;
  actual preference-reader comparison confirms equivalent settings. Owner typed
  recovery phrases locally. Existing cloud backups remain untouched.
- Official API-35 x86-64 16 KiB runtime (`PAGE_SIZE=16384`) passed launch/render,
  SQLite task save/cold reopen and widget completion/reopening. No app crash/ANR
  recorded there. One private-baseline ANR recovered earlier under constrained
  emulator resources; do not infer its cause or hide it. Physical ARM64 testing
  remains unobserved.
- Windows Sandbox test used only the verified published v1.0.18 portable package,
  public payload and bounded read-only results. UI-control tools failed even after
  reset. Owner reported browser sign-in but app still showed Connect; sentinel
  never appeared in the isolated database. Owner explicitly declined further
  Windows testing; Sandbox closed. Cross-platform Drive discovery remains
  unverified and retains its documented publication-blocker status.
- Android offline local use, account cancellation, local disconnect/reconnect and
  refreshed cloud history passed. Offline authorization has a generic
  canceled/denied message. Updated GMS through official Google Play for the final
  reconnect. Restored networking and stopped both test emulators/fixture server.
  Account-wide grant revocation remains unverified; no global grant was revoked.
- Staged [unpublished GitHub draft](https://github.com/2HIK4/Todorbit/releases/tag/untagged-76b06409b4f941be9b7c)
  (release ID `429762923`, target `9f1d55e`). APK, update JSON, notes and checksum
  all match remote asset sizes/digests. API confirms draft/prerelease, no publish
  timestamp; no public beta tag exists. Private AAB/test fixtures excluded.
  Development installation and personal
  Windows data/releases remain untouched. Detailed hashes, receipts and manual
  acceptance procedure: [production acceptance](ANDROID_PRODUCTION_BETA_ACCEPTANCE.md).

## Paused by owner to free PC resources (2026-10-30)

- Owner explicitly requested stopping. Stopped local Release/Gradle, fixture,
  loopback server, download and disposable-emulator processes; no files deleted.
  Production signing credentials and all application profiles remain intact.
- Do not restart work until the owner resumes. Pending changes/evidence are kept
  in the working tree and `.buildlog/android-production-beta/`. No release was
  published and no production APK validation or actual upgrade is claimed.
- On resume inspect status/diff first. The startup checkpoint retry passed
  unchanged. Connected Dart analysis of the updated integration test reports no
  errors. Fixture scripts now derive baseline/candidate codes from source and APK
  metadata; Release helper rejects `-NoPub` to avoid stale debug registrants.
- Current intended emulator fallback is Android 11 on USB, as selected by owner.
  Official Google image metadata and a partial verified-only-on-completion curl
  download are retained. The NVMe emulator did not start because C: had only
  approximately 2.2 GB free. No personal files were removed to free space.
- Resume production build with plugin regeneration enabled and no concurrent
  Flutter commands in this checkout. Finish all signing, alignment, CI, actual
  production-signer installer/data/widget persistence and authorized Drive gates
  before any publication. See the production acceptance checkpoint below.

## Production signing verified; beta acceptance running (2026-10-30)

- Owner completed long-lived signing setup, confirmed two independent encrypted
  recovery-tested backups and production OAuth registration. Verified RSA-4096
  key access and public fingerprints without emitting credentials. See the
  [production acceptance checkpoint](ANDROID_PRODUCTION_BETA_ACCEPTANCE.md).
- Candidate source versions synchronized in `ee38860`: `1.0.19-beta.1+23`, private
  baseline code 22. Pushed `feature/android-mobile`; existing Windows releases
  unchanged. `dcd6c7e` avoids retired SDK `tools` installation in Android CI;
  `38ec237` reads Gradle's debug signing path for CI fixtures and retains tool
  failures. Exact-source CI must pass after these CI-only changes.
- Windows CI `41118115728` passed on `dcd6c7e`, including full host tests, Release,
  native/package/config gates and installer/portable artifacts (unpublished).
  Local formatting/analysis pass; full suite has 425 passes, one deliberate skip
  and one 70-second startup-worker checkpoint timeout. Focused retry is pending;
  no assertions/timeouts weakened. Release Python tests 4 pass. Local evidence:
  `.buildlog/android-production-beta/`, host receipt
  `.buildlog/verify/20261030-223852-2873/`.
- Initial local Release failed on an incomplete system SDK selected by saved
  Flutter config. A workspace-scoped ignored Gradle init now selects the existing
  complete SDK; no system SDK/cache was removed or global config changed. The
  candidate Release build is still running. No signed APK validation/publication
  is claimed yet.
- Fresh disposable production AVD: `TodorbitProductionBeta`, `emulator-5582`,
  visible for owner test-account sign-in. Archived `TodorbitAndroidTest` stopped
  without uninstall/wipe. Never install production into its debug profile.
  Owner sign-in confirmation is pending; leave credential entry to the owner.
  Private fixture source/TLS transport and same-signer read-only instrumentation
  are isolated under ignored build logs, excluded from normal `lib/main.dart`.
- Resume: finish production APK/AAB and private code-22 fixture build, verify
  signer/non-debuggable/SDK/ABIs/alignment/hashes and credential exclusions;
  perform actual permission/cancel/retry/system-installer upgrade, compare closed
  profiles/widgets/attachments/backups, complete authorized Drive acceptance and
  required CI/runtime gates, then prepare a draft. No release/tag published.

## First production-signed Android beta preparation (2026-10-30)

- Clean implementation baseline `5fcd561`, `feature/android-mobile`. Owner
  confirmed no existing production key and requested creation instructions.
  Only the debug keystore was found in the standard local location; ignored
  signing configuration is absent. No key/password was generated or exposed.
- GitHub release inventory remains Windows-only through `v1.0.18`; no protected
  `android-signing` environment exists. Proposed Android candidate is
  `1.0.19-beta.1` / code 23, with unpublished same-signer baseline code 22;
  recheck remote tags and version-code floor before building. No version bump,
  push, tag, release modification or publication was performed.
- [Owner setup and resume checklist](ANDROID_BETA_PREPARATION.md) gives interactive
  RSA-4096 key creation, restricted local configuration, two separate encrypted
  backups with recovery verification, production OAuth registration, future Play
  app-signing/upload-key distinctions, and safe debug-to-production migration.
  Default candidate notes now contain a reviewable Android beta draft with
  installation, migration and explicit unverified production/Drive status.
- Production build/signature/hash, real production OAuth and same-production-key
  in-app installer/data-preservation acceptance remain pending owner setup. Prior
  implementation checks remain source-specific evidence, not production passes.
- Preparation checks: 25 updater/UI/backup/portable round-trip tests pass, four
  release-validator tests pass, docs links and diff whitespace pass. Receipt:
  `.buildlog/android-beta-preparation-tests.log`. Portable fixtures use distinct
  temporary files/executors; Drift emits its multiple-database debug warning.
  No application code changed, so prior static analysis and platform builds were
  not repeated for this documentation checkpoint.

## Android widgets and mobile UI refinement (2026-10-30)

- Started clean on `feature/android-mobile`, baseline `4c93b60`. Used installed
  Apple Design/UI UX Pro Max plus the project UI/regression skills. Added shared
  mobile section rhythm/48 dp controls, actionable empty states, clearer settings
  and Support/Contributors discovery; retained the existing feature implementations.
- Reworked RemoteViews with shared palettes, readable surfaces, measured row
  capacity, date context, event/session rows and an expanded date strip. Native
  publication/rendering uses a serialized worker and goAsync receivers. Widget
  completion consumes an unguessable one-use capability, waits for unlock/editor
  closure and uses the shared revision-checked completion rules. It opens the app.
- Fixed Calendar Add Event routing and startup preference/navigation races;
  preserved event occurrence IDs and drafts. GitHub Support uses the official
  destination; Play/unknown builds offer feedback. Android Drive was already
  enabled and remains unchanged; native authorization start/cancel observed,
  no authenticated cloud acceptance claimed.
- Full host gate: **426 pass / one intentional skip**, clean formatting/analysis,
  Python release/helper gates pass. Focused mobile/action/support 42 pass; Android
  update UI 13 pass after localized Last checked copy. Windows Release/config gate
  and isolated packaged companion self-test pass. Device workflow passes on the
  archived API 35 disposable AVD `TodorbitAndroidTest` / `emulator-5580`.
- Added opt-in native render/capability harness and repeatable helper: **72 cases
  pass** across three sizes, both themes, zero/one/twelve items and normal/200%
  text. Representative corrected screenshots inspected. Actual same-title task
  completion/reopen, process-kill cold reopen, task/event rows and Calendar Add
  observed. Live hot reload succeeds; no Flutter runtime errors reported.
- Final development APK: **1.0.18 (21)**, same debug signer as code 20, API 26+,
  arm64/x86-64; installed SHA-256 matches
  `3a864e4900b3964245c8397f3b8677eb68548c8936555e432ed7f3439816906c`.
  Alignment/signature gates pass. All 45 isolated profile table counts and stable
  task/event/organization IDs survive; schema 22, test tasks reopened, native
  fixture keys removed. No personal data tested, release published or merge/push.
- [Full report and APK instructions](ANDROID_UI_REDESIGN.md) records source-specific
  receipts and remaining launcher-drag, physical/OEM, lock/recurring/session
  breadth, reboot and authorized Drive/Play/production-signing acceptance.

## Android finalization checkpoint (2026-10-30)

- Recovered implementation committed as `3b8dcce` on `feature/android-mobile`;
  baseline analysis clean, focused auth/update/cloud checks 29 pass, release
  preparation Python tests 4 pass. No secrets/artifacts staged or publication.
- Follow-up commits: `e19e8ea` mechanical formatting, `d88161d` transfer safety,
  `b2b264e` feature routing/verification and guarded platform harnesses.
- Added feature routing and explicit Quick/Feature/Full helper with bounded logs,
  timings and failure propagation. Developer-helper checks 8 pass; links/catalog
  validate. Windows Release and isolated packaged native self-test pass on the
  current source. Optional generated junctions resolve local symlink permissions.
- Cloud transfer adds full-transfer history/local-edit warnings, per-profile
  operation exclusion and stale database/preferences checks through startup.
  Focused UI/local-safety checks 13 pass. Full host checks **416 pass / one skip**,
  analysis/format clean, release Python tests 4 pass. Full receipt:
  `.buildlog/verify/20261030-115022-1274/`.
- Retained disposable AVD `TodorbitAndroidTest` (`emulator-5580`) archived to
  `.buildlog/finalize-emulator-before.tar`. Final device integration passes; actual
  permission deny/recover, cancel/retry/approve and product 19-to-20 relaunch pass.
  Installed hash matches; all 45 SQLite tables, appearance/update JSON, retained
  backups and widget IDs 5/6/settings survive. Live reload/restart and clean runtime
  diagnostics observed. Drive teardown requires `--keep-app-running`; fixed after
  it removed the archived disposable installation. No personal data was tested.
- No authorized Google account (owner confirmed) or production key is available;
  live official GitHub has no Android assets (15 releases). Exact external steps,
  timings, artifacts and remaining phone/16 KiB/Play gates are in
  [finalization acceptance](ANDROID_FINALIZATION.md). Nothing published/pushed.

## Android Drive and updater continuation (2026-10-30; started 2026-10-29)

- Continuing clean baseline `63965f5` on `feature/android-mobile`. Android Drive
  now defaults enabled, with account pinning, refresh/reconnect, safe switching,
  cancellation/Play-services/network messages and serialized identity removal.
  The shared encrypted codec, database/restore gates and Windows OAuth config
  are retained. Real OAuth and cross-client Drive discovery need owner setup.
- Added Android Software Updates, official-repository metadata/ABI/code/channel
  selection, bounded download/cancel/cache handling, native APK signature and
  installed-signer/package/SDK/ABI verification, and user-approved system install.
  GitHub/Play native flavors separate the installer from the official store flow.
- Added a read-only signed-candidate CI workflow, durable-signing/checksum/AAB
  gates, negative APK fixtures and disposable-emulator verification/installation
  harnesses. No production key or public release was created. [Drive setup](ANDROID_GOOGLE_DRIVE.md),
  [updates](ANDROID_UPDATES.md), [signing and releases](ANDROID_RELEASE.md).
- Validation checkpoint: full Flutter suite **403 pass / one native-service skip**;
  final focused account/updater suite **24 pass**; analysis clean; Python release
  version gates **4 pass**. GitHub debug APKs code 19/20 build, APK v2 signature
  and seven native-library alignment checks pass. Isolated Windows Release and
  packaged native self-test pass. Play AAB builds, signature/alignment/16 KiB
  configuration and installer exclusion pass. Mobile restore and native APK
  positive/negative checks pass on the established disposable API 35 AVD; a
  fresh AVD had Android service startup failures. Actual in-app build 19-to-20
  update passes through source-permission denial, system-installer cancellation,
  retry/approval and product relaunch. Installed APK hash matches; SQLite
  integrity, all seeded/existing domain rows, dark appearance and both widget
  configurations survive. Live diagnostics and attached hot reload pass.
  [Current evidence](ANDROID_DRIVE_UPDATES_ACCEPTANCE.md). Real OAuth, cross-client
  Drive access, production signing and physical-phone acceptance remain external.

## Android continuation: installable development build verified (2026-10-28)

- Recovered clean `feature/android-mobile` at **4de8dff**, following committed
  stages **8189c3d** and **c4b0218**. Continued existing work without resetting
  data/history or changing public Windows releases. Schema 22 remains shared.
- Continuation commits **7f11afc**, **fea4b89**, **e881a12**, **e58f57c** fix
  notification permission recovery, asynchronous background startup, pending
  inexact reminders across refresh/midnight, SAF private temporary exports and
  regression coverage. Final app binaries use product source **e881a12**.
- **385 Flutter tests pass / one intentional native-service skip**, clean
  analysis of all product/test sources, one Android workflow passes. APK/AAB
  builds and all seven packaged native-library alignment checks pass. Windows
  Release at e881a12 and its isolated packaged companion self-test pass.
- On isolated API 35 emulator `TodorbitAndroidTest`: task/event reminders and
  notification links, permission recovery, actual Tasks/Calendar widgets,
  package-update/reboot persistence, PIN/device credential/privacy, SAF exports,
  Windows snapshot import with verified Before Restore copy, managed PDF opening,
  cold headless refresh, and timer reboot review/explicit checkpoint recovery
  were observed. Personal Windows profiles and running widgets were preserved.
- Development-signed APK/AAB and checksums are in ignored
  `.buildlog/android-deliverables/`. Real Drive OAuth registration and production
  signing need owner configuration. Physical-device/API/OEM/TalkBack/Doze/16 KiB
  runtime/performance acceptance and remote CI remain outstanding; emulator
  System UI ANRs and slow host startup are recorded. No Android release published.
- [Acceptance/evidence/artifacts](ANDROID_ACCEPTANCE.md),
  [feature status matrix](ANDROID.md), [phone installation/signing/OAuth](ANDROID_SETUP.md),
  [future synchronization proposal](FUTURE_CROSS_DEVICE_SYNC.md).

## v1.0.18 widget hotfix published (2026-10-28)

- [Public Windows x64 pre-release v1.0.18](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.18),
  **1.0.18+19**, source/tag **08eab9a**. [Publication receipt](TODORBIT_1_0_18_PUBLICATION.md),
  [findings](WIDGET_STARTUP_HOTFIX.md), [notes](TODORBIT_1_0_18_RELEASE_NOTES.md).
- Temporary Close Widget no longer persists disabled; main startup restores saved
  enabled widgets without replacing hosts/active editors. Selected navigation uses
  one contrast rule; the Calendar planned-task square becomes an inset circle.
  Explicit disabled settings, personalization, profile identity and schema remain.
- [Exact-source CI](https://github.com/2HIK4/Todorbit/actions/runs/40690309900) passes:
  **357 tests / one opt-in skip**, analysis, native/Windows Release, packages and
  checksums. Local opt-in real companion **1 pass**; packaged self-test/lifecycle,
  actual main close/reopen/disabled/single-instance, portable swap/rollback/restart,
  public assets/digests and v1.0.17 updater discovery/download pass for both modes.
- Personal startup/installer registration fingerprints unchanged; no setup run.
  Physical DPI/input, actual sign-in, registered installer/clean-user acceptance
  remain unverified. All limits and exact asset hashes are in the receipt.

## v1.0.17 audited widget upgrade published (2026-10-28)

- [Public Windows x64 pre-release v1.0.17](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.17),
  **1.0.17+18**, source/tag **cae2b4b**. Implementation d8f2bc8, handoff 72b584e;
  audit adds regression fixes for unchanged reminders, async navigation/draft races
  and compact Calendar marker overlap. Main fast-forwarded; tags not moved.
- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40671604747)
  passes: **356 tests / one opt-in skip**, clean analysis, config gates, Windows
  Release, native self-test, installer/portable/checksums. Local focused **9 pass**,
  formatting/diff checks pass; final packaged self-test and actual-HWND lifecycle
  pass. Enabled packages retain the SHA-verified public v1.0.16 configuration;
  tracked config restored disabled/empty. No credential values committed.
- All five public assets/digests and anonymous downloads match local bytes;
  production updater discovers/downloads/verifies v1.0.17 from v1.0.16 in both
  package modes. Stable excludes the pre-release. Actual bundled helper rollback,
  swap and restart pass at an isolated portable path with spaces. Core approved
  backup/migration path preserves all 44 legacy tables/values, old event reminders,
  sessions, project/category/task data, theme/calendar and custom widget presets;
  schema 22 defaults task reminders Off. Verified schema-21 Before upgrade snapshot.
- Live driver inspection verifies settings/control layout and applied navigation
  order; hot reload/runtime diagnostics clean. Computer Use native pipe unavailable
  after recovery, so physical release UI/approval/DPI/input and OS notification
  receipt remain unverified. Debug install initially hit a disposable companion
  file lock; closing that isolated companion resolved it. Personal installed
  process/registration/data were not changed; no setup executable was run.
- [Publication, exact hashes and remaining acceptance](TODORBIT_1_0_17_PUBLICATION.md).
  Evidence: ignored `.buildlog/release-1.0.17-20261028/`.

## Widget settings, reminders and direct navigation (2026-10-28)

- Implementation **d8f2bc8** on `feature/widget-settings-navigation-upgrade`,
  based on main `d6a1620`. [Behavior, migration and manual checklist](WIDGET_SETTINGS_UPGRADE.md).
  Production app/native version remains **1.0.16+17**; no publication, installer
  execution, dependency/OAuth-config change or personal-profile migration.
- Implemented ordered/hidden widget navigation, per-kind built-in/custom presets,
  bounded/coalesced settings Undo/Redo, independent row/selection colors/alpha,
  Calendar divider/proportions and event-count indicators. Settings transfer,
  local snapshots and encrypted Drive restore apply portable configuration and
  preset libraries while keeping visibility/geometry/startup/lock device-local.
- Schema **22** adds explicit-Off task notification JSON, enabled-reminder index
  and delivery ledger, reusing the existing companion timer/privacy boundary.
  Custom UTC timing stays separate from planned dates; relative timing uses
  upcoming work sessions. Future recurring occurrences are not silently enabled.
- Typed activation opens existing task/event/session editors by stable IDs and
  occurrence dates; pending requests preserve active edits/modals. The native
  Scheduled item popup and native row-edit detour are retired for these clicks;
  completion checkboxes keep their direct behavior.
- Verification: full serial Flutter suite **353 passed / one opt-in skip**;
  final targeted drag/history/preset/text-focus checks **4 passed**. Final whole
  analysis clean; changed-Dart formatting and `git diff --check` pass.
  Windows Release and native Release build pass (native zero warnings/errors),
  final packaged self-test and two-widget actual-HWND lifecycle pass. Native
  offscreen light/dark/DPI fixtures inspected; physical DPI/input is not implied.
- Isolated debug runtime: preset select/save/Apply; actual second-process task
  activation and cold executable startup open the exact editor with one main
  process. An unsaved title stays intact during a queued missing-item request,
  then the missing-item message appears after closing the editor. Successful
  hot reload and clean subsequent runtime diagnostics. Disposable apps closed;
  the already-running installed companion was not stopped.
- Restore tests include real encryption/staging/file application through a fake
  Drive provider; real-account OAuth was not rerun. Physical notifications,
  Win+D/Explorer restart, multi-monitor/DPI transitions, screen readers and real
  event/session clicks remain manual acceptance items. Initial failing snapshot
  envelope expectations, schema table-count expectations, narrow preset layout
  and a date-dependent Calendar fixture were corrected before final verification.
- Evidence remains ignored under `.buildlog/widget-*`; screenshots mentioned in
  the request were not attached, so written requirements and rendered UI were
  used. No installer/portable/release assets were modified.

## Repository workflow maintenance (2026-10-27)

- Clean baseline `main` at `6592b2b`; remote main matches. GitHub releases API
  confirms latest public pre-release v1.0.16, source/tag `6e3b64b`; source app
  and companion metadata remain 1.0.16+17. Local tags had not included v1.0.15/16;
  remote inspection avoided treating the local tag list as public release state.
- Root AGENTS now routes tasks to architecture/setup/testing/workflow/release
  owners, preserves data/native safety, clarifies existing optional Drive support
  and selective skills. Contributor and PR guidance use checks matched to risk.
- Added TESTING; expanded Architecture with verified paths/dependencies/tests;
  Workflow includes safe branches, interrupted work, a reusable prompt and all
  three routing examples (Calendar widget resize, persisted setting, pre-release).
- Corrected stale public v1.0.7/v1.0.13 pointers and source-vs-published Drive
  wording. Release owns draft/gates/hashes/publication; Updates owns protocol and
  recovery. Dated acceptance/publication evidence remains intact and contextualized.
- Lightweight code assessment: AppController.refresh loads a broad shared snapshot
  and notifies all listeners; main.dart's database/WAL watcher already debounces
  events by 250 ms. Profile before proposing narrower refresh/rebuild boundaries;
  no measured performance defect or safe verified code optimization established.
  Windows CMake already publishes the companion, so separate native builds are
  diagnostic checks rather than an additional packaging prerequisite.
- Documentation-only: no app code, version, assets, CI behavior or data changed.
  Local Markdown link targets and referenced implementation paths checked;
  final diff/whitespace reviewed. No Flutter suite or distribution rebuild needed.
  No measured token-savings claim. Remaining product/manual acceptance limits
  continue to live in the release receipts, not this maintenance checkpoint.

## v1.0.16 refinement pre-release published (2026-10-27)

- [Public Windows x64 pre-release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.16),
  **1.0.16+17**, source/tag **6e3b64b** (implementation **23526bf** plus lint fix).
  Recovered interrupted changes are included; no review artifacts were committed.
- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40418348308)
  passes: clean analysis, **340 passed/one opt-in skip**, config gates, Windows
  build, native test, installer, portable and checksums. Published enabled bundle
  retains the approved previous Drive configuration; tracked config restored.
- All five public assets/digests, anonymous binary equality/CRC and production
  updater discovery/download from v1.0.15 pass for both package modes; Stable
  excludes it. Actual isolated portable rollback/swap/restart preserves all 44
  tables/settings and creates the once-only support receipt. Legacy widget mode
  compatibility, independent visibility and one companion pass.
- Personal installation/profile/Run entries remain unchanged. Physical scrolling,
  snapping/input, DPI, Win+D, Explorer restart, multi-monitor, screen readers and
  registered installer execution remain unverified. Packages remain unsigned.
  [Publication and upgrade instructions](TODORBIT_1_0_16_PUBLICATION.md).

## Unified widget refinements and optional support (2026-10-27)

- Recovered all four tracked interrupted UI fixes and tests without resetting
  the working tree. Continued on `feature/widget-refinements-support`.
- Unified native Calendar with bounded 4/5/6-row dates and scrollable agenda;
  companion edge snapping, exact same-DPI geometry persistence, cleaner menus,
  shared settings scroll fades and optional fixed-destination PayPal support.
- Existing UI UX Pro Max installation actively used; theme/branding retained.
  Focused Flutter **42 passed**, targeted analysis clean; current native Release
  build, self-test and actual-HWND lifecycle pass. Release gates/publication
  remain pending. [Evidence and limits](WIDGET_REFINEMENTS_SUPPORT.md).

## v1.0.15 widget redesign pre-release published (2026-10-27)

- Owner-authorized implementation **ae649f1** and preparation **a116069**
  fast-forwarded to main. Version **1.0.15+16**, tag **v1.0.15** targets a116069.
  [Release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.15),
  [publication record](TODORBIT_1_0_15_PUBLICATION.md).
- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40399386479)
  passes: clean analysis, **329 tests passed/one opt-in skip**, config/package
  gates, Windows Release, native self-test, portable, installer and checksums.
  Prior local implementation verification reused without another local full suite.
- Published installer/ZIP retain the prior enabled Drive configuration; audited
  receipts, complete bundle equality, ZIP CRC/private-file guards, native checks
  and all five public assets/digests pass. Tracked config restored disabled/empty.
- Production updater detects/downloads/verifies v1.0.15 from **v1.0.14** for both
  installer and portable; Stable excludes it. Disposable actual portable rollback,
  swap/restart preserves all 44 tables/settings; widget compatibility/independent
  visibility checks pass in one companion. Personal install/profile/registration
  and update channel untouched; no website/Cloud changes.
- Real-user physical Windows acceptance, registered installer execution, DPI,
  focus/input, Win+D, Explorer restart, multi-monitor and screen readers remain
  pending. Packages are unsigned. Owner will test after upgrading.

## Widget redesign and application UI audit (2026-10-26)

- Branch `feature/widget-redesign-live-preview`, from main `ce535e4`; no
  publication, profile migration, personal install or cloud configuration change.
- Native Calendar now offers compact/agenda and full-month presentations with
  shared geometry, item previews/overflow, complete selected-day inspection and
  compatible preferences. Tasks, drag regions, checked menus, transparent text
  and delayed themed/DPI-aware tooltips receive a coordinated polish pass.
- Actual-widget preview uses the established scoped pipe with ordered leased
  drafts, recoverable timeout and explicit rollback. Apply stays open; dirty
  Close/Escape offers Save/Discard/Continue. Shared Apply preserves independent
  settings. Visibility/menu edits merge safely; continuous slider movement
  previews before release without preference writes.
- Shared settings/helper controls, scrollable validated color/prompt dialogs,
  disabled-choice keyboard traversal and narrow settings/privacy/backup fixes
  address the [concrete audit findings](WIDGET_REDESIGN_UI_AUDIT.md).
- Full integration: **327 passed, one opt-in skip**, zero errors, 374.505 s.
  Final preview refinements also pass **11 editor tests**; opt-in packaged native
  launch/reload passes separately. Analysis clean (17.2 s); final Windows Release
  passes (102.6 s). Native Release has zero warnings/errors; bundled self-test,
  two-HWND lifecycle/preview/rollback/restart and offscreen review pass.
- Isolated debug build/live Flutter MCP passes: actual pipe preview leaves saved
  bytes unchanged, Apply stays open, Cancel/reopen preserve the saved Calendar
  mode, dirty Close offers choices, and hot reload reports no runtime errors.
  The single companion survives main-app closure and restarts with saved settings.
  Test processes closed cleanly; live screenshots/evidence remain ignored.
  Physical input, Win+D, Explorer restart, multi-monitor,
  screen-reader and actual Windows DPI checks remain unverified.
  [Implementation and evidence](WIDGET_REDESIGN_IMPLEMENTATION.md).

## v1.0.14 widget pre-release published (2026-10-26)

- Owner-approved feature **d355ee2** fast-forwarded to main; release source/tag
  **b599396**, version **1.0.14+15**. [Publication record](TODORBIT_1_0_14_PUBLICATION.md).
- Final Windows CI passes: clean analysis, 303 tests/one opt-in skip, Windows
  build, native self-test, configuration gates, portable and Inno Setup/checksums.
- Both published packages keep Drive enabled with the exact v1.0.13 configuration.
  Full bundle/receipt/CRC/checksums and all five public assets verified.
- Production Pre-release updater selects/downloads v1.0.14 from v1.0.13 for
  installer and portable; Stable excludes it. Isolated actual portable rollback,
  swap/restart and legacy widget migration pass; all 44 tables/preferences and
  personal Run/uninstall fingerprints preserved. Calendar enables independently
  in one companion process. Personal installed app/profile remains untouched.
- Official Pages deployment/live HTTPS files/download links pass. Physical DPI,
  Win+D, screen-reader, manual native input and registered installer acceptance
  remain unverified; owner will test after upgrading. No Sandbox/VM required,
  Cloud change, general UI audit or Google branding verification claim.

## Widget customization and Calendar Widget development (2026-10-26)

- Resumed after VS Code interruption on `feature/widget-customization-calendar`
  from main `3d499fb`; retained all source/test edits and saved evidence. No
  reset, personal install/profile change, Cloud change or publication.
- Scoped update/backup/calendar presentation fixes and the two-widget model,
  native hosts and Settings editor are implemented. Both widgets reuse one
  companion/startup/IPC identity and keep separate visibility/configuration and
  geometry. Apply/confirmed shared Apply/Cancel preserve widget-specific state.
- Final full-source suite: **304 cases, 303 passed, one opt-in native test
  skipped**, zero error events, 379.966s. The opt-in first-launch/reload test also
  passes separately against the final packaged companion on a fresh isolated
  profile. Complete analysis clean (16.7s); Windows Release passes (33.7s), then
  the final native CMake target and repeated packaged native checks pass.
- Packaged native self-test, actual disposable-profile two-HWND lifecycle and
  offscreen renders pass; Windows Run fingerprint unchanged. Isolated debug
  Flutter MCP restart/reload reports no runtime errors, and separate-process
  activation selects either editor without duplicates. Cross-widget edit
  requests preserve/cancel dirty drafts; first companion launch no longer waits
  on the persistent process. No personal app/profile/registration operation.
- [Development record](WIDGET_CUSTOMIZATION_UPDATE.md) tracks exact evidence,
  interruption limits and remaining manual input/DPI/Win+D/screen-reader checks.
  No general UI audit or Sandbox/VM requirement is added.

## v1.0.13 experimental pre-release published (2026-10-26)

- Owner explicitly approves main merge, tag, GitHub pre-release publication
  and official Pages download updates. This supersedes earlier publication
  holds below; Cloud settings and the personal installed app stay untouched.
- Reuse app source **8d667df**, its 287 tests, successful Windows CI and real
  Google/recovery/updater evidence. No app/build/config changes or repeated
  suite/build/Google tests. Release prep changes only docs and website copy.
- Exact enabled private installer/ZIP pass final size/SHA-256/sidecar/manifest,
  portable CRC/full bundle equality, version and config/runner/AOT receipt
  checks. Disabled-config CI artifacts will not be published.
- Google Drive is explicitly experimental. Non-sensitive-only verification
  guidance does not establish a branding-only prohibition; full production
  policy/domain compliance and broad account eligibility remain unresolved.
  Clean-user/VM remains skipped, registered/manual GUI/trust unverified.
- [v1.0.13](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.13) is now
  published as a non-draft **pre-release**, not latest stable. Tag targets
  **83fad4b** on main; app/config/build sources equal **8d667df**. Both public
  binaries and three checksum files pass anonymous download/digest checks;
  downloaded ZIP retains the enabled config/runner/AOT receipt and exact bundle.
- Real production updater service from explicit version **1.0.12** detects
  v1.0.13 on Pre-release for installer and portable, verifies both transfers,
  and excludes it on Stable. No package was run and no personal channel changed.
- [Pages deployment](https://github.com/2HIK4/Todorbit/actions/runs/40355725550)
  PASS; anonymous homepage/all eight deployed files match source and all nine
  external links pass. Download links point to v1.0.13, with experimental Drive
  wording in homepage/privacy/terms. Rendered browser QA remains unverified.
- See [publication record](TODORBIT_1_0_13_PUBLICATION.md) for exact artifacts,
  policy sources, remaining limits and bounded evidence under ignored
  `.buildlog/release-1.0.13-20261026/`. Personal app/profile and Cloud unchanged.

## Initialization reliability and engineering acceptance (2026-10-26)

- Final audit also reproduced and fixed SQL LIKE's underscore-prefix issue:
  GLOB now excludes only the literal reserved `sqlite_` prefix, never user
  tables such as `sqlitecustom`. Added empty/populated name regressions; final
  suite/build/Google recheck/CI pass at **8d667df**. First engineering CI was
  cancelled as superseded. Counts below describe the corrected final candidate.

- Root cause: creation and upgrades autocommitted DDL before Drift recorded the
  version. Both now transact DDL plus version together. Version-0 recovery only
  completes empty, compatible schemas and verifies the exact fresh schema
  before commit; populated/incompatible files roll back without a reset.
- Initialization/controller-load failures are handled by startup before native
  companion/main workspace use. Existing schema version 21, upgrade approval
  and verified Before upgrade snapshots stay compatible. Fixed the backup
  validator's v20+ reminder-table check order; malformed snapshots are rejected.
- **287/287** Flutter tests, zero JSON errors, 423.259 seconds; clean analysis
  (54.8 seconds). Twenty-two new initialization tests include real process death
  during create/upgrade and after version write before commit. The added backup
  test covers missing reminder tables. Both original interrupted fixtures
  recovered in disposable copies; originals retained. Native Release has zero
  warnings/errors and all 11 configuration/package guards pass.
- Enabled private Release and installer compile passed. New private packages,
  separate Source/Restore/layout startup/restart, 37-entry portable integrity,
  receipts, hashes and packaged widget self-test pass; Windows Run unchanged.
  Tracked configuration is restored disabled/empty. Post-change real Google
  recheck passed three independent runs (40 requests, three refreshes, sole
  appdata grant): full/settings encrypted transfer, wrong phrase/cancel,
  selective recovery, original Release full restore/restart with all 44 tables
  and preferences matching, Before Restore and finalized receipt. Exactly two
  new test objects deleted; pre-existing objects retained. Earlier authorized
  session reused in place, no token copying/new consent claim.
  [Final CI](https://github.com/2HIK4/Todorbit/actions/runs/40342429612) passes at
  8d667df with disabled public configuration. Downloaded packages independently
  pass SHA-256/CRC/config/runner/AOT checks; no public release created. See
  [engineering acceptance](GOOGLE_DRIVE_ENGINEERING_ACCEPTANCE.md).
- Owner explicitly **skips clean Windows-user/VM testing for this release**.
  Record it as known unverified coverage, not a required Sandbox action. No VM
  was launched or OS features changed by the agent. Native GUI controls remain
  unavailable; physical dialogs/input/DPI, registered install/upgrade/uninstall,
  fresh credential identity and machine prerequisites/trust remain unverified.
- Production updater live checks/downloads pass against real GitHub: current
  1.0.13 sees no unpublished update; an explicitly simulated older selector
  finds actual public v1.0.12 and verifies both asset transfers/digests/progress.
  Actual bundled portable helper tested public v1.0.12 -> private v1.0.13 at a
  disposable path with spaces: readiness/parent exit, injected wrong-version
  rollback/reopen, then successful complete swap/restart. All 44 tables, selected
  preferences and exact profile path preserved; personal install registration
  and Windows Run unchanged. No setup executable was run. Evidence in final
  ignored run's `updater-live-result.json` / `updater-local/acceptance*.json`.
  Personal installation/profile, official website and Cloud settings untouched.
- Keep v1.0.13 unpublished, no main merge. Google branding/policy compliance is
  unresolved regardless of real account access.

## Enabled private Google Drive candidate (2026-10-26)

- Owner now reports project Todorbit / `todorbit` is External/In production,
  Drive API enabled and only drive.appdata configured; branding remains
  unverified. Console state is owner-reported. The existing external installed
  Desktop JSON exists and its project ID matches; no client/project created.
- Source inspection confirms an appdata-only PKCE/loopback authorization flow,
  appDataFolder storage, bundled Release parameters and no Release developer
  JSON import. Ordinary users do not supply client fields. No app source or
  official website change is part of this test.
- Fresh analysis clean; full serial Flutter suite **264/264**, zero JSON error
  events, 466.371 seconds. Includes auth/Drive mocks and actual local SQLite/
  encryption/settings recovery round trips. Existing OAuth configuration and
  stale/private-package gates **11/11**. Native Release has zero warnings/errors.
- Enabled private Windows Release and Inno Setup 7.1.0 compile passed. Portable
  packaging/sidecars are prepared under an ignored private run folder. The
  existing wrapper/receipt and packaging sources are reused; two Desktop
  parameters are supplied temporarily and tracked configuration is restored
  byte-for-byte to disabled/empty after packaging. Log scans found neither
  Desktop parameter value. Missing generated plugin links were recreated as
  local NTFS directory junctions; no SDK/security setting/OAuth control changed.
- Private package integrity passed: 37-entry ZIP CRC/full bundle equality,
  enabled receipt, private-file guards and SHA-256 manifest/sidecars. Source,
  Restore and copied installer-layout startup/restart schema checks pass with
  integrity OK, schema v21, 44 tables and no task/event rows. Extracted widget
  self-test passed; Windows Run registry was unchanged. The installer is not run against
  the personal Windows account; launchers redirect APPDATA/LOCALAPPDATA and
  seed widget sign-in launch off. APPDATA isolation is not a fresh Windows
  Credential Manager identity; strict fresh-user/VM acceptance remains open.
- Initial fixed-seven-second smoke force-killed initialization, leaving two
  empty schema-0 test fixtures rejected by the migration gate. Preserved them
  under the ignored run's `interrupted-startup/`, used fresh profiles and
  replaced fixed delay with bounded schema readiness. Interrupted first-start
  recovery remains a documented usability/reliability limit. Also drained the
  normal engine stderr notice directly to avoid PS 5 aborting a redirected
  parent pipeline. These are smoke-harness changes, not app fixes.
- **Owner-observed real sign-in PASS:** owner confirmed the private Source
  profile and an account outside the former test list; packaged v1.0.13
  connected with no unverified-app warning or authorization block. This does
  not measure project-wide caps or prove universal account eligibility.
- No app-control surface is available; the supported Computer Use plugin also
  reports its native pipe unavailable. A separate ignored Windows test harness
  invokes production cloud/repository/secure-storage APIs without UI automation.
  Its real Google probe passed secure session load after packaged process exit,
  one real refresh exchange, account identity and appDataFolder listing (three
  actual Google requests). Full/settings encrypted upload, verified readback,
  listing/download, wrong-phrase rejection, preview/schedule cancellation and
  selective settings/hotkey recovery then passed against real Google (27
  requests). All target SQLite tables/unrelated settings were preserved by
  settings-only recovery.
- Original private Release applied the real downloaded full backup on Restore
  startup, then started normally once more. Two independent post-startup
  verifications each passed all 44-table equality, full allowed personalization,
  exact Before Restore rows/settings, finalized receipt, retained source account
  and cloud history (4 real requests each). The actual refreshed grant contains
  **only drive.appdata**. These are service/API and packaged startup results;
  backup/settings confirmation-dialog interactions remain unobserved.
- Production Source disconnect and empty secure-record reload passed (3 real
  requests before local disconnect; no Google grant/cloud object deletion).
  Owner then confirmed same-account packaged reconnect with no warning/block
  and the connected account displayed. An independent process loaded the
  reconnected session, refreshed against Google, confirmed the sole appdata
  grant/same account and listed both retained snapshots. Scoped cleanup deleted
  exactly those two test-created objects; every pre-existing cloud object was
  retained (9 real requests, one refresh). Private app closed, local synthetic
  fixtures and the Source session retained. Total real harness evidence:
  50 Google requests, six refresh exchanges; consent behavior is owner-observed.
- Locked Windows secure-storage 4.2.2 primary backend is DPAPI encrypted JSON,
  with legacy AES-GCM/Credential Manager fallback/migration. Corrected the
  narrower internal security description; website Windows-protected-storage
  wording remains accurate and unchanged. Logical profile keys do not create
  a separate Windows vault identity. Original Release packages remain intact.
  Public release remains **BLOCKED**; see
  `docs/GOOGLE_DRIVE_PRIVATE_ACCEPTANCE.md`.
- Private artifacts are in `.buildlog/private-drive-20261026-151411/packages`;
  checksums and restart launch command are in the private acceptance report.
  Private core Google Drive tests **PASS**. Complete packaged acceptance is
  **PARTIAL**; public release is **BLOCKED** by unresolved first-start
  interruption recovery, fresh-user/manual packaged acceptance, policy review
  and the owner's publication hold. Branding remains unverified. No remaining
  owner consent action is needed for this private test.
- No main merge, Git push, app publication, public release edit, website deploy
  or Google Cloud change was performed for this private test.

## Official website publication (2026-10-26)

- Owner explicitly approved GitHub Pages publication in `2HIK4/Todorbit`.
  Website-only commit `5d77f37` fast-forwarded `main` from `7965205`; app/native
  source, version, packaging and existing Windows workflow were unchanged.
- Configured Pages for Actions with HTTPS enforced. [Deployment](https://github.com/2HIK4/Todorbit/actions/runs/40317545954)
  passed. Homepage `https://2hik4.github.io/Todorbit/`, Privacy Policy
  `https://2hik4.github.io/Todorbit/privacy.html` and Terms of Service
  `https://2hik4.github.io/Todorbit/terms.html` are publicly accessible over HTTPS.
- Anonymous live checks passed canonical homepage/all eight dist files with
  source equality after Git line-ending normalization, plus all nine external
  links. Downloads match v1.0.12, the latest actual public release. Local/CI
  static navigation, responsive/accessibility CSS and contrast checks pass.
  Rendered desktop/mobile/zoom/screen-reader checks remain UNVERIFIED because
  browser infrastructure is unavailable. See `website/README.md` and reusable
  `website/verify_live.py`.
- More specific current Google [OAuth domain guidance](https://support.google.com/cloud/answer/13804266?hl=en)
  requires DNS-level Domain verification, not URL-prefix verification. HTML-tag
  verification of the project site is possible in Search Console but does not
  satisfy that documented OAuth requirement. `2hik4.github.io` is only a
  conditional hostname, not a Google-accepted Authorized Domain. Public OAuth
  remains BLOCKED. No Google settings, domain/DNS or app release changed.

## Google Drive public distribution candidate (2026-10-26)

- Baseline `198da07`; clean start on `feature/google-drive-backups`, then
  `feature/google-drive-production-readiness`. Latest public release checked
  through GitHub CLI is v1.0.12; selected unused candidate 1.0.13+14. No personal
  installation/profile was opened or changed.
- Added bundled public Desktop client ID/client-secret parameters for exchange
  and refresh, with the existing PKCE/state flow unchanged. Release builds
  remove developer configuration import. Strict `config/google-drive.json`
  remains disabled/empty until production access is confirmed. Disabled
  builds do not load saved Google sessions or start login. Ordinary-user
  usability is still PARTIAL, not public-login PASS.
- Added one Release wrapper and a public configuration/AOT/runner hash receipt
  checked by both packaging scripts, private-file guards, candidate checksums
  and CI installer/portable packaging. Prepared truthful privacy disclosure,
  candidate release notes, and current Google Auth Platform owner actions in
  `docs/GOOGLE_DRIVE_RELEASE_READINESS.md`. The receipt is a consistency check,
  not a signature or evidence of Google approval.
- Focused auth/UI checks passed 15/15; public configuration/package gates passed
  11/11. Analysis passed with no issues. The one final serial full Flutter suite
  passed **264/264**, zero JSON error events, in 07:54. Native .NET Release built
  with zero warnings/errors and isolated source widget self-test exited 0.
  Gated Windows Release, Inno Setup 7.1.0 installer and portable ZIP passed.
  Extracted portable widget self-test, ZIP CRC (37 entries), complete bundle byte
  equality, config/AOT receipt and checksum manifest/sidecars passed. Both
  installer-layout and extracted portable copies started/restarted on disposable
  profiles with SQLite integrity OK, 44 tables and no tasks/events. Windows Run
  registration was unchanged. This is not an actual registered installer test.
- Reused the historical real Google 44-table full restore and selective settings
  recovery evidence for unchanged codec/service/recovery boundaries only.
  Bundled production-client login and fresh packaged recovery are UNVERIFIED.
  No connected browser/Cloud Console is available; Computer Use initialization
  succeeded but listing apps failed because its native pipe is absent. Physical
  Release GUI, DPI/resizing and strict clean installer acceptance need an
  authorized account and disposable Windows user/VM.
- **Public OAuth BLOCKED:** owner confirms project Todorbit is Testing,
  Branding lacks homepage/privacy/terms URLs, and Data Access lists no scopes.
  External status is unconfirmed. Found a valid installed Desktop JSON outside
  Git with both client fields; no values were printed or copied into the gated
  config. Exact-value scans of 337 source files and every portable entry found
  none of that private input parameter. The original JSON was left untouched.
- At the owner's request, prepared a responsive static GitHub Pages site with
  product information, actual v1.0.12 download links/screenshot, support, privacy
  and terms. Three-page static link/anchor/landmark/image/contrast checks pass;
  rendered browser, zoom and screen-reader behavior remain UNVERIFIED because
  browser/native UI infrastructure is unavailable. No telemetry/third-party
  scripts or fonts are added. Pages deployment is manual-only and requires
  explicit owner approval; push/PR only validates. Google's owned/verified-domain
  requirements were documented at preparation time. The later owner-approved
  Pages publication and updated DNS-verification finding are recorded above;
  no domain purchase, DNS or Google Console setting changed.
- Website/policy/terms publication is now approved and complete. The remaining
  Cloud steps in `GOOGLE_DRIVE_RELEASE_READINESS.md` and outside-test-user clean
  packaged acceptance still need completion. The app candidate remains on its
  feature branch; no v1.0.13 release/tag or updater entry has been created.
- Pushed candidate `afbb187`. Website validation CI passed and deployment was
  skipped. Initial Windows CI `40291855078` passed analysis, the full Flutter
  suite, config gates, Windows Release, portable packaging and packaged widget
  self-test, then failed because Chocolatey's feed lacks Inno Setup 7.1.0.
  Replaced that bootstrap with the official immutable vendor x64 release,
  pinned its SHA-256 and used an explicit runner-local compiler path. Local
  download-only integrity verification passed without modifying the installed
  compiler. A second CI attempt installed the official compiler but failed the
  capped native version-output probe. Replaced it with complete process output/
  exit capture and moved toolchain verification before the app checks. Policy
  wording explicitly discloses plaintext local snapshot staging even if restore
  is canceled.
- **Final Windows CI PASS:** `40296394097` at source `63b8bc6` passed compiler
  hash/install/exact version, analysis, **264 Flutter tests**, 11 config gates,
  Windows Release, portable packaging, packaged native self-test, installer,
  checksums and unpublished candidate upload. Downloaded all five CI files and
  verified both package hashes/sidecars, 37-entry ZIP CRC, disabled OAuth receipt
  and runner/AOT hashes. Website validation `40293992419` passed with deploy
  skipped. Local/CI artifact sizes and hashes are separately recorded in
  ACCEPTANCE.md. The handoff receipt changes documentation only and reuses this
  successful source verification. Main and public release/website remain
  unchanged; working tree is finalized on the feature branch.

## Google Drive backup implementation (2026-10-25)

- On `feature/google-drive-backups`, moved the main-sidebar Backups entry into Settings > Backups & Cloud. The embedded existing local panel retains manual/automatic history, create/export/import, reviewed next-launch restore, cancellation and recovery status. Added independent full/settings cloud flows, account-bound history/deletion, system-browser loopback OAuth with PKCE, profile-specific secure tokens, refresh/reconnect, a provider interface, versioned authenticated passphrase encryption, chunk progress and remote readback verification. SQLite snapshots and migrations still use the existing service; no sync engine, Android UI, OneDrive or cloud retention was added.
- Full packages carry all SQLite tables plus allowlisted personalization; linked external file contents and device-only security/startup policy are explicitly excluded. Full restore preserves a local Before Restore database and separate personalization recovery JSON, applies portable settings after database open/migration, and finalizes the receipt before permitting new user edits. Settings-only restore reuses category preview, selection and hotkey merging. Cloud limits and exact Google setup are documented in `docs/GOOGLE_DRIVE_BACKUP.md`.
- Final automated checks: `flutter analyze --no-pub` passed; the complete serial Flutter suite passed **262/262**, zero JSON error events, in 06:41 after the device-local Desktop configuration addition. The added coverage includes real encryption/SQLite round trips across isolated profiles and every SQLite table, settings-only preservation, wrong passphrase/tampering/future format/schema, PKCE/cancellation/state checks, expired/revoked tokens, 401 refresh, account switching, paging, quota/offline/interrupted transfer failures, secure client-configuration import/removal and remote verification. Earlier targeted failures involved test fixtures, teardown ownership/menu scrolling and a missing shader during overlapping Flutter test commands; sequential targeted runs and the final full suite passed.
- Native Release built with zero warnings/errors and its isolated widget self-test exited 0. A Windows Release build with the new plugins passed. Live debug UI used a verified temporary profile, rendered light/dark Settings/local/settings-transfer panels, created a verified local backup and completed MCP hot reloads with no runtime errors. Narrow light/dark 440 px, 1.3x text controls passed widget tests. Physical DPI/resizing and native widget input/Explorer behavior were not newly observed.
- The owner supplied a public Desktop OAuth client ID and a downloaded Desktop configuration outside the repository. Real Google returned `invalid_request` requiring desktop client authentication; added a minimal validated Desktop JSON import into profile-specific secure storage and supplied its secret only at runtime with PKCE still enabled. No credential content was printed or compiled into the binary. Focused authentication/UI rechecks passed 13/13 after this change, followed by the final complete suite above.
- **Real Google core flows PASS:** sign-in, forced token refresh, secure session persistence across restart, full and settings upload with remote readback, listing, download, wrong-passphrase rejection, selective settings restore with hotkey merging, confirmed full restore on an actual close/reopen, disconnect/reconnect with both objects retained, deletion cancellation/confirmation and selected deletion. The restored target matched all **44 SQLite tables** in the uploaded snapshot, with five tasks, three recurrence occurrences, recurring event, checklist/subtask relationships, category/project, habit/goal, session and saved view. Its Before Restore database matched the original target, personalization persisted, a settings recovery JSON existed and the opened receipt was finalized. Settings-only restore preserved the complete target database digest and unrelated appearance.
- Deleted only the two disposable cloud objects created during testing and removed saved tokens/client configuration from both isolated profiles. The owner's original JSON file was left untouched. Driver timing/serialization errors required scoped retries and one windowless disposable driver process termination; final live runtime checks found no application errors. Real multi-account switching, quota/revocation/network interruption and physical DPI/native widget behavior remain unobserved beyond the relevant mock/self-test coverage. No production profile or installed binary was modified; no push, merge or publication is authorized.
- Final configured Windows Release build passed from `lib/main.dart` using only the public client-ID define, and its packaged widget self-test exited 0 on an isolated profile. The 23-file Release bundle contained no database or credential JSON; exact-value scans found neither the owner's client secret nor the disposable recovery passphrase in the bundle, 29 staged files, or isolated profile files. Private configuration and test harnesses remain outside Git. A final hot-reload probe against a directly launched debug binary failed; earlier CLI-managed reload/restarts passed and the final direct runtime check was clear. The restored 44-table digest remained equal after cleanup/reopening. Changes stay on `feature/google-drive-backups`; no release package or public publication was produced.

## v1.0.12 publication (2026-10-25)

- Pushed and fast-forwarded `feature/app-ui-layout-audit` into main and published [v1.0.12](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.12) at `ebba16e` as a Windows x64 pre-release, version 1.0.12+13. Reused the clean local 245-test run and visual evidence from `100d10f`. Both [main CI](https://github.com/2HIK4/Todorbit/actions/runs/40194712436) and [tag CI](https://github.com/2HIK4/Todorbit/actions/runs/40195355512) passed analysis, 245 Flutter tests, Windows Release build, and packaged widget self-test. Canceled only the duplicate feature CI for the identical SHA.
- One new local versioned Release build, isolated packaged widget self-test, Inno Setup 7.1.0 compile, ZIP CRC (34 entries), private-data audit, complete bundle/helper byte equality, and disposable same-version portable helper swap passed. The smoke test retained its seeded task, valid SQLite database, startup-off preference, and sentinel while restarting one app at the same path. The installed application and production profile were not modified.
- Downloaded all four published assets and verified local/public/GitHub SHA-256 equality and the checksum manifest. The actual update service detected v1.0.12 from v1.0.11 for installed and portable packages, downloaded and validated each, reported v1.0.12 current, and excluded the pre-release on Stable. Checksums and unchanged manual acceptance limits are recorded in `docs/ACCEPTANCE.md`. This documentation-only publication receipt reuses the successful release CI; no additional application build is needed.

## UI audit verification completion (2026-10-25)

- Audited the exact eight prior failures in `docs/ACCEPTANCE.md`: six custom-temp I/O timeouts, one privacy fixture with concurrent old/restarted profile owners, and one pre-scroll-settlement tap already corrected in `56a27d0`. The original external locking/delay process was not captured. No application regression found.
- Privacy tests now stop and drain the old manager before restart, assert single fixture ownership, clean up on failure, and await session I/O with `tester.runAsync` before provider unmount. Existing behavioral assertions and timeouts are unchanged; production code is untouched.
- Focused affected groups passed 43/43; final privacy checks passed 6/6. One final full serial Flutter run passed **245/245** in 04:35 with no retries or timeout overrides and zero JSON error events. `flutter analyze --no-pub` passed with no issues. Reused the prior Windows Release build and isolated UI evidence; physical resizing/DPI, Release GUI, native widget behavior, and enabled-lock PIN layout retain their previous limits. No production data or installation was changed.

## Shared form layout audit (2026-10-25)

- Shared expansion styling now gives child fields 12 px of vertical clearance and avoids duplicate section borders; Task Status/Estimates/Prerequisites, series review, and backup details inherit it. New/Edit checklists share one entry row with 12 px label clearance and an 8 px action gap. PIN fields have explicit separation; session footers reuse the wrapping dialog action bar. Generated `release/` output is excluded from analysis.
- An isolated debug profile under `TodorbitUILayoutAudit-20261025` was verified before interaction. Live Flutter Driver screenshots showed dark/light New/Edit Task panels with empty/populated, short/long, focused/unfocused checklist inputs, scroll clearance, and readable expanded Status subtitles/labels. Dark New/Edit Work Session footers and empty PIN setup fields in both themes were also observed. MCP hot reload passed with no application runtime errors. A later recovery hot restart hit a temporary file lock; the running app remained usable. Physical narrow-window resizing, DPI, native widget behavior, and the enabled-lock PIN form remain unverified; native Computer Use could not connect. Narrow Task and Session forms were widget-tested at enlarged text scale in both themes.
- Analysis, focused layout tests, and Windows Release build passed. The full serial suite completed with 237 passes and eight failures: seven temporary-file locks/timeouts on the workspace temp drive and one prerequisites test tapping before its scroll settled. Added scroll settling and a hittability assertion; all 43 tests in the affected groups then passed sequentially with the normal Windows temp directory and a two-minute limit. All 245 tests are covered across the full pass and retries; this is not a single clean full-suite run. The initial C: redirected run and Release attempt also reported a Windows resource failure; the Release retry with workspace-drive temp files passed. Existing nonfatal scroll hit-test warnings remain. No production profile or installation was modified.

## v1.0.11 update handoff repair (2026-10-24)

- Read the personal v1.0.10 update receipt without changing the installation or profile. It records the same-path Todorbit process conflict after the helper waited for the original app PID. The old helper did not record process IDs, so whether a widget action, user launch, or stale helper started that process cannot be distinguished retrospectively. The native single-instance guard protects profiles but did not reserve the installation during replacement.
- The helper now holds `Local\TodorbitUpdateHandoff` during replacement, rejects a pre-existing same-path process with its PID before asking the app to close, and permits brief exiting launches before treating a post-handoff process as a conflict. New app launches exit promptly while the mutex exists so their executable mapping cannot lock the installer; the helper restarts the updated app with `--update-restart` after verifying the installed version. The old v1.0.9 installed binary cannot honor this gate, so affected users may need to run the new installer manually once.
- Replaced the README image byte-for-byte with the user-supplied 1255×679 `Screenshot.png`, updated its alt text, and kept the layout. The source screenshot has no visible cursor, interaction overlay, or personal records.
- `flutter analyze --no-pub`, all 243 serial Flutter tests, native .NET Release with zero warnings, Windows Release 1.0.11+12, packaged widget self-test, targeted conflict test, and an isolated Release-app handoff gate test passed. Inno Setup 7.1.0 compiled the setup; the 34-entry portable ZIP passed CRC validation. A disposable same-version portable helper swap from the final ZIP closed a running widget, restarted one app at the same path, and retained a seeded task, valid SQLite database, sentinel, and disabled widget startup preference. Final review caught that failure recovery needed the helper restart flag too; a forced post-handoff version mismatch then proved rollback and automatic reopening with the seeded task intact. This tests the helper and file replacement, not the Settings button or registered installer upgrade. The personal registered installation and profile were not modified.
- Merged and published [v1.0.11](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.11) as a Windows x64 pre-release at `7ada916`. Both final `main` and tag Windows CI passed analysis, the full Flutter suite, Release build, and packaged widget self-test. The four published assets were downloaded and matched the local SHA-256 digests. Setup: `ED40DC66B3FDBA7783B7A46B5C812B76E7B0233A5B652BE006DA48F482AEA456` (46,909,855 bytes). Portable ZIP: `F8F36ED0783AA2F115C70E99F5A423E5C44500B0DF058CA0BF5F76EE5FCCDBC4` (61,970,679 bytes). The app's `SoftwareUpdateService` selected each asset from the public pre-release feed for v1.0.9 and reported v1.0.11 current. The registered installer and exact Settings button handoff still require an isolated Windows account or VM.

## v1.0.10 Software Updates layout (2026-10-24)

- Moved only the available update action and collapsed Markdown Details below Check for Updates. Version/status, last checked, automatic checks, channel, and Check retain their previous relative positions. The 460 px, 1.3x text widget test now asserts the full order and Details behavior.
- `flutter analyze --no-pub`, the focused Software Updates test, and all 242 serial Flutter tests passed locally. An isolated debug profile showed the current-version Software Updates screen in dark theme with the requested preference order. The available-release action order was verified in the rendered widget test because the live app is already v1.0.9. The production installation and profile were untouched.
- The prior documentation-only `main` CI run failed on a temporary-file lock in an unrelated privacy test; that test passed locally in this run. Require a fresh passing Windows CI run before publishing v1.0.10.
- Merged feature commit `87e1109` into `main` and published [v1.0.10](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.10) as a Windows x64 pre-release at release commit `bfcfc31`. Feature and release `main` CI passed analysis, the full Flutter suite, Windows Release build, and disposable-profile packaged widget self-test. Local native Release build, packaged widget self-test, Inno 7.1.0 setup compile, ZIP CRC, embedded helper equality, and package data audit passed.
- All four public assets were downloaded and matched local SHA-256 digests. Setup: `1EFD4F16AA81BCBF991BE954C4FCC521F43A120A02AF4838D28E982482F2D8AF` (46,907,464 bytes). Portable ZIP: `B6906323E2893CB64EBB5EB21DEDEA3ED68DF6D244628DD2291C7E270031DAE3` (61,970,221 bytes). The unchanged v1.0.9 `SoftwareUpdateService` selected v1.0.10 and the exact installer and portable assets on Pre-release, then reported v1.0.10 current. An actual registered update handoff remains unverified without an isolated Windows account or VM.

## v1.0.9 publication and public updater check (2026-10-24)

- Merged feature commit `1a41569` into `main` by fast-forward and published [v1.0.9](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.9) as a Windows x64 pre-release at that commit. Feature, `main`, and tag Windows CI runs passed analysis, the full Flutter suite, Windows Release build, and the disposable-profile native widget self-test. This closes the v1.0.8 `Get-FileHash` CI preflight failure.
- All four public assets were downloaded and matched their local SHA-256 digests. The installer digest is `8877F81553E6D92C982E3E2E3D25857930DCE3BBE0718D3DAB2C0FE305B12F8F`; the portable ZIP digest is `4F94CD316A2B6B7675FE5E6352D68569D1CE1CBD01D6DDB4C6134500D81B66EC`. The published tag points to `1a41569`.
- In a temporary staging directory, the actual `SoftwareUpdateService` selected the v1.0.9 installer from the public GitHub feed for v1.0.8 on the Pre-release channel, downloaded all 46,907,767 bytes, passed its size/SHA-256 verification, and reported v1.0.9 up to date. The temporary download was removed. The personal installation and profile were not touched. A registered v1.0.8 Update and Restart flow, real Windows login, and physical DPI checks remain unverified and require an isolated Windows account or VM.

## v1.0.9 UI and widget startup candidate (2026-10-24)

- Traced repeated selection overlap to Flutter's `DropdownButtonFormField`/`DropdownButton` route centering the selected row over the trigger. Replaced form and compact selects with shared `AnchoredSelectField`; action menus keep their separate PopupMenuButton behavior. A widget test checks below-field placement in light/dark, viewport containment near the bottom at 1.3× text scale, mouse selection, and keyboard choice. An isolated Flutter Driver GUI selected Pre-release and persisted it; dark and light open-menu screenshots show the trigger and label visible with the menu below.
- Corrected Update Channel's label/field gap and Backup & Restore's action spacing. Added a shared About this view button to Habits, Goals, Calendar, and Reports; Habits and Goals widget flows opened their descriptions individually.
- Reused the native per-user Run registration for widget startup, with default-on widget settings, explicit-off persistence, profile-specific value names, stale-path repair, and Release app synchronization. A private-key native self-test covers registration on/off, no duplicate value, path repair, and saved off. Actual Windows sign-in behavior and a registered installer upgrade remain unverified. Debug GUI runs used isolated APPDATA/LOCALAPPDATA and do not synchronize startup registration.
- Replaced the update helper's `Get-FileHash` call with .NET SHA-256 so PowerShell preflight has no dependency on that cmdlet. Local helper preflight tests passed; the previous CI-specific failure still needs a passing Windows CI run on this branch.
- The native widget now uses the Windows GUI executable subsystem to avoid a console at sign-in. CI waits for its `--self-test` process explicitly and checks its exit code, matching the local packaged self-test procedure.
- Final `flutter analyze --no-pub` and all 242 serial Flutter tests passed after the narrow-label correction (the existing nonfatal workspace scroll hit-test warning remains). An isolated Flutter CLI hot restart completed. Native Release build, source self-test, Windows Release, and packaged self-test passed. Installed upgrade, login, physical DPI, and publication remained unverified at this checkpoint.
- Final Windows Release built as 1.0.9+10 and the packaged widget self-test exited 0. Inno Setup 7.1.0 produced the 46,907,767-byte installer (SHA-256 `8877F81553E6D92C982E3E2E3D25857930DCE3BBE0718D3DAB2C0FE305B12F8F`); portable packaging produced a 61,970,183-byte, 34-entry ZIP (SHA-256 `4F94CD316A2B6B7675FE5E6352D68569D1CE1CBD01D6DDB4C6134500D81B66EC`). ZIP CRC and embedded update-helper byte equality passed. The stable installer AppId, install path, and profile paths remained unchanged.
- Isolated dark and light debug GUI flows opened About this view in Habits and Goals individually and captured Backup & Restore. Both popovers and the Import SQLite description/action gap rendered clearly. Neither run touched the registered installation or personal profile.
- A 700 × 650 isolated Windows debug window exposed an edge case: the menu flipped above Update Channel and covered its separately rendered label. Moving the label into the shared select anchor kept it outside the popup; a second narrow GUI screenshot and the 350 × 400 enlarged-text widget test confirmed it. A final normal-size dark GUI flow reopened the dropdown and persisted Pre-release. The Release bundle and packages were rebuilt after this correction.

## Updater handoff repair and Software Updates UI (2026-10-24)

- Published [v1.0.8](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.8) as a Windows x64 pre-release from merge commit `3d24650` after pushing `feature/updater-restart-ui` (`9d989e1`) and merging it into `main`. All four published assets were downloaded again. The installer (46,903,624 bytes) SHA-256 is `362A5E74462508B04429E6845E0A7E6555E2CF159127C4ABE05B997437CC0BDC`; the portable ZIP (61,978,365 bytes) is `2C015ABA3322A732D6ED0A905A179D4C444DE75EF62AF8A2465C3366C9947BD3`. The downloaded checksum and release-notes files also matched their uploaded hashes. Release notes direct installed v1.0.6 users to the manual installer and state that registered upgrade and the actual in-app button remain unverified. No personal installation or production data was changed.
- Windows CI on the tagged merge `3d24650` passed analysis but failed one of 238 tests: the helper preflight test received `Get-FileHash` not recognized in its PowerShell process. Local full and focused suites passed. The CI cause is unresolved and the in-app updater depends on that command; do not treat the pre-release as a fully verified updater. The installer and ZIP asset bytes were not changed after publication.
- Reproduced the reported v1.0.6 failure without touching the registered installation: the profile contains the v1.0.7 helper but no result receipt, and the installed executable remains v1.0.6. A disposable Dart `ProcessStartMode.detached` launch returned a PID while a minimal PowerShell script never ran; normal launch completed both immediately and after the parent exited. The published helper syntax and registered path were valid. This establishes the failed process handoff, rather than an omitted user action.
- The app now starts the helper normally, waits for a ready receipt before closing, and surfaces preflight errors while still open. The helper verifies registration, checks for another app at the target, waits for the widget, verifies the replacement executable version after installation, records a result, and attempts to reopen the available app on failure. Failure after handoff is also designed to show a Windows error message. Profile paths, Inno AppId, and database migration behavior are unchanged.
- Software Updates places the available version, a short plain-language excerpt from the first release-notes paragraph, and the primary action before a collapsed Details section. Markdown notes render inside a bounded scroll area with active images blocked and HTTPS links handled by the existing Windows channel. A narrow, enlarged-text widget test and process-handoff tests pass. The Settings GUI was captured in an isolated debug profile at 1264 x 681; the available-release details state was verified by widget tests, not by a live installer GUI.
- A targeted Settings audit found release notes were the only intended Markdown string rendered raw in `lib/features/`. Backup history already collapses technical detail, and Share settings keeps actions outside bounded scrolling content, so no unrelated dialog was redesigned.
- A disposable real portable 1.0.6 to 1.0.7 bundle swap and restart passed with a profile sentinel and executable version 1.0.7+8. This checked the helper independently of the app UI. The account's registered v1.0.6 installation was untouched, so installed upgrade, UAC cancellation, and real post-upgrade data reading remain **UNVERIFIED**. See `docs/ACCEPTANCE.md` for the exact remaining manual checks.
- Prepared a local **1.0.8+9** candidate on this branch without publishing. Native and Flutter Release builds, source and packaged widget self-tests, Inno 7 setup compilation, and a 34-entry portable ZIP with full CRC validation passed. Both executables report 1.0.8+9. The Inno AppId, per-user install path, and privileges setting stayed the same.
- The final local unsigned candidate packages are ignored build artifacts: setup SHA-256 `362A5E74462508B04429E6845E0A7E6555E2CF159127C4ABE05B997437CC0BDC` and portable ZIP SHA-256 `2C015ABA3322A732D6ED0A905A179D4C444DE75EF62AF8A2465C3366C9947BD3`. They were later published unchanged, but have not been installed as a registered upgrade.
- A second disposable real portable upgrade used the published 1.0.7 ZIP and a branch 1.0.8 ZIP built before the final helper error-message change. Before swapping, repository writes seeded a UUID task and fixed event in the exact location-based portable profile plus update settings and a sentinel. The helper exited 0, launched one 1.0.8+9 process, and all seeded records/settings remained. A wrong digest returned a failure receipt, retained 1.0.8, and reopened one app; repeated helper runs succeeded with one app and both records intact. The actual in-app button and registered setup flow remain separate, unverified checks.
- Final stable-source `flutter analyze --no-pub` and all **238** serial Flutter tests passed; the longstanding nonfatal workspace scroll hit-test warning was still emitted. All **11** focused updater/process/Markdown tests passed again after the final helper message change. The final Release bundle contains the source helper byte-for-byte; PowerShell parsing, Inno setup compilation, 34-entry portable ZIP CRC and embedded-helper checks, and the packaged widget self-test passed. The registered setup flow and actual in-app update button remain unverified on a disposable installation.

## Settings, backup, and UI audit (2026-10-24)

- Published [v1.0.7](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.7) as a Windows x64 pre-release from tag commit `66f4693` after merging the verified feature branch into `main`. The installer (46,752,080 bytes) SHA-256 is `4EFD283BCB34E03CC7D46B5AF3A17360A6FC761E0891C6A9FE1B2A095B01ADD0`; the portable ZIP (61,760,119 bytes) is `FF60F08046E47827A8597EAA7A53CCAECD756EE42A4AA0B3BD1F7526A1CB3A54`. All four public assets downloaded and matched local hashes and GitHub digests.
- The live `SoftwareUpdateService` check against GitHub selected v1.0.7 and its notes for v1.0.6 on the Pre-release channel, chose the installer for an installed copy and ZIP for portable, and reported v1.0.7 up to date. Its public installer download completed with progress callbacks and passed size and SHA-256 verification. The personal registered v1.0.6 installation was not updated; Settings UI interaction and installed update/restart/data preservation remain for the user's manual test or a disposable Windows user/VM.
- Work was committed on `feature/settings-backup-ui-audit` from the fetched v1.0.6 `main` and fast-forward merged into `main`. A fresh disposable APPDATA/LOCALAPPDATA profile opened with zero user records; its tasks, events, categories, projects, habits, goals, work sessions, and deletion tombstones were all empty. No seed inserts were found. Existing personal Trash records were not inspected or changed, so their provenance remains unknown.
- Calendar period and segmented controls now retain their positions through Day/Week/Month, including a live isolated debug GUI pass. Segmented choices across Calendar, event editing, and Settings no longer gain a selected-icon height. The Custom Event Color dialog uses Todorbit's Material segmented control; live light-theme Primary/Wheel, HEX preview/application, and the widget test for Primary/Accent/Wheel and safe closing passed. Backups now aligns with Settings in the sidebar.
- Hotkeys gained a Duplicate preset action and a disabled Reset control when a binding equals its default. Existing preset persistence and shortcut dispatch were retained; focused tests cover conflicts, reset state, and store reload. Share settings exports selected allowlisted personalization into versioned JSON and validates imported categories before replacement; hotkey presets may be merged. The native Windows JSON file dialog was added.
- Backup & Restore now groups creation/export, import/restore, and history, with human dates and technical details collapsed. A verified snapshot preview shows record counts. A pending restore explicitly requires reopening, and a completion receipt appears only after the restored database opens. Startup now checks the restored schema after applying the snapshot, preserving the upgrade approval gate.
- A disposable schema 20 snapshot with identifiable task and weekly event restored through actual debug startup. The app presented schema upgrade approval, made Before Restore and Before Upgrade backups, migrated to schema 21, and displayed the event in Day Calendar. Read-only SQLite queries found the restored task/event and the previous task in Before Restore. This is debug GUI evidence, not a production-profile restore or installed-updater test.
- Final `flutter analyze --no-pub` passed with no issues, all 234 serial Flutter tests passed, native .NET Release built with zero warnings, source and packaged widget self-tests passed, and Windows Release built as v1.0.7. A final isolated debug launch and hot reload completed. Installer/portable packaging and public updater checks were completed after the merge, as recorded above.

## v1.0.6 Windows pre-release (2026-10-24)

- Advanced app and native widget versions to 1.0.6, updated public docs and release notes, and retained the stable installer AppId, install directory, and profile paths.
- `flutter analyze --no-pub` and 229 serial Flutter tests passed (existing nonfatal workspace scroll hit-test warning). Native .NET and Windows Release builds, source and packaged widget self-tests, Inno Setup 7 compilation, and portable ZIP archive/contents checks passed.
- A disposable same-path portable 1.0.5 to 1.0.6 update passed with isolated profiles using both the local 1.0.5 ZIP and the SHA-256-verified public 1.0.5 ZIP: the helper restarted the new bundle, retained each database and sentinel file unchanged, and kept binary rollback. Actual installed upgrade remains unverified because the current account has a real registered Todorbit installation; it was not touched. See `docs/ACCEPTANCE.md`.
- Merged `feature/calendar-ui-audit` into `main` and published [v1.0.6](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.6) as a pre-release. Downloaded installer, portable ZIP, checksum file, and release notes matched local SHA-256 hashes and GitHub asset digests. The app's `SoftwareUpdateService.selectRelease` selected both package types from the live GitHub API response for a 1.0.5 user on the Pre-release channel. Stable intentionally ignores pre-releases.

## Codex development workflow (2026-10-24)

- Kept the installed official Dart/Flutter plugin and Apple Design skill. Added repo-local `todorbit-ui-review` and `todorbit-regression` skills under `.agents/skills/` and linked them from concise `AGENTS.md` and `docs/CODEX_WORKFLOW.md`. No new plugin, MCP config, or project dependency was added.
- Added a focused widget regression for the actual app theme's task input in light and dark; existing event editor, dropdown, dialog, calendar, and narrow layout tests remain the targeted UI suite. The Dart/Flutter MCP connected to the editor DTD and analyzed `lib/main.dart` without errors; no app was connected for live inspection. Automated checks do not establish physical Windows GUI or native widget behavior.
- Both skill manifests passed a local frontmatter/name check. Skill Creator's Python validator could not start because PyYAML is absent in the local Python environment. `flutter analyze --no-pub` and 13 focused UI/calendar tests passed; the Dart/Flutter MCP found no errors in the new test. This checkpoint changes development configuration and tests only, not product or profile data.

## Windows software updates completion pass (2026-10-24)

- Hardened the helper to wait for the widget process at the current bundle path and roll a portable swap back when the restarted app exits immediately. The Settings install action now ignores repeated clicks and releases the process even if database close reports an error after the helper starts. Update preference loading rejects malformed field types instead of silently changing choices.
- A disposable Windows x64 portable 1.0.4 → 1.0.5 upgrade used the final packaged ZIP and kept the exact executable/profile path. The new app stayed running. Its schema 20 profile retained a task, fixed event, valid dark custom theme preset, calendar/appearance preferences, widget settings, and update channel. The schema remained at 20 pending user-approved migration. An immediate-exit replacement rolled the binary back; wrong digest and still-running widget attempts failed before replacement. The isolated native widget accepted its exit command and exited. A mismatched installed target was rejected before setup launched.
- Isolated Flutter Driver navigation and screenshot inspection showed Settings > Software Updates at 1264 × 681 with version, status, channel, and check controls. Toggling automatic checks persisted and reopening worked. Native computer control exposed no app windows, so physical mouse, DPI, Explorer widget painting/input, and full migration approval remain unverified.
- `flutter analyze --no-pub` and all 228 serial Flutter tests passed; the existing nonfatal workspace scroll hit-test warning appeared. Native .NET Release built with zero warnings/errors. The source and packaged widget self-tests, Windows Release build, Inno Setup 7 installer compilation, portable ZIP packaging, and final-package helper smoke test passed. The final local artifact hashes are in `release/SHA256SUMS.txt`.
- The current Windows account has a registered Todorbit installation at the stable AppId/path. No isolated account or VM was available, so an actual installed upgrade and installer recovery were not exercised; that installation and production profile were left untouched. Unsigned publisher authentication and post-update widget visibility also remain unverified. See `docs/ACCEPTANCE.md` and `docs/SOFTWARE_UPDATES.md`. No release was published.

## Windows software updates (2026-10-23)

- Added Settings > Software Updates, per-profile preferences, automatic and manual GitHub Release checks, semantic-version/channel selection, exact Windows x64 package and SHA-256 validation, download progress, explicit unsigned-package confirmation, and a separate Windows update helper. Portable staging keeps the installation path and rollback copy; registered installs use the existing Inno identity. Installation does not modify profile databases or existing personalization files. See `docs/SOFTWARE_UPDATES.md` for publishing and recovery steps.
- Final `flutter analyze --no-pub` and all 228 serial Flutter tests passed. Windows Release and native .NET Release builds, packaged widget self-test, Inno installer compilation, and portable ZIP packaging passed. The final local artifact hashes are in `release/SHA256SUMS.txt`. Disposable synthetic portable helper checks confirmed both rollback after a failed restart and a same-path swap retaining the old binary folder. An isolated debug app started and hot restarted under temporary APPDATA/LOCALAPPDATA; native Computer Use could not connect to its pipe, so live Settings pixels remain unverified.
- Real installed and portable updates, signed-package verification, native widget close/restart, migration failure recovery, and success without duplicate windows still need isolated Windows acceptance. No production profile was opened or modified for this work. No release was published.

## Calendar UI audit follow-up (2026-10-23)

- Continued from `e10fe1a` on `feature/calendar-ui-audit`. Isolated debug GUI inspection of New/Edit Event, Task, Habit, and Goal confirmed their title and footer layouts at 1264 × 681. Habit End day was hidden at the old 510 px cap; New/Edit now cap at 550/580 px. Advanced Search needed spacing between floating-label selects. Narrow widget tests exposed Habit/Search dropdown and footer overflows; selects now constrain content and Habit, Goal, and Search use a shared wrapping action bar. No model, repository, schema, or production data changed.
- `flutter analyze --no-pub` and all 221 serial Flutter tests passed; the suite emitted the existing nonfatal `workspace_test.dart` scroll hit-test warning. Native .NET Release built with zero warnings/errors and the source widget self-test passed. Windows Release build and packaged widget self-test evidence is recorded in `docs/CALENDAR_UI_AUDIT.md`.
- Narrow 360 × 600 at 1.5× and Search 430 × 620 at 1.3× were widget-tested, not physically resized in Windows. A native narrow offscreen capture showed control and scrollbar clearance, but Computer Use exposed no native windows. Release GUI pixels, real scrollbar drag, Explorer widget input, and physical DPI/text scaling remain manual acceptance items in `docs/CALENDAR_UI_AUDIT.md`.
- A second isolated debug GUI pass exercised New/Edit Work Session, recurring Event series scope, Template Save/Apply, and Saved View Create/Edit. Template Save and Apply had floating-label collisions; added field gaps and constrained selects, then reopened both dialogs with clear labels. Focused Template tests cover those gaps. ID 20 New/Edit consistency is now supported by normal-size debug GUI evidence; ID 02 scrollbar drag and ID 19 broader physical/native consistency remain partial.

## Calendar and cross-app UI audit (2026-10-23)

- Work is on `feature/calendar-ui-audit` from clean `main` at `0a3548e`. Schema 21 adds category event colors and extensible event details with a reusable type catalog. Existing location data migrates to a saved Location detail; native schema support is raised to 21. Existing events keep explicit colors, and project inheritance is omitted because events have no project ID.
- Profile settings now persist sidebar order, last selected Calendar view, and first weekday. Calendar Week/Month headers, date pickers, recurrence weekday rows, habit week summaries, and weekly availability use the configured order. The Event editor has a compact title/icon row, anchored Category and Color menus, a custom color wheel/HEX picker, live duration, clearer recurrence ending options, and optional Details rows. Day details open in a centered modal. Creation/editing forms gained top and trailing scroll space; Habit and Goal dialogs are shorter.
- `flutter analyze --no-pub` passed with no issues, focused tests passed, and the full serial Flutter suite passed 217 tests. Native .NET Release built with zero warnings/errors; source and packaged widget self-tests passed. Windows Flutter Release built and its executable stayed alive on `C:\Users\User\AppData\Local\Temp\TodorbitCalendarAuditFinal`, creating an isolated SQLite database.
- An isolated Flutter Driver debug session was inspected in dark and light at 1264 × 681. Month headers and restoration, Event Title, Category/Color menus, custom HEX preview/application, Details row, duration, recurrence controls, centered day dialog, Habit dialog, Settings, and sidebar-order dialog were observed. A color-dialog disposal assertion found during this pass was fixed and the interaction repeated without a new process error. The Computer Use native helper could not connect to its pipe, so Release pixels, physical scrollbar/DPI/keyboard interactions, and native widget UI remain unverified. See `docs/CALENDAR_UI_AUDIT.md` for per-issue evidence and steps. No production profile was opened.

## v1.0.5 pre-release preparation (2026-10-21)

- Fetched GitHub: `feature/todorbit-feedback-round4` at `9c12bd0` is six commits ahead of `origin/main`; the worktree was clean. The public repository has v1.0.3 and no v1.0.5 release or tag.
- Advanced Flutter and standalone native widget versions to 1.0.5 and updated current release documentation. The Windows build derives main executable resources and packaged widget version from Flutter; packaging reads the same version. The v1.0.3 public release and historical audit remain untouched.
- Physical native widget and installer acceptance limits remain listed in `ACCEPTANCE.md`.
- `flutter analyze --no-pub` passed with no issues; all 208 serial Flutter tests passed. One existing nonfatal scroll hit-test warning appeared in `workspace_test.dart`. Native .NET Release built with zero warnings/errors and its source self-test passed. The Windows Release build, packaged widget self-test, and disposable-profile single-instance/profile-isolation script passed. The .NET vulnerability query found no vulnerable packages in configured sources.
- An isolated Release app opened with Todorbit branding and an empty Today view on a disposable profile. The widget process started with that profile, but Computer Use did not expose its Explorer-hosted child as a targetable window. New Task interaction was not completed; live widget painting/input and installer lifecycle remain unverified.

## Native widget final control polish (2026-10-21)

- Replaced the separate bordered date buttons with internal 32 px actions on
  one rounded date field; drew dropdown arrows at a stable trailing position
  and removed square parent corners. Rounded Quick Add to match the painted
  field. Added bottom scroll space, removed the editor footer divider, and
  raised the default editor client height to 570 px.
- A first dark/light offscreen render exposed square choice corners and the
  last field crowding the footer; a second dark/light/custom render showed
  corrected corners, spacing, date actions, and arrow alignment. The calendar
  and rounded Quick Add outline were also rendered; its placeholder did not
  appear in `DrawToBitmap`. These are WinForms observations, not live
  Explorer pixels. The initial screenshot path was absent; the user then
  supplied all five baseline images at
  `D:\AI_Projects\Todorbit_Widget_UI_Review_References`. They confirm the
  prior date-border collisions, text-adjacent dropdown arrows, corner/edge
  artifacts, and crowded final row. The post-fix offscreen renders do not
  establish live Explorer behavior.
- Native Release build (zero warnings), source and packaged self-tests, four
  focused Flutter tests, and Windows Release build passed. Geometry tests cover
  date action separation at 170/245/340 px, clearing, and choice arrow state.
  Computer Use reported no native windows, so physical mouse, dropdown open,
  Explorer composition, Win+D, DPI, and monitor-edge checks remain unverified.
  See `docs/ACCEPTANCE.md` and `docs/windows-widget.md` before release.

## Native widget UI redesign (2026-10-21)

- Rebuilt the native Edit Task form into themed, responsive sections with
  consistent fields and buttons, custom choice and date controls, and a fixed
  action area above compact themed scrolling. Every existing value still saves
  through the widget repository with stale-edit and dependency review handling.
- Replaced the widget's header action glyph with an app-window/open arrow,
  corrected view-specific empty copy, added a slim list scroll cue, and made
  selected tabs and menu hover/check colors follow the active palette. The
  custom theme error color now reaches native validation feedback.
- Release native build, source and packaged self-tests, focused Flutter widget
  tests, `flutter analyze`, and Windows Release build passed. Offscreen editor
  and calendar renders were inspected in dark/light and narrow layouts. Native
  computer-use inventory exposed no windows, so Explorer pixels, mouse input,
  task-editor activation, context-menu placement, DPI, and Win+D are still
  **UNVERIFIED**. See `docs/ACCEPTANCE.md` and `docs/windows-widget.md`.

## Feedback round 5 implementation and audit (2026-10-21)

- Continued on `feature/todorbit-feedback-round4`. Added inline local spell underlines, shared New/Edit schedule columns, a persistent full/compact checklist and subtask text setting, selectable checklist text, icon-only resource actions, a subtle dismissible Info menu, and working workspace hotkey dispatch. Reordered optional task planning below composition and cleaned major section separators. The native widget received balanced bottom padding and a reorganized task editor. No database schema or production profile changed.
- An isolated debug Flutter Driver session was visually inspected in light and dark at a 1265 x 681 desktop window. New and Edit Task, schedule columns, long checklist/subtask text, compact and full modes, Settings persistence, Info popover, and the red underline on misspelled title text were observed. A real dialog disposal error found while saving a draft subtask was fixed, then repeated without runtime errors. A second pass also removed row-level subtask dividers. The Windows Release application started with a disposable profile and created its own database, but the available computer-control surface did not expose the Release window for visual interaction.
- Acceptance evidence and remaining physical Windows checks are in `docs/ACCEPTANCE.md`. Native widget self-test and Flutter widget tests do not establish mouse, Win+D, DPI, or painted native editor behavior.

## Codex environment setup (2026-10-21)

- Installed the official Dart/Flutter Codex plugin and its bundled skills and Dart MCP registration; installed UI/UX Pro Max globally after source inspection. Existing Apple Design and built-in OpenAI skills were retained.
- Made project guidance task-scoped and added `docs/CODEX_WORKFLOW.md` for reasoning, search, verification, UI review, and handoff conventions. This setup made no application behavior or data changes.
- Dart MCP initialized, listed 14 tools, accepted the project root, and `analyze_files` returned no errors in a direct protocol probe. A focused Flutter preference test passed. UI/UX Pro Max search returned a relevant result; its optional upstream validation script could not run because PyYAML is not installed. The current chat's tool catalog predates plugin installation, so normal in-chat MCP discovery remains for a new session.
- The temporary inspection clone `.codex-audit-ui-ux-pro-max/` remains untracked: automatic command review rejected its recursive deletion. Do not commit it.

## Feedback round 4, part 2 implementation (2026-10-20)

- Continued on `feature/todorbit-feedback-round4` from Part 1 commit `5fdc737`.
  Read all eight private screenshot references. The screenshots show older
  TodoPilot branding, while current source and the isolated Part 1 Release GUI
  show Todorbit. No compatible data path or installer identifier was renamed.
- Replaced the narrow checklist action strip with one overflow menu; rows now
  reserve width for selectable two-line text, expand and collapse when needed,
  and have subtle dividers. Saved and draft checklist edits share a responsive
  dialog whose width stays fixed while typing. Draft and saved subtasks have
  separators and draft actions use an overflow menu.
- The task editor now places scheduled day and deadline together where wide,
  stacks them when narrow, and labels their independent clear actions. Resource
  actions have compact icons and short labels; the redundant empty-state line
  is removed. List views have filter-accurate Info actions. Settings is grouped
  into Appearance & Themes, Hotkeys, Task Preferences, Notifications, Widget,
  and Privacy & Data, with a compact section picker on narrow windows.
- The native Explorer-hosted widget menu uses a semantic-palette ToolStrip
  renderer. The update-time footer is no longer painted, freeing vertical task
  space. Its Open Todorbit control uses a small window/orbit icon and a native
  tooltip. The native task editor is shorter and resizable, with matching
  palette colors and controls anchored to available width and height. Native
  menu and task editor pixels still require direct GUI acceptance.
- Version advanced locally to 1.0.4 in Flutter and the native widget for an
  unpublished release candidate. All 203 serial Flutter tests passed, then the
  final Info-popover contrast fix passed its focused test; `flutter analyze`,
  native Release build, widget self-test, and Windows Release build passed.
  The isolated GUI showed light and dark Settings, the task schedule and
  checklist draft areas, and the final readable Info popover at 1266 x 713.
  Native widget menu/editor pixels and long saved checklist interactions remain
  on the manual checklist. No production profile was opened.
- The final local portable ZIP has 33 entries and passed a full ZIP read.
  `release/Todorbit-1.0.4-win-x64-portable.zip` SHA-256:
  `B3AE11E5E7F00CCB428FFE8827377275BC18C84089CA037F5693E7DC53340ABF`.
  `release/Todorbit-1.0.4-win-x64-setup.exe` compiled with Inno Setup 7.1.0;
  SHA-256: `065D01F0A04E33441E7F54CBB6413446EFF2E3FF7C35B00A6B7DBDF9D85B3B05`.
  Both artifacts are unsigned and have not been installed or published.
  The final single-instance and separate-profile script passed; one disposable
  process required a forced close after its cleanup warning.

## Feedback round 4, part 1 implementation (2026-10-20)

- Created `feature/todorbit-feedback-round4` from fetched `origin/main` with a
  clean initial working tree. The public v1.0.3 tag, release, assets, and
  published branch remain untouched. Read the private screenshot references
  from `D:\AI_Projects\Todorbit_Feedback_Round4_Screenshots`; current source
  and an isolated Release GUI show Todorbit branding, so the TodoPilot image
  appears to be from an older executable.
- Fixed widget movement snap-back: `RenderLayer` reused saved settings X/Y
  while `SetWindowPos` was applying live drag coordinates. Painting now uses
  the HWND rectangle; resize repaint is coalesced, capture loss saves current
  geometry, and DPI/display repositioning waits until drag ends. Geometry
  calculations have self-test coverage. Real mouse movement remains pending
  because the Explorer child is not targetable by Computer Use.
- Added a per-profile native main-app mutex and same-window activation with
  queued task/appearance commands. Ten secondary launches on one disposable
  profile left one process; an independent profile ran simultaneously with
  its own database. `--appearance` routed to one existing Customize Theme
  dialog in isolated GUI observation. Native widget launch now inherits its
  explicit APPDATA override rather than delegating to the shell. Widget menu
  click and minimized restore still need direct GUI checks.
- Added a functional per-profile Hotkeys editor with capture, conflict and
  reserved-key rejection, search, reset, and named preset operations. Added
  task display/default settings: Today by default, No Date option, Anytime
  exception, and completed tasks optionally faded at the bottom of eligible
  active lists. Completed view remains independent.
- New Task now holds draft checklist items and one-level subtasks with child
  planned dates/deadlines until Save. Repository creation is transactional;
  cancellation writes no children. Checklist text is selectable without
  editing. Existing task checklist edit dialog has stable width.
- Added an on-demand local Windows spelling review for task titles, notes,
  checklist items, and subtask titles, with explicit suggestion choice and an
  enable/disable setting. It currently uses the installed `en-US` dictionary;
  Windows COM GUI behavior still needs observation. Added native Explorer file
  drop handling in task Resources, with target feedback, path deduplication,
  validation, and attach-copy/link-original choice. The Windows drop path still
  needs real Explorer drag testing.
- No SQLite schema change. New preferences extend the existing per-profile
  appearance settings JSON. All 198 Flutter tests pass with serial execution,
  and `flutter analyze` reports no issues. The final native Release build has
  zero warnings/errors and its widget self-test passes on a disposable profile.
  The final Windows Release build passes; its packaged widget self-test and
  the disposable-profile single-instance regression script also pass. Actual
  widget dragging, native Explorer drop, and Windows spell-checker GUI behavior
  still need direct observation. The manual matrix is in `docs/ACCEPTANCE.md`.

## Final private GitHub review (2026-10-20)

- Authenticated GitHub account `2HIK4` and private repository `2HIK4/Todorbit`
  were confirmed. The four observed Windows CI runs passed, including tag
  `v1.0.3` at `919c618`. GitHub vulnerability alerts were enabled. Branch
  protection was unavailable on the current private repository plan.
- The existing installer, portable ZIP, and checksum file hashes match their
  uploaded GitHub asset digests. ZIP integrity passed. The ZIP has 29 files and
  four directory entries with no personal data files found in its entry list.
  The tag's application source matches the original package checkpoint; later
  commits only changed the README screenshot.
- Visual inspection exposed a screenshot regression at the tag: the file named
  `todorbit-today.png` showed old TodoPilot branding and an empty Today page.
  Restored the original 1.0.3 Todorbit sample screenshot on the development
  branch. The existing tag still points at the bad screenshot and was not moved.
  The prerelease body also contains malformed Portfolio and LinkedIn links;
  corrections are described in `docs/RELEASE_AUDIT.md`.
- A scoped scan of 51 Git revisions found no private data paths or common token
  signatures. Formal name clearance, disposable-user installer acceptance,
  native widget GUI checks, broader app flows, and Windows 10 remain open.
- `main` was created as a linear descendant of the development branch at
  `25abaab`, pushed to the private repository, and selected as its default.
  Existing `master`, the development branch, tag, and prerelease were retained.
  The verified local `flutter analyze` and all 191 serial Flutter tests passed;
  the final Windows Release build and fresh GitHub runs were still in progress
  when this note was written.


## Todorbit 1.0.3 public-release preparation (2026-10-20)

- The creator selected **Todorbit** and approved the exact proposed MIT license
  text with 2026 Hussam Alkhatib copyright. Public UI, package, executable,
  shortcut, and documentation names now use Todorbit. The installer AppId,
  `%LOCALAPPDATA%\Programs\Life Manager`, `%APPDATA%\TodoPilot`, legacy
  `%APPDATA%\Life Manager`, upgrade marker, and native IPC identifiers remain
  stable. Formal trademark clearance remains open. The GitHub destination is
  confirmed in the final private review above.
- Fixed two rename regressions before packaging: the native widget privacy
  session's expected main-process name and its Exit Completely process lookup
  now use Todorbit. CMake recognizes the old TodoPilot install-prefix cache and
  regenerates it for the new target. The first post-rename Windows build failed
  on the stale cache; the corrected build succeeded.
- `flutter analyze` passed. All 191 serial Flutter tests passed; two focused
  native-widget-service/notification fixture tests passed after executable-name
  updates. The native .NET Release build succeeded with zero warnings/errors.
  `flutter build windows --release` succeeded. The packaged widget and an
  extracted portable widget both passed `--self-test`. Main executable version
  is 1.0.3+4, widget file version 1.0.3.0.
- The extracted 1.0.3 portable GUI launched from a path with spaces in a
  disposable APPDATA/LOCALAPPDATA root. It opened empty, showed the Todorbit
  mark and title, created a task planned for today, and displayed that task
  after restart. A second extraction opened empty in a separate profile.
  `docs/screenshots/todorbit-today.png` is captured from this sample profile.
  The normal installed app and personal data were not used.
- The 29-file portable ZIP includes the approved MIT LICENSE, Flutter
  `NOTICES.Z`, Lucide attribution, .NET and SQLitePCLRaw licenses/notices, both
  executables, and the Todorbit mark. Its entry scan found no database,
  backup, log, key, old executable, or old mark. Inno Setup 7.1.0 compiled the
  installer with matching version; no installation was performed. Both
  artifacts are unsigned. The package scripts now reject version mismatch,
  obsolete executables, and private data.
- `release/Todorbit-1.0.3-win-x64-portable.zip`: 61,348,174 bytes, SHA-256
  `93C220087F91FCA5D34B556FCFB05526F7BB2B1DAA72A3E8ADF9BCB5C77ECB34`.
  `release/Todorbit-1.0.3-win-x64-setup.exe`: 46,461,244 bytes, SHA-256
  `D6D5419C5427819CDB8BFCDA130DD7A8FDADD22FAE221C2ED387599361452A04`.
  `release/` contains only these packages, LICENSE, notices, notes, and checksums.
- A targeted tracked-path and 48-revision Git-history scan found no obvious
  committed database, backup, key, or credential signatures. The .NET package
  vulnerability query found no vulnerable packages from configured sources.
  These are scoped checks. A Windows 2022 CI workflow is prepared but has not
  run on GitHub.
- **NOT READY:** actual disposable-user/VM installation, registered upgrade,
  uninstall/reinstall, native widget shell/opacity/Win+D/DPI/menu checks,
  broader 1.0.3 GUI flows, Windows 10, and formal name clearance remain open.
  The GitHub account/repository and publication approval are also pending.
  See `RELEASE_AUDIT.md` and `ACCEPTANCE.md`.

## TodoPilot 1.0.2 release-readiness checkpoint (2026-10-19)

- Baseline `b9a75ce` on `feature/windows-v1-completion` had a clean working
  tree. The sidebar's sole Flutter logo reference used the black-tile app PNG.
  It now uses a shared `BrandMark` widget and a transparent, black-outlined
  128 px orbit PNG generated from the existing window-icon geometry. The
  executable/installer black-tile ICO stayed byte-identical. There are no
  separate About, splash, or onboarding logo surfaces in the Flutter UI.
- `flutter analyze` found no issues and all 191 serial Flutter tests passed.
  The Windows Release build succeeded. The packaged widget self-test passed.
  The extracted portable widget self-test first found a test-only assumption
  that expected an installed profile even with `PORTABLE-MODE`; after correcting
  the assertion and rebuilding, packaged and extracted self-tests passed.
- Final ZIP has 27 entries, including `TodoPilot.exe`, `TodoPilotWidget.exe`,
  the new Flutter mark, notices, and attribution. No legacy executable,
  database, backup, log, key, or settings entry was found. Inno Setup 7.1.0
  compiled the version-1.0.2 installer. Both packages are unsigned. The .NET
  package vulnerability audit found no vulnerable packages from the configured
  NuGet and local SDK sources.
- Removed two stale generated `life_manager` executables from the Release
  bundle; removed old 1.0.0/1.0.1 installers and ZIPs, 10 previous-checkpoint
  binaries, and two test logs from `release/`. Only the current ZIP, installer,
  release notes, checksums, and third-party notice remain. Packaging rejects
  legacy executables and reads installer version from `pubspec.yaml`.
- Final `release/TodoPilot-1.0.2-win-x64-portable.zip`: 61,326,680 bytes,
  SHA-256 `7DEF1199062A8C76CF9A7B58B132DB413FAB0259D47A2204E65ACDBAFF450C46`.
  Final `release/TodoPilot-1.0.2-win-x64-setup.exe`: 46,449,025 bytes,
  SHA-256 `09A6B0462EAC2C8BF00C2CC401511AB1454F939BA538E9B3C84400673BA463DF`.
- The isolated 1.0.2 Release GUI process started but the Windows inspection
  tool did not enumerate its window. Direct visual confirmation of the new
  sidebar mark in dark/light themes remains open. Installed upgrade/uninstall,
  full native widget UI, Windows 10, and other manual GUI flows remain open.
  Production data and the installed TodoPilot were not touched. Public name
  clearance found other TodoPilot/ToDoPilot task products; MIT is still only
  `LICENSE.proposed`. Verdict: **NOT READY**. See `RELEASE_AUDIT.md`.

## Feedback Round 3 implementation checkpoint (2026-10-19)

- Implemented the icon registry and Release font verification, explicit Saved
  View creation/editing with sorting and zero-result saves, anchored named
  event colors, calendar right-click creation and day preview, tinted event
  blocks, cancelled title strikethrough, adaptive Month entry counts, Anytime,
  in-editor category/project creation, task-panel hierarchy and scrolling, and
  parent/subtask calendar presentation. No schema migration or native-widget
  source change was needed; schema remains v20.
- The supplied `docs/feedback/round-3/` markdown and eight named screenshots
  were absent, so the written requirements and isolated Release UI provided
  the visual reference. The prior packaged Material font lacked 25 of 30
  picker glyphs. The rebuilt Release font contains all 30. The Saved Views `+`
  previously opened generic Advanced Search and required a second hidden
  naming dialog, which made the creation path unclear. It now opens a labeled
  form with its name and Create action visible.
- `flutter analyze` found no issues; all 184 Flutter tests pass. The Windows
  Release build, packaged widget persistence self-test, and Release icon-font
  coverage check pass. Inno Setup 7.1.0 compiled
  `release/LifeManager-1.0.0-win-x64-setup.exe`, SHA-256
  `B14D64048D83C0070C1468DDDB9FF414AB2B63E7B4B2F1DA382415B7E4AB9976`.
- Disposable-profile Release UI inspection at 1266x713 covered dark and light
  themes, icon choices, task title placement and persistence, Saved View
  creation with zero matches, Month/Week calendar blocks and right-click menu,
  event color menu, and the final compact Month day preview. Narrow restored
  window, DPI scaling, populated busy-day overflow, and installed upgrade and
  native widget behavior still require manual acceptance. No installation or
  production database access occurred.

## Feedback Round 2 installer checkpoint (2026-10-19)

- The verified Windows Release bundle for commit `8fd380f` was packaged with
  `D:\vs code\Inno Setup 7\ISCC.exe` (Inno Setup 7.1.0). The compiled Dart
  payload contains the Feedback Round 2 task-editor, Today, focus, and work-log
  text, tying the Release bundle to the current UI checkpoint.
- Inno Setup compressed all 15 files in the Release bundle, including
  `life_manager.exe`, `life_manager_widget.exe`, `flutter_windows.dll`,
  `sqlite3.dll`, `data/app.so`, ICU data, Flutter assets, fonts, manifests,
  notices, and shaders. The packaged widget persistence self-test and targeted
  profile-isolation, native-widget-service, and Windows-theme tests pass.
- The source bundle contains no SQLite database, WAL/SHM file, personal
  settings file, log, or backup. The installer source also excludes those
  file types and packages only the Release directory; no personal profile was
  opened or modified during this checkpoint.
- The rebuilt artifact is
  `release/LifeManager-1.0.0-win-x64-setup.exe` (45,845,619 bytes), SHA-256
  `7DBB6DD5EF1A2E09F59C45381401D7BA6131DA82F67CE9ABC8737CE5AB0C7195`.
  Its file and product versions are 1.0.0. Installation, upgrade, and uninstall
  were not run and remain final manual acceptance work.

## Feedback Round 2 UI refinement checkpoint (2026-10-19)

- A Windows Release baseline was inspected at 1266×713 with a verified
  disposable APPDATA/LOCALAPPDATA profile. The personal database was not
  opened. The dark-theme Today, new-task, Calendar, task-row, running focus,
  stopped focus, live mini-timer, and work-log states were inspected in the
  rebuilt app. Light-theme Today and its task row were also inspected with
  readable contrast and synchronized native caption colors. Populated secondary
  screens, DPI scaling, and the native desktop widget remain manual visual
  acceptance work.
- Shared Material styling now defines restrained typography, 40 px button
  targets, consistent 10 px field/button corners, semantic field outlines and
  focus treatment, quiet dialog surfaces, and common divider/card treatment.
  Page headings use weight 600. The existing indigo/lavender accent, Windows
  frame, dark/light color schemes, and native caption synchronization remain.
- The task editor now keeps title, notes, scheduled day, deadline, category,
  and project in the primary path. Status/priority and estimates/schedule
  protection are labeled expandable groups which open when editing nondefault
  values. New-task resource guidance was removed, notes are more compact, and
  lower controls can scroll clear of the fixed Create/Save action. Task,
  subtask, and planned-session dialogs clamp to the available viewport.
- Today shows persisted counts for planned tasks, fixed events, and work
  sessions with direct Calendar actions and a more specific empty state. The
  sidebar timer has a distinct compact surface with truncation protection.
  The focus dialog clamps to the viewport, makes HH:MM:SS the visual center,
  uses explicit running/paused/stopped/review states, and separates recorded
  total from readable source/timestamp log rows. A disposable Release session
  visibly advanced from `00:00:00` to `00:00:06`, then stopped at `00:00:14`;
  the mini timer updated at the same time.
- Calendar week highlights today; month distinguishes event/session/task rows
  with icons, marks the selected date, adjusts preview density at narrower
  widths, and retains full labels in tooltips. Advanced Search keeps its result
  count visible outside the scrolling filter list. Advanced Search and Smart
  Reschedule clamp their large dialogs to the viewport.
- No domain model, schema, repository, personal settings, installer rules, or
  native-widget source changed. The first full test run found three test-flow
  regressions after editor grouping and one hidden Advanced Search result
  count; those were corrected without suppressing errors. Final validation is
  clean: `flutter analyze`, all 172 Flutter tests, the Windows Release build,
  the native Release build with zero warnings/errors, and both the packaged
  and native widget persistence self-tests pass.

## Feedback Round 1 checkpoint (2026-10-19)

- Profile audit found no startup sample seeding. Runtime SQLite resolves to the
  current user's `%APPDATA%\Life Manager\life_manager.sqlite`, while the
  installer targets `%LOCALAPPDATA%\Programs\Life Manager`. The previously
  recorded personal schema-v4 database can therefore reappear after an install
  for that Windows user. No personal database was opened, reset, or migrated.
  Settings now shows the active profile location; installer rules exclude SQLite
  files and the build script refuses a bundle containing them. Disposable tests
  verify a clean root starts empty while an existing root retains its task.
- Schema v16 extends existing fixed events with location, all-day, category,
  color/icon references, reminder metadata, and date-only recurrence. A bounded
  calendar projection uses the existing recurrence arithmetic; only changed or
  cancelled dates use extra rows. Users can set selected weekdays and an end
  date, edit one date, split from this and future, edit the remaining series,
  restore a cancelled date, end a series at a selected date, duplicate, or move
  all series generations to Trash. Historical dates and manual future overrides
  survive a series split. Day/week/month share an immediate persisted Events /
  Tasks / Both filter; planned sessions remain distinct from events.
- Schema v20 enables event reminder choices in the packaged Windows app. The
  existing tray companion checks one-off and recurring events, cancellation
  exceptions, and moved occurrences, and uses an atomic per-occurrence claim
  to avoid repeat balloons. It checks a five-minute recent window to prevent
  stale backlogs; Windows notification delivery still needs manual acceptance.
  The control is disabled if the native companion is missing. Event icons and
  calendar overlap indicators are available. Whole-family Trash restoration
  and manual Windows GUI acceptance remain open.
- New event, recurrence, cancellation, split, migration, profile-isolation,
  calendar-filter, and conflict-indicator tests pass.
- Task rows now offer Start Task (status only), End Work (on hold), and Start
  Focus Session (one transactional timer plus In Progress status). Focus opens a
  live HH:MM:SS stopwatch dialog with Pause/Resume/Stop, recorded total, and
  second-level work-log timestamps. The sidebar mini timer shows the active
  task, live elapsed time, and Pause/Resume/Stop actions. Stopping a timer never
  completes its task. Focus and sub-minute repository tests and a row-action
  widget test pass; manual Windows timer UI acceptance is still needed.
- The Flutter light/dark surface and foreground colors now pass through a
  runner MethodChannel to supported DWM caption attributes. The native
  minimize/maximize/close frame and Snap behavior remain Windows-owned. A
  widget test observes both color changes, and the Windows Release build passes.
  Actual maximized/restored, DPI, and keyboard behavior still need manual
  Windows acceptance.
- Schema v17 stores built-in icon keys for tasks, recurring task series,
  categories, and projects; event icons use the v16 event field. A searchable
  compact picker supports selection and reset. Task rows, category/project
  sidebar entries, editor, and calendar events render those keys with defaults.
  SQLite backups and portable exports carry the keys; database triggers remove
  keys only when the owning record is permanently deleted. Icon persistence
  tests pass. Native task widget keeps its own established vector icons.
- Schema v18 adds independent task checklist items and one-level parent links
  for true subtasks. Checklist add/edit/remove/reorder/toggle and progress are
  in task details; child tasks keep their own schedule, status, notes, and
  priority. Parent rows expand/collapse children and show progress. Parent
  Trash/restore hides and reveals children without deleting their rows; native
  widget filters children of hidden parents. Repository persistence/restore and
  task-detail widget tests pass.
- Schema v19 adds progressive recurring task plans separate from static
  checklists. New recurring tasks can define ordered activities in the editor;
  existing scheduled series can edit a plan in task details. Assignments are
  stored per occurrence and shown in Calendar. Users can carry an unfinished
  or skipped step, choose a step manually, add/remove/reorder future steps, or
  explicitly repeat after the last step. Past, completed, and manual snapshots
  survive future plan and recurrence-rule edits. Repository tests cover skips,
  plan changes, rule splits, persistence, and v18 migration; a widget test
  covers Calendar and editor access.
- Final automated checkpoint: `flutter analyze` clean; all 172 Flutter tests
  pass, including a visible two-second stopwatch update and mini timer
  navigation/controls. The Windows Release build passes on schema v20. The
  native Release build has zero warnings/errors; its source and packaged
  persistence/reminder self-tests pass. Inno Setup 7.1.0 compiled the installer
  from that bundle, with no SQLite file included. Disposable v18→v20 and
  v19→v20 migrations preserve records and pass `PRAGMA integrity_check`.
  Manual Windows GUI and tray notification acceptance remain pending. No
  production database was opened or migrated.
- Next: use the isolated-profile manual acceptance checklist in
  `docs/ACCEPTANCE.md`. Whole-family event Trash restoration remains a
  possible follow-up; individual cancellation and restoration work now.

## Completed

- Windows-first offline Flutter foundation with Riverpod, Drift/SQLite,
  per-user storage, schema migrations, UUID identifiers, UTC modification
  timestamps, categories, projects, and task CRUD.
- Today, Inbox, All, Upcoming, Overdue, Waiting, Completed, category, and
  project task views with sorting, details editing, completion, and confirmed
  permanent deletion.
- Calendar day/week/month views backed by real tasks, deadlines, and fixed
  events. Schema v2 migration preserves v1 tasks.
- Planned work sessions with independent outcomes and actual-start tracking.
  Schema v3 supports upgrades from v1 and v2 without resetting user data.
- Deterministic, non-mutating scheduling preview logic with availability
  windows, exceptions, fixed-event/session blocking, buffers, no-slot reasons,
  and deadline warnings.
- Smart Reschedule integrated into task lists, task actions, project/category
  scopes, and Calendar sessions. Move, Shift, Push, Pull, Swap, Reorder, Repack,
  and Split generate reviewable proposals and persist only after explicit Apply.
- The All Tasks Schedule History toolbar action uses a reliable clock-arrow icon
  with explicit light/dark, hover, focus, and disabled-state colors.
- Schema v4 persists editable availability, task schedule protection, focused
  manual/Smart scheduling history, safe undo, and previous/original restoration.
  Stale previews are rejected and later manual schedules are protected.
- Schema v5 adds persistent named task sequences and cross-project prerequisite
  links. Sequence order can be edited with accessible move controls, and the
  sequence can be sent to Smart Reschedule in its stored order. Prerequisites
  are edited from task details, cycles are rejected transactionally, and
  incomplete prerequisites appear as blocked indicators. Smart Reschedule
  warns about proposals before unfinished prerequisites and rejects applies
  that gained an unreviewed conflict after preview.
- Recurrence foundation (schema v6): date-only rules support daily, weekly,
  selected weekdays, monthly, yearly, and interval-based schedules with end
  dates/counts. The task editor creates a series; fixed occurrences are created
  only for bounded task-list/calendar windows with stable UUIDs. Each is an
  independent task. Completion-based rules create the next pending occurrence
  from the actual local completion day in the same transaction; both Flutter
  and the native widget perform this write. Occurrence edits and reschedules
  are tracked separately from the series, and a selected occurrence can be
  explicitly skipped. Schema v7 extends this foundation with linked series
  versions and reviewed edits.
- Recurrence series editing (schema v7) previews This and Future or Entire
  Series changes from an explicit boundary. It preserves completed and
  individually changed occurrences and their links, reuses compatible task
  IDs, excludes only untouched generated occurrences, and requires a choice
  for each same-day collision. Apply rejects changed tasks, links, occurrences,
  or series revisions and writes the new version and audit record in one
  transaction. Smart Reschedule asks before moving an occurrence onto another
  date in its family; Keep Both and Skip Moved are supported, while Combine is
  unavailable for distinct scheduled tasks. The native widget accepts schema
  v7 and respects completion-series version boundaries.
- Habits (schema v8) are separate from recurring tasks. The Habits screen
  creates Yes/No, minimum-target, and maximum-limit habits with fixed custom
  schedules. Users can log or correct historical days, clear audited logs,
  mark and remove rest days, and archive or restore habits. Week/month/year
  rates and scheduled-day streaks derive from persisted values; missing days
  create no task backlog. Future outcomes are rejected. Habit reminders and
  native widget habit actions remain future integration work.
- Goals (schema v9) have targets, start days, deadlines, milestone checkpoints,
  manual adjustment history, linked task/project/binary-habit progress,
  explicit completion, and reversible archive. Direct and project links count
  each completed task once. The Goals screen exposes progress, links,
  milestones, history, and correction controls. Today links to unfinished goals
  due within seven days.
- Actual work (schema v10) stores timer runs and UTC work intervals separately
  from planned sessions. Task details offer start, pause, resume, stop, and
  historical manual logs with audited corrections. A running timer has a
  sidebar control and minute checkpoints. After a gap of over two minutes,
  users explicitly keep elapsed time or stop at the last checkpoint;
  unreviewed time is not added to the displayed total. Overlapping intervals
  count once in the displayed total. The native widget accepts schema v10
  without editing time records.
- Templates (schema v11) save standalone tasks, current recurring rule
  definitions, and project task collections as reusable snapshots. Applying
  one creates new task, project, and recurrence IDs and does not copy
  completion or work history. Project templates copy internal prerequisite
  edges with new task IDs; external links and planned sessions are disclosed
  as omitted. Relative planned/deadline dates shift from a chosen anchor day,
  while undated tasks stay undated. Project creation rolls back fully on a
  conflict; stale/deleted template revisions are rejected. The Templates
  manager previews the destination and generated task dates before Apply.
- Advanced task search and saved views (schema v12) filter persisted tasks by
  text, status, category, project, priority, relative planned/deadline dates,
  recurrence, and unfinished prerequisites. Matching tasks preview before a
  view is saved. Named views have no count limit, appear in the sidebar,
  recalculate from current records, and support editing and deletion with
  stale-revision rejection. Quick Search still locates categories and
  projects. Saved views below Categories retain the category creation
  control's reachability in compact windows; closed-only selections cannot
  launch Smart Reschedule.
- Automatic backups create standalone SQLite snapshots from the live WAL
  database with `VACUUM INTO`, then verify SQLite integrity before publication.
  Startup takes a backup before any schema upgrade and refuses to open or
  migrate the database if that safety step fails. While running, the app
  checks daily backup eligibility every six hours and on resume. The latest
  14 automatic snapshots are retained; manual and pre-upgrade copies are
  preserved. A Backups dialog lists verification state and allows a manual
  snapshot. Restore is reviewed and scheduled for the next launch. The
  selected file is integrity checked and hashed; startup closes the native
  companion, saves a Before restore rollback snapshot, replaces SQLite data
  through its backup API, verifies the result, and migrates an older snapshot
  forward. A changed snapshot or busy database leaves the restore pending;
  the startup error screen can cancel that request and retry the current
  database.
  Recoverable Trash is implemented in schema v13.
- Schema v13 adds recoverable task archiving and Trash for tasks, projects,
  categories, fixed events, planned sessions, individual recurring occurrences,
  and whole recurring families. Parent deletion hides descendants without
  changing their own state. Archive and Trash can restore records, including
  completed work and linked history, in transactions. Future recurring
  occurrences stop materializing while their family or parent is hidden. The
  native widget excludes archived and trashed records on v13. Explicit
  permanent deletion checks relationships first and records tombstones; it
  never purges automatically at startup. Unlinked occurrence tasks can be
  purged while retaining their series slots. A series can be purged only after
  its occurrence tasks and edit history are resolved.
- Statistics and reports calculate actual task completions, creations, planned
  dates, recorded work, habit outcomes, and project completion counts over
  last-7, last-30, last-90, or custom local-day ranges. Work is clipped to
  days and overlaps count once; unreviewed timer time ends at the last
  checkpoint. Archived task history is included, Trash is excluded. Goal
  counts are explicitly labeled as current rather than historical. The
  Reports view reads current persisted snapshots and never fabricates data.
- Schema v14 adds opt-in Windows tray notifications for open due/overdue tasks
  and a daily planned/due summary at a chosen local time. Both are off by
  default. The native companion can start in a background tray mode without
  showing the desktop widget, continues after the main window closes, and
  checks every 30 seconds. A unique per-type/local-day delivery record avoids
  duplicates after restart. Delivery occurs only in the first hour after the
  selected time while the companion is running; no missed-day backlog is sent.
  Archived, trashed, completed, and cancelled tasks are excluded. The dialog
  exposes the opt-in and time controls; the app starts the companion at launch
  when notifications are enabled. Windows notification visibility still needs
  manual acceptance on an isolated profile.
- Import/export publishes a standalone SQLite snapshot at a chosen `.sqlite`
  path and stages an external Life Manager database in managed backups. Import
  checks integrity, supported schema, required tables, and foreign keys.
  Export also checks required tables and foreign keys before publication.
  The restore preview shows source, schema, and size; replacement requires an
  explicit choice and occurs only on the next launch through the existing
  Before restore rollback flow. Cancelling either picker or the preview leaves
  the active database unchanged.
- Schema v15 adds task resources: managed attachments, external file and folder
  references, and website/application URLs. Managed attachment bytes live in
  SQLite with stable UUIDs, original filenames, size, and SHA-256 digest. The
  attachment limit is 16 MB per file. This makes automatic backups, manual
  snapshots, Before restore backups, and portable SQLite exports complete for
  managed attachments without a second archive or arbitrary extraction path.
  External file and folder contents are never copied into backups. The task
  editor supports adding, opening, renaming, editing URLs, availability display,
  and confirmed removal. Files opened from managed storage are verified and
  placed in an app-owned cache; executable/shortcut extensions are blocked.
  Task archive and Trash retain resource rows; permanent task purge cascades
  them. Resource changes are not copied by task templates or recurrence rules:
  each task or occurrence owns only its explicitly added resources.
- Stale completion now rejects a newer task edit, and task duration input
  rejects invalid text instead of silently clearing the estimate. Prerequisite
  edits compare task revisions, and the narrow task editor keeps unsaved fields
  after saving prerequisites.
- Quick Search opens from the sidebar or Ctrl+K and searches persisted task
  titles/notes plus category and project names. Results navigate to the real
  task, category, or project. This is an in-memory search over the loaded
  workspace; advanced filters, tags, and saved views remain unfinished.
- Category-dialog lifetime and task-row hover regressions covered by widget
  tests. The previously reported Windows-only checkbox duplication has not been
  reproduced in automated tests.
- Native widget architecture investigation documented the failed Flutter
  desktop-child activation path, Explorer hierarchy behavior, WinForms black
  composition failure, and the successful direct owner-drawn HWND approach.
  Opt-in diagnostics and guarded shell probes remain available for regression
  investigation.
- Integrated native Windows widget packaged as the self-contained
  `life_manager_widget.exe` beside `life_manager.exe`. It owns its independent
  process/tray lifecycle, uses a named mutex and named pipe, watches SQLite/WAL
  changes without polling, and performs bounded recovery of only its own HWND
  after Explorer changes.
- Widget UX includes inline-positioned activatable Quick Add, transactional
  view-aware task creation, compact optimistic-concurrency task editing,
  task-specific Flutter handoff, vector header controls, separate checkbox/row
  targets, Today/Inbox/All Tasks/Upcoming selection, empty states, scrolling,
  header dragging, all-edge/corner resizing, persisted monitor-aware geometry,
  and per-monitor DPI scaling.
- System/Light/Dark appearance is authoritative in
  `%APPDATA%\Life Manager\appearance-settings.json`, migrates the former widget
  setting, persists across restarts, and synchronizes between Flutter and the
  native companion through debounced file notifications.
- Manual acceptance passed for continuous visibility, `Win+D`, Quick Add,
  task editing, resizing, header icons, view switching, theme synchronization,
  and independent main-application lifecycle.
- Promotion finalized: normal app controls and optional sign-in registration
  launch the native companion. `life_manager.exe --widget` delegates to the
  packaged companion before Flutter starts. The failed Flutter widget is
  retained only behind the explicit `--legacy-flutter-widget` diagnostic flag.

## Current validation

- Flutter 3.47.7 / Dart 3.13.5; Windows toolchain healthy.
- `flutter analyze`: clean.
- `flutter test`: 138 passing tests, including engine, database, migration,
  stale-apply, undo/restoration, split, persistence, and preview/Apply coverage.
- Native Release build and disposable database/settings self-test: passing.
- Native dependency audit: no vulnerable packages reported.
- `flutter build windows` Release and Debug packages succeed and contain both
  `life_manager.exe` and `life_manager_widget.exe`.
- Packaged `life_manager_widget.exe --self-test`: passing.
- `flutter build windows --release`: passing at the previous checkpoint; package
  contains the main app and native companion.
- Manual visual check: the Release task-list entry point opened the themed Smart
  Reschedule workspace with the real current scope, selected tasks,
  Availability, Generate preview, Cancel, and disabled-until-preview Apply. It
  was closed without applying changes. Automated widget coverage verifies the
  preview and persisted Apply path.
- The native companion never creates or migrates the production database; it
  accepts schema v4-v9, enables foreign keys and a busy timeout, and uses
  parameterized transactional writes. Automated tests use an isolated database.
- Milestone B validation: focused v4→v5 migration, dependency-cycle/rollback,
  stale-editor, sequence persistence, and joint schedule-conflict tests pass.
  Native Release build and self-test pass for both accepted schema versions.
  `flutter analyze` is clean, `flutter test` passed 45 tests, and the Windows
  Release rebuild passed with the schema-v5-compatible widget companion.
  Quick Search and prerequisite editing have widget-level interaction tests.
  New GUI flows still need manual Windows acceptance testing.

- Recurrence foundation validation: v5-to-v6 and v4-to-v6 disposable
  migration tests pass; recurrence rules, repository behavior, native v6
  self-test, and task-editor creation have focused regression coverage.
  `flutter analyze`, all 54 Flutter tests at the first v6 checkpoint, the native Release build, the
  Windows Release build, and the packaged companion self-test pass. Manual
  recurrence UI acceptance has not been performed.
- Recurrence follow-up: the widget editor now preserves a completed task's
  original completion timestamp. Native self-test covers completion through
  both checkbox and editor. The recurrence rule snapshots selected weekdays
  and requires the first planned day to be one of them. Smart Reschedule has a
  regression test proving it moves one occurrence while leaving nominal dates
  and the rule intact. `flutter analyze`, all 56 Flutter tests, native Release
  build/self-test, Windows Release build, and packaged companion self-test pass.
- Completion-based skip recovery: a skipped occurrence remains in history and
  does not invent a completion time. Task details now offer an explicit resume
  day for that series, with a transactional successor and duplicate guard.
  Disposable restart and resume tests pass. `flutter analyze`, all 58 Flutter
  tests, Windows Release build, and packaged widget self-test pass. This
  control still needs manual Windows UI acceptance.
- Schema v7 validation: disposable v6-to-v7, v5-to-v7, and v4-to-v7 migrations,
  series splits, completed and linked history, collision choices, stale
  previews, and editor interactions pass. `flutter analyze` is clean; all 70
  Flutter tests pass. Native Release build and self-test, Windows Release
  build, and packaged companion self-test pass. The new GUI flows still need
  manual Windows acceptance.
- Schema v8 validation: disposable v7-to-v8 migration and restart persistence,
  historical correction, rest-day and streak calculations, archive safety, and
  a narrow-screen Habits widget flow pass. `flutter analyze`, all 77 Flutter
  tests, native Release build/self-test, Windows Release build, and packaged
  companion self-test pass. Manual Windows UI acceptance remains pending.
- Schema v9 validation: disposable v8-to-v9 migration, direct/project
  double-count prevention, binary-habit links, manual corrections, milestone
  editing, archive/completion, and Goals UI interactions pass. `flutter
  analyze` is clean; all 82 Flutter tests pass. Native Release build and
  self-test, Windows Release packaging, and packaged companion self-test pass.
  Manual Goals UI acceptance remains pending.
- Schema v10 validation: disposable v9-to-v10 migration and restart,
  timer state transitions, recovered-timer decision, manual log correction,
  overlap accounting, and dialog interactions pass. `flutter analyze` is clean;
  all 88 Flutter tests, native Release build/self-test, Windows Release build,
  and packaged companion self-test pass. Manual Windows UI acceptance remains
  pending.
- Schema v11 validation: disposable v10-to-v11 migration and restart,
  standalone and recurring template creation, project dependency remapping,
  date shifts, atomic rollback on project-name conflict, and manager UI flows
  pass. `flutter analyze` is clean; all 94 Flutter tests and native Release
  build/self-test, Windows Release build, and packaged companion self-test
  pass. Manual Windows UI acceptance remains pending.
- Schema v12 validation: disposable v11-to-v12 migration and restart,
  combined relative-date/project/blocker filtering, unlimited persisted views,
  stale edits, and search/save UI pass. `flutter analyze` is clean and all 98
  Flutter tests, native Release build/self-test, Windows Release build, and
  packaged companion self-test pass. Manual Windows UI acceptance remains
  pending.
- Backup validation: live WAL snapshot isolation, independent later writes,
  pre-upgrade schema preservation, automatic retention, and manual creation
  pass on disposable databases. `flutter analyze` is clean; all 101 Flutter
  tests, the Windows Release build, and packaged companion self-test pass.
  The Backups dialog still needs manual Windows UI acceptance.
- Restore validation: disposable round trips preserve a rollback snapshot,
  reject changed size or content digest, wait for an active reader, and
  upgrade an older restored schema. `flutter analyze` is clean; all 106
  Flutter tests, Windows Release build, and packaged companion self-test
  pass. The restore dialog and next-launch flow still need manual Windows
  UI acceptance on an isolated profile.
- Trash validation: disposable v12-to-v13 and realistic v4-to-v13 migrations,
  parent restoration order, linked-record purge rejection, occurrence identity,
  family archive/Trash, 30 day retention without automatic purge, event/session
  restore, foreign key checks, and Archive/Trash widget restore flow pass.
  `flutter analyze` is clean; all 122 Flutter tests, native Release self-test,
  and Windows Release build pass. Manual UI acceptance is pending.
- Report validation: range bounds, midnight clipping, overlapping intervals,
  unreviewed timer checkpoint, archived versus trashed task inclusion, and
  date-span UI interaction pass. `flutter analyze` and all 122 Flutter tests
  pass. Windows Release build and packaged widget self-test pass. Manual UI
  acceptance is pending.
- Notification validation: disposable v13-to-v14 migration, default-off
  settings, invalid-time rejection, dialog opt-in and companion launch,
  native due/summary claim timing, duplicate suppression, disabled settings,
  and trashed-task exclusion pass. `flutter analyze` is clean and all 125
  Flutter tests pass. Native Release self-test, Windows Release build, and
  packaged companion self-test pass. On an isolated
  Windows profile, the Notifications dialog showed both toggles off, Archive
  and Trash tabs rendered, a task archived and restored through the UI, and
  Reports rendered persisted empty counts. Actual tray balloon visibility,
  notification opt-in via Windows UI, Trash restoration, and populated Reports
  remain manual acceptance work.
- Import/export validation: on disposable databases, a live WAL export is
  consistent and independent of later writes; import and reviewed restore
  preserve task IDs, categories, projects, and relationships; Before restore
  contains the replaced database. Invalid SQLite, truncated data, newer
  schema, missing tables, and broken foreign keys are rejected without
  changing the active database or publishing a managed backup. Existing export
  files are retained; exports with broken relationships publish no file;
  cancelled pickers and cancelled restore review perform
  no replacement. Dialog tests verify preview details and disabled controls
  while a picker is pending. `flutter analyze` is clean; all 131 Flutter tests,
  Windows Release build, and packaged widget self-test pass. Native Windows
  file picker interaction and next-launch restore remain manual acceptance.
- Task resources validation: disposable v14-to-v15 migration preserves tasks;
  managed bytes survive source-file removal, archive, Trash, and restoration,
  while permanent task deletion removes the association. Duplicate filenames
  get distinct UUIDs; invalid URLs, missing paths, oversized files, and a
  source changed during copying leave no resource row. Portable export/import
  restores managed bytes and rejects corrupted content or unsafe original
  filenames. A blocked restore retains the live attachment and pending request
  until the lock clears. Widget tests cover attach, rename, confirmed removal,
  and a missing external file remaining visible. `flutter analyze` is clean;
  all 138 Flutter tests, Windows Release build,
  and packaged widget self-test pass. The native widget self-test checks v15
  compatibility. Native Windows picker/opening flows still need manual
  acceptance on an isolated profile.

## In progress

- Milestone 3 follow-up: manual recurrence UI acceptance, richer
  multi-window availability editing,
  and drag-to-reorder sequence UX. Sequences currently use accessible up/down
  controls. A sequence owns at most one position per task, and a task can belong
  to one sequence.
- Reproduce the reported Windows task-row checkbox duplication and capture its
  first exception if it occurs again; widget tests remain stable.

## Not yet implemented

- Windows Hello and complete settings/preferences coverage. Habit and
  session-specific reminders remain future work.

## Environment and data notes

- Android SDK command-line tools and licenses remain incomplete; Android is
  outside the current milestone.
- Existing task/category/project/event/session data is migrated forward in place;
  Smart Reschedule does not reset the production database.
- The existing production database is schema v4. A consistent SQLite online
  backup with integrity check `ok` was written to
  `%APPDATA%\Life Manager\backups\pre-schema-v7-20261018T052232Z.sqlite`.
  The production database was not migrated or modified during this checkpoint.
- Launch-at-sign-in remains disabled by default and changes only through the
  explicit tray action.
- The production schema-v4 database has not been opened or migrated during the
  v13 implementation. Only disposable databases were upgraded in automated
  tests. Before eventual production upgrade, the startup backup must verify a
  consistent snapshot.
- V14 automated tests and the successful manual UI launch used disposable
  databases. An initial manual launcher did not inherit the intended APPDATA
  override and was stopped before UI interaction. The production SQLite main
  file and WAL modification times were unchanged when checked afterward; no
  production migration was observed. A later launcher set APPDATA explicitly
  in the child process and its isolated SQLite file was verified before UI
  interaction.
- The manual UI acceptance profile is left at
  `%LOCALAPPDATA%\Temp\life-manager-v14-manual-20261018` after its window was
  closed; automated cleanup was rejected by command review. It contains only
  disposable test data and can be removed later.
- PID 19828 was absent on inspection; its executable path and command line
  therefore could not be verified. The isolated profile above was left in
  place. No production database or settings were used for import/export tests.
- Trash retains records indefinitely unless the user explicitly confirms
  permanent deletion. The displayed 30 day date is a retention guide, not an
  automatic purge date. Records with linked history can remain nonpurgeable
  until those links are safely resolved. Deleted category/project names remain
  reserved while in Trash.

## Windows v1.0 finalization checklist (2026-10-18)

- [x] Shared Flutter/native app-lock implementation, PIN lifecycle, locked
  notification policy, and process-bound widget session. Automated checks pass;
  real two-process Windows acceptance remains pending.
- [ ] Persisted Windows settings audit and completion.
- [x] Per-user installer compiled with Inno Setup 7.1.0. Installed
  upgrade/uninstall checks remain in the acceptance matrix.
- [ ] Disposable migration audit: v4-to-v15 fixture preserves task, project,
  category, event, session, scheduling history, IDs, foreign keys, and resource
  index. Broader historical data fixtures and corruption cases remain.
- [ ] Backup, restore, import/export, and attachment portability regression coverage.
- [ ] Integrated UI, native companion, accessibility, and performance review.
- [x] Full Flutter analysis/tests and Windows Release/native self-tests at this
  checkpoint, plus the native package vulnerability audit. Repeat after
  subsequent source edits.
- [ ] Isolated Windows manual acceptance. Status matrix in `ACCEPTANCE.md`.
- [x] Draft release instructions, notes, limitations, and acceptance record in
  `RELEASE.md` and `ACCEPTANCE.md`; finalize after installer and acceptance.

## Finalization checkpoint

An explicit read-only schema gate now stops automatic v4-to-v15 migration until
the user approves a verified Before upgrade backup and migration in the app.
Automated checks did not open the personal schema-v4 database. The rebuilt
Release app was launched twice with verified isolated APPDATA and LOCALAPPDATA
directories; the default-disabled Privacy dialog rendered at 1266×713 and
was closed without changing settings. The latest full suite before the final
migration/icon edits passed 142 tests; the targeted migration-gate and v4-to-v15
tests passed separately. Final `flutter analyze` is clean, all 146 Flutter
tests pass, the Windows Release build and packaged widget self-test pass,
and the native dependency audit reports no vulnerable packages from the
configured sources. The final Release app opened on an isolated profile;
a disposable task was created and shown after a full restart. The native
companion now honors the explicit APPDATA override (the .NET special folder
had resolved the real profile), with a self-test guarding this isolation.
Inno Setup 7.1.0 compiled the existing project successfully. The final
installer is `release/LifeManager-1.0.0-win-x64-setup.exe` (45,791,473 bytes;
SHA-256 `51672ABA224E95762C9FBD82C7ED1671E0DE2C195F421348FF55961CF13C5FBC`).
Both setup version fields report 1.0.0. The 15-file Release bundle contains
both executables and no database or log file. The installer is unsigned.
The installer configuration audit found a stable AppId, per-user privileges,
an installation path outside `%APPDATA%`, no install/uninstall deletion section,
and no widget auto-start registration. These static checks do not replace an
installed upgrade/uninstall test.
After compilation, all 146 Flutter tests passed, `flutter analyze` was clean,
the packaged widget self-test passed with an isolated profile, and the native
dependency audit found no vulnerable packages in the configured sources.
An initial parallel `flutter analyze` attempt hit a Flutter SDK cache race;
its sequential retry passed. No installer installation was attempted on the
normal Windows profile, so installed upgrade/uninstall behavior remains
unverified. No production database was opened or migrated.

Next: verify the installer in a disposable Windows installation or with user
approval for an installed acceptance test, then manually verify
task resource selection/opening through native Windows dialogs on an isolated
profile. Manually verify
import/export through the native Windows file picker and the reviewed
next-launch restore using the isolated profile. Manually verify a due reminder and daily summary
through the Windows tray on an isolated profile, including after closing the
main window. Manually
exercise Archive, Trash, and Reports on an isolated profile. Manually
exercise the recurrence editor, Smart Reschedule collision choices, and Habits
screen on an isolated Windows profile before opening the production schema-v4
database. Time-of-day recurrence is outside the current date-only task model;
planned work sessions retain their own UTC times. Re-run the native widget
regression checklist in
`docs/windows-widget.md` whenever shell attachment, native input, rendering,
DPI behavior, process lifecycle, or packaging changes.

## TodoPilot continuation checkpoint (2026-10-19)

Branch: `feature/windows-v1-completion`; latest committed baseline was
`d7fd802` before this work. The public rename, theme architecture, widget
redesign, Contributors, open-source files, and packaging are implemented in
the working tree. Preserve these changes rather than restarting the mission.

- The preferred orbit screenshot was identified as Lucide's `orbit` glyph.
  `assets/todopilot_icon.svg` is the editable source, and
  `tools/generate-icon.ps1` generated a black/white 16, 24, 32, 48, 64, 128,
  and 256 px ICO plus 256 px README/app asset. The main and widget executable
  resources both extracted as black/white icons with zero purple pixels at
  32 px in the first Release build. The widget tray loads its executable icon.
  Lucide ISC attribution is in `THIRD_PARTY_NOTICES.md` and packaging config.
- Settings → Appearance → Customize Theme has independent light/dark palettes,
  presets, validated JSON import/export, contrast warning, layout controls,
  and an interactive hue wheel with saturation/value square and synchronized
  HEX input. Calendar default view and reduced-motion preference were added.
  The shared settings store persists across restarts and native widget watches
  it for palette/opacity updates.
- Native widget source now supports background opacity, flexible resize,
  context menu, and layout lock. Its Release build and packaged self-test pass.
  A Windows-aware manifest enabled the layered Explorer child window, and
  parent-client coordinate conversion placed it correctly across two monitors.
  Read-only inspection confirmed `WS_CHILD` and `WS_EX_LAYERED` on Explorer's
  `SHELLDLL_DefView` at the intended screen position. Per-pixel alpha, Win+D,
  wallpaper contrast, multiple DPI/monitors, and task hit testing still need
  actual GUI acceptance.
- The TodoPilot README, contributor registry/page, contribution/security
  policies, MIT license proposal, developer/customization docs, portable
  builder, Inno Setup project, and release notes are prepared. There is no Git
  remote. Do not publish, merge into master, install on the normal account, or
  open the production database without user approval.
- Final `flutter analyze` is clean, all 189 Flutter tests pass, the native
  Release build has zero warnings/errors, the Windows Release build succeeds,
  native widget self-test passes, and the native package audit reports no
  vulnerable packages from configured sources.
- In an isolated Release UI at 1266×713, the revised color picker fit without
  overflow. Wheel changes synchronized the preview and HEX field. Keyboard HEX
  edits synchronized the preview and wheel. A saved light accent `#BD561A`
  survived a full app restart while the dark accent stayed `#B9A4F4`.
  The README screenshot is a real isolated-profile Today view with one generic
  sample task. The extracted portable app also opened from a directory with
  spaces, and its widget self-test passed.
- Both main/widget Release executable icons and the Inno Setup executable
  extracted as the orbit icon at 32 px (white strokes, zero purple pixels).
  The ICO includes seven sizes from 16 to 256 px. Actual taskbar, Start menu,
  File Explorer, shortcut, and installer wizard visual checks remain pending.
- `release/TodoPilot-1.0.0-win-x64-portable.zip` has 25 checked entries,
  including both executables, Flutter license notices, the icon asset, and
  Lucide attribution; no database/log/key entries were found. The extracted
  widget self-test passed, and the extracted main app opened from a path with
  spaces in a fresh isolated profile. Size: 61,308,791 bytes; SHA-256:
  `00E1F63A03169C57985B9EC21D05486FCCC909A45FA1759D102E8833DD7A9F20`.
  `release/TodoPilot-1.0.0-win-x64-setup.exe` compiled with Inno Setup 7.1.0
  after a transient resource-update failure and successful retry. Size:
  46,431,717 bytes; SHA-256:
  `4E5ED977E05418B311DAA5D61BA1116E2DDFF6CC09A50ED15F43CF006C8A2967`.
  Both are unsigned. Older candidate artifacts were moved into
  `release/previous-checkpoint/` and are excluded from the new packages.
- `git remote -v` is empty. Tracked filenames and 44 revisions of Git history
  were scanned for likely secrets, databases, logs, and signing keys; no
  matching committed file or secret signature was found. This scan does not
  guarantee that arbitrary personal content is absent. No repository was
  published, no license was activated, no normal-account installer test was
  run, and no production database was opened or migrated.

Next: perform the manual acceptance in `docs/ACCEPTANCE.md` and
`docs/windows-widget.md`, especially real widget alpha, Win+D, wallpaper/DPI,
task interactions under layout lock, installed upgrade/uninstall, and shell
icons. Review `LICENSE.proposed` and the GitHub account/repository before any
public publication. Do not merge into master without explicit approval.

## TodoPilot 1.0.1 icon and clean-install checkpoint (2026-10-19)

This checkpoint supersedes the older 1.0.0 artifact paths and legacy-profile
assumptions above. Baseline was commit `ba2da50` on
`feature/windows-v1-completion`; no production database or installed app was
opened, modified, or uninstalled.

- The original black-tile `IDI_APP_ICON` ICO is byte-identical to the baseline.
  `IDI_WINDOW_ICON` adds a transparent black-edged white orbit at 16, 20, 24,
  32, 48, and 64 px. The runner assigns both `WM_SETICON` sizes and refreshes
  them on DPI change. The final extracted ZIP visibly showed the outlined
  orbit in the title bar; the sidebar and executable still show the black-tile
  icon. Windows taskbar and pinned-shortcut selection remain visually untested.
- Fresh installer-style launches use `%APPDATA%\TodoPilot`; an unrelated
  `%APPDATA%\Life Manager` database is not opened automatically. The first-run
  UI offered a reviewed import when a disposable legacy database with one task
  was present; the new database contained zero tasks while the old one retained
  one. A valid marker in a separate disposable upgrade profile selected the
  old one-task database. The installer now requires a matching registered
  TodoPilot AppId, display name, install location, and executable before it
  writes that marker. Actual setup upgrade was not run.
- Portable ZIPs carry `PORTABLE-MODE` and use separate application-data
  folders keyed by extraction location. In an extracted package, the first
  copy started with zero tasks, fixed events, goals, habits, work sessions,
  timer runs, and time entries. One UI-created task remained after reopening
  the same copy. A second copy in the same disposable APPDATA started with
  zero tasks in a different profile. The final rebuilt ZIP again created two
  separate empty profiles. Both native widgets ran simultaneously and wrote
  appearance settings to their respective profiles; exiting the first widget
  left the second running. A marked upgrade widget wrote to the marked legacy
  profile. Widget mutexes and command pipes now use profile-specific names.
- `flutter analyze` passed; focused profile tests passed; all 191 Flutter
  tests passed with serial execution. A parallel full-suite run had one
  timing-sensitive privacy-test failure; the focused test passed on retry and
  the serial full suite passed. Native Release build had zero warnings and
  errors, widget self-test passed, and `flutter build windows --release`
  succeeded. The final 26-entry ZIP contains both Release executables,
  Flutter notices, and Lucide attribution, with no database, backup, log,
  settings file, or key. The installer compiled with Inno Setup 7.1.0 from
  the scanned Release bundle. Both packages are unsigned.
- Final portable ZIP: `release/TodoPilot-1.0.1-win-x64-portable.zip`,
  61,320,933 bytes, SHA-256
  `52BC9C32BCFE4297DDCDF15809F4F922C76614CD150B374748A488ED6F061635`.
  Final installer: `release/TodoPilot-1.0.1-win-x64-setup.exe`,
  46,448,813 bytes, SHA-256
  `91B0816DA076F0B65C4A1964F8C184BACA85EB6B5CAF780951E3DD9E6B075109`.
- No actual installer install, registered upgrade, uninstall, or reinstall was
  performed because those operations would change the normal Windows account.
  They require a disposable Windows user or VM. Visual taskbar, Explorer,
  shortcut, DPI, and installer-wizard icon checks remain manual acceptance.


Beta13 release verification continuation: see
[resumable receipt](FINAL_STABILIZATION_2026_11_07.md#beta13-release-verification-continuation-2026-11-07).
At3700185, source/packages match retained evidence. CI fixture/schema coverage
corrections pass focused checks; no app rebuild. Offline Sandbox installer/upgrade
runner prepared; actual migration consent and clean signed-APK runtime pending.
No publication, real Sync or production-profile changes.


2026-11-08: Beta13 feasible local release acceptance closed: actual Sandbox
26-to27 upgrade/uninstall/reinstall and exact worker barriers PASS; production-
signed APK core/restart/native widgets PASS on separate clean API35 x64. VM/AVD
stopped, production18 hashes/startup/protected docs unchanged. Hosted CI and
physical-platform gates remain open; no publication. Owner now requests alarm
implementation and authorizes the next experimental release subject to gates.
See FINAL_STABILIZATION_2026_11_07.md and external release-verification039/041.


2026-11-08 alarm beta14+37 WIP: portable schema28 rules, task/event editor and
scoped family controls, Android native actions/service and Windows companion
alarms implemented. Focused11/18 and new migration/codec/backup checks pass;
Kotlin11 compile and initial native selftest pass. Final source/native build/OS/CI
gates pending. Owner authorizes experimental publication only after gates.
Resume docs/ALARM_BETA_2026_11_08.md; do not repeat Standard/Private matrices.
