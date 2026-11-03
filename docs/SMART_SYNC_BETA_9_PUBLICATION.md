# Experimental Smart Sync beta 9 release ledger

Owner explicitly authorizes building and publishing the next experimental beta
from `e7eedc1`, `9fe20f5` and `292175c`. Baseline is clean `292175c`; new branch
`maintenance/smart-sync-beta9-release`, intended `1.0.19-beta.9+32`, schema 26,
sync protocol 1. Beta 8 is public at `dd36189`; beta 9/tag/code 32 were unused.

No publication before fresh exact-candidate CI, enabled Windows/production-signed
Android builds, package integrity, startup/data-preserving upgrade and signing
gates pass. Personal profiles, encryption formats and real cloud workspaces are
outside this task. Real Drive exchange remains explicitly NOT VERIFIED.

## Reuse and new gates

Reuse [comprehensive verification](SMART_SYNC_VERIFICATION.md): 635 host passes/
one opt-in skip, clean direct four-root analysis/313-file format, seven synthetic
real-adapter contracts, Python helper/preparation/Sandbox tests, and unchanged
compatibility/security assertions. Counts overlap; these are not new executions.
Version-only release preparation does not invalidate unchanged logic evidence.
Exact-source release CI, actual newly enabled/signed package checks and real
artifact upgrade/startup evidence are nevertheless fresh mandatory gates.

## Invocation ledger

Machine commands, durations, source and logs live under ignored
`.buildlog/verify/smart-sync-beta9/` and its protected C build context. No private
signing properties, keystore, OAuth sessions or recovery codes belong in artifacts.

| Invocation / purpose | Result / identity / reuse or rerun reason |
| --- | --- |
| Status, guidance, verification/publication receipts, release/tag inventory | Clean `292175c`; three required commits present; beta 9/code 32 available |
| Resource/context inspection | Approximately 5.2 GiB RAM and 138 GiB C space free; no personal-profile test. Use persistent C checkout/temp and sequential local heavy work, preserving prior evidence/caches |
| Release preparation | Version metadata synchronized, experimental notes and this ledger created; source identity follows after commit |

Final identifiers, CI/runtime outcomes, checksums, commands and limitations will
be recorded here after their gates execute. This checkpoint is not publication
or build-success evidence.
