<img src="assets/app_icon.png" alt="" width="72">

# Todorbit

Todorbit is a free, open-source planner for Windows and Android. Use it to organize tasks and fixed events, build habits, work toward goals, and see where your time went. A task's planned day, deadline, and recorded work stay separate. The everyday planner works offline without an account.

[Download Beta 30](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30) · [Official website](https://2hik4.github.io/Todorbit/) · [Installation and recovery](docs/INSTALLATION.md) · [Documentation](docs/README.md)

**Current public download:** Experimental Beta 30. Windows packages are unsigned. Windows 11 is the primary desktop test platform, and Windows 10 testing is limited. Android APKs require Android 8.0 or later on ARM64 or x86-64.

[![Todorbit Today on Windows with a sidebar, planning controls, and a list of fictional tasks](docs/screenshots/todorbit-today-redesign.png)](docs/SCREENSHOTS.md)

*Windows Today workspace, captured from the running app using an isolated profile with fictional records. See the [screenshot gallery](docs/SCREENSHOTS.md) for Android, Calendar, Hotkeys, and widgets, with capture methods.*

## What you can do

- **Plan and organize tasks.** Create and complete tasks with statuses and priorities. Duplicate tasks on Android. Organize with categories, nested projects, subtasks, named checklists, dependencies, recurring step plans, and templates. Review Today, Inbox, and Upcoming, sort and filter lists, save views where supported, search tasks and events, and recover items from Archive or Trash.
- **Schedule work and fixed events.** Keep deadlines, planned days, work sessions, and recurring calendar events separate. On Windows, use the Day, Week, and Month calendar with drag, resize, zoom, and undo where supported. On Android, browse the touch agenda. Preview Smart Reschedule changes before applying them.
- **Track focus and progress.** Log work manually or with Stopwatch, Countdown, and Pomodoro timers. Use the Windows mini timer, record habit check-ins and streaks, set measurable goals and milestones, and review local reports.
- **Bring related material and reminders together.** Attach managed files, link resources, accept files into the Android Shared Inbox, and set reminders and alarms. Windows and Android both offer Tasks and Calendar widgets with platform-specific controls.
- **Make the workspace your own.** Switch themes, customize colors and layout, transfer supported preferences, and manage Windows shortcut presets and spell highlighting. Use the app's supported update channel and review its package checks before upgrading.
- **Keep control of your data.** Use automatic and manual local backups, reviewed restores, and separate Windows portable profiles. Optional Google Drive backups and Standard or Private Encrypted Sync are available in configured Experimental builds, subject to account and device limits.

The [feature catalogue](docs/FEATURES.md) records platform differences, release status, and source and verification evidence.

## Install and update

| Platform | Public package | What to know |
| --- | --- | --- |
| Windows x64 | Installer or portable ZIP | Extract the entire ZIP. Moving a portable folder selects a separate local profile. |
| Android 8.0+ | Universal, ARM64, or x86-64 APK | Direct installation from GitHub. In-place updates require the same signing key. |

Choose an asset from [Beta 30](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30), compare its SHA-256 with the matching release checksum file, and export a verified backup before upgrading. See the [installation guide](docs/INSTALLATION.md) and [platform support matrix](docs/PLATFORM_SUPPORT.md).

## Privacy and recovery

Planner data and managed attachments are stored on the device in SQLite. The optional PIN locks the app interface. Use operating-system protections for encryption at rest. Local backups work offline. Configured cloud builds can store client-encrypted Drive snapshots, send planner changes using Standard Sync, or use Private Encrypted Sync with a passphrase or recovery code. Standard Sync sends planner operations without client-side encryption. Public Google OAuth approval and universal account compatibility remain unverified. [Privacy and data handling](docs/PRIVACY.md)

## Source and contributions

- **Release source:** [Beta 30 tag](https://github.com/2HIK4/Todorbit/tree/v1.0.19-beta.30) at `253f4ed`, app build `1.0.19-beta.30+53`.
- **App development:** [Experimental branch](https://github.com/2HIK4/Todorbit/tree/feature/todorbit-beta27-refinement). Flutter handles the app, Drift/SQLite handles storage, and native Windows and Android components provide platform integrations.
- **Public documentation and site:** `main` also carries the older Windows app source. Use the tagged source to reproduce a release or the Experimental branch to contribute to the current app.
- **Start here:** [Contributing](CONTRIBUTING.md) · [Starter tasks](docs/CONTRIBUTOR_TASKS.md) · [Roadmap](docs/ROADMAP.md) · [Open-source evidence](docs/OPEN_SOURCE_EVIDENCE.md)

Report bugs or suggest features through [GitHub Issues](https://github.com/2HIK4/Todorbit/issues/new/choose). Report security concerns privately using the [security policy](SECURITY.md). See the [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

Created by [Hussam Alkhatib](https://2hik4.github.io/). [MIT license](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Contributors](assets/contributors.json)
