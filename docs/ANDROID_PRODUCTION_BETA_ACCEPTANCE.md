# Production Android beta acceptance - 2026-10-31

This is an unpublished candidate checkpoint. It must not be read as a public
release receipt. Candidate name is `1.0.19-beta.1`, Android code 23; code 22 is
reserved for a private same-signer baseline.

## Owner acceptance update (2026-10-31)

The owner explicitly deferred Windows/Android Google Drive discovery/restore
acceptance until after the first Android beta is published and will personally
test a Windows-created backup on Android. This narrowly scoped acceptance changes
the earlier hold below: interoperability remains unverified but is an openly
disclosed beta limitation, not a prepublication blocker for this version. Begin
with disposable data and externally back up existing data before replacement.
Backup/restore is not automatic two-way synchronization. Windows testing remains
stopped. Real OAuth grant revocation/reauthorization subsequently passed as recorded
below. All signing, integrity, CI and data-safety
gates remain in force.

## Real OAuth revocation and reauthorization: passed (2026-10-31)

The owner confirmed the existing emulator account is dedicated/disposable and
authorized account-wide revocation. Native production code 23 refreshed Drive
history successfully before revocation. A closed profile export was retained.
The owner manually revoked Todorbit access in Google's third-party connections
settings; no credentials were requested or captured. The page-opening ADB action
was rejected by automatic approval review as blocked by policy, so the owner
opened the page and performed the account action manually.

Without locally disconnecting or restarting Todorbit, Refresh cloud backups then
reported **Session needs reconnecting** and **Google access expired or was revoked.
Reconnect Google Drive to authorize again.** The app remained open and local data
still matched the prior full transfer. Reconnect opened the Google account chooser
and fresh consent for Todorbit's own Drive configuration data. The owner manually
approved Continue on the disposable account. Todorbit reported Google Drive
connected, and refreshed history rediscovered both existing encrypted backups,
with the same dates, source/version, sizes and verification/compatibility labels.
No cloud delete/upload/restore operation was performed during this test.

Closed before/after comparison passed SQLite integrity and identical contents of
all 45 tables, stable IDs, the 41-byte managed attachment, all preceding backup
bytes, appearance, updater preferences and widget themes/filters/opacity. No
Todorbit crash/ANR event was recorded in this emulator session. The emulator was
stopped with data retained. Evidence stays private/ignored:
`oauth-before-profile.zip`, `oauth-after-profile.zip`,
`oauth-profile-comparison.json`, and the `oauth-*` UI captures. No OAuth bug was
found or fixed. This clears only the revocation hold; the newly discovered CI
safety failure below still blocks publication.

## New CI safety blocker discovered during final revalidation

Windows run `41176493080` on documentation-only `9f1d55e` failed
`test/android_widget_action_test.dart: stale completion cannot overwrite an edit`.
The expected `StateError` was not thrown; the asynchronous command completed.
The run had 425 passes, one failure and one deliberate skip. Following Windows
run `41176579454` on `6fac3c0` passed, including the full suite/Release/package
checks. Application source remains identical to the built APK and earlier CI.

A private local probe ran 100 rapid add/edit operations in an isolated in-memory
database: zero equal revisions and zero stale commands accepted. It does not
reproduce or explain the runner failure. The guard uses `updatedAt` equality;
clock/revision collision is a hypothesis, not a proven diagnosis. No production
code or assertions have been changed, and no retry is treated as resolving the
failure. This is a new data-safety publication blocker under the owner's explicit
instruction to stop if another mandatory gate cannot be satisfied. The existing
APK remains unpublished pending diagnosis and any required rebuild/reacceptance.

The existing draft ID `429762923` was refreshed to source `01215d7` and remains
unpublished at the [current draft URL](https://github.com/2HIK4/Todorbit/releases/tag/untagged-5d37eaf3644b4e6ac064).
Updated notes and their checksum disclose OAuth success, owner deferral and this
new hold; APK/update JSON are unchanged. All four remote asset sizes/digests match
local staged files. Existing public release identities and complete asset
inventories/digests/update timestamps match the pre-session snapshot. No public
beta tag exists. Earlier draft URL/target below is the historical staging receipt.

## Identity and source

- Owner-controlled keystore: `C:\Users\User\TodorbitSigning\todorbit-release.jks`,
  alias `todorbit`, package `io.github.hik4.todorbit`.
- Observed certificate SHA-1:
  `D0:AE:60:28:E4:CD:0C:1C:83:67:11:42:F6:0F:14:2D:A8:1D:AD:96`.
- Observed certificate SHA-256:
  `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
- JKS PrivateKeyEntry, RSA-4096, SHA256withRSA, valid from 2026-10-30 to
  2054-03-17. Private-key access and both expected fingerprints verified by an
  ignored local Java helper; no passwords or private-key bytes emitted.
- Owner confirms two independent encrypted, recovery-tested backups and
  production Android OAuth client registration in the existing Cloud project.
  These are owner attestations, not independent remote verification.
- Ignored local `android/key.properties` has access restricted to the current
  owner and SYSTEM. It is not tracked. No signing secrets are uploaded to CI.
- `ee38860` synchronizes candidate pubspec/native version metadata and changelog.
  `dcd6c7e` fixes Android CI/candidate setup to request `platform-tools` explicitly,
  avoiding the no-longer-served `tools` package. Existing Windows release tags and
  assets are untouched.

## Isolated acceptance boundaries

The owner authorized moving disposable acceptance to C: on 2026-10-31 after
freeing approximately 46 GiB. Use the new AVD **TodorbitProductionFast**, serial
**emulator-5584**, under
`C:\Users\User\AppData\Local\TodorbitReleaseAcceptance\avd\`.
The earlier USB-backed **TodorbitProductionBeta** remains stopped and preserved
beneath ignored `.buildlog/android-production-emulator/`.
The archived development AVD was shut down without uninstalling or wiping its
installation. No personal phone or Windows profile is a test target.

The public candidate must be the normal `lib/main.dart` Release build. The private
code-22 acceptance target substitutes discovery and loopback TLS transport only,
while using the real update page, downloader/checksum, native publisher/package
verification, FileProvider, permission and Android installer. It must never be
published. Its test-only entry point and fixture transport stay in ignored
`.buildlog/android-production-beta/`; they are not production endpoints.

A separately signed, non-debuggable test instrumentation APK is reserved for
read-only before/after profile exports. It requires explicit disposable mode,
emulator hardware, the approved production signer, version 22/23 and the synthetic
fixture marker. It does not open or write SQLite. Force-stop the test app before
export to obtain closed database/profile files. It is not a public release asset.

## Artifacts and regression

Production APK code 23 built from unchanged application source at `313b7a7`:
51,529,687 bytes, SHA-256
`02e97a8be84a79f11a165569aedb2e662bd41f66cc607c231531f14b8ddcc295`.
Observed package `io.github.hik4.todorbit`, name `1.0.19-beta.1`, minimum API 26,
target API 36, ARM64/x86-64, non-debuggable and APK v2 signature with the approved
production certificate. Eight native libraries passed ELF/applicable APK ZIP
alignment. Credential scan passed across 601 tracked files/archive entries.
Normal unpublished code-22 baseline has the same approved signer and SDK levels;
SHA-256 `eb23bce89dc62f481d7460e36a0cd80b9ae4c92f5e4164d7dda056d93f9e418f`.
The separate private code-22 fixture also built but is excluded from publication.

`220cec2` supports current aapt2 minimum-SDK labels without changing the API-26
policy; seven release-tool tests pass, including parsing the actual production
APK. `7224076` strengthens the tampered candidate fixture and requires a native
signature-integrity rejection. Neither changes application runtime source.

Local full analysis has passed. The full host test run had 425 passes, one
deliberate skip and one process-death checkpoint timeout; the focused unchanged
retry passed. Production builds use a process-local 3 GiB Gradle heap and two
workers. The exact-source CI passes are recorded below. Older Android run
`41132199207` was canceled after the newer corrected runs passed; it is not a
passing CI receipt.

Initial Android CI `41117606497` failed during SDK setup on the retired `tools`
package, before application checks. The first local Release build failed because
Flutter's saved system SDK selection overrode the requested workspace SDK and
selected an incomplete system NDK. A repository-scoped, ignored Gradle init file
now selects the complete workspace SDK; no system SDK was deleted and no global
Flutter preference was changed. These failures are not release passes.

## Current observed emulator acceptance (2026-10-31)

Android CI `41134977565` and Windows CI `41134977577` passed on `7224076`.
Android includes 57 focused host tests and two real-emulator integration tests;
the tampered newer APK is rejected specifically for signature integrity. Connected
Dart analysis of that integration test reports no errors after a cold-server
timeout and successful warm retry. Application source is unchanged since the APK.

The owner signed into the C: disposable emulator with an authorized test account.
Closed Play Store background work and disabled animations after reported slowness.
The private baseline seeded synthetic records/managed attachment/manual backup;
widget IDs 2 (dark/all tasks) and 3 (light/calendar) display the corresponding
task/event. Closed before-profile export and `production-baseline-22` emulator
snapshot are retained locally.

Actual same-production-signer code-22 to code-23 in-app update passed: download
cancel/retry, checksum/native verification, denied install-source permission,
permission grant, FileProvider/system installer, installer cancel with retained
verified APK, retry and approved installation. Play Protect scanned the APK and
reported "This app looks safe" before approval. No adb replacement install was
used for the candidate upgrade. Closed before/after profiles have all 45 database
tables identical, stable task/event/resource IDs, verified 41-byte managed
attachment, unchanged manual-backup bytes and appearance, retained update channel
and automatic-check preference, and identical widget settings. Launcher widget
IDs 2/3 remain registered and render the retained task/event with their chosen
themes. Widget completion and reopening both work through the normal candidate.

One private-baseline ANR was observed after reopening following widget setup and
snapshot capture: `No response to onStartJob`. It recovered after Wait. Google
services also reported ANRs earlier in this slow emulator; that does not establish
the cause of Todorbit's ANR. The normal candidate reopened and handled task,
widget and settings interactions without another observed Todorbit ANR so far.
The Play bundle build was initially stopped to free interactive resources, then
completed with one worker and a process-local 1.5 GiB Java heap. AAB is 48,102,481
bytes, SHA-256 `cdd0073eac72932bb500ab75d9d83ec520e69b0630af419a39204dc2bde5e9c7`.
Strict `prepare-android-release.py` passed both signatures/identities, SDK/ABIs,
native alignment, Play permission/provider separation, bundle 16 KiB configuration,
published-code floor, checksums and update metadata. APK/AAB credential scan passed
723 tracked files/archive entries. The AAB remains private validation material.

Real native Google account selection/authorization succeeded in the normal
production-signed code-23 app. The owner entered the test recovery passphrase only
in the emulator. Encrypted upload and remote-content verification passed. History
identifies the new full backup as Android `1.0.19-beta.1`, encrypted, verified and
compatible. Existing cloud backups were not restored, altered or deleted.

Wrong-passphrase rejection passed and no restore was recorded. The owner unlocked
the new test backup locally; preview showed the expected one task/event/category/
project and the exact disposable target. Confirmed replacement, closed/reopened,
and observed the successful-restore receipt and matching transfer fingerprint.
Closed profile comparison has all 45 tables identical, attachment bytes verified,
existing backups retained, and widget/update settings retained. A verified Before
Restore snapshot also has all 45 preceding database tables identical. Appearance
JSON gained explicit defaults; a Flutter acceptance check using the application's
actual preference reader confirms all effective settings match, keyed to both
captured file hashes. Quiet hours was inadvertently toggled while navigating and
restored to its original off value before final capture. No tokens, credentials
or real recovery passphrases were emitted.

The official API-35 x86-64 16 KiB emulator reports `PAGE_SIZE=16384`. The identical
code-23 candidate APK installed/launched, rendered Flutter, saved a task to SQLite,
retained it through force-stop/reopen, rendered a launcher task widget and handled
completion/reopening through the normal app. No Todorbit crash/ANR was recorded
in that guest during the checks. This is emulator runtime evidence, not physical
ARM64-device acceptance. Initial headless startup stalled while redirecting task
logs to the saturated USB drive; relaunching in the foreground with logs on C:
allowed prompt ADB and normal boot.

Windows Sandbox is already enabled. Prepared a bounded cross-platform test using
the existing published Windows `v1.0.18` portable package, verified against GitHub
SHA-256 and its sidecar. Only public package/scripts/synthetic IDs are mapped
read-only; bounded results have a separate mapping. Bootstrap refuses host
execution and inspects SQLite read-only. No repository, signing key or personal
profile is mapped. Sandbox-only prerequisite installation checks Microsoft's
Authenticode signature before execution. Windows UI-control tools fail with
`failed to write kernel assets` even after reset. The owner reported browser
sign-in returning while the app still showed Connect. The isolated schema-22
database remained empty; the requested sentinel was not confirmed. No restore was
attempted there. The owner explicitly declined further Windows app testing, so
the Sandbox was closed. No further Windows app testing is currently authorized.

Android offline local use passed with no active default network. An offline
authorization attempt preserved data and reported a generic canceled/denied error;
it did not accurately identify the network cause. Wi-Fi/mobile-data settings were
restored to their original enabled state. Native reconnect and cloud-history
refresh passed. Account-switch confirmation cancellation, local disconnect,
Google account-chooser cancellation and reconnect/history passed. During this
sequence GMS requested an update; followed the official Google Play update path
from 24.23.35 to 26.42.31 and repeated reconnect/history successfully. No security
prompt was bypassed and no account-wide Google grant was revoked. Both Android
test guests are stopped with data retained, and the temporary fixture server is
stopped.

At that initial checkpoint, Windows/Android Drive interoperability and real
account-wide grant revocation were unverified publication blockers. The owner
decision and completed revocation test above supersede those two holds; the new
CI safety blocker remains. Public discovery/download/install checks can only
follow publication and are not claimed. The
[unpublished draft](https://github.com/2HIK4/Todorbit/releases/tag/untagged-76b06409b4f941be9b7c)
is release ID `429762923`, target `9f1d55e`, proposed tag `v1.0.19-beta.1`.
GitHub API confirms `draft: true`, `prerelease: true`, no publication timestamp,
and all four asset sizes/SHA-256 digests match local files. No public beta tag
exists. Assets are the normal APK, Android update JSON, notes and a three-entry
checksum file; the private AAB and all test fixtures are excluded. The full local
preparation checksum separately includes the validated AAB.

Source review of the existing Windows updater shows Android APKs cannot be
selected as Windows packages. Stable excludes the beta. Pre-release may report
that a newer release has no verified Windows x64 package when no compatible newer
Windows asset exists. This existing behavior is not a public-download observation;
do not alter historical Windows releases to disguise it.

## Retained manual acceptance procedure

Android steps, including account-wide revocation, have observed evidence above.
Cross-platform steps remain unverified. This procedure is retained for future explicit
authorization; it is not a request to repeat the Windows test the owner stopped.
Do not capture or automate password/verification entry.

1. Open the production-signed app's **Settings > Backups and Google Drive >
   Connect Google Drive**. Select only the authorized test account and approve
   the existing `drive.appdata` scope. Confirm account identity locally.
2. Create synthetic tasks/events and a managed attachment, plus distinctive
   portable settings. Make an independently accessible local backup first.
3. Run **Back Up Now** with a test recovery passphrase retained locally by the
   owner. Verify upload completion and refresh the backup list. No passphrase or
   token belongs in chat, logs or screenshots.
4. Download and preview that encrypted backup. Compare content counts and source
   metadata. Restore only into disposable data, reopen, and compare stable IDs,
   contents, attachment bytes and portable settings. Verify Before Restore exists.
5. From a separately isolated Windows test profile using the same authorized
   account, verify actual cross-platform discovery/preview and a safe restore.
   Then verify Android can discover a Windows-created encrypted snapshot. Same
   project/account alone is not proof of appDataFolder interoperability.
6. Exercise cancellation, denied permission, offline local use,
   disconnect/reconnect and revoked grant; record results without credentials.
   For the remaining real-revocation case, use a dedicated authorized test account:
   remove Todorbit access on Google Account's third-party connections page, then
   verify reconnect is required and fresh authorization restores access without
   changing local data or cloud snapshots. Revocation can affect every Todorbit
   client using that Google account; do not perform it against personal access
   without the owner's explicit action.

The owner explicitly deferred cross-platform acceptance for this first beta;
OAuth revocation passed. The separate unresolved CI failure still blocks release.
See [full OAuth and recovery details](ANDROID_GOOGLE_DRIVE.md). Native 16 KiB
alignment and actual 16 KiB runtime acceptance must also be reported separately;
compilation/alignment is not a runtime observation.
