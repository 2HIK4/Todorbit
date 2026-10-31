# Drive sync and restore work — 2026-10-31 to 2026-11-01

Branch: `feature/drive-sync-recovery`, baseline `f62cd7b`.
The owner authorizes coordinated publication after all mandatory gates pass;
real Drive testing is currently restricted to mocked transport by owner choice.
No new release, version, tag, cloud object or personal profile has been changed.

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
encrypted backup envelope remains unchanged; schema 24 is unpublished. Real cross-client pairing/exchange
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
