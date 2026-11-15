# Todorbit 1.0.19-beta.22

Experimental beta candidate, build 45. Windows x64 and Android GitHub distribution.

## Changes

- Navigation and Custom Views: multiple category/project/priority selections, saved icons and synchronized task visibility preferences.
- Unified Resources: portable attachments, subtask assignments, normalized links and Windows Chrome webpage-link drops.
- Dedicated Task Details with editing and return navigation.
- Focus Workspace: Stopwatch, Countdown and Pomodoro with corrected work/break accounting, pause/resume and explicit restart recovery.
- Safer Archive/Trash bulk operations and compact Focus layout corrections.

## Data and compatibility

This version upgrades the database from schema 28 to **29** using the existing
verified Before Upgrade backup and approval flow. Existing task, resource,
preference and sync data are retained. Snapshot restore remains separate from
incremental Sync. Update **all paired devices** before exchanging schema-29 sync
batches: older clients reject them and retain their local data/pending history.
New clients accept supported schema-26/27/28 history. No downgrade migration is
provided; keep verified backups before switching back to an older application.

Android uses the established production package/signing identity (code 45).
Windows packages remain unsigned. Stable releases and reminder/alarm delivery
are unchanged.

## Experimental acceptance

Test installation through the Pre-release/Beta updater, data retention and the
new journeys on both platforms. Real Chrome drag/drop, device background/restart,
physical input/accessibility and exact-package acceptance remain explicitly
tracked. This candidate has not been pushed or published.
