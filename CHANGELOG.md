# Changelog

## 1.0.19-beta.1+23 - Android candidate (unpublished)

- Prepare the first production-signed Android beta with the permanent publisher
  identity; retain Android 8+ and universal ARM64/x86-64 packaging.
- Include the mobile UI, Tasks/Calendar widget routing and guarded completion
  refinements recorded in `docs/ANDROID_UI_REDESIGN.md`.
- Preserve encrypted snapshot recovery and optional Google Drive; production
  account acceptance and same-signer installer acceptance gate publication.
- Existing published Windows tags and assets remain unchanged. Native version
  metadata stays synchronized with the candidate source for regression builds.

## 1.0.18+19

- Restore enabled Tasks and Calendar widgets when opening Todorbit, including after updates and temporary widget closure. Closing a widget no longer disables its saved setting.
- Keep explicit disabled preferences, customization, geometry and sign-in policy intact; safely default missing enabled fields by widget kind.
- Use a single contrast decision for selected widget navigation text during opacity changes, preserving custom text colors and independent alpha.
- Replace the Calendar grid's planned-task square with a padded, background-derived circle. Event dots/lines, session markers and date selection retain their meanings.


## 1.0.17 - Windows x64 pre-release

- Reorder widget navigation, save per-widget presets, and undo/redo settings changes.
- Customize task-row and selected-navigation colors/opacity independently. Resize the Calendar/agenda split and see exact event-count indicators.
- Add explicit, default-Off task reminders using custom times or work-session offsets; retain existing reminder behavior.
- Open actual task/event/session editors directly from widgets, with single-instance readiness and protection for active drafts.
- Include portable widget configurations/presets in settings transfers and local/Drive backups. Schema 22 migration requires approval and a verified backup.
- Final audit fixes old-reminder editing, startup navigation races and overlapping compact Calendar markers.

## 1.0.9 — Windows x64 pre-release

- Anchored form selection menus below their controls with viewport bounds, scrollbars, and consistent selection marks. Updated Software Updates and Backup & Restore spacing.
- Added About this view popovers to Habits, Goals, Calendar, and Reports using the shared task-view control.
- Enabled per-profile widget launch at Windows sign-in by default, with a Settings toggle and startup path repair when a Release app opens. Preserved explicit off preferences.
- Replaced updater helper's `Get-FileHash` dependency with the .NET SHA-256 API for Windows PowerShell compatibility.

## 1.0.8 — Windows x64 pre-release

- Repaired update helper startup handoff and surfaced preflight errors before the app closes.
- Simplified Software Updates with a short release summary and collapsible Markdown details.

## 1.0.7 — Windows x64 pre-release

- Added selective, versioned JSON export and import for appearance, hotkeys, Calendar, navigation, and task display preferences, with validation, preview, and optional hotkey preset merge.
- Clarified Backup & Restore actions and snapshot contents. A queued restore now reports success only after its database has opened; an older restored database still requires reviewed migration approval.
- Kept Calendar header and segmented controls stable across views and refined the themed event color picker, hotkey preset actions, and Backups sidebar alignment.
- Verified synthetic older-schema restore and isolated profile behavior. Installed upgrade and physical native widget checks remain open.

## 1.0.6 — Windows x64 pre-release

- Added Calendar event detail fields, category event colors, a custom color picker, and clearer Event editing.
- Added configurable first weekday, sidebar order, and restored Calendar view preference.
- Added Settings > Software Updates with release selection, SHA-256 validation, explicit unsigned-package confirmation, and portable update rollback.
- Advanced the database to schema 21. Older profiles require approval and a verified backup before migration; installed and portable profile locations remain stable.
- Improved narrow dialog layouts and field spacing across Calendar, Habit, Goal, Search, and Template flows.
- Verified a disposable portable upgrade. Installed upgrade and physical native widget acceptance remain open.

## 1.0.5 — Windows x64 pre-release

- Improved task creation and editing with draft checklist items and subtasks, independent scheduling fields, Today defaults, Anytime behavior, and completed-task display preferences.
- Added inline local spelling underlines, editable keyboard shortcuts and presets, selectable and expandable checklist text, and Explorer file drop for resources.
- Refined Settings, themes, task editor layout, and view information popovers.
- Redesigned the native Windows widget editor, date and choice controls, menu, and Quick Add styling; improved movement, sizing, profile isolation, and single-instance activation.
- Kept the existing database schema and legacy data paths. Physical widget, Windows 10, and installed upgrade/uninstall acceptance remain limited; see [acceptance status](docs/ACCEPTANCE.md).

## 1.0.3 — Todorbit release candidate

- Adopted the creator-approved MIT license and changed the public name from TodoPilot to Todorbit while preserving installer and data identities.
- Synchronized native widget versioning with the app and added version checks to both package builders.
- Added native third-party license files, Windows CI, and portable upgrade guidance. Installed rename/upgrade and full desktop widget acceptance remain open.

## 1.0.2 — release candidate preparation

- Replaced the in-app sidebar's black-tile mark with the transparent outlined orbit used in the Windows title bar. The executable and installer retain the black-tile icon.
- Rejected stale Life Manager executables during packaging and generated the installer filename from the application version.
- Completed another automated release gate. Public release remains pending license, name, and Windows GUI acceptance.

## 1.0.0 — release candidate preparation

- Rebranded the Windows app and native widget as TodoPilot while retaining the Life Manager data path and installer upgrade identity.
- Added independent light/dark palette editing, theme JSON validation and presets, a Contributors view, and native widget context menu, layout lock, flexible size, and alpha background painting.
- Prepared Windows installer and portable packaging. Public release and native GUI acceptance are pending.
