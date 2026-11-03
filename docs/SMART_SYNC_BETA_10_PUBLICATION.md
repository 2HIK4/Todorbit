# Experimental optional Sync encryption beta 10 publication receipt

Owner explicitly authorizes version bump, release commits/tag, builds/packages,
GitHub upload and publication of this specific experimental pre-release.
Baseline `06b9ded`, branch `maintenance/smart-sync-beta10-release`, intended
version `1.0.19-beta.10+33`, tag `v1.0.19-beta.10`. Remote inventory confirmed it
unused; current production Android code is 32. Beta 9 and all prior releases/tags
must remain unchanged. Personal profiles and all real Drive operations are excluded.

## Scope, evidence reuse and explicit validation exception

Read AGENTS, workflow/testing/ledger, optional-encryption/manual-build receipts,
release/signing/OAuth/updater/packaging guidance and prior publication scripts.
The 23 implementation source/config fingerprints matched before version edits.
Reuse recorded targeted codec/pairing/controller/UI checks and the first successful
enabled Windows/production Android builds at `06b9ded`. New binaries/packages are
necessary only for version/code 33. Application logic, SQLite schema 26, native
profile/installer identity, backup/legacy encrypted formats and signing remain.

For **this beta only**, the owner's current explicit instruction prohibits full
Flutter suites, broad analysis/integration, emulator tests and duplicate builds.
It takes precedence over repository default exact-candidate broad CI/platform
gates. Workflow definitions are unchanged; release commits use `[skip ci]` to
avoid triggering those prohibited runs. No exact-candidate broad CI pass is
claimed, and historical passes are not relabeled as current-source acceptance.
Signature, package, version monotonicity, authorized OAuth, checksum/public-delivery
and updater-compatibility gates still must pass. Real Sync remains unverified.

Existing installer/AppId/profile paths and Android package/certificate are retained.
Static upgrade compatibility plus unchanged prior data-preserving upgrade evidence
is reused; no actual installation/emulator/registered-user upgrade is executed.
This is an explicit physical-acceptance gap, disclosed in release notes.

The existing Android preparer required an otherwise unnecessary Play AAB. Add an
explicit `--apk-only` mode to that same helper: retain all APK/signing/alignment/
monotonic-code checks, keep its existing default requiring AAB, and reject supplied
AAB plus APK-only. No second release pipeline, signing change, extra APK variant
or AAB is introduced. Only three focused helper tests cover this tooling addition.

## Invocation ledger

Detailed logs/identities stay in ignored `.buildlog/verify/smart-sync-beta10/`.
Every build/check records source/time/purpose/result there and in this receipt.

| Invocation / purpose | Source / result / necessity |
| --- | --- |
| Git status/branch/HEAD/recent commits/remote; focused guidance/source/receipt reads | Baseline above, six documentation changes identified. Preserve original three storage docs; include relevant manual-build receipt/ledger/Progress in release work. No unfinished Git operation. |
| `gh auth status`, release inventory, `git ls-remote --tags origin refs/tags/v1.0.19-beta.10` | Authorized existing GitHub account; tag/release unused. Entire prior release/tag inventory retained for non-mutation checks; no credentials printed. |
| Prior SHA-256 comparison; preserved storage/OAuth/signing hashes; version edits | All 23 source/config fingerprints matched. New beta10+33 metadata only; schema/logic/credentials untouched. Need fresh versioned packages, not repeated unchanged tests. |

Build, packaging, draft/public delivery and updater outcomes will be appended with
actual source and artifact identities. This checkpoint is not publication proof.

| 2026-11-04T02:55:31+03:00 `python -m unittest tools.test_prepare_android_release.ApkOnlyPreparationTests` | PASS three focused tests: explicit APK-only emits metadata/checksums with existing APK/floor gates; unchanged default requires AAB; conflicting AAB argument rejected. New tooling boundary only; old unchanged verifier tests reused. `logs/apk-only-tests.log`. |

| 2026-11-04T02:55:56+03:00 `python tools/dev/check-docs.py` with the six changed release/manual/ledger documents; `git diff --check`; reviewed version/tooling diff | PASS zero routing/catalog/link or whitespace errors. New release docs and narrow helper changes only; no broad analysis. |
