# Android beta 2 — preparation and resolved publication hold, 2026-10-31

Candidate source `500a9a8a7c078f54dd79fa0f03aaa8f7cf4da596`, branch
`feature/android-mobile`. Version **1.0.19-beta.2 (25)** is synchronized with
native regression-build metadata. Published code floor was 23; retained private
validation builds used 24. New APKs/AAB were built from committed beta 2 source,
without overriding/reusing the code-24 validation artifacts.

**Published after the runtime gate passed.** The hold below is historical.
The unchanged candidate passed on a healthy official API-36 16 KiB Linux/KVM
environment in run `41218583203`. See the
[publication receipt](ANDROID_BETA_2_PUBLICATION.md) for public hashes and the
completed real beta 1 → beta 2 upgrade. No failed environment was counted as a pass.

## Continued investigation and verification ledger

The resumed task preserved the candidate's exact runtime source and all artifact
hashes. `ac9a884` permanently adds receipt review, evidence reuse, four risk levels
and per-invocation ledger requirements to AGENTS/Testing/Codex workflow guidance.
The artifact-only Linux/KVM acceptance harness is separate from packaged source;
no APK/AAB was rebuilt and no application fix was inferred from a guest crash.

Detailed per-invocation records are retained privately in
`.buildlog/android-beta2/verification/ledger.json`. The compact ledger below covers
new execution; the completed-check table below remains reused evidence.

| Invocation / purpose and coverage | Source / environment | Result | New or rerun / reason |
| --- | --- | --- | --- |
| Git/draft/artifact SHA-256 audit; establish resumed identity | Candidate `500a9a8`, `public-asset-audit.json` | Pass; unchanged local artifacts and draft target | New identity audit before reuse |
| `check-docs.py`, `git diff --check`; policy links/whitespace | Documentation changes | Pass | New; policy changed |
| No-app `Beta2Controlled16k` baseline; Android system stability | Emulator 35.3.11, official API-35 ps16k revision 5, WHPX, fresh 2 GB/2-core guest, software graphics, no snapshots | Fail: `PAGE_SIZE=16384`; system-server SIGSEGV before Todorbit installation | Rerun: remove old AVD/snapshot/app/concurrent-guest confounds |
| Official emulator download and size/SHA-1 verification | Isolated emulator 37.2.13, Google stable repository metadata | Pass; original SDK untouched | New diagnostic environment; later WHPX fixes documented |
| Stable emulator no-app launch | Same official image, fresh `Beta2Stable16k` | Initial launch required explicit SDK root; no runtime executed | Rerun: isolated executable path needs existing SDK root |
| Configured stable-emulator no-app baseline | Emulator 37.2.13/WHPX, 2 GB guest, no snapshots | Fail: System UI SIGSEGV, repeated low-memory kills | Rerun: correct tool launch; candidate still absent |
| Same no-app guest with `-memory 4096 -cores 4` | Emulator 37.2.13/WHPX, same API-35 image | Fail: native Google and System UI crashes | Rerun: remove observed guest memory-pressure confound; no new AVD/app |
| `py_compile tools/android-16k-runtime.py`, docs/diff checks | New artifact-only harness | Pass | New; validate harness syntax and documentation |
| Runtime workflow dispatch/bootstrap | Harness branch, candidate x64 hash unchanged | Dispatch initially unavailable before workflow registration; push registration used | New tooling setup; no application test executed |
| [Runtime job 41218074723](https://github.com/2HIK4/Todorbit/actions/runs/41218074723) | Existing draft APK, read-only integration token | Stopped at HTTP 403, before guest/test | New artifact-only job; GitHub draft visibility requires push access |
| [Runtime job 41218240895](https://github.com/2HIK4/Todorbit/actions/runs/41218240895) | Same APK, official API-35 16 KiB image, Linux/KVM, emulator 37.2.13 | Fail: system server restarted in 40-second baseline before app installation | Rerun: correct draft access; independent host platform |
| [Runtime job 41218583203](https://github.com/2HIK4/Todorbit/actions/runs/41218583203) | Same APK, official API-36 16 KiB image revision 7, Linux/KVM | Pass: healthy no-app baseline, render, SQLite/task restart and completion; no crash/ANR | Rerun: API-35 no-app failure reproduced across platforms; newer supported image, failure diagnostics preserved |
| Complete draft audit; remote sizes/digests/states | Same six public artifacts | Pass; all six uploaded, no private AAB/profile/key | New distribution audit after interrupted uploads completed |
| Anonymous public downloads, checksum/installed-signer audit | Same three published APKs; x64 downloaded by production app, ARM64/universal once on host | Pass; all five checksum entries and installed production signer | New mandatory public-distribution check; no repeated large fixture downloads |
| Public metadata ABI/channel test | Anonymous API + metadata, candidate parser | Pass: ARM64/x64/universal fallback, unsupported ABI, Stable and code gates | New public-discovery gate; focused test only |
| Actual public beta 1 updater → Android approval → beta 2, closed profile comparison | Populated production guest, exact public x64 APK | Pass; all 45 tables and existing attachment/backups/preferences/widgets preserved | Rerun required after publication; earlier private installer acceptance reused for prepublication |

Redundant broad Windows/Android jobs triggered by test-harness-only pushes were
canceled before their test suites. They are not claimed as passes. The actual
candidate's required exact-source CI remains the two successful `500a9a8` runs
below. Runtime-source equality against that commit was checked before reuse.
No Google OAuth, Sandbox or broad widget acceptance was repeated.

The no-app failures establish environmental instability independent of Todorbit.
They do not establish the exact internal emulator/image defect. Google documents
a [later WHPX guest-crash fix](https://developer.android.com/studio/releases/emulator)
than the original emulator, but newer-emulator and Linux results mean that fix
alone does not explain this case. Do not treat a causal hypothesis as a pass.

[Physical-phone installation, signing, download and backup checks](ANDROID_BETA_2_PHONE_TESTING.md)
are prepared. Beta 2 does not offer itself as an update: its Pause/Resume controls
can be exercised when a newer compatible official update is offered; the beta 1
to beta 2 path exercises the older downloader and actual installation.

## Historical blocker

The existing disposable API-35 x86-64 16 KiB guest `TodorbitProduction16k` accepted
the production-signed beta 2 x64 APK. It rendered a retained task; completion
persisted through force-stop/reopen. However, startup also produced system-server,
System UI, Google-process and Todorbit crash records. One Todorbit record reported
`CloneNotSupportedException: Class w2 doesn't implement Cloneable` in the Flutter
lifecycle path. The candidate R8 mapping ID matched the crash record.

A targeted cold boot with `-no-snapshot-load` also became unstable: system
processes failed, Todorbit recorded `DeadSystemException: The system died`,
UIAutomator exited 137 and `dumpsys activity` reported that the service was absent.
This is not evidence of a clean application runtime pass. System-wide failures
suggest an emulator/runtime problem, but the cause is **not established**, and
the earlier Todorbit lifecycle exception is not dismissed as harmless.

The 16 KiB ELF/ZIP and AAB configuration checks pass; they do not replace the
runtime gate in [Android release policy](ANDROID_RELEASE.md). Publication was
stopped without weakening that gate or claiming historical acceptance for this
candidate. Both test emulators were stopped, with their data retained.

Private evidence under `.buildlog/android-beta2/`:

- `runtime16k-existing-crash-buffer.log`: first-boot system/app failures.
- `runtime16k-cold-boot-crash.log`, `runtime16k-cold-after-launch.log`: cold-boot
  failures and DeadSystemException records.
- `runtime16k-reopen.xml`, `runtime16k-completed-reopen.xml`: observed render and
  completion persistence, which do not negate the crashes.
- `emulator16k*.log`, `emulator16k*-errors.log`: emulator startup diagnostics.

Next action: diagnose the retained guest/runtime failure or establish a healthy
supported 16 KiB test environment, investigate/reproduce the lifecycle exception,
and repeat only the unresolved runtime gate. If application source changes,
rebuild and rerun the checks invalidated by those changes, including exact-source CI.

## Completed checks

| Gate | Observed result |
| --- | --- |
| [Windows CI 41213677399](https://github.com/2HIK4/Todorbit/actions/runs/41213677399) | Passed on candidate source: full analysis, 451 host tests, one deliberate opt-in skip; Windows Release, packaged native self-test, installer/config gates |
| [Android CI 41213677390](https://github.com/2HIK4/Todorbit/actions/runs/41213677390) | Passed on candidate source: focused analysis, 71 host tests, 11 release-validator tests, artifact checks and two emulator integration tests |
| Local signed APKs | Fresh ARM64/x64/universal outputs; approved signer, package/version/code, non-debuggable, expected ABIs; 4/4/8 libraries pass 16 KiB ELF/applicable ZIP alignment |
| Local signing-policy JVM tests | Five passed; release-component flag required by AGP 9 was supplied |
| Private Play AAB | Signature/production certificate, ID/version, permission/provider separation, native alignment and 16 KiB bundle config passed |
| Final generated metadata | A focused test passed for ARM64 priority, x64 priority, universal fallback, unsupported ABI rejection, Stable exclusion and non-increasing-code rejection |
| Updater implementation regression | Prior 50-test focused evidence retained; final full CI includes the shared Range/pause/process-death/hash/recovery tests and decimal formatting/UI tests |
| Credentials/exclusions | 940 tracked/archive entries checked without printing secrets; no signing credentials or private fixture entry found in candidate archives |
| Preservation of existing releases | All 16 pre-session releases retain their identities, metadata and all asset IDs/names/sizes/digests/update timestamps, including beta 1 and Windows |

No Google OAuth, Windows Sandbox or broad widget acceptance was repeated. Native
Windows version metadata was synchronized for required CI builds; no Windows
release package was uploaded or published.

## Actual prepublication installation and data preservation

The retained populated guest `TodorbitRevisionAcceptance` began on production
beta 1 code 23. A private, emulator-guarded, same-signer instrumentation helper
called the **installed production native channel handler**, passing the exact
new x64 APK and final metadata. It did not modify the installed app, bypass
verification or run `adb install -r` for the application update.

Native `updateVerify` succeeded. Native `updateInstall` reverified the APK and
opened Android's actual **Do you want to update this app?** approval dialog.
Update was selected; Play Protect requested a scan. **Scan app** was selected,
and Play Protect reported **This app looks safe / You can continue to install it**.
Install was selected; the package became `1.0.19-beta.2`, code 25, and reopened.
The instrumentation process was terminated during package replacement and
reported `Process crashed`; that callback is not used as the success proof.
Package identity after replacement, reopening, and the independent profile
comparison establish the observed result.

Closed before/after exports passed SQLite integrity and equality of **all 45
tables**, stable task/event/resource IDs, the 41-byte managed attachment, both
existing backup files' bytes, appearance/updater preferences and widget IDs 2/3
configuration. Records and a task widget remained visible. Evidence includes
`profile-comparison.json`, `preinstall.xml`, `scan-progress.xml`,
`install-completed.xml`, and `beta2-reopen.xml` in the private evidence directory.

This was the prepublication native handler/system installer observation. Normal
public discovery/download/in-app installation was pending at that checkpoint;
it subsequently passed as recorded in the [publication receipt](ANDROID_BETA_2_PUBLICATION.md).
The retained `beta2-baseline23` snapshot supplied the baseline for that check.

## Final private artifacts and draft

All three APKs use package `io.github.hik4.todorbit`, version `1.0.19-beta.2`,
code **25**, and unchanged production certificate SHA-256:

```text
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
```

| APK | Exact bytes | Decimal size |
| --- | ---: | ---: |
| `Todorbit-1.0.19-beta.2-android-arm64.apk` | 25,533,723 | 25.53 MB |
| `Todorbit-1.0.19-beta.2-android-x64.apk` | 27,051,703 | 27.05 MB |
| `Todorbit-1.0.19-beta.2-android-universal.apk` | 51,611,607 | 51.61 MB |

APK SHA-256, in the same order:

```text
3cef87bcd4cbdcce08f6fbe14fa3b6a3d4d84a35c2516f9a30b27433377dfde8
7c348bc0286eb9c9134698426a9569d9f9a264063c559c196da5a4a2fdd42d74
aec2ce70779ed3194a4841d99ecec03f67483cb258895499e4e031c7b4d5ab6c
```

Update JSON SHA-256:
`369351f1aa352c6b8325ffe17f3f87c67ff98e956459ab6b92912924cff85ebc`.
The private Play AAB SHA-256 is
`8e5f7dec195b1d478c23ae936d92e902916d3b760502333eee4f8c835770a58f`.
The public staging checksum file lists only the three public APKs, metadata
and Markdown notes; the AAB is excluded from public staging.

GitHub draft release ID **430022327**, proposed tag `v1.0.19-beta.2`, points to
the exact candidate source and is marked pre-release/draft. Upload was interrupted
when the runtime blocker was confirmed. At the hold checkpoint only x64 APK,
metadata, Markdown notes and checksum file were fully uploaded; ARM64/universal
uploads are incomplete/absent. The draft **must not be published as-is**.
Use `draft-held.json` and local `public-asset-audit.json` to reconcile assets on
resume; verify every remote asset state, length and digest after completing upload.
No public beta 2 URL or anonymous-download verification existed at that hold.
The complete draft was later verified and published as recorded in the publication
receipt. Beta 1's tag/assets were preserved.

## Owner phone signing check

The actual phone's installed signer remains unmeasured. Follow the short
read-only APK extraction/certificate commands in
[update recovery](UPDATE_DOWNLOAD_RECOVERY.md#signing-diagnosis-and-owner-recovery).
Compare the certificate SHA-256 against the production value above.
`CN=Android Debug` with a different fingerprint identifies development signing;
never uninstall until external backups and recovery have been verified. Matching
production fingerprints support an ordinary same-signer update; retain any
different/unexpected-signer installation and contact the publisher.

Android screen lock/Doze/force-stop can interrupt execution; retained bytes are
resumed manually. Physical phone/OEM behavior, physical ARM64 16 KiB acceptance
and Windows/Android Drive interoperability remain unverified as already disclosed.
