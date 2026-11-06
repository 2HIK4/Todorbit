# Private Drive-enabled Windows build — 2026-11-06

**Prepared and validated; not launched, installed or connected to Google.**
There were no account actions or real Drive requests. This is a private build
handoff, not a real OAuth/Sync acceptance pass or release authorization.

## Authorization and validated configuration

The owner reports Cloud inspection complete: existing Todorbit project, Drive
API enabled, non-sensitive `drive.appdata`, External/In production audience and
the Android debug package/SHA-1 registration matching the retained APK.
The owner confirms data-access verification is not required; branding remains
outstanding. These are owner-reported Console facts, not a new agent Console
inspection. Production consent configuration was not changed.

The owner explicitly approved reading one existing Desktop OAuth JSON locally
and using it for an isolated private build. Only that original file was read;
no other credential, token store or personal installation was inspected.

Local checks pass:

- Google downloaded **`installed` Desktop JSON**, not the three-field build
  format. The client identifier matches the explicitly approved filename and
  the project matches the owner-confirmed existing project.
- Expected Google authorization/token endpoints and Desktop loopback redirect
  entries are present. Runtime endpoints still come from fixed app source.
- Required client ID/Desktop parameter types and formats validate. No access
  token, refresh token or private-key fields were found in the checked structure.
- A new config with only `GOOGLE_DRIVE_ENABLED`, `GOOGLE_DRIVE_CLIENT_ID` and
  `GOOGLE_DRIVE_CLIENT_SECRET` was derived **outside Git** and accepted by the
  existing `-GoogleDriveConfigPath` validator. The original JSON is unchanged.
- New config/build directories have protected ACLs for the current Windows user,
  SYSTEM and Administrators. No credential values are printed, committed or
  retained in the sanitized handoff logs. A final scan of 126 diagnostic files
  found one MSBuild command-cache record containing encoded build defines; that
  private generated `.tlog` was sanitized before handoff. No values were emitted.

The required Desktop public-client parameter is compiled into this authorized
private app, as explained in the [OAuth audit](REAL_DRIVE_ACCEPTANCE_2026_11_06.md).
No downloaded credential JSON or user token is included in either package.
The private candidate has not been shared or published.

## Exact source and outputs

Source revision: `d8abbec9a707f3f5d185f1a9b0be8135df5a6dc2`.
Application version remains `1.0.19-beta.12+35`, schema 27. Installer numeric
registration version remains `1.0.19`. No source/version/OAuth-default edit was
required. A Git archive of that exact revision was built in an isolated directory;
240 handwritten app/native inputs still match the archive after compilation.
Offline dependency resolution preserved `pubspec.lock` byte-for-byte.

Private root:
`D:\AI_Projects\TodorbitPrivateBuilds\drive-enabled-20261106-ab9a4087`

Complete Release bundle:
`D:\AI_Projects\TodorbitPrivateBuilds\drive-enabled-20261106-ab9a4087\source\build\windows\x64\runner\Release`

Its executable is `Todorbit.exe`; the complete adjacent bundle must remain together.
The bundle is not a profile and was not launched. Packages are under the private
root's `packages` directory:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Todorbit-1.0.19-beta.12-schema27-drive-enabled-win-x64-portable.zip` | 63,199,128 | `11b3876a92223bc7d8ca295fa8b70032aae262231eca32f584e7c878c3612a5b` |
| `Todorbit-1.0.19-beta.12-schema27-drive-enabled-win-x64-setup.exe` | 47,777,015 | `a2ca2d4c1959c45ee26069f021657e3fcf9f521e8640da1461ffa7155912b16f` |

Each has a `.sha256` sidecar; `SHA256SUMS.txt` and `artifacts.json` retain exact
identities. Windows packages remain unsigned. Same-version earlier candidates
are distinct artifacts; identify this one by its private path, enabled flag and
hashes. Earlier build outputs and private packages were neither replaced nor
used as the enabled build.

## Build validation and evidence

The retained bundle/config receipt passes the strict enabled config/main/AOT
consistency guard. In-memory comparison confirms the approved OAuth fields are
actually present in AOT; values were not emitted. All three staged desktop CRT
DLLs pass the existing Microsoft-signature guard. The packaged companion's
isolated self-test passes. Portable ZIP CRC is valid, all 28 applicable fresh
Release-bundle files are byte-identical, and no credential JSON, session, database
or log files are packaged. The SDK's current native-assets manifest is present
under `data/flutter_assets`; the old checkout's stale root `native_assets.json`
was not copied into the clean bundle.

Schema-27 source/compiled named-checklist marker and unchanged application-input
fingerprints are verified. This is build/provenance evidence, not a new live app
database migration or Google connection test. Previous unchanged UI, causal
merge, recovery and two-profile tests are reused at their recorded boundaries.
No full Flutter suite, Android build, emulator boot or unrelated test was repeated.

Detailed non-secret audit records are under
`.buildlog/drive-enabled-20261106-ab9a4087/` in the original checkout. The private
root contains sanitized logs and exact step metadata. The approved JSON and
derived configuration contents remain outside Git; do not attach those files or
dump local build metadata/credential stores for support.

| Invocation / action | Result / reason |
| --- | --- |
| Git status, approved JSON local validation and config conversion | PASS; expected Desktop structure/client/project; three-field conversion required, original unchanged, strict validator accepts derived config |
| Restricted private directories, exact Git archive and offline dependency setup | New isolated build required because enabled config changes AOT. Initial offline setup and first build stopped on missing Windows plugin symlink support; no OS setting changed |
| Existing `tools/dev/prepare-windows-plugins.ps1` in the isolated copy | PASS four junctions. Repeated offline `pub get` then passes; lockfile unchanged |
| `tools/build-windows-release.ps1 -GoogleDriveConfigPath <approved derived outside-Git config>` in the isolated source | Compiler reports successful Windows Release build in 237.7s. The task log runner subsequently failed while printing Flutter's Unicode success mark; CRT files and receipt had completed. Runner changed to explicit UTF-8; no repeat compilation |
| Direct post-build `Assert-GoogleDriveReleaseBundle` with approved config plus `Assert-TodorbitWindowsCrtBundle` | PASS enabled config/main/AOT hashes and Microsoft-signed CRT. This independently verifies completed outputs despite the log-runner failure; no enabled-build success inferred from the earlier disabled package |
| Packaged `tools/dev/native-self-test.ps1` | PASS with new disposable child APPDATA/LOCALAPPDATA in the private source's ignored self-test root. Actual packaged binary checked; no personal profile or account |
| `tools/build-portable.ps1 -GoogleDriveConfigPath <derived config> -OutputDirectory <private packages>` | PASS; original OAuth/CRT/private-file/version/license guards retained |
| Existing Inno 7.1.0, `/DAppVersion=1.0.19 /O<private packages> /FTodorbit-1.0.19-win-x64-setup installer/life_manager.iss` | PASS, 55.890s; private setup compilation only. Installer execution and new enabled GUI/Google behavior NOT TESTED |
| Source/AOT checks, redacted-log value scan, package CRC/equality and SHA-256 | PASS; no known approved OAuth values in sanitized logs; package checksums recorded after final naming |
| Final generated diagnostic-cache scan | Checked 126 private log/command-cache files; sanitized one generated MSBuild `.tlog` containing encoded defines. No credential value emitted; generated cache is not a runtime/package component |
| Final preservation review | Original credential, tracked disabled config, protected storage docs, prior build/package hashes unchanged. No app/profile launch, account action, Drive access, push, tag or publication |

## Next steps requiring the owner

The OAuth build-configuration blocker is removed. Cloud settings are not being
requested again, and no change to branding/production consent is proposed.

1. Explicitly approve a **named disposable Google test account** and the first
   workspace mode. The account must have no personal Todorbit workspace. For
   both Standard and Private without resetting a workspace, approve separate
   fresh accounts, one per mode, shared by Windows/Android within each mode.
2. Make an isolated Windows user/VM and a healthy isolated Android device or
   Google Play emulator available. Use the retained debug APK whose registration
   the owner has confirmed. Do not install the private setup into the personal
   Windows installation or use a personal app profile for acceptance.
3. In a later authorized session, start this candidate only in that test identity,
   verify empty/resolved profiles, and complete normal Google account selection
   and consent on Windows and Android. Do not send passwords, tokens, Desktop
   parameters or Private recovery material in chat.
4. Resume the [A–L real exchange matrix](REAL_DRIVE_ACCEPTANCE_2026_11_06.md)
   against new synthetic records only. Standard is readable JSON; Private
   encrypts payloads. Preserve recovery snapshots and all existing workspaces.

**Real OAuth and cross-device Sync remain unverified.** This candidate is ready
for the owner's isolated sign-in step once the account/environment is approved;
it is not a real-service PASS or permission to release. All account/Drive
operations stopped at the boundary explicitly requested by the owner.
