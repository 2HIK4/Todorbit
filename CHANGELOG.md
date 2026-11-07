# Changelog

## 1.0.19-beta.13+36 - unpublished refinement candidate

- Add shared task/event filters, recurrence-family grouping and nested subtasks, customizable navigation, grouped Android Settings, and clearer optional editor fields.
- Add event-project assignments, named checklists and richer draft creation; schema 27 migrates additively and retains immutable Sync history. Update connected devices together; schema-26 clients safely refuse newer batches.
- Correct equivalent deletion conflicts, restored decision clocks, Today event windows and explicit recurring-event field clearing; preserve archive/edit and delete/edit decisions.
- Add Windows/Android widget date navigation while retaining bounded projections and device-local configuration.
- Use compact themed auto-dismissed routine Sync confirmations; keep required decisions actionable. Clarify reconnect versus account switching and add recovery-code copy control.
- Verify real Standard Sync and a scoped real Private encrypted Windows/Android round trip with synthetic accounts; keep passphrase/recovery requirements and backup/Sync separation. No workspace conversion or password rotation is introduced.
- Candidate only: see the stabilization receipt for live recovery/restore, exact artifact, CI, signing and physical-platform limits. Nothing is published or automatically distributed by this entry.

## 1.0.19-beta.12+35 - UI reliability and recovery

- Preserve task, nested subtask, recurring-series, Goal and Habit drafts through supported navigation and dismissal; retain edits after rejected saves.
- Improve Calendar labels, overnight agenda, compact forms, large-text layouts, scheduling review, reports and work-entry controls.
- Keep resource and template input available through validation/save failures; explain exclusions and duplicate names clearly.
- Preserve damaged preference bytes during startup; provide bounded recovery and Retry without resetting data.
- Retain full theme file paths, guard asynchronous transfer completion and clarify native-widget preview feedback.
- Preserve schema 26, Sync protocol/recovery requirements, backup formats, profiles, widget identity and Android production signing.
- Experimental pre-release: further tests skipped at the owner's explicit request. Earlier scoped evidence is retained; native Windows/Android and real Drive cross-device acceptance remain incomplete.

## 1.0.19-beta.11+34 - experimental Start New Sync

- Add an explicit Start New Sync flow with a verified local recovery snapshot, Standard/private setup, durable resume, complete seed readback and retryable retired-cloud cleanup.
- Isolate replacement workspace generations, preserve local histories and offline edits, detect competing replacements and reconnect updated devices safely.
- Replace vague Sync errors with typed causes and relevant actions, including Android Google sign-in and storage failures.
- Experimental: back up first. Cloud-only data can be lost; non-content safety markers remain and old devices can recreate isolated files. Live Drive and physical upgrades remain unverified. Existing-workspace conversion/passphrase changes stay unavailable.

## 1.0.19-beta.10+33 - experimental Standard and private Sync

- Default new Google Drive workspaces to Standard Sync without an extra password; detect existing modes and preserve legacy encrypted recovery.
- Offer Private Encrypted Sync for new workspaces, memorable passphrases, authenticated Argon2id key wrapping, recovery codes and protected local key retention.
- Improve shared Windows/Android Sync settings, credential forms and one-time onboarding. Keep backups independent.
- Existing-workspace encryption conversion and cloud passphrase changes remain unavailable. Real Google Drive synchronization is not yet manually verified; back up first and use disposable data.

## 1.0.19-beta.9+32 - experimental Smart Sync reliability fixes

- Accept authenticated encrypted history/proofs when an interrupted completed
  Drive upload lacks the sender's mutable readback marker. Keep AES-GCM,
  identity/digest/schema/causal checks and outgoing readback acknowledgement.
- Treat socket/HTTP transport interruption as offline so reviewed conflict
  decisions can be saved durably and uploaded after connectivity returns.
- Preserve schema 26, sync protocol 1, keys, backups and Android signing identity.
- Experimental: real Google Drive exchange remains unverified. Keep a verified
  backup, use disposable test data initially and retain the recovery code.

## 1.0.19-beta.8+31 - experimental Smart Sync

- Continue Google sign-in through secure setup and manual synchronization.
- Check on startup, throttled foreground return, active polling and debounced
  committed edits, preserving in-flight changes and controlled offline retries.
- Simplify Sync settings and one-time encrypted device authorization; retain
  recovery keys securely and keep advanced controls separate.
- Keep a counted conflict badge without automatic popups; provide individual
  and bulk review, confirmation and durable offline resolution propagation.
- Preserve schema 26, protocol 1, encrypted history, backups and signing identity.
- Experimental: independent real Drive end-to-end verification and comprehensive
  Windows/Android acceptance remain incomplete. Keep a verified backup and
  recovery code; start with disposable profiles and synthetic data.

## 1.0.19-beta.7+30 - startup lock handling

- Include the calendar appearance and editor reliability improvements below.
- Wait up to five seconds for transient SQLite locks during startup schema and
  backup integrity reads, matching live database connections. Persistent locks
  still fail safely without replacing data or bypassing integrity checks.
- Retain the unpublished beta 6 candidate and failed 16 KiB restart evidence;
  prepare beta 7 for fresh exact-source CI and signed-artifact runtime checks.

## 1.0.19-beta.6+29 - calendar appearance and editor reliability

- Honor selected event icons and explicit/category colors in mobile and native
  Windows calendar agendas, with contrast backing for light/dark surfaces.
- Preserve event/session duration when moving Start; retain deliberately edited
  End values and present all-day End consistently with stored boundaries.
- Keep color/icon, focus timer and manual-work dialogs usable in short windows,
  at large text and with the keyboard visible.
- Align mobile editor gutters, anchor settings selectors and refresh shared
  select values without replacing focus or scroll identity.
- Show More for unpinned mobile views and clarify habit repeat interval guidance.
- Preserve schema 26, signing/profile/widget identities, backups and preferences.
- Original Android error shaking remains unreproduced; physical launcher,
  assistive-technology and Windows DPI/input acceptance remain limited.

## 1.0.19-beta.5+28 - UI hierarchy refinement

- Unify page, section, item, body, helper and metadata typography; use semantic
  text colors and custom-palette surface layers in both themes.
- Compare changed sync values first, with complete records and base values
  available on demand, clear selection and fixed review actions.
- Simplify backup, pairing and update copy; keep recovery warnings visible.
- Keep the focused recovery input visible as the Android keyboard opens,
  including large text and resized windows.
- Group restore warnings and recovery steps; disclose profile IDs, paths and
  replaced settings on demand without changing replacement approval.
- Improve settings headings, task readability and small progress-entry dialogs.
- Preserve schema 26, encryption/conflict rules, profiles and package identities.
- Real Google Drive end-to-end and physical-device acceptance remain unverified.

## 1.0.19-beta.4+27 - coordinated Windows + Android pre-release

- Add encrypted incremental Google Drive sync, same-account recovery-code pairing,
  automatic exchange, Sync Now and persistent consolidated conflict review.
- Preserve both branches of meaningful conflicts and related deletion consequences;
  merge safe independent fields and retain interrupted encrypted transfers.
- Schedule bounded Android network jobs and hidden Windows companion workers,
  subject to OS authorization/scheduling and foreground privacy barriers.
- Preserve original queued history across restore reconciliation using a fresh
  device identity; report committed restores accurately as requiring restart.
- Migrate existing data to schema 26 with portable preferences and explicit timer
  ownership. Keep snapshot backups, device settings and release identities intact.
- Include Microsoft-signed C++ runtime DLLs for clean Windows installations.
- Drive validation uses mocks; real-account and physical acceptance
  remain unobserved. See docs/GOOGLE_DRIVE_SYNC.md.

## 1.0.19-beta.3+26 - Sync button preview

- Publish the initial Coming soon Sync control for Windows and Android, retaining
  schema 22. Full synchronization follows in beta 4.

## 1.0.19-beta.2+25 - Android pre-release

- Prefer smaller compatible ARM64/x86-64 APKs; retain a universal fallback and
  identical version codes and production signing across all variants.
- Retain partial update downloads through Pause/Resume, navigation and process
  restart; explicit Discard removes partial bytes. Reverify full size/hash and
  Android package/signature/device compatibility before installation.
- Show decimal KB/MB/GB download sizes, progress and speed on both updater screens.
- Distinguish development signing, unexpected publisher, package, version and
  architecture errors without bypassing protection or uninstalling user data.
- Preserve database schema 22, backups, widgets, preferences and Windows releases.

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
