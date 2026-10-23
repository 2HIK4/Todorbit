# Todorbit v1.0.6 — Windows x64 pre-release

Todorbit is an offline Windows planner. This unsigned pre-release adds a Calendar editing pass and built-in update checking.

## Changes

- Calendar events gain optional detail rows, reusable detail types, category colors, and a custom color picker. Event and day dialogs have clearer layouts.
- Choose the first weekday and sidebar order; the last Calendar view is restored.
- Settings > Software Updates checks published GitHub Releases, validates exact Windows x64 packages against GitHub SHA-256 digests, and supports installed and portable updates. Portable replacement keeps the same folder and a binary rollback copy.
- Narrow Habit, Goal, Search, and Template dialogs have improved spacing and wrapping controls.

## Install and data safety

Download the installer or portable ZIP and verify it against `SHA256SUMS.txt`. The installer retains AppId `{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}` and `%LOCALAPPDATA%\Programs\Life Manager`. Installed profiles remain under `%APPDATA%\TodoPilot`; registered older TodoPilot profiles can continue using `%APPDATA%\Life Manager`. Portable profiles remain keyed to the exact extracted path under `%APPDATA%\TodoPilot`. See [installation guidance](https://github.com/2HIK4/Todorbit/blob/v1.0.6/docs/INSTALLATION.md).

Schema 21 adds event data. Opening an older database requires explicit migration approval and a verified Before upgrade backup. Do not delete either data directory or a portable rollback copy until the profile has been checked.

## Verification limits

Automated analysis, Flutter tests, Windows and native Release builds, packaged widget self-test, package contents, and a disposable same-path portable upgrade from the published 1.0.5 ZIP are recorded in the [acceptance record](https://github.com/2HIK4/Todorbit/blob/v1.0.6/docs/ACCEPTANCE.md). A registered installer upgrade, live schema migration approval, physical widget painting/input, Windows 10, and mixed DPI behavior remain unverified. The packages are unsigned. Do not interpret a GitHub digest as a publisher signature.
