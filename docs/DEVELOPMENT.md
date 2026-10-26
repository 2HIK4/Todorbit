# Development

Todorbit is a Windows-first Flutter app. Flutter UI lives in `lib/features/`, domain types in `lib/domain/`, and SQLite access in `lib/data/`. The native .NET widget is in `experiments/widget-shell-probe/`; despite the historical directory name, it is the packaged widget companion. `windows/runner/` holds the Flutter Windows runner and file-opening channels. Internal identifiers still use `life_manager` where renaming would add migration risk.

Install Flutter, Visual Studio Windows C++ desktop tools, and .NET 10 SDK. Run `flutter pub get`, `flutter analyze`, `flutter test`, `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`, the resulting `TodorbitWidget.exe --self-test`, and `./tools/build-windows-release.ps1`.

The [Windows CI workflow](../.github/workflows/windows-ci.yml) runs analysis, serial Flutter tests, a Release build, and the packaged widget self-test on `windows-2022` with Flutter 3.47.7 and .NET 10. It also validates public OAuth configuration, packages the portable ZIP and installer, writes checksums, and retains an unpublished candidate artifact. It does not publish a GitHub release or replace manual Windows acceptance. Keep the widget version synchronized with `pubspec.yaml`; both package scripts reject a mismatched widget executable.

For manual runs, set child-process `APPDATA` and `LOCALAPPDATA` to isolated temporary directories before launching. Verify those environment variables and the resulting SQLite path before interacting. Do not point development builds at a personal profile. Fresh installer profiles use `%APPDATA%\TodoPilot`; ZIP copies carry a `PORTABLE-MODE` marker and select a profile keyed by the extracted directory. The installer creates a `legacy-profile.json` marker only when upgrading a registered previous TodoPilot installation that used `%APPDATA%\Life Manager`; both executables honor it. Schema v21 is the current database format; old schemas require the reviewed Before upgrade backup gate.

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
credentials JSON import is exposed in Release. The configuration stays disabled
until [production OAuth and packaged acceptance](GOOGLE_DRIVE_RELEASE_READINESS.md)
pass. Debug-only imports remain available for authorized isolated testing with
`GOOGLE_DRIVE_ENABLED=true`. Never include user tokens, private keys, passphrases
or a downloaded Desktop credentials JSON in Git or packages. APPDATA redirection
does not create a fresh Windows Credential Manager identity; strict clean-install
acceptance needs a disposable Windows user/VM. See [format and recovery](GOOGLE_DRIVE_BACKUP.md).
