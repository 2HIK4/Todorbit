# Todorbit open-source readiness & PR #3 reconciliation

## Historical reconciliation (2026-11-27)

Open-source preparation work originally staged in
[PR #3 (`codex/todorbit-readiness`, commit `25097d3`)](https://github.com/2HIK4/Todorbit/pull/3)
against `feature/todorbit-release-p8` (`7f1802d`, Beta 25) was audited file by
file against `feature/todorbit-beta27-refinement` (`81a05f7`, Beta 29+):

### Code & Architecture Hardening Reconciled from PR #3
- **Retained / Forward-Ported (`0208cdd`)**: Restored clock-rollback automatic backup retention (`BackupService._pruneAutomatic(instant)` and `!age.isNegative`) in `lib/data/backup_service.dart` plus `test/backup_service_test.dart`.
- **Retained / Forward-Ported (`d356116`)**: Restored damaged full-length partial download restart without invalid EOF `Range` requests in `lib/data/resumable_update_download.dart` plus `test/resumable_update_download_test.dart`.
- **Adapted (`1559090`)**: Integrated desktop sidebar non-cancelled event search into Beta 29 `lib/features/workspace/workspace.dart` (`matchingEvents` -> `_openEventDetails`) and scaled mobile search `AppBar` height / `kMinInteractiveDimension` tap targets into Beta 29 `lib/features/mobile/mobile_workspace.dart`, plus regression tests in `test/workspace_test.dart` and `test/mobile_workspace_test.dart`.
- **Retained / Forward-Ported (`15aa1e3`)**: Enforced `export`, conditional `if (dart.library.io)` directives, and nested `lib/domain/` adaptor shadowing checks in `tools/test_architecture_boundaries.py`.

### Documentation, Community & Website Artifacts Reconciled
- **Added / Restored**: `.github/ISSUE_TEMPLATE/documentation.md`, `docs/CONTRIBUTOR_TASKS.md`, `docs/PLATFORM_SUPPORT.md`, `docs/REUSABLE_COMPONENTS.md`, `docs/OPEN_SOURCE_EVIDENCE.md`, `docs/OPEN_SOURCE_READINESS.md` (alongside the new [Feature catalogue](FEATURES.md)).
- **Updated for Beta 29+ & TDAT**: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/ISSUE_TEMPLATE/bug_report.md`, `.github/ISSUE_TEMPLATE/feature_request.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `docs/INSTALLATION.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE_MAP.md`, `docs/DEFERRED_VERIFICATION.md`, and `website/dist/` + `website/verify_live.py`.

## Release and deployment boundaries at the time

- `main` (`a6d36dc`), `Stable` tags, SQLite schema `29`, Sync protocol `2`, and release tags (`v1.0.19-beta.29`, etc.) remain untouched by readiness edits.
- GitHub Pages deployment (`https://2hik4.github.io/Todorbit/`) is gated in `.github/workflows/pages.yml` on `main` + `workflow_dispatch` (`publish_approved=true`) and requires owner PR review / workflow approval.
- Live runtime results, offline/widget verification, and remaining manual acceptance items are tracked in Test run ledger (`docs/TEST_RUN_LEDGER.md` on `feature/todorbit-beta27-refinement`) and Deferred verification (`docs/DEFERRED_VERIFICATION.md` on `feature/todorbit-beta27-refinement`).
