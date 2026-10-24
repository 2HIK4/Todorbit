# Todorbit

![Todorbit icon](assets/app_icon.png)

![Todorbit Today view with a sample task in an isolated test profile](docs/screenshots/todorbit-today.png)

Todorbit is an offline Windows productivity app for tasks, calendar events, habits, goals, focus sessions, and a native desktop widget. It is built with Flutter and SQLite. Creator: [Hussam Alkhatib](https://2hik4.github.io/).

## What it does

- Plan tasks and deadlines separately; track actual work with focus timers and sessions.
- Organize categories, projects, subtasks, recurring tasks, and saved views.
- View fixed events and tasks on the calendar; preview Smart Reschedule before applying it.
- Track habits and goals, and review reports.
- Use a native Windows desktop widget for Quick Add, task editing, and completion.
- Keep data local, with managed backups, reviewed restore, and SQLite import/export.
- Customize light and dark color palettes with a color wheel and share validated JSON themes through Settings → Appearance → Customize Theme.

## Windows installation

Todorbit v1.0.7 is a free, MIT-licensed Windows x64 pre-release. Windows 11 is the main development and test platform; Windows 10 acceptance is limited. Download the unsigned installer or portable ZIP from [GitHub Releases](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.7) and compare it with the published SHA-256 checksum. Run the installer or extract the portable ZIP and run `Todorbit.exe`. Keep the full extracted folder together, including `TodorbitWidget.exe`, DLLs, and the `data` folder. Neither package requires Flutter or Visual Studio on the user's computer.

The portable ZIP does **not** store data beside the executable. Each extracted portable location uses its own `%APPDATA%\TodoPilot\portable-<location-id>` profile; copying or moving the extracted folder selects a new empty profile. An installer fresh profile uses `%APPDATA%\TodoPilot\life_manager.sqlite`. This legacy path remains stable through the rename. An older `%APPDATA%\Life Manager` database is never selected just because it exists; on first launch Todorbit offers a reviewed, explicit import through Backups. Upgrading an installed TodoPilot retains its existing profile and settings. Export/import data before moving a portable folder, and do not delete either profile folder.

The native widget can be shown from the app sidebar. Right-click it for Refresh, appearance, layout lock, and Close Widget. The widget can run while the main window is closed. The optional PIN locks the UI; it does not encrypt the SQLite database. See [installation and portable upgrade instructions](docs/INSTALLATION.md).

## Source build

Install Flutter with Windows desktop support, Visual Studio C++ desktop tools, and .NET 10 SDK. Then run:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

The Release bundle is `build\windows\x64\runner\Release`. Build instructions and architecture are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

If a moved portable copy looks empty, check Settings > Data profile and reopen the original extracted path or import its verified backup. Keep the full application bundle together. See [installation troubleshooting](docs/INSTALLATION.md) for recovery steps.

## Customization and contributions

See [theming](docs/THEMING.md), [customization extension points](docs/CUSTOMIZATION.md), and [contribution guidance](CONTRIBUTING.md). Official community entries come from `assets/contributors.json` through reviewed pull requests; imported themes do not add someone to that list.

Creator: **Hussam Alkhatib**, Creator & Project Founder. Original concept, product direction, and development of Todorbit. [Email](mailto:hussamalkhatib24@gmail.com) · [Portfolio](https://2hik4.github.io/) · [LinkedIn](https://www.linkedin.com/in/hussam-alkhatib-dev).

## Current release status

The v1.0.7 pre-release adds selective settings sharing, clearer backup restore status, stable Calendar controls, and hotkey preset improvements. Schema 20 profiles require approval and a verified backup before migration to schema 21. Native widget alpha blending, Win+D, different wallpapers and monitor layouts, installer upgrade/uninstall, and some physical Windows GUI flows still require manual acceptance. The installer is unsigned. See [release preparation](docs/RELEASE.md), [acceptance matrix](docs/ACCEPTANCE.md), and the [preliminary naming review](docs/NAMING_REVIEW.md); formal trademark clearance remains open.

**License:** [MIT](LICENSE), approved by the creator for this project. Third-party terms remain separate in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the distributed Flutter and native notices.
