# Testing and verification

Run commands from the repository root in PowerShell. Resolve dependencies with
`flutter pub get` after checkout/dependency changes. `--no-pub` below assumes that
has succeeded. Toolchain/profile setup lives in [Development](DEVELOPMENT.md).

## Choose checks by changed boundary

| Change | Focused checks and constraints |
| --- | --- |
| Markdown only | Validate changed links/paths and commands; review diff; `git diff --check`. No Flutter tests or builds. |
| Flutter UI | Relevant `test/*_test.dart`, targeted analysis, isolated rendered inspection; narrow size/larger text and theme variants when affected. Reuse [UI review](../.agents/skills/todorbit-ui-review/SKILL.md). |
| SQLite/domain | Relevant repository/domain tests plus migration, round-trip and stale-write cases for changed data. Start with `test/repository_test.dart`, `test/database_initialization_test.dart`, `test/migration_gate_test.dart` when changing schema/startup. Never use a personal database. |
| Settings/profile | Feature tests plus `test/profile_isolation_test.dart`, `test/settings_transfer_test.dart` or `test/appearance_preference_store_test.dart` when those boundaries change. Check malformed/newer formats and local vs portable fields. |
| Calendar/scheduling | `test/calendar_test.dart`, `test/calendar_improvements_test.dart`, `test/event_recurrence_test.dart`, `test/scheduling_engine_test.dart`, `test/scheduling_repository_test.dart` as affected. Native Calendar is a separate rendering path. |
| Widgets/IPC | `test/widget_configuration_test.dart`, `test/widget_edit_session_test.dart`, `test/widget_settings_page_test.dart`, `test/native_widget_service_test.dart` as affected; native Release/self-test for native changes. Follow [widget manual checks](windows-widget.md) for painting, input, shell, DPI and menus. |
| Backup/Drive | `test/backup_service_test.dart`, `test/import_export_test.dart`, `test/cloud/cloud_backup_test.dart`, `test/cloud/google_drive_test.dart` as affected. Include tampering, interrupted restore and settings portability. Real OAuth/recovery needs authorized isolated acceptance: [Drive guide](GOOGLE_DRIVE_BACKUP.md). |
| Updater/packaging | `test/software_update_service_test.dart`, `test/update_helper_launcher_test.dart`, `test/software_updates_page_test.dart`; relevant PowerShell harnesses below and [update recovery](SOFTWARE_UPDATES.md). |
| Integration/release | Full analysis and serial suite, relevant native/Windows builds, packaged self-test and all [release gates](RELEASE.md). Exact-source CI success is required for release; candidate CI is not publication approval. |

Select relevant files, not every file in a row. Widen after shared behavior changes,
an unexplained failure or at integration/release checkpoints. Re-run after new
changes invalidate prior evidence; do not blindly repeat passing gates.

## Commands

```powershell
# Substitute the actual changed Dart files; formatting check does not rewrite.
dart format --output=none --set-exit-if-changed lib/features/settings/widget_settings_page.dart
flutter analyze --no-pub lib/features/settings/widget_settings_page.dart
flutter test --no-pub test/widget_settings_page_test.dart
# Whole-project integration/release checks:
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release
./tools/build-windows-release.ps1
```

Unit and Flutter widget tests both use `flutter test`; there is no separate
`integration_test/` suite. `lib/driver_main.dart` is a debug-only live-inspection
entry point, not a release target. The opt-in real companion test is
`test/native_widget_launch_integration_test.dart`: it requires
`TODORBIT_NATIVE_SERVICE_EXE` pointing to an absolute companion path and fresh
`APPDATA`/`LOCALAPPDATA` beneath
`.buildlog/widget-customization/native-service-profile/`. Read its guard before
running; without the executable variable it skips deliberately.

For native checks, launch the built executable with `--self-test` **after**
configuring an isolated child-process environment as in Development. Source
build output is `experiments/widget-shell-probe/bin/Release/net10.0-windows/`;
distribution checks use `build/windows/x64/runner/Release/TodorbitWidget.exe`.
Actual-HWND `--lifecycle-self-test` supplements the self-test on an interactive
Windows desktop; neither establishes physical input/DPI acceptance.

Existing isolated harnesses (read parameters before running; require matching
Release binaries/packages):

```powershell
./tools/test-google-drive-release-config.ps1
./tools/test-single-instance.ps1
./tools/test-update-handoff.ps1
./tools/test-portable-update.ps1 -Package release/Todorbit-X.Y.Z-win-x64-portable.zip
./tools/test-portable-update.ps1 -Package release/Todorbit-X.Y.Z-win-x64-portable.zip -ExpectFailure
```

Replace `X.Y.Z` with the candidate version. Installer execution belongs in a
disposable Windows user/VM, not the owner's normal account. Redirecting APPDATA
alone does not isolate Windows Credential Manager or installer registration.

[Windows CI](../.github/workflows/windows-ci.yml) runs analysis, full serial
tests, OAuth/package gates, Release, portable, packaged native self-test,
installer and checksums; it retains an unpublished artifact. [Pages CI](../.github/workflows/pages.yml)
owns website deployment. Record passed, failed, skipped and manually unverified
checks separately, with source revision and profile context for release evidence.
