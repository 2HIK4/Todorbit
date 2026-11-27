# Todorbit open-source evidence

Snapshot recorded on **2026-11-27 (UTC+03:00)**. This document summarizes
publicly verifiable evidence of Todorbit's engineering maturity and distribution
without inventing user counts, telemetry, or adoption metrics.

## Product and distribution

Todorbit is an independently maintained, MIT-licensed cross-platform planner
for Windows x64 (`Workspace` + native .NET 10 Explorer-hosted
`TodorbitWidget.exe`) and Android API 26+ (`MobileWorkspace` + `RemoteViews`
home-screen widgets).
[Beta 30 (`v1.0.19-beta.30`)](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30)
ships Windows x64 and Android ARM64/x86-64/universal packages from source
[`253f4ed`](https://github.com/2HIK4/Todorbit/commit/253f4ed560018bfbb9acc9f1e110c823c77041d1)
on SQLite schema 29. See [Platform support](PLATFORM_SUPPORT.md) and the full
[Feature catalogue](FEATURES.md). Optional Google Drive Sync and AES-256-GCM
cloud backups remain experimental.

The verified automated CI baseline on `253f4ed` includes:
- [Windows checks (`46066659736`)](https://github.com/2HIK4/Todorbit/actions/runs/46066659736): full Dart analysis & serial Flutter tests, TDAT safety/watchdog/hygiene/registry/docs checks, Windows Release build (`googleDriveEnabled: true`), Microsoft-signed CRT packaging gate, portable ZIP (`1.0.19.53`), native sync writer/background barriers, `TodorbitWidget.exe --self-test`, Inno Setup installer compilation, and SHA-256 checksums.
- [Android validation (`46066664484`)](https://github.com/2HIK4/Todorbit/actions/runs/46066664484): static analysis, mobile Flutter suites, release verification (`test_prepare_android_release.py`), APK validation, and API 35 KVM emulator run.
- [Android 16 KiB runtime (`46068388702`)](https://github.com/2HIK4/Todorbit/actions/runs/46068388702): API 36 `PAGE_SIZE=16384` in-place upgrade (`build 52 -> 53`) retaining synthetic planner state across upgrade.

Exact Beta 30 asset digests, portable upgrade verification, and open physical/manual
acceptance gates are recorded in [Beta 30 candidate receipt](TODORBIT_BETA_30_CANDIDATE.md),
[Test run ledger](TEST_RUN_LEDGER.md), and [Deferred verification](DEFERRED_VERIFICATION.md).

## Public activity (verified via GitHub API on 2026-11-27 / 2026-11-28 UTC+03:00)

| Measure | Observed |
| --- | --- |
| Published GitHub releases | 44 (no Stable release published yet; `/releases/latest` returns 404) |
| Beta 29 Windows setup downloads (`Todorbit-1.0.19-beta.29-win-x64-setup.exe`) | 11 |
| Beta 29 Windows portable ZIP downloads (`Todorbit-1.0.19-beta.29-win-x64-portable.zip`) | 28 |
| Beta 29 Android APK downloads (`universal` + `arm64` + `x64`) | 7+ (prior Beta 29 line prior to Beta 30 publication) |
| Public pull requests | 6 from the repository owner (4 merged: #1, #4, #5, #6; 2 open: #2, #3) |

Sources: [Beta 30 release API](https://api.github.com/repos/2HIK4/Todorbit/releases/tags/v1.0.19-beta.30),
[all releases](https://github.com/2HIK4/Todorbit/releases), and
[pull requests](https://github.com/2HIK4/Todorbit/pulls?q=is%3Apr). GitHub asset
download counters include maintainer verification checks and repeat fetches;
Todorbit collects zero analytics or user telemetry, so distinct active users
are unknown.

## Next public milestones

- Prioritize the reliability, accessibility, and multi-monitor/device manual acceptance gates in [Deferred verification](DEFERRED_VERIFICATION.md) and [Roadmap](ROADMAP.md).
- Onboard community contributors cleanly using [CONTRIBUTING.md](../CONTRIBUTING.md), [Contributor tasks](CONTRIBUTOR_TASKS.md), and the [TDAT engineering toolkit](DEVELOPER_AUTOMATION_TOOLKIT.md).
- Public default branch (`main`, synchronized via [PR #6](https://github.com/2HIK4/Todorbit/pull/6)) and [GitHub Pages site](https://2hik4.github.io/Todorbit/) (deployed via [`46065232969`](https://github.com/2HIK4/Todorbit/actions/runs/46065232969)) are live without modifying Stable application binaries until owner release approval.
