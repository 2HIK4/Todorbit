# Todorbit open-source evidence

Snapshot recorded on **2026-11-27 (UTC+03:00)**. This document summarizes
publicly verifiable evidence of Todorbit's engineering maturity and distribution
without inventing user counts, telemetry, or adoption metrics.

## Product and distribution

Todorbit is an independently maintained, MIT-licensed cross-platform planner
for Windows x64 (`Workspace` + native .NET 10 Explorer-hosted
`TodorbitWidget.exe`) and Android API 26+ (`MobileWorkspace` + `RemoteViews`
home-screen widgets).
[Beta 29 (`v1.0.19-beta.29`)](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.29)
ships Windows x64 and Android ARM64/x86-64/universal packages from source
[`bd9d337`](https://github.com/2HIK4/Todorbit/commit/bd9d3375d03964377110943eb7b7a0acd0acc691)
on SQLite schema 29. See [Platform support](PLATFORM_SUPPORT.md) and the full
[Feature catalogue](FEATURES.md). Optional Google Drive Sync and AES-256-GCM
cloud backups remain experimental.

The verified automated CI baseline on `bd9d337` includes:
- [Windows checks (`45777666379`)](https://github.com/2HIK4/Todorbit/actions/runs/45777666379): full Dart analysis & serial Flutter tests, TDAT safety/registry/docs checks, Windows Release build, CRT packaging gate, portable ZIP (`1.0.19.52`), native sync writer/background barriers, `TodorbitWidget.exe --self-test`, Inno Setup installer compilation, and SHA-256 checksums.
- [Android validation (`45777673011`)](https://github.com/2HIK4/Todorbit/actions/runs/45777673011): static analysis, mobile Flutter suites, release verification (`test_prepare_android_release.py`), APK validation, and API 35 KVM emulator run.
- [Android 16 KiB runtime (`45784257387`)](https://github.com/2HIK4/Todorbit/actions/runs/45784257387): API 36 `PAGE_SIZE=16384` in-place upgrade (`build 51 -> 52`) retaining synthetic planner state across upgrade.

Current post-Beta 29 readiness work, widget theme/pixel-scroll fixes, embedded
Settings > Hotkeys, PR #3 reliability recovery, and open physical/manual
acceptance gates are recorded in [Open-source readiness](OPEN_SOURCE_READINESS.md),
[Test run ledger](TEST_RUN_LEDGER.md), and [Deferred verification](DEFERRED_VERIFICATION.md).

## Public activity (verified via GitHub API on 2026-11-27)

| Measure | Observed |
| --- | --- |
| Published GitHub releases | 43 (no Stable release published yet; `/releases/latest` returns 404) |
| Beta 29 Windows setup downloads (`Todorbit-1.0.19-beta.29-win-x64-setup.exe`) | 3 |
| Beta 29 Windows portable ZIP downloads (`Todorbit-1.0.19-beta.29-win-x64-portable.zip`) | 2 |
| Beta 29 Android APK downloads (`universal` + `arm64` + `x64`) | 7 (2 universal, 2 arm64, 3 x64) |
| Public pull requests | 6 from the repository owner (3 merged: #1, #4, #5; 3 open: #2, #3, #6) |

Sources: [Beta 29 release API](https://api.github.com/repos/2HIK4/Todorbit/releases/tags/v1.0.19-beta.29),
[all releases](https://github.com/2HIK4/Todorbit/releases), and
[pull requests](https://github.com/2HIK4/Todorbit/pulls?q=is%3Apr). GitHub asset
download counters include maintainer verification checks and repeat fetches;
Todorbit collects zero analytics or user telemetry, so distinct active users
are unknown.

## Next public milestones

- Prioritize the reliability, accessibility, and multi-monitor/device manual acceptance gates in [Deferred verification](DEFERRED_VERIFICATION.md) and [Roadmap](ROADMAP.md).
- Onboard community contributors cleanly using [CONTRIBUTING.md](../CONTRIBUTING.md), [Contributor tasks](CONTRIBUTOR_TASKS.md), and the [TDAT engineering toolkit](DEVELOPER_AUTOMATION_TOOLKIT.md).
- Synchronize the public default branch (`main`) and [GitHub Pages site](https://2hik4.github.io/Todorbit/) documentation without modifying Stable application binaries until owner release approval.
