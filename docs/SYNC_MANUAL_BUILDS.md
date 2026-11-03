# Local builds for manual Sync acceptance

2026-11-04 (+03:00), application source `06b9dedee50ca6639e2e3a2f1d387f45fa0d1c62`,
branch `feature/sync-optional-encryption`. These local builds are for owner manual
acceptance, not a published release. Version remains `1.0.19-beta.9+32`.

Reviewed AGENTS, workflow/testing/ledger, optional-encryption and Sync receipts,
Windows build/profile/CRT guidance, Android signing/setup/OAuth and beta-9 build
provenance. The three unrelated storage-cleanup documents are preserved. No UI or
application change, conversion, passphrase rotation, live Google request, user
profile access, installer, AAB, emulator or publication is part of this task.

## Evidence and build decisions

All 23 final source/configuration fingerprints in the implementation receipt
match the current files. Reuse its targeted crypto, pairing, controller, adapter
and UI passes; no unit/widget tests or broad analysis are repeated. Published
beta-9 builds predate this implementation, so new platform binaries are needed.
One Windows Release bundle and one GitHub universal production-signed APK are
selected. Existing SDKs, dependency caches and signing configuration are reused.

Tracked Windows OAuth defaults remain disabled. The existing enabled public build
configuration matches its recorded approved provenance. The Windows wrapper uses
that same configuration temporarily, restoring original bytes in `finally`.
Android release uses existing `android/key.properties` without modification;
the actual configured certificate matches documented production SHA-256
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`
and SHA-1 `d0ae6028e4cd0c1c83671142f60f142da81dad96`.
No credentials are printed or included in artifacts. Existing OAuth project,
consent, certificate registration and cross-client discovery still require owner
verification; a successful build does not prove Google authentication or Sync.

## Invocation ledger

Detailed compiler output stays in ignored `.buildlog/sync-manual-builds-20261104/`.
This task preserves one log per build and small identity/receipt files, with no
duplicate SDK, checkout, APK variant or copied bundle.

| Time (+03:00) / invocation | Scope / purpose | Result / reason |
| --- | --- | --- |
| Initial `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, `git status`; focused guidance/source/build-receipt reads | Ownership, unfinished operations, build requirements and prior evidence | PASS expected source/branch; only original three cleanup changes. No test execution. Initial toolchain inventory included absent optional paths; corrected to existing paths from prior build context. |
| Static preflight via Python: approved config SHA-256 comparison, configured keystore `keytool -list -v -storepass:env TODORBIT_BUILD_STORE_PASSWORD` with captured output, SDK/JDK/cache existence | Verify existing build inputs without exposing credentials or signing in | PASS approved configuration and production certificate match prior provenance; API36/NDK/JDK21/SDK CMake3.22.1/existing Gradle cache present. Root Windows CMake cache absent, so compile is necessary. |
| Prior-source SHA-256 comparison and protected `baseline.json` | Reuse unchanged application tests; retain config/signing hashes for final preservation check | PASS all 23 fingerprints match. New read-only preflight; no tests repeated. |
| `tools/dev/prepare-windows-plugins.ps1` | Validate/reuse existing generated plugin junctions before the one Windows build | PASS four existing links verified; no dependency/version/system settings changed. |
| 2026-11-04T02:37:58.8362879+03:00 `.buildlog/sync-manual-builds-20261104/build-windows.ps1` -> `tools/build-windows-release.ps1` -> `flutter build windows --release --no-pub --dart-define-from-file=config/google-drive.json` | One Windows compile/link; existing approved OAuth parameters; native companion and CRT included by existing wrapper | PASS first attempt, Flutter compilation 199.7s. Exact version `1.0.19-beta.9+32`, config bytes restored. `windows-build.log`, `windows-result.json`. No app launched. |
| 2026-11-04T02:38:43.841620+03:00 Python Windows build identity/required-file summary | Consume the wrapper's existing OAuth/main/AOT hashes; ensure the complete runtime bundle is available | PASS enabled receipt, main/native/Flutter/data/CRT files present; `windows-artifact.json`. Necessary artifact handoff metadata, no recompilation or runtime test. |
| 2026-11-04T02:39:53+03:00 `python tools/dev/check-docs.py docs/SYNC_MANUAL_BUILDS.md docs/TEST_RUN_LEDGER.md docs/PROGRESS.md` | Validate only changed documentation routes (plus the helper's existing small feature catalog) | PASS zero errors; necessary new receipt/ledger links. Later artifact-result text adds no links; reuse this pass. |
| 2026-11-04T02:44:58.4228123+03:00 `.buildlog/sync-manual-builds-20261104/build-android.ps1` -> `tools/build-android.ps1 -Mode Release -Distribution github -GoogleDrive -JavaHome <existing JDK21> -AndroidSdk .buildlog/android-sdk -GradleUserHome <existing beta9 C cache>` | One universal ARM64/x64 APK; existing signing/cache; release-mode plugin regeneration | PASS first build. Existing wrapper native ELF/ZIP alignment gate passed. `android-build.log`, `android-result.json`. No AAB, splits, installation or live Drive. |
| 2026-11-04T02:44:58.4228123+03:00 `apksigner verify --verbose --print-certs <APK>`; `aapt dump badging <APK>`; SHA-256 / original config-signing hash comparison (captured in `record-android.py`) | Required artifact identity and safe-update metadata | PASS package `io.github.hik4.todorbit`, version `1.0.19-beta.9`, code 32, nondebuggable, ARM64/x64 and original production signer. Existing signing/OAuth source files preserved. `android-artifact.json`. New build identity check, no runtime test. |

Both builds completed on their first invocation. No further application checks
were run after successful artifact completion. Runtime and cloud acceptance
remain separate owner observations.

## Safe manual use

Windows: keep the entire `build/windows/x64/runner/Release` directory together,
including `data/`, Flutter/plugin/native DLLs, companion and staged CRT. Do not
copy only `Todorbit.exe` and do not replace an installed app. A prepared launcher
lives at `.buildlog/sync-manual-builds-20261104/Launch-Sync-Test.ps1`; it has not
been executed here. Run in a PowerShell window:

```powershell
& 'D:\AI_Projects\life_manager\.buildlog\sync-manual-builds-20261104\Launch-Sync-Test.ps1' -Scenario Standard
# Use -Scenario Private or -Scenario Legacy for separate retained test profiles.
```

The launcher sets child-only APPDATA/LOCALAPPDATA under
`%LOCALAPPDATA%\TodorbitManualSync\06b9ded\<Scenario>`, expects the database at
`Roaming\TodoPilot\life_manager.sqlite`, and seeds only new disposable settings
with widget startup/display off. It never resets an existing profile. Confirm
Settings > Data profile matches the printed path before connecting Google.
Environment isolation separates database, settings and profile-keyed credentials;
it is not a complete Windows security boundary. Release companion startup handling
can inspect per-user registry entries. For complete OS isolation, use a disposable
Windows user or existing Windows Sandbox and run the whole bundle there. Never
copy personal profiles/credentials into the test environment.

Android: this APK uses the existing ID `io.github.hik4.todorbit`, production signer
and code 32. It does **not** install alongside the same package in one Android user.
It can update a production beta-9 installation with the same certificate/code,
retaining app data; the actual installed version/signature have not been queried.
First export a recoverable backup and portable settings if using an existing app.
Prefer a spare/disposable device for a clean profile. On the chosen device, open
the APK and approve installation, or run `adb -s <chosen-device> install -r
"D:\AI_Projects\life_manager\build\app\outputs\flutter-apk\app-github-release.apk"`.
If Android reports a signing mismatch (for example an old debug-signed app) or a
higher installed version code, stop. Do not uninstall, clear data, use `-d`, or
bypass update checks to force installation. Android secondary-user app data can be
separate, but a same-package binary update may affect other users too; a separate
device gives stronger isolation. Installation/device behavior remains owner-tested.

**Cloud safety:** use dedicated disposable Google accounts. A fresh local profile
does not make an existing cloud workspace empty. Standard, new-private and legacy
acceptance should use separate appropriate accounts/workspaces. Never delete real
cloud application data to make a workspace empty. Both devices must run this new
implementation when testing protocol-2 workspaces. The legacy case must retain its
original recovery code and independent backups before any synchronization.

## Owner checklist (run safety-critical cases first)

For any failure, report platform/OS, scenario, app source `06b9ded`, phase/action,
exact visible error, whether both local/remote records remain, and whether retry
or restart changed the result. Use synthetic record names; omit passwords,
recovery codes, OAuth tokens, private logs and personal content.

| Priority / scenario | Steps and expected behavior | Report if it fails |
| --- | --- | --- |
| Critical: local data | Create different local tasks/events on each disposable profile before connecting. Connect and compare stable records on both devices. Initial setup merges, never replaces either database. | Which local/remote records disappeared, duplicated or changed unexpectedly; stop further edits if data is missing. |
| Critical: failed detection | Attempt setup offline or cancel/deny authorization. Reconnect later. No empty-cloud success or replacement workspace; existing records and pending edits remain. | Error/status shown and any unexpected upload/initialization. |
| Critical: legacy encryption | Join an existing backed-up disposable legacy encrypted workspace with its original recovery code. No Standard initialization; old records/settings/attachments remain accessible. | Whether a code was requested, verification error and any cloud/local changes; retain all credentials/history. |
| Critical: account boundary | On a paired disposable profile, reconnect with another disposable account. Account mismatch must stop exchange and preserve its pending work; sign-out must keep local data. | Selected account versus displayed binding and whether anything uploaded to the wrong account. |
| Standard 1: sign-in and empty cloud | With a dedicated empty account, press Connect Google Drive. Existing publisher OAuth opens without client IDs/JSON. Successful empty detection initializes Standard Sync without a Todorbit password. | OAuth error, unexpected credential/config prompt or misleading empty-cloud message. |
| Standard 2: second device | Connect the other disposable device to the same Standard account. No encryption credential prompt; pre-existing records merge. | Any extra password prompt, missing records or duplicate IDs. |
| Standard 3: Windows to Android | Create a task and fixed event on Windows, sync both devices. Compare title/date/notes/attachment bytes. | Missing fields, wrong dates/IDs or transfer direction. |
| Standard 4: Android to Windows | Edit task notes and event details on Android; sync both. Compatible changes arrive on Windows. | Missing/reverted values and sync status on each side. |
| Standard 5: preferences | Change a supported portable appearance/task/calendar preference, sync and reopen. It travels; window/widget position, OS permissions, credentials and other device-only settings remain local. | Setting name, expected versus observed value and affected device. |
| Standard 6: automatic sync | Enable Automatic Sync, keep both apps unlocked/active, edit, then allow polling/network time. Changes arrive without repeated setup. OS background timing remains opportunistic. | Elapsed time, foreground/locked/background state and pending/error status. |
| Standard 7: introduction | After first successful new Standard setup, dismiss the explanation. Re-sync/restart. It stays dismissed and does not appear as newly initialized for encrypted/joined workspaces. | When/where it repeats or appears prematurely. |
| Private 1: new private workspace | With a separate empty account and clean profile, choose Encryption options before ordinary connection. Enter a memorable passphrase, confirm it, save the recovery code and acknowledge it. Only successful cloud setup establishes private mode. | Validation/setup error, unexpected Standard setup, or success shown after failure. |
| Private 2: incorrect password | On another clean device/profile, connect that private account; choose passphrase and enter an incorrect value. Unlock fails without new uploads/replacement data; correct value then unlocks. | Whether failure created credentials/data or correct retry failed. |
| Private 3: recovery | On another clean disposable profile, use the saved recovery code instead. Same private records become available. | Recovery error, differing records or unexpected new workspace. |
| Private 4: restart | Restart/reopen an unlocked trusted profile after successful private setup. Its protected key permits routine sync without repeated passphrase prompts, subject to app lock/platform storage. | Prompt frequency, account/lock state and whether local data/credentials remain. |
| Critical: offline durability | Disconnect network, edit records, restart if desired, reconnect and sync. Local mutations stay durable/pending and later merge. | Lost edits, false success or unexpected fresh initialization. |
| Critical: conflicts | Edit the same field differently while offline on both devices. Sync, review both versions, defer/reopen and resolve. Meaningful conflicts remain reviewable; safe independent changes merge. | Missing candidate/version, premature overwrite or repeated resolved conflict. |
| Critical: backups | Make an independent backup, then restore only into another disposable profile. Verify records/settings and Before Restore retention; reconcile restored sync explicitly. | Missing backup/records, restoration error or automatic destructive exchange. |
| Scope limit | Inspect encryption controls on an established workspace. Conversion and passphrase changes remain explicitly unavailable and must not change cloud mode. | Any enabled conversion, success claim or cloud mutation. |

Optional after safety checks: light/dark, larger text, Windows keyboard/focus and
Android Back/IME, actual native background timing and physical-device behavior.
Build success and previous host tests do not establish these observations.

## Windows artifact outcome

**PASS first build**, executable:
`D:\AI_Projects\life_manager\build\windows\x64\runner\Release\Todorbit.exe`.
Keep its whole sibling directory, including native companion, Flutter/plugin DLLs,
`data/` and Microsoft-signed C++ runtime DLLs. The wrapper checked the enabled
OAuth receipt, main/AOT/config hashes and expected displayed version. This is a
new local build of `06b9ded`, despite retaining beta-9's displayed version/code.
No installer/ZIP/copy or installed-app replacement was made. Runtime/UI/Google
sign-in and real Sync remain owner acceptance, not inferred from compilation.

Executable SHA-256: `412431d7cf40e5066a883704012f9b6f4caef2ac4acd58e71c2331d9ac8b2fbf`.
AOT SHA-256: `3c89622129e9411eae608d650f498dd9b3d3ef8bc4ddd30f4dae72e861cf3aa7`.

## Runtime and remaining limits

No executable/APK was launched or installed, no device/emulator was created or
queried, and no Google authentication, cloud operation or manual Sync scenario
was executed. The prepared Windows launcher and actual installation/UI remain
unobserved. Build/signature/configuration evidence is distinct from runtime and
real synchronization acceptance. Mode conversion and cloud passphrase changes
remain unavailable by design in this implementation.

The Windows approved config is the same previously authorized publisher config;
Google Console registration/consent/current account eligibility are not inspectable
here. Android uses its production package/certificate and explicit existing Drive
enablement; successful authorization and shared Windows/Android appData access
still need the owner's real test. No client IDs/credential JSON are required from
ordinary users.

## Android artifact and final handoff

**PASS first build**, one APK:
`D:\AI_Projects\life_manager\build\app\outputs\flutter-apk\app-github-release.apk`.
Size: 52,726,591 bytes (50.3 MiB).
SHA-256: `7b805078f3956946f69307921e56d8e8884f6e3ae9e0a8c5548f47691f9cbb1b`.
Package `io.github.hik4.todorbit`, version `1.0.19-beta.9`, code 32; production
certificate and both ARM64/x64 ABIs verified, nondebuggable. Native ELF/APK
alignment passed through the existing build helper. Use this exact universal
APK; no new AAB or additional APK variants were built.

Both artifacts are ready for **owner manual acceptance**, with OAuth/real Sync
and actual startup/installation unverified. No test/analysis/emulator/integration/
benchmark/full-suite runs, application source changes, version changes, new
commits, push, installer or publication occurred. Existing prior tests were
reused only after source/config fingerprints matched. The SDK emitted an XML
version warning during Android compilation; it did not prevent the build or its
required artifact checks.

Final Git/documentation finishing at 2026-11-04T02:45:15+03:00: `git diff --check`,
`git status --short`, `git branch --show-current`, `git rev-parse HEAD` (recorded
in the handoff command). These verify whitespace/ownership after receipt edits;
they do not repeat application tests. Application HEAD remains `06b9ded`.
New task documentation is left uncommitted: this receipt, its test-ledger link
and the Progress checkpoint. The original three storage-cleanup changes remain
uncommitted and untouched. Ignored local logs/launch scripts/artifacts remain local.
