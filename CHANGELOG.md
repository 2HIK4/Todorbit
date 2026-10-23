# Changelog

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
