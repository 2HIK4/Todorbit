# Todorbit 1.0.19-beta.23

Experimental beta candidate, build 46. Windows x64 and Android GitHub distribution.

## Changes

- Synchronization and conflict resolution:
  - Fixed phantom sync conflict badges by unifying badge counts with actionable unreviewed conflicts via causal projection (`_readSyncResolution(binding)`).
  - Added automatic conflict reconciliation in `SyncResolutionRepository` (`reconcileSyncConflicts`) so multi-record mutation groups superseded by newer edits materialize safely without manual intervention or data loss.
  - Protected sync status snapshot calculation against excessive or malformed history entries (`StateError`, `FormatException`, `TypeError`), transitioning safely to `SyncProblem.reviewUnavailable` with clear user feedback.
  - Suppressed empty conflict dialogs when no actionable conflicts remain, and corrected singular/plural grammar in sync status button labels and tooltips.
- Focus Workspace performance:
  - Eliminated continuous idle rebuilds (240 rebuilds/minute) in `FocusWorkspace` by guarding periodic timer notifications so rebuilds only occur during active sessions.
- Task Details lifecycle:
  - Ensured safe Riverpod provider access in `TaskDetailsView`, using `ref.read` outside `build()` and `ref.watch` within `build()` to prevent lifecycle warnings and stale controller references.

## Data and compatibility

Shared database schema remains at **29** (identical to Beta 22). Existing task,
resource, preference, and sync journal data are preserved. Snapshot restore
remains separate from incremental Sync. Paired Windows and Android devices
exchanging sync data should update to Beta 23 for matching causal conflict
reconciliation.

Android uses the established production package/signing identity (`io.github.hik4.todorbit`, version code 46).
Windows packages remain unsigned under the established policy. Stable releases and
the separate reminder/alarm implementation are unchanged.

## Experimental acceptance

Test installation through the Pre-release update channel, data retention, and the
repaired sync conflict and focus timer behaviors on both platforms. Real multi-device
Google Drive sync exchange, physical device input/accessibility, and runtime package
acceptance remain explicitly tracked. This candidate has not been pushed or published.
