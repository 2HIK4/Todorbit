# Development

TodoPilot is a Windows-first Flutter app. Flutter UI lives in `lib/features/`, domain types in `lib/domain/`, and SQLite access in `lib/data/`. The native .NET widget is in `experiments/widget-shell-probe/`; despite the historical directory name, it is the packaged widget companion. `windows/runner/` holds the Flutter Windows runner and file-opening channels. Internal identifiers still use `life_manager` where renaming would add migration risk.

Install Flutter, Visual Studio Windows C++ desktop tools, and .NET 10 SDK. Run `flutter pub get`, `flutter analyze`, `flutter test`, `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`, the resulting `TodoPilotWidget.exe --self-test`, and `flutter build windows --release`.

For manual runs, set child-process `APPDATA` and `LOCALAPPDATA` to isolated temporary directories before launching. Verify those environment variables and the resulting SQLite path before interacting. Do not point development builds at a personal profile. Fresh installer profiles use `%APPDATA%\TodoPilot`; ZIP copies carry a `PORTABLE-MODE` marker and select a profile keyed by the extracted directory. The installer creates a `legacy-profile.json` marker only when upgrading a registered previous TodoPilot installation that used `%APPDATA%\Life Manager`; both executables honor it. Schema v20 remains the current database format; old schemas require the reviewed Before upgrade backup gate.

The Inno Setup project is `installer/life_manager.iss` and retains its existing AppId and install path for upgrades. Run `installer/build-installer.ps1 -Compiler '<ISCC.exe path>'` only after a Release build. Portable packaging uses `tools/build-portable.ps1`. Packages and generated files under `release/` are ignored by Git.
