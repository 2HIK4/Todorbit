# Contributing to Todorbit

Welcome! Todorbit is an open-source, local-first planner for Windows and Android. Start with the [contributor task list](docs/CONTRIBUTOR_TASKS.md) or open an issue through [GitHub Issues](https://github.com/2HIK4/Todorbit/issues/new/choose) to discuss larger behavior changes before making a focused pull request. Keep Windows desktop behavior, Android parity, and existing data compatibility intact. Preserve the optional Drive snapshot integration and incremental sync; new cloud services, synchronization, accounts, telemetry and executable theme plugins require an explicit product decision. Never use production data in tests.

### Quick Onboarding Checklist

1. Browse implemented capabilities in [Features](docs/FEATURES.md) and locate entry points in Architecture Map (`docs/ARCHITECTURE_MAP.md` on `feature/todorbit-beta27-refinement`).
2. Read [Development](docs/DEVELOPMENT.md) (including the [Windows plugin workaround](docs/DEVELOPMENT.md#windows-plugin-links) and disposable-profile setup), Android setup (`docs/ANDROID_SETUP.md` on `feature/todorbit-beta27-refinement`), [Architecture](docs/ARCHITECTURE.md), and [Testing](docs/TESTING.md).
3. Note that the public default branch can lag the experimental release line. For a reported bug, identify the installed version and its source tag on [GitHub Releases](https://github.com/2HIK4/Todorbit/releases) before selecting a base branch.
4. Bootstrap and check your environment from the repository root:
   ```powershell
   flutter.bat pub get --enforce-lockfile
   .\dev doctor
   .\dev context <feature>
   ```
5. Keep changes local to a focused branch (`feature/`, `fix/`, `docs/`), verify with `.\dev verify changed`, and check `git diff --check`.

Run focused checks while editing; broaden at integration/release checkpoints. Markdown-only edits need link/path review (`python tools/dev/check-docs.py` and `python -m unittest tools/test_workspace_paths.py`) and `git diff --check`, not application builds. Report GUI behavior you have not physically verified as pending. [Codex workflow](docs/CODEX_WORKFLOW.md) covers branches, safe handling of uncommitted work, and handoffs; [Release](docs/RELEASE.md) owns publishing gates. Publishing requires an explicit request.

---

## Architectural Layer Boundaries & Code Layout

Todorbit enforces a clean 4-tier layer structure to keep the codebase modular, testable, and maintainable:

```text
[ Presentation: lib/features/ ]
        │
        ▼
[ Presentation Orchestration: lib/app/ ]
        │
        ├──────────────────────────────┐
        ▼                              ▼
[ Pure Domain: lib/domain/ ]   [ Persistence / Data: lib/data/ ]
```

### Directory Placement Rules
1. **`lib/features/<feature>/` (Presentation UI)**:
   - Houses screens, dialogs, sheets, and modular widgets (e.g. `workspace`, `calendar`, `scheduling`, `habits`, `goals`, `time_tracking`, `settings`, `shared`).
   - **Isolation Invariant**: Leaf feature components in one feature must **never** directly import leaf components from a sibling feature (e.g., `calendar` must not import `workspace`, and `shared` must not import `settings`).
   - Shared cross-cutting presentation contracts and guards belong in `lib/features/shared/` (e.g. `unsaved_editor_guard.dart`).
2. **`lib/app/` (Presentation Orchestration)**:
   - Houses `AppController` and presentation state management. Coordinates user actions, in-memory collection views, and refresh pipelines.
   - UI widgets observe `AppController` via scoped Riverpod selectors (`ref.watch(appControllerProvider.select((c) => c.property))`) rather than coarse watches to avoid unnecessary rebuild cascades.
3. **`lib/domain/` (Pure Business Logic & Models)**:
   - Contains pure entity models, recurrence math, scheduling algorithms, and projection calculators.
   - **Purity Invariant**: Domain logic must remain pure Dart without dependencies on `package:flutter/`, `lib/app/`, or `lib/data/` (with narrowly scoped UI adaptors `appearance.dart` and `hotkeys.dart` as the sole allowable exceptions).
4. **`lib/data/` (Persistence & Infrastructure)**:
   - Houses SQLite access via Drift, `LifeRepository` and its domain-specific part files, migration gates, backup services, and cloud sync codecs.
   - **Encapsulation Invariant**: Raw database handles (`.db.transaction`, `.db.close()`) must **never** be invoked from presentation (`lib/features/`) or orchestration (`lib/app/`). All multi-record mutations must go through dedicated composite methods on `LifeRepository`.

---

## Data Safety & Concurrency Invariants

- **Zero Data Loss**: Never wipe, drop, reset, or silently overwrite SQLite tables, profile JSON files, user backups, or widget settings as an error recovery fallback.
- **Forward-Only Migrations**: All SQLite schema modifications must be forward-migrated through explicit Drift migrations and verified in `MigrationGate` (Current source: Schema 29).
- **CAS Concurrency Tokens**: Every task update must advance `updated_at` beyond the predecessor timestamp and check revision concurrency tokens via SQL compare-and-swap (CAS).
- **Atomic Multi-Record Mutations**: Operations touching multiple records or tables must execute inside an explicit SQLite transaction encapsulated within `LifeRepository`.

---

## Verification & Testing Standards

Before submitting changes, contributors must use the Developer Automation Toolkit (`docs/DEVELOPER_AUTOMATION_TOOLKIT.md` on `feature/todorbit-beta27-refinement`) (`.\dev doctor`, `.\dev context <feature>`, `.\dev verify changed`, `.\dev registry --refresh` / `--validate`) and execute verification matched to the risk boundary of the modification (see `docs/TESTING.md`):

1. **Level 1 (Fast Verification)**:
   - Formatting check: `dart format --output=none --set-exit-if-changed <paths>`
   - Static analysis: `flutter analyze --no-pub <paths>`
   - Architecture boundary enforcement: `python tools/test_architecture_boundaries.py`
   - Focused unit/widget tests: `flutter test --no-pub <test_file>`
2. **Level 2 (Critical Data-Safety & Persistence Verification)**:
   - Required for any change touching `lib/data/`, SQLite queries, migrations, CAS tokens, sync schemas, or backups.
   - Must run immediately; never deferred:
     - `flutter test --no-pub test/repository_test.dart`
     - `flutter test --no-pub test/migration_gate_test.dart`
     - `flutter test --no-pub test/database_initialization_test.dart`
     - `flutter test --no-pub test/backup_service_test.dart`
     - `flutter test --no-pub test/task_revision_concurrency_test.dart`
3. **Feature Test Catalog**:
   - Preview feature test suites defined in `tools/dev/features.json` using:
     ```powershell
     powershell -ExecutionPolicy Bypass -File tools/dev/verify.ps1 -Mode Feature -Feature <feature_name> -Plan
     ```
   - Available features: `tasks`, `calendar`, `task-timers`, `time-tracking`, `habits`, `goals`, `alarms`, `reports`, `templates`, `scheduling`, `trash`, `notifications`, `drive`, `sync`, `widgets`, `settings`, `mobile`, `database`, `android-updates`, `windows-updates`.

---

## Theming & Contributor Registry

Themes use the validated version 1 JSON format in [docs/THEMING.md](docs/THEMING.md). Include a preview from an isolated profile and check text contrast. Theme author metadata is distinct from official creator and contributor attribution.

To add a reviewed community contributor, edit `assets/contributors.json`. Records require `name`, `title`, `type`, and `description`; optional `profile` must use HTTPS and `related` can name the theme or feature. Types: `themes`, `iconSets`, `features`, `bugFixes`, `uiImprovements`, `accessibility`, `documentation`, `translations`. Do not add unreviewed theme imports to the registry. The Creator section remains fixed.

Do not submit personal databases, backups, logs, private screenshots, local settings, credentials, or signing files. See [SECURITY.md](SECURITY.md) for private vulnerability reports.
