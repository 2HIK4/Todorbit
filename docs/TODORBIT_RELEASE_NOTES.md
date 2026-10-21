# Todorbit v1.0.5 — Windows x64 pre-release

Todorbit is a free, MIT-licensed, offline Windows planner for tasks, calendar events, habits, goals, focus sessions, and a native desktop widget. Windows 11 is the main development and test platform. The installer is unsigned.

## Changes

- Improved New and Edit Task with draft checklists and subtasks, selectable and expandable checklist text, clearer sections, side-by-side scheduled day and deadline fields, Today defaults, Anytime behavior, and completed-task display preferences.
- Added local inline spelling underlines, configurable keyboard shortcuts and presets, Explorer file drop for resources, theme customization, organized Settings, and view information popovers.
- Redesigned the native widget and task editor, including rounded controls, date calendar and clear actions, aligned choice arrows, footer spacing, Quick Add, theme-aware menu, and Open Todorbit icon.
- Improved widget positioning, resizing, layout lock, profile isolation, and main-app single-instance activation.

## Install and compatibility

Download the installer or portable ZIP and verify it against `SHA256SUMS.txt`. See [installation and portable upgrade instructions](https://github.com/2HIK4/Todorbit/blob/v1.0.5/docs/INSTALLATION.md). The installer retains the stable AppId and legacy `%LOCALAPPDATA%\Programs\Life Manager` installation path; installed profiles remain under `%APPDATA%\TodoPilot`. The legacy `%APPDATA%\Life Manager` path is preserved for reviewed import. Portable data is stored in a location-keyed profile under `%APPDATA%\TodoPilot`, outside the extracted folder. No production database migration is introduced in this version.

Windows 10 acceptance remains limited. Physical native widget input, Explorer composition, Win+D, opacity, DPI, multiple monitors, and installed upgrade/uninstall have not all been manually verified. Automated tests and offscreen render checks do not establish those behaviors. See the [acceptance record](https://github.com/2HIK4/Todorbit/blob/v1.0.5/docs/ACCEPTANCE.md) and [widget checklist](https://github.com/2HIK4/Todorbit/blob/v1.0.5/docs/windows-widget.md).

Project: [GitHub](https://github.com/2HIK4/Todorbit) · Creator: [Portfolio](https://2hik4.github.io/) · [LinkedIn](https://www.linkedin.com/in/hussam-alkhatib-dev)
