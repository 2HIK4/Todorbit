# Todorbit 1.0.19-beta.17 Publication Receipt

- **Date**: 2026-11-13
- **Tag**: `v1.0.19-beta.17`
- **Branch**: `fix/calendar-interaction-regressions`
- **Version**: `1.0.19-beta.17+40` (Build 40, SQLite Schema 28)
- **Classification**: Experimental Pre-release (excluded from Stable channel)
- **Release URL**: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.17

## 1. Candidate Gate Verification

Correction (2026-11-14): the recorded focused checks below did **not** satisfy all
mandatory gates. [Exact tag Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/43475207925)
failed: 866 passed, 8 failed, 9 skipped (seven pending midnight timers and one
concurrent WAL setup failure in the lease-test fixture). No published binaries
or tags were replaced. See the [independent review](INDEPENDENT_REVIEW_2026_11_14.md).

Previously recorded checks:
- Windows checks (Flutter analysis: 0 issues, test suite: 15/15 workspace passes, Release build, Inno Setup 7.1.0 compiler, CRT sidecars, native widget self-tests).
- Android validation (Flutter tests, release packaging, signature verification, 16 KiB native ELF alignment).
- Version synchronization across `pubspec.yaml`, `widget-shell-probe.csproj`, `CHANGELOG.md`, and release notes.

## 2. Published Packages and Hashes

All release assets staged and verified for GitHub Release `v1.0.19-beta.17`:

| File Name | Size (Bytes) | SHA-256 Checksum |
|---|---|---|
| `Todorbit-1.0.19-beta.17-win-x64-setup.exe` | 47,740,345 | `ca0b27e13270fe1f8de5797c43bfc74f0b2295cc3d33c51a5f576b5c2723889b` |
| `Todorbit-1.0.19-beta.17-win-x64-setup.exe.sha256` | 109 | `0a75f859f7125368a48b8b9816bb6e4b9f0be82bc1f0a1ea34524c96570188aa` |
| `Todorbit-1.0.19-beta.17-win-x64-portable.zip` | 63,158,969 | `430998c6562a090c0729be703415de43fc4a9dae3c8540954428a8e35b991879` |
| `Todorbit-1.0.19-beta.17-win-x64-portable.zip.sha256` | 112 | `e097cb07ae2522718105085e68364673cb691dc573b98c5ee23661be491ddfec` |
| `Todorbit-1.0.19-beta.17-SHA256SUMS.txt` | 221 | `9d55aa6199cf062db2899479b1836c2f5d817ce8c973a87679cf887cf46f483c` |
| `Todorbit-1.0.19-beta.17-android-universal.apk` | 53,776,379 | `07d97b9000ad96f475ac39a48d3ec6bd59650eb525190290fee213de8b875d16` |
| `Todorbit-1.0.19-beta.17-android-universal.apk.sha256` | 112 | `60b411956e1b6f00e998db4948a37f5979f187a5f6e80b8529b5c3d2cfcba6b8` |
| `Todorbit-1.0.19-beta.17-android-update.json` | 421 | `b2d1f8d96b4fe6090b4cd70c01937bf36d803a8b0b941b2884e2784a07042137` |
| `ANDROID-RELEASE-NOTES.md` | 4,496 | `1fdeaf0c37df6b53a84e43f2f35a751f1c05171beb042a1e697bb2f002f7f7fb` |
| `ANDROID-SHA256SUMS.txt` | 316 | `141d06b7d57df74c102c98d63c5aa68cc76ebfd50a9df7c94fafe0e4395df3d0` |

## 3. Package Verification Details

### Windows Packages
- **Inno Setup Installer**: Built via Inno Setup 7.1.0 x64. Installs per-user to standard local app directory preserving `%APPDATA%\TodoPilot` profile data and native registry keys. Includes Microsoft C++ runtime DLLs, native `.NET 8` widget companion (`TodorbitWidget.exe`), `sqlite3.dll`, and `NOTICES.Z`.
- **Portable ZIP**: Root-level executable bundle with embedded runtime and asset directory. Verified via `Assert-GoogleDriveReleaseBundle` and `Assert-TodorbitWindowsCrtBundle`.
- **Public Checksums**: `Todorbit-1.0.19-beta.17-SHA256SUMS.txt` contains SHA-256 hashes matching setup and portable binaries.
- **Google Drive Sync Status**: Intentionally disabled by design (`GOOGLE_DRIVE_ENABLED: false`) pending Google Cloud domain and branding verification. Desktop users utilize offline scheduling, native widgets, and local `.tdbackup` snapshot backup/restore.

### Android Universal APK
- **Signer**: Production release keystore verified via `tools/prepare-android-release.py` and `apksigner`.
- **Certificate SHA-256**: `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99` (matches Beta 16).
- **Application ID**: `io.github.hik4.todorbit`
- **Version Code**: `40` (exceeds published floor 39).
- **ELF & ZIP Alignment**: Verified across 8 native libraries (arm64-v8a, x86_64) with 16 KiB page alignment.
- **Google Drive Sync Status**: Platform Google authentication enabled (`GOOGLE_DRIVE_ANDROID_ENABLED: true`); real Google account authentication and physical-device acceptance remain pending.
