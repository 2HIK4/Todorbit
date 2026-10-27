# Contributing to Todorbit

Open an issue to discuss larger behavior changes, then make a focused pull request. Keep Windows desktop behavior and existing data compatibility intact. Preserve the optional Drive snapshot integration; new cloud services, synchronization, accounts, telemetry and executable theme plugins require a product decision. Never use production data in tests.

Start with [Development](docs/DEVELOPMENT.md) for toolchain and isolated-profile setup, [Architecture](docs/ARCHITECTURE.md) for implementation locations, and [Testing](docs/TESTING.md) for checks matched to the changed boundary. Run focused checks while editing; broaden at integration/release checkpoints. Markdown-only edits need link/path review and `git diff --check`, not application builds. Report GUI behavior you have not physically verified as pending. [Codex workflow](docs/CODEX_WORKFLOW.md) covers branches, safe handling of uncommitted work and handoffs; [Release](docs/RELEASE.md) owns publishing gates. Publishing requires an explicit request.

Themes use the validated version 1 JSON format in [docs/THEMING.md](docs/THEMING.md). Include a preview from an isolated profile and check text contrast. Theme author metadata is distinct from official creator and contributor attribution.

To add a reviewed community contributor, edit `assets/contributors.json`. Records require `name`, `title`, `type`, and `description`; optional `profile` must use HTTPS and `related` can name the theme or feature. Types: `themes`, `iconSets`, `features`, `bugFixes`, `uiImprovements`, `accessibility`, `documentation`, `translations`. Do not add unreviewed theme imports to the registry. The Creator section remains fixed.

Do not submit personal databases, backups, logs, private screenshots, local settings, credentials, or signing files. See [SECURITY.md](SECURITY.md) for private vulnerability reports.
