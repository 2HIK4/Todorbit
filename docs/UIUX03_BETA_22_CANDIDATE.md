# Todorbit UIUX-03 beta 22 candidate — 2026-11-15

Local candidate only. No push, remote draft/tag/upload or publication authorized or performed.

## Source and scope

- Reviewed implementation checkpoint: `5f30fd9b46264542a758ad6daf6f8fb12ce656d1`.
- Version checkpoint: `865468d995d3475dd20d993969e472baa2ca1590`.
- Candidate source: `41b6aff76be82ea8c9e0c34cebfb85ba255cc3f5`.
- Version: **1.0.19-beta.22+45**; Android versionCode 45; Windows PE 1.0.19.45.
- All 45 staged review paths matched the completed review manifest before commit.
  Three unrelated untracked documents remain byte-identical and excluded.
- The only later executable inputs changed are the synchronized pubspec/native
  version metadata. Windows version-checkpoint and candidate-source compiled
  inputs are identical. No dependency or separate alarm implementation changes.
- The Sandbox preparation guard required one schema-29 / 55-table entry. A focused
  regression failed before it, then all seven helper checks passed, including
  rejection of schema 30. This is release harness work, not a feature change.

## Evidence reuse and compatibility

Reuse [UIUX-03 review](UIUX03_CODEX_REVIEW_2026_11_15.md) and its source/assertion/
dependency manifest: 84 focused passing checks and clean affected-path analysis.
No full suite or broad audit was repeated. Schema-28 -> 29 gate/backup/migration,
reopen/idempotency, resource assignments/bytes, visibility/saved-view exchange and
scheduled restore already passed against unchanged product sources. Supported
schema-26/27/28 history remains readable; old clients fail closed on new schema-29
batches. Update all paired clients before new exchanges. Actual installed first-
launch migration approval and real two-client Drive acceptance remain distinct.

## Candidate preparation

All local preparation checks have passed. [Exact artifact/source identities](UIUX03_BETA_22_CANDIDATE_MANIFEST.json)
record the ten unpublished release assets. Raw logs remain under ignored
`.buildlog/uiux03-beta22/`; deliverables are in `release/beta22-candidate/`.
Android is production signed with certificate
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
Windows remains unsigned under the existing workflow; its three bundled CRT DLLs
retain verified Microsoft signatures. No signing identity was created or changed.

| Release-specific check | Evidence and result |
| --- | --- |
| Windows build/configuration/CRT | `./tools/build-windows-release.ps1`, 204.7s, PASS; enabled approved Desktop Drive configuration and exact AOT/runner receipt. |
| Packaged native gate | `./tools/dev/native-self-test.ps1 -Executable build/windows/x64/runner/Release/TodorbitWidget.exe`, PASS in isolated APPDATA/LOCALAPPDATA. |
| Installer / portable / checksums | Existing `installer/build-installer.ps1`, `tools/build-portable.ps1`, `tools/write-release-checksums.ps1` with explicit candidate output; PASS. Both PE versions are 1.0.19.45; product versions retain beta.22+45. |
| Windows artifact audit | `python .buildlog/uiux03-beta22/audit-windows.py`, PASS; ZIP CRC/safe paths/complete byte equality with the built bundle, normalized license/helper equality, enabled Drive receipt/AOT identity, private-file exclusions and exact sidecars/manifest. |
| Sandbox staging guard | One schema-29 regression failed before the guard update; `python -m unittest tools.test_windows_sandbox_prepare` then passed 7 checks, including Stable identity and unknown-schema rejection. |
| Android signed build | Established `tools/build-android.ps1 -Mode Release -Distribution github` with existing JDK 21, workspace SDK/cache and corrected ignored CMake path; retry PASS, 279.1s. Universal APK contains ARM64/x64; all eight ELF libraries and applicable ZIP entries pass 16-KiB alignment. Initial CMake failure retained. |
| Android preparation | `tools/prepare-android-release.py --apk ... --apk-only --version 1.0.19-beta.22 --version-code 45 --certificate-sha256 <approved fingerprint> --notes docs/UIUX03_BETA_22_RELEASE_NOTES.md --output release/beta22-candidate`; PASS. Production signer, non-debuggable package, ID, ABIs, minSdk 26, code 45 above all published floors, manifest and SHA-256 checked. No Play AAB requested/generated. |
| Updater contracts | `flutter test --no-pub --concurrency=1 .buildlog/uiux03-beta22/candidate_updater_test.dart`, 3 PASS against actual local artifact names/sizes/hashes: Windows installed/portable and Android both-ABI selection; Stable/draft exclusion, no same-version offer and tampered digest rejection. Official-response fixture only; no actual published discovery claimed. |
| Windows clean-user acceptance | Prepared standard Sandbox harness plus an ignored previous-version extension using the official-digest-verified Beta 21 installer. PASS: previous installed schema 28 and candidate portable schema 29 create/reopen with integrity OK; candidate native self-test; actual installer 21->22 registration/path/version; populated database bytes and sentinel retained; uninstall/reinstall preserves data. Only two package payloads, previous setup and harness mapped; no owner profile/OAuth data. Result: `windows-sandbox-result.json`; GUI/OAuth UNVERIFIED. Installer preservation does not prove the later first-start schema-29 approval journey. |
| Source / remote preservation | Compared reviewed code/assertion/dependency identities; only two version inputs differ. No separate alarm diff. All remote release objects/assets/digests/tags match the before snapshot. Stable untouched; no pushes/drafts/uploads/publication. |

Windows source was version checkpoint `865468d`; Android source was `41b6aff`.
Their compiled product inputs are byte-identical: the intervening commit changes
only the Sandbox staging guard/assertion. Subsequent receipt-only commits do not
invalidate package evidence. Gradle's workspace daemon was stopped before VM
acceptance, and only this task's Sandbox processes were closed after collecting
results. The three unrelated documents remain byte-identical and untracked.

### Primary artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `Todorbit-1.0.19-beta.22-android-universal.apk` | 54170139 | `01686c128c63f55b69aa03fe55768fa81f2d5016a200de78649301b7d13986ad` |
| `Todorbit-1.0.19-beta.22-win-x64-portable.zip` | 65347850 | `41282406ec54bb055a22593b2cfa3d4aabf2bec7e9b213404d1397713c130ca2` |
| `Todorbit-1.0.19-beta.22-win-x64-setup.exe` | 47943233 | `a8280080118db27b75226a262da9686056ae6a19c0be7a0c41cfa54d1f12b33d` |

The first Android build failed only at JNI CMake configuration: the selected
Visual Studio 18 CMake was 4.2.3, while this host's documented ignored override
requires 3.31.6. The retry selects existing Visual Studio 2022 CMake 3.31.6 via
PATH and ignored `android/local.properties`. No tracked product/toolchain setting
was changed. Existing future-Kotlin/SDK-XML warnings are retained in the log.

## Publication and acceptance gates

- Required exact-candidate Windows CI cannot run on this local-only commit until
  push is authorized. Historical CI is not a pass for this candidate.
- Candidate-specific Android 16-KiB runtime and any remaining device/physical/
  real-account gates remain open; ELF/ZIP alignment does not establish runtime.
- Actual built-in updater discovery/download/install requires approved publication.
  Local/draft files are deliberately excluded by production selectors.
- Stable and prior release/tag/assets must remain unchanged. No pre-release may
  be marked latest Stable; no release/tag/upload action has been taken.

## Exact manual updater acceptance

Use disposable profiles/devices with synthetic data. Keep existing verified backups.
Do not uninstall, clear app data, reset Sync or move a portable folder to work around failures.
Record candidate SHA-256 and previous installed version/package identity.

1. **Windows installed Beta 21 -> Beta 22:** select Pre-release in Software Updates,
   check for 1.0.19-beta.22, download and install through the built-in updater.
   Verify installed-mode handoff, exact existing install path/shortcuts, restart,
   schema-29 approval and a verified Before Upgrade backup. Confirm stable task/event
   IDs, managed attachment bytes, saved views, preferences and widget settings remain.
   Cancel the schema approval once: the existing database must remain untouched.
2. **Windows portable Beta 21 -> Beta 22:** repeat through the portable updater
   without moving its directory. Verify helper handoff, replacement/restart, the same
   location-keyed profile and retention of the same synthetic records/settings.
3. **Android production GitHub Beta 21/code44 -> Beta 22/code45:** choose the beta
   updater, download the APK, cancel installation once, retry, grant the OS install
   permission if requested, and install in place. Confirm package/certificate continuity,
   first-start schema approval/backup and retained records, preferences, launcher widget
   instances and permissions. No debug-key or uninstall/reinstall transition.
4. **Resources and Details:** drag a real Chrome address-bar URL and webpage hyperlink,
   then .url shortcuts, normal files, images and folders. Verify attach/link/cancel,
   normalized targets, portable copied bytes, subtask assignments and drag receiver
   restoration after closing an editor. Edit/save/reopen Details and return to the
   correct task/list. Check Custom View OR-within/AND-between filters and hidden scopes.
5. **Focus on both installed candidates:** Stopwatch start/pause/resume/stop;
   Countdown pause/reset/expiry; Pomodoro work -> short/long break -> ready work,
   skip/reset and stop. Breaks must add no work. Leave/return through the mini timer;
   short/long app restarts and device background/suspend must use explicit checkpoint
   recovery without counting powered-off time by default. Check recorded totals and
   subsecond/zero-entry display. Verify Android Back/IME/rotation and Windows input/DPI.
6. **Two updated schema-29 clients, dedicated test account:** exchange managed resources,
   assignments, saved Custom Views and visibility in both directions through existing
   Standard or Private Sync. Verify local file/folder references remain local; keep
   snapshot backup/restore as a separate journey. An older incompatible client must
   show update-required and retain local data/history, never silently apply new batches.
7. **Destructive controls:** cancel bulk Archive/Trash actions, retry a batch with a
   linked-record/timer blocker and confirm no partially deleted selection. Confirm
   reminder/alarm configuration and normal delivery were preserved after the update.

Actual beta-updater discovery/download/installation cannot be observed before
approved publication. Drafts/local files are deliberately not offered by production
updaters. Candidate-specific Android 16-KiB runtime, required exact-source CI and
unperformed physical/real-account acceptance remain separate release gates.
