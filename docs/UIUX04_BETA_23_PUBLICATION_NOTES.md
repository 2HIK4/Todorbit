# Todorbit 1.0.19-beta.23 — Experimental Beta

Version 1.0.19-beta.23+46 for Windows x64 and Android GitHub distribution.

- Resolve phantom sync conflict badges by aligning sync status badge counts with actionable unreviewed conflicts via unified causal projection.
- Add automatic reconciliation in `SyncResolutionRepository` (`reconcileSyncConflicts`) to safely materialize complete multi-record mutation groups superseded by newer edits without discarding history or requiring manual user resolution.
- Guard sync status calculation with resilient exception containment (`StateError`, `FormatException`, `TypeError`), presenting clear `SyncProblem.reviewUnavailable` feedback when sync history boundaries are exceeded.
- Suppress empty conflict review dialogs and fix singular/plural conflict grammar in the sync status button.
- Optimize `FocusWorkspace` timer execution, stopping 240 unnecessary widget rebuilds per minute when timers are paused or idle.
- Refactor `TaskDetailsView` Riverpod controller access to ensure clean widget lifecycles without build-phase read warnings.

## Migration and synchronization

Shared database schema remains at **29** (identical to Beta 22). Existing task,
resource, preference, backup, and sync journal data are preserved. Snapshot restore
and incremental Sync remain strictly separate. Paired Windows and Android clients
should be updated together to benefit from aligned causal conflict resolution.

Android retains its production package/signing identity with version code 46.
Windows remains unsigned under the established policy. Stable releases and the
separate reminder/alarm implementation are unchanged.

This is an experimental pre-release. Real physical DPI/accessibility, Android background/IME/rotation,
real multi-device cloud exchange, and built-in updater installation journeys remain manual
acceptance; only executed automated checks are claimed in the release evidence. Do not uninstall
or clear app data as an update workaround.
