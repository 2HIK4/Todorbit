# Persistent test run ledger

## Urgent Calendar Event Duration Invariant Verification (2026-11-11)

Branch `fix/calendar-interaction-regressions` (Schema 28). Resolves P0 data truncation defect where Day/Week calendar move operations erroneously applied day-column visual bounds (`maxEnd = 23:59`) to domain event persistence, truncating events > 24 hours to at most 23h59m and shifting overnight events backward:
- **Root Cause & Fix**: Removed `finalEnd.isAfter(maxEnd)` clamping from `CalendarInteractionController.updatePointer` during `CalendarGestureKind.move`. Established domain invariant: `finalEnd = finalStart.add(originalDuration)`. Display clipping is handled by layout rendering (`CalendarLayoutEngine`); persisted duration is strictly invariant.
- **Auto-scroll & Cancellation Hygiene Intact**: Retained top auto-scroll tolerance (-10px) and complete gesture cancellation handlers (`onPanCancel`, `onVerticalDragCancel`).
Runs & Evidence:
- `test/calendar_interactions_regression_test.dart` (10/10 PASS):
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
