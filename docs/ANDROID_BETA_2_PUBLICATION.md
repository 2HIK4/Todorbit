# Android beta 2 publication receipt — 2026-10-31

Published **1.0.19-beta.2 (25)** as a GitHub **pre-release** at
**2026-10-31 16:18:52 UTC / 19:18:52 Asia/Amman**. This is not Stable or Play.

- [Public release](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.2)
- [ARM64 APK — 25.53 MB](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.2/Todorbit-1.0.19-beta.2-android-arm64.apk)
- [x86-64 APK — 27.05 MB](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.2/Todorbit-1.0.19-beta.2-android-x64.apk)
- [Universal APK — 51.61 MB](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.2/Todorbit-1.0.19-beta.2-android-universal.apk)
- [SHA-256 checksums](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.2/ANDROID-SHA256SUMS.txt)
- [Update metadata](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.2/Todorbit-1.0.19-beta.2-android-update.json)
- [Release notes](ANDROID_BETA_2_RELEASE_NOTES.md) and
  [physical-phone testing/signing/recovery guide](ANDROID_BETA_2_PHONE_TESTING.md).

## Immutable source and package identity

Release ID **430022327**, tag `v1.0.19-beta.2`, resolves to
`500a9a8a7c078f54dd79fa0f03aaa8f7cf4da596`. All APKs/AAB were built from this
committed candidate, using the existing production key. No code-24 validation
artifact was reused; no runtime source or binary changed during the later
environment investigation. Test-harness/documentation commits do not change the
tagged package source. No existing tag moved.

Package `io.github.hik4.todorbit`, version `1.0.19-beta.2`, common code **25**,
non-debuggable, minimum API 26, target API 36. APK signers match the approved
production SHA-256 certificate:

```text
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
```

| APK | Exact bytes | SHA-256 |
| --- | ---: | --- |
| ARM64 | 25,533,723 | `3cef87bcd4cbdcce08f6fbe14fa3b6a3d4d84a35c2516f9a30b27433377dfde8` |
| x86-64 | 27,051,703 | `7c348bc0286eb9c9134698426a9569d9f9a264063c559c196da5a4a2fdd42d74` |
| Universal | 51,611,607 | `aec2ce70779ed3194a4841d99ecec03f67483cb258895499e4e031c7b4d5ab6c` |

ARM64 is 50.4% smaller than beta 1's 51,529,687-byte universal APK. Metadata
selects ARM64/x64 according to ordered supported ABIs, with universal fallback;
all variants share code 25, preventing Flutter ABI version-code offsets.
Metadata SHA-256:
`369351f1aa352c6b8325ffe17f3f87c67ff98e956459ab6b92912924cff85ebc`.

Exactly six assets are public: three APKs, update JSON, Markdown notes and
checksums. All remote states/sizes/digests match staged files. Anonymous host
downloads of ARM64/universal/metadata/notes/checksums passed; production beta 1
downloaded x64 anonymously through its ordinary updater. The resulting installed
base APK was pulled read-only and matches the public x64 size/hash/certificate.
All five checksum entries verify. The AAB remains private validation material;
no signing credential, fixture, profile or private key was published.

## Runtime blocker resolution

The original API-35 16 KiB environment was unreliable independently of Todorbit:
fresh guests crashed before installation, including system-server/System UI
failures. This reproduced with old/current Windows emulators, after removing
snapshots/concurrent guests and increasing RAM, and on Linux/KVM with the same
API-35 image revision 5. The newer Windows emulator alone did not resolve it.

The exact candidate x64 APK passed in a healthy **official API-36 16 KiB image
revision 7**, Emulator **37.2.13**, Linux/KVM, 4 GB/four cores, software graphics,
fresh disposable data and no snapshots. Image fingerprint:

```text
google/sdk_gphone16k_x86_64/emu64xa16k:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys
```

[Artifact-only runtime run 41218583203](https://github.com/2HIK4/Todorbit/actions/runs/41218583203)
confirmed `PAGE_SIZE=16384`, a stable 40-second baseline with Todorbit absent,
then installed the hash-verified APK. Flutter rendered, a synthetic task was
created and retained through force-stop/restart, completion was exercised and
the reopened screen showed one of one tasks complete. No crash or Todorbit ANR
was observed. Screens/XML, crash/events logs and a hash-bound JSON receipt were
downloaded from the job's evidence artifact.

The failing environment is demonstrably not dependent on Todorbit. The precise
upstream image/emulator defect is **not established**; it is not attributed solely
to WHPX or memory pressure. No speculative application fix was made. Failed
guest results remain failures in the [investigation ledger](ANDROID_BETA_2_RELEASE_CHECKPOINT.md).
Static alignment checks were not substituted for runtime verification.

## Verification reused and newly executed

| Gate | Result and evidence |
| --- | --- |
| Exact candidate Windows CI | [41213677399](https://github.com/2HIK4/Todorbit/actions/runs/41213677399): 451 host tests, one intentional opt-in skip; full analysis, Windows Release/native self-test, package/config gates — reused |
| Exact candidate Android CI | [41213677390](https://github.com/2HIK4/Todorbit/actions/runs/41213677390): 71 host checks, two emulator integrations and 11 release-validator tests — reused |
| Signed artifacts | 4/4/8 native libraries pass ELF/applicable APK ZIP 16 KiB alignment; all identities/ABIs/signers/version codes, private AAB signature/provider separation/bundle configuration — reused; final files rehashed unchanged |
| Updater/signing regressions | Prior 50 focused checks and five JVM signing-policy checks remain valid; final candidate CI includes transfer/formatting tests — reused, no repeat full suite/build |
| Credential exclusions | 940 tracked/archive entries reviewed before publication; no private candidate content — reused for unchanged assets |
| Environment/runtime | Controlled no-app failures and the successful API-36 artifact runtime above — new targeted execution, with each rerun reason recorded |
| Public ABI/channel metadata | Focused test against anonymous public API/JSON passed: ARM64, x64, universal fallback, unsupported ABI, Stable exclusion and increasing code — new distribution gate |
| Public installation/preservation | Ordinary beta 1 discovery/download/native verification/system approval → installed code 25; all 45 tables and retained bytes/configuration identical — new required public check |
| Documentation | Testing policy, phone guide, ledger and publication links/whitespace checked; detailed logs ignored — new documentation validation |

The new manual artifact-runtime workflow/harness is narrowly scoped and does
not build Flutter or repeat host tests. Draft access needed push visibility;
the job has no signing key and makes no release/repository writes. Initial
workflow-registration/draft-access failures did not execute runtime tests and
are recorded separately. Redundant broad jobs triggered by harness-only pushes
were canceled before their test suites; they are not claimed as passes and do
not replace the successful exact-candidate CI above.

## Actual public beta 1 → beta 2 update

The retained production guest began on **beta 1 code 23** with synthetic task,
event, attachment, existing backups, preferences and launcher widgets. Its normal
Software Updates page excluded beta 2 on Stable, discovered beta 2 on Pre-release,
rendered real notes and selected the **27,051,703-byte x64 package**.

Download completed, the native verifier reported a verified update ready, and
**Install Update** opened Android's **Do you want to update this app?** dialog.
Update was approved; the installation became **1.0.19-beta.2 (25)** and reopened.
This used the actual public updater and system approval, not `adb install -r`
or a substituted release/transport. Beta 1's old screen still displayed MiB;
beta 2 contains the new decimal formatter and resumable downloader.

Closed before/after exports passed SQLite integrity and equality of **all 45
tables**, stable IDs, the 41-byte managed attachment, existing backup bytes,
appearance/updater preferences and widget IDs 2/3 configuration. The task widget
still rendered its record. Installed base APK hash and production certificate
matched the identical public x64 APK. Prepublication native installer approval
and Play Protect's safe scan are separately retained in the earlier checkpoint.

Private evidence stays under `.buildlog/android-beta2/verification/`, including
`ledger.json`, `linux-api36/receipt.json`, `public-final-receipt.json`, anonymous
downloads and `public-upgrade/profile-comparison.json`. Test emulators were
stopped with disposable data retained; no personal phone/Windows data was used.

## Remaining beta limits

Physical ARM64 16 KiB devices, physical lock/Doze/OEM launcher behavior and
TalkBack breadth remain unobserved/limited. Android may suspend or force-stop a
download; retained bytes resume manually. Beta 2 does not offer itself as an
update, so owner Pause/Resume testing needs a newer compatible official release.
The actual phone's installed signer remains unmeasured; use the read-only
[certificate and backup-first migration instructions](ANDROID_BETA_2_PHONE_TESTING.md).

Google Drive remains optional snapshot backup/restore, not synchronization.
Its production OAuth/codec/schema implementations are unchanged; previous
acceptance is retained without repeating account/destructive tests.
Windows/Android Drive discovery/restore remains explicitly owner-deferred; start
with disposable data and external backups, copying/relinking external files
separately. No new cloud/telemetry/account system or Play release was introduced.

All **16 pre-session releases** retain their metadata and asset IDs, names,
sizes, digests and update timestamps. Beta 1 and every Windows release are
unchanged. This Android release publishes no Windows package.
