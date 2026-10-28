# Android development

Android work lives on `feature/android-mobile`. It shares schema 22, the
repository, recurrence/scheduling rules, controller, backup codec and theme
palettes with Windows. Android screens live under `lib/features/mobile/`;
Android adapters under `lib/platform/android/`. Windows IPC, updater and native
widget source remain independent.

The previous Android scaffold used the unpublished example identifier
`com.example.life_manager`. The development application identity is
`io.github.hik4.todorbit`; retain it and a durable signing identity before any
public Android distribution. Android minimum API is 26 (Android 8), target and
compile API 36 (Android 16). The installed Flutter 3.47.7/Dart 3.13.5 toolchain
is retained; no Windows toolchain upgrade is needed. Build, signing, OAuth,
installation and manual acceptance instructions are in [Android setup](ANDROID_SETUP.md).

## Feature inventory and acceptance matrix

Status is implementation evidence, not a claim of device acceptance. Update
the last column as checks complete. Existing desktop dialogs reused by mobile
still need narrow-screen and touch acceptance.

| Windows feature/source | Shared dependencies | Android surface/integration | Status / checks required |
| --- | --- | --- | --- |
| Today, All, Inbox, Anytime, Upcoming, Overdue, Waiting, Completed (`workspace`) | Controller task filters, repository | Mobile lists/dashboard, bottom navigation and drawer | Implemented; host layout/CRUD tests pass; device acceptance pending |
| Task fields, priorities, statuses, planned dates, deadlines, estimates | TaskEditor, TaskDraft, repository | Full-screen task editor, safe Back | Implemented; mobile create/complete/Back tests pass |
| Recurrence, progressive plans, series edits, dependencies, sequences | Domain recurrence, composition/series repositories | Existing editor sections and scheduling tools | Shared implementation exposed; host domain tests pass; touch workflow acceptance pending |
| Subtasks, checklists, resource links and managed attachments | Composition/resource repositories | Editor sections; Android document/URL access and FileProvider | Implemented in source; external Windows paths require relinking; device document acceptance pending |
| Calendar day/week/month, events, sessions, recurrence, conflicts | EventEditor, SessionEditor, occurrence identity | Touch month/week/day agenda, full-screen editors | Implemented; compact recurring-event/Back and shared calendar tests pass; device links pending |
| Projects/categories, icons, event colors | Controller organization APIs | Drawer destinations and organization management | Implemented in source; device organization workflow pending |
| Habits, daily logs, rest days, history | HabitsView, habit repository/domain | Shared responsive feature view | Implemented; compact host layout and existing behavior tests pass |
| Goals, links, milestones, progress history | GoalsView, goal repository/domain | Shared responsive feature view | Implemented; compact host layout and existing behavior tests pass |
| Actual time, manual entries, focus/timer recovery | TimeTrackingDialog, persisted timer runs | Editor timer access and active timer banner | Shared session model; lifecycle tests pending |
| Statistics/reports | ReportsView, reports repository | Shared responsive reports view | Implemented; compact host layout and shared calculation tests pass |
| Search, saved views, templates, routines | Search/template dialogs, filters | Drawer actions and mobile search | Implemented; compact search/template host tests pass; device workflows pending |
| Smart Reschedule, availability and history | Scheduling engine, preview/apply APIs | Existing approval dialog | Implemented; shared approval tests pass; touch workflow acceptance pending |
| Archive and Trash | TrashDialog, repository | Drawer action | Implemented; shared repository tests pass; mobile acceptance pending |
| Appearance, custom palettes, task/calendar preferences | Theme/task preferences, profile stores | Mobile settings; independent navigation preferences | Implemented; compact theme/settings and preference round-trip tests pass |
| Task and event reminders | Existing reminder models | Android notification channel, permission and alarm adapter | Native source implemented; planner tests pass; device delivery/permission checks pending |
| Tasks and Calendar desktop widgets | Shared task/event data and tokens | Separate RemoteViews AppWidgetProviders | Native source implemented; launcher/device checks pending; no Windows geometry import |
| App lock and privacy | PrivacyManager/PIN verifier | Android lifecycle, secure window, biometrics | Native adaptation implemented; device biometric/privacy checks pending |
| Local snapshot backup, restore, recovery, import/export | BackupService, MigrationGate | Android Storage Access Framework | Two-profile snapshot round trip passes; device picker/restart acceptance pending |
| Encrypted Google Drive snapshots | CloudBackupService/codec/provider | Android Google authorization | Code implemented; blocked for real acceptance by external OAuth package/certificate registration |
| Settings import/export, contributor credits | SettingsTransfer, official registry | Mobile settings/About | Implemented; host tests pass; device document acceptance pending |
| Tray, Explorer attachment, registry startup, Windows Hello, EXE updater | Windows runner/.NET | No Android equivalent; Android package manager owns updates | Justified Windows-only exclusions |

## Data and portability

Android keeps its active profile in app-private internal storage. No broad
storage permission is needed. The SQLite schema and verified snapshot format
are identical across Windows and Android. Restore replaces the database, does
not merge devices, preserves a Before restore snapshot and uses the existing
startup migration gate. Linked external file contents are not bundled; Windows
paths require relinking on Android. OAuth tokens, PIN policy, launcher widget
IDs, permission grants and navigation preferences are device-local.

Google Drive remains optional snapshot backup/restore, not synchronization.
Future synchronization needs per-record revisions/tombstones, device identity,
transactional outbox, conflict review and recurrence-family merge rules before
any automatic transfer can be enabled. No last-writer-wins database replacement
or background synchronization is introduced by Android support.
The [future synchronization proposal](FUTURE_CROSS_DEVICE_SYNC.md) defines the
transactional outbox, identity, conflict and security gates for a separate task.

## Build and signing

Keep signing keys and passwords outside Git. Debug APKs are development builds,
not public releases. A release must use the same long-lived upload/app signing
identity for every update. Public publishing remains a separate approval.

Build/test/device results and exact outstanding acceptance must be recorded here
before claiming the Android definition of done.
