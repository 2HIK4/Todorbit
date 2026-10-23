# Todorbit working rules

- Windows-first, offline Flutter app. Keep Android scaffold intact; no Android UI, cloud, telemetry, or accounts now.
- Keep UI in `lib/features/`, domain models in `lib/domain/`, and SQLite access in `lib/data/`. Persistent writes go through the repository; use stable UUIDs and UTC timestamps.
- Separate planned dates, deadlines, sessions, actual work, and fixed events. Never auto-complete or silently reschedule a task.
- Keep visible controls functional or explicitly unavailable. Do not show invented data or claim widget behavior without manual verification.
- Preserve user data. Migrate schemas forward and use transactions for multi-record edits.
- Read `docs/PROGRESS.md` when selecting the next product task or preparing a handoff. Update it after meaningful work; record major choices in `docs/DECISIONS.md`. Use `docs/ARCHITECTURE.md` for data boundaries and `docs/DEVELOPMENT.md` for build/profile setup.
- Search targeted paths with `rg`; exclude generated, build, and dependency output. Read only relevant docs and skill references. Reuse existing code and theme tokens.
- Use the installed Dart/Flutter MCP for targeted diagnostics and live inspection when connected. Run focused tests while editing; expand to full analysis/tests and Windows/native builds for integration or release risk. See `.agents/skills/todorbit-regression/SKILL.md` for the risk-based workflow. Record failures accurately.
- Follow Microsoft Fluent guidance for Windows UI, the existing Todorbit theme system, keyboard access, and responsive layout. Use `.agents/skills/todorbit-ui-review/SKILL.md` for UI audits. Visually verify UI changes on an isolated profile when practical; label unobserved behavior accurately.
- Do not commit caches, builds, secrets, or machine-specific settings. Use safe Git operations.
- Public brand is Todorbit; preserve the existing `%APPDATA%\TodoPilot` and legacy `%APPDATA%\Life Manager` data paths, native IPC names, and stable installer AppId until a reviewed migration exists.
- Theme JSON is validated data only. Keep light/dark defaults and native widget tokens synchronized; imported theme metadata never changes the official contributor registry.
- Test widget painting, shell attachment, input, DPI, and menu changes with `TodorbitWidget.exe --self-test` and the manual checklist in `docs/windows-widget.md` on an isolated profile.
