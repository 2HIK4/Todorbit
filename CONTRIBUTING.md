# Contributing to Todorbit

Open an issue to discuss larger behavior changes, then make a focused pull request. Keep Windows desktop behavior and existing data compatibility intact. Do not add cloud services, accounts, telemetry, executable theme plugins, or production data to tests.

Run `flutter analyze`, `flutter test`, `flutter build windows --release`, and the native widget self-test for changes that touch UI or persistence. Use disposable `%APPDATA%` and `%LOCALAPPDATA%` paths for manual runs. Report GUI behavior you have not physically verified as pending.

Themes use the validated version 1 JSON format in [docs/THEMING.md](docs/THEMING.md). Include a preview from an isolated profile and check text contrast. Theme author metadata is distinct from official creator and contributor attribution.

To add a reviewed community contributor, edit `assets/contributors.json`. Records require `name`, `title`, `type`, and `description`; optional `profile` must use HTTPS and `related` can name the theme or feature. Types: `themes`, `iconSets`, `features`, `bugFixes`, `uiImprovements`, `accessibility`, `documentation`, `translations`. Do not add unreviewed theme imports to the registry. The Creator section remains fixed.

Do not submit personal databases, backups, logs, private screenshots, local settings, credentials, or signing files. See [SECURITY.md](SECURITY.md) for private vulnerability reports.
