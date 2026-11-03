# Corrected UI quality beta 7 candidate ? 2026-11-03

The unpublished beta 6 candidate below is rejected, not released. Its mandatory
[16 KiB runtime](https://github.com/2HIK4/Todorbit/actions/runs/41615668784)
created and displayed the synthetic task, then cold restart showed a startup
failure: SQLite code 5 at `PRAGMA quick_check`. The failure XML contains the
startup error screen; this was not a missing-task navigation assertion issue.

Startup backup readers had no busy handler, unlike the live database connection.
New real-lock regression tests reproduced the same exception before the fix at
schema inspection, automatic backup inspection and manual snapshot creation.
Those readers now use the existing five-second bounded wait. Integrity checks,
read-only source access and fail-closed persistent-lock behavior are preserved.
SQLite documents transient contention during [WAL recovery](https://www.sqlite.org/wal.html).
The exact cold-restart cause is confirmed only when the corrected APK passes the
original runtime assertions; the host reproduction alone does not prove that.

The corrected candidate is **v1.0.19-beta.7+30**, schema 26. Beta 6's private draft,
asset IDs/digests and evidence are retained unchanged. New compiled code
invalidates its exact-source CI and packages for publication; those historical
passes below remain evidence only for beta 6. Fresh beta 7 gates are pending.
The candidate will remain private until all mandatory release checks pass.

The four new contention tests pass after the fix (three failed before it);
the fourth proves a persistent lock still raises code 5, leaves database bytes
unchanged and publishes no backup. Full startup/backup/migration regressions and
connected diagnostics are recorded under `.buildlog/verify/stage21-release/`.
DTD had no connected app; hot restart was attempted but unavailable. No personal
profile was opened. Failure diagnostics now retain the complete Android main log
in addition to the existing crash/events/system evidence, without weakening any
runtime assertion or changing its timeout.

## Rejected beta 6 preparation history

# UI quality beta 6 release checkpoint — 2026-11-03

Publication was explicitly requested after the completed local
[Stage 2.1 follow-up](UI_UX_STAGE2_AUDIT.md#stage-21-follow-up--2026-11-03).
Candidate: **v1.0.19-beta.6**, Windows/Android `1.0.19-beta.6+29`, schema 26.
This is a prerelease; do not mark it as latest Stable.

Public releases and remote tags were inspected before selection: beta 5/code 28
was current, beta 6 was unused and no draft release existed. Previous public
releases/tags must remain unchanged. The local Stage 2.1 checkpoint is `9240364`;
runtime candidate source is `e8419c74bb3d435414d0ccf87ca7704b65f081e5`.
Later documentation-only corrections do not change packaged runtime code.

## Scope and release gates

[Release notes](UI_UX_STAGE2_RELEASE_NOTES.md) cover the Stage 2 editor/navigation
fixes and Stage 2.1 Windows native event appearance. Production Android code,
installer/updater, database schema, app/profile/IPC identities and signing
identity are preserved. The production Android certificate remains
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.

The previously owner-approved public Desktop OAuth configuration is retained for
the coordinated experimental release, with provenance/hash validation, temporary
build-only substitution and exact restoration of the tracked disabled config.
No user credentials, accounts or Cloud Console settings are copied or changed.

| Gate | Status |
| --- | --- |
| Local Stage 2.1 native Release/self-test, live style reload/recreation, rendered icon atlases | PASS; detailed source/artifact boundaries in audit |
| Local focused host probes and test-source analysis | PASS across scoped runs; full unchanged Stage 2 evidence reused for local follow-up only |
| Exact beta 6 Windows full analysis/serial suite/native/package CI | [41584177622](https://github.com/2HIK4/Todorbit/actions/runs/41584177622) PASS: 597 tests/one existing opt-in skip, eight helper tests, full analysis, OAuth/CRT, native writer/hidden worker, packaged self-test, Setup/portable/checksums |
| Exact beta 6 Android CI and emulator integration | [41584178103](https://github.com/2HIK4/Todorbit/actions/runs/41584178103) PASS: analysis, 72 host tests, 11 preparation tests, artifact alignment and two real emulator integrations |
| Production-signed beta 6 APKs and private Play AAB identity/alignment | PASS: universal/ARM64/x64 production identity, nondebuggable code 29, ABI/SDK/alignment, private AAB certificate/manifest/signature and official monotonic metadata. Temporary signing-properties copy removed; scoped daemon stopped |
| Enabled local Windows Release/CRT/config consistency, Setup/portable integrity | PASS: enabled build/config/CRT, unchanged-binary C-temp self-test, byte-verified C-context writer/worker gates, Setup, ZIP CRC/exact 29 bundle files plus notices/license and final sidecars/manifests |
| Exact final APK 16 KiB hosted runtime | [41615668784](https://github.com/2HIK4/Todorbit/actions/runs/41615668784) in progress, source e8419c7, exact x64 SHA-256 `d0e7afa4…f6a04` |
| Draft source/classification/assets/digests, public delivery/updaters | Private draft 432503248 targets e8419c7, prerelease/latest false. All 11 local assets pass integrity; public delivery/updater checks await final gate/publication |

CI and build results for beta 5 or the pre-version Stage 2.1 artifacts do not
satisfy exact beta 6 release gates. Logs, artifact manifests and per-invocation
records are retained under ignored `.buildlog/verify/stage21-release/`.

## Invocation ledger

| Procedure / scope | Result | New/rerun or reuse reason |
| --- | --- | --- |
| `gh api .../releases`, `git ls-remote --tags origin`; snapshot existing public identities | PASS: beta 5 latest, beta 6 unused; releases-before.json / tags-before.txt | New publication authorization/version selection; prior releases preserved |
| `gh api .../actions/workflows` | First TLS handshake timeout; retry PASS, existing Android/Windows/16 KiB workflows active | Rerun only failed network read; no workflow/source change |
| Version synchronization, changelog/notes, builder/helper syntax, docs checker, `git diff --check` | PASS | New beta 6 candidate; notes link corrected in documentation-only follow-up |
| Push candidate branch; dispatch Android CI; inspect job/step evidence and retain logs | Both exact-source CI runs PASS as linked above | New Release risk gates; broader Stage 2 local evidence does not replace these |
| Local `build-candidate.ps1 -Mode Windows -Source e8419c7…` | Enabled build/config/CRT PASS; original D-temp native check failed after 36m at `VerifyCommandPipe` synchronization assertion | New enabled public-config artifact, independent of disabled CI bundle; failed log retained |
| Git blob comparison against beta 5: installer, updater/helper, Android native main, startup/runner and portable acceptance helper | PASS: unchanged | Reuse beta 5 portable swap/rollback, clean installer retention and native Android installer-path acceptance only for these unchanged boundaries; final artifact/signature/runtime gates are fresh |
| Diagnostic process/log/resource reads | Flutter preparation advancing; no speculative source change | New build observability. One `gh --jq` status expression lost Windows quoting; corrected to PowerShell JSON parsing |
| Android task-local build resource limits | Selected two active CPUs, one worker and 1536 MiB Gradle daemon heap after observed ~1.1–1.4 GiB free RAM; existing app processes retained | Process environment only, no tracked Gradle/settings change; [Gradle environment/property reference](https://docs.gradle.org/current/userguide/build_environment.html). Wrapper configured to stop its scoped daemon after build; execution pending |
| Three 4 KiB write/flush probes in new C/D disposable directories → disk-probe.json | C: 0.0015–0.0026s; D: 4.5839–6.6655s; C had 8.5 GiB free. Probe directories confined and removed | New environment diagnostic for unexpectedly slow persistence/build work, not an app test |
| Exact unchanged companion `--self-test` with fresh C-temp APPDATA/LOCALAPPDATA/TEMP | PASS in 50s, including command pipe, revision safety and persistence; packaged-self-test-c-temp.log | Controlled storage-environment rerun; no binary/assertion change. D's command-pipe timeout is retained; storage/scheduling contribution is an inference from these observations |
| `build-candidate.ps1 -Mode Windows -ResumeWindowsPackaging` | Reused validated build/CRT/C-temp pass and rechecked enabled AOT/config receipt; resumed Setup/portable/checksums only | New guarded resume; do not rebuild unchanged runtime |
| Private C-temp detached checkout of e8419c7, cache seed and plugin junction preparation | Source and user/SYSTEM-only ACL verified. First wrapper treated Git informational stderr as failure although checkout completed; reuse confirmed clean. Redundant ACL reset then failed privilege check; existing correct ACL retained/validated | Retry only preparation after diagnosed wrapper issues; no credentials materialized during preparation. Existing dependencies copied without lock/gc files, per [Gradle cache guidance](https://docs.gradle.org/current/userguide/dependency_caching.html) |
| Local enabled writer/worker gates, original D context | Writer test timed out at two minutes; worker not reached | New exact enabled-artifact boundary, independent of disabled CI artifact; no timeout/assertion relaxed |
| Same gates from byte-identical C bundle and exact-source temporary checkout | Initial setup failures: copied JSON BOM hid dependencies, then missing generated package_graph; standard `flutter pub get --offline` regenerated complete locked metadata. One wrapper suffix expression failed before tests. Final `-c-context-04` PASS: native writer and all four hidden-worker barriers | Rerun only after diagnosed context preconditions; original assertions and exact binary bytes retained. No real Drive connection; source config restored |
| Android candidate context/root guard and first production attempt | First guard used overridden TEMP instead of original base; corrected before signing. First real attempt failed Kotlin DSL settings imports with distribution junction; shutdown stderr initially masked root error | Guard/wrapper corrected; no application build-source change, temp signing file removed even on failure |
| Same pinned Gradle 9.3.1 distribution physically copied into private context; generated API cache retained by rename; `gradlew help` | PASS in 2m44s, same project source | Controlled installation-context correction; previous junction/cache preserved, no project cleanup or dependency upgrade |
| Production `build-candidate.ps1 -Mode Android -AndroidContext … -AttemptLogSuffix -03` | PASS: APKs 5m20s, private AAB 2m59s, certificate/complete preparation and scoped daemon stop. Original keystore unchanged; temporary properties removed in finally | New final signed artifacts from exact-source C checkout; all signatures/identity/ABI/SDK/alignment gates retained |
| `audit-artifacts.py --windows-only`, then full `audit-artifacts.py` | PASS: 29 bundle files, complete ZIP CRC/membership/notice/font-license equality, sidecars/manifests, five Windows then eleven coordinated assets | New final integrity gate; private AAB excluded by explicit asset allowlist |
| Private draft create/upload; independent final x64 verifier and runtime dispatch | Windows five digests/sizes verified; x64 production signer/code/ABI/SDK/alignment/hash verified and GitHub digest matched before 16 KiB dispatch | Staging only, publication authorized but held for mandatory runtime/draft gate; x64 asset never replaced during runtime test |

The fresh package and 16 KiB gates below remain mandatory; unchanged-boundary
acceptance reuse does not waive them. Local physical GUI/launcher testing is not
silently inferred from CI. No installer is executed on the owner's account.

## Explicit acceptance limits

The original Android shaking sequence remains unreproduced. Native keyboard/error
transitions and the expanded 192-case footer probe were blocked by local guest
failures; the original two footer PNGs show complete labels on reinspection.
Physical OEM launcher, ARM64, TalkBack, Narrator, Windows input/DPI/multi-monitor
and shell acceptance are unobserved. No Windows Sandbox will be launched for
this checkpoint. These limitations are disclosed, not converted to passes.

Existing unchanged installer/updater and signing acceptance can be reused only
at identical source boundaries; final package identities, signatures, code 29,
alignment and mandatory runtime/CI still require fresh evidence. Real Google
Drive exchange and branding remain under the existing experimental limitations.
The AAB is a private candidate, not a GitHub release asset or Play publication.
