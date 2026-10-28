# Todorbit 1.0.17 — Windows x64 pre-release

Version **1.0.17+18** adds persistent widget customization, optional task reminders
and direct navigation to existing editors. Windows 11 is the primary test platform;
Windows 10 compatibility remains limited. Packages are unsigned.

## Widgets and settings

- Drag Tasks navigation destinations into any order or use the Up/Down controls.
  Hidden items retain their positions across top/bottom/side layouts and restarts.
- Choose five built-in presets for each widget. Save, rename, duplicate and delete
  custom presets independently. Preset previews use the existing Apply/Cancel flow.
- Undo/Redo settings with Ctrl+Z, Ctrl+Shift+Z or Ctrl+Y in widget, theme,
  task-display and sidebar contexts. Slider drags count as one change; focused
  text fields retain text Undo/Redo.
- Independently customize task-row, hover and selected-navigation backgrounds,
  foregrounds and opacity. Overall shell opacity does not multiply text/row alpha.
- Drag the Calendar divider or adjust Calendar share to allocate space to its
  date grid and scrolling agenda. Saved proportions respect usable minimum sizes.
- Event indicators show no mark for zero events, one to three dots, or one line
  for four or more. Cancelled/duplicate occurrences do not inflate counts;
  task/session markers remain separate.

## Tasks and navigation

- Task notifications are **Off by default**. Explicitly select a custom date/time
  or an offset from the next upcoming work session. Planned days and deadlines
  have no clock time and remain separate. Recurring settings apply to the selected
  task occurrence; future tasks are not silently enabled.
- The existing companion timer, privacy behavior and duplicate-delivery ledger
  support reminders while the main window is closed. Delivery requires the
  companion and Windows notification availability; missed reminders beyond the
  existing five-minute window are not replayed.
- Widget rows open the selected task, event occurrence or session directly in
  Todorbit. The old intermediate Scheduled item popup is removed. Checkboxes
  still complete tasks directly. Activation reuses the existing main instance,
  defers during active editing/modal sessions and reports missing targets.
- Audit fixes let ordinary edits preserve an unchanged past reminder, protect
  drafts opened during asynchronous navigation, and separate compact indicators.

## Upgrade and backup safety

Create a verified backup before upgrading from v1.0.16. Database schema **22**
adds per-task reminder configuration and delivery claims. The existing approval
and verified Before upgrade backup gate applies; an older executable cannot open
the migrated database. Binary rollback does not reverse database migration.

Widget appearance, navigation order, split proportions and custom presets now
travel through settings export/import, local SQLite snapshots and encrypted Drive
snapshots. Visibility, geometry, startup and layout lock remain device-local.
Existing profile paths and installer identity are unchanged. Portable updates
must retain the exact application path to retain their location-derived profile.

Google Drive remains experimental, using the established packaged Desktop
configuration; source defaults remain disabled. Branding/policy limitations are
unresolved. This is snapshot backup/restore, not synchronization.

## Verification and limits

Final exact-source CI, artifact/hash, backup/migration and v1.0.16 updater results
are recorded in the publication receipt linked from repository Progress. Automated
widget/layout/recurrence tests, native self-tests and isolated runtime checks do
not establish physical DPI/monitor behavior, Explorer restart/Win+D, screen-reader
acceptance, actual OS notification receipt or registered installer execution.

Choose **Pre-release** in Settings > Software Updates to receive this update.
Stable excludes pre-releases. Compare downloads with the published SHA-256 files;
checksums establish integrity and are not a publisher signature.
