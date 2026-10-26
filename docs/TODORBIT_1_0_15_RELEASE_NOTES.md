# Todorbit v1.0.15 - Widget redesign (Windows x64 pre-release)

This pre-release delivers the completed desktop widget redesign for real-user
testing. Enable widgets in Settings > Widget and choose Configure, or right-click
a widget and choose Edit This Widget.

## What's new

- **Two Calendar presentations:** Compact Calendar + Agenda and Full Month Grid.
  Responsive day cells show scheduled item titles and overflow counts when space
  permits. Select a day to inspect its complete agenda; native item details do
  not require opening the main application. Existing week-start/content filters
  and the distinction between planned tasks, sessions and events are retained.
- **Live customization on the actual widgets:** colors, opacity, borders,
  typography, navigation and calendar presentation preview while editing.
  Continuous slider movement updates before release without saving every change.
- **Safer editing:** Apply saves and keeps the editor open. Cancel restores the
  latest saved baseline. Close/Escape offers Save Changes, Discard Changes or
  Continue Editing. Confirmed Apply to All copies compatible appearance while
  retaining independent widget settings. Timeout recovery and native menu edits
  preserve the saved configuration; unsaved previews are not persisted.
- **Polished desktop interaction:** easier background/header dragging, protected
  controls and layout lock, visible checked menu settings, responsive Tasks
  navigation, larger completion hit regions and themed delayed rounded tooltips.
  Optional text shadows replace opaque backgrounds behind ordinary labels.
- **Application UI improvements:** clearer settings sections and secondary help,
  scrollable color/prompt/preferences/notification/privacy/backup interfaces,
  improved narrow-window layouts and keyboard traversal past disabled choices.

## Upgrade and compatibility

From v1.0.14, open Settings > Software Updates, select **Pre-release**, then
Check for updates. Review the release and use Download/Install. Stable excludes
this pre-release; your update channel is not changed automatically.

SQLite remains at **schema v21**. Tasks, events, schedules, themes, profile paths,
installer identity and backup formats are unchanged. Existing widget appearance,
visibility, positions and startup preferences are preserved. Older Calendar
settings default to Compact Calendar + Agenda; choose Full Month Grid explicitly.
No task is automatically completed or rescheduled.

Keep a verified local backup. Per-widget customization remains device-local and
excluded from shareable/cloud settings backups. Installer users should upgrade
the existing installation; portable users must retain their exact existing
extraction path to retain the location-derived profile. Keep the entire bundle
together and close Todorbit and its companion before manual replacement.

Google Drive backup remains **enabled and experimental**, using the same Desktop
OAuth configuration as the previous published packages. No credentials JSON or
new Cloud setup is required. Google verification/account-policy limitations
remain unchanged; this release does not claim Google approval.

## Verification and testing limits

Existing verification includes 327 passing tests, clean analysis, Windows/native
builds, 11 final editor regressions, the separately passing packaged first-launch
test, native self-tests and isolated two-window/live-preview checks. Release CI,
package digests and public updater checks are recorded in the publication report.

**Real-user physical Windows acceptance is pending.** Physical dragging/input
focus, display scaling/DPI, multi-monitor, Win+D, Explorer restart and screen-reader
checks have not been declared passed. Offscreen renders and Flutter automation
do not establish those results. Windows 10 and registered installer execution
also require real-user acceptance.

Both packages are **unsigned**. SHA-256 verifies integrity, not publisher identity;
Windows may display a publisher/SmartScreen warning. Apply to All uses atomic
individual files with rollback on a save failure, not a crash-atomic transaction
across both files. Calendar event details remain read-only in the widget.
