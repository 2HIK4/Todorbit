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

## Candidate build checkpoint

Application/tag candidate `a69dd63523f530ca69e547e5439725dbb8ed80aa` includes all
three requested commits. The release branch was pushed within publication
authorization. Protected persistent C context contains the exact detached
checkout, task scripts, output and temporary signing-property scope. Approved
public OAuth configuration is checked against existing provenance, temporarily
compiled into Windows and restored to the tracked disabled configuration.

| Fresh invocation | Result / identity / reason |
| --- | --- |
| `git push` + Android CI dispatch | Windows CI `41714353595`, Android CI `41714355673`, both exact `a69dd63` |
| C worktree/bootstrap/plugin-junction preparation | PASS exact source, four existing Pub-cache junctions prepared before first pub get; no Developer Mode or dependency change |
| Enabled Windows Release | PASS 169s Flutter compilation; exact beta 9+32 executable/native identity, approved configuration/binary receipt, Microsoft-signed CRT staging |
| CRT/packaged native/writer/background gates | PASS packaged self-test in fresh child profiles, real native journal writer, all four hidden-worker barriers |
| Setup/portable/checksum builders | PASS five Windows assets with final beta 9 names, core numeric installer metadata preserved; original source configuration restored |
| `audit-artifacts.py --windows-only` | PASS 29 bundle files, exact portable membership/bytes/CRC/licenses, five asset hashes/sidecars/manifest |
| Four-package Sandbox upgrade preparation | Hash-check actual public beta 8 and fresh candidate Windows packages; guarded shadow of production runner, exact old/new executable versions, same-location portable update, retained synthetic tasks/theme, repeated startup/integrity and uninstall preservation. Guest has only read-only package/runner and empty result mappings; networking disabled. Execution outcome pending |
| Android CI attempt 1 | FAIL in `android-workflow` before emulator/app execution: Google system-image installation reports invalid ZIP (`Error reading Zip content from a SeekableByteChannel`). Failed log retained; not an application failure or pass |
| `gh run rerun 41714355673 --failed` | Rerun only failed integration job on a fresh hosted guest/new download after diagnosed SDK preparation failure; unchanged passing jobs retained. Publication remains blocked until successful |
| Scoped Gradle cache reuse | Copy task-owned D cache/wrapper into protected C context for local Release build; preserve original cache and signing material. No global cleanup or source/toolchain upgrade |

### Diagnosed guest fixture and CI retry

Android CI attempt 2 is successful on the same source; only the failed SDK-image
integration job was rerun. The original failed download log is retained.

The first Windows Sandbox upgrade run passed actual installed beta 8 -> beta 9
DB-byte preservation, then failed a theme assertion. A fresh diagnostic guest
reported `Upgraded theme setting differs`. The fixture had edited only JSON,
while both beta 8 and beta 9 initialize supported preferences from authoritative
`portable_preferences` SQLite values. `AppController.initialize` /
`applyPortablePreferences` confirmed that existing contract. The fixture now
seeds SQLite and its JSON cache consistently **before** upgrading; the expected
dark value was retained, not changed to accept a failure. No product code or
candidate bytes changed. Failed receipts and shadow-runner hashes are retained.

The corrected fresh guest **PASS** verifies all four old/new package hashes,
exact old/new executable versions, installed and same-location portable actual
beta 8 -> beta 9 upgrades, retained task/theme/schema 26, repeated reopen and
integrity/foreign-key checks, candidate native self-test, uninstall data
preservation and reinstall. No GUI/OAuth acceptance is inferred. The synthetic
guest was closed; no owner installation/profile/secure-store data was mapped.

The diagnostic guest was capped at 2048 MiB after default Sandbox grew to 3.7 GB
and pressured the host. This follows [Microsoft Sandbox configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file).
Networking was disabled. Cache copy completed: 3.108 GiB/20,059 files plus
275.56 MiB/318 wrapper files, preserving its source. Local Android Release now
uses this protected C cache and two CPUs/one worker/1536 MiB heap sequentially
after the guest, not alongside another local compiler.

## Published outcome

Published **[v1.0.19-beta.9](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.9)**,
version `1.0.19-beta.9+32`, schema 26, sync protocol 1. GitHub release
`433219002` is public, `prerelease=true`, `draft=false`; publication used
`gh release edit v1.0.19-beta.9 --draft=false --latest=false`.
Application/tag source is **`a69dd63523f530ca69e547e5439725dbb8ed80aa`**.
No existing public release/asset/tag was replaced or edited.

GitHub publication timestamp: **2026-11-03T21:19:25Z**.

### Final gates and invocations

| Invocation / scope | Exact-source/artifact outcome |
| --- | --- |
| [Windows CI 41714353595](https://github.com/2HIK4/Todorbit/actions/runs/41714353595) | PASS exact `a69dd63`: full Flutter analysis (20.2s), **635 tests/one existing opt-in skip**, eight helper checks, public-config/CRT/native writer/workers, Release, Setup/portable and checksums. The 635 include the seven new adapter contracts; counts are not additive |
| [Android CI 41714355673](https://github.com/2HIK4/Todorbit/actions/runs/41714355673) | PASS exact source, overall attempt 2: 72 focused host checks, preparation/native alignment and two real emulator integration tests. Failed SDK-image job alone rerun; unchanged passing host/build job retained |
| Local production Android APKs | PASS in 352.86s; GitHub universal/ARM64/x64, code 32/version beta 9, nondebuggable, MinSDK 26, actual production certificate and ELF/APK 16 KiB alignment |
| Private Play AAB, signer and preparation | PASS AAB build 184.30s, bundle signature/config/native checks and durable signer; monotonic official Android metadata/code checks. AAB is retained privately and not uploaded to GitHub or Play |
| [16 KiB runtime 41719403377](https://github.com/2HIK4/Todorbit/actions/runs/41719403377) | PASS exact source: stable 40s no-app baseline, Android 16 x64 16,384-byte guest, actual production `adb install -r` beta 8 code 31 -> beta 9 code 32, retained synthetic task, completion/cold restart, no crash/ANR observed. Retained/completed screenshots inspected |
| Signing cleanup and original-file hash | PASS original signing properties unchanged; temporary protected C copy removed and scoped Gradle daemon stopped. No private key, user token/recovery code or personal data in public assets |
| Final `audit-artifacts.py` | PASS exact application inputs in main and private worktree, restored disabled source config, 29 Windows bundle files, ZIP CRC/content/licensing, APK metadata/manifests and exactly 11 public assets |
| Private staging/runtime dispatch | Verified production x64 uploaded once, server size/digest matched; immutable APK used by runtime gate. Uploaded only missing ten assets without clobber; all 11 server sizes/SHA-256 matched build audit |
| `readiness.py` + `draft-gate.py` | PASS actual Windows upgrade receipt, actual signed Android 31->32 receipt/hash, signing cleanup, all build/native gates, all three exact-source CI successes, notes/source/prerelease classification and 11 explicit assets |
| Publication command | PASS reviewed draft published with `--latest=false`; no Stable promotion |
| `verify-public.py` | PASS all 11 anonymous complete downloads/hashes; large-package Range delivery also checked. Downloaded bytes/GitHub digests match original build SHA-256. New remote tag exact source; previous public releases/assets/tags unchanged |
| `fetch-updater-inputs.py` then `flutter test --no-pub .../public_updater_test.dart` | PASS one test using production parsers and real anonymous JSON: beta 8 -> beta 9 Windows installed/portable, Android ordered ARM64/x64 and universal fallback/code 31->32; Stable excludes beta 9. Fixtures fetched before test; no owner profile or package execution |
| Archive/source review/docs/diff checks | Explicit logs and 11 public packages archived under ignored task folder, with hashes rechecked. Final docs/feature-catalog links and `git diff --check` pass; docs-only follow-up does not invalidate application evidence |

Final documentation commands: `python .buildlog/verify/smart-sync-beta9/finalize.py`,
`python tools/dev/check-docs.py` with the six changed documents and frozen beta 9
release notes, `git diff --check`, explicit documentation staging, and
`git commit -m 'docs(release): record experimental Smart Sync beta 9 publication [skip ci]'`
followed by `git push origin maintenance/smart-sync-beta9-release`. The release
tag stays at the tested application commit. Finalization first stopped reading a
PowerShell UTF-16 log as UTF-8, before changing documents; BOM-aware decoding fixed
the archival script and the same passing log was reused. No application gate was
rerun for this documentation-only correction.

The runtime APK SHA-256 is
`db04ec05ee9e64a2f519039a64551e5aa1a19b04d361e3a33caae71704b59c04`.
Previous beta 8 APK SHA-256 is
`c4d420c766008eaba8dbee6974499a448c942ff1d783e5e100acc357e2c29149`.
All CI/runtime source identities are the same candidate; no later test-harness
application-source exception was needed.

## Signing, compatibility and limits

Android production certificate SHA-256 remains
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
The x64 production in-place upgrade is observed; physical ARM64/OEM and native
installation approval/cancellation UI remain separate acceptance. Never uninstall
to bypass signer mismatch: retain/export data and verify recovery first.

Windows packages remain unsigned. Microsoft-signed CRT DLLs do not constitute a
publisher signature for Todorbit. Windows x64/11 is primary; Windows 10, physical
keyboard/DPI/shell and assistive-technology acceptance remain incomplete. Sandbox
process/SQLite/native checks do not prove those physical interactions.

No SQLite/encryption/backup/protocol migration occurred. Existing keys, immutable
history, Before Restore and profile/IPC/installer identity remain unchanged.
Readback-marker repair still requires authenticated content; outgoing provider
acknowledgement remains strict. Old clients can still encounter their original
blocking defect, so update both test devices. No personal profile, Google account
or real workspace was accessed or altered.

**Real Google Drive synchronization remains NOT VERIFIED end to end.** No
disposable account was available. Local contracts and packaged startup/upgrade
evidence do not establish actual consent, token refresh, cloud convergence,
quota/permission handling, OS background delivery, mixed-client behavior or
elimination of every data-loss risk. Google branding/policy acceptance remains
unresolved. This is explicitly experimental, not readiness for Stable promotion.
Keep a verified external backup, initially use disposable profiles/data and
retain the recovery code securely. See the concise [release acceptance
checklist](SMART_SYNC_BETA_9_RELEASE_NOTES.md#two-device-manual-smart-sync-acceptance)
and [detailed manual procedure](SMART_SYNC_VERIFICATION.md#precise-disposable-account-procedure).

## Public asset SHA-256

All rows match local builds, GitHub asset metadata and anonymous full bytes.
The two public checksum manifests/sidecars provide user-download comparisons.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `ANDROID-RELEASE-NOTES.md` | 3849 | `36744983ddb9dfac5c6b44b15f8e1b7857227e15151badf4d21709b160b83115` |
| `ANDROID-SHA256SUMS.txt` | 528 | `e061b82292d46eb3c01134c985a16bdae2c443761139660ed4c45b4e4822e4f2` |
| `Todorbit-1.0.19-beta.9-android-arm64.apk` | 26058651 | `b12c39a414d0e0763db1ad9d577b060f3ea8cbe25923a3e99e856035d92afa17` |
| `Todorbit-1.0.19-beta.9-android-universal.apk` | 52660823 | `8bb922090827537e92ac373d8551bd14a08eabfbb9bb707465a7e93c4216a702` |
| `Todorbit-1.0.19-beta.9-android-update.json` | 876 | `361042b46114b0cccfa857648e3279d76a19ab0d4a19417f40d649f71a871a9d` |
| `Todorbit-1.0.19-beta.9-android-x64.apk` | 27576631 | `db04ec05ee9e64a2f519039a64551e5aa1a19b04d361e3a33caae71704b59c04` |
| `Todorbit-1.0.19-beta.9-SHA256SUMS.txt` | 219 | `2a29d3d00c2e658ff2fc25ce8fad12cd03f49a9ee71ad6051860e89ac6da706a` |
| `Todorbit-1.0.19-beta.9-win-x64-portable.zip` | 63041842 | `959abda55f1b376f4456020df96f06c9500aca973d66ff37345596d9827f84cf` |
| `Todorbit-1.0.19-beta.9-win-x64-portable.zip.sha256` | 111 | `b32f434c28bd04653cd867bbe41843002978f68f8f07b1d9bd266091ddbca9bf` |
| `Todorbit-1.0.19-beta.9-win-x64-setup.exe` | 47662488 | `19bf323a14deede4b0d8ad861fdc308473c0660d490bbe31c3b19ede781b2537` |
| `Todorbit-1.0.19-beta.9-win-x64-setup.exe.sha256` | 108 | `4edf5996e3f56a3793fd2a264a43b2ec4a10b20120c9b65528cded1cc2f1421f` |
