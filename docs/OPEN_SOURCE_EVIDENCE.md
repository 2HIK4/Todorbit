# Todorbit open-source evidence

Snapshot recorded on **2026-11-20 (Asia/Amman)**. This document can support
a funding application together with the linked evidence.

## Product and distribution

Todorbit is an independently maintained, MIT-licensed productivity app.
[Beta 25](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.25) ships
Windows x64 and Android API 26+ artifacts from source
[`6b75a55`](https://github.com/2HIK4/Todorbit/commit/6b75a559a1b7d3f9d849ba9ed27c7a291124d554).
It includes local task and project organization, calendar planning, recurring
work, habits, goals, focus and time tracking. Configuration, offline storage,
widgets and backup/restore are covered in the
[platform matrix](PLATFORM_SUPPORT.md). Optional Standard and Private Sync
and encrypted Drive snapshots remain experimental.

The automated baseline includes the published Windows Release build, native
companion self-test and installer compilation, Android validation, and
Android 16 KiB emulator upgrade/persistence. These three successful Actions
runs all record the release SHA. See [Windows run](https://github.com/2HIK4/Todorbit/actions/runs/44694169827),
[Android run](https://github.com/2HIK4/Todorbit/actions/runs/44694185735), and
[16 KiB runtime run](https://github.com/2HIK4/Todorbit/actions/runs/44699666409).

Current candidate work and tests are in [Open-source readiness](OPEN_SOURCE_READINESS.md)
and the [test ledger](TEST_RUN_LEDGER.md). Physical Windows keyboard/focus and
multi-monitor DPI, Android Share Sheet and installer journeys, broadened
assistive technology checks, and real-account acceptance still need evidence.
See [deferred verification](DEFERRED_VERIFICATION.md).

## Public activity

| Measure | Observed |
| --- | --- |
| Beta 25 Windows installer downloads | 4 |
| Beta 25 Windows portable ZIP downloads | 2 |
| Beta 25 Android universal APK downloads | 3 |
| Published GitHub releases | 38 |
| Public pull requests | 2 from the repository owner, including 1 merged and 1 open |

Sources are the [beta 25 release API](https://api.github.com/repos/2HIK4/Todorbit/releases/tags/v1.0.19-beta.25),
the [release list](https://github.com/2HIK4/Todorbit/releases), and the
[public pull request history](https://github.com/2HIK4/Todorbit/pulls?q=is%3Apr).
GitHub's asset counters can include repeat downloads. There is no verified
count of distinct users, installations, or regular users.

## Next public milestones

The [roadmap](ROADMAP.md) prioritizes reliability, accessibility and safe
packaging. The [contributor task list](CONTRIBUTOR_TASKS.md) shows practical
places where community help would matter. Maintainers can update progress
through the existing [changelog](../CHANGELOG.md) and publication receipts.
The in-app Support screen offers optional project support where available.
