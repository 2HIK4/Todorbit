# Persistent test run ledger

Consult this index **before every test** with [Testing](TESTING.md#verification-ledger).
Keep existing detailed task receipts authoritative; add one linked receipt per
task, rather than another testing framework or copied historical outputs. Every
execution/failure/rerun and meaningful reuse/skip belongs in its receipt, including
timestamp/offset, source identity, command, scope, purpose, result and necessity.
Reuse requires unchanged relevant source, assertions, dependencies, configuration
and equivalent environment. A commit alone does not identify a dirty tree; use a
small manifest of SHA-256 hashes for the affected files, or a patch hash.

| Date / task | Source / scope | Receipt and reuse limits |
| --- | --- | --- |
| 2026-11-04, optional sync encryption | `13e2734` plus feature diff; codec, pairing, controller, provider error states, Settings | [Implementation and invocation receipt](SYNC_OPTIONAL_ENCRYPTION.md). Prior passes do not cover changed Sync behavior. No live Drive acceptance or builds authorized. |
| 2026-11-04, experimental beta 9 publication | Exact release source `a69dd63`; signed Android and Windows artifacts | [Publication receipt](SMART_SYNC_BETA_9_PUBLICATION.md). Unchanged backup/native/packaging boundaries retained as historical baseline, not current Sync acceptance. |
| 2026-11-03, comprehensive Smart Sync verification | Per-invocation source/artifact identities in receipt | [Verification ledger](SMART_SYNC_VERIFICATION.md). Full host/adapter/runtime results cannot be reused for altered protocol or UI; unchanged feature evidence may be reused after boundary comparison. |
| 2026-11-03, Smart Sync redesign | Per-invocation source identities and rerun causes | [Redesign ledger](SMART_SYNC_REDESIGN.md). Preserve failures and interrupted runs; do not add overlapping test counts. |

Older feature receipts remain discoverable from [Progress](PROGRESS.md). Add their
links when relevant; no repository-wide scan or historical migration is required.
