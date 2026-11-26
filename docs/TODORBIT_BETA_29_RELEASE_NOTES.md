# Todorbit 1.0.19-beta.29

Experimental beta for Windows x64 and Android, build 52. Uses SQLite Schema 29.

- **Task Details & Theme Dialog**: Replaces hardcoded purple accents in
  `TaskDetailsView` with active theme and semantic priority tokens, keeps the
  manual work-time entry modal scrollable above keyboards, makes `ThemeDialog`
  responsive on compact windows and phones, and wires desktop theme JSON
  import/export through the native Windows file picker.
- **Android Upcoming & Mobile Polish**: Restores planned-day group headings and
  semantic date context in Android `Upcoming`, colors priority badges on mobile
  rows and subtasks, dims completed mobile task titles, preserves `48 dp`
  subtask action targets, and fixes blank-query empty search messaging.
- **Desktop Layout & Calendar Cards**: Separates the scrollable sidebar
  navigation list from its pinned footer with a divider, aligns `Workspace`,
  `Habits`, `Goals`, and `Reports` horizontal insets and headings, uses error
  styling for destructive habit-log clearing, and shows readable start times on
  narrow overlapping Calendar week cards while preserving full time ranges in
  tooltips and accessibility semantics.
- **Reliability & Tooling**: Hardens artifact validation (`dev package`),
  offscreen screenshot rendering, worktree dependency diagnostics (`dev doctor`),
  and test isolation without altering data schemas, saved themes, or sync rules.
- **Upgrades & Data Safety**: Schema 29 compatible with Beta 28. Export a
  verified backup before updating. Use the setup installer for an installed
  Windows copy, the portable ZIP for a portable copy, or the production-signed
  APK matching your ABI on Android, and verify published SHA-256 checksums.
