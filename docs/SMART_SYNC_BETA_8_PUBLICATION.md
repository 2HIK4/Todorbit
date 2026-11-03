# Experimental Smart Sync beta 8 release ledger

Owner explicitly authorized public experimental prerelease publication despite
incomplete comprehensive acceptance. Mandatory builds, startup/data safety,
signing and integrity remain gates; no publication before they pass.

Candidate: `1.0.19-beta.8+31`, schema 26, protocol 1, branch
`maintenance/smart-sync-beta8-release`, based on clean `4c83b8d` and all five
Smart Sync commits. Remote beta 7 is `2919551`; beta 8/tag/code 31 were unused.
No existing release or tag was replaced. Full-suite stalls are not passes.

## Evidence policy

Reuse the Smart Sync 38-test regression and 18-test final orchestration evidence
where runtime behavior/assertions are unchanged (counts overlap), plus unchanged
beta 7 installer/updater acceptance boundaries. Run fresh exact-candidate CI,
enabled Windows and production-signed Android builds, final artifact integrity
and minimum isolated startup/runtime checks. The owner's experimental exception
allows focused checks if the full suite stalls; it does not waive mandatory
build, signing, startup or data-safety gates. Real provider and physical acceptance
remain separate and must be disclosed in release notes.

## Invocation ledger

| Procedure | Result / reason |
| --- | --- |
| Initial status/log and five ancestor commits | Clean Smart Sync branch at `4c83b8d`; required commits present |
| Guidance, workflows, Smart Sync and beta 7 release evidence | Read; no application rewrite planned |
| `gh release list`, repository identity, `git ls-remote --tags` | Beta 7 latest published prerelease, rejected beta 6 draft retained; beta 8 unused |
| Prior build context inspection | C-temp source has no Git pointer/pubspec and cannot be reused as a valid checkout; preserve it. Existing C Gradle dependency cache remains available |
| Host/build diagnosis reuse | Prior measured D write/flush latency was 4–7 seconds versus milliseconds on C. New isolated C checkout selected; no cache deletion or personal-profile access |

Detailed per-command logs and candidate metadata: ignored
`.buildlog/verify/smart-sync-beta8/`. Final publication outcomes and assets follow
below. Earlier checkpoints record the state at the time of each invocation.

## Candidate checkpoint

Runtime/tag candidate source: `dd36189c74548b14ed49fea8b12344ba4d0966fe`.
Version preparation `2125e76`; artifact-only upgrade harness `dd36189` adds an
optional hash-verified previous APK to the existing 16 KiB runtime job. It seeds
synthetic data, requires actual production `adb install -r`, increasing code and
retained data, then exercises completion/cold restart. No uninstall/clear fallback.

- [Windows CI 41667016596](https://github.com/2HIK4/Todorbit/actions/runs/41667016596)
  PASS: full analysis, **628 tests/one existing opt-in skip**, eight helper checks,
  native/background barriers, Release/CRT, Setup/portable/checksum gates.
- [Android CI 41667037549](https://github.com/2HIK4/Todorbit/actions/runs/41667037549)
  PASS: focused analysis/host checks, preparation, Debug artifact alignment and
  both emulator integrations. Production signing/runtime gates remain separate.
- Ancestor-source CI runs were canceled only after the release harness changed
  the candidate; the two passing runs above use the exact candidate source.
- Enabled local Windows build, CRT, packaged native self-test, native writer and
  all four hidden-worker barriers PASS. Setup and portable packages audit PASS:
  29 bundle files, exact ZIP bytes/membership/CRC/licenses, five Windows assets
  and matching SHA-256 sidecars/manifests. No installer executed on owner's account.
- Actual Release startup survives in a new C-temp child APPDATA/LOCALAPPDATA;
  resolved `TodoPilot/life_manager.sqlite` passes read-only quick_check, schema 26.
  This is process/database startup evidence, not physical GUI/DPI acceptance.

### Build diagnostics and rerun reasons

| Invocation | Outcome / controlled follow-up |
| --- | --- |
| Initial private Windows pub get | Plugin symlink prerequisite failed; repository junction helper prepared generated links without changing Developer Mode; rerun passed |
| Same-source enabled Windows build in private checkout | PASS; preserved original SDK and config, restoring tracked disabled config after packaging |
| One 4 KiB write/flush probe on each drive | C 0.0023s, D 5.6334s; scoped build diagnosis only, not comprehensive performance work |
| Private SDK setup | Full reference clone stalled and was retained; optional source cleanliness probe was interrupted, not evidence of SDK modification. Exact pinned Git-object checkout required private `core.longpaths=true`; no global setting changed |
| Private SDK identity check | Flutter 3.47.7, framework `abaf9c523780a608bd46686fd5e53740a07077f8`, Dart 3.13.5; same pinned binaries reused through cache junctions, writable metadata on C |
| First Android production attempt | SDK path change required refreshed generated plugin junctions; failed before Gradle wrapper creation. Temporary signing properties removed. Wrapper cleanup corrected to preserve the primary failure when no daemon was launched |
| Android production retry `-02` | PASS: production APKs, private AAB, signer and preparation; refreshed junctions, pinned SDK, existing cache, two CPUs/one worker/1536 MiB heap and scoped CMake. Temporary signing properties removed and daemon stopped |

The build checkpoint identified private context, SDK, synthetic profiles and
logs in ignored `context.json` / `candidate.json`. Some temporary files were no
longer available on resume, as recorded below. Signing material is excluded from
packages; original keystore/properties remain outside artifacts and unchanged.

## Published outcome

Published **[v1.0.19-beta.8](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.8)**
on 2026-11-03 at **17:45:51 UTC** (20:45:51 Asia/Amman). GitHub release
`432942440` is public, `prerelease=true`, `draft=false`; publication used
`--latest=false`. Tag/application source is
`dd36189c74548b14ed49fea8b12344ba4d0966fe`.
The later runtime-harness commit `4ce4d3765b3007ce92b36a9ad3d784b8996fa388`
changes only the runtime capture script. A strict Git diff whitelist confirms
no application/build source changed; uploaded binaries were not replaced.

### Final verification invocations

| Invocation / purpose | Identity / result / rerun reason |
| --- | --- |
| Production APKs + private AAB + signer + preparation, attempt `-02` | PASS exact app source; APK code 31/version beta 8, nondebuggable, MinSDK 26; ZIP/ELF 16 KiB checks pass. AAB remains private |
| Full artifact audit | PASS 29 Windows bundle files and 11 explicit public assets; ZIP CRC/content equality, licenses, metadata, SHA-256 sidecars/manifests and private-file exclusions |
| [Runtime 41675902414](https://github.com/2HIK4/Todorbit/actions/runs/41675902414) | FAIL before candidate upgrade, while capturing previous beta 7 UI: UIAutomator null root/missing XML; empty app crash buffer. Not a candidate runtime pass or proven app crash |
| Harness correction `4ce4d37` | Unique XML per capture prevents stale acceptance; transient command/parse failures retry within the original deadline. Assertions and deadlines unchanged |
| [Runtime 41677222187](https://github.com/2HIK4/Todorbit/actions/runs/41677222187) | PASS using identical immutable APKs, fixed harness. 16,384-byte page Android 16 x64 guest; stable no-app baseline 40s; actual production `adb install -r` code 30 to 31; retained synthetic task, completion/cold restart, no crash/ANR observed. Receipt and retained/completed screenshots inspected |
| Resume status/receipt inspection | Only own publication-document changes; runtime pass reused after user pause, no rebuild/repetition of passed application checks |
| `draft-gate.py` | PASS exact application source/body, prerelease draft, all 11 sizes/digests/exclusions, exact app-source Windows/Android CI and whitelisted harness-source runtime CI |
| `gh release edit ... --draft=false --latest=false` | PASS published reviewed draft, unchanged immutable x64 asset 706301801 |
| Initial `verify-public.py` | Stopped at missing saved C-temp package path after successful publication; no digest mismatch. Remaining temporary source/SDK/log files were also unavailable on resume; cause not established |
| `verify-public.py` adjusted for full anonymous download | PASS all five large packages downloaded fully and SHA-256 matched recorded build hashes; all six small assets fully fetched/hashed, Range delivery checked. Prior public releases/assets/tags unchanged, new tag exact source |
| First public updater test invocation | Stopped on missing anonymous JSON because download verification had not finished; test assertions were unchanged |
| `fetch-updater-inputs.py` then `flutter test --no-pub .buildlog/verify/smart-sync-beta8/public_updater_test.dart` | PASS one test using production parsers against anonymous public JSON: Windows installer/portable, Android ordered ABIs/universal fallback, code 30 to 31 and Stable exclusion. Rerun supplied the previously missing fixture; installed pinned SDK and existing D package configuration worked |
| `archive-small-assets.py` | Six small public assets additionally retained under the ignored package archive, with full byte/hash validation |
| `gh api .../releases/latest` | HTTP 404, consistent with no GitHub latest Stable release; beta 8 remains explicitly a prerelease and publication used `--latest=false` |
| Documentation/feature-catalog check and `git diff --check` | PASS changed-document links and feature catalog: zero errors; no whitespace errors. Documentation-only follow-up does not invalidate runtime/build gates |

Detailed retained machine receipts are under ignored
`.buildlog/verify/smart-sync-beta8/`: `artifact-audit.json`,
`draft-integrity.json`, `public-verification.json`, `runtime-02/receipt.json`
and its screenshots/XML. Public assets provide durable package bytes; the
original local build hashes match their downloaded bytes. Missing temporary
build logs are not represented as newly archived evidence. CI provides durable
exact-source analysis/test/build and runtime logs.

### Signing and compatibility

Android APKs retain the production certificate SHA-256
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
The actual signed x64 beta 7 to beta 8 in-place upgrade passed. ARM64 physical
phone upgrade remains unobserved. No debug signer or private AAB was published.
Windows packages are unsigned; verify SHA-256 before executing. No installer
was executed on the owner's account. Windows 10, physical shell/DPI/keyboard,
OEM Android, screen-reader and comprehensive acceptance remain incomplete.

Schema 26, sync protocol 1 and AES-256-GCM/causal history formats are unchanged.
Focused Smart Sync/encryption/backup evidence above remains applicable, and
fresh full Windows CI passed. No destructive owner-profile/Drive tests occurred.
Real Google Drive authentication/exchange remains pending independent end-to-end
verification; compilation and mocked coverage do not prove provider access.
Snapshot Backup and Sync stay independent. Preserve a verified external backup,
initially use disposable profiles/data, and retain the recovery code securely.
Do not uninstall to work around an Android signer mismatch or delete a profile.

### Public asset SHA-256

All 11 assets have matching recorded local build and GitHub digests; post-publication
anonymous full downloads also match. Checksums below refer to the exact published bytes.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `ANDROID-RELEASE-NOTES.md` | 2931 | `3a88c6bd9bbf232cdc8550d524e12241a53937113426f6555c47cb329ab05281` |
| `ANDROID-SHA256SUMS.txt` | 528 | `340e1d96280aea26edf8f164b32143a92fa80d15444b2e1d13f652ddfa06f512` |
| `Todorbit-1.0.19-beta.8-android-arm64.apk` | 26058651 | `31e5daecb1b6bf5bc5cec67ad17339890c328d03625f0c4ca9abc23eec51ccde` |
| `Todorbit-1.0.19-beta.8-android-universal.apk` | 52660823 | `9d81e6c8722da151d120f10c18d5e58596274c899b5c1b20595cec466ed232e6` |
| `Todorbit-1.0.19-beta.8-android-update.json` | 876 | `604ec69ec3cccc4449a9e0e8e4910bf667c23f2f4559a4427258bc7ef6e4412f` |
| `Todorbit-1.0.19-beta.8-android-x64.apk` | 27576631 | `c4d420c766008eaba8dbee6974499a448c942ff1d783e5e100acc357e2c29149` |
| `Todorbit-1.0.19-beta.8-SHA256SUMS.txt` | 219 | `c6b1afcd86fa52c6695cf4f272204b65731538bfe42e43ac35a7f1f2e1d706d7` |
| `Todorbit-1.0.19-beta.8-win-x64-portable.zip` | 63041817 | `f97279cf8765a859ee9c02ddd871be9bfec21dd774e0b37edb47eb5a168b8453` |
| `Todorbit-1.0.19-beta.8-win-x64-portable.zip.sha256` | 111 | `71f204abd3306777db2d4698c3d68a77f6ea024c23a0fc360527cc6e2bd45212` |
| `Todorbit-1.0.19-beta.8-win-x64-setup.exe` | 47664577 | `33dcc9ea0023cffdb28b83e6f8cce71e7bb1e7903730c45e87f341ae3e4a0438` |
| `Todorbit-1.0.19-beta.8-win-x64-setup.exe.sha256` | 108 | `007942fd4b2e686d635e73f96f83e64a6ac0113476fcdd1cd2969e3c2fcf9c24` |
