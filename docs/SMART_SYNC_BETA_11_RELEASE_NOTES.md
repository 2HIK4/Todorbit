# Todorbit 1.0.19-beta.11 - Experimental Start New Sync

Experimental pre-release for Windows 10/11 x64 and Android API26+ ARM64/x64.
Version `1.0.19-beta.11+34`, Android code 34. Back up important data before upgrading.

## Improvements

- **Settings > Sync > Start New Sync** explicitly replaces old cloud sync using
  this device's current portable records, keeping local tasks, events, attachments,
  settings, stable IDs and retained journals/conflicts. No old encryption password
  is needed to start fresh. Existing legacy unlock/recovery remains available.
- A verified independent local snapshot precedes confirmation. Standard is the
  default; private setup creates a new key, passphrase and acknowledged recovery
  code. This does not recover inaccessible old encrypted/cloud-only records.
- The new seed uploads to an isolated workspace and is read back, decoded or
  decrypted and hash-checked before activation. Only then is selected retired
  cloud content deleted. Incomplete cleanup has a clear retry action.
- Durable protected operation state resumes interrupted setup on its original
  device. Generation markers detect stale sessions and concurrent replacements.
  Updated devices reconnect safely with a recovery snapshot and fresh operations
  from their current local records; old journals stay retained and do not replay.
- Specific errors and actions cover offline/API, sign-in/permission, encryption
  credentials, conflicts, unsupported/corrupt/missing data, account mismatch,
  storage quota, interrupted setup, stale devices and cleanup. Android also
  distinguishes canceled authorization and unavailable Google Play services.
- Shared Windows/Android settings, status details and scrollable confirmation
  support touch/keyboard and larger text without repeated error popups.

## Safety and limitations

**Start New Sync can permanently remove cloud-only information.** Confirm the
account, affected workspace and local recovery copy before acknowledging this.
All devices joining a replacement must update to beta11 or later and reconnect.
Unmodified older clients cannot obey a new barrier: their old writes remain
isolated and may recreate retired files. Permanent erasure of Drive revisions or
external copies is not promised. Non-content generation safety markers remain.
Two competing replacements stop exchange/cleanup rather than picking a winner;
a reviewed replacement can explicitly supersede both using current local data.
Unknown/future ownership and foreign unfinished staging block destructive setup.
Keep the original device's protected state and backup to resume an interruption.
Restored/quarantined profiles require their existing reconciliation first.

**Real Google Drive synchronization is NOT VERIFIED.** Targeted synthetic Drive,
disposable SQLite and UI tests pass; the owner will perform live acceptance.
No full Flutter suite, broad analysis, emulator or physical installation/upgrade
was run for this release, as explicitly requested. Prior evidence is reused only
for unchanged boundaries. Native interaction/IME, OS prompts/background timing,
real Google account eligibility and cross-client appData access remain unverified.
Existing-workspace encryption conversion and password changes remain unavailable.
Backups remain independent; no live Google operation occurred during development.

## Downloads and update

Windows packages remain unsigned. Choose Setup for an installed app or the whole
portable ZIP for portable use. Preserve the same Windows account and profile/path.
Android: one production-signed GitHub universal APK, package
`io.github.hik4.todorbit`, code 34, ARM64/x64. Same production certificate enables
in-place update of compatible GitHub installations; physical retention is untested.
No AAB or extra APK variants. Debug-signed/other-store installs may be incompatible.

Back up, then Settings > Software Updates > **Pre-release** > check > download >
install. Android may request permission to install from this source and system
confirmation; reopen afterward. Checks may be cached for about ten minutes.
Do not uninstall, clear data or force downgrade on signature/version errors.
Stable excludes this release. Checksums and update metadata accompany the assets.

After upgrading, use disposable records/accounts first: test legacy unlock,
Start New Sync without the old password, cancel/confirmation, local preservation,
Standard/private setup, interrupted upload/resume, cleanup retry and another
updated device reconnecting with offline edits. Full completion should leave no
selected retired content at the final scan, while safety markers remain.
