# Windows v1.0 release preparation

## Current status

The Windows Release bundle contains `life_manager.exe`,
`life_manager_widget.exe`, Flutter assets, `flutter_windows.dll`, and
`sqlite3.dll`. Inno Setup 7.1.0 compiled the installer at
`release/LifeManager-1.0.0-win-x64-setup.exe`. This is **not yet an approved
release candidate**: installed upgrade/uninstall and full manual acceptance
remain unverified. The manual acceptance matrix is in `ACCEPTANCE.md`.

## Build and install

Run `flutter build windows --release`. The bundle is under
`build/windows/x64/runner/Release`; keep the entire directory together. To
compile the per-user installer with Inno Setup 7, run
`./installer/build-installer.ps1` (or pass `-Compiler` with an `ISCC.exe` path).
The script verifies the Release executables and prints the installer SHA-256.
The current artifact's SHA-256 is
`51672ABA224E95762C9FBD82C7ED1671E0DE2C195F421348FF55961CF13C5FBC`.
It is unsigned; a signing certificate and distribution decision remain open.

The installer is configured to use `%LOCALAPPDATA%\Programs\Life Manager`, adds a
Start menu shortcut, and offers an optional desktop shortcut. It does not
touch the app's data directory, change sign-in preferences, or run a data
migration. Normal uninstall leaves personal data intact; it removes a widget
sign-in entry only when that entry points exactly to the uninstalled widget.
These behaviors still require an actual installer acceptance test.

## Upgrade and personal data

The database and settings are under `%APPDATA%\Life Manager`, outside the
installation directory. A database below schema v15 prompts for approval
before backup or migration. Approval creates and checks a `Before upgrade`
SQLite backup before opening the newer schema. If preparation fails, the
workspace remains closed. Do not use the personal database for development or
acceptance testing; use an isolated `APPDATA` and `LOCALAPPDATA` profile.

Backups are under `%APPDATA%\Life Manager\backups`. Managed attachments are
stored in SQLite and travel with its verified snapshots. External resource
paths and URLs remain references. The Backups dialog offers reviewed restore;
replacement occurs on the next launch after a `Before restore` snapshot.

## Privacy

App lock is disabled by default. When enabled, it uses a 6–12 digit PIN with
a random 16-byte salt, PBKDF2-HMAC-SHA256 (210,000 iterations), constant-time
comparison, and a persisted delay after repeated wrong attempts. The app and
native widget share a short-lived unlock session; a closed or crashed main app
causes the widget to lock. The widget hides task content and blocks task reads
and writes while locked. Locked notifications are suppressed by default; users
can choose a generic message without task details.

App lock is **UI privacy**, not SQLite encryption or protection against someone
who can access the Windows account's files. If the PIN is forgotten, close the
app and rename `%APPDATA%\Life Manager\privacy-settings.json`; this explicitly
resets only app lock and leaves the database intact. Windows Hello is not
implemented. Workstation lock behavior has not been verified as a distinct
signal; the optional focus/lifecycle setting locks on return when Flutter
receives a lifecycle interruption. Native privacy behavior still needs manual
acceptance on an isolated profile.

## Known limitations and troubleshooting

- Windows 10 compatibility is unverified. The native widget's Explorer child
  hosting relies on shell behavior that requires target-system testing.
- Reminder delivery requires the native companion running and Windows tray
  notification visibility; receipt is not guaranteed by the SQLite delivery
  ledger.
- If the widget cannot find the main app, keep both executables beside each
  other in the Release bundle or reinstall from a verified package.
- If a database upgrade is refused or fails, keep the database and its backups,
  inspect available disk space and file access, and retry only after resolving
  the cause. Never delete the database to resolve a startup error.
- For a failed reviewed restore, use the startup screen to cancel the pending
  request or retry after correcting the reported issue. `Before restore`
  backups are retained.

## Release notes

This checkpoint adds a shared optional app lock, a PIN management screen,
locked native widget behavior, a migration approval gate, corrected sidebar
Material behavior, Windows version metadata, and an Inno Setup project. All
other established productivity features remain on schema v15.
