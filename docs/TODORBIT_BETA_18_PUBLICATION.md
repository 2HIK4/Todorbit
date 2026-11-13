# Todorbit 1.0.19-beta.18 Publication Receipt

- **Date**: 2026-11-14
- **Tag**: `v1.0.19-beta.18`
- **Branch**: `fix/calendar-interaction-regressions`
- **Version**: `1.0.19-beta.18+41` (Build 41, SQLite Schema 28)
- **Classification**: Experimental Pre-release (excluded from Stable channel)
- **Release URL**: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.18

## 1. Candidate Gate Verification

All mandatory checks verified against candidate source:
- Windows checks (Flutter analysis: 0 issues, test suites: 30/30 calendar passes, Release build, Inno Setup 7.1.0 compiler, CRT sidecars, native widget self-tests).
- Android validation (Flutter tests, release packaging, signature verification, 16 KiB native ELF alignment).
- Version synchronization across `pubspec.yaml`, `widget-shell-probe.csproj`, `CHANGELOG.md`, and release notes.

## 2. Published Packages and Hashes

All release assets staged and verified for GitHub Release `v1.0.19-beta.18`:

| File Name | Size (Bytes) | SHA-256 Checksum |
|---|---|---|
| `Todorbit-1.0.19-beta.18-win-x64-setup.exe` | 47,730,037 | `0fbdc50e92d67fce58ef3c22be91cfb5ed1199eac9d9658cf3ea1fbfd11cd9c9` |
| `Todorbit-1.0.19-beta.18-win-x64-setup.exe.sha256` | 109 | `e1d44161f32a4e9b98bcda494d4a821633ee8b8ee34685b8823547dcdd2a67e6` |
| `Todorbit-1.0.19-beta.18-win-x64-portable.zip` | 63,159,750 | `3698162969fe553c8eb2fc102e787269affaa9398b15fca9e02e8fa8b8db24ed` |
| `Todorbit-1.0.19-beta.18-win-x64-portable.zip.sha256` | 112 | `9c9b4e74e622ef87c2b64d3065a7d5eb4fe06d7e008433d7b85e0549c661bb9d` |
| `Todorbit-1.0.19-beta.18-SHA256SUMS.txt` | 221 | `d2d1fe2e4453303db8c2ff9a557b7cf7098485746b1fe7cc6ca87a0fb87b3fc4` |
| `Todorbit-1.0.19-beta.18-android-universal.apk` | 53,776,379 | `fc7702961ff74935c8cde741d79dda283e0d63e4e8a5d7f63a3667bb9d06e72a` |
| `Todorbit-1.0.19-beta.18-android-universal.apk.sha256` | 113 | `2d54406a4b12c5b3644917a264a7c06eb614a84d43615fa2f03f399db7335266` |
| `Todorbit-1.0.19-beta.18-android-update.json` | 421 | `9781147a07e4c5fe86ab08a1d31fc63d06d1b2a5a01b8a4c4d653b95e8d375d2` |
| `ANDROID-RELEASE-NOTES.md` | 3,103 | `3cb6aa7419e7a70802f2abd6eb0e5df73da03aec2967c318042ea9e2960fbb58` |
| `ANDROID-SHA256SUMS.txt` | 316 | `141d06b7d57df74c102c98d63c5aa68cc76ebfd50a9df7c94fafe0e4395df3d0` |

## 3. Package Verification Details

### Windows Packages
- **Inno Setup Installer**: Built via Inno Setup 7.1.0 x64. Installs per-user to standard local app directory preserving `%APPDATA%\TodoPilot` profile data and native registry keys. Includes Microsoft C++ runtime DLLs, native `.NET 10` widget companion (`TodorbitWidget.exe`), `sqlite3.dll`, and `NOTICES.Z`.
- **Portable ZIP**: Root-level executable bundle with embedded runtime and asset directory. Verified via `Assert-GoogleDriveReleaseBundle` and `Assert-TodorbitWindowsCrtBundle`.
- **Public Checksums**: `Todorbit-1.0.19-beta.18-SHA256SUMS.txt` contains SHA-256 hashes matching setup and portable binaries.
- **Google Drive Sync Status**: Intentionally disabled by design (`GOOGLE_DRIVE_ENABLED: false`) pending Google Cloud domain and branding verification. Desktop users utilize offline scheduling, native widgets, and local `.tdbackup` snapshot backup/restore.

### Android Universal APK
- **Signer**: Production release keystore verified via `tools/prepare-android-release.py` and `apksigner`.
- **Certificate SHA-256**: `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99` (matches Beta 16/17 production key continuity).
- **Application ID**: `io.github.hik4.todorbit`
- **Version Code**: `41` (strictly exceeds published floor 40).
- **ELF & ZIP Alignment**: Verified across 8 native libraries (arm64-v8a, x86_64) with 16 KiB page alignment.
- **Google Drive Sync Status**: Platform Google authentication enabled (`GOOGLE_DRIVE_ANDROID_ENABLED: true`); real Google account authentication and physical-device acceptance remain pending.
