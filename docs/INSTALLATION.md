# Install Todorbit on Windows

Todorbit v1.0.16 is a free, MIT-licensed Windows x64 pre-release. Windows 11 is the main development and test platform; Windows 10 and installed upgrade/uninstall behavior still need direct acceptance. The packages are unsigned. Download from the [public GitHub release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.16), then compare SHA-256 with its published `SHA256SUMS.txt`.

## Installer

Run the matching `Todorbit-<version>-win-x64-setup.exe`. It installs for the current Windows user under `%LOCALAPPDATA%\Programs\Life Manager` (a stable legacy path), creates a Start menu shortcut, and optionally creates a desktop shortcut. Its stable installer AppId preserves upgrade identity. The app stores new installed-user data under `%APPDATA%\TodoPilot`, outside the program directory. The uninstaller is designed to leave data in place. These installed behaviors need direct verification in a disposable Windows user or VM before public release.

An unrelated `%APPDATA%\Life Manager` database is not opened automatically on a fresh install. If the app offers a legacy import, review it explicitly; canceling leaves the old database in place. An upgrade of a registered older TodoPilot install can retain the legacy profile through an installer marker. Before approving a schema upgrade, inspect the offered backup. Never remove an old profile until its data has been verified in the new installation.

## Portable ZIP

Extract `Todorbit-<version>-win-x64-portable.zip` completely, even when the destination path contains spaces. Launch `Todorbit.exe` inside the `Todorbit` folder. Keep the entire folder together, including `TodorbitWidget.exe`, DLLs, `data`, and `PORTABLE-MODE`.

Portable data is **not inside the extracted folder**. Each extraction location selects a distinct `%APPDATA%\TodoPilot\portable-<location-id>` profile. Reopening the same folder selects the same profile. Moving, renaming, or re-extracting to a different path selects a different profile; this can look like missing data. To upgrade a portable copy safely:

1. In the old copy, use Backups to export and keep a verified SQLite backup outside both application folders. Note the active profile path shown in Settings > Data profile.
2. Close the app and widget. Keep the old extracted folder and its profile as a rollback copy.
3. Extract the new ZIP to a new folder. Use the app's reviewed Import SQLite flow to bring in the export. Verify tasks, settings, themes, and attachments before discarding the old folder.
4. If replacing files **in the exact same folder**, preserve its path and `PORTABLE-MODE`, and keep the old folder copy until verification. The location-keyed data profile should remain selected; confirm it in Settings > Data profile.

External file links store paths, not file contents. Managed attachments are included in verified database exports.

## Widget and troubleshooting

The native widget starts from the app's Windows widget control or its own executable in the complete bundle. It may remain running after the main window closes. Right-click it for appearance and layout controls. Its desktop attachment depends on Explorer behavior and needs target-system testing.

If Todorbit shows an empty profile after moving a portable folder, inspect Settings > Data profile and reopen the original folder or use the reviewed import. If an upgrade or restore is refused, retain the database and backups; do not delete them to make the app start. App lock is UI privacy only and does not encrypt the SQLite file. See [release preparation](RELEASE.md) and [acceptance status](ACCEPTANCE.md).
