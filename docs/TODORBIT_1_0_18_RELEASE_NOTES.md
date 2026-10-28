# Todorbit v1.0.18 - widget startup and appearance fixes

Windows x64 public pre-release, version **1.0.18+19**.

- Enabled Tasks and Calendar widgets return when Todorbit opens, including after an update or Exit widgets. Explicitly disabled widgets stay disabled. Windows sign-in still starts the companion without opening the full app.
- Close Widget is now temporary. Widget positions, sizes, presets, navigation, opacity and startup preferences are retained.
- Selected navigation text uses one predictable contrast rule throughout opacity adjustment. Explicit text-color overrides and text opacity are preserved.
- Planned tasks in the Calendar date grid use a subtle inset circle instead of a square touching the cell border. Event counts, session markers and date selection are unchanged.

No database/schema change. Existing local data, backups and optional Google Drive settings are preserved. A disabled preference saved by an older Close Widget action cannot be distinguished from an intentional disable; enable that widget once in Settings if needed.

Packages are unsigned. Physical display-scaling/input, Windows sign-in and registered installer execution require target-system acceptance; automated checks do not establish them. Stable update channel excludes this pre-release; choose Pre-release to receive it.
