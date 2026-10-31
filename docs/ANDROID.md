# Android development

The first production-signed [Android beta is public](ANDROID_BETA_1_PUBLICATION.md):
`1.0.19-beta.1` (23), Android 8.0+ on ARM64/x86-64. See
[phone installation and Windows backup testing](ANDROID_PHONE_BETA_TESTING.md).
Windows/Android cloud restoration remains unverified under the owner's scoped
first-beta deferral; this is not a Stable or Play release.

Android work lives on `feature/android-mobile`. It shares schema 22, the
repository, recurrence/scheduling rules, controller, backup codec and theme
palettes with Windows. Android screens live under `lib/features/mobile/`;
Android adapters under `lib/platform/android/`. Windows IPC, updater and native
widget source remain independent. Android now has separate GitHub and Play
update providers; see [Android updates](ANDROID_UPDATES.md), [Drive/OAuth](ANDROID_GOOGLE_DRIVE.md)
and [signing/release preparation](ANDROID_RELEASE.md).

The previous Android scaffold used the unpublished example identifier
`com.example.life_manager`. The development application identity is
`io.github.hik4.todorbit`; retain it and a durable signing identity before any
public Android distribution. Android minimum API is 26 (Android 8), target and
compile API 36 (Android 16). The installed Flutter 3.47.7/Dart 3.13.5 toolchain
is retained; no Windows toolchain upgrade is needed. Build, signing, OAuth,
installation and manual acceptance instructions are in [Android setup](ANDROID_SETUP.md).

## Feature inventory and acceptance matrix

Complete means the feature is implemented with the checks listed below; it does
not claim every phone/OEM behavior has been observed. Partial identifies an
outstanding implementation or acceptance gate; Blocked needs an external owner
dependency; Not Applicable is a justified Windows-only exclusion. No supported
feature in this inventory is Not Started. Exact current artifact/device evidence
and remaining acceptance are in [the continuation report](ANDROID_ACCEPTANCE.md).

| Windows feature/source | Shared dependencies | Android surface/integration | Status / checks required |
| --- | --- | --- | --- |
| Today, All, Inbox, Anytime, Upcoming, Overdue, Waiting, Completed (`workspace`) | Controller task filters, repository | Mobile lists/dashboard, bottom navigation and drawer | Complete; host layout/CRUD tests and Android task workflow pass |
| Task fields, priorities, statuses, planned dates, deadlines, estimates | TaskEditor, TaskDraft, repository | Full-screen task editor, safe Back | Complete; Android create/edit/complete/persistence and manual Back checks pass |
| Recurrence, progressive plans, series edits, dependencies, sequences | Domain recurrence, composition/series repositories | Existing editor sections and scheduling tools | Complete shared implementation; domain and compact editor tests pass; extended phone workflows remain manual |
| Subtasks, checklists, resource links and managed attachments | Composition/resource repositories | Editor sections; Android document/URL access and FileProvider | Complete; shared composition/resource tests pass; a managed PDF was imported through SAF and rendered by Android's viewer; Windows paths require relinking |
| Calendar day/week/month, events, sessions, recurrence, conflicts | EventEditor, SessionEditor, occurrence identity | Touch month/week/day agenda, full-screen editors | Complete; host recurring editors/calendar tests and Android event workflow/widget event link pass; recurring native links remain manual |
| Projects/categories, icons, event colors | Controller organization APIs | Drawer destinations and organization management | Complete; shared CRUD tests pass, Android workflow preserves category/project identity; full touch organization workflow remains manual |
| Habits, daily logs, rest days, history | HabitsView, habit repository/domain | Shared responsive feature view | Complete; compact host layout and existing repository/widget behavior tests pass |
| Goals, links, milestones, progress history | GoalsView, goal repository/domain | Shared responsive feature view | Complete; compact host layout and existing repository/widget behavior tests pass |
| Actual time, manual entries, focus/timer recovery | TimeTrackingDialog, persisted timer runs | Editor timer access and active timer banner | Complete for scoped API 35 acceptance; start, short process interruption, reboot with a longer gap, explicit review and stopping at the last checkpoint observed; shared time-entry tests pass |
| Statistics/reports | ReportsView, reports repository | Shared responsive reports view | Complete; compact host layout and shared calculation tests pass |
| Search, saved views, templates, routines | Search/template dialogs, filters | Drawer actions and mobile search | Complete; narrow search/template UI and shared saved-view/routine tests pass; extended phone workflows remain manual |
| Smart Reschedule, availability and history | Scheduling engine, preview/apply APIs | Existing approval dialog | Complete; shared approval/scheduling tests pass; extended phone workflows remain manual |
| Archive and Trash | TrashDialog, repository | Drawer action | Complete; shared archive/Trash repository tests pass; extended phone workflow remains manual |
| Appearance, custom palettes, task/calendar preferences | Theme/task preferences, profile stores | Mobile settings; independent navigation preferences | Complete; compact theme/settings and independent preference round-trip tests pass |
| Task and event reminders | Existing reminder models | Android notification channel, permission and alarm adapter | Complete for scoped API 35 acceptance; deny/regrant, background task/event delivery, receipts/duplicate prevention, notification links and cold refresh job observed; physical Doze/time-zone/API coverage remains manual |
| Tasks and Calendar desktop widgets | Shared task/event data and tokens | Separate RemoteViews AppWidgetProviders | Partial acceptance; both placed/configured with real data, task/event links, locked privacy, package update and reboot persistence observed on API 35; resize/OEM breadth tracked in acceptance |
| App lock and privacy | PrivacyManager/PIN verifier | Android lifecycle, secure window, biometrics | Complete for scoped API 35 acceptance; PIN/cold restart, cancellation/success with Android credential, secure capture and locking over an editor observed; physical fingerprint/face remains manual |
| Local snapshot backup, restore, recovery, import/export | BackupService, MigrationGate | Android Storage Access Framework | Complete; actual SAF Android export opens on Windows; Windows import/confirmation/Recent-apps restart retains IDs and a verified Before Restore copy; shared migrations/bidirectional tests pass |
| Encrypted Google Drive snapshots | CloudBackupService/codec/provider | Android Google authorization enabled by default | Code complete; real acceptance awaits OAuth package/certificate registration and authorized cross-client discovery |
| Settings import/export, contributor credits | SettingsTransfer, official registry | Mobile settings/About | Complete shared behavior; host portability/credits tests pass; document picker workflows remain manual |
| Software Updates | Shared channel/version/preferences; independent Android release metadata and native verification | GitHub APK installer or official Play flow, selected at build time | Implemented; exact automated/device evidence in acceptance record |
| Tray, Explorer attachment, registry startup, Windows Hello, EXE updater | Windows runner/.NET | Android package manager owns updates; no Windows helper on Android | Not Applicable for Windows-only mechanisms |

| Infrastructure area | Status | Evidence / remaining gate |
| --- | --- | --- |
| One repository and platform boundaries | Complete | Shared schema/controller/domain; separate native adapters, no Windows IPC on Android |
| Android package/toolchain/API 36 setup | Complete | APK/AAB builds; minimum API 26, arm64/x86-64 development artifacts |
| SQLite persistence, migrations and safe restore | Complete | Shared migration/backup suite and real Android reopen/staged-restore workflow |
| Development packaging | Complete | Debug-signed APK/AAB and native alignment checks; exact evidence in acceptance report |
| Production signing | Blocked | Owner's durable keystore required; release gate fails closed |
| Deep links and lifecycle breadth | Partial acceptance | Cold task URI/notification, widget task/event links, queued event notification preserving an editor draft and locking over an editor observed; broader locked/recurring/API/low-memory coverage remains manual |
| Performance and battery | Partial acceptance | Bounded native projections/jobs, no permanent service; physical startup/large database/Doze profiling unobserved |
| Accessibility and locale coverage | Partial acceptance | Host RTL/dark/large-text/narrow/tablet checks pass; physical TalkBack/cutout/OEM coverage unobserved |
| CI | Partial acceptance | Android jobs configured and local commands pass; remote Windows/Linux workflow has not been pushed or run |
| Windows regression protection | Complete | Full shared suite, isolated Windows Release and packaged companion self-test pass; no Windows native behavior changed |
| Documentation | Complete | Architecture/parity, setup/signing/OAuth, acceptance, future sync design and testing guide |

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
