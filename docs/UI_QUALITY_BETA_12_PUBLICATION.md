# UI quality beta 12 publication

2026-11-04, Asia/Amman UTC+03:00. Candidate `1.0.19-beta.12+35`, branch
`feature/ui-quality-beta12`, based on `940db4a`; previous public beta11 source
`c8f15614eb05fcbd39f287418d1f4de61d39dfef`.

The owner explicitly instructed: **“skip the tests and publish the app if any new
changes have been added.”** Remote releases/tags confirm beta11/code34 is the
latest published app; six committed UI batches add production changes. This new
request authorizes version synchronization, new release branch/tag push and
publication, superseding the earlier local-only constraint. No old tag or release
may be altered. Three unrelated storage documents remain excluded and unchanged.

## Scope and deliberate test skips

Publish a coordinated Windows Setup/portable + production-signed Android universal
APK experimental pre-release; keep latest Stable unchanged. No new product change
beyond the six committed batches. [Release notes](UI_QUALITY_BETA_12_RELEASE_NOTES.md)
describe the final behavior and limits. [Existing acceptance](UI_UX_PLATFORM_ACCEPTANCE.md)
retains actual reported W01 attachment passes and all remaining gaps.

At the owner's request, skip further host tests, analyzer, CI, native self-test,
emulator/device/manual acceptance and updater test execution. The normal
[release](RELEASE.md) gates still apply to future releases; this is an explicit
exception for this candidate. Reuse earlier scoped evidence only within its
recorded source/assertions/environment; do not label skipped work PASS. Native
Windows/Android and real Drive cross-device acceptance remain incomplete.

Artifact identity, approved public OAuth configuration, version consistency,
production Android certificate/code monotonicity, ELF/ZIP alignment, package
contents/private-file exclusion, checksums and remote/public upload integrity
remain required. Those are packaging/integrity operations, not application tests.
No installer, personal profile, cloud account or existing app data is operated.

## Evidence and invocations

Ignored `.buildlog/verify/ui-quality-beta12/` retains source/protected hashes,
remote release/tag baseline, exact build/package commands, times with offset,
logs, exit results and artifact metadata. Each invocation and any failure/retry
will be retained. Candidate/source, artifacts and final publication outcomes
follow below; preparation is not a published receipt.
