# Todorbit working rules

- Windows-first, offline Flutter app. Keep Android scaffold intact; no Android UI, cloud, telemetry, or accounts now.
- Keep UI in `lib/features/`, domain models in `lib/domain/`, and SQLite access in `lib/data/`. Persistent writes go through the repository; use stable UUIDs and UTC timestamps.
- Separate planned dates, deadlines, sessions, actual work, and fixed events. Never auto-complete or silently reschedule a task.
- Keep visible controls functional or explicitly unavailable. Do not show invented data or claim widget behavior without manual verification.
- Preserve user data. Migrate schemas forward and use transactions for multi-record edits.
- Read `docs/PROGRESS.md` for the next task. Update it after meaningful work; record major choices in `docs/DECISIONS.md`.
- Validate with `flutter analyze`, `flutter test`, and Windows builds at milestones. Record failures accurately.
- Do not commit caches, builds, secrets, or machine-specific settings. Use safe Git operations.
- Public brand is Todorbit; preserve the existing `%APPDATA%\TodoPilot` and legacy `%APPDATA%\Life Manager` data paths, native IPC names, and stable installer AppId until a reviewed migration exists.
- Theme JSON is validated data only. Keep light/dark defaults and native widget tokens synchronized; imported theme metadata never changes the official contributor registry.
- Test widget painting, shell attachment, input, DPI, and menu changes with `TodorbitWidget.exe --self-test` and the manual checklist in `docs/windows-widget.md` on an isolated profile.
