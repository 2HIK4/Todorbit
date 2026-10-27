# Development

Todorbit is a Windows-first Flutter app. Flutter UI lives in `lib/features/`, domain types in `lib/domain/`, and SQLite access in `lib/data/`. The native .NET widget is in `experiments/widget-shell-probe/`; despite the historical directory name, it is the packaged widget companion. `windows/runner/` holds the Flutter Windows runner and file-opening channels. Internal identifiers still use `life_manager` where renaming would add migration risk.

Install Flutter, Visual Studio Windows C++ desktop tools, and .NET 10 SDK. Run `flutter pub get` first. Use [Testing](TESTING.md) to select checks for the changed boundary; a small edit does not require all build/test commands. Distribution builds use `./tools/build-windows-release.ps1` after dependencies are resolved.

The [Windows CI workflow](../.github/workflows/windows-ci.yml) runs analysis, serial Flutter tests, a Release build, and the packaged widget self-test on `windows-2022` with Flutter 3.47.7 and .NET 10. It also validates public OAuth configuration, packages the portable ZIP and installer, writes checksums, and retains an unpublished candidate artifact. It does not publish a GitHub release or replace manual Windows acceptance. Keep the widget version synchronized with `pubspec.yaml`; both package scripts reject a mismatched widget executable.

For manual runs, set child-process `APPDATA` and `LOCALAPPDATA` to isolated temporary directories before launching. Verify those environment variables and the resulting SQLite path before interacting. Do not point development builds at a personal profile. Fresh installer profiles use `%APPDATA%\TodoPilot`; ZIP copies carry a `PORTABLE-MODE` marker and select a profile keyed by the extracted directory. The installer creates a `legacy-profile.json` marker only when upgrading a registered previous TodoPilot installation that used `%APPDATA%\Life Manager`; both executables honor it. Schema v21 is the current database format; old schemas require the reviewed Before upgrade backup gate.

For a native self-test, this PowerShell example passes isolated environment
variables only to the child (requires a native Release build):

```powershell
$checkRoot = Join-Path $env:TEMP ('todorbit-native-' + [guid]::NewGuid().ToString('N'))
$checkInfo = [System.Diagnostics.ProcessStartInfo]::new()
$checkInfo.FileName = (Resolve-Path 'experiments/widget-shell-probe/bin/Release/net10.0-windows/TodorbitWidget.exe').Path
$checkInfo.UseShellExecute = $false
$checkInfo.CreateNoWindow = $true
$checkInfo.Environment['APPDATA'] = Join-Path $checkRoot 'Roaming'
$checkInfo.Environment['LOCALAPPDATA'] = Join-Path $checkRoot 'Local'
New-Item -ItemType Directory -Force -Path $checkInfo.Environment['APPDATA'],$checkInfo.Environment['LOCALAPPDATA'] | Out-Null
$checkInfo.ArgumentList.Add('--self-test')
$checkProcess = [System.Diagnostics.Process]::Start($checkInfo)
$checkProcess.WaitForExit()
if ($checkProcess.ExitCode -ne 0) { throw 'Native self-test failed.' }
```

Use PowerShell 7 for this `ProcessStartInfo.Environment`/`ArgumentList` example.
For packaged verification substitute the Release bundle executable path.
Windows CMake already publishes/packages the companion; a separate `dotnet build`
is useful for fast native diagnostics, not an extra distribution packaging step.

Release builds synchronize the native widget's per-user Windows Run entry after opening the active profile. New widget settings default to startup on; an explicit saved off remains off. Debug builds skip this synchronization so isolated GUI work does not alter the developer account's startup entries. Test registration through the native self-test's private registry key; a real sign-in still requires separate Windows acceptance.

The Inno Setup project is `installer/life_manager.iss` and retains its existing AppId and install path for upgrades. Run `installer/build-installer.ps1 -Compiler '<ISCC.exe path>'` only after a Release build. Portable packaging uses `tools/build-portable.ps1`. Packages and generated files under `release/` are ignored by Git.

CI obtains Inno Setup 7.1.0 x64 directly from the official vendor GitHub release,
verifies its pinned SHA-256, and installs it only in the hosted runner through
`tools/install-inno-setup-ci.ps1`. Chocolatey's `innosetup` feed did not contain
the 7.1.0 package. Local `-VerifyDownloadOnly` checks the compiler download
without installing or changing the existing compiler.

Google Drive is opt-in and gated by the reviewed public `config/google-drive.json`.
Use `tools/build-windows-release.ps1` for distribution: it compiles the Desktop
client ID and required public client-secret parameter and writes a consistency
receipt checked by both packaging scripts. No end-user developer setup or
credentials JSON import is exposed in Release. The tracked default remains disabled/empty. Owner-approved experimental public
packages have used enabled configuration since v1.0.13; this does not resolve
[production OAuth policy/acceptance limits](GOOGLE_DRIVE_RELEASE_READINESS.md). Debug-only imports remain available for authorized isolated testing with
`GOOGLE_DRIVE_ENABLED=true`. Never include user tokens, private keys, passphrases
or a downloaded Desktop credentials JSON in Git or packages. APPDATA redirection
does not create a fresh Windows Credential Manager identity; strict clean-install
acceptance needs a disposable Windows user/VM. See [format and recovery](GOOGLE_DRIVE_BACKUP.md).

The earlier [private acceptance](GOOGLE_DRIVE_PRIVATE_ACCEPTANCE.md) is a
historical checkpoint. For the published enabled package and remaining limits,
see the [v1.0.16 publication receipt](TODORBIT_1_0_16_PUBLICATION.md); it grants no
authorization to enable or publish a future build.

Database creation and upgrades commit schema DDL and `user_version` in one
transaction. Startup recognizes version 0 as unfinished initialization, but
automatically completes it only when every user table is empty and the final
schema exactly matches a fresh current database. Populated/incompatible files
are preserved and rejected; no reset/delete fallback exists. Schema v21 and
approved upgrade/Before upgrade gates remain unchanged. Regression includes
real child-process termination before commit; see
[engineering acceptance](GOOGLE_DRIVE_ENGINEERING_ACCEPTANCE.md).

For strict fresh-user installer/portable acceptance, prepare a guarded Windows
Sandbox payload with `tools/prepare-windows-sandbox-acceptance.ps1`. Follow
[clean Windows acceptance](WINDOWS_CLEAN_ACCEPTANCE.md); never run the installer
on the owner's normal account. Preparing a Sandbox script is not VM acceptance.
