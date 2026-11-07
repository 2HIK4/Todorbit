# Real Standard Sync acceptance — 2026-11-06

## Latest cross-platform checkpoint (2026-11-07)

[Corrected real Windows/Android Standard acceptance, current private artifact paths and limits](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03)
supersedes the earlier stage below:383 operations/all43 portable tables converge,
corrected Android restore/reconciliation and repeated checks/restart pass. Both
updated credential-isolated candidates preserve prior artifacts and production
baseline. Same approved spare account/workspace, no new sign-in. Historical
failures and archived invalid decisions remain explicit. Windows is closed;
authenticated SSD emulator retained. No release, Private Sync or cloud snapshot
testing. Earlier build/readiness receipts retain only their recorded boundaries.


**Latest: owner-authorized REAL Standard Windows/Drive acceptance passes.**
[Current results and limits](REAL_STANDARD_SYNC_2026_11_06.md): existing candidate,
fresh spare-account approval/workspace, upload/readback, independent desktop
download, edits/deletions/conflict resolution, controlled lost-reply recovery,
local restore/reconciliation and real resync.43 portable tables/81 immutable
facts agree; production/recovery unchanged. Android and Private remain open.
The prior empty-cloud/unapproved checkpoint is superseded; synthetic cloud
history is now deliberately retained for further acceptance.
The earlier requests for another Windows user/private-build approval below are
historical and superseded. Standard Sync remains gated pending the owner's
explicit next instruction to create the fresh synthetic-data workspace.

## Latest reevaluation: normal Windows account preferred (15:25 UTC+03)

The owner prefers reasonable same-account separation over more infrastructure.
**A separate Windows user is not inherently required for separate databases or
Google account selection.** The earlier recommendation was too broad in treating
shared browser/storage context itself as accidental credential reuse. No Sandbox,
Windows user or emulator is started for this reevaluation. Earlier user-creation
scripts are retained as historical alternatives, not the recommended next step.

The unchanged enabled binary does have a narrower unresolved write-isolation
problem. Inspection establishes:

| Concern | Actual behavior / assessment |
| --- | --- |
| Local data/settings | APPDATA + portable executable-directory hash selects an independent SQLite/profile; native IPC also has a profile hash. No import or copy of personal data is necessary for a test profile |
| Token selection | `SecureCloudTokenStore` keys are `todorbit.drive.<SHA256(absolute database path)>.<purpose>`. A fresh unique DB path requests different token, workspace-key and reset-operation entries. It does not normally select personal tokens merely because the Windows user/client ID is shared |
| Browser sessions | OAuth requests `prompt=consent select_account`, PKCE and state; owner can explicitly choose the spare account in the normal browser. Shared browser cookies are not themselves silent selection/reuse of a saved Todorbit token |
| Account/workspace pinning | Verified Drive permissionId is retained; refresh rejects account changes. Saved pairing checks account/workspace/device, and new namespace discovery uses the selected account. Account labels alone are not workspace proof; an empty local DB does not imply an empty remote namespace |
| Shared secure-storage writes | Windows plugin4.2.2 loads its entire DPAPI map from the application-support Known Folder, mutates one key and rewrites that shared file. Its `_AsyncLock` is process-local, not a cross-process lock. Overlapping production/test read-modify-write operations can lose an update. Error paths can delete an unreadable map. These are source-level risks, not a reproduced loss or proof of existing corruption |
| Native startup | Release startup invokes `synchronizeStartup` even with launch-at-sign-in false. `StartupRegistration.SetEnabled(false)` can inspect/remove stale entries from the shared user's HKCU Run key. It does not rewrite a valid live production entry, but the settings file alone is not a guarantee of zero changes to existing startup configuration |

Thus database/profile and normal authentication selection are independent, but
the existing build cannot provide **independent credential-file writes** through
APPDATA/LOCALAPPDATA or an exposed launch setting. Closing personal app/widget
processes reduces the concurrency risk; it does not make the store independent.
A backup permits recovery but is not permission to modify production tokens or
claim those risks are eliminated. The app is **not launched or connected**.

### Recovery copy completed before any proposed launch

Verified read-only local recovery snapshot:
`D:\AI_Projects\TodorbitPrivateBuilds\standard-acceptance-20261106\Recovery\20261106-152133`.
Both existing fixed-name TodoPilot/Life Manager databases were copied with SQLite
online backup in read-only source mode (committed WAL included), rather than
guessing which historical profile matters. The copies pass `integrity_check`
and have zero foreign-key violations. Top-level profile JSON files were copied
with matching before/copy/after SHA-256 values. Managed attachment bytes stored
in SQLite are included. Private manifest records source paths and file hashes;
no record titles or personal values were printed or queried for testing.

This is a local SQLite/settings recovery folder, **not an app-importable backup
package, token export, browser backup or external-linked-file archive**. Credential
stores were not read/exported/decrypted; production tokens and cloud content were
not modified. Existing app/widget processes were not stopped or manipulated.
This backup operation was explicitly authorized by the owner's preservation
request; it is not a test against personal data.

### Simpler account-verification sequence already exists

On a future safely isolated, fresh/unpaired test profile, **Backups & transfer →
Connect Google Drive** performs authentication without creating a Sync binding.
Its `connectionChanged()` calls the engine, but the engine exits before cloud
exchange when binding is null. This allows owner account verification first.
Do not use **Sync → Connect Google Drive** for that preflight: its manual action
continues from sign-in into pairing/activation and initial exchange. Workspace
discovery must then be read-only and checked against the spare account before
allowing workspace creation/upload. No such account/discovery calls are made now.

### Least complicated safe next step

For the preferred **normal Windows account**, recommend a narrowly changed private
candidate with a profile-local DPAPI credential store (no fallback to the shared
production store) and no global startup changes in this test configuration.
Keep existing OAuth, account-pinning and Sync algorithms. Reuse the auth-only
backup connection path above; use a disposable-account/workspace verification
gate before actual Sync. This requires a real, focused source/packaging change;
it is not achievable by inventing an environment flag for the unchanged binary.
Only that changed private candidate would need a build and focused isolation
checks; no full suite, VM, new user or Android launch is needed.

No new build/code change is performed without agreeing that small scope. If the
owner insists on the unchanged binary with complete credential-file separation,
a separate OS identity remains the existing alternative; it is not being created
or recommended as mandatory. The preferred next action is to agree the focused
same-user isolation change, **not Google sign-in yet**. Personal data/tokens/cloud
must not be used to test it. Current prepared candidate remains unlaunched.

### Reevaluation receipt

Source `4dcda12`, unchanged app/dependencies/artifacts; UTC+03, 2026-11-06.
Reused existing build/installer/native/deterministic evidence; no product tests.

| Action | Result / scope |
| --- | --- |
| Git/process/read-only source audit | Preserved all existing work; no private candidate, emulator, Sandbox or user-creation action. Reused loaded UI/regression instructions |
| Portable paths, token load/connect/refresh, pairing and Windows plugin load/save/lock/error handling | Logical key/account separation verified by source; shared-file write/cleanup and HKCU effects remain unresolved. No personal credential access or experimental corruption test |
| Backup/auth-only UI/controller/engine call-chain inspection | Existing auth-only route identified; unpaired engine exits before exchange. Manual Sync connect auto-activates. No OAuth or Drive traffic performed |
| Read-only SQLite online backup plus copied-DB PRAGMA checks; stable top-level JSON hashes | PASS two recovery DBs, both integrity OK, zero FK violations; private `latest-recovery.json` / recovery manifest. No source DB writes requested, no token export, no personal-record assertions |

## Current checkpoint: persistent low-RAM strategy (15:10 UTC+03)

This continuation supersedes the Sandbox sign-in instructions below. The owner
reports Sandbox closed before authorization. It is not reopened. Source remains
`4dcda12` on `feature/sync-ux-refinement`; only acceptance documentation changes.
No Google authorization/exchange, workspace reset, build, full suite or release.

Persistent private root, outside Git:
`D:\AI_Projects\TodorbitPrivateBuilds\standard-acceptance-20261106`.
ACL is restricted to the current owner, SYSTEM and Administrators. The existing
enabled portable was extracted to `Windows\app\Todorbit` and verified against
its retained package hash and corresponding Release files. It was **not launched
under the personal Windows identity**. Prior installer, native self-test,
deterministic Sync and artifact evidence are reused without rerunning them.

### Sandbox closure and memory

- At 14:56:56: 15.74 GiB usable RAM, 4.32 GiB free. Pagefile 18,439 MiB allocated,
  8,552 MiB in use, recorded peak 13,661 MiB. Earlier dual-VM observations were
  about 0.55 GiB free. These show pressure, not proof that it closed Sandbox.
- Accessible System/Application and virtualization logs show pause/network
  teardown around 14:53:09–15. No matching Sandbox WER report, application-crash
  event or contemporaneous resource-exhaustion record was found. Resource-detector
  latest records are November 3; resolver November 4. Compute channels advertised
  by the provider are not readable/available in this session. Cause **UNPROVEN**.
  No dump, personal credential store or Google account was inspected.
- Idle host disk samples were about 0.09 ms/transfer in one sample; this does not
  establish historical latency during either failure. Paging counters and full
  non-sensitive event observations are retained privately in the new root.
- At 15:08:53 after closing the task emulator: 4.16 GiB free RAM; pagefile 8,476 MiB
  in use. No guest or emulator is running. `wsb list` reports zero instances; an
  idle Sandbox broker (~62 MiB) is not a running VM. Personal app/widget processes
  were left untouched. Platform testing will be sequential.

### Windows isolation result: same-user launch blocked

APPDATA redirection correctly isolates Flutter SQLite/preferences and native
profile paths, but is **insufficient for the owner's credential-isolation rule**:

| Surface | Verified implementation / decision |
| --- | --- |
| SQLite, settings, backups/resources | `ProfilePaths`: APPDATA + portable marker + SHA-256 of the executable directory; legacy fallback is bypassed with that marker. Expected persistent data is `Windows\Roaming\TodoPilot\portable-<hash>\` |
| Secure storage | Locked `flutter_secure_storage_windows` 4.2.2 FFI calls `getApplicationSupportDirectory()`, loads/decrypts its complete map, then selects the profile key. `path_provider_windows` 2.3.0 uses `SHGetKnownFolderPath(RoamingAppData)`, not the APPDATA environment variable. A profile-specific key does not prevent opening the same Windows user's shared map. Compatibility also uses that user's native credential APIs |
| OAuth browser | Actual `LoopbackGoogleAuthorization` uses `url_launcher_windows`/`ShellExecuteW`, which opens the identity's default HTTPS browser. Changing APPDATA alone does not isolate personal browser cookies/accounts |
| Native companion | Adjacent packaged executable, inherited APPDATA, portable/profile-specific pipe/mutex; `--app-exe` points at that same bundle. Startup synchronization touches HKCU Run and can inspect/clean stale entries. Theme reads also use HKCU. A separate data directory alone does not isolate registry behavior |
| Caches/extraction/temp | Launcher redirects LOCALAPPDATA, TEMP/TMP and `DOTNET_BUNDLE_EXTRACT_BASE_DIR` into the dedicated private root. Windows Known Folders/browser/DPAPI must belong to a separate Windows identity |

No personal token file, Credential Manager entry, browser profile or registry
startup value was read to validate this; dependency/application source supplied
the proof. No application rewrite or disabled secure storage is proposed.

Smallest safe alternative: a **dedicated persistent standard local Windows user**,
`TodorbitDriveTest`, running the existing portable directly on the host. This
avoids VM RAM overhead and separates the real Windows profile, browser, HKCU,
DPAPI and compatibility credential namespace. Current session is not elevated;
the account has **not** been created. A fully verified live Windows test profile
is therefore **not yet available**. Do not launch the extracted EXE directly.

Prepared outside-Git files for owner review:

- `Setup-TestIdentity.ps1`: requires elevation, refuses an unrecognized existing
  account/SID, creates a standard user, asks for a **new local Windows test-user
  password** in a secure dialog, grants that SID scoped folder access, then starts
  the launcher using `-Credential -LoadUserProfile`. It saves no password and
  does not add the user to Administrators. It is not executed by the agent.
- `Launch-IsolatedWindows.ps1`: refuses the personal/elevated identity, verifies
  SID and OS Known Folders against the Windows ProfileList entry, hashes all
  packaged files, checks portable marker and linked directories, sets the private
  environment, and preconfigures native launch-at-sign-in false only when absent.
  It records exact identity/path metadata before launching; no token contents.
- `Start-Existing-Test.cmd`: later reuses that loaded Windows identity/profile,
  prompting for its Windows password without `/savecred`. Google authorization
  can persist normally in that identity's secure storage.
- `README.txt`: exact owner command, scope and future reuse instructions.

Planned paths: `Windows\Roaming`, `Windows\Local`, `Windows\Temp`, native extraction
`Windows\Local\DotNetBundle`, `Windows\Evidence`. Real Windows Known Folders and
the encrypted `Hussam Alkhatib\Todorbit\flutter_secure_storage.dat` remain inside
the dedicated OS user's own profile, not the personal user's. Exact OS paths and
portable DB path are computed by the launcher, not guessed or claimed observed.
No credentials/configuration are committed or mapped from a personal profile.

### Android conservative solo attempt

Fresh AVD `TodorbitStandardLowRam20261106` under the private root's `Android\`,
serial `emulator-5582`; Play API35 x86_64 revision9, emulator35.3.11/WHPX.
Explicit 2,048 MiB, two cores, 720×1280/320dpi, supported
`swiftshader_indirect`, Vulkan off, no snapshot, no audio. Google Play services
and Play Store remain intact. Prior AVDs/data/logs were not reused or removed.

Boot completed in 163.446s. At 15:05:11, boot=1, PID556, package/input/GMS/Play
present, but Phone had already SIGABRTed and native Settings reported timeout.
At 15:07:17, the server was absent, package/input/activity unavailable; logs show
system_server SIGABRT at 15:06:22, with ART `SuspendAll timeout`/unsuspended thread
in the later native trace. **No Todorbit APK was installed or launched.** This is
an independently reproduced guest-system failure, not an app/Sync defect.

A synthetic 8MiB ADB push took 1.94s, and on-device SHA-256 matched. Basic data
transfer worked in this attempt. QEMU used 2.86 GiB working set / 3.19 GiB private
commit, with host free RAM about 1.45 GiB at one sample. Resource reduction did
not establish stability; exact emulator/image/host cause remains unresolved.
Closed only the verified task AVD at 15:07:38, preserving userdata. No reset,
Play-service disablement, APK retry, emulator/image update or download was made.
Android acceptance remains blocked pending a changed, qualified environment.

### New verification receipt

All times 2026-11-06 UTC+03; source/artifacts above. Detailed evidence is in the
private root (`Evidence\` plus selected event JSON files). New checks concern
isolation/environment only and do not invalidate unchanged product test passes.

| Command/action | Result / reason |
| --- | --- |
| Git/status/ledger/docs, process/memory/pagefile and disk counters | Existing work preserved; fresh environment diagnosis, no app/credential reads |
| `Get-WinEvent` System/Application/resource/virtualization, WER directory metadata; `wsb list` | Closure evidence collected; missing/unavailable Compute channels explicit. No OOM cause inferred; no Sandbox opened |
| Source/plugin audit, exact archive extraction/hash comparison | PASS static provenance; same-user secret/browser/HKCU isolation FAILS requirements. Portable not launched |
| Parse two prepared PowerShell scripts; invoke launcher as current user | PASS parse; expected wrong-identity rejection before app launch. Final parse after native-extraction/idle-broker guard correction also passes. Account setup and dedicated-user runtime NOT EXECUTED |
| New AVD creation plus one solo cold boot with explicit conservative flags | Environment attempt justified by no Sandbox, new userdata and reduced graphics/CPU. Boot succeeds; initial native Phone/Settings errors retained |
| Separated `adb -s emulator-5582` service/boot/PID/crash checks at 15:05:11 / 15:07:17 | FAIL guest health; server abort before any APK. Root trace retained; no additional boot/install retry |
| Synthetic 8MiB `adb push -Z`, `sha256sum` | PASS transport/data readback; meaningful contrast with previous timed-out writes, not a cloud/SQLite test |
| Exact AVD-name assertion then `emu kill`; final memory/device/instance inventory | PASS owned shutdown, userdata retained, no device/Sandbox guest left running. Idle broker distinguished |

### Required owner action

Review the private `README.txt` and setup script. If choosing the dedicated-user
alternative, run this once in PowerShell (normal UAC; creating a standard local
Windows user requires administrator rights unavailable to this agent):

```powershell
Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File D:\AI_Projects\TodorbitPrivateBuilds\standard-acceptance-20261106\Setup-TestIdentity.ps1'
```

Choose a new **Windows test-user password**, not a Google password, in its dialog.
The guarded launcher then verifies the real paths/identity and starts the portable.
Use **Settings → Sync → Connect Google Drive**, personally select only the approved
spare account and complete normal consent, keeping Standard Sync. Report when
authorization completes. Do not send credentials in chat. If setup/launch fails,
report its non-sensitive error; do not bypass identity checks or launch directly.

After that, inspect the actual path/readiness receipts, schema and synthetic
data, then verify first real Standard upload/readback before preparing Android
independently. Real exchange/CRUD/conflicts/recovery remain UNVERIFIED. Private
remains deferred to a separately approved second disposable account. No beta or
release readiness is inferred. Branch/HEAD unchanged; documentation uncommitted.

## Historical initial Sandbox session (superseded setup instructions)

Scope: owner-authorized disposable account selected personally during sign-in,
fresh isolated Windows/Android profiles, synthetic data, Standard Sync only.
No personal phone/profile, existing cloud workspace, Start New Sync, Private mode,
release/version change or publication is authorized by this checkpoint.

Starting source: `4dcda12`, branch `feature/sync-ux-refinement`. Application/native
inputs have no changes since `f26f6b0`; the enabled Windows archive is `d8abbec`.
The three preexisting storage-document changes are preserved. Detailed commands,
setup scripts, timestamps and machine-readable observations are retained under
`.buildlog/standard-drive-20261106/`; no credential contents belong there.

## Reused candidates and evidence

- Windows enabled portable: `D:\AI_Projects\TodorbitPrivateBuilds\drive-enabled-20261106-ab9a4087\packages\Todorbit-1.0.19-beta.12-schema27-drive-enabled-win-x64-portable.zip`.
  SHA-256 `11b3876a92223bc7d8ca295fa8b70032aae262231eca32f584e7c878c3612a5b`.
- Android registered debug APK: `.buildlog/private-acceptance-20261106/packages/Todorbit-1.0.19-beta.12-schema27-github-debug.apk`.
  SHA-256 `01192d13226571fdeac48a21a47e2c27b014b4cc4a7846bb1298ba70deed9051`.
  Package `io.github.hik4.todorbit`; Android debug registration is owner-confirmed.
- Both hashes were checked again before use. No build, dependency change or full
  suite was needed. [Enabled configuration/AOT/package checks](PRIVATE_DRIVE_ENABLED_BUILD_2026_11_06.md),
  [deterministic exchange and recovery](REFINEMENT_2026_11.md) and
  [backup/resource round trips](PRIVATE_ACCEPTANCE_2026_11_06.md) remain valid at
  their recorded boundaries. They are not real Google results.

## Environment and execution receipt

All new observations below are 2026-11-06, UTC+03. The changed boundary is the
new test environment and actual OAuth/runtime behavior; app code is unchanged.

| Command/action | Result and necessity |
| --- | --- |
| Git status/log, selected source diff and artifact SHA-256 | Expected branch/protected changes; only documentation differs from enabled archive; app/native/dependency inputs unchanged |
| Computer Use `sky.list_apps()` | BLOCKED: native pipe missing, OS error 2. Windows visual input cannot be claimed |
| `adb devices -l`, process/AVD/image inventory | No attached devices or running emulator; only retained unhealthy `TodorbitBatch6`. Personal phone never targeted; old AVD never booted or modified |
| `avdmanager create avd --name TodorbitDriveStandard20261106 --package system-images;android-35;google_apis_playstore;x86_64 --device pixel_6 --path <task root>/TodorbitDriveStandard20261106.avd` | Fresh userdata created using installed official Play API35 x86_64 revision 9. SDK emits missing `devices.xml` warning despite exit 0; generated config inspected. PlayStore enabled explicitly; complete image selected by absolute path. No image download or old userdata copy |
| Emulator 35.3.11, fresh AVD, port 5580, `-no-snapshot -gpu software -no-boot-anim -no-audio` | FAIL before Android startup: OpenGLES initialization. This is an environment graphics failure, not a Todorbit defect |
| Same fresh AVD, `-gpu swiftshader_indirect -feature -Vulkan` | Controlled renderer correction, no repeated old-AVD boot. Full first boot took 273.36 seconds; partial-service samples and premature Settings `PermissionPolicyInternal` error retained, not reported as app failures |
| Bounded ADB service/log/launch diagnostics; one selected-device `adb -s emulator-5580 reconnect` | Initial boot/transport incomplete, then boot=1, PID585 retained, native Settings launch succeeds and Pixel launcher resolves. Stalled log-only child stopped; ADB server/other devices not stopped |
| Fresh `.wsb`, read-only portable payload + bounded writable results only | Drive-enabled Release running under `WDAGUtilityAccount`. No host repo, profile, Desktop JSON/config or token directory mapped. Separate guest APPDATA/LOCALAPPDATA, native launch-at-sign-in disabled before app launch |
| Sandbox bootstrap SQLite read-only checks | PASS 14:28:36: empty tasks, schema27, integrity OK. Exact DB `C:\TodorbitStandardTest\Roaming\TodoPilot\portable-de7e1fa5ea9c9e41\life_manager.sqlite`. Bootstrap receipt `windows-results/windows-ready.json`; OAuth not started |
| `wsb list/exec --help`; scoped `Check-Isolation.ps1` via ExistingLogin | CLI available despite missing UI pipe. Initial inline command rejected by argument parsing, no guest command executed. Script-file invocation PASS 14:30:43, correct guest user/PID5656 and `C:\TodorbitStandardTest\Todorbit\Todorbit.exe`. Do not repeat setup/installer tests |

| `python <task root>/probe_android.py android-qualified-1.json` and `android-qualified-2.json` | PASS 14:33:01 / 14:35:12, >2 minutes apart: boot=1, PackageManager query works, activity/input/GMS/Play present, empty crash buffers. Main system_server PID585 retained. Second sample briefly included another PID4296; subsequent `ps`/`pidof` confirms only original PID585, with working Settings launch, no main-process replacement |
| `am start -W -a android.settings.SETTINGS`, foreground inspection and screenshot | PASS after completed boot. Settings renders, resumes and launches successfully; Pixel Home resolves. Earlier six-second first-launch timeout superseded only for native launch readiness, not hidden as a pass |
| Hash/AVD/qemu/absent-package assertions; `adb -s emulator-5580 install --no-incremental <verified APK>` | FAIL 14:38:35: streamed install reports PackageManager broken pipe. Todorbit was never launched. First native Settings/PermissionController aborts occurred after the initially passing samples; post-install sample shows PID5827 replacing PID585 and missing services. Initial health is superseded for ongoing readiness |
| Post-install `probe_android.py`, disk/installer queries and bounded logcat root-cause capture | Environment failure: Android watchdog killed system_server at 14:38:32, blocked in `PackageInstallerSession.write` on android.io >60s. Native Settings/launcher/GMS failures retained in logs. `/data` has 8.7GiB free, WHPX operational. Host available RAM is low with both VMs. Installer dump timed out; no app error/launch or real account activity |
| Restarted-service probe; file-based alternative preparation `adb -s emulator-5580 push <same APK> /data/local/tmp/TodorbitStandard.apk` | Services return under PID5827, but push times out after 75s; a bounded file-size query also times out. APK digest could not be verified on-device, so no file-based installation was submitted. This was a changed transfer method after investigating streaming failure, not an identical install retry |
| `adb -s emulator-5580 emu avd name` then `emu kill` | PASS 14:42:52, closes only the verified fresh failed AVD. Userdata, partial transfer and diagnostics retained; no wipe/uninstall/clear-data or retry of old AVD. Android test app profile/schema/workflows remain UNVERIFIED |
| Sandbox scoped process recheck via `wsb exec` | PASS 14:42:58, original guest PID5656/path retained and test app still running. Sandbox remains open for owner authorization; no host installation or existing profile used |
| Final protected-file SHA-256 comparison, documentation-link review, `git diff --check`, `adb devices -l`, `wsb list --raw` | PASS 14:44:52: all three protected files unchanged; links/diff clean; no Android device connected, intended Sandbox retained. No new app/test/build run. Detailed review in `handoff-review.json` |

App installation and the owner sign-in boundary are recorded below. No real
Sync outcome is implied by environment setup or successful installation.

## Real-service status

No Google account has yet been selected or authorized by the owner in these
profiles. No Todorbit cloud exchange is claimed. The A–L matrix in
[the real Drive plan](REAL_DRIVE_ACCEPTANCE_2026_11_06.md) remains unverified;
Private is outside this Standard session. The unfamiliar-task incident remains
unreproduced: no original-cause or resurrection fix is inferred from local tests.

The Windows candidate is ready for its owner-performed sign-in step. Android
acceptance is **BLOCKED by the guest environment**, even though initial health
samples passed. Todorbit was not launched on Android and its schema/UI/Sync were
not exercised there. A working Play emulator and stable install/launch are still
needed; do not sign into or repeatedly reboot the failed AVD. Storage/transport
failure and low host memory are observed; their ultimate host/image cause is not
proven. No application fix is justified by this evidence.

## Minimum owner action and resumption

In the open **Windows Sandbox**, use the running Todorbit:

1. Open **Settings → Sync → Connect Google Drive**.
2. Select/sign in with **only the fresh spare Google account** and complete
   Google's normal sign-in/consent. Leave Standard Sync selected. If an unexpected
   existing Todorbit workspace is reported, stop without replacement or reset.
3. Leave Sandbox open and report that authorization completed. Do not send the
   password, token, downloaded JSON or any recovery material in chat.

This is an authentication handoff, not another approval request. The owner has
already authorized Standard tests with synthetic data. Android sign-in is deferred
until a healthy emulator is available. Windows-only OAuth/first exchange can then
be inspected, but cross-platform results require both clients. Private requires
a second fresh account plus separate authorization after Standard acceptance.

Resume using Sandbox ID `bf33024b-2444-481e-93ac-11e626c8597e` only if still listed
by `wsb list`, with the exact guest app/profile above. Bootstrap configuration is
`.buildlog/standard-drive-20261106/Todorbit-Standard.wsb`. Do not reopen it over an
active session or close the existing Sandbox: guest authorization/profile state
is ephemeral. CLI execution is available for safe scoped checks; computer-use UI
remains unavailable. Do not read OAuth/token stores from the agent.

No synthetic task fixture has yet been created in these profiles. Later fixtures
must retain stable IDs, causal heads, deletion history and attachment hashes;
never reset a workspace to simplify a test. Reused deterministic checks are not a
new cloud result. The candidate is suitable for continued isolated private testing,
**not ready for a beta/release claim of verified real cross-platform Sync**.
