# Data Safety, SQLite & Synchronization Engineering

This reference defines non-negotiable data-safety rules for SQLite persistence, Drift migrations, task concurrency, incremental Google Drive sync, and backup recovery.

---

## 1. Zero-Data-Loss Invariant

Todorbit is an offline-first productivity system. User tasks, planned schedules, events, notes, time logs, and preferences represent irreversible real-world personal commitments.

- **Forbidden**: `DROP TABLE`, resetting databases on open error, deleting profiles as a fallback, or catching exceptions to overwrite dirty state with empty defaults.
- **Transactions**: Any operation modifying more than one row or crossing relational boundaries (e.g. task with checklists, recurring occurrences, schedule reordering) MUST be executed inside `db.transaction(...)`.
- **Foreign Keys**: Enabled by default (`PRAGMA foreign_keys = ON`). Ensure cascading deletions are reviewed and intentional; soft deletion via `deleted_at` timestamps is the primary deletion pattern.

---

## 2. SQLite Schema Evolution (Current: Schema 28)

The schema version is tracked in `lib/data/app_database.dart` via `AppDatabase.currentSchemaVersion`.

### Migration Invariants:
1. **Never alter historical migrations**: Migrations from version `N` to `N+1` are permanent history.
2. **Deterministic Step Sequence**: In `migration.onUpgrade`, migrations execute strictly sequentially.
3. **Trigger Reinstallation**: When schema updates introduce new tables or columns tracked by sync, `sync_capture_*` triggers must be dropped and safely re-installed (`installSyncCaptureTriggers`).
4. **Migration Verification Gate**:
   - Every migration must be accompanied by a test in `test/database_initialization_test.dart` or `test/alarm_migration_test.dart`.
   - `MigrationGate` (`lib/data/migration_gate.dart`) inspects SQLite `user_version` before Drift opens the database. It enforces that unmigrated databases have an automated Before-Restore backup created before migration starts.

---

## 3. Concurrency Control & Compare-And-Swap (CAS)

Concurrency conflicts can occur between the main Flutter application, background alarms, and the native Windows companion widget (`TodorbitWidget.exe`).

### Concurrency Invariants:
1. **Revision Concurrency Token**:
   - `LifeTask.updatedAt` serves as the CAS token (`LifeTask.revision`).
   - Every write operation MUST advance `updated_at` beyond the predecessor timestamp:
     ```dart
     final revision = _nextTaskRevision(previous.updatedAt);
     ```
   - Even if the system clock freezes, runs backward, or has low resolution, `_nextTaskRevision` strictly guarantees `revision > previous.updatedAt`.
2. **Atomic CAS Update**:
   ```sql
   UPDATE tasks SET ... WHERE id = ? AND updated_at = ? AND deleted_at IS NULL;
   ```
   If rows affected != 1, throw `StateError('This task changed elsewhere. Reopen it before saving.')`.
3. **Widget State Verification**:
   - Windows and Android widget completions pass both `taskId` and `expectedRevision`.
   - A widget cannot complete a task if the task was edited in the main window since the widget rendered its snapshot.

---

## 4. Google Drive Synchronization & Backup Isolation

Incremental Synchronization and Snapshot Backups are independent systems with distinct security, UX, and storage contracts:

### Distinct Subsystems:
| Dimension | Google Drive Incremental Sync | Google Drive Snapshot Backups |
|---|---|---|
| **Storage Target** | `drive.appdata` hidden app folder | Dedicated user-selected Drive folder or root |
| **Data Format** | AES-GCM encrypted operation batches | Full SQLite snapshot ZIP / JSON export |
| **Protocol** | Protocol 2, causal vector clocks, immutable workspace heads | Timestamped whole-database snapshot |
| **Encryption** | Standard (account-bound) or Scoped Private (AES-256-GCM + user recovery code) | Encrypted with user passphrase (optional) |
| **Safety Barrier** | Conflict resolution dialog; Durability ACK | "Before Restore" automatic safety snapshot |

### Sync Engineering Rules:
- **Never overwrite local database on sync pull**: Sync applies discrete entity operations via `SyncApplyRepository`.
- **Soft Deletes**: Deletions are journaled tombstones. Tombstones sync across clients so remote devices delete the record rather than resurrecting it.
- **Immutable Operation Revisions**: Once an encrypted batch is published, its payload and causality proof are immutable.


## Task timer entry and planned-session removal (Prompt 2)

`startTimer(taskId)` is idempotent for the current task, returning the existing
running or paused run without writes. Other-task switching closes and opens work
intervals in one transaction using the reviewed timer revision and ownership checks;
a failed destination start rolls back the stop. Never infer task status from a timer.
Break phases start without creating work intervals. `deletePlannedSession` checks
session revision, upcoming outcome and absent actual start inside the Trash
transaction; actual work and task identity survive. Cover these contracts using
`task-timers` in `tools/dev/features.json`. Schema remains 29; no migration applies.

## Scheduling proposal boundaries

- Deduplicate scoped UUIDs before building a scheduling proposal; a Set used for
  checkboxes does not deduplicate a separate ordered input list. Verify one
  change/history entry per target and guard preview/apply re-entry before await.
- Preview and cancellation are reads only. Apply the complete reviewed proposal
  through the existing transaction/stale checks; do not silently filter partial
  swaps, recurrence collisions or eligibility issues after review.
- A post-commit refresh can fail after persistence succeeds. Report an unconfirmed
  result accurately, invalidate the proposal, and require a fresh read before
  retrying; never promise rollback solely because the UI await threw.

## Local file staging and independent copy boundaries

- Stream large file hashing and writes: Ingesting files approaching the maximum
  size limit (e.g. 32 MiB) must stream bytes via `sha256.bind(source.openRead())`
  and OS file copying rather than reading the entire byte array into the Dart
  heap on the UI isolate.
- Dual-path I/O architecture: Pair synchronous metadata hydration (`loadSync()`)
  for zero-jank frame-1 UI mounting and deterministic test execution with genuine
  asynchronous methods (`load()`, `save()`, `addFile()`, `addBytes()`) so bulk
  disk operations do not block Flutter's main isolate.
- Local filesystem durability boundaries: Local files stored on disk outside the
  SQLite database (e.g. `TodoPilot/shared_inbox/`) are NOT captured by SQLite
  snapshots (`BackupService`) or Google Drive sync journals. Once attached to a
  task, copy the bytes into managed SQLite `task_resources` with independent copy
  semantics so inbox deletion never breaks task attachments and vice versa.
