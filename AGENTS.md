# Todorbit working rules

## Scope and safety

- Todorbit is a local-first Flutter productivity app targeting Windows 10/11 and Android. Windows 11 remains the primary desktop test platform. Preserve the Windows release while developing Android; see [Android acceptance and parity](docs/ANDROID.md). Keep the iOS scaffold outside this task.
- Optional Google Drive snapshot backup/restore already exists. Preserve it; do not introduce synchronization, new cloud services, accounts or telemetry without a product decision.
- Preserve tasks, events, preferences, backups and widget configurations. Never reset/delete data as an error fallback. Use compatible forward migrations and transactions for multi-record edits.
- Keep planned dates, deadlines, sessions, actual work and fixed events separate. Never auto-complete or silently reschedule tasks.
- Public brand is Todorbit. Preserve `%APPDATA%\TodoPilot`, legacy `%APPDATA%\Life Manager` compatibility, native IPC names and installer AppId until a reviewed migration exists.

## Implementation

- UI belongs in `lib/features/`, domain logic in `lib/domain/`, SQLite access in `lib/data/`. Flutter database writes go through `LifeRepository` and its part files; use stable UUIDs and UTC modification timestamps.
- `AppController` coordinates shared state; profile JSON stores own device/preferences data. The native companion has a deliberately narrow database writer and never migrates schemas. See [architecture](docs/ARCHITECTURE.md).
- Follow existing Dart/Flutter conventions. Reuse nearby components, domain calculations, services and theme tokens; prefer small changes over parallel implementations.
- Follow Microsoft Fluent guidance, keyboard access and responsive layout. Keep visible controls functional or explicitly unavailable; never invent data.
- Theme JSON is validated data only. Keep light/dark and native widget tokens synchronized; imported metadata never changes the official contributor registry.
- Keep Windows runner, native widget and packaged behavior compatible. `experiments/widget-shell-probe/` is production companion source despite its name.

## Efficient workflow and verification

- Start with `git status --short` and the smallest relevant `rg` search. Exclude generated, build and dependency directories. Read only task-relevant documentation.
- Preserve unrelated uncommitted work; use a focused branch. Never reset another task's changes or move release tags. See [Codex workflow](docs/CODEX_WORKFLOW.md).
- Find the feature in [Architecture map](docs/ARCHITECTURE_MAP.md) before searching broadly. `tools/dev/verify.ps1` selects explicit Quick/Feature/Full checks; `-Plan` previews them. Never guess tests for an uncertain dependency.
- On interrupted work, inspect the current diff and latest relevant Progress checkpoint; resume pending checks against current source. Historical artifacts are evidence only for their recorded source.
- Use focused tests/analysis while editing. Broaden for integration, data safety, shared behavior or release risk; do not repeat full suites for small unrelated edits. [Testing](docs/TESTING.md) owns commands and scope.
- Use connected Dart/Flutter MCP diagnostics and live inspection when relevant. Visually verify UI in an isolated profile when practical. Never test against personal data; verify child-process `APPDATA`, `LOCALAPPDATA` and resolved profile first.
- Native painting, shell attachment, input, DPI or menu changes require native Release/self-test plus the relevant [manual widget checklist](docs/windows-widget.md). Automated tests do not prove physical Windows behavior; report unobserved behavior accurately.
- Review diffs and run `git diff --check`. Do not commit builds, caches, secrets, credentials or machine-specific settings.
- Do not publish a release unless explicitly requested. Preserve version synchronization, CI, installer, updater and checksum gates in [release preparation](docs/RELEASE.md). Documentation-only work needs no version bump or package rebuild.

## Skills and documentation routing

- Use `.agents/skills/todorbit-regression/SKILL.md` for code validation/release checkpoints and `.agents/skills/todorbit-ui-review/SKILL.md` for UI audits or cross-screen changes.
- Use installed UI UX Pro Max for substantial interface design when helpful; use specialized Dart/Flutter or other skills only when they materially help. Do not load every skill. Windows guidance and Todorbit tokens remain authoritative for this app.
- [README](README.md): public introduction; [CONTRIBUTING](CONTRIBUTING.md): onboarding.
- [Architecture map](docs/ARCHITECTURE_MAP.md): feature entry points; [Architecture](docs/ARCHITECTURE.md): relationships and constraints; [Development](docs/DEVELOPMENT.md): toolchain/profile setup; [Testing](docs/TESTING.md): checks by risk.
- [Codex workflow](docs/CODEX_WORKFLOW.md): task execution and handoffs; [Release](docs/RELEASE.md): packaging/publishing; [Updates](docs/SOFTWARE_UPDATES.md): updater protocol/recovery.
- Consult [Progress](docs/PROGRESS.md) when choosing the next product task or preparing a handoff; add a short checkpoint after meaningful work. Record major choices in [Decisions](docs/DECISIONS.md).
- Feature-specific references are linked from Architecture. Dated audits, acceptance reports and publication receipts are historical evidence, not proof of the current checkout. No task requires reading the entire docs folder.
