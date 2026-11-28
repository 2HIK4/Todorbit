# Todorbit platform support

This matrix describes [Experimental Beta 30][release] (build 53, SQLite schema
29). The [feature catalogue](FEATURES.md) links to the released source and tests
for each capability. See [Install Todorbit](INSTALLATION.md) for packages,
checksums, and upgrade instructions.

| Capability | Windows x64 | Android 8.0+ (ARM64 or x86-64) |
| --- | --- | --- |
| Offline planner | Tasks, projects, built-in and custom views, recurrence, templates, habits, goals, focus timers, work logs, and reports. | Shared planner in touch-oriented screens. The task menu can duplicate core fields. |
| Calendar and Smart Reschedule | Day, Week, and Month calendar views. Day and Week have a time grid with drag, resize, zoom, and undo. Preview and approve rescheduling changes. | Day, Week, and Month selection with a touch agenda and shared Smart Reschedule review. |
| Keyboard shortcuts | Embedded Hotkeys editor with presets and conflict checks. | Touch-oriented navigation. |
| Themes and appearance | System, Light, and Dark modes, color presets, theme JSON, text/density settings, and native widget customization. | System, Light, and Dark modes, color presets, theme JSON, and touch layout settings. Launcher widget appearance follows supported system settings. |
| Attachments and links | Managed attachments and external file, folder, and web links. External paths are device-local. | Managed attachments and web links. Files shared from compatible Android apps can go to the Shared Files Inbox. |
| Widgets | Explorer-hosted Tasks and Calendar widgets with layout, styling, keyboard navigation, and a shared background companion. | Home-screen Tasks and Calendar widgets with cached date browsing and app-mediated task actions. Behavior varies by launcher. |
| Reminders and alarms | Local notifications and native alarms through the background companion. | Local notifications and alarms subject to notification and exact-alarm permissions and battery policies. |
| Local backups and portability | SQLite snapshot export/import, reviewed restore, selective settings transfer, and a portable ZIP. | SQLite snapshot export/import and settings transfer through the Android file picker. The active profile uses app-private storage. |
| App Lock | Optional PIN to hide the app and widget content. | Optional PIN. Supported devices can use Android biometric unlock from API 28 and device credentials from API 30. |
| Google Drive backup | Optional experimental encrypted snapshots. Recovery needs the backup passphrase. | Same format and recovery requirements. Google authorization requires a supported device and account. |
| Google Drive Sync | Optional experimental Standard or Private Encrypted Sync. The companion provides background opportunities while running. | Same modes. Android schedules background opportunities subject to device policy. |
| Software updates | GitHub release discovery, SHA-256 checks, and installer or portable update handoff. | GitHub APK discovery and ABI, package, version, and signing certificate verification before Android’s install handoff. |

Windows 11 is the primary desktop test platform. Windows 10 acceptance is
limited. The Windows packages are unsigned. Android builds are distributed
as signed GitHub APKs. Google Play publishing is separate. Windows ARM64
native packages, 32-bit Android packages, and iOS, macOS, Linux, and web app
distribution are outside the current support scope.

The planner works offline without a Todorbit account. Local SQLite and local
snapshots are plaintext unless protected by the operating system. App Lock
hides planner content in the interface. Optional Drive backup and Sync require
an enabled build and Google authorization. Standard Sync uses readable JSON.
Private Encrypted Sync encrypts data on the device and has its own recovery
credentials. [Privacy](PRIVACY.md) · [Drive Sync][sync] · [Drive backup](GOOGLE_DRIVE_BACKUP.md)

The [Beta 30 verification record][receipt] identifies the exact CI and
isolated runtime checks, including an Android 16 KiB upgrade. Physical Windows
multi-monitor and assistive technology coverage, Android launcher and
multi-file Share Sheet behavior, and live two-client Drive exchange are
tracked in [deferred verification][backlog].

[release]: https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30
[sync]: https://github.com/2HIK4/Todorbit/blob/253f4ed560018bfbb9acc9f1e110c823c77041d1/docs/GOOGLE_DRIVE_SYNC.md
[receipt]: https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/TODORBIT_BETA_30_CANDIDATE.md
[backlog]: https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/DEFERRED_VERIFICATION.md
