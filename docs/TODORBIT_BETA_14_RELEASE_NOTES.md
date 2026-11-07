# Todorbit 1.0.19-beta.14 — Alarms and planning refinements

Experimental Windows and Android beta, build37. Beta13 remains an unpublished
private acceptance checkpoint; its refinement and recovery fixes are included.

- Add an optional alarm while creating or editing a task or event. Choose an
  exact time, an advance offset, or a clock time on a task's planned day. Sound,
  Android vibration and a15–120 second sound limit are available under options.
- Dismiss, snooze for5/10/15 minutes, or open the associated item. Recurring
  alarms follow actual occurrences; individual overrides remain separate. Task
  dates and deadlines are never changed by snooze or dismissal.
- Alarm configuration follows Sync; schedules, receipts and snoozes stay local.
  Use Alarm settings to disable delivery on an individual device. Multiple
  enabled devices can legitimately ring for the same item.
- Windows uses the existing tray companion, including when the main window is
  closed. Windows sign-in startup requires a saved explicit choice. Sleeping or
  powered-off PCs cannot sound an alarm; missed delivery has a five-minute grace.
- Android uses native scheduling and a short-lived playback service. Review
  exact alarm access and notification/sound permissions in Alarm settings.
  Without exact access, delivery can be delayed and may use a single notification
  sound. Quiet hours, Do Not Disturb, force-stop and battery/OEM restrictions apply.
- Includes shared filters, recurring-task groups, nested subtasks, named
  checklists, event-project assignments, richer creation, customizable navigation,
  grouped Settings, and Windows/Android widget date controls.
- Includes safer Sync conflict/restore decisions, clearer account switching,
  recovery-code copying, and automatic restart after applying a reviewed backup.
  Before Restore and explicit Sync reconciliation remain part of recovery.

Schema28 adds alarm rules through a reviewed additive migration. Keep backups
and update every connected device before using the new schema. Older clients
refuse newer batches safely; do not downgrade a migrated database. Snapshot
backups and incremental Sync remain separate; encryption/recovery requirements
are unchanged. No workspace conversion or key rotation is performed.

Windows packages are unsigned. Physical Windows10/DPI/Narrator and Android
ARM64/OEM/TalkBack/16KiB runtime coverage remains limited; see the acceptance
receipt. Google branding remains unverified. This is an experimental pre-release,
excluded from the Stable update channel.
