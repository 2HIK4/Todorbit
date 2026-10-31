# Todorbit Android beta 1 - unpublished draft

Proposed version: **1.0.19-beta.1 (23)**. Android 8.0+; ARM64 and x86-64.
This Android beta does not replace or modify the published Windows releases.

**Publication hold:** Windows/Android Drive interoperability and real grant-revocation
acceptance remain unverified. Windows app testing was stopped at the owner's request.
The production APK/AAB, artifact preparation, current application-source CI,
same-signer in-app upgrade/data preservation, Android encrypted Drive recovery and
16 KiB emulator runtime checks have passed. This file must be
finalized against the verified artifacts before publication. No public download
is available yet. The local production APK is 51,529,687 bytes; SHA-256:
`02e97a8be84a79f11a165569aedb2e662bd41f66cc607c231531f14b8ddcc295`.

The permanent RSA-4096 signing identity is established; the owner confirms two
independent encrypted backups passed recovery. Its verified public fingerprints are:

- SHA-1: `D0:AE:60:28:E4:CD:0C:1C:83:67:11:42:F6:0F:14:2D:A8:1D:AD:96`.
- SHA-256: `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.

## Included in the candidate source

- Shared local-first tasks, events, planning and encrypted snapshot recovery.
- Refined mobile navigation, settings, readable empty states and 48 dp controls.
- Responsive Tasks and Calendar home-screen widgets, with theme-aware colors,
  date context and distinct task/event actions.
- Widget completion/reopening through the app's existing revision and recurrence
  rules. This action opens the app and respects its lock and unsaved editors.
- Optional Google Drive encrypted snapshot backup, with account selection rather
  than user-supplied OAuth credentials. This is backup/restore, not synchronization.
- GitHub update discovery, release notes, cancelable APK download, checksum and
  installed-publisher verification, followed by Android's installation approval.

## Install after publication

1. Download `Todorbit-1.0.19-beta.1-android-universal.apk` from this official release.
   Compare its SHA-256 against `ANDROID-SHA256SUMS.txt` before opening it.
2. If Android asks, permit the download source to install apps, then approve
   installation. Installation is never silent. Revoke that source permission
   afterward if desired.
3. For subsequent beta updates, open **Settings > Software Updates**, choose
   **Pre-release**, and select **Check for Updates**. Stable excludes this beta.
   Review the offered version/notes, download, and approve Android's installer.

The Android update JSON asset is required for discovery; it is not an app to
install. An AAB is not an installable APK and is not included in the GitHub
installation assets. No Google Play release is being made.

## Development APK migration

Existing development APKs use the Android Debug certificate. A production signer
cannot update them in place. Do not uninstall until recovery is verified:

1. Export a verified full database snapshot and portable settings, or an encrypted
   full backup with its recovery passphrase. Copy it outside app-private storage.
2. Test preview/restore on a disposable installation and compare tasks, events,
   settings and managed attachments. Preserve external linked files separately.
3. Only after recovery succeeds, deliberately remove the debug app yourself,
   install the production APK, restore and compare the recovered data.
4. Reconfigure device-local PIN, permissions and launcher widgets, and reauthorize
   Google Drive. Keep the original backup until all checks are complete.

Android uninstall removes app-private data. The updater does not uninstall the
app to work around a certificate mismatch.

## Known limitations and testing status

- This is an Android beta; retain independently accessible backups.
- **Google Drive:** production native authorization, encrypted upload/remote
  verification, wrong-passphrase rejection, decrypted preview and restore/reopen
  passed with an authorized test account and synthetic data. Local offline use,
  authorization cancellation and local disconnect/reconnect were also observed.
  Windows/Android interoperability and account-wide grant revocation remain
  unverified. Offline authorization can show a generic canceled/denied message.
  Ordinary users must not supply credentials JSON.
- Google Drive requires current Google Play services. The disposable test device
  was updated through Google Play before the final reconnect/history checks.
- Production-signer build 22 to 23 passed real download cancel/retry, permission
  denial/grant, Android installer cancel/retry and approved update. All 45 SQLite
  tables, attachment bytes, backup, preferences and widget configurations survived.
  Task widget completion/reopening worked after updating. Android and Windows CI
  passed on the tested application source.
- Physical-phone/OEM launcher resizing, reboot behavior and TalkBack breadth
  remain limited. Widget completion opens Todorbit; it is not a stopped-app
  background database writer.
- Native ELF/APK ZIP alignment and runtime on Google's API-35 x86-64 16 KiB
  emulator passed, including SQLite save/reopen and widget actions. Physical
  ARM64 16 KiB devices remain unobserved.
- Existing Windows Pre-release update checks may report that the newer Android
  tag has no verified Windows x64 package. Windows never selects the Android APK;
  this beta supplies no Windows update.
- No synchronization, telemetry, new cloud account system or Play publication
  is introduced. Local use remains available without Google Drive.

Before publishing, complete the remaining mandatory acceptance gates and update
this draft status. After publication, verify the public APK download and normal
Android Pre-release discovery/installation; these checks have not run yet.
