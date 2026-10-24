# Todorbit v1.0.9 — Windows x64 pre-release

This unsigned pre-release improves selection menus, view guidance, and widget startup.

## Changes

- Form selection menus open below their fields when space allows, stay within the visible app area, and show a consistent selected-item mark. Software Updates gives Update Channel a separate label; Backup & Restore aligns space above its action buttons.
- Habits, Goals, Calendar, and Reports explain their purpose through the same About this view control used by task views.
- The Windows widget launches at sign-in by default after Todorbit's first launch. Settings > Widget can turn this off. An explicit off choice stays off; startup registration is repaired when the Release app opens after a path change or update.
- The update helper verifies package SHA-256 without relying on the PowerShell Get-FileHash cmdlet, which failed in the previous Windows CI preflight test.

## Updating an installed v1.0.8 copy

Open Settings > Software Updates, select Pre-release, then Check for Updates. Confirm the version and release notes, download the installer, and use Update and Restart. Check that Todorbit reopens as v1.0.9 with your tasks, events, and settings. Keep the installed copy and profile in place; do not uninstall or delete %APPDATA%\TodoPilot. If the in-app update fails, retain the existing installation and use the verified v1.0.9 installer manually.

The portable ZIP is for portable copies. Moving a portable folder selects a different location-based profile; replace files at the same path to retain that profile.

## Verification and limits

Automated analysis, Flutter tests, native widget self-test, Windows Release build, package integrity, and an isolated debug GUI dropdown interaction were run. A registered v1.0.8 installer upgrade, Windows login, physical DPI behavior, and the actual in-app Update and Restart handoff on an installed copy require separate acceptance. The user's installed app and personal profile were not changed.

The packages are unsigned. Compare downloads with SHA256SUMS.txt; a matching hash checks integrity but is not a publisher signature.
