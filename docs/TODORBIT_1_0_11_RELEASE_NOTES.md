# Todorbit v1.0.11 — Windows x64 pre-release

This patch release protects the update handoff from an app launch that races with installation. New app launches during replacement exit promptly so they do not hold installation files open; the updater restarts Todorbit after installation. The helper detects a process already using the same installation before closing the current app and reports its PID. It still waits for the native widget to exit and refuses to replace locked files.

The README Today screenshot has been replaced with the supplied clean image.

Automated analysis and all 243 Flutter tests passed. The Windows Release bundle, native widget self-test, installer, portable ZIP, and disposable portable helper swap passed. The disposable update closed a running widget, restarted Todorbit at the same path, and kept a seeded task, valid SQLite database, widget startup preference, and sentinel file. A registered installer upgrade and the exact in-app button flow remain unverified on a disposable Windows account; the personal installation and profile were not changed.

The v1.0.9 updater in an existing installation does not contain this repair. If Update and Restart reports another Todorbit process, close other windows and retry once. If it persists, run the verified v1.0.11 installer manually in the same Windows account and installation path. Keep `%APPDATA%\TodoPilot` and any legacy profile data in place; do not uninstall first.

These packages are unsigned. Use `SHA256SUMS.txt` to verify downloads; a matching digest does not establish publisher identity.
