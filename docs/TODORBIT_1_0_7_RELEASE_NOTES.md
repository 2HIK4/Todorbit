# Todorbit v1.0.7 — Windows x64 pre-release

This unsigned pre-release improves profile safety checks, settings sharing, Calendar controls, hotkeys, and Backup & Restore.

## Changes

- Calendar Day, Week, and Month keep the header controls aligned. Segmented controls across Calendar and Settings keep stable dimensions. The Custom Event Color picker now uses Todorbit's themed Primary, Accent, and Wheel control.
- Hotkeys support duplicating a preset and show Reset as unavailable when a shortcut already matches the default. Existing saved presets remain compatible.
- Settings > Appearance & Themes > Share settings exports selected personalization as versioned JSON. Import validates and previews categories before applying them; hotkey presets can be merged. Shared settings exclude PINs, file paths, and task/event database records.
- Backup & Restore groups create/export, import/restore, and history. Snapshot previews show data counts, technical details are collapsed, and the app distinguishes pending restore from a database that opened successfully.
- A pending restore is applied before migration approval is checked. Older restored databases still require explicit approval and verified Before Upgrade and Before Restore recovery copies.
- The Backups sidebar item aligns with its Settings peer.

## Install and data safety

Use the installer or portable ZIP and verify the download against `SHA256SUMS.txt`. The installer retains AppId `{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}` and the existing installation path. Installed profiles remain under `%APPDATA%\TodoPilot`; registered older TodoPilot profiles can continue using `%APPDATA%\Life Manager`. Portable profiles remain keyed to their exact extracted path. No existing profile records are deleted by this release.

Database restore replaces the current database after Todorbit is closed and reopened. It does not merge individual tasks or events. A verified Before Restore backup is created first. If the snapshot is older than schema 21, review and approve the following database upgrade.

## Verification limits

Disposable profile and synthetic schema 20 restore checks, automated tests, and build gates are recorded in [the acceptance record](https://github.com/2HIK4/Todorbit/blob/main/docs/ACCEPTANCE.md). The user's original Trash entries were not inspected, so their provenance is unknown. A registered v1.0.6 installer upgrade, native Windows file picker interaction, physical DPI/window resizing, and Explorer widget painting/input remain unverified. The packages are unsigned; SHA-256 is an integrity check, not a publisher signature.
