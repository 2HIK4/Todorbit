# Drive sync and restore work — 2026-10-31

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
for a real account or saved to a user profile. No SQLite schema was changed.

## Release status

Unpublished implementation checkpoint. Sync engine, pairing, all-writer capture,
conflict UI and both background adapters are not yet implemented. No claim of
two-way sync, automatic/background sync or release readiness is made. Existing
backup format and schema remain unchanged. Real cross-client pairing/exchange
acceptance cannot be performed while testing is limited to mocks; historical
backup OAuth acceptance is not acceptance of a new sync protocol.
