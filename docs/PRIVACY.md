# Todorbit privacy disclosure — release candidate

Prepared 2026-10-26 for owner review and hosting on the verified production
application domain. The owner-approved public website policy is now at
https://2hik4.github.io/Todorbit/privacy.html; its OAuth domain eligibility is
unresolved. This repository document is not evidence of Google approval. Public Google Drive login remains disabled
until the production deployment and packaged acceptance gates are satisfied.

## Local information

Todorbit keeps planner records in a local SQLite database. Local backups are
not encrypted by Todorbit. Its optional PIN hides the interface; it does not
encrypt local files. Todorbit does not add telemetry or a Todorbit account.
The optional software updater contacts GitHub for release information and
downloads; this is separate from Google backup.

## Optional Google Drive backup

Only after you connect your Google account and request a backup does Todorbit
upload a snapshot to that account's hidden Google Drive application-data
folder. It requests only `drive.appdata`, rather than access to your general
Drive files. Google receives encrypted backup bytes and metadata: backup ID,
kind, app/schema/format versions, encryption status, creation time and size.
Google processes these requests under its own policies.

Todorbit reads the connected account's permission identifier and, when
available, email address or display name to show the account and prevent
accidental account changes. Your browser handles Google sign-in; Todorbit
does not receive your Google password. Access and refresh tokens remain in
Windows-protected device storage, associated with the selected local profile.
They are not included in exported settings or backups.

A full backup contains all SQLite records and shareable personalization. That
can include private tasks, notes, event details, history, archived/deleted
records, and paths referencing external files. **External file contents are
not included.** Settings-only backup contains the selected supported settings
categories, without planner database records. Device-only privacy/PIN policy,
OAuth tokens and widget startup/position controls are excluded from the
additional settings payload. See [backup contents](GOOGLE_DRIVE_BACKUP.md).

Backups are encrypted on your device using AES-256-GCM and a key derived from
your recovery passphrase. Todorbit does not save or upload that passphrase
or derived key. Keep it separately: losing it makes the backup unrecoverable.
Downloaded backups are decrypted locally. Opening a full backup for review
creates an unencrypted local SQLite snapshot even if you cancel replacement.
That staged snapshot, approved database restores and local recovery copies
remain on the device separately from the encrypted cloud object.

The app transfers Google user data directly between your device and Google's
API. It does not send backup content or Google account data to a Todorbit
server, advertisers, or AI training services. The implementation uses Google
user data only to provide and protect the backup/restore feature. There is
no human access to cloud content through a Todorbit service.

## Retention, deletion and revocation

Cloud snapshots remain until you delete them; Todorbit does not automatically
prune them. In Settings > Backups & Cloud, connect the intended account, inspect
the backup history, and choose Delete for each unwanted snapshot. Confirming
deletion permanently removes that snapshot. Keep another recoverable copy.

Disconnect removes this profile's saved Google session from the device; it
keeps cloud snapshots and Google's authorization grant. Reconnect to manage
retained snapshots. You can separately revoke access through
[Google Account connections](https://myaccount.google.com/connections).
Drive's Settings > Manage apps can also manage hidden application data where
Google offers that control. Revoking access is not a verified substitute for
deleting snapshots. Local files and local recovery backups are separate and
remain on your device.

## Contact and publication

Product questions can be filed at
[Todorbit issues](https://github.com/2HIK4/Todorbit/issues); do not post private
records, tokens, passphrases or backup files. Security reporting follows
[SECURITY.md](../SECURITY.md). Before public OAuth deployment, the publisher
must select a monitored support/developer contact in Google Auth Platform,
host this reviewed disclosure and an accurate homepage on their verified
domain, and keep those URLs and the application's disclosures current.
