# Todorbit 1.0.19-beta.17 — Data Integrity, Sync Clarity & Core Engineering Refinements

Experimental Windows and Android pre-release, build 40 (SQLite Schema 28). Builds upon the interactive calendar introduced in Beta 15 and refined in Beta 16, restoring scheduling data invariants, polishing cross-platform UI accessibility, enhancing Google Drive Sync transparency, decomposing task persistence, and delivering high-performance task list caching.

### Key Improvements Since Beta 16

- **Event Duration Invariant Restored**: Fixed critical defect in interactive calendar dragging where overnight and multi-day events were artificially truncated to midnight (23:59). Moving events now strictly preserves their original duration across days.
- **Timeline Clamping & Scroll Hygiene**: Added upper-bound 23:59 clamping for bottom edge resize, lower-bound clamping for multi-day cards, and a -10px auto-scroll top buffer so drag scrolling stays active when approaching column headers.
- **Screen-Reader & Accessibility Refinements**: Added descriptive `Semantics` formatting start/end times, alarm status, and overlap counts for Windows Narrator and Android TalkBack. Added hover tooltips to resize handles and current-time indicators, and enriched Month-view card tooltips.
- **Desktop Task Editor Productivity Shortcuts**: Added <kbd>Ctrl</kbd>+<kbd>S</kbd> and <kbd>Ctrl</kbd>+<kbd>Enter</kbd> to save task changes instantly, and <kbd>Escape</kbd> to safely dismiss or close the editor pane.
- **Android Overdue Visibility Parity**: Integrated overdue deadline detection into `MobileWorkspace` with amber warning icons and relative due-date indicators, matching desktop urgency.
- **Google Drive Sync Clarity**: Added dedicated informational cards in `SyncSettingsPage` explaining Standard Sync (zero extra password required). Renamed passphrase input to `Private Sync passphrase` with explicit guidance not to enter Google account passwords. Demystified cloud unlock cards and enhanced recovery code copy affordances.
- **Modular TaskEditor Persistence Pipeline**: Decomposed the monolithic 270-line `_save()` method into bounded, testable phases (`findPrerequisiteConflicts`, `_validateAlarmsAndNotifications`, `_buildTaskDraft`, `_confirmPrerequisiteConflicts`, and `_persistTaskDraft`).
- **High-Performance Task Memoization**: Added notification-cycle memoization to `AppController.visibleTasks` and `filteredTasks`, backed by `List.unmodifiable` immutability protection and property setter invalidation. Benchmarked at 6.7x faster sequential query execution (32 µs vs 219 µs) on 500 tasks with zero allocation churn during static re-renders.
- **Automatic Midnight Rollover**: Added a single one-shot timer scheduled precisely for 00:00:01 local time to invalidate caches and trigger UI rebuilds across open Today views without polling or user intervention.

### Verification & Platform Status
- Automated regression suite (`test/calendar_interactions_regression_test.dart`) verified (11 end-to-end scenarios, including Scenario K).
- All 15 tests in `test/workspace_test.dart` passed (including prerequisite conflict resolution, cache memoization, immutability, setter invalidation, and midnight rollover).
- Full sync, draft safety, repository, and widget suites passed; `dart analyze` reports 0 issues.
- Native widget companion verified via `dotnet run --project experiments/widget-shell-probe -- --self-test`.
- Android release configured with 16 KiB page-size native library alignment.

### Known Limitations & Synchronization Notice
- **Windows Google Drive Sync Disabled**: Windows desktop Google Drive synchronization is intentionally disabled by design in this public pre-release (`GOOGLE_DRIVE_ENABLED: false`) pending Google Cloud domain and branding verification. Desktop users have full offline task and calendar scheduling, local `.tdbackup` snapshot backup/restore, and native Windows widgets. Cross-device synchronization between Windows and Android is **not** available in this public build.
- **Android Google Drive Authentication & Acceptance Limits**: While the Android package enables platform Google authentication (`GOOGLE_DRIVE_ANDROID_ENABLED: true`), real Google account authentication and end-to-end sync have not been fully verified on physical target devices. Google Play Services and matching OAuth client registration in Google Cloud Console remain prerequisites. Users should export local `.tdbackup` snapshots before testing cloud sync.
- Windows packages remain unsigned. Excluded from the Stable release channel.
