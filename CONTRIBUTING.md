# Contributing to Todorbit

Start with the [contributor tasks](docs/CONTRIBUTOR_TASKS.md) or [open an issue](https://github.com/2HIK4/Todorbit/issues/new/choose). Hussam Alkhatib maintains Todorbit and reviews changes. Focus each contribution on one documented behavior or maintenance problem. Changes to persistent data, integrations, or the release process need a design discussion before implementation. See the [Code of Conduct](CODE_OF_CONDUCT.md).

## Choose your base

| Work | Base |
| --- | --- |
| Public README, documentation, GitHub templates, or website | `main` |
| Current Windows or Android app, native integrations, or TDAT | [Experimental development branch](https://github.com/2HIK4/Todorbit/tree/feature/todorbit-beta27-refinement) |
| Reproducing Beta 30 | [Release source tag](https://github.com/2HIK4/Todorbit/tree/v1.0.19-beta.30), build `1.0.19-beta.30+53` |

Fork the repository for your changes. Current app source requires checking out Experimental or the release tag explicitly. `main` still carries the older Windows implementation and doesn't include TDAT.

## Documentation and website

Use Python 3.11 or later. From the repository root, run:

```powershell
python tools/dev/check-docs.py
python website/verify.py
python -m http.server --directory website/dist 8080
```

Open [the local preview](http://localhost:8080/) after starting the server. Use a narrow and wide viewport, a keyboard, and light and dark browser settings for visual changes. For download changes also run `python website/verify_live.py --preview`. The [website guide](website/README.md) explains deployment and receipts.

## Application development

Clone the current app branch into a separate directory. To reproduce Beta 30, substitute `v1.0.19-beta.30` for the branch and expect a detached HEAD.

```powershell
git clone --branch feature/todorbit-beta27-refinement https://github.com/2HIK4/Todorbit.git Todorbit
Set-Location Todorbit
flutter.bat pub get --enforce-lockfile
.\dev.cmd doctor
```

Use your fork URL when you are preparing a push. Beta 30 CI uses Flutter 3.47.7. Windows development also uses Visual Studio with Desktop development with C++ and the .NET 10 SDK. Android builds use JDK 21 and the checked-in toolchain described in the [Android setup guide](https://github.com/2HIK4/Todorbit/blob/feature/todorbit-beta27-refinement/docs/ANDROID_SETUP.md).

If Flutter resolves packages but exits because Windows cannot create plugin symlinks, run the repository's junction helper and repeat package restoration:

~~~powershell
pwsh -NoProfile -NonInteractive -File tools/dev/prepare-windows-plugins.ps1
flutter.bat pub get --enforce-lockfile
~~~

A regular development build works without production signing keys or Google Drive credentials. Use a disposable profile or Android emulator with fictional records. Follow the [development guide](https://github.com/2HIK4/Todorbit/blob/feature/todorbit-beta27-refinement/docs/DEVELOPMENT.md) for profile isolation and the optional Windows plugin-link workaround.

Find the affected feature in the [architecture map](https://github.com/2HIK4/Todorbit/blob/feature/todorbit-beta27-refinement/docs/ARCHITECTURE_MAP.md). Use [TDAT](https://github.com/2HIK4/Todorbit/blob/feature/todorbit-beta27-refinement/docs/DEVELOPER_AUTOMATION_TOOLKIT.md) and the [testing guide](https://github.com/2HIK4/Todorbit/blob/feature/todorbit-beta27-refinement/docs/TESTING.md) to choose affected checks:

```powershell
.\dev.cmd context tasks
.\dev.cmd impact
.\dev.cmd verify changed
```

Replace `tasks` with the affected feature. Run the relevant data-safety suites immediately for changes to migrations, write boundaries, recurrence, sync, backup, or restore. Keep planned dates, deadlines, work sessions, and fixed events distinct. Reuse the app's shared components and keep changes inside the established architecture boundaries.

## Submit a change

- State what changes, which platforms are affected, and what you tested. Name skipped or blocked checks.
- Include screenshots from synthetic data for visual changes. Update the feature catalogue, platform matrix, guides, or release notes where behavior changes.
- Keep personal profiles, databases, backups, diagnostic logs, credentials, and signing material private. Use [private security reporting](SECURITY.md) for vulnerabilities.
- For themes and reviewed attributions, follow the [theme guide](https://github.com/2HIK4/Todorbit/blob/feature/todorbit-beta27-refinement/docs/THEMING.md) and existing [contributor registry](assets/contributors.json).
