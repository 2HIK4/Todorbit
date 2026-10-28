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
is retained; no Windows toolchain upgrade is needed.

## Feature inventory and acceptance matrix

Status is implementation evidence, not a claim of device acceptance. Update
the last column as checks complete. Existing desktop dialogs reused by mobile
still need narrow-screen and touch acceptance.

| Windows feature/source | Shared dependencies | Android surface/integration | Status / checks required |
| --- | --- | --- | --- |
| Today, All, Inbox, Anytime, Upcoming, Overdue, Waiting, Completed (`workspace`) | Controller task filters, repository | Mobile lists/dashboard, bottom navigation and drawer | Pending mobile implementation and CRUD tests |
| Task fields, priorities, statuses, planned dates, deadlines, estimates | TaskEditor, TaskDraft, repository | Full-screen task editor, safe Back | Shared editor available; mobile host pending |
| Recurrence, progressive plans, series edits, dependencies, sequences | Domain recurrence, composition/series repositories | Existing editor sections and scheduling tools | Shared implementation; mobile access/acceptance pending |
| Subtasks, checklists, resource links | Composition/resource repositories | Editor sections; Android document/URL access | Shared implementation; Windows external paths require relinking |
| Calendar day/week/month, events, sessions, recurrence, conflicts | EventEditor, SessionEditor, occurrence identity | Touch month/week/day agenda, full-screen editors | Pending mobile implementation and identity tests |
| Projects/categories, icons, event colors | Controller organization APIs | Drawer destinations and organization management | Pending mobile implementation |
| Habits, daily logs, rest days, history | HabitsView, habit repository/domain | Shared responsive feature view | Mobile layout acceptance pending |
| Goals, links, milestones, progress history | GoalsView, goal repository/domain | Shared responsive feature view | Mobile layout acceptance pending |
| Actual time, manual entries, focus/timer recovery | TimeTrackingDialog, persisted timer runs | Editor timer access and active timer banner | Shared session model; lifecycle tests pending |
| Statistics/reports | ReportsView, reports repository | Shared responsive reports view | Mobile layout acceptance pending |
| Search, saved views, templates, routines | Search/template dialogs, filters | Drawer actions and mobile search | Mobile access/acceptance pending |
| Smart Reschedule, availability and history | Scheduling engine, preview/apply APIs | Existing approval dialog | Mobile access/acceptance pending; no automatic rescheduling |
| Archive and Trash | TrashDialog, repository | Drawer action | Mobile acceptance pending |
| Appearance, custom palettes, task/calendar preferences | Theme/task preferences, profile stores | Mobile settings; independent navigation preferences | Pending mobile implementation and round-trip tests |
| Task and event reminders | Existing reminder models | Android notification channel, permission and alarm adapter | Pending Android implementation/device tests |
| Tasks and Calendar desktop widgets | Shared task/event data and tokens | Separate RemoteViews AppWidgetProviders | Pending Android implementation/device tests; no Windows geometry import |
| App lock and privacy | PrivacyManager/PIN verifier | Android lifecycle, secure window, biometrics | Pending Android adaptation/device tests |
| Local snapshot backup, restore, recovery, import/export | BackupService, MigrationGate | Android Storage Access Framework | Pending adapter/cross-platform tests |
| Encrypted Google Drive snapshots | CloudBackupService/codec/provider | Android Google authorization | External OAuth package/certificate registration required; code pending |
| Settings import/export, contributor credits | SettingsTransfer, official registry | Mobile settings/About | Mobile access/acceptance pending |
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

## Build and signing

Keep signing keys and passwords outside Git. Debug APKs are development builds,
not public releases. A release must use the same long-lived upload/app signing
identity for every update. Public publishing remains a separate approval.

Build/test/device results and exact outstanding acceptance must be recorded here
before claiming the Android definition of done.
