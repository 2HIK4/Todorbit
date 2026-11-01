# Drive sync and restore work — 2026-10-31 to 2026-11-01

Branch: `feature/drive-sync-recovery`, baseline `f62cd7b`.
The owner authorizes coordinated publication after all mandatory gates pass;
real Drive testing is currently restricted to mocked transport by owner choice.
The separate button-only beta 3 publication is recorded in
[its receipt](SYNC_BUTTON_PREVIEW_PUBLICATION.md). Full sync remains unpublished;
no real Drive account or personal profile is used for this implementation.

## Plan and scope

1. Repair restore staging, opened receipts and interrupted-finalization recovery.
2. Audit portable records and every writer before introducing durable operations.
3. Implement encrypted workspace pairing, causal incremental exchange, conflict
   decisions and restore reconciliation, with deterministic failure tests.
4. Add foreground controls and supported platform background scheduling.
5. Complete exact-source CI, signing, migration, packaging and release acceptance.

## Restore diagnosis

The old cloud service commits `pending-restore.json` before fingerprinting the
snapshot and updating `cloud-transfer-history.json`. A failure in either later
step escapes to the generic UI error while startup can still apply the restore.
This is a reproducible lifecycle defect consistent with the reported symptom;
the original phone failure has no captured stage/exception, so its precise cause
is not established. It must not be described as a confirmed device diagnosis.

Transfer baseline metadata now travels in the atomic restart marker and then
the applied/opened receipt. Cloud-history writes are no longer part of restore
staging. Legacy opened receipts can report their actual completion time without
inventing a baseline. The screen explicitly distinguishes prepared restoration
from current active data and requests closing/reopening the app.

Replacement intent and the incoming logical digest are persisted before copying
SQLite. If replacement finished but receipt finalization was interrupted,
startup recognizes the exact restored contents and finishes finalization while
retaining the original Before Restore snapshot. Changed target data still takes
the existing refusal/review path. Receipt files use temporary-write/rename.

## Verification ledger

All new checks use disposable data. The full host checkpoint and its focused
correction pass are recorded below; no coordinated release build has run.
Detailed helper receipts/logs stay in ignored `.buildlog/verify/`.

| Invocation | Source / purpose | Result | Reason |
| --- | --- | --- | --- |
| Read `.buildlog/verify/20261031-173959-9477/result.json` and `20261031-174757-6907/result.json`; tail `android-drive-updates-full-tests.log` | Historical updater/fingerprint and Drive evidence | Inspected only | Unchanged updater remains outside the restore boundary; old results do not prove changed restore logic |
| `dart format` on six changed Dart paths | Working tree based on `f62cd7b`; formatting | Sandbox wrapper stalled; escalated invocation passed | SDK/cache access; no test rerun |
| Feature `drive`, plus backup service/import-export/managed attachments/widget upgrade; `.buildlog/verify/20261031-212328-0225/result.json` | Restore staging/receipts and consumers, working tree | 69 tests, analysis, formatting and diff check passed | New restore behavior invalidated historical restore evidence |
| Quick restore checks; `20261031-212838-2978/result.json` | Local-restore retry guard and new compact UI tests | Analysis failed: fixture missing required `clientId`; tests not run | New local retry invariant and UI assertions; fixture corrected |
| Quick restore checks; `20261031-213003-6274/result.json` | Final local retry guard, cancellation callback, compact UI | Analysis/format pass; 40 tests passed, two UI tests failed | UI fixture tapped an offscreen section title; restore/data assertions passed |
| Quick UI checks; `20261031-213148-5907/result.json` | Corrected outer scroll before cancellation | Six passed, two failed | Cancel remained unbuilt in the nested lazy list; prior data checks retained |
| Quick UI checks; `20261031-213346-6195/result.json` | Explicit nested-list scroll | Six passed, two failed | Reached Cancel, but nested viewport offsets left it outside the screen |
| Quick UI/core checks; `20261031-213606-9064/result.json` | Pump after nested ensureVisible, causal tests | 15 passed, two UI failures | Isolated the embedded fixed-height scrolling defect; causal assertions passed |
| Quick UI checks; `20261031-213704-1793/result.json` | Embedded panel uses parent scroll; standalone retains scrolling | Eight passed, analysis/format/diff pass | Runtime layout fix invalidated prior UI evidence; final compact/large-text cancellation passed |
| Quick causal checks; `20261031-213539-5167/result.json` | New revision DAG | Analysis stopped on two brace lints; tests not run | New code; corrected before behavioral checks |
| Quick codec checks; `20261031-213825-3472/result.json` | New encrypted batch codec | Analysis stopped on four brace lints; tests not run | New code; corrected before behavioral checks |
| Quick causal/codec checks; `20261031-213854-9741/result.json` | Transitive ancestry validation, absent-vs-null conflicts, encryption | 15 passed; analysis/format/diff pass | Added transitive and field-presence invariants; first codec behavioral execution |
| Dart MCP `listDtdUris`, `hot_reload` before access change | Live inspection | Tool approval policy denied | No runtime change or personal-profile access |
| Dart MCP discovery/connect after access change | IDE DTD `ws://127.0.0.1:63713/...` | Connected, no running apps | Live reload unavailable; no live UI claim |
| `verify.ps1 -Plan` | Command selection | Initial direct script blocked by local execution policy; explicit child PowerShell preview passed | No tests executed by preview |
| `dart format` after each retry-guard and UI fixture edit | Changed paths only | Passed | Formatting newly edited source/assertions |
| Quick Drive transport; `20261031-214211-9438/result.json` | Sync namespace and change feed, working tree after `dcb578a` | Analysis stopped on fixture brace lint; no tests | New transport code; lint corrected |
| Quick Drive transport; `20261031-214321-4584/result.json` | Default backup regressions and new change feed | 16 passed; analysis/format/diff pass | First behavioral execution of new feed/account guards |
| Quick Drive transport; `20261031-214404-9579/result.json` | Added sync upload identity/read-back assertion | 17 passed; analysis/format/diff pass | Shared upload fixture changed; new namespace upload assertion required |
| Quick SQLite capture; `20261031-234025-7760/result.json` | Schema 23, inactive capture, atomic outbox, migration/startup | Analysis stopped on two brace lints; no tests | New code; braces corrected |
| Quick SQLite capture; `20261031-234256-6899/result.json` | Journal/reopen/quarantine plus startup/migration interruption | 30 passed; analysis/format/diff pass | Added restored-queue quarantine and stable fingerprint assertions |
| Quick restore integration; `20261031-234515-3754/result.json` | Startup guard, resource-path exclusion, existing restore fixtures | 50 passed, three legacy-fixture failures | Historical fixture relabeling retained new schema objects; primary-key capture was also refined during this run, so this is not final DDL evidence |
| Quick capture/restore/domain migration; `20261031-234853-9753/result.json` | Final key-move capture, corrected synthetic legacy fixtures, all affected migration consumers | 104 passed; analysis/format/diff pass | Legitimate event-occurrence key moves need an old-key tombstone; old-schema fixtures now remove only inactive/empty sync schema before relabeling |
| Quick journal; `20261031-235217-8730/result.json` | Additional explicit public schema-22 migration and attachment-ID/byte preservation | Nine passed; analysis/format/diff pass | New upgrade-path assertion; production source unchanged and the other 96 integration checks remain reusable |
| Full host integration; `20261031-235306-4534/result.json` | Shared-schema checkpoint, complete host analysis/serial tests | 480 passed, one existing opt-in skip, five stale fixture/assertion failures; full analysis/format passed | First broad invocation in this task; Python/doc steps did not run because the host step failed. Production source stayed frozen; test-only corrections followed |
| Targeted final assertions; `20261101-000234-0657/result.json` | Cloud roundtrip, v7/v8 and other historical migrations, fresh-profile control row, native revision/CAS format | 55 passed; analysis/format/diff pass | Corrected five full-run failures and all newly edited legacy fixture consumers; other host passes retained rather than repeating the full suite |
| `python -m unittest discover -s tools -p test_dev_verify.py` | Changed catalog and helper plans, `.buildlog/sync-dev-helper-tests.log` | Eight passed | New sync feature group and database coverage invalidate prior catalog evidence |
| `python tools/dev/check-docs.py` | Developer links/map/catalog, `.buildlog/sync-docs-check.log` | Zero errors | New checkpoint/routing links; subsequent decision link was reviewed against the same existing checkpoint |
| Read-only GitHub release API and `git ls-remote --tags origin` | Version history | Latest Android beta 2 (`500a9a8`), Windows 1.0.18; no tag/release changed | Required release history inspection; no artifacts downloaded or candidate version selected |
| `git diff 500a9a8 -- tools/prepare-android-release.py tools/test_prepare_android_release.py pubspec.lock`; Python version | Reuse check for release validator | Unchanged; Python 3.14.5 | Eleven validator checks from existing receipts retained for unchanged tooling; mandatory final candidate CI remains pending |
| `flutter test --no-pub --concurrency=1 --reporter=expanded .buildlog/native-capture-check/fixture_test.dart` | Export synthetic actual-schema captured task for cross-language verification | One passed; `.buildlog/native-capture-check/fixture.log` | Dart connection tests cannot prove the native Microsoft.Data.Sqlite library executes these triggers |
| `dotnet run --project .buildlog/native-capture-check/NativeCapture.csproj --configuration Release` | Builds production native Release project and exercises its actual repository against the Dart-created synthetic database | Passed; `.buildlog/native-capture-check/native.log` | Child APPDATA/LOCALAPPDATA and explicit database were verified beneath `.buildlog/`; completion journaled exactly once, duplicate delivery did not write |
| `tools/dev/native-self-test.ps1 -Executable experiments/widget-shell-probe/bin/Release/net10.0-windows/TodorbitWidget.exe` | Production native Release schema compatibility and regressions | Passed; `.buildlog/sync-native-self-test.log` | Maximum supported schema changed to 23; isolated child environments printed before launch |
| Dart MCP hot reload after access change | IDE DTD | No active app connection | Live inspection unavailable; no personal profile launched |

New regression assertions cover unavailable cloud history, interrupted receipt
finalization, retaining the original recovery snapshot, rejecting edits after
interruption, and compact light/dark restart status/cancellation at 1.5x text.

## Current sync implementation boundary

Pure `CausalRecord` retains immutable revision ancestry, missing-parent
operations, tombstones and competing versions. It merges independent field
edits against a unique common base, conservatively rejects ambiguous ancestry,
supports coupled semantic fields, and rejects stale resolutions. Eleven tests
include all 24 permutations of an independent/concurrent operation fixture.
`SyncBatchCodec` uses separate AES-256-GCM protocol framing and a randomly
generated 256-bit recovery key. Account and workspace are authenticated context;
backup passphrases/formats remain independent. Four tests cover pairing-code
roundtrip, nonce freshness, tampering and identity/schema isolation.

These are primitives, not an activated sync service. No keys have been generated
for a real account or saved to a user profile. Commit `b0b254a` contains the
restore checkpoint; `dcb578a` contains the causal/encryption primitives.

Drive transport now provides a separate `todorbit-sync` application namespace,
batch identities/extensions, chunked verified uploads and explicit paged change
tokens. Account identity is rechecked after token acquisition and responses.
Missing cloud objects are removal signals, never domain deletion operations.
Expired tokens require retaining local state and re-reading retained history.
References: [Drive changes](https://developers.google.com/workspace/drive/api/reference/rest/v3/changes/list),
[appdata isolation](https://developers.google.com/workspace/drive/api/guides/appdata).

Commit `b689ce7` added schema 23 capture context, journal and visible heads.
It is not enabled by app startup or UI. Activation requires a verified recoverable
snapshot and stable account/workspace/device binding. SQLite triggers cover the
41 portable tables, including native-connection writes. Delivery ledgers and local
notification policy are excluded. This migration is still under focused review;
packaging, exact-source CI and final release gates remain required. Current
host coverage consists of the full run plus the 55-test correction pass, not a
claim that the original Full helper returned success. Physical/native UI and
background delivery have not been observed in this task.

Restore applies a quarantine before opening the replaced database; startup also
quarantines older snapshots after migration. Android reminder jobs refuse staged
or applied-but-unopened restores. No queue is cleared: the source snapshot and
Before Restore copy retain their respective original journals. A quarantined
profile cannot activate capture until explicit reconciliation exists. Internal
sync bookkeeping is excluded from the logical user-data fingerprint.

## Portable model audit

| Boundary | Capture policy |
| --- | --- |
| Tasks, categories, projects, fixed events, event detail types | Portable stable rows |
| Work sessions, availability windows/exceptions, scheduling operations/changes | Portable; transitions and domain constraints must be revalidated on remote apply |
| Task sequences/membership/dependencies, parent links, checklist | Portable relationships; key moves retain old-key tombstones |
| Recurrence series/occurrences, series edit/collision history, progressive plans/steps/assignments | Portable; completion and recurrence cannot be merged as independent unrelated fields |
| Habits/entries/rest days/history, goals/milestones/progress/task-project-habit links | Portable stable rows and history |
| Timers, time entries/history, templates, saved views, deletion tombstones, entity icons | Portable; active-timer uniqueness and relationship transitions still require safe apply validation |
| Managed resource rows and HTTP/HTTPS link rows | Portable; exact managed bytes retained in journal JSON using an explicit blob encoding |
| External file/folder references and platform-specific application links | Device-local; excluded from bootstrap and subsequent capture |
| Notification settings and three delivery ledgers | Device-local policy/receipts; excluded |
| Portable JSON preferences | Not integrated yet; no claim of preference synchronization |
| PIN/privacy, OAuth tokens, workspace credentials, OS permission/widget placement/launcher IDs/startup | Device-local; never added to journal capture or cloud metadata |

## Release status

Unpublished implementation checkpoint. Complete sync engine, pairing,
conflict UI and both background adapters are not yet implemented. No claim of
two-way sync, automatic/background sync or release readiness is made. Existing
encrypted backup envelope remains unchanged; schema 25 is unpublished. Real cross-client pairing/exchange
acceptance cannot be performed while testing is limited to mocks; historical
backup OAuth acceptance is not acceptance of a new sync protocol.

## Durable exchange checkpoint — 2026-11-01

The current draft schema 24 retains per-device sequence numbers, causal clocks,
encrypted incoming/outgoing batches and verified cloud-object receipts. Existing
schema-23 operation IDs and ancestry survive migration. Outgoing encrypted bytes
are persisted before network use and reused exactly after restart. Acknowledging
one batch never clears edits made during its upload and never sets a misleading
end-to-end success timestamp. SHA/identity mismatches retain the queue.

Original SQLite transactions have explicit mutation-group bounds, including
nested-savepoint rollback and actions larger than the 512-operation wire limit.
The Flutter adapter finishes lazy initialization before choosing the first
action's grouping boundary. Native writes use the same grouping protocol.
Encryption and large batch encoding run off the foreground isolate.

Incoming receipt authenticates account/workspace, ciphertext and full record
identity before retaining immutable history transactionally. Partial groups and
missing causal dependencies remain pending. Received-history clocks are separate
from materialized/visible observations: a local edit cannot acknowledge a remote
change merely because its ciphertext arrived. Incoming receipt is **not** remote
application, conflict resolution or successful synchronization. No UI/network
engine enables these primitives yet.

| Invocation | Source / purpose | Result | Reason |
| --- | --- | --- | --- |
| Quick `20261101-001521-1503` | Draft schema24, journal/migration, causal clocks, isolation | 26 pass; analysis/format pass | New sequence migration and cross-record causal metadata |
| Quick `20261101-002256-6434` | Outgoing batch staging | Analysis stopped on redundant import and brace lint; no tests | New exchange adapter; corrected mechanical issues |
| Quick `20261101-002408-0083` | Staging/restart/ack, migration, codec | 10 pass | Validates immutable encrypted retry bytes and preservation during upload; predates mutation groups |
| Quick `20261101-004257-6379` | Transaction groups and native boundary | Analysis stopped on brace lint; no tests | New group capture; corrected mechanical issue |
| Quick `20261101-004632-9403` | Journal, staging, schema23 migration, profile isolation, task CAS | 27 pass; analysis/format pass | Group-aware capture and migration invalidate earlier schema24 evidence |
| Quick `20261101-005749-0338` | Staging, schema23 migration, initialization interruption | 28 pass; analysis/format pass | First explicit creation/upgrade crash checks for grouped schema24 |
| `flutter test --no-pub --reporter=expanded .buildlog/native-capture-v24/fixture_test.dart` | Actual Dart schema24 recurring fixture; isolated explicit file | 1 pass | New schema/native group protocol invalidates schema23 native fixture |
| `dotnet run --project .buildlog/native-capture-v24/NativeCapture.csproj -c Release` | Actual native repository + Microsoft.Data.Sqlite; synthetic APPDATA/LOCALAPPDATA | Pass; exactly one completion/next-occurrence group, duplicate adds no operation | New C# grouping code; logs/fixture/evidence retained privately |
| `tools/dev/native-self-test.ps1 -Executable .../TodorbitWidget.exe` | New Release native executable, helper-isolated profile | Pass | Changed native transaction wrapper; no physical UI claim |
| Quick `20261101-010120-8835` | Incoming retention and additional outgoing transaction tests | Analysis stopped on a fixture const expression; no tests | New receiver; corrected fixture |
| Quick `20261101-010148-2706` | Incoming reorder/dedup/fragments/managed bytes/auth/rollback; outgoing rollback/fragments | 12 pass; analysis/format pass | New receiver and >512-operation group coverage |
| Quick `20261101-010257-9904` | Lazy first action after reopening, staging/migration/initialization | 31 pass; analysis/format pass | Review identified startup grouping gap; received-clock column was added during this run, so this receipt does not establish final DDL |
| Quick `20261101-010441-2138` | Separate received/visible clocks, real child-process deaths, schema23 migration, isolation, initialization | 33 pass, one fixture assertion failed; analysis/format pass | New clock column and crash barriers; fixture expected empty visible clock instead of legitimate local-device zero. Corrected assertion. Both real-crash and initialization checks passed against this DDL and are retained |
| Quick `20261101-010710-2968` | Corrected clock fixture, cross-device cycle closure, outgoing groups, backup/restore, capture, codec and causal graph | 51 pass; analysis/format/diff pass | Corrected the sole failed assertion; new causal-cycle validation moved ahead of readiness; added current-schema backup regressions. Unchanged successful crash/migration/isolation checks above reused |
| `dart format --output=none --set-exit-if-changed` and `flutter analyze --no-pub` over every changed/untracked Dart file | Entire current schema24 exchange checkpoint; `.buildlog/sync-v24-final-{format,analysis}.log` | Pass | Final combined lint/format review without repeating passing runtime tests |
| `python -m unittest discover -s tools -p test_dev_verify.py` | Expanded sync feature path/test catalog | 8 pass | Catalog now includes exchange and real-crash tests; `.buildlog/sync-v24-dev-helper-tests.log` |
| `python tools/dev/check-docs.py` | Current links/map/catalog | Zero errors | New exchange references; `.buildlog/sync-v24-docs-check.log` |
| Dart MCP `hot_reload` after checkpoint changes | IDE DTD `ws://127.0.0.1:63713/EwjOuzLVbjU=` | No active application | Diagnostic attempt only; no live UI acceptance claimed |

Native evidence under `.buildlog/native-capture-v24/` predates the additive
received-clock column and Dart lazy-open correction. It establishes the tested
native grouping protocol, not final-source packaged acceptance. Exact-source
platform gates remain mandatory.

SQLite leases now coordinate independent processes/Flutter engines. Ownership
expires after 30 seconds unless renewed; stale owners cannot acknowledge or stage
new work under a successor's lease. A backward wall-clock jump permits bounded
lease recovery without making timestamps conflict winners. User database writes
continue while exchange owns a lease. Restore quarantine invalidates ownership.
Connection setup sets its SQLite busy timeout **before** enabling WAL, fixing a
race reproduced by concurrent independent-engine startup.

| Invocation | Source / purpose | Result | Reason |
| --- | --- | --- | --- |
| Quick `20261101-011040-3222` | Lease adapters and exchange guards based on `6fe452f` | Analysis stopped on multiline brace lint; no tests | New job-ownership boundary; corrected mechanical issue |
| Quick `20261101-011147-0396` | Concurrent engines, expiry/heartbeat/clock jumps/fencing/quarantine; staging and incoming regressions | 19 pass; one concurrent-opening failure | SQLite WAL setup raced before busy timeout; 14 unaffected exchange checks retained |
| Quick `20261101-011321-2254` | Earlier busy-timeout setup and all lease cases | 6 pass; analysis/format/diff pass | Corrected the reproduced opening race; no blanket rerun |

## Remote-application design boundary

Global causal clocks prove retained ancestry; they cannot alone prove what the
user has seen when unrelated later changes apply around unresolved conflicts.
The materializer must preserve that distinction. Planned visibility metadata is
an exact set of applied per-device sequence intervals (compressed adjacent
ranges), separate from received causal clocks. Applying sequence 100 must not
implicitly acknowledge conflicted sequence 10. Complete mutation groups apply
atomically, while independent groups may continue. Per-record visible parent
sets must retain every safely merged head; local edits inherit all of them.
Automatic safe merges must not emit endlessly competing synthetic revisions.

Meaningful cross-record hazards (recurrence completion/rule changes, parent
deletion/descendant edits, uniqueness and relationship cycles) still require
domain review before SQL application. Do not implement the receiver by blindly
upserting rows or by treating received history as user acknowledgement. These
checks, persisted resolution and restore reconciliation remain unfinished.

## Exact visibility checkpoint — 2026-11-01

Draft source schema 25 adds exact applied/explicitly reviewed sequence intervals,
separate from received causal history, plus complete visible parent sets. Range
normalization preserves holes and is independent of delivery order. Visibility
cannot reference a future/unobserved sequence or acknowledge only a fragment of
another device's original action. Native and Flutter captures persist the same
metadata with the original transaction. Incoming groups remain unmaterialized.

The schema24 forward migration retains original operation IDs, payloads and
encrypted bytes. Pending old-schema ciphertext is marked superseded, retained
privately, and its pending operations restaged under a new encrypted batch ID
with visibility metadata. Automatic exchange is disabled during that migration;
no stored history or user rows are deleted. Schema24 never enabled remote
application, so migration establishes visibility only for original local rows.
This is an unpublished protocol transition, not compatibility evidence for a
released multi-client sync protocol.

Portable-record review now excludes `updated_at` from user-value decisions and
derives deterministic UTC metadata separately. Divergent user values still need
a decision, regardless of skewed clocks. Completion/scheduling, recurrence
rules/templates, event timing, managed bytes and other coupled record transitions
remain meaningful conflicts. Full record candidates stay in immutable history.
This review helper has not been wired to a remote SQL materializer or UI yet.

| Invocation | Source / purpose | Result | Reason |
| --- | --- | --- | --- |
| Quick `20261101-011617-6348` | Exact interval primitive, causal serialization and codec | 21 pass; analysis/format/diff pass | New visibility model, hole/order/immutability/malformed-wire checks |
| Quick `20261101-011645-7926` | Visibility cannot invent unobserved/future facts | 22 pass; analysis/format/diff pass | Added visibility-subset validation and regression |
| Quick `20261101-011858-3579` | Schema25 capture, staging/incoming, schema23 migration and isolation | 28 pass; analysis/format/diff pass | New stored intervals and merged parent sets invalidate schema24 capture evidence |
| Quick `20261101-012241-0273` | Actual schema24 encrypted-queue migration, backup/restore, real crash barriers and leases | 21 pass; analysis/format/diff pass | New forward migration and schema25 snapshot gate; old ciphertext/IDs retained exactly |
| Quick `20261101-012423-2710` | Portable record semantics review | Analysis stopped on two multiline brace lints; no tests | New domain helper; corrected mechanical issues |
| Quick `20261101-012511-4759` | Independent-field merge, skewed clocks, completion/schedule, bytes, deletion and malformed UTC | 6 pass; analysis/format/diff pass | New semantic review boundary; recurrence-specific assertion added afterward for Full pass |
| `flutter test --no-pub --reporter=expanded .buildlog/native-capture-v25/fixture_test.dart` | Actual Dart schema25 recurring fixture, isolated file | 1 pass | Changed capture DDL invalidates schema24 native fixture |
| `dotnet run --project .buildlog/native-capture-v25/NativeCapture.csproj -c Release` | Actual production native writer + Microsoft.Data.Sqlite; isolated child APPDATA/LOCALAPPDATA | Pass; completion/next occurrence grouped once with exact prior visibility | Changed native schema ceiling and capture metadata; source/executable/fixture hashes in ignored `evidence.json` |
| `tools/dev/native-self-test.ps1 -Executable .../TodorbitWidget.exe` | New native Release executable, helper-isolated profile | Pass | Schema25 native boundary; no physical UI claim |
| Quick `20261101-012656-1538` | Incoming cross-device partial-group acknowledgement | 7 pass; analysis/format/diff pass | New global retained-history validation; full-group acknowledgement accepted, partial rejected atomically |
| `verify.ps1 -Mode Full -Plan` | Preview standard host integration checks | Plan inspected only | Shared transaction wrapper/schema invalidates previous full-host coverage |

Full host integration `20261101-012822-1294` passed formatting (275 files), full
analysis, 524 host tests with one existing opt-in skip, 11 Android release-helper
tests, eight developer-helper tests and documentation/catalog validation (zero
errors). Its final diff check found one newly added blank line at EOF in the
feature catalog. That whitespace was corrected and `git diff --check` passed
separately (`.buildlog/sync-v25-diff-check.log`); no runtime suite was repeated.
The original Full helper receipt therefore has a nonzero final status despite
all runtime/static checks passing. This run was necessary because the shared
transaction wrapper and schema25 migration postdate the schema23 full pass.

Foreground/background engines and remote application remain disabled. No
publication candidate exists yet.

Retained-history readiness now processes at most 1,024 metadata nodes per
transaction, computes dependency closure off the foreground isolate and updates
known flags in bounded SQL chunks. A delayed first page cannot monopolize a
lease while unlocking an arbitrarily large queue. Follow-up jobs continue after
restart; received clocks still do not change visible data.
Quick `20261101-080051-4478` passed 14 incoming/lease checks plus analysis,
formatting and diff validation. Its new 1,025-operation reordered fixture proves
bounded continuation, restart and an intervening local user edit. This targeted
pass replaces receiver-readiness evidence only; unaffected full-host checks from
`20261101-012822-1294` are retained.

### Remote applier implementation notes

The next implementation must prepare a review outside the writer transaction,
then compare the captured local sequence and exact visible state under the writer
lock before applying. Received-history changes alone do not invalidate a visible
review. Original groups apply fully or remain retained; missing visible parents
wait, semantic conflicts persist, and independent eligible groups continue.

Use per-record causal review with all safely materialized heads and the candidate
group. Keep complete visible parent sets; do not emit synthetic merge operations
which can bounce between devices. Modification metadata may be derived for
display, but any changed task row must get a strictly new local CAS timestamp
even when a future clock makes the maximum remote timestamp unchanged. Reuse the
existing monotonic repository helper. Incoming facts remain unchanged in history.

Audit cross-record concurrent deletion/descendant edits and recurrence/progressive
rule/completion changes before SQL. Use FK references plus task-parent,
recurrence-family and entity-icon relationships. Validate dependency/parent
cycles, task project/category compatibility, recurrence namespaces and SQLite
constraints inside the trial transaction. Native recurring semantics must not be
rerun from a remote task completion. The three recurrence and four icon-cleanup
SQL triggers must be suppressed/restored inside the same atomic apply transaction
or explicitly guarded; capture is suppressed with `applying_remote`.

Managed byte history should be compared by authenticated digest/length references
and load only a selected payload when writing, avoiding retention of every old
attachment in a review's memory. Keep per-record processing bounded and renew
owned work between steps. A remote purge must not silently cascade through a
device-local external resource. An existing row without captured visible heads
must not be overwritten as a presumed empty slot. Restore quarantine and staged
restore suspension remain exchange barriers.

## Atomic remote application checkpoint — 2026-11-01

`sync_apply_repository.dart` now prepares causal reviews outside the writer lock,
then revalidates both portable sequence/visibility and actual affected rows under
the lock. Safely merged original groups apply atomically; conflicts/constraint
failures retain immutable history and persist a structured review barrier.
Independent eligible groups continue, leaving exact visibility holes. SQLite
constraints, dependency cycles, one-level task hierarchy and task assignment
checks run before commit. Recurrence completion writes the original stable rows;
it does not run completion/generation logic again.

All seven audited recurrence/icon triggers are suppressed and restored in the
same apply transaction. `applying_remote` prevents journal echoes. Modified task
rows, including dependency-only revisions, receive a strictly new local CAS token
using the existing monotonic helper. Actual cloud revisions remain unchanged in
history. Managed bytes are reviewed by digest/length and only the selected payload
is loaded/rehashed when writing. Cross-record deletion/recurrence barriers retain
concurrent edits. Device-local file references are checked again under the writer
lock: excluded local mutations intentionally do not advance portable clocks.

These are controlled repository fixtures, not an enabled app sync feature or UI
acceptance. The applier is not connected to startup/network/background adapters.
Persistent review decisions, model-wide acceptance and the remaining release
requirements are still pending.

| Invocation | Source / purpose | Result | Reason |
| --- | --- | --- | --- |
| `flutter analyze --no-pub` on the new applier, repository and models; `.buildlog/sync-apply-initial-analysis.log` | Initial applier implementation based on `d75ef17` | Stopped on 19 brace lints; no tests | New code; mechanically corrected with scoped `dart fix --apply --code curly_braces_in_flow_control_structures lib/data/sync_apply_repository.dart` (19 fixes, private log) |
| Quick `20261101-082021-9281` | Bootstrap/idempotence, two-way merge without echo, stale editor CAS, visibility holes, managed bytes, recurrence, related deletion and rollback | 7 pass; analysis/format/diff pass | First actual remote SQL application evidence |
| Quick `20261101-082714-1250` | Added dependency cycles, dependency-only CAS, rule/completion, external refs and identity collisions | 10 pass; two path assertion failures; analysis/format pass | Source barriers behaved correctly; fixtures compared normalized stored Windows paths with mixed-separator constructor strings. Corrected fixtures |
| Quick `20261101-083010-1291` | Writer-lock revalidation and deterministic review/lock race fixtures | Analysis stopped on one brace lint; no tests | New excluded-reference race guard; corrected mechanical lint |
| Quick `20261101-083143-4558` | All corrected applier cases plus portable/excluded mutation races | 14 pass; analysis/format/diff pass | New writer-lock guards invalidate first applier evidence; preserves real external files/references |
| Quick `20261101-083545-9481` | Real process death after row insertion and after group materialization, incoming history and lease regressions | 16 pass; analysis/format/diff pass | New apply lifecycle boundary: both killed transactions restore rows, flags and all seven triggers; resume applies once with original ciphertext/history retained |

Before enabling the engine, active timer ownership/heartbeat behavior still needs
integration review: importing a running timer must not make a second controller
checkpoint it or duplicate actual work. Pairing must also prove that both auth
adapters use the same canonical Google account identity for authenticated context;
historical passphrase backup interoperability alone does not establish that fact.

The updated sync feature catalog passed eight helper tests
(`.buildlog/sync-apply-dev-helper-tests.log`) and documentation/catalog validation
reported zero errors (`.buildlog/sync-apply-docs-check.log`). Dart MCP hot reload
was attempted after this checkpoint; the IDE DTD still had no active application.
No live UI claim is made.

## Resumed exchange and resolution checkpoint - 2026-11-01

The owner resumed the remaining sync work after the separate button-only beta 3
publication. Mocked Drive only remains authorized. The earlier no-test exception
was scoped to that UI-only release; data-safety checks resume for the engine.
No full-sync release is published and the new engine is not wired into app startup.

Persistent conflict review now snapshots complete pending groups, local sequence,
exact visibility, retained history and actual affected records. Decisions recheck
under the writer lock, apply atomically and append a durable resolution group
parenting every reviewed head, including unchanged-local choices. Independent
fields survive a conflict choice. Covered original ancestor groups can be safely
superseded by a complete resolution without replaying a conflicting predecessor.
Structural barriers require explicit choices for every reviewed coupled record;
SQL/domain constraints and device-local resource protection remain authoritative.

A shared bounded engine stages immutable encrypted uploads before HTTP, retains
incoming pages before advancing cursors, takes the initial cursor before listing,
rescans on expired cursors, continues past conflict barriers and renews SQLite
ownership during network waits. Backoff/contact/error state is durable; lock,
account and restore barriers stop exchange. Repeat clicks share one in-flight job.
Secure pairing has account-bound AES-GCM workspace proofs, a deterministic account
workspace identity, independent device identities and OS-secure recovery-key
storage. The sole generated key is persisted before any ambiguous proof upload.
Competing first-device keys stop pairing and preserve both keys/history.

| Invocation | Result | Reason / evidence |
| --- | --- | --- |
| Scoped resolution analysis; `.buildlog/sync-resolution-analysis.log` | Two brace lints, no tests | New resolver and previously unverified covered-ancestor changes |
| Scoped `dart fix` diagnostic; `.buildlog/sync-resolution-lint-fix.log` | Rejected multiple positional paths; no source change | Corrected both braces directly instead |
| Quick `20261101-181458-7721` | Analysis/format pass; 15 pass, two fixture expectations fail | A predecessor conflict is encountered before its later resolution; fixtures incorrectly expected a one-step drain |
| Quick `20261101-181644-6463` | 17 pass; analysis/format/diff pass | Fixtures now drain past the predecessor; proves both resolutions converge without echo |
| Scoped engine analysis / brace fixes; `.buildlog/sync-engine-analysis.log`, `sync-engine-lint-fix.log`, `sync-status-lint-fix.log` | Five mechanical brace lints corrected | New engine and durable status repository |
| Quick `20261101-182020-4063` | Analysis stopped on two missing override annotations; no tests | New change-feed transport interface; annotations corrected |
| Pairing brace fixes; `.buildlog/sync-pairing-lint-fix.log` | Nine mechanical fixes | New pairing service |
| Quick `20261101-182342-7647` | 25 pass; analysis/format/diff pass | New mocked two-profile engine, ambiguous ciphertext retry, cursor failure/expiry, lock/account barriers, pairing/recovery/competing-key tests plus resolver regression after preserving compatible bulk selections |

Next: integrate timer ownership, portable preferences, restore reconciliation,
workspace-proof checks in exchange, foreground UI/runtime and supported platform
scheduling. Real-account acceptance remains unobserved and unauthorized for now.

## Integrated sync checkpoint — 2026-11-01

Working tree after `e0be3d3`. Schema 26 adds portable preference records, timer
ownership and immutable restore intent. Foreground Windows/Android controls now
use the shared engine. Background entry points use the same leases/protocol;
Android schedules constrained jobs, and the Windows companion starts a hidden
bounded worker. Protected profiles require an unlocked foreground session.

Restoration retains authenticated pre-restore operations and original staged
ciphertext, then uses a fresh device identity and a causal restore group. An
older restored value cannot silently erase a newer competing edit; cloud-only
records are not deleted. Automatic sync remains off after reconciliation.
Structural conflict review previews actual SQL consequences inside a rolled-back
savepoint, includes affected related records, and rejects choices that would
silently hide or cascade away a record the user chose to retain. A running timer
has one owner; explicit adoption pauses at its last known checkpoint, never now.

The earlier statements that the engine is inactive describe historical commits.
Current runtime integration is implemented, with release verification pending.
Mocked Drive remains the only authorized cloud acceptance environment.

| Invocation / evidence | Result | New or rerun reason |
| --- | --- | --- |
| `sync-ownership-analysis.log`, `sync-ownership-verify.log` | Initial analysis passed; new repository code then stopped on two brace lints | Ownership/preferences implementation; scoped mechanical correction |
| `sync-preferences-analysis.log`, `sync-device-preferences-verify.log` | Five controller brace lints; no tests | Added preference integration; corrected with scoped `sync-preferences-lint-fix.log` |
| Quick `20261101-183312-7981` | 44 pass, 13 old table-count assertions fail | Added portable table; expected count updated from 51 to 52, no domain data changed |
| Quick `20261101-183704-1040` | 22 pass; format/analysis/diff pass | Corrected table count; initialization/migration/process-death checks |
| `sync-ui-analysis.log`, `sync-ui-wiring-analysis.log` | Missing required desktop argument and brace lints corrected; ten-path analysis passed | New foreground integration |
| Quick `20261101-184447-1508`, `sync-ui-verify-followup.log` | Formatting then lint gates stopped before tests | New conflict dialog/fixtures; corrected formatting, braces and super parameter |
| Quick `20261101-184857-8235` | 20 pass, two narrow UI fixture tap failures | Fixture scrolled without pumping a frame before hit testing; no overflow observed |
| Quick `20261101-185259-9349` | Three UI tests pass | Corrected fixture frame: light/dark narrow large-text decisions and lock closure |
| `sync-background-analysis.log`, `sync-background-braces.log`, `sync-budget-braces.log` | Six brace lints corrected | New headless entry points and cycle budget |
| `sync-restore-integration-analysis.log`, `sync-restore-braces.log` | Read-only database constructor API corrected and braces fixed | Used installed Drift API source to select `NativeDatabase.opened` with SQLite read-only mode |
| Quick `20261101-190904-2954`, `20261101-190927-8282` | Format then invalid constant property access stopped before tests | Newly added restore integration fixture; corrected format and fixture constants |
| Quick `20261101-191115-9501` | 12 pass, restore conflict expectation failed | Revealed older restore matching common-base value could be merged away; introduced authenticated immutable restore intent |
| Quick `20261101-191416-4910` | 13 pass; format/analysis/diff pass | Intent fix: staged restore/reopen/quarantine, original ciphertext retry, fresh device sequence, older/newer conflict and cloud-only record retention |
| `sync-related-consequence-analysis.log`, `sync-consequence-braces.log`, `sync-consequences-verify.log`, `sync-adoption-braces.log`, `sync-relationship-braces.log` | Seven consequence and four adoption brace lints corrected; tests blocked until corrected | New structural preview, relationship guards and explicit timer adoption |
| Quick `20261101-193019-7016` | 29 pass; format/analysis/diff pass | Actual SQL cascade/soft-delete consequences, mixed decisions rollback, ownership adoption, restore and causal merge regressions |
| `sync-native-dotnet.log` | Release build passed, zero warnings/errors | New companion scheduler/schema compatibility |
| `sync-native-self-test.log` | Passed with verified disposable APPDATA/LOCALAPPDATA | Native Release self-test; no physical shell/input claim |
| `sync-native-kotlin.log` | Canceled before source compilation | PowerShell split unquoted dotted Gradle property; corrected argument quoting |
| `sync-gradle-threads.log` | Diagnostic captured own Gradle daemon | Slow native build investigation; no test/retry or source change |

Private logs referenced above are under ignored `.buildlog/`; helper receipts
retain exact commands/source/dirty state. New foreground behavior, platform
compilation, full host integration and exact-source release gates remain pending.

## Runtime integration follow-up — 2026-11-01

- Quick `20261101-225404-4603`: 31 tests passed, targeted analysis/format/diff
  passed. New cases prove background-budget yield retains the queue without
  failure backoff, workspace-proof rejection prevents uploads, and Resolve Later
  survives another apply attempt plus an unrelated edit. Includes narrow
  light/dark large-text conflict UI. Later projection/route cleanup changes are
  covered by the broader integration invocation below, not this earlier pass.
- `sync-native-kotlin-corrected.log`: `:app:compileGithubReleaseKotlin` passed
  (55 tasks, 9m34s), using JDK 21 and the complete cached SDK. Existing Kotlin/AGP
  deprecation warnings remain. This is compilation evidence, not a release APK
  or real-account background acceptance. The draft AOT generated as a dependency
  is not a publication candidate.
- Full `20261101-225848-7809`: formatting passed (298 files); canceled during
  analysis before tests after review identified missing headless preference JSON
  projection and loss of device-local customization metadata. Corrected before
  proceeding; no pass claimed. `sync-gradle-kotlin-threads.log` is a diagnostic
  snapshot of the active build, not a test rerun.
- Full `20261101-230131-9035`: formatting passed; analysis stopped on one new timer
  brace lint and an invalid CalendarContent name in a new fixture; no tests.
  Both corrected in `sync-full-lint-format.log`. The fixture now exercises SQL
  preferences projected without controller initialization while preserving local
  author/sidebar/opening-page/widget-opacity settings and clearing a null calendar
  mode. These device fields are explicitly excluded from the portable theme.
- Dart MCP hot reload attempted: DTD had no active app connection. Widget tests
  are rendered automation evidence only. No personal profile was opened.
- Source versions selected for the next candidate: `1.0.19-beta.4+27`, greater
  than public beta 3/code 26 (read-only `gh release list` checked). Unpublished;
  existing tags/assets are unchanged. Full integration remains pending in
  `sync-full-integration-corrected.log`.

- Full `20261101-230258-9769`: format and full analysis passed; stopped during
  serial tests after two appearance tests exposed a Map<dynamic,dynamic> passed
  to the strictly typed theme decoder. The stopped run is incomplete, not a
  full-suite pass. Fixed the map type directly before continuing.
- Quick `20261101-230441-0301`: eight appearance/settings/conflict UI tests passed;
  targeted analysis, formatting and diff checks passed. This validates the
  corrected headless JSON projection and device-local customization preservation.
- The top-right button now routes quarantined/reconnect profiles to setup and
  shows actionable safe engine notices. Final broad integration runs after this
  last UI change in `sync-full-final.log`.

- `sync-privacy-website-check.log`: dependency-free website checks passed for
  three pages after adding the optional-sync privacy disclosure. Rendered browser
  layout was not repeated for this text-only change.
- `sync-native-theme-build.log`: native Release build passed with zero warnings
  after adding transactional portable theme capture from both companion commands
  and its tray control. Native JSON remains a projection after SQL commits.
- Quick `20261101-231107-7211`: formatting and targeted analysis passed; Flutter
  could not start tests because the concurrently running full suite held
  `build/native_assets/windows/sqlite3.dll`. No test results are claimed. Run
  Windows Flutter test processes sequentially; rerun this gate after full-suite
  completion. No permissions or dependency changes are needed.
- Full `20261101-230534-1558` currently continues with one historical assertion
  failure: settings-only import now intentionally updates `portable_preferences`.
  The corrected fixture compares every other SQLite table and explicitly checks
  the selected imported preference. Current planner data remains protected.
- Added an explicit Release-only fixture outside the default host suite:
  `test_driver/native_sync_writer_test.dart`. Windows CI runs it after building
  the companion, with isolated child APPDATA/LOCALAPPDATA. It checks capture,
  group completion, idempotence and failed-write preservation of JSON/history.
  `tools/test-background-sync.py` checks the exact Windows runner for hidden,
  unchanged missing/migration/protected/pending-restore profiles. Both gates
  remain pending; neither uses real Drive authorization.

## Broad integration repairs and source freeze preparation

- Full `20261101-230534-1558`: 560 pass, one existing opt-in skip, five failures.
  Full analysis/format passed. The five failures were one obsolete all-SQL-tables
  settings assertion, two plain-Dart crash workers importing Flutter through
  preference validation, and two prototype migration fixtures assuming capture
  resumes automatically. This run changed during targeted repairs and does not
  establish the final exact-source full-suite gate; final CI remains mandatory.
- Theme JSON validation now lives in pure Dart `theme_json.dart`, shared by the
  UI adapter and portable preference validation. Repository workers no longer
  import Flutter rendering types. Native author/sidebar/opening/opacity metadata
  stays local. Session sharing also makes Backups disconnect fence Sync, without
  deleting workspace keys or queued data. Explicit reconnect can repair a damaged
  saved session without repeatedly loading that same damaged session first.
- `sync-auth-data-boundary-format.log` stopped on an extra parenthesis in a new
  widget fixture; corrected in `sync-shared-auth-fixture-format.log`.
  `sync-auth-pure-data-analysis.log` then passed on eight affected paths.
- Quick `20261101-232836-8831`: 21 pass, one new shared-auth widget fixture timeout;
  analysis/format passed. Actual native theme capture/group completion/idempotence
  and write-failure preservation passed against the rebuilt native executable.
  Both real process-death rollback gates, schema 23/24 retained-history quarantine,
  settings-only planner preservation, theme decoding and reconnect checks passed.
- Quick `20261101-233122-5291`: seven backup UI checks passed; analysis/format/diff
  passed. The new fixture now allows the existing asynchronous file-I/O setup to
  finish before settling its progress indicator. No production timeout change.
- `sync-final-release-validator-tests.log`: 11 Python release-validator tests pass.
- `sync-final-dev-helper-tests.log` and `sync-final-docs-check.log`: helper/link
  gates found two wildcard paths in the architecture map; replaced with concrete
  existing paths. `sync-final-dev-helper-corrected.log`: eight pass;
  `sync-final-docs-corrected.log`: zero errors. `sync-final-diff-check.log` passed.
- `sync-native-theme-final-build.log`: native Release build passed, zero warnings,
  after rechecking schema changes during companion scheduling. Actual packaged
  self-test and hidden-worker artifact gates remain pending.
- Windows Sandbox acceptance harness now reads the candidate schema from its
  manifest (26/52 tables) and checks a synthetic populated in-place setup before
  uninstall/reinstall preservation. It still refuses execution outside a fresh
  Sandbox account. This gate remains pending final package creation.
- Final background privacy review added an asynchronous policy fence: a headless
  job re-reads persisted privacy/restore state at exchange boundaries and before
  publishing Android surfaces, so a PIN enabled by another process stops the
  already-running worker. Focused validation is in `sync-background-policy-check.log`.

## Frozen implementation candidate — 2026-11-01

- Quick `20261101-233359-1322`: eight engine/controller tests passed;
  analysis/format/diff passed. Includes a persisted background-policy change
  fencing incoming content before download/application, bounded job yield,
  immutable retry, workspace proof checks and explicit damaged-session reconnect.
- Headless application now projects portable preferences without refreshing a
  foreground controller, so a sync-only process never starts a timer heartbeat.
- `sync-candidate-full-analysis.log`: final full analysis of lib/test/integration
  and test-driver roots passed. `sync-headless-projection-format.log` records the
  last two formatted paths. `sync-platform-harness-syntax.log` and PowerShell
  parser checks passed for the new hidden-worker/Sandbox harness changes;
  `sync-candidate-diff-check.log` passed.
- Dart MCP hot reload was attempted again after implementation: no active app
  connection on the IDE DTD. No live debug UI acceptance is claimed.
- Earlier broad unaffected passes and corrected focused evidence are retained;
  do not repeat the local full suite just for a fresh receipt. Exact-source CI
  must run the full final suite before publication. Final packages, Sandbox,
  hidden-worker artifact check and Android 16 KiB artifact runtime remain pending.

## Final artifact checkpoint (candidate application source `0813913`)

- `sync-final-windows-build.log`: Windows Release build passed (186.7 seconds),
  using the previously approved public Drive configuration digest. Installer,
  portable ZIP and checksum generation passed in the matching
  `sync-final-windows-{installer,portable,checksums}.log` logs. The tracked default
  configuration was restored; it was not committed with publisher parameters.
- `sync-final-hidden-worker.log`: harness cleanup failed because Python's SQLite
  connection context manager commits but does not close the connection. No app
  behavior failure was established. Added explicit close in the harness only.
- `sync-final-hidden-worker-corrected.log`: the exact Windows Release runner
  passed all four disposable missing/migration/protected/restore barriers;
  original profile files remained unchanged, no visible window was observed.
  Executable SHA-256 is retained in that receipt. `sync-final-packaged-native-test.log`
  passed using isolated child APPDATA/LOCALAPPDATA.
- Windows exact-source CI run `41347862678` was superseded before completion by
  the corrected harness checkpoint. Application code and packaged bits do not
  change for this one-line harness fix; reuse the valid local build evidence.
  Replacement Windows CI remains mandatory. Android run `41347898852` validates
  unchanged Android application source; website run `41347862688` passed.
- Signed split APK construction is in progress in `sync-final-android-apks.log`.
  No release/tag/assets have been published for beta 4.

## Clean Windows deployment correction — 2026-11-02

- Windows CI `41348561761` passed on `0f8e61f`: 568 host tests passed, one existing
  opt-in skip; full analysis, native writer, hidden-worker, packaged self-test,
  OAuth/config and installer/package gates passed. Android CI `41347898852` passed
  on identical Android application source. Both complete logs remain private.
- Signed APKs from unchanged runtime source `0813913` passed alignment:
  universal 52,463,895 bytes; ARM64 25,927,259; x64 27,510,775. Private Play AAB
  is 48,924,126 bytes. `sync-final-android-candidate-validation.log` passed all
  production signer/package/version/code/ABI and Play separation/configuration
  gates. Five native signing-policy JVM tests passed, zero failures/errors/skips,
  recorded in XML plus `sync-final-android-native-receipt.json`. A PowerShell
  stderr warning interrupted orchestration after successful Gradle execution;
  native tests were not repeated, and the not-yet-started AAB build ran separately.
- `sync-final-portable-equality.log`: all 24 application bundle files matched
  the initial ZIP byte-for-byte; CRC/private-file checks passed. CRT repackaging
  invalidates that package hash, so compare the replacement ZIP again.
- Clean Sandbox install initially passed hash/registration checks, then failed
  app schema readiness twice. `sync-final-sandbox-diagnostic-launch.json` records
  the unchanged-package diagnostic run. Standard error was empty: Windows could
  not start the native loader. No planner data was opened on the owner's account.
- Controlled fresh-guest probe `sync-crt-probe-launch.json` injected only three
  valid Microsoft-signed x64 Visual C++ runtime DLLs. It passed all schema-26/
  52-table cold create/reopen, packaged native self-test, populated in-place setup
  byte preservation, uninstall retention and reinstall checks. This is diagnostic
  evidence, explicitly not acceptance of the original packages. Shader/renderer
  warnings occurred in the virtual guest; no physical GUI claim is made.
- Root cause: application-local `msvcp140.dll`, `vcruntime140.dll` and
  `vcruntime140_1.dll` were missing. Flutter's Windows deployment guidance lists
  these files; Microsoft's Visual Studio redistribution list permits unmodified
  redist distribution under its terms. Added signed desktop-x64 redistributable
  staging/receipt and installer/portable gates, plus distribution notices.
- `sync-crt-staging.log` passed; `sync-crt-negative-gates.log` accepts the authentic
  set and rejects absent receipts/DLLs, altered bytes and hash mismatches. Exact
  runtime executable/AOT/native hashes are bound in
  `sync-pre-crt-runtime-binaries.json`; app recompilation is unnecessary.
- Repackaging is in `sync-crt-windows-{installer,portable,checksums}.log`. Final
  unchanged-package Sandbox acceptance, replacement ZIP equality and exact-source
  packaging CI are still required. Public beta 4 remains unpublished.

## Final package acceptance — 2026-11-02

Release candidate source is `67b265d2c546aa5ea5fad6b5214dad1a715869d9`.
Application/runtime source remains identical to `0813913`; the later commits
change acceptance harnesses, packaging scripts/CRT redistribution and evidence.

- CRT-inclusive installer built successfully. Initial portable invocation refused
  to overwrite its prior output (`sync-crt-windows-portable.log`); corrected by
  using a fresh private output directory, preserving the older ZIP.
  `sync-crt-windows-portable-corrected.log` passed. Exact executable/AOT hashes
  remained unchanged and tracked build configuration was restored.
- `sync-crt-portable-equality.log`: all 28 Release bundle files matched final ZIP
  bytes; ZIP CRC passed; three signed runtime DLLs, receipt and notice present.
- `sync-crt-final-sandbox-launch.json` and its mapped `results/acceptance.json`:
  PASS against the unchanged final setup/ZIP. Fresh per-user installation,
  installer registration/path, installed and path-with-spaces portable cold
  schema-26/52-table create/reopen/integrity, native self-test, populated in-place
  setup byte preservation, uninstall data retention and reinstall all passed.
  The private runner only adds failure diagnostics and guest shutdown afterward;
  no dependency injection or test weakening. The guest was stopped afterward.
- Computer-use inspection was attempted when waiting for that guest. Both the
  skill's node runtime and the alternate CUA entry point reported missing kernel
  assets; no desktop UI was automated. The file-based guest completed normally.
- `sync-android-upgrade/receipt.json`: disposable `TodorbitProductionFast`, serial
  `emulator-5584`, accepted production beta 1/code 23 to beta 4/code 27 with
  `adb install -r`, retaining the first-install timestamp. Explicit schema 22->26
  backup/migration prompt observed; existing synthetic task and project survived
  a cold reopen. The attempted additional draft sentinel was not saved, so it is
  explicitly not claimed as migration evidence. Retained original synthetic
  records provide the observed preservation evidence. Network radios were off;
  no real Drive exchange/pairing was attempted. An existing locally saved account
  label was displayed by setup, without contacting Drive. The emulator is stopped
  with its disposable data retained. Actual system-installer approval is unobserved.
- Top-right Sync opens the real production Android setup page. Private screenshot
  and accessibility evidence are under `sync-android-upgrade/`; this is emulator
  Release rendering, separate from physical phone/OEM acceptance.
- Android 16 KiB artifact workflow `41353852427`: PASS for the exact x64 APK
  SHA-256 `8d2a5fb6c9c257f31a140ad44077ee68e23d7a1634a4654264bc64c155417d43`.
  Official API-36 16 KiB guest: stable no-app baseline, rendered app, create/reopen/
  complete synthetic task, no crash or ANR observed. Receipt downloaded under
  `sync-final-16k-evidence/Android-16KiB-runtime-evidence/`.
- Draft beta 4 created as release ID `430876643`, target `67b265d`, prerelease.
  Parallel upload initially left four starter objects. After stopping only its
  owned uploader, retrying missing draft objects sequentially over HTTP/1 completed.
  A duplicate x64 retry was correctly refused because that asset had completed;
  it was reused unchanged. `sync-beta4-draft-integrity.json`: all 11 completed
  assets match local exact lengths and GitHub SHA-256 metadata; private AAB absent.
  Initial JSON audit selected UTF-8 for a PowerShell UTF-16 redirection and failed
  decoding; detecting the BOM corrected the diagnostic without changing assets.
- `sync-final-portable-update.log` found an old harness expecting numeric-core
  version 1.0.19 instead of beta.4. Corrected only harness prerelease parsing.
  `sync-final-portable-update-corrected.log`: actual package swap, automatic restart,
  SQLite integrity, synthetic task and widget/settings/profile retention passed.
  Its cleanup raced a terminating process and reported a locked DLL. Cleanup now
  waits for its owned processes. Valid swap evidence is reused, not repeated.
  `sync-final-portable-rollback.log`: deliberate version mismatch rolled back,
  automatically restarted and retained isolated data/settings; cleanup passed.
- Exact-source Windows CI for the CRT packaging correction is `41353292679`.
  It remains pending before publication. Prior 568-pass host evidence is retained;
  Android/16 KiB artifact and Windows package evidence remain valid because no
  runtime code changed. Beta 4 is still a draft; no public release gate is waived.

## Public release verified — 2026-11-02

- Exact candidate Windows CI `41353292679` passed: 568 host tests, one existing
  opt-in skip, full analysis, helper/config gates, native Release/self-test,
  C++ runtime positive/negative gates, native SQL writer, hidden background
  barriers, installer/portable/checksums. Complete log is
  `sync-final-exact-source-ci.log`. No mandatory gate was waived.
- Published release `430876643`, tag `v1.0.19-beta.4`, source `67b265d`, version
  `1.0.19-beta.4+27`, at 2026-11-02 01:03:03 Asia/Amman. Pre-release, Latest false.
  `sync-beta4-published.json` and `sync-beta4-public-tag.json` bind source/tag.
- `sync-beta4-anonymous-verification.log` and `sync-beta4-anonymous-integrity.json`:
  anonymous public metadata, all 11 exact lengths/digests, and hashed small-asset
  downloads pass. Five final binary HTTP Range delivery probes passed in
  `sync-beta4-public-download-probes.log` / JSON. Complete digests are verified
  through GitHub metadata; large APK/ZIP files were not downloaded redundantly.
- `sync-beta4-public-updater-test.log`: one production-selector check passes on
  anonymous metadata, covering Windows Setup/portable choice, Android ARM64/x64
  priority and hashes, increasing code 27, and Stable exclusion. No data profile,
  real Drive account or installer is opened by this metadata test.
- Portable swap evidence was reused after its cleanup-only fix. The required
  deliberate-failure rollback then passed in `sync-final-portable-rollback.log`.
  The harness fix preserves prerelease version names and waits for terminating
  owned processes before deleting its verified temporary root. It is test-only;
  packaged `update-helper.ps1` is unchanged and its actual version gate passed.
- `sync-publication-docs-check.log`: zero link/map/catalog errors;
  pre-publication diff check passed. Final publication documentation is being
  finalized after the observed public checks; binary rebuilds/CI reruns are
  unnecessary for this evidence/test-harness-only follow-up.
- [Public receipt, all artifact hashes and explicit acceptance limits](DRIVE_SYNC_BETA_4_PUBLICATION.md).

Final documentation checks `sync-final-publication-docs.log` and
`sync-publication-final-docs.log` report zero errors; final diff checks passed.
These text-only invocations validate the completed receipt and updated download
links, not new runtime behavior. The final follow-up also retains the already
validated portable test-harness prerelease/cleanup corrections. It does not
change published application or package source, so no binary rebuild or new
full-suite run is warranted. Published tag remains exactly `67b265d`.
