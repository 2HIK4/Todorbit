# Android beta phone installation and Windows backup acceptance

For the public pre-release `1.0.19-beta.1` (23), package `io.github.hik4.todorbit`.
Windows/Android Google Drive discovery
and restore remain unverified; the owner explicitly deferred this test until
after publication. Backup/restore replaces snapshots; it is not synchronization.

[Direct APK download](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.1/Todorbit-1.0.19-beta.1-android-universal.apk),
51,529,687 bytes. Verified SHA-256:

```text
eeb140b1ee574689c890bd52e2e078f547a3fc5533a5197c4d066eb8828c5d6b
```

1. Use Android 8.0 or later on ARM64 or x86-64. Open the official
   [beta release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.1)
   and download `Todorbit-1.0.19-beta.1-android-universal.apk` and
   `ANDROID-SHA256SUMS.txt`. A draft or missing page means publication has not
   occurred. Compare the APK SHA-256 with the published checksum; do not install
   the update JSON or an AAB.
2. If a debug-signed Todorbit installation already contains data, stop before
   replacing it. Export a full database snapshot and portable settings, or a
   verified encrypted full backup with its locally retained recovery passphrase.
   Copy these outside app-private storage to independently accessible storage.
   Verify preview and restoration on a disposable installation, including managed
   attachments. Copy linked external files separately. Only after recovery works
   may you deliberately uninstall the debug app yourself and install production.
   Uninstall removes private data; production cannot update a different signer.
3. Open the APK, allow your browser/file manager to install apps if Android asks,
   and approve installation. Follow Play Protect normally; do not bypass a warning.
   The production certificate SHA-256 must be
   `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
   Revoke installation-source permission afterward if desired. Restore your
   verified migration backup before proceeding; recreate local permissions,
   PIN and launcher widgets as needed.
4. In Todorbit open **Settings > Backups and Google Drive > Connect Google
   Drive**. Select the same Google account that owns the Windows backup. Approve
   the existing app-data backup permission. No credentials JSON is required.
   Stop and report security/consent errors; do not change Cloud projects or scopes.
5. Before testing any replacement, open **Local backup actions & history** under
   **Local Backups** and create a full snapshot. Export/copy it outside the app
   and verify it is independently readable. Export portable settings separately
   if needed. Do not rely solely on an app-private Before Restore copy.
6. Choose **Refresh cloud backups**, then **Restore from Google Drive**. Identify
   the Windows-created full backup by timestamp, version, size and source where
   recorded. Older backups may lack platform labels. If it is absent, stop and
   report the account/project/discovery problem. Do not delete, move or overwrite
   cloud backups or broaden permissions as a workaround.
7. Select that backup, enter its recovery passphrase locally if encrypted, and
   choose **Download and unlock**. Review the decrypted preview, compatibility,
   record counts and target profile. A wrong passphrase or unsupported package
   should leave current data unchanged. Never send the passphrase in a report.
8. Initially restore only into disposable data. Confirm replacement only after
   checking the target and external backup. Restoration is scheduled; fully close
   Todorbit and reopen to apply it. Check the actual successful-restore receipt
   in Backups and confirm a Before Restore snapshot exists. Cancel or stop if
   recovery reports an error; never clear app data as a fallback.
9. Compare tasks and completion/recurrence, events and dates, categories/projects,
   settings and managed attachments against the Windows snapshot. Open attachment
   contents. Windows linked paths need Android-accessible files and relinking;
   external file contents are not bundled. Device permissions, account tokens,
   PIN and launcher widget IDs remain local. Settings-only transfers are separate
   from a full database restore. Keep originals until all checks pass.
10. Report the app version/code, Android version/device, backup timestamp/source/
    version, expected and observed counts, exact non-secret error and whether a
    restore was scheduled or applied. Redact account names, paths and personal
    record contents. Never attach tokens, passphrases, credentials or a personal
    database to a public issue. For later betas choose **Settings > Software
    Updates > Pre-release > Check for Updates**; Stable excludes this beta.

See [release notes](ANDROID_RELEASE_NOTES.md) and
[observed acceptance](ANDROID_PRODUCTION_BETA_ACCEPTANCE.md) for current status.
