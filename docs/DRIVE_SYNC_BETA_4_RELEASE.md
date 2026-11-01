# Todorbit 1.0.19-beta.4 — Encrypted sync (Windows + Android)

Version `1.0.19-beta.4+27`, Android versionCode 27, database schema 26.

- Save locally and exchange encrypted incremental changes with paired Windows
  and Android devices through your existing Google Drive account.
- Use the top-right Sync icon or Settings > Sync for setup, pending work,
  recovery code, automatic exchange and consolidated conflict resolution.
- Merge compatible independent fields; keep meaningful competing values for
  explicit review. Resolve Later retains both versions through restart.
- Keep related records and attachment bytes safe when reviewing deletions.
- Use bounded background opportunities: constrained Android jobs and hidden
  Windows workers scheduled by the existing native companion. OS restrictions,
  network and authorization affect delivery. App lock requires foreground unlock.
- Restore snapshots with an accurate restart-required message. Reconciliation
  retains pre-restore queued history, uses a fresh device identity, and reviews
  older restored values against newer edits without deleting cloud-only records.
- Upgrade existing records to schema 26; preserve independent snapshot backup,
  device preferences, production signing and Windows installation identities.

On your first device, connect Google Drive in Settings > Sync and set up a new
workspace. Keep its recovery code privately. Connect the same account on the
second device and enter that code before setup. Keep a verified external backup.

Drive checks use mocks for this candidate. Real-account authorization, physical
ARM64/OEM background behavior and final physical UI acceptance are unobserved.
Google branding/public OAuth policy limitations from earlier experimental Drive
releases remain. No Google approval or compatibility with every account is claimed.

Download the ARM64 APK for most phones, x64 for a compatible emulator/device, or
the universal fallback. All APKs have code 27 and the established production
signer. Windows Setup and portable ZIP are separate choices. Verify the published
SHA-256 manifests before installing. Do not uninstall an app to bypass a signer
error; retain and verify its data recovery first.

[Pairing, data boundaries and short manual acceptance guide](https://github.com/2HIK4/Todorbit/blob/feature/drive-sync-recovery/docs/GOOGLE_DRIVE_SYNC.md).

[Publication receipt, exact checksums and acceptance limits](https://github.com/2HIK4/Todorbit/blob/feature/drive-sync-recovery/docs/DRIVE_SYNC_BETA_4_PUBLICATION.md).
