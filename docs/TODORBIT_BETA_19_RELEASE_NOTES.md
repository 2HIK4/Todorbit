# Todorbit 1.0.19-beta.19 — Calendar data safety and date refresh

Experimental Windows and Android pre-release, build 42, SQLite schema 28.

- Calendar Undo/Redo preserves later task/event edits, deadlines, task status and work-session outcomes while undoing the intended date/time.
- Overnight and multi-day continuation drags preserve start offset and duration in both directions and across days. Resize handles appear at real event boundaries.
- Midnight resizing retains the minimum duration and supports an exact midnight end time.
- Date rollover reloads Today events and recurring tasks; disposed controllers cannot restart the timer.
- Failed calendar actions show dismissible errors and retain failed history. Successful edit notices dismiss after four seconds.

Verified source: `375729e064ba9a2c7af298fa4c40e60d51d14821`.
[Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/43516558494): 893 tests passed, 9 opt-in skips; analysis/build/package gates passed.
[Android validation](https://github.com/2HIK4/Todorbit/actions/runs/43516561285) passed, including on-device update integration.
[Exact signed APK 16 KiB runtime](https://github.com/2HIK4/Todorbit/actions/runs/43527857993) passed render/create/restart/complete and production-signed Beta 18-to-19 upgrade retention.
Separate isolated startup/recovery tests passed 15 cases. Fresh Windows Sandbox installer/portable, database preservation and uninstall/reinstall checks passed.

Windows Google Drive Sync remains intentionally disabled. Android Google authentication retains its existing configuration and acceptance limits. Standard/Private Sync, encryption/recovery, local backups, profile locations and schema are unchanged. Stable is unaffected.

Windows packages remain unsigned. Android retains the production signing identity. Android's production calendar is its touch agenda/month interface; desktop timeline gestures are Windows features.

Manual gaps: Windows 10, physical keyboard/DPI, Narrator/TalkBack, ARM64/OEM reminders and real Google account flows. Text/key entry through the local UI automation helper was inconclusive. One portable handoff test timed out closing its disposable app; diagnostic swap and original rollback/recovery checks then passed. The initial timeout's cause remains unverified and no code change was made for it.

[Publication receipt and checksums](TODORBIT_BETA_19_PUBLICATION.md).
