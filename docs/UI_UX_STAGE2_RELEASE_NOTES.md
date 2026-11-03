# Todorbit v1.0.19-beta.7 — calendar appearance and editor reliability

Coordinated Windows and Android prerelease, version `1.0.19-beta.7+30`.
This beta improves the existing interface while preserving tasks, events,
preferences, backups, widget settings and schema 26.

## What changed

- Startup and backup integrity checks wait briefly for SQLite locks while
  retaining all safety checks. Persistent locks still stop startup safely.

- Calendar agendas honor event icons and selected colors. Windows companion
  events also inherit category colors and occurrence-specific appearance;
  contrast backing keeps white, black and pale choices distinguishable.
- Moving an event/session Start preserves its duration unless you deliberately
  edited End. Invalid explicit intervals offer a visible correction. All-day
  End opens on the same inclusive day displayed in the editor.
- Color/icon pickers, the focus timer and manual-work dialogs scroll and wrap
  controls in short windows, with large text and the keyboard visible.
- Mobile editors use balanced gutters. Settings choices open below their
  controls where space permits, and shared choices reflect external updates.
- More represents unpinned mobile views; habit recurrence guidance is readable.

## Compatibility and known limits

Existing Windows installation/profile/IPC identities and Android package/signing
identity are retained. No uninstall or data reset is needed for an update from
the same production signer. Windows packages remain unsigned.

The reported Android error shaking was not reproduced in focused host tests;
this release does not claim a confirmed fix for that original device sequence.
Re-inspection of the original Android widget captures shows complete footer
labels. Wider OEM launcher sizing, native keyboard/error transitions, TalkBack,
Narrator, physical Windows DPI/multi-monitor/input and shell behavior still need
manual acceptance. Automated renders do not certify those behaviors.

Google Drive remains optional and experimental under the existing authorization
and branding limitations. No new account, cloud service or telemetry is added.
Real-account end-to-end exchange is not newly certified by this release.

The [Stage 2 / 2.1 audit](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.7/docs/UI_UX_STAGE2_AUDIT.md) records findings, exact check
scopes, failed attempts, reused evidence and the manual acceptance checklist.
