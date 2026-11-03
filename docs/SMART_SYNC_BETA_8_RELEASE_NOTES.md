# Todorbit v1.0.19-beta.8 — Experimental Smart Sync

An experimental Windows and Android pre-release for testing the Smart Sync
redesign. This is not a stable release.

## Changes

- A compact Google Drive Sync interface with account, status, last successful
  check and one primary action; recovery and account controls are advanced.
- Manual Sync continues Google sign-in through secure setup and exchange.
- Automatic checks at startup, appropriate foreground returns and periodically
  while active, plus debounced checks after committed local changes.
- Improved offline/retry handling and preservation of edits made during sync;
  metadata-only database notifications do not start redundant network jobs.
- Persistent counted conflict attention without automatic popups; individual
  and bulk decisions with confirmation. Offline decisions remain queued and
  propagate through the existing versioned history.
- One-time encrypted device authorization. Google sign-in alone cannot recover
  an end-to-end key; authorized devices retain access securely.

## Important testing notice

Smart Sync is experimental. Real Google Drive end-to-end synchronization remains
pending independent verification, and full Windows/Android acceptance testing is
incomplete. Passing builds and focused checks do not eliminate every data-loss
risk. Preserve a verified backup before experimenting, initially use disposable
profiles and synthetic data, and keep the one-time recovery code securely outside
the device. Losing every authorized key copy and the recovery code can make
encrypted data unrecoverable. Never post the code in logs or issue reports.

Sync and Backup remain separate. Sync includes confirmed deletions; a backup is
a historical recovery snapshot. Schema 26, sync protocol 1 and existing encrypted
formats remain compatible. Background timing depends on OS policy and account
access and is not continuous delivery.

## Installation

- Windows x64: use the Setup EXE for an installed copy or extract the complete
  portable ZIP. Keep the existing portable folder location when updating. Windows
  packages remain unsigned; verify the published SHA-256 before installation.
- Android 8.0+: choose ARM64 for most phones, x64 for compatible x64 devices, or
  universal when unsure. Production signing identity is retained; compatible
  production installs can update in place. Do not uninstall to bypass a signing
  mismatch: preserve/export data and investigate first.
- The beta channel may offer this release. Stable must exclude it. Private Play
  AABs are not GitHub installation assets.

On the first test device, press Sync, connect Google Drive and save the recovery
code privately. On the other, connect the same test account and enter that code
once. Test additions, edits, completion and deletion both ways; then make competing
offline edits, resolve on either device, sync and restart both to check convergence.
