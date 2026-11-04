# Todorbit 1.0.19-beta.12

This experimental Windows + Android pre-release includes the six committed UI
reliability batches since beta11. Back up your data before updating.

## Changes

- Protect task and nested drafts during supported navigation, dismissal and
  resizing; preserve recurring-series, Goal and Habit edits and failed-save input.
- Improve Calendar labels and overnight agenda, short/narrow windows, large text,
  event/session date controls, scheduling review, reports and work-entry dialogs.
- Retain resource/template input through validation and write failures, clarify
  template exclusions and handle duplicate names with a useful correction.
- Stop malformed preferences from being silently overwritten with defaults.
  Startup recovery preserves damaged data, displays the profile path and offers Retry.
- Support full Windows theme-import/export paths, avoid transfer feedback after
  dialog disposal and clarify preview feedback when the widget is enabled but stopped.
- Clarify routine Sync controls and unlock wording while keeping snapshot backup,
  incremental Sync and optional private encryption distinct.

Schema 26, Sync protocol and credential/recovery requirements, backup formats,
Windows profile paths/AppId, widget contracts and Android signing identity remain.

## Acceptance and limitations

The owner explicitly requested publication with further tests skipped. No new
host suite, analyzer, CI, native self-test, emulator or guided manual tests were
run for this publication. Existing scoped evidence from the six implementation
batches is retained; it is not full application acceptance. Build/package identity,
production APK signing, native alignment, checksums and public asset integrity
are verified separately from application testing.

The dark/100% Windows attachment sample passed actual file selection, Notepad
opening, return, draft preservation, Save/reopen, cold restart and reference
removal with the original intact. External-file/folder variants, comprehensive
physical keyboard/Narrator, widget shell/input/menus/DPI and other themes/scales
remain unverified. Windows packages are unsigned.

The disposable API35 environment lost system_server and core services before
app installation. No new Android IME, SAF, Calendar launcher-widget, TalkBack,
physical/OEM/ARM64 or upgrade acceptance is claimed. Do not interpret boot completion
or compilation as a device pass. Real Google Drive cross-device synchronization
acceptance remains a separate task. Existing-workspace encryption conversion
and cloud passphrase changes remain unavailable.

## Update

In Todorbit select **Software Updates > Pre-release**, check for updates, download
and install. Windows installed mode uses Setup; portable mode uses the complete ZIP.
Retain the same Windows account and installation/portable path. Check the active
profile afterward. Android GitHub edition uses the production-signed universal
ARM64/x64 APK, version code **35**, preserving in-place update identity.

Do not uninstall, clear data or force a downgrade to recover from an update error.
Keep verified exported backups and the actual credentials required by your Sync
mode. Debug or differently signed/store installations may be incompatible.
