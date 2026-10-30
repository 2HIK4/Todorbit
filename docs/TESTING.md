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

The optional helper preserves these commands and CI as the authority:

```powershell
# Preview only; explicit test groups are in tools/dev/features.json.
./tools/dev/verify.ps1 -Mode Feature -Feature drive -Plan
./tools/dev/verify.ps1 -Mode Quick -ChangedPaths lib/data/profile_fingerprint.dart -Tests test/cloud/cloud_transfer_history_test.dart
./tools/dev/verify.ps1 -Mode Feature -Feature android-updates
./tools/dev/verify.ps1 -Mode Full
# Full host checks plus Windows Release and isolated packaged companion self-test:
./tools/dev/verify.ps1 -Mode Full -Platform Windows
# Requires a disposable AVD: existing harness installs test builds into that app.
./tools/dev/verify.ps1 -Mode Feature -Feature android-updates -Platform Android -Device emulator-5580 -AndroidSdk '<SDK>' -JavaHome '<JDK 21>' -GradleUserHome '<existing cache>'
python tools/dev/check-docs.py
python -m unittest discover -s tools -p test_dev_verify.py
```

Quick checks formatting/analysis of explicit paths plus explicitly selected tests.
Feature uses a reviewed group and any extra `-ChangedPaths`/`-Tests`. Full checks
all source formatting/analysis, the complete serial host suite and release/helper
Python tests. `-Platform Android`, `Windows` or `All` adds the existing platform
harnesses/builds; `None` is the host-only default. Full with platform None does
not satisfy device/build release gates. Android's harness covers native negative
APK verification and mobile restore, not interactive system-installer approval.
Run that approval/cancellation sequence from [Android release](ANDROID_RELEASE.md)
separately. Logs, exit codes, revision/dirty flag and timings are retained under
`.buildlog/verify/`; failures stop later steps and return nonzero. Test groups are
starting points; add related tests when dependencies cross the listed boundary.

The helper never resolves packages, cleans caches or guesses affected tests.
Run `flutter pub get` when lockfile/dependencies change. CI's independent full
commands remain mandatory before publication. Host tests cannot establish real
Google authorization, OEM delivery or physical native input behavior.

The local Android harness refuses an installed version above its code-19 baseline.
Archive the disposable emulator profile first, then explicitly add
`-AllowDebugDowngrade` to reuse it, or select a fresh AVD. This installs the
same-source debug baseline with `adb install -r -d`; it never uninstalls data to
recover from an error. Its Flutter Drive runner retains the test installation.
This requires the explicit `--keep-app-running` flag: default Drive teardown also
uninstalls its app. Archive before deployment even when that flag is supplied.
Negative fixtures are never installed. CI's ephemeral Android runner is separate.

Android additions: `test/mobile_workspace_test.dart` checks compact/tablet,
text scaling, RTL/dark layout, task CRUD and unsaved Back protection;
`test/android_platform_test.dart` covers navigation preferences and reminder
planning; `test/cross_platform_backup_test.dart` moves a verified snapshot
between two isolated profiles in both directions. These host tests do not prove
native Android behavior. Run `flutter test integration_test/android_workflow_test.dart
--flavor github -d <isolated-emulator-id>` for the on-device SQLite/UI workflow, then the manual
matrix in [Android](ANDROID.md). Never reset a personal app profile to run tests.

Android widget rendering/capabilities also have an opt-in native harness:

```powershell
./tools/test-android-widgets.ps1 -Device emulator-5580 -ApplicationApk build/app/outputs/flutter-apk/app-github-debug.apk -AndroidSdk '<SDK>' -JavaHome '<JDK 21>' -GradleUserHome '<existing cache>'
```

Use an archived disposable emulator with app lock disabled and the same-source,
debug-signed APK. Retain the CMake/Ninja process PATH described in Android setup
when using local toolchain overrides. The harness never opens SQLite: it restores
its temporary projection and removes only its own test keys in `finally`.
It captures real RemoteViews in a native test window at three sizes, both themes,
zero/one/twelve items and normal/200% text, and verifies footer geometry and
one-use capability identity. PNGs remain in app-private cache under
`widget-render-acceptance`; copy them to ignored build logs for review.
These renders do not establish launcher drag/OEM resizing or physical TalkBack.

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

Unit and Flutter widget tests both use `flutter test`. Android's separate
`integration_test/android_workflow_test.dart` exercises real app-private SQLite,
mobile editors and staged restore on an isolated emulator. `lib/driver_main.dart` is a debug-only live-inspection
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

[Android CI](../.github/workflows/android-ci.yml) adds Android-focused host checks,
APK/native-alignment gates and real emulator integration. Its duplicate Windows-host
full suite is removed; Windows CI still runs full analysis/serial tests on every
push/PR. The signed Android candidate requires **both** workflows. Keep both
required before release; a green Android-only workflow is not full acceptance.
