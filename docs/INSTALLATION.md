# Install Todorbit

Open [GitHub Releases](https://github.com/2HIK4/Todorbit/releases) and choose
the experimental pre-release you want to install. Its **Assets** list includes
the available packages and SHA-256 checksums. Back up your current profile
before upgrading and keep any passphrase you need for recovery.

| Platform | Choose this download |
| --- | --- |
| Windows x64 | `Todorbit-<version>-win-x64-setup.exe` or `Todorbit-<version>-win-x64-portable.zip` |
| Android 8.0+ on ARM64 or x86-64 | `Todorbit-<version>-android-universal.apk` |

## Verify the download

Use the checksum for the exact filename you downloaded. The release includes a
checksum list for Windows and `ANDROID-SHA256SUMS.txt` for Android. You can
check either platform's download on a computer before opening or copying it.

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '<path-to-downloaded-file>'
```

On a system with `sha256sum`, use `sha256sum "<path-to-downloaded-file>"`.
Open the package only if its SHA-256 matches the release entry. Get a fresh copy
from the release if the values differ.

## Windows

Windows 11 is the primary test platform. Windows 10 acceptance is limited.
The Windows installer and portable ZIP are unsigned, so Windows may show an
unknown-publisher warning. Both packages include the runtime files for
Todorbit. You can install them without installing Flutter or Visual Studio.

### Installer

Run the verified setup file and follow the prompts. It installs for the
current user under `%LOCALAPPDATA%\Programs\Life Manager` by default and
creates a Start menu shortcut. The installed app keeps its data outside the
program directory, normally in `%APPDATA%\TodoPilot`.

If Todorbit offers to import an older `%APPDATA%\Life Manager` profile, review
the source and destination first. Canceling leaves the old files in place.
An upgrade of a registered TodoPilot installation can retain its legacy profile
through an installer marker. Keep old profiles and their backups until you
verify your records in the upgraded installation.

### Portable ZIP

Extract the complete ZIP and run `Todorbit.exe` in the extracted Todorbit
folder. Keep the folder together, including `TodorbitWidget.exe`, the DLLs,
`data`, and `PORTABLE-MODE`.

Portable data lives in `%APPDATA%\TodoPilot\portable-<location-id>`. Moving,
renaming, or extracting the app to a different path selects a different
profile. To upgrade or move a portable copy:

1. In the old copy, open **Settings > Data profile** to note the current
   profile path. Use **Backups & Cloud** to export a verified SQLite backup
   outside both application folders. Export your supported settings separately
   if you want to transfer them.
2. Close Todorbit and the widget. Keep the old extracted folder and its profile
   available for recovery.
3. Extract the new ZIP. If you use a new path, import the verified backup
   through the app's reviewed SQLite import flow. If you replace files in
   the exact same folder, preserve its path and `PORTABLE-MODE` and confirm
   that the same profile opens.
4. Verify your tasks, settings, and managed attachments. External file links
   reference paths, so you may need to relink files you moved.

Show the native widget from Todorbit's sidebar. It can run while the main
window is closed and uses the complete bundle. Right-click it for appearance
and layout controls.

## Android

1. Download and verify the production-signed universal APK from the release.
2. Open the APK. If Android asks, grant the download source permission to
   install apps, then approve installation. You can turn that source
   permission off again afterward.
3. Open Todorbit. You can use it locally without signing in. The Tasks and
   Calendar home-screen widgets are available through the launcher.

For an upgrade, use a newer APK with the same app identity and production
signing key. GitHub builds also have an in-app updater with Android's install
approval. If Android reports a package conflict or signature mismatch, verify
an external backup before considering any uninstall. Uninstalling can remove
the Android app's private data, including its local database. Keep any
debug-signed development installation intact until you have verified how to
recover its records.

## If your records seem missing

Check the active profile before importing or restoring. For a moved Windows
portable copy, reopen the original extracted path or use the reviewed import
flow with its verified backup. A full restore replaces the selected local
database, so review the source and target and keep the Before Restore snapshot.
If a restore or upgrade is refused, keep the existing database and backups so
you can investigate or recover.

See the [platform matrix](PLATFORM_SUPPORT.md), [Sync guide](GOOGLE_DRIVE_SYNC.md),
and [backup guide](GOOGLE_DRIVE_BACKUP.md) for feature and recovery details.
