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

All new checks use disposable data. No full suite or release build has run.
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

Working-tree schema 23 adds inactive capture context, journal and visible heads.
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
encrypted backup envelope remains unchanged; schema 23 is unpublished. Real cross-client pairing/exchange
acceptance cannot be performed while testing is limited to mocks; historical
backup OAuth acceptance is not acceptance of a new sync protocol.
