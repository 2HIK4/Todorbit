# Android / Google Drive authentication readiness — 2026-11-06

## Latest cross-platform checkpoint (2026-11-07)

[Corrected real Windows/Android Standard acceptance, current private artifact paths and limits](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03)
supersedes the earlier stage below:383 operations/all43 portable tables converge,
corrected Android restore/reconciliation and repeated checks/restart pass. Both
updated credential-isolated candidates preserve prior artifacts and production
baseline. Same approved spare account/workspace, no new sign-in. Historical
failures and archived invalid decisions remain explicit. Windows is closed;
authenticated SSD emulator retained. No release, Private Sync or cloud snapshot
testing. Earlier build/readiness receipts retain only their recorded boundaries.


Scope: recover a retained isolated Google Play AVD, install/launch the existing
registered debug APK, and prepare auth-only Google connection. **No Android Sync
exchange is authorized or performed in this phase.** Private Sync and cloud
snapshot testing remain excluded. Continue from the completed
[real Windows milestone](REAL_STANDARD_SYNC_2026_11_06.md).

## Latest: Android account and read-only workspace preflight PASS (19:09 UTC+03)

Owner completed Google sign-in using the approved spare. On resumption the live
Todorbit controller still had no connected account. Reopened **only** the existing
Backups/auth-only Connect Google Drive action; it completed without another
account/consent prompt. Actual Android account ID now matches the pinned Windows
receipt, existing Standard approval and owner-confirmed spare ID. Account IDs and
credential values are not printed; private evidence pins the comparison.

**REAL Android Google Drive read-only metadata preflight PASS.** Invoked only the
existing `GoogleDriveProvider.sync.list()` on the authenticated Android runtime:
complete paginated GET listing in appDataFolder, non-trashed `todorbit-sync`
namespace. It returns exactly11 objects:1 existing workspace proof and10
operation objects representing9 unique batches. The known duplicate is the
retained Windows lost-upload-reply test copy. Every object ID, size, MD5 and
property matches the recorded Windows cloud inventory. All objects belong to
`315ab404-bbd0-55d3-b0d1-10afafe13fbc`, protocol2; no unknown workspace, generation
head, migrating object or incompatible protocol was found.

Standard mode is established by matching the **unchanged proof ID/size/MD5 and
metadata** to the Windows byte-verified Standard proof. This metadata preflight
does not re-download the proof or operation payloads. Android has not fetched or
materialized task records yet. Normal Drive, other applications and cloud
snapshot namespace `todorbit` were not enumerated. No pairing/prepare/activate,
Sync engine exchange, upload, PATCH, delete, reset or Start New Sync invoked.

Post-preflight DB/WAL hashes exactly match the pre-auth copies: schema27,
integrity OK, FK0, tasks0/events0/journal0, binding absent, capture/automatic0.
Actual path remains `/data/user/0/io.github.hik4.todorbit/files/TodoPilot/life_manager.sqlite`.
All18 production database/settings/encrypted-credential paths still match the
quiescent baseline. Emulator/app remain running unchanged: server PID572, app
PID3875; no reboot, reinstall, rebuild or suite repeat. Windows candidate stays
closed for sequential RAM use. Protected source/work remain preserved.

New private receipts: `post-owner-account-inspection.json`,
`post-owner-reconnect.json`, `after-auth-only-reconnect.json`,
`android-account-verified.json`, `android-read-only-cloud-preflight.json`,
`private-profile-after-auth-preflight.json`, and
`production-after-android-preflight.json` under the same evidence root below.
Read-only VM helper source/commands and logs are retained there.

The first metadata helper stopped with a foreign/incompatible-object guard
because it silently interpreted a VM `CastMap` wrapper as an empty map. Source
inspection identified `appProperties.cast<String,String>()`; a no-network
retained-object diagnostic found0 objects after GC. Corrected the **outside-Git
helper** to unwrap the backing map and reject unreadable wrappers. One justified
read-only list rerun passes exact comparison of all11 objects. Original source
and failure log retained; this was not an actual cloud identity mismatch or
application defect. No product source changed or credential values logged.

**Ready to authorize the first Android Standard Sync exchange with the existing
workspace and subsequent synthetic Windows/Android tests.** Android is still
unbound/disabled; no Android exchange approval record was created. Next owner
action: explicitly authorize that exchange/testing. No additional sign-in or
consent is currently required. No Private Sync, cloud snapshot test, production
data access, commit, push, tag or publication.

## Earlier environment/auth-readiness checkpoint

The earlier auth-pending state below is superseded by the verified account and
read-only preflight above. Environment warnings and their evidence remain valid.

**Native/app functions PASS after emulator-component correction, with a retained
startup warning.** This is bounded functional readiness, not an all-clean guest
or general platform acceptance. The strict zero-historical-ANR probe flag remains
**false** because Messaging recorded one startup SIM_STATE_CHANGED broadcast ANR.
It is not hidden, cleared or attributed to Todorbit. No additional ANR/crash
appeared over more than15 minutes of separated observations, native launches,
storage/APK staging, installation and Todorbit navigation. `system_server` PID572
remained unchanged. Google account and Android workspace verification remain
**PENDING OWNER AUTHENTICATION**; request separate exchange authorization only
after both IDs are checked.

| Check | Result |
| --- | --- |
| APK identity/signature/API/ABI | PASS; exact retained artifact, version35 / 1.0.19-beta.12, min26/target36, arm64-v8a+x86_64, v2 signature verifies. API35 x86_64 guest is compatible. |
| Offline userdata preservation | PASS; nine config/data/encryption/cache files copied offline and source/copy hashes verified. Original AVD retained; no wipe, reset, deletion or replacement AVD. |
| Retained disk structure | PASS; qemu-img check without repair reports no errors on userdata QCOW2. Not a full guest-filesystem or universal corruption check. File is sparse, not NTFS-compressed. |
| Original emulator35.3.11 recovery trial | FAIL; cold boot53s and services present, but System UI/GMS/Settings ANRs and UiAutomation timeout precede any APK. Native failure; no Todorbit install/auth in that trial. |
| Isolated official stable37.2.13 trial | PASS for observed post-startup critical functions; boot65s. Settings/Play/UIAutomation work; one historical Messaging startup ANR remains a warning. Strict zero-ANR gate does not pass. |
| PackageManager/ADB/storage | PASS; native queries,4MiB push/hash, full148,684,069-byte APK push/hash in4.32s, local staged `pm install` Success in2.94s. |
| Networking | PASS at Android validated-network level; native connectivity reports VALIDATED. ICMP ping receives no reply, retained as a diagnostic failure, not proof of no HTTP access. Actual Android Drive authorization/API requests still await owner sign-in. |
| Google Play services/Play Store | Packages present; persistent GMS process running, Play Store unauthenticated UI launches. Authorization success and current-account identity are pending. No services disabled or bypassed. |
| Actual Todorbit launch/navigation | PASS; Today renders empty, drawer, grouped Settings, Data and app, auth-only Backups/Google connection reached using native ADB input and UI semantics. Not full task/editor/widget/input/accessibility acceptance. |
| Android profile/SQLite/runtime | PASS; schema27, integrity OK, FK0, tasks0/events0/journal0; no account/workspace/device binding, capture disabled, automatic Sync0. Live VM field inspection corroborates actual path, account absent and Sync disabled. |
| Production/source preservation | PASS; all18 production DB/settings/encrypted-credential existence/hash entries and relevant startup settings unchanged. Frozen20 implementation hashes and3 unrelated protected source documents unchanged. Windows private app closed normally for sequential testing. |

## Diagnosis and controlled changes

Prior retained trace: `system_server` PID556 aborted at15:06:22 UTC+03 during ART
SuspendAll; culprit pool thread923 was in kernel D/uninterruptible wait. GMS
fsync histogram includes stalls above16s. Earlier installer/watchdog failures
also predate Todorbit launch. Root cause beyond emulator/guest/host interaction
remains **unproven**. Do not infer a RAM-only cause.

At this task's start the16GiB host had about1.1–1.5GiB available, about24.8GB
committed against36.2GB commit limit, and7.8GB pagefile use. Disk capacity and
sampled latency were adequate; commit limit was not exhausted. Closed only the
owned private Windows PID16828 normally; production18 paths/startup matched.
Owner freed personal-app memory; before the first trial about5.3GiB was free.
No personal processes or services were terminated by the agent.

Reused `TodorbitStandardLowRam20261106`, its2GiB/two-core720×1280/320dpi config,
Google Play API35 x86_64 revision9 and WHPX. First controlled cold boot used
supported host GPU rather than prior SwiftShader. It still developed native
ANRs and the UiAutomation command itself crashed after connection timeout;
closed only the verified AVD, retained logs/userdata, and did not install APK.
Guest pressure counters were permission-denied; no root/privilege bypass used.

Downloaded official stable emulator37.2.13 build16740729 from Google's
`repository2-3.xml` channel0 into the private evidence directory. Size455,344,678
and official SHA-1 `4d7268aa7787c640ad892844e6c9a5f159e91ad3` verified; local
SHA-256 is in `emulator-stable-verified.json`. Existing SDKs and system image
were not replaced. Same retained AVD/RAM/cores/host renderer, Vulkan off,
`-no-snapshot -no-boot-anim -no-audio`; no new AVD or userdata reset. The brief
initial ADB authorizing/offline state resolved during normal boot without keys
being read/copied or a global ADB-server reset.

[Google's troubleshooting](https://developer.android.com/studio/run/emulator-troubleshooting)
supports examining physical memory and commit separately;
[release notes](https://developer.android.com/studio/releases/emulator) record
newer large-file-transfer and Windows/WHPX fixes. These justify a component
trial, not a claim that any one published bug is our exact cause.

## Identities and paths

- Branch `feature/sync-ux-refinement`, HEAD `4dcda12`, existing frozen dirty source
  unchanged. No application changes, rebuild, commit, release/version change,
  push or publication. Reuse existing deterministic Sync/native/build evidence.
- APK:
  `D:\AI_Projects\life_manager\.buildlog\private-acceptance-20261106\packages\Todorbit-1.0.19-beta.12-schema27-github-debug.apk`.
  SHA-256 `01192d13226571fdeac48a21a47e2c27b014b4cc4a7846bb1298ba70deed9051`.
  Package `io.github.hik4.todorbit`; debug certificate SHA-1
  `64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`.
  Matches the owner-confirmed Android OAuth registration; no Cloud Console changes.
- AVD userdata:
  `D:\AI_Projects\TodorbitPrivateBuilds\standard-acceptance-20261106\Android\TodorbitStandardLowRam20261106.avd`.
  Owner/SYSTEM/Administrators ACL retained. Separate local locator points to this
  same AVD; emulator home/user preferences are task-local. **Do not launch it
  through old Android Studio emulator35.3.11 for this acceptance.** Reuse the
  running guest or the recorded stable binary/argv with a fresh reviewed receipt.
- Stable binary:
  `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\evidence\android-readiness\emulator-stable\emulator\emulator.exe`.
  Actual owned launcher PID29296, QEMU PID24052, serial `emulator-5582` at checkpoint.
  Always verify AVD name before device-specific operations; no physical phone targeted.
- Android user0 app sandbox: `/data/user/0/io.github.hik4.todorbit`.
  Actual DB/settings: `files/TodoPilot/life_manager.sqlite` and adjacent JSON.
  Package was absent before installation; no existing app/data replaced.
  Android keystore/preferences and Google Play account storage stay inside this
  AVD; no Windows tokens, credential files or personal profiles were imported.
- DB/WAL-only copies were read through debug `run-as`; source hashes stable
  before/after copy, host integrity/FK/binding checks pass. No credential stores
  copied. Read-only live VM inspection uses a localhost ADB forward; its URI is
  private evidence, never printed. First expression inspection failed because no
  compilation service is attached; corrected to field inspection, no app rebuild,
  hot reload or heavyweight Flutter attach. No credential values logged.

## Audit and next owner action

Evidence root:
`D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\evidence\android-readiness`.
Includes both boot logs, retained old/new ANR/crash buffers and screenshots,
`diagnosis.json`, `avd-preservation.json`, disk checks, verified download identity,
`stable-qualified-*.json`, native launch/storage/APK receipts, actual UI XML/PNGs,
`private-profile-verification.json`, `vm-before-auth.json`,
`production-after-android-setup.json`, and `readiness-summary.json`.
Strict probe false flags and all earlier failures remain retained. A separate
command index records scope/reasons; no full Flutter suite or Android rebuild.

Use only the running emulator. At the Google prompt, owner must select/sign in
to **the same approved spare account used for Windows** and approve Todorbit's
Drive app-data consent. Do not use a personal account, create/restore a snapshot,
tap Sync Now, reset or Start New Sync. No password/2FA/credential entry is automated.
If the app's three-minute authorization request expires while adding the Google
account, finish account setup and reconnect through the same auth-only button;
do not repeat account creation or choose the Sync setup route.

Observed owner boundary at18:32 UTC+03: native Google Sign in shows an empty
Email or phone field. Auth-only Connect opened GMS AuthorizationActivity, then
MinuteMaidActivity. Skipped only the optional carrier phone-number discovery
page using Google's Skip button. No account, password or 2FA entry automated;
UI automation stops here. `google-flow-start.json` and pre-entry screenshots
record the boundary, not authorization success. If the app request expires,
owner can finish adding the spare Google account and report that state; the
agent can reopen the auth-only connection for Drive consent afterward.

After owner reports connection, read live account ID and compare with the pinned
Windows receipt. Only on equality run **read-only** `todorbit-sync` metadata/proof
preflight and verify existing workspace `315ab404-bbd0-55d3-b0d1-10afafe13fbc`,
Standard protocol2, no unexpected workspace/control objects. Verify Android
capture/binding still disabled/absent. **Then report and request explicit Android
exchange authorization.** No approval record or replacement workspace is created
by this readiness task. Preserve existing synthetic cloud objects and evidence.

Bidirectional task/event creation, edits/completion/deletion, recurrence,
projects/checklists/attachments, offline conflicts, process recovery and duplicate
prevention remain **unverified on actual Android**. Existing real Windows passes
remain valid for their scope. Private Sync and cloud snapshot testing stay excluded.
