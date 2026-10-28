# Windows v1.0 release preparation

## Current status

As checked on 2026-10-27, the latest public release is the Windows x64
**v1.0.16 pre-release (1.0.16+17)**, tag/source `6e3b64b`.
[Publication receipt](TODORBIT_1_0_16_PUBLICATION.md) records the exact-source
340 passing tests/one opt-in skip, CI, asset hashes and updater checks; this is
historical evidence, not verification of subsequent changes. Source defaults
keep Drive disabled/empty; the published packages retain the approved enabled
configuration. Google branding/policy limitations remain unresolved.

Windows 11 is the primary test platform; Windows 10 acceptance is limited.
Packages are unsigned. Physical DPI/input, Explorer behavior and registered
installer execution remain unverified as detailed in that receipt. Never infer
these passed from compilation, self-tests or a previous release.

## Release sequence (only when explicitly requested)

1. Confirm a clean candidate branch and intended base. Inspect remote releases
   and tags (`gh api repos/2HIK4/Todorbit/releases` and `git ls-remote --tags origin`)
   before selecting the next semantic version/build number. Do not move tags.
2. Synchronize `pubspec.yaml` with `Version`, `FileVersion` and
   `InformationalVersion` in `experiments/widget-shell-probe/widget-shell-probe.csproj`.
   Update `CHANGELOG.md` and candidate release notes. Package scripts derive names
   from the source version; documentation-only maintenance needs no version bump.
3. Resolve dependencies and pass full analysis, serial Flutter tests, OAuth/config
   gates, native/Windows builds and packaged self-test. Commands and focused
   diagnostics are in [Testing](TESTING.md); [Windows CI](../.github/workflows/windows-ci.yml)
   must pass on the exact candidate source. Retain evidence, do not bypass gates.
4. Build the complete bundle and packages using the commands below. Preserve the
   reviewed Drive configuration/runner/AOT consistency receipt. A disabled CI
   artifact does not verify an enabled local artifact. Do not copy credentials
   from prior work or change tracked configuration without authorization; restore
   authorized temporary configuration after packaging. See [Drive readiness](GOOGLE_DRIVE_RELEASE_READINESS.md)
   and the latest publication receipt for configuration/acceptance limits.
5. Audit executable identity/version, full portable bundle equality/ZIP integrity,
   installer contents and private-file exclusions. Generate checksums only after
   final packaging; compare `Get-FileHash -Algorithm SHA256 <artifact>` with both
   sidecars and the manifest. Stale packages must fail, not be reused.
6. Stage a private draft with the exact source tag, notes and all five assets:
   setup EXE, portable ZIP, their two `.sha256` sidecars and versioned
   `SHA256SUMS.txt`. For example, after substituting version/source:
   `gh release create vX.Y.Z --draft --prerelease --target <full-source-sha> --notes-file docs/<candidate-notes>.md <five-explicit-asset-paths>`.
   Check draft source, classification, sizes and GitHub SHA-256 metadata. Do not
   mark a pre-release as latest Stable. Inspect assets before publication.
7. Complete applicable isolated upgrade/recovery and manual acceptance from
   [Updates](SOFTWARE_UPDATES.md), [widget checklist](windows-widget.md) and
   [clean Windows acceptance](WINDOWS_CLEAN_ACCEPTANCE.md). Preserve all data and
   profile identity. Keep unresolved tests explicit; historical skipped tests
   never become passes. Do not repeat prior release exceptions implicitly.
8. Only within explicit publication authorization, publish the reviewed draft
   (`gh release edit vX.Y.Z --draft=false`). Verify anonymous release/assets,
   all public hashes and production updater discovery/download from the previous
   version for installer and portable modes; Stable must exclude pre-releases.
   Record source, CI, artifacts, acceptance and limits in a publication receipt
   linked from [Progress](PROGRESS.md). Never execute setup on the owner's account.

## Build and install

For in-app update package naming, verification, installed/portable recovery,
and publishing requirements, see [Software updates](SOFTWARE_UPDATES.md).

Run `./tools/build-windows-release.ps1` to compile the reviewed public OAuth
configuration and create the package consistency receipt. The bundle is under
`build/windows/x64/runner/Release`; keep the entire directory together. To
compile the per-user installer with Inno Setup 7, run
`./installer/build-installer.ps1` (or pass `-Compiler` with an `ISCC.exe` path).
The script verifies the Release executables and prints the installer SHA-256.
Run `./tools/build-portable.ps1` for the portable ZIP. Both packages are
unsigned; a signing certificate and distribution decision remain open. Use
`./tools/write-release-checksums.ps1` for versioned checksums and updater sidecars.

The installer is configured to use `%LOCALAPPDATA%\Programs\Life Manager`, adds a
Start menu shortcut, and offers an optional desktop shortcut. It does not
touch the app's data directory or run a data migration. On an upgrade it updates
an existing, exact-match widget sign-in entry to the renamed executable;
it does not opt users in. Normal uninstall leaves personal data intact; it removes a widget
sign-in entry only when that entry points exactly to the uninstalled widget.
These behaviors still require an actual installer acceptance test.

## Upgrade and personal data

Fresh installer database and settings are under `%APPDATA%\TodoPilot`, outside the
installation directory. Portable copies use separate location-keyed folders
under that directory; moving a portable copy selects a new profile, so use
Export/Import to move data. A database below the running app's schema prompts for approval
before backup or migration. Approval creates and checks a `Before upgrade`
SQLite backup before opening the newer schema. If preparation fails, the
workspace remains closed. Do not use the personal database for development or
acceptance testing; use an isolated `APPDATA` and `LOCALAPPDATA` profile.

Fresh installer backups are under `%APPDATA%\TodoPilot\backups`; portable
backups are under their location-keyed profile. Managed attachments are
stored in SQLite and travel with its verified snapshots. External resource
paths and URLs remain references. The Backups dialog offers reviewed restore;
replacement occurs on the next launch after a `Before restore` snapshot.

## Privacy

See [privacy policy](PRIVACY.md) for the public disclosure.

App lock is disabled by default. When enabled, it uses a 6–12 digit PIN with
a random 16-byte salt, PBKDF2-HMAC-SHA256 (210,000 iterations), constant-time
comparison, and a persisted delay after repeated wrong attempts. The app and
native widget share a short-lived unlock session; a closed or crashed main app
causes the widget to lock. The widget hides task content and blocks task reads
and writes while locked. Locked notifications are suppressed by default; users
can choose a generic message without task details.

App lock is **UI privacy**, not SQLite encryption or protection against someone
who can access the Windows account's files. If the PIN is forgotten, close the
app and rename `privacy-settings.json` in the active profile shown by Settings > Data profile; this explicitly
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

Use [v1.0.16 notes](TODORBIT_1_0_16_RELEASE_NOTES.md) and its publication receipt
for that release. Older notes and acceptance reports retain their dated context;
they do not define the next release's version, assets or permission to publish.
