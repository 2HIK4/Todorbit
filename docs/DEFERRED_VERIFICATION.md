# Deferred Verification Backlog

## Beta 30 Remaining Physical / Multi-Client Gates (2026-11-28)

The [Beta 30 candidate receipt](TODORBIT_BETA_30_CANDIDATE.md) closes exact-source Windows (`46066659736`) and Android (`46066664484`) CI, owner visual acceptance of the isolated Windows candidate (desktop widget Light/Dark rendering, continuous pixel scrolling, embedded Settings > Hotkeys), signed Android packaging, isolated Beta 29 → Beta 30 Windows portable upgrade, official API 36 `16 KiB` in-place upgrade (`46068388702`, `52 → 53`), and live Experimental updater/asset verification (`461064408`). Physical multi-monitor DPI variations, `Win+D` across displays, Narrator/TalkBack assistive output, physical registered installer upgrade on an isolated test machine, physical Android device/OEM flows, and separately authorized two-client live Google Drive sync tests remain open manual gates (exclude personal profile and Windows Sandbox).

## Post-Beta 29 Candidate & Recovery Remaining Gates (2026-11-27)

- **Android 16 KiB Pre-Publication Draft APK Runtime (`android-16k-runtime.yml`)**: Beta 29 run [`45784257387`](https://github.com/2HIK4/Todorbit/actions/runs/45784257387) covers Beta 29 (`bd9d337`) only and does **not** certify Beta 30. Prior to publishing Beta 30, build signed APKs via `android-release.yml` on the bumped Beta 30 candidate, attach them to an unpublished **draft** GitHub release, and dispatch `android-16k-runtime.yml` with the exact Beta 30 x64 APK `asset_id` + `sha256` (and Beta 29 previous asset) to verify in-place upgrade retention cleanly. Local `.\dev runtime android` remains `BLOCKED` (`emulator-5554` offline; persisted in `.buildlog/verify/android-runtime/latest.json`).
- **Pending GitHub Actions CI Runs for Application Candidate `10588a5`**: Track completion of `windows-ci.yml` ([`46062228284`](https://github.com/2HIK4/Todorbit/actions/runs/46062228284)) and `android-ci.yml` emulator rerun ([`46062232852`](https://github.com/2HIK4/Todorbit/actions/runs/46062232852)).
- **Full Unbatched Flutter Test Sweep (`flutter test`)**: `18` targeted Flutter suites (`195` tests across Group A, PR #3 recovery, and DB/concurrency) plus native Windows release self-tests/benchmarks and `.\dev runtime windows` / `-LiveApp` passed locally before/across post-review edits; full-repo serial sweep runs inside `windows-ci.yml` (`46062228284`).
- **Physical Multi-Monitor / Multi-DPI Desktop Widget & Touch Acceptance**: Physical live Windows 11 wallpaper appearance across light/dark/mixed backgrounds, mouse-wheel/precision-trackpad smoothness, Narrator/TalkBack assistive readout, and physical Android device checks require manual owner acceptance prior to approving Beta 30 release publication (exclude personal profile and Windows Sandbox).

## Post-Beta 29 Widget Rendering, Pixel Scroll & Settings > Hotkeys Acceptance (2026-11-26)

- **Windows Desktop Widget Live Wallpaper Visual Acceptance**: Confirm Light/Dark opaque and translucent widget text, active `Today` / `selectedToday` pills, task row separation, and tray/open icons on real Windows 11 light and dark wallpapers (`--self-test` and offscreen `.buildlog/widget-fixed/` renders passed, but live Explorer-parented `UpdateLayeredWindow` compositing requires manual visual sign-off).
- **Continuous Pixel Scroll Feel & Embedded Settings > Hotkeys**: Confirm physical mouse-wheel and precision-trackpad smooth scroll easing (`16ms` timer, scrollbar drag, clipped agenda/task viewports) and live Settings > Hotkeys keyboard recording/contrast on the running desktop shell.

## Beta 29 experimental acceptance (2026-11-26)

The [Beta 29 candidate receipt](TODORBIT_BETA_29_CANDIDATE.md) closes exact-source
Windows and Android CI, local production Android signing, PE/archive/checksum
audits, isolated Beta 28 → Beta 29 portable handoff, official API 36 16 KiB
signed in-place upgrade (`build 51 → 52`), and public asset/updater discovery.
Physical Windows/Android DPI, input, TalkBack/Narrator assistive output,
registered Windows installer upgrade on an isolated test machine, Android device
install UI/OEM behavior, and separately authorized two-client Drive tests remain
manual acceptance steps. Exclude the owner's personal profile and Windows Sandbox.

## UI & TDAT Integration Review PR Gates (2026-11-26)

- **Resolved Remote CI (`fix/ui-and-tdat-refinement-2026-11-25` @ `a23c825`, merged in PR #5 @ `aa9cdf8`)**: **Lightweight CI** (`45758321789`), **Android validation** (`45758321859`, including API 35 KVM emulator), and **Windows checks** (`45758673278`, covering full Flutter analysis/tests, all TDAT safety suites, Release/portable builds, native self-test, installer, and checksums) all passed on `a23c825`, covering the full 92-suite impact scope remotely.
- **Host-Blocked Runtimes & Physical Acceptance**: Local `dev runtime windows -LiveApp` (Windows Developer Mode off), `dev runtime android` (missing local API 36 16 KiB emulator/APK), and physical Windows/Android DPI, mouse/touch, TalkBack/Narrator, registered installer, and authorized two-client Drive checks remain open until release/manual acceptance.

## TDAT Safety Gate & Host-Blocked Runtime Checks (2026-11-25)

- **Windows live application process launch/UI/restart (`dev runtime windows -LiveApp -BuildLiveApp`)**: `BLOCKED` on this local Windows 11 host because Windows Developer Mode (symlink support) is disabled (`Building with plugins requires symlink support`). Run on a Developer-Mode-enabled Windows machine or supply a prebuilt driver-enabled `Todorbit.exe`.
- **Android 16 KiB emulator runtime (`dev runtime android`)**: `BLOCKED` locally; requires an authorized API 36 16 KiB emulator (`PAGE_SIZE=16384`), `.buildlog/16k-runtime/candidate.apk`, and `APK_SHA256`.
- **Full shadow verification (`dev verify changed -Shadow`)**: Optional omitted-suite shadow execution against the full Dart test suite remains deferred from ordinary development runs.
- *(Note: GitHub Actions cloud execution for `Lightweight CI` (`45661321438`), `Android validation` (`45661321128`), and `Windows checks` (`45661320360`) completed with `success` on integration candidate `db1db0a`.)*

## Beta 28 experimental acceptance

The [Beta 28 candidate receipt](TODORBIT_BETA_28_CANDIDATE.md) closes the
automated Windows and Android packaging gates, local portable handoff and
official API 36 16 KiB signed upgrade for build 51. It lists the exact remaining
manual steps for a registered Windows upgrade, physical DPI/input and
accessibility, Android installation UI and OEM behavior, and separately
authorized two-client Drive testing. Use a separate test installation for
registered Windows acceptance. The owner's current installation is excluded.

## Beta 27 polish follow-through (2026-11-24)

The [polish receipt](BETA_27_POLISH_IMPLEMENTATION.md) shows dense-scroll
raster improvement and remaining 120 Hz budget misses. High-load mode
latency is mixed. A long physical-device run, assistive output and installed
shell/DPI acceptance remain open. The user owns the default accent choice.
Beta 28 preparation needs its own release candidate and applicable CI,
production signing, packaging, update and official 16 KiB gates.

## Beta 27 refinement follow-through (2026-11-24)

The [refinement receipt](BETA_27_REFINEMENT.md) records Windows Profile
measurements, palette and layout comparisons and manual limits. The dense
Day scroll still has raster budget misses on the development host. A long
real-device run and installed Windows shell/widget DPI checks remain open.
Run signing, packaging, upgrade and official 16 KiB acceptance with a future
release candidate. This branch did not create or publish a release.

## UI Redesign 2.0 release acceptance (2026-11-24)

The [final integration review](UI_REDESIGN_FINAL_ACCEPTANCE.md#remaining-acceptance-and-decision)
classifies outstanding gates for implementation `90768ef`.
The settings restart stall is resolved. Normal-session Windows portable
reopen, the Android emulator's 192 native widget cases, and local packaging
have verified receipts. Keep final verification on the normal Windows
session with disposable app-data directories and the disposable Android
emulator. This review's execution policy excludes Windows Sandbox.

- **Release blockers**. Exact-candidate green CI and production package
  identity, plus the official 16 KiB API 36 Release emulator gate.
- **Required manual acceptance**. Registered installer/update on an
  isolated Windows test installation, physical Windows input/DPI and
  assistive output, and separately authorized two-client Drive/recovery.
  Verify OEM-only behavior on its target hardware when applicable.
- **Nonblocking deferred improvement**. Longer Focus and memory profiling
  with a controlled release-mode comparison.

## Batch 5 Settings, Sync and widgets (2026-11-24)

The [Batch 5 receipt](TEST_RUN_LEDGER.md#batch-5-settings-sync-and-native-widgets-2026-11-24)
records Flutter and native-render verification at `2227ff0`. The settings
export/import/restart journey initially stalled. The [final integration
review](UI_REDESIGN_FINAL_ACCEPTANCE.md#settings-exportimportrestart)
records its harness correction and passing persistence check. Windows Explorer attachment, native input,
assistive technology and DPI on physical displays remain pending.
The final integration receipt covers the full Android native stress
matrix and emulator touch/IME. Real cloud and device-dependent behaviors
remain tracked in the release gates above.

## Batch 4 Focus, Habits and Goals native acceptance (2026-11-24)

The [Batch 4 receipt](TEST_RUN_LEDGER.md#batch-4-focus-habits-and-goals-2026-11-24)
records host and offscreen acceptance at `6815424`. Windows
physical keyboard, pointer, reader and DPI checks remain due. Android
physical touch, hardware Back, TalkBack, IME, background timer and recovery
observations remain due. Packaged acceptance is pending for both platforms.

## Batch 3 calendar native acceptance (2026-11-24)

The [Batch 3 receipt](TEST_RUN_LEDGER.md#batch-3-calendar-and-event-editing-2026-11-24)
records widget and offscreen acceptance at `0741dd2`. Windows still
needs physical mouse, trackpad, keyboard, assistive input and DPI checks
for the timeline and editor. Android still needs physical touch, TalkBack,
system Back, IME and native alarm observations. Packaged Windows and Android
release acceptance remains due for the release candidate.

## Batch 2 task-list native acceptance (2026-11-23)

The [Batch 2 receipt](TEST_RUN_LEDGER.md#batch-2-inbox-and-task-lists-2026-11-23)
records host and offscreen acceptance at `2bf025f`. Windows DPI and
assistive-input checks, Android TalkBack and IME, and packaged-device
acceptance remain pending.

## Todorbit UI redesign pilot (2026-11-23)

Batch 1 visual refinement is recorded for source `586e3a3` in the
[Batch 1 receipt](TEST_RUN_LEDGER.md#batch-1-visual-refinement-and-acceptance-2026-11-23).

Source `bb37558`. The [pilot receipt](TEST_RUN_LEDGER.md#todorbit-ui-redesign-pilot-2026-11-23)
covers targeted host checks and offscreen Flutter rendering. Native acceptance
remains pending for Windows mouse, keyboard and assistive input at real DPI,
Android system Back and IME on a physical device, and independent native
widget appearance. Packaged-build checks and native performance profiling
remain pending. The redesign is a development branch based on Beta 26.

## Release candidate build and acceptance (2026-11-21)

- **Level 3 host verification passed.** Full analysis, the architecture gate,
  the serial suite and all three previously intermittent cases passed.
  [Test receipt](TEST_RUN_LEDGER.md#release-candidate-host-baseline-2026-11-21).
- **Windows execution pending.** Select and synchronize the release version,
  run exact-candidate CI, build the native companion and Windows Release,
  run packaged self-test, validate installer and portable contents, and
  generate and verify checksums. Exercise isolated install/update/recovery
  and physical Windows timer, editor, keyboard, widget and DPI behavior.
- **Android execution pending.** Run exact-candidate CI and workflow tests,
  verify release signing and package identity, and check the production
  artifact for 16 KiB alignment and runtime behavior. Use a physical device
  for lifecycle, accessibility, share, notification and timer acceptance.
- **Cross-platform acceptance pending.** Verify the approved Drive release
  configuration, live two-client OAuth, sync and recovery. Use the existing
  [release checklist](RELEASE.md) and [Android acceptance](ANDROID.md).

## Beta 25 Architecture Program Release Acceptance (2026-11-20)

- **Level 3 pending.** Broader cross-platform manual matrix across non-primary host configurations.
- **Level 4 pending.** Physical Windows 11 hardware acceptance (touch, DPI scaling, multi-monitor window management, shortcut navigation); physical Android device acceptance (TalkBack accessibility, Share sheet receiver, process death/recreation); real two-client Google Drive OAuth synchronization.

## Beta 24 Windows CI correction acceptance (2026-11-19)

- **Level 3 pending.** Run the complete Windows CI workflow once Gemini integrates `fix/todorbit-beta24-windows-ci`.
- **Level 4 pending.** Verify the integrated Windows installer and portable artifacts through the existing package and update gates. Exercise the view-help menu with a physical Windows keyboard and the shared icon picker with the Android keyboard at large text. [Scoped host evidence](BETA24_WINDOWS_CI_FAILURE_FIXES.md).

## Beta 24 release-blocker patch acceptance (2026-11-18)

Before release, exercise real Android sharing with two external providers,
multiple-file grants, Flutter inbox deletion during import, a process kill and
restart, and the continued availability of managed task attachments. Use an
isolated Android profile. Verify desktop keyboard/focus on physical Windows
and run exact-candidate package/update, real Drive and 16 KiB runtime gates.
See the [Codex Beta 24 implementation receipt](BETA24_CODEX_RELEASE_BLOCKER_FIXES_2026_11_18.md) for executed checks and the legacy Sync limitation.

## Prompt 4 Smart Reschedule acceptance (2026-11-17)

**L3/L4 PENDING; scoped Level1/2 host checks PASS.**
[Receipt](PROMPT4_SMART_RESCHEDULE_2026_11_17.md) and [source manifest](PROMPT4_SMART_RESCHEDULE_2026_11_17_SOURCE.json).
Before release, use isolated profiles and verify Windows keyboard/focus/Escape,
resize/scroll/expansion at actual DPI, Android production menu/per-task entry,
Back/IME/touch/TalkBack, narrow landscape and lifecycle interruption. Observe
actual alarms/reminder reprojection/delivery after occurrence/session Apply/undo
and timezone/DST transitions. Broad host integration, packaging/update and device
acceptance remain separate gates. Reuse unrelated valid packaging/cloud evidence
only for matching artifacts; no new real OAuth requirement is introduced by this
UI change. No failed critical test deferred: 64 scoped host checks pass.
No live app/DTD exists; native launch prerequisite is blocked by Windows symlink
support. Offscreen font/theme captures do not close physical acceptance. Trigger
independent review/integration with Prompt5; do not treat this as publication or
permission to modify Stable. No Prompt5/6 work started.


## Integrated Prompts 2/3 acceptance - 2026-11-17

Target: final checkpoint on `integration/ui-reliability-p2-p3`; [source identity and executed gates](INTEGRATION_P2_P3_2026_11_17.md).
Owner: next integration/release reviewer. Level 1/2 selected integration gates PASS
(122 tests, full analysis); no critical failure is being deferred here.

- Level 3 PENDING: wider application combinations, full RTL/theme/assistive-tech
  matrix and measured performance profiling. Current source has focused narrow,
  light/dark/large-text/IME and cache-identity evidence, not full runtime coverage.
- Live debug BLOCKED: no DTD/debug app; requested hot reload had no target.
  `flutter pub get --offline` resolves pinned packages but native plugin setup
  reports missing Windows symlink support. Use an authorized isolated profile
  after tooling is available; do not use personal or implementation profiles.
- Level 4 PENDING: physical Windows pointer/keyboard/resize/DPI/native focus;
  Android device Back/TalkBack/IME/background/kill/restart and actual month-edge
  navigation under sync. Verify timer identity/work accounting and route retention.
- Level 4 PENDING before release: exact-candidate native/installer/Android packaging,
  install/update, 16-KiB runtime, actual alarms and real OAuth/Drive journeys.
  Schema29/Stable unchanged; no push/publication or Prompt4/5 work was performed.


## Prompt 2 task timer/composition acceptance — 2026-11-17

Target: `feature/todorbit-task-ux`, base `5803e52` + [source manifest](PROMPT2_TASK_UX_2026_11_17_SOURCE.json).
Owner: next Codex integration/release reviewer. [Executed Level 1/2 evidence](PROMPT2_TASK_UX_2026_11_17.md)
is complete for changed critical boundaries; the items below are additional
acceptance, not deferred critical unit/persistence verification.

- Level 3 PENDING: wider shell integration, new compact/menu controls at 2x text,
  light/dark, RTL, long labels, keyboard/semantics permutations.
- Live debug BLOCKED: no DTD/debug app; requested hot reload had no target.
  Flutter dependency setup reports Windows native plugin symlink support missing;
  use an authorized isolated profile after Developer Mode/tooling is available.
- Level 4 PENDING: Windows physical pointer/keyboard/DPI, Android physical Back,
  TalkBack/background/kill/restart/checkpoint review. Confirm same-session identity,
  one work interval, cancellation route retention, finish/recovery and task/status/
  plan separation. Process-local focus phase is intentionally not restart-persisted.
- Level 4 PENDING before any release: exact-candidate packaging/install/update,
  Android 16-KiB runtime and existing real-service/release gates. No beta authorized.


This backlog tracks unperformed Level 3 regression and Level 4 acceptance.
[AI Review Queue](AI_REVIEW_QUEUE.md) tracks unreviewed code independently.
An approved code review or empty queue does not establish platform/release readiness.

## Selection, source identity and status

- Level 1: relevant inexpensive coding checks; reuse matching valid evidence.
- Level 2: the smallest checks covering affected persistence/migration/CAS/sync/
  encryption/backup/recurrence/alarm/history invariants are immediate and mandatory.
  They cannot be deferred here to save time. Unrelated UI/docs edits do not require
  all critical suites. See [Testing](TESTING.md) and [workflow](CODEX_WORKFLOW.md).
- Level 3: broader host/integration/environment permutations, batched on demand.
- Level 4: appropriate artifact/device/install/update/real-service acceptance,
  required by the release plan before publication. Preserve mandatory gates in
  [Release](RELEASE.md); no implicit waiver arises from this backlog.

`PENDING` means unexecuted for its target; `BLOCKED` requires a named missing
prerequisite; `FAILED` retains the actual failure receipt; `PASSED` requires
source/artifact identity, command, environment and result; `SUPERSEDED` links
replacement coverage and a reason. None of the items below is a current pass.
A dependency named in an unexecuted procedure is not proof that it is unavailable.

For each execution record owner/date (+offset), exact Git commit plus dirty-source
manifest (or candidate APK/EXE hash), assertion/procedure, tool/config/device/zone,
actual result and receipt/log. Do not treat the target checkpoint below as an
execution receipt. Compare source, assertions, dependencies/configuration and
environment before reusing a pass. A relevant change creates a new PENDING target;
retain the historical pass/failure and its source instead of erasing evidence.
Only intersecting boundaries invalidate a result. Review the actual release gates,
not just this finite list, before publishing.

Product target baseline: `8be2f048757348f7c2f522f048e23801e5dc749f`, with
[portable reviewed-source identities](CALENDAR_REVIEW_SOURCE_MANIFEST_2026_11_14.json).
Future candidates must record their own identities. CAL-01 keeps its approved
supported-operation restrictions; no deferred item authorizes bypassing them.
Historical automated evidence is in the [calendar receipt](CALENDAR_CODEX_REVIEW_2026_11_14.md)
and relevant platform receipts; it does not prove the unperformed procedures here.

## Active verification backlog

| ID | Scope / owner role | Level / environment | Status | Target and outstanding evidence |
| --- | --- | --- | --- | --- |
| DEF-CAL-DST | CAL-01/CAL-03; calendar engineer | 3; isolated Windows VM with DST zone | PENDING | Reviewed product baseline, then candidate; actual transition-date persistence/rendering acceptance absent. |
| DEF-DRV-OAUTH | Drive Sync/recovery; release owner with authorized test-account operator | 4; two isolated Win/Android clients | PENDING | Candidate source/binaries/account authorization; real pairing/refresh/dual-client exchange absent. |
| DEF-AND-16K | Android candidate; release engineer | 4; Linux/KVM API-36 ps16k AVD | PASSED | Beta 20 APK `f7277b05…edf0`, asset 750329257: run 43694416334, 16384-byte pages, render/task/restart/production 42→43 retention pass. Applies only to this exact universal APK on x64; future candidates/physical ARM64 need their own acceptance. |
| DEF-WIN-PKG | Windows installer/update; release engineer | 4; disposable Windows VM/Sandbox | PENDING | Beta 20 Sandbox Beta 19→20 installer registration/database-byte preservation, uninstall/reinstall and portable startup pass; actual registered in-app handoff/GUI and physical Windows acceptance remain pending. See UIUX02_BETA_20_PUBLICATION.md. |
| DEF-WIN-WIDGET | Native companion; Windows widget engineer | 4; disposable Windows user, physical mixed-DPI monitors | PENDING | Candidate native executable hash; physical companion DPI/hit-test evidence absent. |
| DEF-AND-WORKFLOW | Mobile editing/SQLite/restore; Android engineer | 3; disposable API-35 AVD | PENDING | Actual android_workflow_test.dart run; update/Drive fixture and host passes do not cover it. |
| DEF-CAL-INPUT | Flutter CAL-03 resize/input; calendar engineer | 4; isolated Windows profile, physical mouse/mixed DPI | PENDING | Candidate app hash; real mouse dwell/reversal/multimonitor behavior absent. Native companion self-test is separate. |
| DEF-CI-CLOUD | INFRA-01 / ARCH-01; repository owner/CI maintainer | 3; GitHub-hosted runners and repository rules | PENDING | Final committed candidate including reviewed architecture guards; real automatic/manual/check/artifact/cold-timing evidence absent. |
| DEF-AND-WIDGET-DOZE | Android widget date rollover; Android engineer | 4; physical Android 12-15 device in Doze mode | PENDING | Final UIUX-02 source/artifact; observe actual inexact/delayed delivery, Follow Today and deliberate browsing separately. No exact-midnight guarantee. |
| DEF-AND-WIDGET-UPGRADE | Android widget upgrade preservation; release engineer | 4; physical Android device / emulator | PENDING | In-place APK update over existing install verifying `ACTION_MY_PACKAGE_REPLACED` preserves widget instances and config without data wipe. |
| DEF-UIUX02-DEVICE | UIUX-02; UI/Android engineer | 4; isolated Android runtime/device and affected Windows UI | PENDING | Offscreen default/stress cases pass; real IME/nonlinear text/TalkBack/locale/input and platform visual acceptance remain unobserved. |

## UIUX-03 candidate acceptance (2026-11-15)

Experimental Beta22 is published at source/tag1a5560a, version1.0.19-beta.22+45,
schema29. [Final receipt](UIUX03_BETA_22_PUBLICATION.md) and
[asset identities](UIUX03_BETA_22_PUBLICATION_ASSETS.json) supersede the initial
candidate manifest for publication. Exact-source CI, package/signing/hash gates,
actual replacement APK 16-KiB runtime and public production updater discovery
pass. Owner reports normal Windows task creation/Details editing/Focus start-pause
PASS on an isolated profile; automated desktop interaction was unavailable. No
further Sandbox testing is used. Rows below retain unperformed manual acceptance;
they do not defer a known failing critical invariant or claim complete device UX.

| ID | Scope / owner | Level / environment | Status | Outstanding procedure |
| --- | --- | --- | --- | --- |
| DEF-UIUX03-CHROME | Resources / Windows reviewer | 4; actual Chrome + candidate in disposable Windows profile | PENDING | Drag address-bar and actual hyperlink URLs (no `.url` prerequisite), files, images, folders and `.url` shortcuts; attach/link/cancel, normalization/rejection, nested editor close and receiver restoration, window/DPI coordinates. Record persisted target/bytes and app hash. Channel/widget tests and native compile do not close physical input. |
| DEF-UIUX03-DEVICE | Focus/Details/navigation / platform reviewer | 4; isolated Android runtime/device and Windows physical input | PENDING | Details edit/save/Back, Custom View hidden-scope behavior, Archive/Trash cancel/blocker flows, Stopwatch/Countdown/Pomodoro pause/reset/phase/expiry, leave/return through mini timer, background/suspend/process death/short restart and explicit checkpoint recovery; no powered-off work by default. IME/rotation/nonlinear text/touch/keyboard/DPI/accessibility. Record exact build/profile and observed states. |
| DEF-UIUX03-CANDIDATE | Schema-29 beta / release owner | 4; exact Windows/Android artifacts and isolated upgrade profiles | PENDING | Required automated CI/package/native/runtime/discovery gates PASS; actual Beta21-to22 Windows installed/portable and Android updater GUI handoff, schema approval/cancel and retention of synthetic records/attachments/views/preferences remain PENDING. Real two-client Drive exchange belongs to DEF-DRV-OAUTH; update all clients before schema-29 exchange and retain older-batch recovery. No downgrade migration is provided. No package publishing authorized by this row. |

The initial [candidate receipt](UIUX03_BETA_22_CANDIDATE.md) retains historical
package and isolated preservation evidence. The final replacement receipt records
exact hashes, actual APK runtime and normal Windows owner-reported acceptance.
These do not prove installed first-start migration approval, actual updater GUI,
physical Chrome/input/background or real two-client service exchange. All paired
clients must upgrade before schema29 exchange; no downgrade migration is provided.

## Beta 20 executed evidence (2026-11-15)

[Publication receipt](UIUX02_BETA_20_PUBLICATION.md) binds current package hashes
and commands. Exact signed APK 16-KiB x64 runtime/production-package upgrade and
fresh Windows Sandbox Beta 19→20 installer preservation passed. These do not
verify launcher widget IDs/preferences/navigation, physical overnight behavior,
nonlinear Android text/IME/TalkBack, real accounts or actual desktop input/update
GUI. All such pending rows remain open; future artifacts invalidate exact-package
passes. No personal profiles/accounts or host clock were used.

## Procedures and prerequisites

### DEF-CAL-DST

Owner: calendar engineer. Use a disposable Windows VM configured with a real
DST-observing zone. Keep the production host clock/timezone untouched. Create
synthetic events spanning known spring-forward and fall-back transition dates;
compare civil nominal identity, elapsed duration, stored UTC instants, exception/
alarm mapping, saved segments and Undo/Redo. Run the existing isolated Debug
harness only after building the reviewed source in that VM:
`./tools/dev/launch-isolated-calendar.ps1 -ProfileRoot <absolute-disposable-root>`.
Its helper seeds synthetic data and requires an existing Debug executable; verify
child APPDATA/LOCALAPPDATA/resolved profile before interaction. If testing actual
OS timezone-change notifications, change settings only inside the disposable VM.
Record the zone, transition dates, OS/SDK and source. Pure UTC-civil unit passes
are not a real-zone or notification-event acceptance claim. Deferred because
this environment permutation has not been performed, not because manipulating
the personal system clock is required.

### DEF-DRV-OAUTH

Owner: release owner and authorized dedicated-test-account operator. Authorization,
network, candidate source/binaries and two isolated clients are prerequisites;
never use stored personal credentials. Pair Standard Sync (or separately test
Private Sync with its actual recovery requirements); verify incremental batches,
not snapshot backup, when exchanging synthetic tasks/events. Test sign-in,
consent/refresh, edits/cancellations/occurrence alarms, conflict handling and
recovery. Perform supported desktop series moves on Windows and verify Android
readback; Android uses its existing agenda/editor, not the desktop drag UI.
Test snapshot backup/restore as a separate journey if required by the candidate.
Network-free mocks/contracts do not prove this real-service acceptance. Ordinary
CI may download dependencies but must not use personal OAuth tokens or accounts.

### DEF-AND-16K

Owner: release engineer. After a candidate artifact exists, obtain its validated
x64 APK asset ID and SHA from its preparation receipt. The separate trusted
workflow reads draft assets and has contents-write permission; it has no signing
secrets and makes no publication call. On the registered workflow, dispatch:

```powershell
gh workflow run android-16k-runtime.yml --ref <reviewed-harness-ref> -f asset_id=<x64-asset-id> -f sha256=<candidate-sha256>
```

Supply `previous_asset_id` and `previous_sha256` together for upgrade acceptance.
Record candidate source/artifact and harness ref separately, runtime page-size
proof, install/start/recovery/update outcomes and artifacts. Generic
android-verification does not invoke this workflow or close this item.

### DEF-WIN-PKG

Owner: release engineer. Use [Windows clean acceptance](WINDOWS_CLEAN_ACCEPTANCE.md)
and [updates](SOFTWARE_UPDATES.md). Prepare exact candidate installer/portable hashes
and previous-beta identity. The owner's default is a dedicated disposable Windows
user/VM; Sandbox enablement is not required. If the owner separately chooses the
optional Sandbox route, prepare its package mapping with
`./tools/prepare-windows-sandbox-acceptance.ps1 -PackagesDirectory <private-packages-directory>`;
`windows-sandbox-acceptance.ps1` is an in-Sandbox runner, not a host command with
an `-Installer` parameter. Observe installation, in-place upgrade preserving
synthetic data, shortcuts/uninstall and updater behavior in the disposable user/VM. Redirecting
APPDATA alone does not isolate installer registration or Credential Manager.
No hard-coded beta19 filename proves a later candidate; derive paths from the
candidate preparation receipt. See [Testing](TESTING.md) for automated commands.

### DEF-WIN-WIDGET

Owner: native widget engineer. Build the reviewed native Release companion with
`dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`;
verify the resulting executable/profile and run self-test plus the actual
[manual widget checklist](windows-widget.md). Observe 100/150/200% scaling and
mixed-monitor attachment, movement, font/hit testing and settings persistence in
a disposable user. Retain executable hash and observed results. A Flutter
calendar test does not prove native shell behavior, and a native self-test is not
physical display acceptance. The earlier unchanged native-source evidence is
historical; no fresh physical pass is asserted.

### DEF-AND-WORKFLOW

Owner: Android engineer. Use a disposable API-35 AVD; discover its actual ID with
`flutter devices` (never assume emulator-5580). Run serially with no concurrent
Flutter/Gradle/emulator process on the 16GB development host:

```powershell
flutter test --no-pub integration_test/android_workflow_test.dart --flavor github -d <disposable-device-id>
```

The integration fixture creates app-private temporary SQLite/profile data. Record
SDK/AVD, source and actual mobile editing/persistence/snapshot results. Existing
Android CI runs android_drive_updates_test.dart via its update script, not this
workspace fixture; neither host widget tests nor that other emulator test close
this item. Deferred for explicit environment/resource scheduling; physical device
acceptance remains a separate candidate requirement.

### DEF-CAL-INPUT

Owner: calendar engineer. In an isolated profile, use an actual mouse for Day/Week
resize across one/multiple pages, forward/backward edge dwell, stationary pointer,
reversal/re-entry, release/cancel/Escape, narrow/scrolled grids and mixed DPI.
Verify one persisted event/exception, no cancel writes, exact timestamps and one
Undo/Redo operation. Include supported recurring scope choice and guarded cases.
Retain app hash, display scale/window dimensions and observed vs untested rows.
Prior widget/Driver/native-button evidence remains valid at its boundaries but
is not a physical mouse-drag pass or native-companion acceptance.

### DEF-CI-CLOUD

2026-11-14 progress: focused [PR #1](https://github.com/2HIK4/Todorbit/pull/1)
targets the existing development baseline `053fa0f`, preserving the 165 historical
commits outside `main`. First [automatic run](https://github.com/2HIK4/Todorbit/actions/runs/43636796051)
on head `204b8d3` reached Linux SDK/cache/lockfile setup and then failed on an
unused test binding; later checks were skipped. Minimal fixture-only lint repair
requires new cloud evidence. Manual workflow/default-branch file registration
returns 404; do not change `main` or treat dispatch as activated. Details and
source/failure artifacts are in the [infrastructure receipt](INFRA_CODEX_REVIEW_2026_11_14.md#focused-development-pr-and-first-cloud-execution-2026-11-14).
Keep this item pending for repaired automatic results, manual registration and
unexecuted groups/timing/platform acceptance. No release or default-branch merge.
Second run 43637305743 on `539d1df` passed analysis/docs, then exposed Linux
PowerShell formatting in a helper-test assertion. Test-only normalization and
nine local passing helper tests are recorded in the receipt; a new cloud result
is still required. This is not a production helper or application logic failure.

Owner: repository owner/CI maintainer. Source is the final committed INFRA-01 tree
identified in its [review receipt](INFRA_CODEX_REVIEW_2026_11_14.md), not the old
product checkpoint, plus the reviewed [ARCH-01 changes](ARCH01_CODEX_REVIEW_2026_11_14.md)
when included in the next authorized candidate. Verify the architecture step and
calendar contract tests actually run on Ubuntu/Python 3.13; local Python 3.14,
actionlint and inert failure probes do not close cloud acceptance.
Follow [first execution and required-check migration](TESTING.md#first-github-execution-and-required-check-migration):
authorized commit/push/PR first, then inspect required-check rules and register
dispatch workflows on the default branch. Run the automatic job and all six
manual selections on exact refs. Verify Linux Flutter 3.47.7/Dart compatibility,
lockfile/cache restoration, cold/warm elapsed times, serial workload, branch/SHA
summaries, selected-only routing, real child-failure propagation and bounded
failure artifacts. Use a controlled non-release failure probe without weakening
release gates. Confirm old standalone windows requirements were intentionally
migrated; retain exact-candidate Windows/Android gates. Record remote run URLs,
conclusions and source; no local lint/parser/mock result closes this item.
No push, dispatch, repository setting change, signing or publication is authorized
by creation of this backlog.

### DEF-AND-WIDGET-DOZE

Owner: Android engineer. Use a dedicated test device (Android 12–16), synthetic
data and no personal accounts. Place Tasks and Calendar widgets, including two
differently configured instances. Record APK SHA, SDK, zone, clock, alarm state
and per-instance settings. Select Today on one and browse another date on the
other. Observe a real overnight rollover, USB disconnected/device idle; record
requested and actual delivery times. `setAndAllowWhileIdle(RTC_WAKEUP)` remains
inexact and may be batched/delayed. Verify Today advances on render, browsing
remains intentional, and return to Today works. Check clock/zone changes and
reboot followed by unlock restore one alarm; removing all widgets cancels it.
Forced-idle/clock-change tests in a disposable emulator are supplementary, not
proof of physical overnight behavior. Never change the personal host clock or
use personal data. No execution occurred in this review.

### DEF-AND-WIDGET-UPGRADE

Owner: release engineer. Use a disposable install with synthetic data, configured
launcher widgets and a previous compatible APK. Record both APK hashes, signing/
application identity, widget IDs/providers, settings, PendingIntent destinations,
content and alarm state. Install in place (`adb install -r <candidate.apk>`)
without data clearance, uninstall/downgrade fallback or widget recreation.
Observe actual MY_PACKAGE_REPLACED handling and retained IDs/config/content/
navigation, restored midnight alarm and synthetic-data continuity. Provider
names/XML and preference keys are statically compatible in UIUX-02; this is not
installed-upgrade acceptance. No running disposable emulator/source-compatible
installed candidate was available for a targeted upgrade run.

### DEF-UIUX02-DEVICE

Owner: UI/Android engineer. Level 4, PENDING. The
[UIUX-02 receipt](UIUX02_CODEX_REVIEW_2026_11_15.md) covers two screens plus an
alarm component, Dark/Light 360/393dp defaults and separate 1.5×/2× linear stress
cases. Verify a candidate APK in an isolated actual Android runtime: OEM fonts,
nonlinear accessibility scaling, IME/safe insets, physical pressed/focused input,
TalkBack, locale/RTL and launcher behavior. Verify affected Windows pointer/
keyboard/agenda appearance before shared UI release acceptance. A complete 24×11
product audit was never established and is not claimed by this scoped review.
