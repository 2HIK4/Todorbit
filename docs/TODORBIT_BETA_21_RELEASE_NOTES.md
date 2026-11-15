# Todorbit 1.0.19-beta.21 — experimental

## Fixes

- Restore Google Drive and Smart Sync in Windows release builds by automatically incorporating the approved Desktop OAuth client configuration during release packaging.
- Add packaging integrity validation (`Assert-GoogleDriveReleaseBundle`) to guarantee future Windows releases cannot ship without active Google Drive configuration unless explicitly permitted for test builds.
- Resolve the regression in Beta 20 where Windows builds reported "Google Drive is unavailable in this build" and "Google Drive is disconnected", re-enabling the "Connect Google Drive" button.
- Retain existing local SQLite tables, sync journals, CAS tokens, stored credentials, and local backup/recovery without data loss.

## Testing and known limitations

This is an experimental prerelease for testing through Todorbit's **Pre-release** update channel. Open Todorbit → Check for updates → review/download the update → install it normally. On Android, approve the system installer and reopen Todorbit afterward. Uninstalling the existing app is not required.

Windows packages remain unsigned. Android uses the existing production signing identity. Data/profile/package/widget identities, database schema and Sync protocol are unchanged. Real Google OAuth and end-to-end cloud sync with multiple physical devices remain subject to documented acceptance limits. Stable and previous releases are unaffected.
