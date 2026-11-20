# Todorbit open-source readiness

## Baseline

- Working branch: `codex/todorbit-readiness`, isolated managed checkout named `todorbit-readiness` from `D:/AI_Projects/life_manager`.
- Review base: `7f1802d66b2bdff6989ad354d7c13a73c04392cd` (`origin/feature/todorbit-release-p8`). The five files changed after the release tag are publication notes and evidence. The original checkout (`5803e52`, beta 23 development line) and its three untracked documents stay in place.
- Public [beta 25](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.25): `1.0.19-beta.25+48` at `6b75a559a1b7d3f9d849ba9ed27c7a291124d554`, SQLite schema 29, Windows x64 and Android API 26+ (ARM64/x86-64). The [public default branch](https://github.com/2HIK4/Todorbit/tree/a6d36dc7ed2863a40b7e9bc9c4cdbebc81f2c530) is still on the v1.0.18 line. The GitHub latest Stable endpoint returned 404 on 2026-11-20.
- GitHub API confirmed success on the exact release commit for [Windows](https://github.com/2HIK4/Todorbit/actions/runs/44694169827), [Android CI](https://github.com/2HIK4/Todorbit/actions/runs/44694185735), and [Android 16 KiB emulator runtime](https://github.com/2HIK4/Todorbit/actions/runs/44699666409). These are baseline receipts. See the [publication record](UIUX06_BETA_25_PUBLICATION.md) and [deferred verification](DEFERRED_VERIFICATION.md) for physical and real-account acceptance.
- Existing building blocks: ARCH-02 through ARCH-09, layered feature/controller/domain/data code, shared theme tokens and controls, independent desktop/mobile shells, a feature test catalog, CI architecture gates, and manual approval for Pages deployment.

## Execution

| Priority | Evidence and work | Acceptance and verification |
| --- | --- | --- |
| P0 | README and live Pages describe older releases. The current release exposes separate Windows/Android downloads and checksum files. | README, installation, platform matrix and website identify the experimental artifacts and privacy/recovery distinctions. Verify published URLs and render the local Pages candidate. |
| P0/P1 | Verify reported phantom conflicts and assess backup/update recovery on the published source. The conflict count and review already share a resolution reader. Reproduce any new defect with disposable files. | Preserve SQLite schema, journals, encryption, signing and recovery rules. Execute failing-then-passing tests for changed critical behavior and neighboring cases. |
| P1 | Check desktop and Android search entry points and compact layout. Review the prior UI work to avoid duplicate fixes. | Use existing search and navigation boundaries. Test affected filters and interactions on representative compact and desktop layouts. |
| P1/P2 | Android onboarding and roadmap contain historical version/branch statements. Templates omit Android details, feature requests, and docs changes. ARCH-09 does not reject direct feature/platform imports in domain. | Provide a usable developer first run and safe issue/PR instructions. Extend existing architecture tooling and validate it against fixtures and source. |
| P2/P3 | Review reuse candidates, separately record available evidence of use, and scope actionable contributor work. | Preserve runtime contracts and license. Substantiate metrics from public sources, with release downloads labeled as asset counters. Extract only if a candidate has a justified stable interface. |

The coordinator owns contributor files, architecture tooling, integration and evidence. Presentation, reliability, and application UI have separate file owners. Review the complete integration with an independent agent before delivery. Keep test commands and results in [the test ledger](TEST_RUN_LEDGER.md) and unfinished acceptance in [deferred verification](DEFERRED_VERIFICATION.md).

## Initial checkpoint, 2026-11-20

- Verified the original checkout, existing parallel worktrees, public tags, API release metadata and exact-source CI. No release tags moved. The readiness branch starts from the release preparation branch so its PR can show a focused diff.
- Local Flutter 3.47.7 / Dart 3.13.5 matches CI. The locked offline dependency resolution succeeded but Flutter returned a Windows symlink error. The existing `tools/dev/prepare-windows-plugins.ps1` workaround verified four generated junctions in the isolated checkout without changing Windows settings.
- Baseline local documentation routing check reported zero errors and all 39 architecture checks passed.
- Next action: implement the scoped findings and verify each changed boundary from the readiness checkout. Real accounts, personal profiles, and release publication are outside this run.

## Implementation and verification checkpoint, 2026-11-20 18:07 UTC+03:00

Reviewed source through `a72ecaf5a8490a65c7fbad1836bdcf5c71d12f05`. The locked dependency blob is `d8bcda914402d58613854dcce3b2e6ae6d461f76` and the analysis configuration blob is `b184301c4d403ce431eb7a76613f9c30be8fa309`. Host runtime is Windows with Flutter 3.47.7 and Dart 3.13.5. Flutter tests inherited fresh temporary APPDATA and LOCALAPPDATA directories and used synthetic records or loopback endpoints.

- **P1 backup recovery**: negative backup ages no longer suppress a daily snapshot. Independent review identified a second-day retention issue. Retention now favors chronological history at or before the corrected clock, within the existing automatic retention limit.
- **P1 updater recovery**: retry a failed checksum on a full-length saved update from byte zero, avoiding an impossible range at EOF. Existing release identity, size/digest, and Android native signature checks still apply.
- **P1 application search**: desktop sidebar returns matching non-cancelled events from the loaded window through the existing guarded editor. Android search grows with scaled text and preserves touch targets and results above a simulated keyboard.
- **P1/P2 presentation and contributor work**: beta 25 install guidance, platform matrix, website candidate, security reporting, onboarding, roadmap, starter tasks, reuse assessment, and public activity evidence. Windows plugin setup accepts correct junctions on safe reruns. Architecture and test receipts now cover the actual platform dialog and prevent direct platform or feature dependencies from the domain.
- **P1 sync investigation**: the published conflict count and review share the same reader. Synthetic checks covered genuine conflicts, offline decisions retained across restart, retry and cursor behavior, and Standard/Private exchange. No sync protocol, SQLite schema, data location, or release artifact changes.

| Invocation / scope | Source and result | Purpose |
| --- | --- | --- |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/backup_service_test.dart test/database_startup_contention_test.dart test/migration_gate_test.dart test/resumable_update_download_test.dart test/software_update_service_test.dart test/android_update_service_test.dart test/sync_apply_repository_test.dart test/cloud/sync_engine_test.dart` | 92 passed on base plus the first reliability fixes. Updater source blob `b395673dcc6644b70bbbaf5e3be0a7dcd6303f3e` is unchanged since this run. | Both new tests initially failed on the baseline, then passed. Adjacent backup, migration, download, and sync checks. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded --name 'clock rollback creates and retains' test/backup_service_test.dart` | Failed on the first fix when the next day's backup pruned the previous one. The expanded regression passed after the retention correction in the integrated suite. | Verify independent review's retention finding at capacity. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded --name 'sidebar search opens events\|mobile search fits large text' test/workspace_test.dart test/mobile_workspace_test.dart` | 2 passed after both tests reproduced the failures. | Event search, dirty editor guard, 320 × 640 layout with 2× text and a 260 dp simulated keyboard. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/backup_service_test.dart test/database_startup_contention_test.dart test/cross_platform_backup_test.dart test/workspace_test.dart test/mobile_workspace_test.dart test/prompt1_search_and_detail_presentation_test.dart test/advanced_search_widget_test.dart` | 74 passed in 3m16s on the integrated app and test source. | Verify the corrected backup retention and neighboring startup/restore, desktop and Android workspace, and detail/search behavior. |
| `flutter analyze --no-pub lib test integration_test test_driver` | No issues found on integrated app and test source. | Check changed code and unchanged callers. |
| `python tools/test_architecture_boundaries.py` | 39 passed. Expanded domain fixture initially failed on the old checker. | Direct, exported and conditional boundary enforcement, including legacy exception path. |
| `python -m unittest discover -s tools -p test_dev_verify.py` and `python -m unittest discover -s tools -p test_ci_workflows.py` | 9 and 5 passed. | Reuse existing developer tool and workflow contracts. |
| `python tools/dev/check-docs.py` and scoped runs on presentation, security and evidence docs | Zero local link, architecture map, or feature catalog errors. | Validate current guides and new developer links. |
| `python website/verify.py` and `python website/verify_live.py --preview` | Three static pages, 15 public HTTPS links, and three checksum entries matched GitHub asset metadata. A fixture confirmed newer platform-only releases and drafts are skipped. | Test the candidate independently of deployment. Package binaries were not rehashed by this check. |
| Isolated Chrome preview | 24 combinations of page, viewport width (320, 375, 768, 1440) and light/dark. Images loaded, no horizontal overflow, keyboard skip links and Android download jump worked. | Live site still renders v1.0.14. The actual screenshot in the candidate is labeled v1.0.12. |
| `tools/dev/prepare-windows-plugins.ps1` | Existing correct four junctions reproduced the scalar-target failure in PowerShell 7.6.9. Two reruns passed after the fix. A disposable fixture confirmed wrong targets fail without replacement and PowerShell 5.1 reruns pass. | Verify developer setup idempotence. |
| PowerShell AST and hash receipt check | All 14 profile journey receipt paths exist. A change to the actual platform resource dialog now affects its fingerprint. | Validate the receipt change without running an application against a user profile. |
| [OSV querybatch](https://google.github.io/osv.dev/post-v1-querybatch/) | Zero advisory matches for the 115 hosted Pub versions in the locked dependency file. | Scoped advisory lookup. Native runtime, framework, and GitHub Action dependencies were outside this lookup. |

The independent review covered data safety, sync, security, desktop and Android
compatibility, architecture, public claims, and release routing. It led to the
retention and plugin-helper fixes and corrections to the Android update and
Drive guides. The [deferred verification list](DEFERRED_VERIFICATION.md)
records outstanding platform acceptance.
