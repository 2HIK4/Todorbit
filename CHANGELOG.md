# Changelog

## 1.0.19-beta.19+42 - independent calendar and date rollover corrections

- Preserve later task/event edits and work-session outcomes when undoing or redoing calendar dates and times.
- Preserve the original start offset when dragging an overnight/multi-day continuation; expose resize handles only at real event boundaries.
- Keep the minimum resize duration at midnight and allow an end time exactly at midnight.
- Refresh Today event projections and recurring tasks at date rollover; prevent disposed controllers from restarting timers.
- Present failed calendar edits/history as dismissible errors while retaining failed history entries.
- Correct the concurrent SQLite lease-test setup race and the overstated Beta 17/18 CI receipts. Candidate release gates remain pending until recorded separately.

## 1.0.19-beta.18+41 - calendar keyboard undo/redo focus ownership and notification auto-dismissal

- Restore calendar keyboard shortcuts (`Ctrl+Z`, `Ctrl+Shift+Z`, `Ctrl+Y`): claim focus on initial mount, post-interaction commit, and pointer down within the calendar layout area.
- Add modal route guard and text input exclusion: calendar pointer interactions never steal focus from active dialogs, popups, or `EditableText` text fields, preserving platform native text undo/redo.
- Enable automatic notification dismissal (`persist: false`): edit notifications with `Undo` action auto-dismiss after 4 seconds without persisting indefinitely; sync status notification with action auto-dismisses after 8 seconds.
- Support test mode configuration for midnight date rollover timer (`AppController.enableMidnightTimerInTests`), preventing pending timers in unit tests while preserving production rollover.
- Experimental pre-release. Correction on 2026-11-14: the published source's required Windows CI failed (881 passed, 1 failed, 9 skipped); the focused passes above did not establish full release readiness. Windows remains unsigned; physical multi-device acceptance remains manual.


## 1.0.19-beta.17+40 - data integrity, sync clarity, task editor modularity, and performance memoization

- Restore event duration invariant in interactive calendar: dragging multi-day and overnight events preserves exact duration without truncation.
- Add upper-bound clamping to bottom-edge event resizing and top-edge auto-scroll buffer tolerance (-10px) preventing cursor stall in timeline headers.
- Improve calendar accessibility: provide detailed Semantics on timeline items, accessible tooltips on resize handles and current-time indicators, and rich Month-view card tooltips.
- Refine mobile workspace: replace unstyled calendar empty state with Material 3 empty state, and add overdue deadline warnings with amber badges and relative due dates.
- Add desktop task editor keyboard shortcuts: commit edits instantly via Ctrl+S or Ctrl+Enter, and close editor pane cleanly via Escape.
- Clarify Google Drive sync configuration: differentiate Standard Sync (no extra password) from Private Encrypted Sync, demystify unlock prompts, and prevent confusing cloud passphrases with Google account passwords.
- Refactor monolithic TaskEditor save pipeline into modular, single-responsibility components with isolated prerequisite conflict resolution.
- Optimize task projection performance: memoize `visibleTasks` and `filteredTasks` with immutability protection, automatic invalidation on task mutations, calendar-day rollover, and 6.7x faster sequential query execution.
- Add automatic midnight rollover scheduler: single one-shot timer fires at 00:00:01 local time to invalidate caches and rebuild Today views without user intervention or continuous polling.
- Experimental pre-release. Correction on 2026-11-14: required Windows CI failed (866 passed, 8 failed, 9 skipped); the focused passes above did not establish full release readiness. Windows remains unsigned; physical multi-device acceptance remains manual.


## 1.0.19-beta.16+39 - calendar interaction and UI regression fixes

- Fix unexpected calendar scroll upward during event dragging by evaluating pointer distance against viewport bounds rather than card-relative coordinates.
- Add continuous auto-scroll ticking keeping dragged items locked to pointer movement during auto-scrolling.
- Enable full cross-day drag and drop in Week view with global column resolution, dynamic ghost preview, and atomic date/time commit.
- Restore live reactivity for toolbar Undo and Redo controls and keyboard shortcuts (Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y) with autofocus and EditableText bypass.
- Replace persistent full-width banners with a compact floating notification (auto-dismissing after 4 seconds without stacking).
- Resolve Month view card drag hitboxes across 100% of card width with opaque hit testing; adapt to LongPressDraggable with haptic feedback on mobile to protect touch scrolling.
- Isolate Ctrl + Mouse Wheel zoom using dedicated scroll physics to eliminate simultaneous timeline scrolling; add 350ms transition debounce.
- Restore comfortable Month view card readability (28–34px height, 11pt font, 12pt icons, 90px min cell height).
- Unify Undo, Redo, divider, and presentation switch in an atomic toolbar pill preventing orphaned icons or awkward wrapping.
- Restyle current-time indicator with theme primary accent, aligned time badge, and accessible tooltip.
- Upgrade native Windows Tasks widget navigation buttons to 32x32 hit bounds with matching chevrons and Fluent hover outlines.
- Experimental pre-release: release, CI, and packaging integrity gates passed. Windows remains unsigned; physical multi-device acceptance remains manual.


## 1.0.19-beta.15+38 - interactive calendar candidate

- Interactive vertical timeline calendar redesign for Day and Week views with accurate time positioning and duration heights.
- Intelligent multi-item collision handling with side-by-side local lane layout, horizontal expansion, and minimum readable widths.
- Direct pointer interactions: drag to move, top-edge start time resizing, and bottom-edge end time resizing with configurable 15-minute snapping, live time chips, and semi-transparent ghost preview.
- Cross-day Week movement and Month date drag & drop preserving clock time and duration.
- Month view extended right-click context menu (Add Event, Add Task, Add Work Session, Show Day, Show Week).
- Date-anchored cursor zoom navigation (Month ↔ Week ↔ Day) via Ctrl+wheel and keyboard shortcuts (Ctrl+1, Ctrl+2, Ctrl+3, T, Esc).
- Complete bidirectional Undo/Redo: Ctrl+Z undo, Ctrl+Shift+Z / Ctrl+Y redo, header toolbar buttons, and reversible SnackBar feedback.
- EditableText focus bypass preserving platform native text undo/redo during typing.
- Single-occurrence recurring edits via `updateEventOccurrence` without altering parent series recurrence rules or sibling occurrences.
- Task deadline protection: scheduled date moves and restorations preserve task deadline dates intact.
- Reversible legacy calendar toggle switch in toolbar.
- Candidate only: release, CI, and packaging integrity gates must pass before publication. Windows remains unsigned; physical Windows/Android runtime coverage remains explicit.

## 1.0.19-beta.14+37 - alarm candidate

- Add optional task/event alarms, exact times, advance offsets, recurring rules, system sounds, bounded ringing, snooze and dismiss. Keep delivery state local while Sync carries configuration.
- Add Android exact-access review and an explicit inexact fallback; use a short native playback service and notification actions. Windows reuses the tray companion and an explicit sign-in startup choice.
- Add schema28 alarm configuration through additive reviewed migration; preserve immutable history and existing work. Update all connected devices before exchanging schema28 batches.
- Include the verified unpublished beta13 refinement, Sync/recovery, editor, navigation and widget improvements below.
- Candidate only: native delivery, release and CI gates must pass before publication. Windows remains unsigned; physical/OEM/reader/16KiB limits remain explicit.

## 1.0.19-beta.13+36 - unpublished refinement candidate

- Add shared task/event filters, recurrence-family grouping and nested subtasks, customizable navigation, grouped Android Settings, and clearer optional editor fields.
- Add event-project assignments, named checklists and richer draft creation; schema 27 migrates additively and retains immutable Sync history. Update connected devices together; schema-26 clients safely refuse newer batches.
- Correct equivalent deletion conflicts, restored decision clocks, Today event windows and explicit recurring-event field clearing; preserve archive/edit and delete/edit decisions.
- Add Windows/Android widget date navigation while retaining bounded projections and device-local configuration.
- Use compact themed auto-dismissed routine Sync confirmations; keep required decisions actionable. Clarify reconnect versus account switching and add recovery-code copy control.
- Verify real Standard Sync and a scoped real Private encrypted Windows/Android round trip with synthetic accounts; keep passphrase/recovery requirements and backup/Sync separation. No workspace conversion or password rotation is introduced.
- Apply a reviewed local backup with an automatic guarded profile restart; retain Before Restore recovery and explicit Sync reconciliation.
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
