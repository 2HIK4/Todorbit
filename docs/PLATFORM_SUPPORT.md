# Todorbit platform support

This matrix describes the
[1.0.19-beta.30 public pre-release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30) (`253f4ed`, build `53`) on SQLite schema 29. The
features marked **Included** are available in the experimental build.
**Experimental** marks cloud features whose availability and recovery depend
on configuration, account access, and the chosen mode. See the
[installation guide](INSTALLATION.md) and full
[feature catalogue](FEATURES.md) for details.

| Feature | Windows x64 | Android 8.0+ ARM64 / x86-64 |
| --- | --- | --- |
| Offline planner | Included. Tasks, projects, recurrence, habits, goals, templates, plans, archive/trash, search, focus timers, and reports. | Included through the touch-oriented `MobileWorkspace` shell. |
| Calendar and Smart Reschedule | Included. Day, week, and month timeline grid with drag/resize/zoom and reviewed Smart Reschedule proposals. | Included. Touch date picker and agenda with day/week/month filtering plus Smart Reschedule review. |
| Hotkeys and keyboard navigation | Included. Embedded **Settings > Hotkeys** editor, conflict checks, and named presets. | Not applicable (touch navigation). |
| Local snapshots and restore | Included. Reviewed SQLite export, import, restore, and selective settings transfer. | Included. Uses Android's system file picker for external backup files and selective settings transfer. |
| Google Drive incremental Sync | Experimental. Standard or Private Encrypted Sync (`SyncEngine`, protocol 2). Windows companion provides background opportunities while running. | Experimental. Standard or Private Encrypted Sync. Android WorkManager controls background job timing. |
| Encrypted Google Drive snapshots | Experimental. Full and settings-only AES-256-GCM snapshots with passphrase recovery. | Experimental. Uses the same encrypted backup format and a compatible Google account. |
| Light/dark themes and theme JSON | Included. Graphite Neutral Silver default dark palette plus custom theme JSON import/export and native widget palettes. | Included in mobile appearance settings. |
| Desktop / home-screen widgets | Included. Native Explorer-hosted Tasks and Calendar desktop widgets (`TodorbitWidget.exe`) with smooth pixel scrolling and per-surface styling. | Included. Tasks and Calendar launcher `RemoteViews` widgets. |
| Shared files inbox | Included via managed file attachments & external file links in `TaskDetailsView`. | Included. Native `ShareReceiverActivity` ingestion into Shared Inbox (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`). |
| Software updates | Included. GitHub release discovery, SHA-256 verification, and installer/portable updates. | Included in the GitHub APK build with native `ApkVerifier` / PackageManager checks. |

Windows 11 is the primary test platform. Windows 10 acceptance is limited.
The public Android build uses GitHub APK distribution; Google Play publishing
remains separate, and the repository's iOS scaffold is outside the supported
distribution.

For Beta 30 exact-source receipts see
Beta 30 Candidate Receipt (`docs/TODORBIT_BETA_30_CANDIDATE.md` on `feature/todorbit-beta27-refinement`). Physical Windows
keyboard/focus/multi-monitor DPI behavior, live wallpaper visual acceptance,
Android multi-file Share Sheet/OEM behaviors, and two-client live Drive tests
remain recorded in deferred verification (`docs/DEFERRED_VERIFICATION.md` on `feature/todorbit-beta27-refinement`). For Sync
and backup account requirements, see Sync setup (`docs/GOOGLE_DRIVE_SYNC.md` on `feature/todorbit-beta27-refinement`) and
[backup and restore](GOOGLE_DRIVE_BACKUP.md).
