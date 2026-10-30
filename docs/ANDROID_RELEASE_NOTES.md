# Todorbit Android beta 1 - unpublished draft

Proposed version: **1.0.19-beta.1 (23)**. Android 8.0+; ARM64 and x86-64.
This Android beta does not replace or modify the published Windows releases.

**Publication hold:** production signing identity/recovery, signed release
artifacts, exact-source CI, same-production-signer in-app upgrade acceptance and
real Google Drive authorization acceptance are pending. This file must be
finalized against the verified artifacts before publication. No production APK,
certificate fingerprint, checksum or public download is available yet.

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
- **Google Drive:** the native authorization start/cancel flow was observed on a
  development emulator. Production OAuth, authenticated encrypted backup/restore,
  and real Windows/Android cloud discovery have not passed acceptance. Production
  certificate registration in the existing Cloud project and authorized account
  testing remain required. Ordinary users must not supply credentials JSON.
- The implementation's host tests, disposable-emulator data workflow, native
  widget render tests and Windows Release checks are recorded in the source
  acceptance report. They do not establish the pending production signing or
  actual same-production-certificate installer upgrade.
- Physical-phone/OEM launcher resizing, reboot behavior and TalkBack breadth
  remain limited. Widget completion opens Todorbit; it is not a stopped-app
  background database writer.
- Native alignment checks do not establish runtime acceptance on a real 16 KiB
  page-size Android environment. That observation remains pending.
- No synchronization, telemetry, new cloud account system or Play publication
  is introduced. Local use remains available without Google Drive.

Before publishing, replace this draft testing status with exact candidate-source
results, production SHA-1/SHA-256 certificate fingerprints, APK SHA-256, actual
updater observations and remaining explicitly accepted limitations.
