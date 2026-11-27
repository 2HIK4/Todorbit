# Roadmap

Todorbit is in experimental release development on Windows and Android. See
[Platform support](PLATFORM_SUPPORT.md) for current distribution, caveats, and
tested configurations.

## Available now

- Local task and project planning, subtasks/checklists/dependencies, recurring
  tasks and events, interactive Day/Week/Month Calendar, habits, goals,
  progressive plans, templates, focus timers, reports, archive, and trash.
- Smart Reschedule previews with user review before applying schedule changes.
- Embedded **Settings > Hotkeys** shortcut customization, system/light/dark
  themes with JSON import/export, local SQLite snapshots, Explorer-hosted
  Windows desktop widgets (continuous pixel scrolling, surface translucency),
  Android launcher widgets, and Android Share Sheet inbox.
- Optional experimental Google Drive synchronization (`Standard` & `Private
  Encrypted`) and AES-256-GCM encrypted cloud backups. Each has its own
  [recovery requirements](GOOGLE_DRIVE_SYNC.md).

## Stabilization & Beta 30 priorities

- Validate Windows desktop widget Light/Dark wallpaper translucency, pixel
  scrolling feel, multi-monitor DPI scaling, and embedded Settings > Hotkeys
  keyboard UX on live builds.
- Expand physical keyboard/focus, screen-reader (`Narrator` / `TalkBack`),
  registered installer upgrade, and Android OEM/Share Sheet acceptance.
- Exercise interrupted restore, offline reconnect, mixed-version sync, and
  two-client Drive recovery on authorized test accounts.
- Reconcile and publish public GitHub documentation (`README.md`, feature
  catalogue, architecture docs) and `2hik4.github.io/Todorbit` website updates.

See [Deferred verification](DEFERRED_VERIFICATION.md) for open acceptance gates
and [Contributor tasks](CONTRIBUTOR_TASKS.md) for bounded ways to help.

## Longer-term research

Evaluate small reusable modules with stable contracts and tests (see
[Reuse assessment](REUSABLE_COMPONENTS.md)). Public plugin APIs, additional
platforms, and non-Drive sync providers require separate design and maintenance
commitments. The roadmap makes no fixed delivery-date guarantees.
