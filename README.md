# Todorbit

[Official website](https://2hik4.github.io/Todorbit/) · [Privacy Policy](https://2hik4.github.io/Todorbit/privacy.html) · [Terms of Service](https://2hik4.github.io/Todorbit/terms.html)

![Todorbit icon](assets/app_icon.png)

![Unreleased Todorbit Today redesign preview](docs/screenshots/todorbit-today-redesign.png)

Todorbit is an offline Windows productivity app with an Android beta for tasks, calendar events, habits, goals, and focus sessions. It is built with Flutter and SQLite. Creator: [Hussam Alkhatib](https://2hik4.github.io/).

## What it does

- Plan tasks and deadlines separately; track actual work with focus timers and sessions.
- Organize categories, projects, subtasks, and recurring tasks. Use Inbox,
  focused task lists, and saved filters on Windows and Android.
- View Month, Week, and Day on Windows and Android. Use the Windows timeline
  to move or resize timed events, and the Android agenda to open events for
  editing. Preview Smart Reschedule before applying it.
  [Calendar guide](docs/INTERACTIVE_CALENDAR.md).
- Check in on habits, review streaks, and track goal progress, linked work
  and milestones. Focus supports stopwatch, countdown and Pomodoro modes.
- Use a native Windows desktop widget for Quick Add, task editing, and completion.
- Keep data local, with managed backups, reviewed restore, and SQLite import/export.
- Customize light and dark color palettes with a color wheel and share validated JSON themes through Settings → Appearance → Customize Theme.

Settings keeps Sync status and queued changes alongside the last successful
sync. Backups provide point-in-time recovery. Windows and Android native
widgets use the selected palette when available.

## Desktop refinement

The [Beta 27 refinement receipt](docs/BETA_27_REFINEMENT.md) records the desktop
task-list layout, graphite appearance, and isolated Calendar comparison.
The [follow-up polish](docs/BETA_27_POLISH_IMPLEMENTATION.md) adds dark palette
choices and depth to the Calendar frame measurements. Beta 28 uses the
approved Graphite Neutral Silver dark default. Existing saved colors stay
available through Appearance. See the [Beta 28 notes](docs/TODORBIT_BETA_28_RELEASE_NOTES.md).

## Android beta installation

The production-signed Android Beta 28 supports Android 8.0+ with universal,
ARM64 and x86-64 APKs. Existing production-signed Beta 27 users can select
Experimental in Settings → Software Updates. For a manual download, verify
the published SHA-256. Back up existing data before changing builds. See the
[Beta 28 downloads](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.28),
[phone signing and backup testing](docs/ANDROID_BETA_2_PHONE_TESTING.md),
[sync setup](docs/GOOGLE_DRIVE_SYNC.md) and the
[Beta 28 verification record](docs/TODORBIT_BETA_28_CANDIDATE.md).

## Windows installation

Todorbit Beta 28 is an Experimental Windows x64 release. Windows 11 is the main
test platform. Windows 10 acceptance is limited. Download the unsigned installer
or portable ZIP and compare it with the published SHA-256. Run the installer or
extract the whole portable ZIP and run `Todorbit.exe`. Keep the executable,
companion, DLLs and `data` folder together. The packages require neither Flutter
nor Visual Studio. [Beta 28 downloads](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.28)

The portable ZIP does **not** store data beside the executable. Each extracted portable location uses its own `%APPDATA%\TodoPilot\portable-<location-id>` profile; copying or moving the extracted folder selects a new empty profile. An installer fresh profile uses `%APPDATA%\TodoPilot\life_manager.sqlite`. This legacy path remains stable through the rename. An older `%APPDATA%\Life Manager` database is never selected just because it exists; on first launch Todorbit offers a reviewed, explicit import. Upgrading an installed TodoPilot retains its existing profile and settings. Export/import data through Settings > Backups & Cloud before moving a portable folder, and do not delete either profile folder.

The [Windows + Android sync beta 4](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.4)
adds encrypted incremental exchange, pairing, conflict review and bounded background
opportunities. See the [sync guide](docs/GOOGLE_DRIVE_SYNC.md) and
[publication checks, hashes and limits](docs/DRIVE_SYNC_BETA_4_PUBLICATION.md).
Current real Drive sync acceptance uses mocks; back up existing data and follow
the pairing/recovery guide before testing with real records.

Google Drive encrypted backup/restore is **enabled and experimental since v1.0.13**, with real full/settings recovery verification. The published packages bundle the tested Desktop application configuration; users do not need Google Cloud setup or a credentials JSON. Google branding verification and full public OAuth policy compliance remain unresolved; no Google approval or compatibility with every account is claimed. Snapshot backups remain independent from the separately enabled sync feature; linked external file contents are excluded. Local backups and settings JSON transfer remain available offline. Source builds keep a disabled/empty default configuration. See [backup contents and recovery](docs/GOOGLE_DRIVE_BACKUP.md), [publication evidence and limitations](docs/TODORBIT_1_0_17_PUBLICATION.md), and the [privacy disclosure](docs/PRIVACY.md).

The native widget can be shown from the app sidebar. By default, it launches at Windows sign-in after Todorbit's first launch; Settings > Widget can turn this off. Right-click it for Refresh, appearance, layout lock, and Close Widget. The widget can run while the main window is closed. The optional PIN locks the UI; it does not encrypt the SQLite database. See [installation and portable upgrade instructions](docs/INSTALLATION.md).

## Source build

Install Flutter with Windows desktop support, Visual Studio C++ desktop tools, and .NET 10 SDK. Then run:

```powershell
flutter pub get
flutter analyze
flutter test
./tools/build-windows-release.ps1
```

The Release bundle is `build\windows\x64\runner\Release`. See [Development](docs/DEVELOPMENT.md) for toolchain/profile setup, [Architecture](docs/ARCHITECTURE.md) for subsystem locations, and [Testing](docs/TESTING.md) for focused checks during development. The commands above are a full source-build baseline.

If a moved portable copy looks empty, check Settings > Data profile and reopen the original extracted path or import its verified backup. Keep the full application bundle together. See [installation troubleshooting](docs/INSTALLATION.md) for recovery steps.

## Customization and contributions

The [Todorbit design system](docs/UI_DESIGN_SYSTEM.md) describes the redesigned
Today workspace and its shared Flutter controls.

See [theming](docs/THEMING.md), [customization extension points](docs/CUSTOMIZATION.md), and [contribution guidance](CONTRIBUTING.md). Official community entries come from `assets/contributors.json` through reviewed pull requests; imported themes do not add someone to that list.

Creator: **Hussam Alkhatib**, Creator & Project Founder. Original concept, product direction, and development of Todorbit. [Email](mailto:hussamalkhatib24@gmail.com) · [Portfolio](https://2hik4.github.io/) · [LinkedIn](https://www.linkedin.com/in/hussam-alkhatib-dev).

## Current release status

The coordinated v1.0.19-beta.12 pre-release includes six UI reliability batches:
draft protection, compact/large-text layouts, resource/template failure recovery,
safe startup preference handling and theme transfer. Android versionCode is 35;
schema 26, Sync protocol 1, backups, recovery requirements and production signing
identity remain compatible. Further tests and CI were skipped at the owner's
explicit request; previous scoped evidence remains limited to its recorded cases.
Build, signing, package and checksum integrity are recorded separately. Native
Windows/Android and real Google Drive cross-device acceptance remain incomplete.
Preserve a verified backup and the credentials required by your Sync mode.
Windows is unsigned. See [release notes](docs/UI_QUALITY_BETA_12_RELEASE_NOTES.md),
[publication evidence/checksums](docs/UI_QUALITY_BETA_12_PUBLICATION.md) and the
[preliminary naming review](docs/NAMING_REVIEW.md); formal trademark clearance
remains open.

**License:** [MIT](LICENSE), approved by the creator for this project. Third-party terms remain separate in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the distributed Flutter and native notices.
