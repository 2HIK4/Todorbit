# Task revision safety: stale widget completion (2026-10-31)

## Cause and reproduction

[Windows CI 41176493080](https://github.com/2HIK4/Todorbit/actions/runs/41176493080)
failed `stale completion cannot overwrite an edit`, while
[41176579454](https://github.com/2HIK4/Todorbit/actions/runs/41176579454) passed the
unchanged application source. The test awaited task creation, editing and widget
completion in order against an isolated in-memory database. `updateTask` wrote
`DateTime.now()` directly as `updated_at`. The widget compared that timestamp,
and the repository used it in an SQL compare-and-swap (CAS). An edit at the same
clock value therefore did not invalidate the old snapshot. Atomic SQL alone
cannot distinguish two states that share their concurrency token.

The CI log does not contain the two timestamp values. The awaited test/code path
narrows acceptance to equal revisions; a new injected frozen task clock reproduces
the same expected-StateError/actual-success failure deterministically before the
fix. No arbitrary sleeps or weakened assertions are used. A previous 100-edit
stress pass could not establish safety because a moving clock hid the condition.

The Windows native completion path had a separate weakness: it accepted only the
task ID, so a delayed click could complete a subsequently edited task. Native
editor writes already had expected-timestamp CAS but could also reuse a clock
value. Existing native six-digit fractional timestamp strings can normalize to
three digits in Dart; comparing reserialized text could reject a legitimate CAS.

## Invariant and implementation

An operation from an older task state cannot mutate a newer state. A duplicate
request for an already attained completion state is a no-op, never another write
or recurrence advance. Deleted/cancelled/unavailable records are rejected.

- Keep the existing `updated_at` token and schema 22. On each task mutation choose
  the UTC wall time if it is strictly later than the previous revision; otherwise
  choose the previous revision plus one microsecond. Correctness therefore does
  not rely on wall-clock precision or progression. The value survives restart.
- Snapshot writers include the exact expected token in their SQL predicate.
  Unconditional task writers read the current token inside their transaction;
  scheduling batches advance beyond all reviewed revisions. Series combination,
  working state, prerequisites, archive/trash and restoration use this rule too.
- `LifeTask.revision` preserves raw SQLite token text. Widget projections and
  Flutter task CAS use it without lossy fractional-format normalization.
- Shared completion checks active state, duplicate state and expected revision
  inside the transaction, then performs the guarded mutation and recurrence
  advance before commit. An intervening writer causes conflict/rollback, not an
  overwrite. The Android precheck is not the final concurrency boundary.
  Direct stale repository calls retain their established rejection contract;
  the Android widget adapter re-reads a completion conflict and treats only an
  already attained desired state as a no-op. It never retries a stale write with
  a refreshed token. This preserves existing recurrence assertions.
- All Windows widget surfaces pass the displayed token. The native writer checks
  it in SQL within its transaction, advances revisions at Dart-compatible
  microsecond precision and treats duplicate completion as a no-op. Native
  editor changes follow the same token rule. Actual `completed_at` and recurrence
  calculations use actual completion time, not the logical revision clock.

No schema migration, token column, new backup format, data reset or cloud change
is introduced. Existing schema-22 backups and older native schema support remain.
Unmodified historical Windows binaries retain their historical behavior; this
change does not modify any existing Windows release asset.

## Deterministic coverage and release acceptance

`android_widget_action_test.dart` now runs with a frozen task clock and retains
its stale edit, repeated recurrence, same-title identity/reopen and deletion checks.
`task_revision_concurrency_test.dart` covers identical wall times and ABA edits,
50 rapid edits/clock rollback, independent SQLite connections with an explicit
barrier between widget validation and mutation, competing completion/edit, multiple
widgets/duplicate delivery, delayed delivery after reopen, legacy native token
format, trash/restore, working state and prerequisite edits. No test uses sleeps.

Native `TaskRevisionSelfTest.cs` covers frozen/sub-microsecond clock values,
monotonic edits after clock rollback, stale edit/completion across independent
connections, duplicate widgets, reopen and deleted records. Existing recurrence
self-tests additionally deliver duplicate completion and retain occurrence counts.

Final focused Dart checks: 18 tests pass, including the unchanged repository
recurrence rejection assertions. Full analysis and connected diagnostics pass;
244 Dart files pass formatting, seven release-validator tests and eight developer
helper tests pass. Native Release builds with zero warnings/errors and the
isolated persistence/revision self-test passes. The first full host run had 433
passes, one deliberate skip and the duplicate repository contract failure; that
behavior was corrected and its unchanged focused test now passes. The final full
host suite passes 434 tests with one deliberate skip.

Implementation commits are `57d7c4d` and `afe5241` (native action/history times
remain actual times, separate from logical revisions).
[Windows CI 41179574454](https://github.com/2HIK4/Todorbit/actions/runs/41179574454)
passes on `afe5241`, including 434 host tests, Windows Release, native packaged
self-test and installer/config gates.
[Android CI 41179298416](https://github.com/2HIK4/Todorbit/actions/runs/41179298416)
passes on `57d7c4d`, including the new host checks and real emulator integration.
Android application source is identical through `afe5241`; final publication-ref
CI and publication checks remain pending at this checkpoint. Rebuilt APK/AAB pass
all production identity/signature/ABI/SDK/alignment and bundle-separation checks.
Actual 22-to-23 installation, all-45-table/file/settings/widget preservation,
normal widget actions, delayed native capability after editing, and identical-APK
16 KiB runtime/persistent SQLite actions passed; see
[production acceptance](ANDROID_PRODUCTION_BETA_ACCEPTANCE.md). The first local signed rebuild stopped
on missing installed CMake in process PATH; the retry includes the verified Visual
Studio CMake/Ninja paths. No source policy or validator was weakened.
Earlier signing/OAuth acceptance is retained; its APK hash is not evidence for
the rebuilt artifact. Windows/Android cloud restoration remains owner-deferred.
