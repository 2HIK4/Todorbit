# Todorbit 1.0.19-beta.15 Publication Receipt

- **Date**: 2026-11-11
- **Tag**: `v1.0.19-beta.15`
- **Commit**: `931f71b`
- **Branch**: `feature/interactive-calendar`
- **Version**: `1.0.19-beta.15+38` (Build 38, SQLite Schema 28)
- **Classification**: Experimental Pre-release (excluded from Stable channel)
- **Release URL**: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.15

## 1. Remote CI Gate Verification

All mandatory remote checks ran and passed against tag `v1.0.19-beta.15` and source commit `931f71b`:

| Workflow | Run ID | Target | Duration | Status |
|---|---|---|---|---|
| **Windows checks** | [43042071223](https://github.com/2HIK4/Todorbit/actions/runs/43042071223) | `v1.0.19-beta.15` | 19m26s | **SUCCESS** |
| **Android validation** | [43027408713](https://github.com/2HIK4/Todorbit/actions/runs/43027408713) | `feature/interactive-calendar` | 9m39s | **SUCCESS** |
| **Website preview checks** | [43042071045](https://github.com/2HIK4/Todorbit/actions/runs/43042071045) | `v1.0.19-beta.15` | 9s | **SUCCESS** |

Verified CI steps on Windows runner include:
- `actions/checkout@v4`
- Inno Setup 7.1.0 pinned installer verification
- `.NET 10` SDK setup
- Flutter 3.47.7 environment
- Dart static analysis (`dart analyze`) — 0 issues
- 853 automated Flutter tests passed (0 failed, 9 skipped)
- Public OAuth configuration audit and packaging gates
- Windows Release build (`Todorbit.exe`) with C++ runtime DLL packaging
- Native sync writer verification with disposable migrated profile
- Background sync barrier checks
- Native widget self-test in disposable profile
- Inno Setup compiler execution (`ISCC.exe`)
- Checksum validation

## 2. Published Packages and Hashes

All 9 release assets were staged, verified, and uploaded to GitHub Release `v1.0.19-beta.15`:

| File Name | Size (Bytes) | SHA-256 Checksum |
|---|---|---|
| `Todorbit-1.0.19-beta.15-win-x64-setup.exe` | 47,732,090 | `2fb24a494adcc0a9ce6267209e56dfa8246d4220cc9d0d040807e1db8760abb2` |
| `Todorbit-1.0.19-beta.15-win-x64-setup.exe.sha256` | 109 | `a5f4f89d3fa6e3ffbf792ae49e7b2355417ae417932d007c58ee16c4fa20c027` |
| `Todorbit-1.0.19-beta.15-win-x64-portable.zip` | 63,150,423 | `a7bf2ad18e291ae4625ccf6a76b9f06438df83c7b344d4b08ac53539c44997e6` |
| `Todorbit-1.0.19-beta.15-win-x64-portable.zip.sha256` | 112 | `369fc6da62a8fc272658b193504bf132470711fe9cbb7a61bb1640a3ddb4a0f8` |
| `Todorbit-1.0.19-beta.15-SHA256SUMS.txt` | 221 | `d2c8c44be2571c4c0bcbfefb532f808795da188eb22634e029413284f18d752f` |
| `Todorbit-1.0.19-beta.15-android-universal.apk` | 53,776,379 | `14be171a2a5a3236e0a45cecb91981956b1b38dac72cc286c29e039e44571a15` |
| `Todorbit-1.0.19-beta.15-android-update.json` | 421 | `34686c013f3d6661b34b9b5e1f2b74c1b3f3a7223a0ed061b3dc62dd0dde0f00` |
| `ANDROID-RELEASE-NOTES.md` | 3,052 | `3caa57f653f839ccb9d91b99a90abc29eb652e75d9351fc1a314b3ebc8600ef5` |
| `ANDROID-SHA256SUMS.txt` | 316 | `4d2e85e135544bc3d67f7ffaa564756c9a35e69e46a6fbbcf49cf94d3ec62b21` |

## 3. Package Verification Details

### Windows Packages
- **Inno Setup Installer**: Built via Inno Setup 7.1.0 x64. Installs per-user to standard local app directory preserving `%APPDATA%\TodoPilot` profile data and native registry keys. Includes Microsoft C++ runtime DLLs (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`), native `.NET 10` widget companion (`TodorbitWidget.exe`), `sqlite3.dll`, and `NOTICES.Z`.
- **Portable ZIP**: Root-level executable bundle with embedded runtime and asset directory. Verified via `Assert-GoogleDriveReleaseBundle` and `Assert-TodorbitWindowsCrtBundle`.
- **Public Checksums**: `Todorbit-1.0.19-beta.15-SHA256SUMS.txt` contains SHA-256 hashes matching both setup and portable binaries.

### Android Universal APK
- **Signer**: Production release keystore verified via `tools/prepare-android-release.py`.
- **Certificate SHA-256**: `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`
- **Application ID**: `io.github.hik4.todorbit`
- **Version Code**: `38`
- **Version Name**: `1.0.19-beta.15`
- **Native Architectures**: `arm64-v8a`, `x86_64` (8 verified native libraries with ELF alignment and 16 KiB page-size compatibility).
- **Update Manifest**: Staged `Todorbit-1.0.19-beta.15-android-update.json` for in-app OTA update service.

## 4. Safety & Channel Integrity

- **Personal Profile**: Production profile `%APPDATA%\TodoPilot` was completely untouched during build and packaging operations.
- **Stable Channel**: Release marked with `--prerelease`; Stable channel remains unaffected.
- **Previous Releases**: `v1.0.19-beta.14` and earlier releases and tags remain intact on GitHub.
