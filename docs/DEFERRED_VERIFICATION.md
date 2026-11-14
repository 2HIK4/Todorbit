# Deferred Verification Backlog

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
| DEF-AND-16K | Android candidate; release engineer | 4; Linux/KVM API-36 ps16k AVD | PENDING | Candidate x64 asset ID and SHA, optional prior APK; exact-artifact runtime evidence absent. |
| DEF-WIN-PKG | Windows installer/update; release engineer | 4; disposable Windows VM/Sandbox | PENDING | Candidate installer/portable hashes plus previous version; install/upgrade/uninstall evidence absent. |
| DEF-WIN-WIDGET | Native companion; Windows widget engineer | 4; disposable Windows user, physical mixed-DPI monitors | PENDING | Candidate native executable hash; physical companion DPI/hit-test evidence absent. |
| DEF-AND-WORKFLOW | Mobile editing/SQLite/restore; Android engineer | 3; disposable API-35 AVD | PENDING | Actual android_workflow_test.dart run; update/Drive fixture and host passes do not cover it. |
| DEF-CAL-INPUT | Flutter CAL-03 resize/input; calendar engineer | 4; isolated Windows profile, physical mouse/mixed DPI | PENDING | Candidate app hash; real mouse dwell/reversal/multimonitor behavior absent. Native companion self-test is separate. |
| DEF-CI-CLOUD | INFRA-01 / ARCH-01; repository owner/CI maintainer | 3; GitHub-hosted runners and repository rules | PENDING | Final committed candidate including reviewed architecture guards; real automatic/manual/check/artifact/cold-timing evidence absent. |

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
