# Todorbit v1.0.19-beta.9 — Experimental Smart Sync fixes

An experimental Windows and Android prerelease containing the two confirmed
Smart Sync reliability fixes from the comprehensive local verification.

## Fixes

- A completed Drive upload can lose its reply before its readback metadata is
  written. Such objects no longer block authenticated history or first-device
  workspace recovery. AES-GCM authentication, account/workspace/batch identity,
  digest, schema and causal checks remain required. Outgoing acknowledgement
  still requires verified provider readback; no cloud objects are deleted.
- Socket and HTTP-client interruptions are classified as offline. Valid reviewed
  conflict decisions can be saved locally, survive restart, and upload later.
  Stale reviews, competing keys and invalid encrypted content still stop safely.

Schema 26, sync protocol 1, encryption/recovery and snapshot backup formats remain
unchanged. Android uses the existing production signing identity and code 32.
Sync and historical snapshot Backup remain separate.

## Experimental testing notice

**Real Google Drive synchronization has not yet been verified end to end.** Local
provider-contract and regression tests use synthetic HTTP/account fixtures; they
do not prove Google OAuth consent, live cloud exchange or every device/OS case.
Physical ARM64/OEM, Windows keyboard/DPI/assistive technology and comprehensive
background/mixed-client acceptance remain incomplete. Existing old clients retain
their known interrupted-upload behavior until updated.

Keep a verified external backup before testing. Initially use disposable profiles,
a disposable account and synthetic data. Retain the one-time recovery code securely
outside the device; Google sign-in cannot reconstruct a lost end-to-end key. Do not
post recovery codes, tokens, passwords or callback URLs in reports. No claim that
all data-loss risks have been eliminated is made.

## Installation

- Windows x64: run the Setup EXE or extract the complete portable ZIP. Keep the
  existing portable location when updating. Windows packages remain unsigned;
  compare SHA-256 with the published manifest/sidecar before execution. Installer
  registration/PE file versions retain the numeric core; the app reports beta 9+32.
- Android 8.0+: ARM64 for most phones, x64 for compatible x64 devices, or universal
  if unsure. Update a compatible production-signed install in place. Never uninstall
  to bypass a signing mismatch; preserve/export data and investigate first.
- This is a beta-channel prerelease, excluded from Stable. AABs are not GitHub
  installation assets. Published packages supply the approved public OAuth
  configuration; normal users do not enter developer credentials or client IDs.
  Google branding/account-policy acceptance remains unresolved.

## Two-device manual Smart Sync acceptance

1. Back up first. Use disposable data/account; connect Windows, then save its
   recovery code privately. Connect Android to the same account and authorize it
   once with that code. Confirm actual completed exchanges, not just sign-in.
2. Create/edit/complete/delete test tasks and create/edit/delete events in both
   directions. Check IDs/values and supported preferences, then restart both.
3. Offline, edit the same field differently on each device. Reconnect, inspect
   the conflict indicator/values, resolve individually and in bulk on either
   device, then sync/restart both. The old conflict should stay resolved; new
   divergence should still be detected.
4. Interrupt connectivity during exchange, save an offline decision and reopen.
   Pending work must remain, retries must converge without duplicates, and keys
   must not be requested again after normal restart. Record failures without
   exposing credentials or deleting history/backups to work around them.
