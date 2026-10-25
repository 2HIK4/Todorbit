# Architecture

Google Drive backups are an optional layer under `lib/data/cloud/` and Settings > Backups & Cloud. `CloudStorageProvider` abstracts remote objects; Google OAuth and secure token storage are separate from Drive HTTP operations. `CloudBackupService` reuses `BackupService` for SQLite-safe snapshots and staged restore, while `CloudBackupCodec` encrypts a versioned portable manifest with AES-256-GCM and a passphrase-derived key. The manifest includes the existing shareable settings JSON; OAuth tokens, PIN policy and device-only controls remain local. Full restore applies portable personalization after the database opens/migrates and before the opened receipt. Settings-only restore reuses selective settings transfer. There is no background synchronization or cloud retention. See `GOOGLE_DRIVE_BACKUP.md` for format limits, setup, portability and verification boundaries.

- Flutter Material 3 UI with a compact Fluent-inspired desktop layout.
- Riverpod owns application state. Feature widgets observe a controller, while data access stays in the repository.
- Drift opens SQLite in a background isolate. The repository owns SQL, migrations, transactions, and mapping to immutable domain objects. Initial schema uses explicit SQL to keep migration changes reviewable.
- SQLite lives in the per-user application-support directory. UUID identifiers and UTC modification fields prepare data for future synchronization; no synchronization is implemented.
- `lib/domain/`: entity models. `lib/data/`: SQLite and repository. `lib/features/`: screens and reusable controls. `lib/app/`: shell, state, theme.
- Windows widget and tray code live behind a separate native-companion boundary.

The integrated Windows widget is a separately packaged .NET companion,
implemented in `experiments/widget-shell-probe` and published beside
`Todorbit.exe` as `TodorbitWidget.exe`. Its persistent display is one owner-drawn
native HWND created directly as an Explorer `SHELLDLL_DefView` child, while
keyboard entry uses short-lived activated WinForms top-level surfaces. This avoids
both shell-child Flutter focus and post-paint WinForms reparenting. A
narrow native repository reads and writes only task fields already owned by
schemas v4 through v20, validates the schema before opening, uses UUIDs/UTC timestamps and
transactions, rejects stale edits, and never creates or migrates the database.
A named-pipe command boundary lets Flutter show, hide, toggle, refresh, open
Quick Add, select Today/Inbox/All Tasks/Upcoming, or close the single native
instance. Both processes use
debounced filesystem events on the SQLite database/WAL rather than polling.
The companion owns its tray lifecycle, persists geometry/view separately from
the shared appearance preference, clamps placement to connected monitors, and
makes bounded recreation attempts if Explorer destroys its child HWND. Manual
acceptance on an earlier widget build observed visibility, `Win+D`, input,
editing, resizing, icons, views, theme synchronization, and independent
main-app lifecycle. The Todorbit 1.0.3 package needs direct repetition of
these checks. Explorer hosting remains an undocumented compatibility dependency
and its diagnostics are retained.

`Todorbit.exe --widget` is a compatibility entry point that launches the
packaged native companion and exits before creating a Flutter engine. The known
broken Flutter desktop-child implementation is reachable only through the
explicit diagnostic flag `--legacy-flutter-widget`; normal application and
widget controls never select it. The native companion is also directly
launchable as `TodorbitWidget.exe --widget`.

Data integrity: foreign keys on, WAL, indexed common filters, schema versioning, and transactions for related writes. Date-only values use local calendar dates (`YYYY-MM-DD`); instants use UTC ISO 8601.

Schema v16 extends `fixed_events` in place. Its recurrence fields are local
date rules; `event_occurrence_changes` stores only cancellations and manually
changed occurrences keyed by the original nominal date. Calendar windows are
projected on read without bulk materialization. Linked event generations carry
active date boundaries for future-series edits. The native task widget accepts
the additive schema but does not edit or notify on calendar events.

Schema v17 uses `entity_icons` for UUID-identified task, series, category, and
project icon keys; fixed events use their own icon column. Schema v18 uses
`task_checklist` and `task_parent_links`. Checklist rows do not carry task
metadata; child tasks remain ordinary task rows. Active views filter children
when their parent is archived or in Trash. Permanent owner deletion cascades
checklist and child-link cleanup while linked child tasks restrict parent purge.

Schema v19 adds `progressive_plans`, ordered `progressive_plan_steps`, and
`progressive_plan_assignments` keyed by stable recurrence occurrence IDs.
Assignment snapshots preserve historical activity text. The repository derives
the occurrence position across recurrence generations from date-only rules,
applies explicit carry markers, and updates future untouched assignments in
transactions. The native widget accepts the additive schema but does not edit
study plans.

Schema v20 adds `event_reminder_deliveries`. The native tray companion reads
event recurrence rules and per-date exceptions, checks a short due window,
and atomically claims each event occurrence before showing a notification.
It honors cancellations and moved occurrences, and does not require bulk
materialization of a semester's events. The main app starts the companion when
saved reminders exist; the event editor requires the packaged companion before
enabling a new reminder.

Optional UI privacy is owned by `PrivacyManager` and a per-user policy outside
SQLite. The PIN verifier uses PBKDF2-HMAC-SHA256 and a persisted wrong-attempt
delay. Flutter renders only the lock shell while locked. The native companion
independently reads the policy and a five-second session bound to a live main
app PID; it suppresses task reads, edits, and painting when the session is
missing or invalid. The companion resolves the process `APPDATA` environment
variable, matching Flutter's isolated-profile and production data paths.
This boundary does not encrypt SQLite or protect against filesystem access.

Before backup or opening Drift, startup reads the existing SQLite schema with
a read-only connection. Older schemas require an explicit upgrade choice;
approval then enters the existing verified Before upgrade backup and migration
path. No migration is attempted when the user exits from that choice.

Schema v4 adds task duration/remaining-work estimates and a scheduling lock,
weekly availability and date exceptions, plus focused scheduling operation and
change history. Migrations from v1, v2, and v3 preserve existing rows. Smart
Reschedule applies reviewed task/session changes in one repository transaction
after optimistic `updated_at` and before-value checks. History stores only the
affected scheduling fields, not full-database snapshots. Restores are new
operations and compare current scheduling values with the selected operation's
after-state so later manual changes remain protected.

Schema v5 adds `task_sequences`, `sequence_tasks`, and `task_dependencies`.
Sequences persist explicit positions; dependencies persist directed prerequisite
edges. Repository transactions validate cycles and keep sequence reorders
atomic. Smart Reschedule's reviewed dependency warnings are checked again at
Apply, so a newly conflicting prerequisite cannot silently bypass the preview.
The native widget accepts v4 through v12 and never migrates the database.

Schema v6 separates recurring rule templates from independent task occurrences.
Schema v7 links rule generations with a family ID and active date boundaries.
Series edits use a read-only impact preview, a task/occurrence/link revision
snapshot, and one transaction for the split, materialization, collision choices,
and audit row. The old version remains for historical tasks. Smart Reschedule
checks same-family planned-date collisions inside its apply transaction and
records each reviewed choice. The native widget respects completion-series
boundaries when advancing or reopening occurrences.

Schema v8 stores habits, daily value logs, rest days, and entry-change history
apart from tasks. The domain computes rates and streaks from stored values and
schedule dates; it does not materialize missed habit tasks. The native widget
accepts v8 without reading or writing the habit tables.

Schema v9 stores goals, milestone checkpoints, an append-only manual adjustment
ledger, and foreign-keyed links to tasks, projects, and binary habits. Derived
progress is recalculated from current completed tasks and stored habit logs.
Direct and project task links use one contribution per task ID, so the same
completion cannot count twice. Goal completion and archiving are independent
of the numeric total. The native widget accepts v9 without goal access.

Schema v10 stores timer runs, actual work intervals, and manual-correction
history independently of planned sessions. A partial unique index admits one
active timer and one open interval per run. The repository writes timer state
and intervals in transactions. AppController heartbeats a running timer and
stops heartbeat when recovery review is required. Actual totals merge
overlapping intervals. The native widget accepts v10 without time access.

Schema v11 stores named task, recurring routine, and project template recipes
as JSON snapshots with a format version. Instantiation checks the template
revision and writes new project/task/recurrence identities in a transaction.
Project prerequisite edges are remapped through the new task IDs. The native
widget accepts v11 without template access.

Schema v12 stores named, versioned task-filter JSON definitions. The
controller evaluates filters against its loaded task/category/project and
dependency snapshot using local relative dates, then renders the same task
rows used by built-in views. Saving/editing/deleting a view writes through the
repository with revision checks. The native widget accepts v12 without view
access.

Schema v13 marks tasks, projects, categories, fixed events, planned sessions,
and recurrence families as archived or deleted without removing linked rows.
Active reads and the native companion filter those markers; the repository
owns transactional restore and checks related records before permanent purge.
Permanent purges write tombstones with entity IDs and UTC deletion times.
Recurring occurrence slots remain after an individual task purge so bounded
materialization cannot recreate that occurrence. Startup performs no Trash
purge.

Reports use a read-only repository query that includes archived tasks and
excludes Trash, then a pure domain calculator merges actual work intervals by
local day and combines persisted habit and goal state. Reports add no schema
tables or synthetic history.

Schema v14 stores opt-in notification settings and a unique delivery ledger
in SQLite. The native companion owns the tray timer and claims each local-day
due reminder or summary in a transaction before invoking WinForms NotifyIcon.
It can run with its widget hidden. Flutter writes settings through the
repository and starts the companion after database migration if enabled.
Notifications depend on the companion process and Windows notification
settings; the SQLite ledger records attempted display, not user receipt.

`BackupService` runs SQLite integrity checks and `VACUUM INTO` in a worker
isolate, producing one self-contained file under the per-user `backups`
directory. The startup path invokes it before opening Drift, so a schema
upgrade always has a verified source snapshot. Automatic retention touches
only backup files with Life Manager's managed automatic name pattern.
Restoration is queued in an atomic local marker containing the chosen managed
backup's size, modification time, schema, and SHA-256 digest. The next startup
closes the native companion and uses SQLite's online backup API to copy the
reviewed snapshot into the live database before Drift opens. It creates an
unpruned Before restore snapshot first and refuses a changed file or an active
external reader. The marker remains until restoration and verification succeed.

The deterministic engine in `lib/domain/` has no database dependency. It keeps
local date-only task plans separate from UTC work-session intervals and fixed
events. Local availability is converted at the proposed date, so calendar-day
movement observes the host time zone and preserves session duration across date
and daylight-saving boundaries. The repository remains the only Flutter writer.

Schema v2 adds `fixed_events` with UTC start/end instants and a start-time index. The v1→v2 migration preserves task rows.

Schema v3 adds `work_sessions` with separate outcome and optional recorded start. Both v1→v3 and v2→v3 upgrade paths are supported. Session status does not drive parent task completion.
