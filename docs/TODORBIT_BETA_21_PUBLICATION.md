# Beta 21 publication receipt — 2026-11-15

**PUBLISHED experimental prerelease:** [v1.0.19-beta.21](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.21)
Version `1.0.19-beta.21+44`, Android code 44, numeric Windows PE 1.0.19.44, schema 28; prerelease=true, draft=false, latest=false. Stable is unchanged.

## Root cause diagnosis

The user reported that after installing Todorbit 1.0.19-beta.20+43 on Windows:
1. Under *Settings > Backups & Cloud*, the UI displayed:
   "Google Drive is disconnected."
   "Google Drive is unavailable in this build. Use local backups or transfer settings below."
   Connect Google Drive button was disabled.
2. Under *Settings > Sync*, the UI displayed:
   "Sync failed."
   "Last synced Wed, Nov 11 · 7:24 PM."
   Connect Google Drive button was disabled.

### Diagnosis findings:
- The UI message was traced to `lib/features/settings/backups_cloud_page.dart` (line 571) and `lib/features/settings/sync_settings_page.dart` (line 509), triggered when `auth.canConnect` is `false`.
- In `GoogleDriveAuth`, `canConnect` is `enabled && clientId.isNotEmpty`.
- `enabled` is controlled at compile time by `publicConnectionEnabled = bool.fromEnvironment('GOOGLE_DRIVE_ENABLED', defaultValue: false)`.
- When `enabled` is false, `GoogleDriveAuth.load()` returns immediately (`if (!enabled) return;`), which prevented loading previously saved session tokens. As a result, existing authenticated sessions could not restore their account label, presenting as "Google Drive is disconnected" and "Sync failed" with disabled connect buttons.
- The root cause was build configuration & release packaging: in Beta 20, the Windows release was packaged using default `config/google-drive.json` (where `GOOGLE_DRIVE_ENABLED: false`) rather than the approved Desktop OAuth configuration (`D:\AI_Projects\Secrets\TodorbitPrivate-drive-enabled-20261106-ab9a4087\drive-build.json`).
- Furthermore, `Assert-GoogleDriveReleaseBundle` lacked an automated assertion enforcing `googleDriveEnabled: true` for release packages, allowing disabled distribution packages to be built without warning.

## Remediation

1. **Release Configuration Tooling**:
   - Updated `tools/google-drive-release-config.ps1` with `Resolve-GoogleDriveReleaseConfigPath` to automatically resolve approved Desktop OAuth configuration (`$env:TODORBIT_GOOGLE_DRIVE_CONFIG` or canonical `D:\AI_Projects\Secrets\TodorbitPrivate-drive-enabled-20261106-ab9a4087\drive-build.json`).
   - Added release gate assertion in `Assert-GoogleDriveReleaseBundle` requiring `googleDriveEnabled: true` for distribution builds unless explicitly overridden by `-AllowDisabledDrive`.
   - Updated `tools/build-windows-release.ps1`, `installer/build-installer.ps1`, and `tools/build-portable.ps1` to resolve configuration and enforce bundle validation.
   - Updated `tools/prepare-android-release.py` with build-tools / JDK path fallback and token-backed API querying.
2. **Architecture Documentation**:
   - Documented Desktop OAuth & Cloud Release Configuration Gate in `.agents/skills/todorbit-engineering-quality/references/cross-platform-architecture.md`.
3. **Data Safety**:
   - Local databases, sync journals, CAS concurrency tokens, and stored Google OAuth refresh tokens on disk remain completely intact. Updating to Beta 21 restores active Google Drive support without requiring database migrations or re-login.

## Assets and integrity

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [ANDROID-RELEASE-NOTES.md](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/ANDROID-RELEASE-NOTES.md) | 1447 | `196db62a2cb6879fd100f3fa79f907a2cc486603911efed9eb2736248923c71a` |
| [ANDROID-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/ANDROID-SHA256SUMS.txt) | 316 | `bcab0a5b1c943975b1c3f5b7827bfa429b90531be8d1a6fd25f7efbe3936bf73` |
| [Todorbit-1.0.19-beta.21-android-universal.apk](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-android-universal.apk) | 53776483 | `766dce9f74b38c060afc2d191e945e3e4c874876bddceca4188bb477849da7c6` |
| [Todorbit-1.0.19-beta.21-android-universal.apk.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-android-universal.apk.sha256) | 112 | `0521779cd5ad17db4aae5d03f72d0c3d3d2394cbb993a48eeb0b315eacd09f47` |
| [Todorbit-1.0.19-beta.21-android-update.json](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-android-update.json) | 421 | `c93ad8d2c2a0fa63f623bcece209a6c7a89867b48156f62824a8c9c60c40c498` |
| [Todorbit-1.0.19-beta.21-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-SHA256SUMS.txt) | 221 | `0f12954485c21c6ec57c4a84b778e2f6633e4751e164f33878997846b537b49a` |
| [Todorbit-1.0.19-beta.21-win-x64-portable.zip](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-win-x64-portable.zip) | 63392016 | `4969fb857ca714bdacd88716ec2445bda945045fcab490e97084ac378539fe55` |
| [Todorbit-1.0.19-beta.21-win-x64-portable.zip.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-win-x64-portable.zip.sha256) | 112 | `34835198a5d6ea50edcd79f57bdb541b831daf966be3298c0a271bc000e9ca4b` |
| [Todorbit-1.0.19-beta.21-win-x64-setup.exe](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-win-x64-setup.exe) | 47895073 | `a6ccd44fa8639e5e58573ca554fa9e9976790f05eddc8c4dde87e721af2ba97a` |
| [Todorbit-1.0.19-beta.21-win-x64-setup.exe.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.21/Todorbit-1.0.19-beta.21-win-x64-setup.exe.sha256) | 109 | `820b5f79c57d64d5a6e6ad0ca50db3ce8d4fe036a2302dd07a740ea1c25264b0` |

## Verification evidence

- **OAuth configuration tests**: 20 checks in `tools/test-google-drive-release-config.ps1` pass.
- **Cloud unit suites**: 23 tests in `google_drive_test.dart` and `backups_cloud_page_test.dart` pass.
- **Sync controller tests**: 2 tests in `sync_controller_test.dart` pass.
- **Windows CRT validation**: `tools/test-windows-crt.ps1` passes with Microsoft-signed runtime DLLs.
- **Windows build bundle metadata**: `build/windows/x64/runner/Release/data/todorbit-build.json` verified with `googleDriveEnabled: true`, desktop client ID, and AOT/main SHA-256 digests.
- **Android package integrity**: Production keystore certificate `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99` verified; all 8 native libraries 16 KiB load-segment aligned and APK ZIP page-aligned; non-debuggable; minSdk 26, targetSdk 36, versionCode 44 > 43 floor.
- **Review scope**: Independent self-review by Gemini under explicit user authorization; Codex usage is exhausted.
