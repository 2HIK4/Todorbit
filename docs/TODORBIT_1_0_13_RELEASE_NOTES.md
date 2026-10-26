# Todorbit v1.0.13 — unpublished Windows x64 candidate

**Not published. Public Google Drive access is still gated.** This candidate
must not be advertised as generally available Google backup until the
[production and packaged acceptance gates](GOOGLE_DRIVE_RELEASE_READINESS.md)
pass. Connection is explicitly unavailable in the current candidate.

- Prepares ordinary-user Google Drive sign-in through bundled Desktop public
  application configuration, including the required token-exchange parameter.
  Release builds remove developer credentials-import controls. Users will
  not need a Google Cloud project or credentials JSON.
- Adds a consistent Release build wrapper, strict public-config validation,
  stale-package checks, CI packaging and checksums.
- Clarifies in-app data use, cloud deletion versus disconnect, passphrase
  recovery responsibility and the 50 MiB database limit.
- Retains encrypted full-database and settings-only snapshots, remote readback
  verification, explicit restore review, Before Restore recovery, and selective
  settings import. The backup format and migration mechanism are unchanged.

Limits: Windows x64; unsigned packages; snapshots rather than live two-way
sync; external linked file contents excluded; no automatic cloud retention;
lost recovery passphrases cannot be recovered. Android/OneDrive sign-in and
sync are not implemented. Local SQLite/recovery files are not encrypted.

Final evidence and outstanding owner actions belong in
`docs/GOOGLE_DRIVE_RELEASE_READINESS.md` and `docs/ACCEPTANCE.md`; no Google
approval, packaged public login, release URL or updater availability is claimed.
