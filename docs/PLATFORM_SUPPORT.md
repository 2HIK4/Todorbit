# Todorbit platform support

This matrix describes the
[1.0.19-beta.25 public pre-release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.25).
The features marked **Included** are available in the experimental build.
**Experimental** marks cloud features whose availability and recovery depend
on configuration, account access, and the chosen mode. See the
[installation guide](INSTALLATION.md) for supported devices.

| Feature | Windows x64 | Android 8.0+ ARM64 / x86-64 |
| --- | --- | --- |
| Offline planner | Included. Tasks, projects, recurrence, habits, goals, search, focus timers, and reports. | Included through the touch-oriented workspace. |
| Calendar and Smart Reschedule | Included. Day, week, and month views and a reviewed rescheduling proposal. | Included. Touch calendar and agenda with day, week, and month views, plus Smart Reschedule review. |
| Local snapshots and restore | Included. Reviewed SQLite export, import, and restore. | Included. Uses Android's system file picker for external backup files. |
| Google Drive incremental Sync | Experimental. Standard or Private Encrypted Sync. The Windows companion provides background opportunities while running. | Experimental. Standard or Private Encrypted Sync. Android controls background job timing. |
| Encrypted Google Drive snapshots | Experimental. Full and settings-only snapshot backups with passphrase recovery. | Experimental. Uses the same encrypted backup format and a compatible Google account. |
| Light/dark themes and theme JSON | Included. Additional native desktop widget appearance controls. | Included in mobile appearance settings. |
| Widgets | Included. Native Tasks and Calendar desktop widgets through a Windows companion. | Included. Tasks and Calendar launcher widgets. |
| Software updates | Included. GitHub update discovery for installed and portable packages. | Included in the GitHub build. The OS confirms APK installations. |

Windows 11 is the primary test platform. Windows 10 acceptance is limited.
The public Android build uses the GitHub APK distribution. The repository's
iOS scaffold is outside the supported distribution.

[Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/44694169827),
[Android CI](https://github.com/2HIK4/Todorbit/actions/runs/44694185735), and
[Android 16 KiB emulator runtime](https://github.com/2HIK4/Todorbit/actions/runs/44699666409)
passed for the published source. Physical Windows keyboard and focus behavior,
multi-monitor DPI, Android multi-file sharing, and updater installation on
physical devices remain pending for this pre-release. For Sync and backup
account requirements, see [Sync setup](GOOGLE_DRIVE_SYNC.md) and
[backup and restore](GOOGLE_DRIVE_BACKUP.md).
