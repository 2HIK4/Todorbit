# Google Drive backup and restore

Public release status: **BLOCKED — held at the production OAuth gate**.
The 2026-10-25 owner-configured debug acceptance below remains valid historical
evidence for the unchanged backup format and recovery flows. It does not prove
ordinary-user access from a distributed application.

The release candidate supports bundled public Desktop client configuration.
Ordinary users will only click **Connect Google Drive**, complete Google's
system-browser authorization, and return to Todorbit; they do not create Cloud
projects, enter IDs or import JSON. Release builds hide developer configuration
controls. Until production access and packaged acceptance pass, connection is
explicitly unavailable; local backup and settings JSON transfer remain usable.

## Production setup — publisher only

Follow the [public release gate and exact Google Cloud owner steps](GOOGLE_DRIVE_RELEASE_READINESS.md).
The reviewed `config/google-drive.json` currently has public access disabled and
empty Desktop client fields. Once the production project is ready, maintainers
supply its public client ID and Desktop client-secret parameter and build with:

```powershell
./tools/build-windows-release.ps1
./installer/build-installer.ps1
./tools/build-portable.ps1
```

The wrapper compiles the public fields with `--dart-define-from-file`. Both
packages use that same Release bundle and reject a stale/missing OAuth build
receipt. No source-project path or device-imported JSON is needed at runtime.
Never put user tokens, refresh grants, private keys, passphrases, or downloaded
credentials JSON into the configuration or distribution.

Google documents Desktop clients as **public clients**, unable to keep an
embedded client secret confidential. Its native-app token documentation lists
`client_secret` as optional, but the real test client required it for exchange;
the build now supplies it for both exchange and refresh. It is an application
parameter, not a security boundary. PKCE S256 and fresh state remain required.
Official references: [desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app),
[loopback support](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration),
[hidden application data](https://developers.google.com/workspace/drive/api/guides/appdata),
[Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth),
[production policy](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance).

The prepared [privacy disclosure](PRIVACY.md) describes data, deletion and
revocation. It still needs owner review/hosting on the verified app domain and
entry in Google Auth Platform. No Google project publishing or verification is
claimed. Android authorization, OneDrive and automatic synchronization remain
unimplemented.

## Developer-only isolated testing

For an authorized development client, run with `GOOGLE_DRIVE_ENABLED=true`, the
public client-ID define, and, if needed, the Desktop client-secret define via a
strictly public three-field define file outside Git. A debug build also retains
the existing secure Desktop JSON import for testing. Release builds cannot use
that import. It accepts only the installed client ID/optional parameter, ignores
arbitrary endpoints/tokens, validates a configured ID match, and requires
disconnection before changes. Use only disposable profiles and authorized
accounts; preserve the same intended project/client when testing recovery.

Windows authorization uses `http://127.0.0.1:<ephemeral-port>/oauth2callback`, a
fresh random state and S256 PKCE challenge, and the external system browser.
Only a matching GET callback completes the flow. Tokens persist in
profile-keyed Windows-protected storage, never backup payloads. Desktop clients
support variable loopback ports; no web JavaScript origin is needed.

Testing-mode projects restrict users and expire Drive/offline grants after seven
days. Production status, branding verification and account/admin policy are
separate checks. A developer/test-user login is not public-access proof.
See [clean packaged acceptance](GOOGLE_DRIVE_RELEASE_READINESS.md#required-packaged-acceptance--unverified).

## Contents and safeguards

- Full backup uses the existing BackupService `VACUUM INTO` snapshot, integrity
  and application-schema checks. It includes **all SQLite tables**: tasks,
  subtask/checklist relationships, recurrence series/occurrences and edit
  history, fixed events, event detail catalog, categories/projects, sessions,
  scheduling history, habits/goals and their history/links, saved views,
  templates, timers/time entries, archive/trash and notification records.
- The package also includes the existing shareable-settings allowlist:
  appearance/themes and widget palette/opacity, hotkey presets, calendar,
  sidebar order and task display. Settings-only backups use exactly this
  versioned JSON and have no database content. Selective import and named
  hotkey merging reuse SettingsTransferDialog.
- Task-resource references are database records. **External linked file contents
  are not bundled**; existing Windows paths may need relinking on another
  device. Todorbit does not currently manage a portable attachment store.
  The package itself adds no machine-specific path. Privacy/PIN policy,
  OAuth credentials, widget position/startup/layout-lock, update preferences
  and other device-local files are not packaged. The full SQLite snapshot
  does contain personal records and existing resource paths, inside encryption.
- Format 1 is platform-independent UTF-8 JSON. Its encrypted manifest has
  stable backup UUID, UTC creation time, actual executable version (or explicit
  Unknown), schema, source profile UUID, kind, database byte length/SHA-256,
  settings format and package version. Encrypted objects expose only backup
  UUID/kind/app version/schema/format/encryption status, creation time and size
  to Drive metadata. No key or recovery passphrase is uploaded.
- Encryption: random 16-byte salt, PBKDF2-HMAC-SHA256 with 600,000 iterations,
  256-bit key, AES-256-GCM with random 12-byte nonce and 16-byte tag. The fixed
  version/algorithm/work-factor header is authenticated as AAD. KDF and
  encryption/decryption run in an isolate. Each backup can use a different
  user-held passphrase (minimum 12 characters). **Losing the passphrase makes
  the backup unrecoverable.** It is never persisted. This is a new application
  format, not an externally audited encrypted archive standard.
- Resource limits: 50 MiB SQLite snapshot, 70 MiB clear package and 128 MiB
  encrypted object; settings JSON has the existing 256 KiB limit. Oversized
  snapshots fail explicitly and remain available as verified local backups.
  No compression/extraction paths are accepted.
- Windows token storage uses flutter_secure_storage's platform protection;
  records are keyed by a hash of the active profile's database path and stay
  outside portable backups. Cloud account identity is checked on connect and
  refresh. A different account requires explicit disconnect first. Download
  and delete reject stale objects from another connected account.
- Upload uses unique files, resumable 1 MiB chunks and bounded network waits.
  It confirms server size/MD5, downloads the stored object back, verifies
  SHA-256, then marks the object verified. Failed verification never reports
  success and never deletes a prior backup. Unverified finalized uploads may
  appear in history and can be reviewed/deleted; interrupted upload sessions
  may expire at Google. Automatic resume/retry after app exit is not provided.
- History is per connected account and includes both full and settings
  snapshots. No cloud retention or automatic deletion occurs. Deletion requires
  confirmation; disconnect removes only the device credential record and
  retains cloud files and the Google grant. Revoke the grant separately in
  [Google Account connections](https://myaccount.google.com/connections).

## Restore behavior

Download verifies server metadata, bounded size and MD5 before authenticated
decryption, manifest checks and database SHA-256 verification. Database import
uses the existing integrity/application-schema validation and safe managed
snapshot staging. Unsupported future database schemas and package versions are
rejected. Supported older database schemas migrate forward on startup.

Full restore previews source/target profiles, counts, app version and replaced
settings. Explicit confirmation schedules replacement; **scheduled is not
success**. Current personalization is exported next to the staged snapshot as
`manual-<timestamp>.sqlite.before-settings.json`; it can be imported selectively
through Import / Export Settings JSON. On next launch the native companion is
closed, the existing service creates a verified Before Restore database backup,
and SQLite's backup API transaction replaces the active profile's database.
After it opens/migrates, allowlisted personalization is applied and the existing
opened receipt is written. Failures are surfaced in startup recovery. The
original IDs and relationships remain intact. Automatic restart is not added:
the app explicitly asks users to close and reopen both Todorbit and its widget.

Settings-only restore displays categories and current conflicts, permits
selection and hotkey-preset merging, and requires confirmation before applying.
It does not schedule a database restore. Unrelated preferences and task/event
records are preserved. A full restore replaces records; it does not merge edits
made on different devices.

## Acceptance and evidence

Automated tests use fake token stores and mocked Drive HTTP. These verify
application behavior, not Google's actual authorization, storage or quota
enforcement. Record the exact final checks in PROGRESS.md.

Real Windows acceptance passed with valid configuration and an owner-signed-in
account. Full and settings uploads were remotely read back and verified. A
fresh profile restored selective calendar/hotkey categories with name merging
and an unchanged digest of every database table, then rejected a wrong full
backup passphrase without changing local data. After confirmed full restore
and an actual process close/reopen, all **44 SQLite tables** matched the uploaded
snapshot, including five tasks, three recurrence occurrences, a recurring
event, category/project, checklist/subtask links, habit, goal, session and saved
view. Theme, week start, hotkeys and widget opacity persisted. The Before Restore
database matched the previous target, a settings recovery JSON existed, and
the actual `opened` receipt had no replayable personalization payload.

Real secure credential persistence, forced refresh, disconnect/reconnect with
both snapshots retained, deletion confirmation/cancellation and selected
deletion passed. Only the two disposable snapshots created by the test were
deleted. Both isolated profiles' saved tokens and client configuration were
removed afterward; the owner's downloaded JSON outside the repository was
left untouched. No production Todorbit profile or installation was changed.

Network interruption, offline/quota errors, revoked access, OAuth cancellation,
account switching, tampering and future schema/version gates were verified
with mocks/isolated automated tests; real account switching, real quota failure,
physical DPI/resizing, Release GUI and Android remain **UNVERIFIED**. Several
Flutter Driver timing/serialization errors required retrying scoped interactions
and restarting a disposable driver process; these are not Google/app PASS
evidence. Final runtime inspection found no application errors.

Repeat this procedure for another OAuth deployment or platform:

1. Launch an isolated source profile. Create recurring tasks/events,
   subtasks/checklists, categories/projects, habits/goals, sessions and saved
   views; customize themes, hotkeys and calendar. Record IDs/table counts.
2. Cancel Google sign-in; retry and connect test account A. Verify displayed
   identity. Back up full data with a recovery passphrase; observe upload and
   remote verification completion. Restart and confirm session/history.
3. Back up selected settings separately. Test offline actions, token refresh,
   grant revocation and reconnect. Attempt account B without disconnect and
   confirm rejection. After explicit disconnect/reconnect B, verify separation.
4. Launch a fresh isolated profile with sentinel task/event/settings. Connect A,
   browse backups, download, try a wrong passphrase, then unlock correctly.
   Cancel replacement and verify sentinels remain. Confirm replacement, close
   both app and widget, reopen and check the actual opened receipt, source IDs,
   relationships, recurrence, settings, recovery snapshot and settings JSON.
5. Settings-only restore: preview/select one category, cancel once, then apply.
   Verify task/event rows and unrelated preferences are unchanged; test hotkey
   name conflicts with merge. Restart to confirm persistence.
6. Test network loss mid-upload/download, Drive quota denial, a corrupted
   object, unsupported future schema, a supported older schema, and explicit
   deletion of a selected disposable backup. Confirm previous backups/local
   data remain recoverable. Disconnect and verify cloud files remain after
   reconnecting. Do not use a production Todorbit profile.

Do not label Google Drive PASS until real sign-in, upload, download and restore
have all passed. The owner completed test-account consent in Google's browser.
Cloud Console ownership, OAuth publishing and production deployment remain
owner actions; no production Todorbit data or public release was changed.
