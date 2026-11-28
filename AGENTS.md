# Todorbit working rules

## Scope and safety

- The current public Experimental Todorbit planner supports Windows x64 and Android. This default branch contains older Windows app source alongside the public documentation and site. See [Contributing](CONTRIBUTING.md#choose-your-base) for source and release routing.
- Preserve the existing behavior of this branch, including optional Drive snapshots and local planner data. The published Experimental build has its own optional Sync scope and evidence in the [feature catalogue](docs/FEATURES.md).
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
- Use focused tests/analysis while editing. Broaden for integration, data safety, shared behavior or release risk; do not repeat full suites for small unrelated edits. [Testing](docs/TESTING.md) owns commands and scope.
- Use connected Dart/Flutter MCP diagnostics and live inspection when relevant. Visually verify UI in an isolated profile when practical. Never test against personal data; verify child-process `APPDATA`, `LOCALAPPDATA` and resolved profile first.
- Native painting, shell attachment, input, DPI or menu changes require native Release/self-test plus the relevant [manual widget checklist](docs/windows-widget.md). Automated tests do not prove physical Windows behavior; report unobserved behavior accurately.
- Review diffs and run `git diff --check`. Do not commit builds, caches, secrets, credentials or machine-specific settings.
- Do not publish a release unless explicitly requested. Preserve version synchronization, CI, installer, updater and checksum gates in [release preparation](docs/RELEASE.md). Documentation-only work needs no version bump or package rebuild.

## Public presentation maintenance

- Update the feature catalogue, platform matrix, relevant user guides, and changelog or release notes together when release behavior changes. Tie claims to source, tests, and separately labeled runtime evidence.
- Link each release claim to a specific public tag or commit. Distinguish the current Experimental release, app development, the older default-branch source, and the Stable update channel.
- For public Markdown run python tools/dev/check-docs.py. For Pages changes run python website/verify.py and check the served preview on narrow and wide viewports, both themes, keyboard navigation, and affected download paths.
- Use isolated synthetic records for screenshot captures. Label runtime and offscreen captures and record their provenance. Preserve signing, OAuth, data-storage, and platform limitations in public copy.
- Reconcile release and checksum links against published assets before requesting deployment. Keep website publication under the existing maintainer workflow.

## Skills and documentation routing

- Use `.agents/skills/todorbit-regression/SKILL.md` for code validation/release checkpoints and `.agents/skills/todorbit-ui-review/SKILL.md` for UI audits or cross-screen changes.
- Use installed UI UX Pro Max for substantial interface design when helpful; use specialized Dart/Flutter or other skills only when they materially help. Do not load every skill. Windows guidance and Todorbit tokens remain authoritative for this app.
- [README](README.md): public introduction; [CONTRIBUTING](CONTRIBUTING.md): onboarding.
- [Architecture](docs/ARCHITECTURE.md): subsystem locations, relationships and constraints; [Development](docs/DEVELOPMENT.md): toolchain, build/profile setup; [Testing](docs/TESTING.md): checks by risk.
- [Codex workflow](docs/CODEX_WORKFLOW.md): task execution and handoffs; [Release](docs/RELEASE.md): packaging/publishing; [Updates](docs/SOFTWARE_UPDATES.md): updater protocol/recovery.
- Consult [Progress](docs/PROGRESS.md) when choosing the next product task or preparing a handoff; add a short checkpoint after meaningful work. Record major choices in [Decisions](docs/DECISIONS.md).
- Feature-specific references are linked from Architecture. Dated audits, acceptance reports and publication receipts are historical evidence, not proof of the current checkout. No task requires reading the entire docs folder.
