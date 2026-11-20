# Roadmap

Todorbit is in experimental release development on Windows and Android. See
[platform support](PLATFORM_SUPPORT.md) for current distribution, caveats and
tested configurations.

## Available now

- Local task and project planning, recurring tasks and events, calendar views,
  habits, goals, focus timers, and time tracking.
- Smart Reschedule previews with user review before applying changes.
- Theme customization, local snapshots and recovery copies, and
  platform-specific widgets.
- Optional experimental Google Drive synchronization and encrypted snapshot
  backups. Each has its own [recovery requirements](GOOGLE_DRIVE_SYNC.md).

## Stabilization priorities

- Verify install and upgrade paths on supported Windows and Android devices
  using disposable data and the release checklist.
- Expand manual keyboard, focus, scaling, TalkBack, and widget acceptance.
- Exercise interrupted restore, offline reconnect, mixed-version sync,
  attachment transfer, and recovery with approved test accounts.
- Measure responsiveness with representative large profiles before changing
  cache or startup behavior.

See [deferred verification](DEFERRED_VERIFICATION.md) for evidence gaps and
[contributor tasks](CONTRIBUTOR_TASKS.md) for bounded ways to help.

## Planned improvements

- Improve accessible navigation and feedback for planning, sync, and recovery.
- Keep install guidance, screenshots, and platform limitations current as
  experimental releases advance.
- Improve developer entry points and automated checks for shared features.
- Develop a repeatable process for theme examples and community documentation.

## Longer-term research

Evaluate small reusable modules with stable contracts and tests. See the
[reuse assessment](REUSABLE_COMPONENTS.md). Plugin APIs, additional platform
releases and alternative sync providers need separate design and maintenance
decisions. The roadmap makes no delivery-date commitments.
