# Todorbit 1.0.19-beta.18 — Calendar Keyboard Shortcuts & Notification Auto-Dismissal

Experimental Windows and Android pre-release, build 41 (SQLite Schema 28). Builds upon Beta 17, resolving manual testing feedback regarding keyboard undo/redo shortcuts and persistent notification dismissal on Windows.

### Key Improvements Since Beta 17

- **Calendar Keyboard Shortcuts Restored**: Restored reliable `Ctrl+Z` (Undo), `Ctrl+Shift+Z` (Redo), and `Ctrl+Y` (Redo) operations in the calendar view by acquiring focus upon view mount, interaction commit, and pointer down events on the calendar body.
- **Focus Safety & Modal Guard**: Pointer-based focus acquisition is scoped strictly to the calendar body grid and guarded by `ModalRoute.of(context)?.isCurrent == true`. It never steals focus from open dialogs, menus, or interactive controls, and `onKeyEvent` preserves native text undo/redo within `EditableText` inputs.
- **Notification Auto-Dismissal**: Fixed framework behavior in Flutter 3.24+ where `SnackBar` defaulted `persist` to `true` whenever an action button was present. Set `persist: false` on calendar edit notifications (dismissing after 4 seconds) and sync announcements (dismissing after 8 seconds) while keeping actions fully functional.
- **Test-Safe Midnight Rollover Scheduler**: Added `AppController.enableMidnightTimerInTests` flag so unit and widget tests avoid unhandled pending async timers, while production midnight rollover remains fully active at 00:00:01 local time.

### Verification & Platform Status

- Automated test suites verified: 30 tests pass cleanly across `test/calendar_undo_redo_shortcuts_test.dart` (8 tests), `test/calendar_interactions_regression_test.dart` (11 tests), and `test/calendar_undo_redo_test.dart` (11 tests).
- Static analysis: `dart analyze lib test` reports 0 issues.
- Native widget companion: `dotnet run --project experiments/widget-shell-probe -- --self-test` passes.
- Android release configured with 16 KiB page-size native library alignment and production key continuity.

### Known Limitations & Synchronization Notice

- **Windows Google Drive Sync Disabled**: Windows desktop Google Drive synchronization is intentionally disabled by design in this public pre-release (`GOOGLE_DRIVE_ENABLED: false`) pending Google Cloud domain and branding verification. Desktop users have full offline task and calendar scheduling, local `.tdbackup` snapshot backup/restore, and native Windows widgets. Cross-device synchronization between Windows and Android is **not** available in this public build.
- **Android Google Drive Authentication & Acceptance Limits**: While the Android package enables platform Google authentication (`GOOGLE_DRIVE_ANDROID_ENABLED: true`), real Google account authentication and end-to-end sync have not been fully verified on physical target devices. Google Play Services and matching OAuth client registration in Google Cloud Console remain prerequisites. Users should export local `.tdbackup` snapshots before testing cloud sync.
- Windows packages remain unsigned. Excluded from the Stable release channel.
