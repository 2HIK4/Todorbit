# Todorbit v1.0.13 — Windows x64 pre-release

Google Drive backup is **enabled and experimental** in both Windows packages.
Connect through your system browser in Settings > Backups & Cloud. You do not
need a credentials JSON file, your own OAuth client or Google Cloud setup.

Google branding verification and full public OAuth policy compliance remain
unresolved. This release does not claim Google approval or compatibility with
every account. Google or Workspace policies, quotas, revocation and changes to
third-party access may prevent connection or continued use. Respect any Google
restriction; keep a verified local backup independently of cloud access.

## Changes

- Bundles the tested Desktop OAuth configuration, using only `drive.appdata`
  for Todorbit's hidden application-data folder. Release builds have no
  developer credentials-import control.
- Supports encrypted full-database and settings-only cloud snapshots, upload
  readback verification, explicit restore review, Before Restore snapshots
  and selective settings recovery. This is backup/restore, not live sync.
- Fixes interrupted database initialization: schema creation/upgrades and the
  version marker commit atomically. Only empty, compatible unfinished schemas
  can recover automatically; populated or incompatible files are preserved.
- Correctly validates user tables with SQLite-like names during recovery and
  rejects malformed v20/v21 backups missing the required reminder table.
- Handles initialization/controller-load errors within the startup screen.

Schema v21, existing profile paths, installation identity, settings, backups
and update-channel preferences are retained. Nothing silently completes or
reschedules planner tasks. A schema upgrade still requires approval and a
verified Before upgrade backup.

## Downloads and updates

Use the Windows x64 installer or extract the entire portable ZIP. Both are
**unsigned**. Compare the package with its `.sha256` sidecar or the included
`Todorbit-1.0.13-SHA256SUMS.txt` before running it; a checksum is not a publisher
signature. Keep portable updates at the same location to retain that profile.

From v1.0.12, select the **Pre-release** update channel and check for updates.
The Stable channel excludes this pre-release. This release does not change
your selected channel automatically.

## Validation and known limitations

Reuses final app source `8d667df`: 287 passing Flutter tests, clean analysis,
[successful Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40342429612),
enabled package checks, real Google encrypted backup/recovery and isolated
portable update/rollback. The published installer/ZIP are the exact enabled
packages from that engineering acceptance, rather than the disabled-config
CI artifacts. Only release artifact checks and public discovery/download
verification are added; the completed suite is not repeated.

Clean Windows-user/VM testing was explicitly skipped. Registered installer
upgrade/uninstall, physical backup/update dialogs, keyboard/DPI behavior and
SmartScreen trust remain unverified. Windows 11 is the main test platform;
Windows 10 acceptance is limited. Real multi-day grants, account switching,
quota exhaustion and interrupted Google transfers remain unmeasured beyond
the documented mocked cases.

Full cloud backups have a 50 MiB database limit. Linked external file contents
are excluded; no automatic cloud retention is applied. Lost backup passphrases
cannot be recovered. Local SQLite and recovery files are not encrypted by
Todorbit. Android/OneDrive sign-in and synchronization are not implemented.
