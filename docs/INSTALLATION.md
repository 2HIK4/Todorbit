# Install Todorbit

Open [GitHub Releases](https://github.com/2HIK4/Todorbit/releases) and choose
the experimental pre-release you want to install (currently
[Beta 30 (`v1.0.19-beta.30`)](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30)).
Its **Assets** list includes the available packages and SHA-256 checksums. Back
up your current profile before upgrading and keep any passphrase you need for
recovery.

| Platform | Choose this download |
| --- | --- |
| Windows x64 | `Todorbit-<version>-win-x64-setup.exe` or `Todorbit-<version>-win-x64-portable.zip` |
| Android 8.0+ on ARM64 or x86-64 | `Todorbit-<version>-android-universal.apk` (or ABI-specific `android-arm64.apk` / `android-x64.apk`) |

## Verify the download

Use the checksum for the exact filename you downloaded.
[Windows checksums](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.30/Todorbit-1.0.19-beta.30-SHA256SUMS.txt) · [Android checksums](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.30/ANDROID-SHA256SUMS.txt). The Android manifest also lists a Play build artifact for which GitHub provides no download.

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '<path-to-downloaded-file>'
```

On a system with `sha256sum`, use `sha256sum "<path-to-downloaded-file>"`.
Open the package only if its SHA-256 matches the release entry.

## Windows

Windows 11 is the primary test platform. Windows 10 acceptance is limited.
The Windows installer and portable ZIP are unsigned, so Windows SmartScreen may
show an unknown-publisher prompt. Both packages bundle the Flutter runtime and
the .NET 10 `TodorbitWidget.exe` companion; no SDKs are needed to run them.

### Installer

Run the verified setup file and follow the prompts. It installs for the
current user under `%LOCALAPPDATA%\Programs\Life Manager` by default and
creates a Start menu shortcut. The installed app stores data outside the
program directory in `%APPDATA%\TodoPilot`.

If Todorbit offers to import an older `%APPDATA%\Life Manager` profile, review
the source and destination first; canceling leaves old files in place. Keep
old profiles and backups until you verify your records in the upgraded
installation.

### Portable ZIP

Extract the complete ZIP and run `Todorbit.exe` inside the extracted folder.
Keep the folder intact, including `TodorbitWidget.exe`, DLLs, `data`, and
`PORTABLE-MODE`.

Portable data lives in `%APPDATA%\TodoPilot\portable-<location-id>`. Moving or
extracting the portable folder to a different path selects a distinct profile.
To upgrade or move a portable copy safely:

1. In the old copy, open **Settings > Privacy & Data** to inspect the active
   profile path and export a verified SQLite backup outside both folders.
2. Close Todorbit and the native widget. Keep the old folder as a rollback copy.
3. Extract the new ZIP. If extracting to a new path, import the verified
   backup through Todorbit's reviewed SQLite import flow (or replace files in
   the exact same path while preserving `PORTABLE-MODE`).
4. Verify your tasks, settings, and managed attachments before discarding old copies.

Show the native Tasks or Calendar desktop widget from the sidebar or **Settings > Widget**;
it can remain running in the tray after the main window closes. Right-click any
widget for quick view, opacity, layout lock, and theme controls.

## Android

1. Download and verify the production-signed APK from the release.
2. Open the APK. Grant your browser/file manager install permission if prompted
   (you can disable that permission afterward).
3. You can use Todorbit completely offline without signing in. Tasks and
   Calendar launcher widgets are available through your Android launcher, and
   other apps can share files directly into Todorbit's **Shared Inbox**.

Upgrades require an APK signed with the same publisher key. GitHub builds also
support in-app update checking/downloading with native `ApkVerifier` checks.
Always export a backup before uninstalling on Android, because uninstalling
removes app-private storage.

See [Platform support](PLATFORM_SUPPORT.md), [Privacy disclosure](PRIVACY.md),
and the [recorded Beta 30 platform limits](https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/DEFERRED_VERIFICATION.md).

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Windows shows an unknown publisher | Confirm the download came from the release assets and compare its SHA-256. Windows packages are unsigned. |
| The portable app opens with an empty list | Check the active data profile path. A different extraction folder selects a different profile. Reopen the original copy or restore from its verified backup. |
| Android refuses an update | Check the ABI, OS version, and signing lineage. Use the same publisher's build for an in-place update. Export a backup before considering uninstalling. |
| The updater offers no release | Check the Pre-release channel and compare with [GitHub Releases](https://github.com/2HIK4/Todorbit/releases). GitHub's Stable latest endpoint has no current release. |
| Restore does not show the expected records | Keep the existing and Before Restore copies. Verify the source file and current profile path before making another restore attempt. |

[Back to documentation](README.md)
