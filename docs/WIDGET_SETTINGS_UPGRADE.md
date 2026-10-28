# Widget settings, reminders and navigation upgrade

> Published as [v1.0.17](TODORBIT_1_0_17_PUBLICATION.md) after the final audit.
> Version/verification statements below describe the initial implementation checkpoint.

Implemented on `feature/widget-settings-navigation-upgrade` from `main` at
`d6a1620`. App/native production version remains **1.0.16+17**. No release,
installer execution, OAuth configuration change or personal-profile migration.
The written request was supplied; its referenced screenshots were not attached.

## Behavior and implementation

| Feature | Implementation |
| --- | --- |
| Navigation order | Drag handles and keyboard-accessible Up/Down actions in Widget settings. Order includes hidden items; visibility is independent. Native horizontal/vertical rendering reads saved order. |
| Presets | Five built-ins per widget; custom Save, Rename, Duplicate and Delete. Active preset name/configuration and libraries persist independently per kind. Apply commits configuration/library; Cancel discards drafts. Built-ins cannot be overwritten. |
| Settings history | Bounded 60-step `SettingsHistory`; Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y with toolbar actions in widget/theme/task-display editors. Sidebar order also supports shortcuts. Slider start/end coalesces gestures. Text inputs retain text Undo. Widget/theme changes stay drafts; existing immediate settings remain immediate. Histories end with their context. |
| Appearance | Independent task-row, hover and selected-navigation surfaces plus text color/alpha. Null colors follow theme. Shell opacity does not multiply row/text alpha. Text protection and a readability warning remain available. |
| Calendar layout | Drag divider or set Calendar share (20–80%). Per-week-row minimums and a 300×420 base minimum keep dates/agenda usable; minimum height scales with text. Default unset split keeps bounded cells. Agenda scroll is independent. |
| Indicators | Uncancelled, distinct event occurrences: 0 none, 1–3 centered dots, 4+ a line. Task squares/session markers stay distinct. Counts use the same filtered projection as the agenda, including moved recurring events. |
| Task notifications | New tasks default Off. Explicit custom UTC date/time or offset from the next upcoming work session. A planned day/deadline has no clock time. Invalid relative timing requires a session or custom time. Recurring task settings apply to the selected occurrence, without enabling future tasks. |
| Direct navigation | Task rows open the in-app task editor; Calendar rows open their actual task/event/session editor. Completion checkboxes remain direct completion. Stable IDs, actual date, nominal occurrence date and action travel over existing activation readiness. Existing editors/modals defer requests; deleted targets produce a message. |

Main locations: `lib/domain/widget_configuration.dart`, `widget_presets.dart`,
`settings_history.dart`, `navigation_request.dart`, `notifications.dart`;
`lib/data/widget_configuration_store.dart`, `backup_service.dart`,
`notification_repository.dart`; widget/theme/task-display/sidebar editors,
`lib/features/workspace/`, `lib/main.dart`; native widget configuration, surfaces,
Calendar layout/projection, `TaskReminders.cs` and `windows/runner/main.cpp`.

## Persistence and compatibility

- Schema **22** adds `tasks.notification_json` (Off default), an enabled-reminder
  index and `task_reminder_deliveries`. Existing event/due reminder data remains.
  The existing reviewed migration/Before upgrade backup gate still applies.
- Config format 1 uses additive optional fields with old-file defaults;
  per-widget preset libraries are version 1, bounded to 30 custom names each.
  Unsupported files are preserved and reported. Reordering hidden views never
  enables them. Native-menu saves retain new fields.
- Settings transfer adds the widgets category. Both configurations and libraries
  travel through settings-only and encrypted full Drive backups.
- Local SQLite backups/exports include a snapshot-only personalization envelope.
  External snapshot staging preserves it. Restore validates the bundle before
  replacing SQLite, applies its files, and removes the envelope from the live
  database. A failed file apply keeps restoration pending; file imports attempt
  rollback. Multi-file replacement is not crash-atomic; startup must finish the
  pending restore before opening the workspace.
- Visibility, layout lock, native geometry and startup remain device-local.
  Portable appearance restores preserve those controls. Old backups without a
  widget bundle leave existing widget files alone.
- The existing companion checks reminders every 30 seconds, claims in a
  transaction and tolerates a five-minute due window. It does not deliver missed
  reminders after a longer offline interval. Completed/cancelled/archived/Trash
  tasks and inactive parents/series are excluded. Relative triggers follow session
  edits; custom times stay independent of planned dates. Delivery is an attempted
  Windows notification, not proof of receipt. Existing privacy/global due/event
  settings retain their meaning; the app has no separate quiet-hours policy.

## Verification and remaining manual acceptance

Automated coverage includes model/alpha/order round-trips, presets and actual
local/cloud restore application, schema migration, history bounds/gestures/
shortcuts/text focus, Apply/Cancel, task/event cold-start editor routing and
existing regression suites. Native self-test covers all navigation layouts,
4/5/6-week split minima, 0–6 event counts, duplicates/cancellations, independent
alpha in both palettes, typed occurrence payloads, reminder rescheduling,
disable/completion and duplicate claims.

Implementation commit: **d8f2bc8**. Full serial suite: **353 passed / one opt-in
skip**; subsequent drag/history/preset checks: **4 passed**. Whole analysis,
changed-Dart formatting, Windows/native Release, final packaged self-test,
actual-HWND lifecycle and diff checks pass. Further evidence and limits are
recorded in [Progress](PROGRESS.md).
Live debug inspection used an isolated profile, including preset selection/save,
Apply, actual second-process task activation with one main app, and direct
closed-app startup opening the exact task editor. An unsaved
title stayed intact while another request waited; closing that editor produced
the expected missing-item message. Driver finder timeouts during exploration
were corrected; hot reload succeeded and subsequent runtime diagnostics were clean.

Before release, on an isolated Windows profile:

1. Drag hidden navigation items, change horizontal/vertical positions, Apply,
   restart and check order/visibility. Test Up/Down and Undo/Redo.
2. Apply every built-in; save/rename/duplicate/delete custom presets. Cancel a
   draft and confirm it was not persisted. Restore local and Drive snapshots,
   checking the actual widgets and preset list after restart.
3. Test row/text/selected colors over real wallpapers in both themes. Drag
   sliders twice and Undo twice; confirm focused HEX/name text keeps text Undo.
4. Drag the Calendar divider at minimum and larger sizes, four-/five-/six-week
   months and larger text. Check independent scrolling, 0–5+ event indicators,
   moved/cancelled recurrences and multiple DPI/monitor configurations.
5. Create a task with Off and confirm no reminder; explicitly configure custom
   and relative times, edit the session, disable, complete, archive and delete.
   With the main app closed, verify actual Windows notification display/privacy
   and no duplicates. Physical OS notification receipt remains unverified.
6. Click task/event/session rows with the app closed, running, minimized and
   behind other windows. Check the exact recurring occurrence, repeated clicks,
   stale/deleted items, one instance and preservation of active editing/modal
   state. Confirm completion checkboxes do not open the app.

Automated rendering, driver interaction and HWND lifecycle checks do not verify
physical mouse/keyboard feel, Explorer restart/Win+D, screen readers, real DPI
transitions, actual notification receipt or registered installer upgrades.
