# Todorbit v1.0.14 — Windows x64 pre-release

This update adds an independent Calendar Widget and detailed customization for
both desktop widgets. Google Drive backup remains **enabled and experimental**
in both Windows packages, using the same Desktop OAuth configuration as v1.0.13.
Connect through your system browser in Settings > Backups & Cloud; no credentials
JSON or Google Cloud setup is required from users.

## Changes

- **Independent Calendar Widget:** monthly grid, month/year navigation, Today,
  date indicators and a compact selected-date agenda. Planned tasks, sessions and
  fixed events remain distinct. Existing week-start and calendar filters apply.
- **Advanced per-widget customization:** separate shell, header, content,
  navigation, quick-add, calendar cell, agenda and date-indicator appearance.
  Control background colors/transparency and border visibility, color, opacity,
  thickness and corner radius without fading all content together.
- **Header and task navigation:** show/hide title and Open App independently;
  hide individual task views; place navigation at top/left/right/bottom; choose
  text, icons or both. Hidden controls remain reachable through the context menu.
- **Settings > Widget:** separate Tasks and Calendar entries, draft previews,
  Apply, confirmed Apply to All Widgets, Cancel and reset. Shared Apply preserves
  each widget's visibility, geometry, layout and widget-specific controls.
  Right-click Edit This Widget opens the correct editor, protecting dirty drafts.
- **Typography and icons:** consistent vector Open App/navigation icons, explicit
  native font sizing, text scaling and optional contrast backplates for transparent
  surfaces. Native text input stays opaque while focused.
- **Software Updates:** human-readable IEC download sizes and selectable, complete
  Markdown release notes in collapsed Details, without the escaped/truncated summary.
- **Backups & Cloud:** shorter sections and expandable explanations, preserving
  passphrase warnings and destructive restore confirmation.
- **Cancelled calendar events:** stronger readability while retaining cancelled
  status and strikethrough.
- First widget launch and settings reload no longer wait on the persistent
  companion process. Both widgets share one companion, IPC and startup entry.

## Upgrade and data compatibility

From v1.0.13, choose **Pre-release** in Settings > Software Updates and check for
updates. The Stable channel excludes this release. Your channel is not changed
automatically. The existing verified download, close/install/restart flow remains.

SQLite stays at **schema v21**. Existing databases, profile paths, themes, backups,
installer identity and task widget startup choices are retained. Legacy task
opacity/layout settings migrate deterministically; task geometry/view remain in
their existing file. Calendar starts disabled and can be enabled independently.
There is no automatic task completion or rescheduling.

Per-widget customization is stored in separate active-profile JSON files and
survives ordinary updates. It remains device-local and is not included in cloud
or shareable-settings snapshots; shared theme colors remain portable. Keep a
verified local backup. Portable updates must retain the exact existing folder
location to preserve the location-derived profile.

## Validation and known limitations

Implementation verification includes **303 passing automated tests**, clean
analysis, Windows/native builds, packaged native self-test, isolated two-widget
lifecycle checks and a separately passing real-companion first-launch test.
Final release packaging, CI, artifact integrity and public updater checks are
recorded in the publication report. Offscreen renders are not physical GUI tests.

**Physical Windows DPI/scaling, Win + D, screen-reader behavior and manual native
interaction/input-focus checks remain unverified.** No pass is claimed for them.
The owner will test the UI after upgrading; Sandbox/VM testing is not required.
Registered installer upgrade/uninstall and clean-machine SmartScreen behavior
also remain unverified. Both packages are **unsigned**; SHA-256 checks integrity,
not publisher identity. Windows 10 acceptance remains limited.

Calendar event rows are read-only in the widget; task/session entries can open
their task in Todorbit. New per-widget preferences are local to the device.

Google branding verification and full public OAuth policy compliance remain
unresolved. This release does not claim Google approval, universal account
eligibility or long-term grant reliability. Workspace/account restrictions,
quotas or revocation may prevent access. This is encrypted backup/restore,
**not live synchronization**. Lost passphrases cannot be recovered; full cloud
backups have a 50 MiB database limit and exclude linked external file contents.
Local SQLite/recovery files are not encrypted by Todorbit.

Download the installer or extract the complete portable ZIP. Compare the package
with its `.sha256` sidecar or `Todorbit-1.0.14-SHA256SUMS.txt` before running.
