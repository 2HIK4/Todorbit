# Android Google Drive configuration and portable recovery

Android Drive is enabled by default. Users select **Settings > Backups and
Google Drive > Connect Google Drive**, choose an account and authorize backups.
They never enter an OAuth client ID, secret or credentials JSON. Builds can
explicitly opt out with `-DisableGoogleDrive` on `tools/build-android.ps1`.
Enabling code does not register the publisher's certificate with Google.

## Publisher setup in the existing Cloud project

1. Open [Google Cloud Console](https://console.cloud.google.com/), select
   **Todorbit**, project ID **`todorbit`**. Existing Windows engineering/private
   acceptance records identify this project; confirm that the currently shipped
   Windows Desktop OAuth client is listed there. Do not create another project.
2. Under **APIs & Services > Library**, enable **Google Drive API**. No Firebase,
   backend server, Drive-wide access or additional API is needed.
3. Open **Google Auth Platform > Clients > Create client > Android**. Set package
   name to **`io.github.hik4.todorbit`**. Name this client clearly as development.
4. Register debug certificate SHA-1
   **`64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`**.
   Rechecked against this workstation's actual `~/.android/debug.keystore` on
   2026-10-29. SHA-256 is
   `9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73`.
   Other developer machines can have different keys. Recheck with:

   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE/.android/debug.keystore" -alias androiddebugkey
   # Standard development store password: android. Do not use it for production.
   ```

5. After selecting a durable production keystore, obtain its SHA-1 with
   `keytool -list -v -keystore <outside-repository-keystore> -alias <alias>`.
   Create another **Android** OAuth client in **the same project**, with the same
   package name and production SHA-1. Do not register only the debug certificate.
6. For future Play App Signing, also register the **app-signing SHA-1** shown in
   Play Console > Setup/App integrity. The upload key and Play-installed signer
   may differ. Each distinct package/certificate pair needs its own Android
   client in the existing project. No Android client secret is embedded.
7. Under **Branding**, retain Todorbit's existing support contact, homepage,
   privacy policy and authorized domain settings. Under **Data Access**, request
   only `https://www.googleapis.com/auth/drive.appdata` (non-sensitive scope).
   Android account identity comes from Drive `about.user`, without extra profile
   scopes. Under **Audience**, External is needed for ordinary Google accounts.
8. If the project is **Testing**, add each authorized test account under Test
   users before testing. External/In production broadens eligibility but is not
   proof of branding approval, Workspace-admin approval or universal access.
   Do not change the existing consent audience just to bypass an error.
9. Build the GitHub development APK with `tools/build-android.ps1`. `-GoogleDrive`
   remains accepted for old scripts but is no longer necessary. Install on an
   isolated test device signed with the certificate registered above.
10. Connect; verify that the correct email appears. Create an encrypted full
    backup with a recovery passphrase, refresh the list, download and preview it,
    restore only into a disposable profile, then verify IDs, contents, portable
    settings and the recoverable Before Restore snapshot. Exercise cancellation,
    denied permission, offline use, disconnect/reconnect, revoked grant and a
    second account. Disconnect before switching accounts; existing cloud backups
    remain with their original account. Local disconnect works offline and does
    not delete cloud objects or revoke the Google Account grant.

## Windows/Android discovery gate

Both adapters use the existing project, Drive `appDataFolder`,
`appProperties.application=todorbit`, `todorbit-<kind>-<UUID>.tdbackup` names,
format version 1, AES-256-GCM/recovery passphrase and schema 22. Android keeps only
profile-specific account identity in secure storage and access tokens in memory;
Google Play services reacquires tokens. It never imports Desktop refresh tokens.

The same Google account alone does **not** establish shared application identity.
Google's [app-data documentation](https://developers.google.com/workspace/drive/api/guides/appdata)
restricts this space to the originating application; its
[private metadata rules](https://developers.google.com/workspace/drive/api/guides/properties)
also require authenticated application access. Keeping the clients in the same
Cloud project is the intended application boundary, but real discovery across
these two registered clients is an acceptance gate, not an assumption.

With the same authorized test account on both platforms, upload a uniquely
identified Windows full backup, confirm its UUID/date/size is listed on Android,
decrypt/preview/restore, then upload an Android backup and repeat on Windows.
Record the Cloud project, OAuth client types/certificate fingerprints and file
IDs without recording tokens. If records are missing, first compare projects,
accounts and private properties. Do not widen Drive scopes, create a second
store, or migrate/delete backups as a fallback. Export a verified portable local
snapshot/settings package while the owner corrects registration. Real Drive
cross-client discovery has not yet been observed in this task.

## Contents and recovery

Full backups preserve the shared SQLite database: tasks, categories/projects,
events, sessions, recurrence, goals, habits/logs, time entries, views, templates,
and managed attachment bytes where stored by the existing repository. Linked
external file contents are not bundled. Windows paths require relinking.
Portable settings/themes use the existing versioned settings transfer, while
OAuth tokens, permissions, PIN policy, launcher widget IDs and platform navigation
remain local. The encrypted format is shared, not Android-specific.

Download verifies Drive size/MD5; upload additionally reads back and compares
SHA-256. Decryption verifies AEAD, the manifest/database digests and supported
format/schema before showing counts and replacement confirmation. Wrong
passphrases cannot modify active data. Restore stages a snapshot, replaces data
on reviewed restart and retains Before Restore through the existing recoverable
restore transaction. It does not merge devices or implement synchronization.
Keep the recovery passphrase outside Todorbit; no server can recover it.

## Safe manual transfer

Use **Back Up Now**, wait for verified upload, then **Refresh cloud backups** on
the other device and review the selected backup before confirming replacement.
The list shows source platform when recorded, timestamp, Todorbit version, size,
encryption and compatibility; decrypted preview supplies verified content counts.
Older packages without source metadata remain readable. Each upload creates a
new UUID/version; a successful transfer never deletes the previous cloud copy.

The page reports last successful full cloud backup and completed restore on this
device. Logical SQLite contents and portable settings are compared with that
checkpoint; a WAL checkpoint/VACUUM alone is not a local edit. Changes during
upload remain marked as local changes. A missing baseline is explicitly unknown.
Before restore, changed/unknown local state receives a warning. A service-level
profile guard prevents simultaneous cloud backup/preview/scheduling, and a pending
restore blocks uploads. Reviewed SQLite contents and preference files are checked
again before scheduling and on restart; a changed profile is preserved and the
restore is refused. SQLite replacement checks the database again under an exclusive
connection lock. Cancel the pending restore in startup recovery and review again.
Before Restore is retained even when a late edit prevents replacement. Successful
restore is recorded only after the replaced database has opened successfully.

These are conservative snapshot safeguards, not per-record synchronization or a
guarantee that the other device has no offline edits. Portable preference files
can also contain local metadata, so an unrelated preference-file write can require
another review. Review both devices and back up local work before replacing it.

Google authorization uses the
[official AuthorizationClient flow](https://developer.android.com/identity/authorization).
Missing/outdated Play services leaves local backups and offline productivity
available. Real authorization, consent and cross-device cloud restoration remain
unverified until the owner completes the setup and authorized account checks.
