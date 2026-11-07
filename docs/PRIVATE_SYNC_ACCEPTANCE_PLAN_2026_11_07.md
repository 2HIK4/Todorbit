# Private encrypted Sync acceptance preparation (2026-11-07)

Latest: [Local readiness and sign-in checkpoint](PRIVATE_SYNC_ACCEPTANCE_2026_11_07.md).
The preparation below is historical; its broad matrix is narrowed by the latest receipt.

Initial status: PREPARATION ONLY. Base `87e976f`, `feature/sync-ux-refinement`.
No real Google request, account/workspace change, application/emulator launch,
build or test execution. No Private acceptance result is claimed.

## Reusable assets and evidence

- [Final Standard receipt](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03):
  corrected Windows portable and Android registered debug APK, version
  1.0.19-beta.12+35/schema 27. Exact paths/hashes remain authoritative there.
- External root: `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106`.
  Evidence under `evidence/cross-platform-standard`, including receipts 362/364,
  fixtures `windows_fixture_test.dart`, `windows_updates_test.dart`,
  `windows_recovery_fixtures_test.dart`, causal/43-table/attachment verifiers,
  metadata-only startup fence and production baseline checks. Reuse methods,
  not hard-coded Standard account/workspace IDs, credentials or approval files.
- Retained Play API35 AVD at
  `C:\Users\User\AppData\Local\TodorbitPrivateTesting\AndroidSSD-Recovery-20261107\AVD\TodorbitStandardLowRam20261106.avd`;
  verified emulator 37.2.13 and existing SDK. Directory presence checked only;
  current guest/process health was not probed. Never run copied device identities
  simultaneously. Do not wipe or repurpose the authenticated Standard profile.
- Existing Desktop OAuth configuration and registered Android debug signing
  identity are mode-independent; no client/consent changes or secret reads needed.
  New account still requires manual selection/consent. Branding status is unchanged;
  actual authorization eligibility is checked when authorized, not assumed.
- Standard causal merge, relationships, tombstones, SQLite integrity, scheduling,
  normal UI and native credential-isolation evidence remains useful within its
  source boundary. Private deterministic codec/pairing/passphrase/wrong-key cases
  are documented in [optional encryption evidence](SYNC_OPTIONAL_ENCRYPTION.md).
  None establishes actual Private cloud interoperability. Consult source hashes
  before reusing each assertion; this preparation reruns none.

## Minimum isolated setup and blockers

1. Obtain authorization for a second disposable Google account, fresh Private
   workspace and separate profiles. Existing Standard account/workspace
   `315ab404-bbd0-55d3-b0d1-10afafe13fbc` must remain untouched. No conversion,
   Start New Sync, cleanup, key rotation or account switch in existing profiles.
2. Use the same Windows bundle with a NEW persistent private-test root, fresh
   Roaming/Local/Temp and independently encrypted credential store. Reuse validated
   launcher/path/ACL checks; copy no Standard database, vault or approval. Verify
   production baseline before/after. Keep startup exchange blocked through
   auth-only connection and read-only empty-namespace preflight.
3. Windows harness limitation: `PrivateTestEnvironment.syncApproved` reads only
   `STANDARD-SYNC-APPROVED.json` with `mode == standard`, and matches account rather
   than actual encryption/workspace. This is a test-gate contract, not proof of
   Private authorization. Do not label Private approval as Standard or reuse the
   old record. A narrowly reviewed Private/account/workspace approval extension
   and focused guard tests are the first implementation dependency; evaluate
   required Windows rebuild only then. No such change/build is made here.
4. Android needs a fresh app-data AND secure-storage/account boundary. On next
   authorized runtime inspection, first check whether this retained Play image
   supports a secondary Android user with Google sign-in and the registered APK.
   If unsupported, propose one separate AVD from the same installed image/software,
   with fresh userdata, retaining Standard offline. Do not assume an app-only
   directory override exists. No profile creation or checkpoint copying now.
5. User chooses a test passphrase and saves the generated recovery code outside
   Git/logs/chat. No secrets in command arguments, screenshots or receipts.
   Passphrase recovery and random-code recovery must both be exercised. Cloud
   metadata/IDs/sizes remain observable; ciphertext is not a metadata-hiding claim.

## Resumable execution checkpoints (all pending authorization)

| Gate | Smallest action / durable completion evidence |
| --- | --- |
| P0 Local readiness | Resolve approval guard; authorize/create isolated profiles; reuse exact artifacts unless code change invalidates them. Record source/artifact hashes, ACL/runtime paths, unique device IDs and production baseline. No Google call. |
| P1 Account only | User selects second disposable account on Windows, then Android sequentially. Verify matching stable account IDs distinct from Standard; auth-only startup fence; read-only full namespace preflight. Stop for unexpected existing data. No workspace creation/exchange approval yet. |
| P2 Private creation | After explicit cloud authorization, create fresh Private workspace through supported encryption flow; save code; record account/workspace/protocol/mode and proof fingerprint. Upload synthetic sentinel and small managed file. Verify encrypted payload/proof and intended metadata; inspect decoded envelopes/raw attachment content for fixture plaintext leakage, without logging keys. |
| P3 Independent recovery | Join Android using passphrase; separate fresh recovery context uses code without copied unlocked key. Wrong passphrase/code/account/workspace and controlled local tamper copies must fail without saving keys, uploading or losing pending data. Never corrupt retained cloud objects. Verify restart/key retention and no plaintext credential persistence. |
| P4 Real encrypted convergence | Small rich fixtures both ways: tasks/events/status/dates, recurrence/exception, parents/checklists, category/project/event relation, managed bytes. Compare IDs, causal history, all portable tables, attachment hashes, integrity/FKs. Exercise delete/edit conflict with explicit resolution, retained tombstones, repeated checks/no duplicates and interrupted/retried encrypted outbox bytes. |
| P5 Restore/recovery | Local synthetic backup/Before Restore/quarantine, loss of unlocked key in a separate recovery profile, passphrase/code re-unlock, explicit reconciliation and convergence. Test local snapshot credential exclusions. Cloud snapshot backups use a separate format and are NOT implied authorized or encrypted by Private Sync; request separate scope before testing them. |
| P6 Close | Recheck production/Standard preservation and originals, retain all evidence/data, record PASS/FAIL/BLOCKED per scenario. No cloud cleanup or publication. |

Each gate receipt lives in a NEW external Private acceptance evidence directory.
Record timestamp/offset, commit plus changed hashes, artifact/profile/device IDs,
account/workspace receipt references (not secrets), actions/API counts, failures,
last completed gate and exact next action. On resume read that receipt, inspect
status and identities, then continue; do not repeat completed exchanges or sign-in.
Run platforms sequentially and close only task-owned app processes when needed;
preserve emulator userdata/authentication. Stop for any identity/isolation failure.

## Preparation verification and next action

Read-only Git/receipt/source inspection confirms HEAD and branch, all 30 recorded
checkpoint source/config hashes, reusable package/helper/AVD presence, and three
protected document hashes. Large artifact hashes reuse receipt 364; artifacts
were not rebuilt or rehashed. Initial searches named two nonexistent test files;
scoped file discovery located actual codec/pairing/Standard-mode tests. No test ran.
Documentation links and `git diff --check` are the only new validation checks.

Next user action: authorize a second disposable account with separate Windows and
Android test profiles and the minimal Private-specific approval-guard change.
Do not send a password/passphrase/recovery code. The smallest next execution is
local approval-guard work/profile readiness, followed by manual Google selection
only when the isolated auth-only flow is ready. Cloud creation/exchanges require
explicit authorization; this preparation does not grant it.
