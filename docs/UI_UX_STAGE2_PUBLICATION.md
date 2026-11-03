# Published UI quality beta 7 - 2026-11-03

Published [v1.0.19-beta.7](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.7)
for Windows and Android after all mandatory gates passed. Exact checksums and
public delivery evidence follow; physical acceptance limits remain explicit.

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
The corrected final APK subsequently passed the original cold-restart assertions
on the same official API-36 16 KiB image; see its exact hash and run below.

The published version is **1.0.19-beta.7+30**, schema 26. Beta 6's private draft,
asset IDs/digests and evidence are retained unchanged. New compiled code
invalidates its exact-source CI and packages for publication; those historical
passes below remain evidence only for beta 6. Fresh beta 7 gate results are recorded below.
All mandatory release gates passed before publication, as recorded below.

The four new contention tests pass after the fix (three failed before it);
the fourth proves a persistent lock still raises code 5, leaves database bytes
unchanged and publishes no backup. Full startup/backup/migration regressions and
connected diagnostics are recorded under `.buildlog/verify/stage21-release/`.
DTD had no connected app; hot restart was attempted but unavailable. No personal
profile was opened. Failure diagnostics now retain the complete Android main log
in addition to the existing crash/events/system evidence, without weakening any
runtime assertion or changing its timeout.

## Beta 7 verification

Runtime source: `291955114e612f850b7ece91c6093a44596e9ec3`.
Version `1.0.19-beta.7+30`, schema 26; original production Android signer retained.
Evidence and per-command ledger: `.buildlog/verify/stage21-release-beta7/`.

| Gate | Result and identity |
| --- | --- |
| Startup/backup/migration focused regressions | PASS 39; real-lock reproduction failed three cases before correction, all four new cases pass after. Persistent lock remains a safe code-5 failure with database bytes unchanged and no published backup |
| Exact-source Android CI | [41617836831](https://github.com/2HIK4/Todorbit/actions/runs/41617836831) PASS; 72 host tests, 11 preparation tests and two real emulator integration tests |
| Signed Android packages | PASS; universal/ARM64/x64 APK and private Play AAB certificate, identity/code 30, nondebuggable/ABI/SDK/native ELF and ZIP alignment, provider/permission separation and monotonic metadata |
| Exact signed x64 APK runtime on API 36 / 16 KiB | [41618940132](https://github.com/2HIK4/Todorbit/actions/runs/41618940132) PASS; SHA-256 `c18715422bfca9c4c9e1873515dd11389ab8b7eca4bb8aa0a85041364042125d`. Forty-second stable no-app baseline, render, synthetic task save/reopen/completion, no observed crash/ANR. Final reopen PNG inspected: one of one planned tasks complete |
| Exact-source Windows CI | [41617835263](https://github.com/2HIK4/Todorbit/actions/runs/41617835263) PASS; full analysis, 601 tests/one existing opt-in skip, eight helper tests, OAuth/CRT, native/runtime and package gates |
| Enabled local Windows runtime | PASS build, CRT positive/negative checks, executable versions, packaged native self-test, actual native writer and four hidden-worker barriers using C-temp synthetic profiles |
| Setup/portable integrity | PASS; ZIP CRC and exact 28-file built bundle equality, required notices and Material Icons license, final sidecars/manifests and eleven-asset allowlist. Public delivery/updater checks PASS |

The five-second wait does not reset, migrate or replace a database, bypass
integrity checks, change SQLite journal mode, alter restore-exclusive-lock
semantics or retry indefinitely. Local temporary signing properties were removed
in `finally`; the original keystore/properties remain unchanged. The pinned
build caches were reused, with standard offline dependency metadata regeneration.
The same isolated C checkout avoids the previously measured D-drive flush latency;
Windows compilation completed in 160 seconds. No installer was executed.

Beta 7 verification is new because compiled source/version changed. Beta 6
acceptance claims below are historical; only unchanged physical acceptance
limitations and installer/updater boundary evidence are carried forward.
The Android native launcher/IME and physical Windows/accessibility limits below
still apply. The Play AAB stays private, and real Google Drive acceptance remains
limited. DTD had no connected app for hot restart and its targeted analyzer timed
out after 300 seconds; exact-source CI analysis provides the analysis gate.

The first beta 7 ZIP audit compared notice bytes with the D checkout and failed
on `LICENSE` because that checkout and the C build checkout have different Git
line endings. The rerun compared all notice/license/script expectations against
the exact clean C build checkout and passed unchanged raw-byte/hash assertions.
No package was changed. The 28-file bundle differs from beta 6's 29 only by an
absent stale root `native_assets.json`; all required runtime files and current
asset manifests remain, with actual native/database worker gates passing.

## Published release and final delivery

Published [v1.0.19-beta.7](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.7) at `2026-11-03T10:35:16Z`,
release ID `432543494`, exact runtime/tag source
`291955114e612f850b7ece91c6093a44596e9ec3`. Prerelease only, `latest=false`.
The strict private draft gate passed exact source/body/classification, eleven
asset sizes/digests, exclusions and all three exact-source CI successes before
publication. The tested x64 asset `705181121` was never replaced.

Anonymous delivery passed for all eleven assets. Small files were downloaded
and hashed completely. Large binaries were checked with `206` Range responses,
exact total sizes and first-byte equality, plus GitHub full SHA-256 digests
matching the local final files; they were not downloaded again in full.
The public tag resolves to the verified source. Every previous public release's
body/classification/assets and every previous remote tag remained unchanged.

The actual production updater fixture passes against the downloaded public
release and Android manifest: Windows installed/portable selection from beta 5,
ordered ARM64/x64 selection, universal fallback, sizes/digests and Stable
exclusion. This is one focused test containing those scenarios. It does not
claim a physical installer execution or Android system approval interaction.

| Public asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `ANDROID-RELEASE-NOTES.md` | 2474 | `58ca9ac264ada2bbc52a1818ee3e6bb34fb71f9b3fcedf20b470f86e2871778f` |
| `ANDROID-SHA256SUMS.txt` | 528 | `50c73b8cb5cab0ec703956be5ad7f2363a07f9479dce8a6dc400de6427095014` |
| `Todorbit-1.0.19-beta.7-android-arm64.apk` | 26058591 | `198ccd2a6c8d01ff31b0731e77f5a8c3c4c7969b238ab43189a5ddf43680968e` |
| `Todorbit-1.0.19-beta.7-android-universal.apk` | 52595227 | `a5d3de93342a1e770bf8ba4ce1a02211df0dd5dd9893ae925ea41acff3560a0c` |
| `Todorbit-1.0.19-beta.7-android-update.json` | 876 | `8acb11855dbfbcd8f30810912171156048405846fc90025bb2c83d7dddb7520f` |
| `Todorbit-1.0.19-beta.7-android-x64.apk` | 27511035 | `c18715422bfca9c4c9e1873515dd11389ab8b7eca4bb8aa0a85041364042125d` |
| `Todorbit-1.0.19-beta.7-SHA256SUMS.txt` | 219 | `57c9c2723258309585d7f80fbcf17ded0df9211799fb44e1ea4bd9adaa296727` |
| `Todorbit-1.0.19-beta.7-win-x64-portable.zip` | 63017146 | `8f3f1a863cdc1520ea39ff386a2179234bf4da85649f019a4afb0e0dcc79195a` |
| `Todorbit-1.0.19-beta.7-win-x64-portable.zip.sha256` | 111 | `8387f759aa1b1f265193cc3ba8d49a3bdc4c7e21044172db272b36c27a4cbeab` |
| `Todorbit-1.0.19-beta.7-win-x64-setup.exe` | 47654546 | `aa12b9ca9fa8c42634198818e4ad3c24c9b74d4a1d66d44d4de75aa5534ab1a2` |
| `Todorbit-1.0.19-beta.7-win-x64-setup.exe.sha256` | 108 | `d87eb47225a0fbbd96a790c761eb13fb24792d076c7e198c53529f504f16cf46` |

The rejected beta 6 draft `432503248` remains private. Its source, classification,
updated timestamp and eleven original asset IDs/sizes/digests are unchanged;
its body equals the original packaged notes. An initial cached API-body comparison
failed because that local capture had replaced an em dash with a replacement
character. Comparison against the immutable packaged notes passed; no remote
metadata was edited. The private Play AAB and signing material were not uploaded.
No main-branch merge, website deployment or Play publication was performed.

Additional executed verification: strict draft gate PASS; anonymous delivery and
old public metadata/tag verification PASS; production public updater fixture
PASS; rejected-draft preservation comparison PASS after the diagnosed capture
encoding correction. Repeated status/digest inspections were read-only. Final
documentation link/path checks and `git diff --check` pass. Per-command build
results, sources, timings, logs and rerun reasons remain in the ignored ledger.
The four pre-fix/new contention cases, 39 post-fix feature tests, MCP timeout,
missing live-app restart, signed builds, fresh CI and fixture-audit rerun are
described above. No broad local suite was repeated after the focused pass;
mandatory exact-source CI supplied the full 601-test gate. Documentation-only
follow-up does not invalidate packaged runtime evidence. A documentation helper
initially stopped on the Windows default decoder while reading the audit; the
remaining append completed with explicit UTF-8 and link/diff checks passed.

## Rejected beta 6 preparation history

**Rejected beta 6 preparation checkpoint - 2026-11-03**

Publication was explicitly requested after the completed local
[Stage 2.1 follow-up](UI_UX_STAGE2_AUDIT.md#stage-21-follow-up--2026-11-03).
Candidate: **v1.0.19-beta.6**, Windows/Android `1.0.19-beta.6+29`, schema 26.
This is a prerelease; do not mark it as latest Stable.

Public releases and remote tags were inspected before selection: beta 5/code 28
was current, beta 6 was unused and no draft release existed. Previous public
releases/tags must remain unchanged. The local Stage 2.1 checkpoint is `9240364`;
runtime candidate source is `e8419c74bb3d435414d0ccf87ca7704b65f081e5`.
Later documentation-only corrections do not change packaged runtime code.

### Scope and release gates

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
| Exact final APK 16 KiB hosted runtime | [41615668784](https://github.com/2HIK4/Todorbit/actions/runs/41615668784) FAIL: startup SQLite code 5 at `PRAGMA quick_check`; candidate rejected, source e8419c7, exact x64 SHA-256 `d0e7afa4…f6a04` |
| Draft source/classification/assets/digests, public delivery/updaters | Private draft 432503248 targets e8419c7, prerelease/latest false. All 11 local assets pass integrity; not published after failed runtime; superseded by beta 7 |

CI and build results for beta 5 or the pre-version Stage 2.1 artifacts do not
satisfy exact beta 6 release gates. Logs, artifact manifests and per-invocation
records are retained under ignored `.buildlog/verify/stage21-release/`.

### Invocation ledger

| Procedure / scope | Result | New/rerun or reuse reason |
| --- | --- | --- |
| `gh api .../releases`, `git ls-remote --tags origin`; snapshot existing public identities | PASS: beta 5 latest, beta 6 unused; releases-before.json / tags-before.txt | New publication authorization/version selection; prior releases preserved |
| `gh api .../actions/workflows` | First TLS handshake timeout; retry PASS, existing Android/Windows/16 KiB workflows active | Rerun only failed network read; no workflow/source change |
| Version synchronization, changelog/notes, builder/helper syntax, docs checker, `git diff --check` | PASS | New beta 6 candidate; notes link corrected in documentation-only follow-up |
| Push candidate branch; dispatch Android CI; inspect job/step evidence and retain logs | Both exact-source CI runs PASS as linked above | New Release risk gates; broader Stage 2 local evidence does not replace these |
| Local `build-candidate.ps1 -Mode Windows -Source e8419c7…` | Enabled build/config/CRT PASS; original D-temp native check failed after 36m at `VerifyCommandPipe` synchronization assertion | New enabled public-config artifact, independent of disabled CI bundle; failed log retained |
| Git blob comparison against beta 5: installer, updater/helper, Android native main, startup/runner and portable acceptance helper | PASS: unchanged | Reuse beta 5 portable swap/rollback, clean installer retention and native Android installer-path acceptance only for these unchanged boundaries; final artifact/signature/runtime gates are fresh |
| Diagnostic process/log/resource reads | Flutter preparation advancing; no speculative source change | New build observability. One `gh --jq` status expression lost Windows quoting; corrected to PowerShell JSON parsing |
| Android task-local build resource limits | Selected two active CPUs, one worker and 1536 MiB Gradle daemon heap after observed ~1.1–1.4 GiB free RAM; existing app processes retained | Process environment only, no tracked Gradle/settings change; [Gradle environment/property reference](https://docs.gradle.org/current/userguide/build_environment.html). Wrapper stopped its scoped daemon after the successful final build |
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

Beta 6 failed the mandatory 16 KiB gate and was never published; unchanged-boundary
acceptance reuse did not waive it. Local physical GUI/launcher testing is not
silently inferred from CI. No installer is executed on the owner's account.

### Explicit acceptance limits

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
