# Todorbit 1.0.19-beta.16 Publication Receipt

- **Date**: 2026-11-11
- **Tag**: `v1.0.19-beta.16`
- **Branch**: `fix/calendar-interaction-regressions`
- **Version**: `1.0.19-beta.16+39` (Build 39, SQLite Schema 28)
- **Classification**: Experimental Pre-release (excluded from Stable channel)
- **Release URL**: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.16

## 1. Remote CI Gate Verification

All mandatory remote checks run against tag `v1.0.19-beta.16` and the final source commit:
- Windows checks (Flutter analysis, tests, Release build, Inno Setup compiler, CRT sidecars, sync barriers, native widget self-tests).
- Android validation (Flutter tests, release packaging, native alignment).
- Website preview checks.

## 2. Published Packages and Hashes

All 9 release assets staged and verified for GitHub Release `v1.0.19-beta.16`:

| File Name | Size (Bytes) | SHA-256 Checksum |
|---|---|---|
| `Todorbit-1.0.19-beta.16-win-x64-setup.exe` | 47,735,614 | `92b3a764d6253940ea6d5f35cbabe2dd231e75813b0a43caf666e89d88832043` |
| `Todorbit-1.0.19-beta.16-win-x64-setup.exe.sha256` | 109 | `7f75143a5ba0c6488bc88220f86ee3921ea2f7d3e69aa7a627da061d36ea1f7b` |
| `Todorbit-1.0.19-beta.16-win-x64-portable.zip` | 63,155,800 | `a7e895c6b58d7fa058222807e51adedbbb1730e20b1cb0081cd126ab5a8ec31d` |
| `Todorbit-1.0.19-beta.16-win-x64-portable.zip.sha256` | 112 | `d120d938b80bbf23ca399ae5dd06249622d4f5cf9e10757a3e8e19c004944ec0` |
| `Todorbit-1.0.19-beta.16-SHA256SUMS.txt` | 221 | `cbca20e8b2691ce2504b7b2ce8f7d983c267c7e5df00435df2a92b235ee62cf9` |
| `Todorbit-1.0.19-beta.16-android-universal.apk` | 53,776,375 | `db477a597fe1708c47e24d3284730f81e2a76ac0c7f8970c7d26200adb013727` |
| `Todorbit-1.0.19-beta.16-android-update.json` | 421 | `e611456c2fda83187a6ff507f41e011f1151f04b3fc9a1265b5e9d46a318f377` |
| `ANDROID-RELEASE-NOTES.md` | 3,567 | `2781cc22d9c13bfd61f2ecd219e7e01f3cf13ddb0f3db4e882f43476fbfc7251` |
| `ANDROID-SHA256SUMS.txt` | 316 | `0937b4f5358044ce4a62118e6e58797f1f11fbce2848906473fa4eb43bfe0893` |

## 3. Package Verification Details

### Windows Packages
- **Inno Setup Installer**: Built via Inno Setup 7.1.0 x64. Installs per-user to standard local app directory preserving `%APPDATA%\TodoPilot` profile data and native registry keys. Includes Microsoft C++ runtime DLLs, native `.NET 10` widget companion (`TodorbitWidget.exe`), `sqlite3.dll`, and `NOTICES.Z`.
- **Portable ZIP**: Root-level executable bundle with embedded runtime and asset directory. Verified via `Assert-GoogleDriveReleaseBundle` and `Assert-TodorbitWindowsCrtBundle`.
- **Public Checksums**: `Todorbit-1.0.19-beta.16-SHA256SUMS.txt` contains SHA-256 hashes matching setup and portable binaries.

### Android Universal APK
- **Signer**: Production release keystore verified via `tools/prepare-android-release.py`.
- **Certificate SHA-256**: `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`
- **Application ID**: `io.github.hik4.todorbit`
- **Version Code**: `39`
- **ELF & ZIP Alignment**: Verified across 8 native libraries (arm64-v8a, x86_64) with 16 KiB page alignment.
