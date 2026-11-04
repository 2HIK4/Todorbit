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


## Candidate artifact checkpoint

Candidate/tag application source: `ed230954f498843dee9d895c4cba2316903bdc02`.
Application logic remains exactly `06b9ded`; only version metadata and the narrow
APK-only release-helper capability changed. No original cleanup document is staged.

| Invocation / purpose | Actual outcome / evidence / reuse |
| --- | --- |
| 2026-11-04T03:00:46.4898547+03:00 `build-windows.ps1` -> `tools/build-windows-release.ps1`, `installer/build-installer.ps1 -Compiler <existing Inno7>`, `tools/build-portable.ps1 -OutputDirectory <task/core-packages>` | PASS first Windows Release, exact beta10+33 main/native versions, configured OAuth/CRT gates, Setup and portable packaging. Core numeric filenames are moved to the established full-prerelease updater names. Existing local core installer/config bytes restored; `logs/windows-build-package.log`, `windows-result.json`. |
| 2026-11-04T03:03:44+03:00 `python .buildlog/verify/smart-sync-beta10/audit-artifacts.py --windows-only` | PASS 28 bundle files, exact ZIP membership/content/CRC (one read pass), licenses, five explicit Windows artifacts and sidecars/manifests. `artifact-audit-windows.json`; this valid audit will be reused after Android completes, without repeating ZIP work. |
| `git diff --exit-code a69dd63 -- installer/life_manager.iss lib/data/profile_paths.dart lib/data/app_database.dart android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml`; release-branch remote lookup | PASS unchanged installer AppId/profile storage/schema/package/signing behavior; release branch absent remotely. Reuse prior actual beta8->beta9 upgrade evidence only for these unchanged boundaries. Current physical upgrade not claimed. |

| 2026-11-04T03:04:20.6096285+03:00 `build-android.ps1` -> `tools/build-android.ps1 -Mode Release -Distribution github -GoogleDrive` with existing JDK/SDK/C Gradle cache; `tools/prepare-android-release.py --apk <universal> --apk-only --version 1.0.19-beta.10 --version-code 33 --certificate-sha256 <existing public production digest> --notes docs/SMART_SYNC_BETA_10_RELEASE_NOTES.md --output <task/packages>` | PASS first APK build, 184.5s Gradle, 50.3 MB; eight native libraries aligned. Preparer passes signature/nondebuggable/package/version/code/ABI/minSDK checks and code 33 exceeds all published stable/prerelease Android metadata. One universal APK only, no AAB/splits. `logs/android-build-prepare.log`, `android-result.json`. |
| 2026-11-04T03:05:57+03:00 `python .buildlog/verify/smart-sync-beta10/finish-artifact-audit.py` | PASS nine explicit assets; reuse unchanged Windows ZIP audit, check Android metadata/manifest/hash/notes and original storage/OAuth/signing bytes. Candidate application inputs match commit. `artifact-audit.json`, `logs/final-artifact-audit.log`. |

| Release branch/tag push and `gh release create v1.0.19-beta.10 --draft --prerelease --verify-tag --target ed23095... --latest=false --notes-file docs/SMART_SYNC_BETA_10_RELEASE_NOTES.md <nine audited asset paths>` | PASS upload; draft ID `433354192`. Initial raw `gh api .../releases/tags/v1.0.19-beta.10` lookup failed HTTP 404 for unpublished draft (including a progress diagnostic). Authenticated release-list/ID lookup found the draft; no upload/build was repeated. |
| `gh api repos/2HIK4/Todorbit/releases/433354192` draft integrity gate | PASS exact candidate/tag, draft=true, prerelease=true, nine uploaded asset sizes and GitHub SHA-256 digests match. `draft-release.json`, `draft-gate.json`. |
| `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded --timeout=2m .buildlog/verify/smart-sync-beta10/updater_candidate_test.dart` (first run) | FAIL one case: fixture changed draft status/date but left GitHub's temporary `untagged-*` draft URLs. Production Windows updater correctly rejected noncanonical release URLs. Corrected only the publication preview fixture; exact public URLs will be checked against this projection after publication. `logs/updater-candidate.log`. |

| 2026-11-04T03:12:35+03:00 updater candidate corrected rerun (same single test command; canonical published URLs projected for private draft) | PASS one grouped case: Windows installed/portable beta9->beta10 names, size/digest/version selection, current-version exclusion; Android code32->33 universal ARM64/x64; Stable excludes beta10. No source changes. `logs/updater-candidate-corrected.log`. Public verification will require these exact canonical URLs and identical tested asset identities. |


## Published outcome

Published **[v1.0.19-beta.10](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.10)**,
experimental/pre-release, version `1.0.19-beta.10+33`, source/tag
`ed230954f498843dee9d895c4cba2316903bdc02`, release ID `433354192`.
Publication uses an explicit PATCH of this new release ID with `draft=false`,
`prerelease=true`, `make_latest="false"`. No previous release was edited.

| Final invocation / purpose | Actual result / limits |
| --- | --- |
| `gh api --method PATCH repos/2HIK4/Todorbit/releases/433354192 --input <publish-request.json>` | PASS published exact-source tag, prerelease=true, latest=false requested, all nine assets. `published-release.json`. Explicit owner authorization; no stable release or unrelated branch change. |
| `python -u .buildlog/verify/smart-sync-beta10/verify-public.py` | All nine anonymous full downloads, byte counts and SHA-256 comparisons PASS; three binary Range requests match the downloaded first 1024 bytes. Aggregate later FAILS at line 60 comparing a historical beta9 body. `logs/public-verification.log`, exact original verifier retained as `verify-public-first.py`. This is not a failed transfer or application test. |
| Focused historical-body diagnosis: compare original authenticated CLI snapshot with anonymous API and exact Unicode codepoints | PASS cause: original `gh` subprocess text capture used Windows CP1252 for UTF-8 JSON, producing mojibake for an em dash. Correct UTF-8 round-trip restores exact old bodies; all prior `updated_at` timestamps match. Original snapshot retained; decoded comparison saved separately. No old notes were changed. |
| Final metadata/history/tag completion using retained public API snapshot and `git ls-remote --tags origin` | PASS canonical published URLs equal updater-tested projections; identical asset IDs/names/state/size/digests. Correctly decoded previous public release fields/assets and every old tag unchanged; new tag points exactly to candidate. `public-verification.json`. Reuse completed first-run transfer assertions (code/trace retained), so no binary is downloaded twice. |

Published at `2026-11-04T00:12:34Z` (UTC). Final public verification
recorded `2026-11-04T03:16:05.239501+03:00`. All download requests used no authentication.
No application suite, broad CI, emulator, real Google Drive, physical installer
or phone update was run. The failed preview fixture and failed historical-text
comparison above remain recorded; no unexecuted acceptance is called a pass.

## Public assets and checksums

| Asset | Bytes | SHA-256 |
| --- | --- | --- |
| [ANDROID-RELEASE-NOTES.md](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/ANDROID-RELEASE-NOTES.md) | 4413 | `9d0ea26f1f940b599ffcbc4c6adddc92e7802a825f46676cb805bdcd84228343` |
| [ANDROID-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/ANDROID-SHA256SUMS.txt) | 316 | `027e84cc8c9ae38f67c58ce3c2a43bc7cfa18baa6a544cac15dcbcf9d32bf233` |
| [Todorbit-1.0.19-beta.10-android-universal.apk](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-android-universal.apk) | 52726595 | `c426c31396a525cbab46f8e2111297557e3b33d641b49f111177ae35595b5f6e` |
| [Todorbit-1.0.19-beta.10-android-update.json](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-android-update.json) | 421 | `6ca383eb8c681a2aefcb4132d438d1a61c1a15258168bb0c9996f3cb65f88102` |
| [Todorbit-1.0.19-beta.10-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-SHA256SUMS.txt) | 221 | `5fe3320c6ce97f8343d4733a2c46798dd3ef6dc7dbaa1d52511dc255fce84579` |
| [Todorbit-1.0.19-beta.10-win-x64-portable.zip](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-win-x64-portable.zip) | 63062430 | `4898306c6a38d2fc4c90d71a3c76cb805ca6a791069f52211846df1a30a779cb` |
| [Todorbit-1.0.19-beta.10-win-x64-portable.zip.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-win-x64-portable.zip.sha256) | 112 | `4152b49dbe7d663b44479612206227b70c7631862bdb79627a40216107da11ea` |
| [Todorbit-1.0.19-beta.10-win-x64-setup.exe](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-win-x64-setup.exe) | 47672121 | `230319c059d1ca237f4c7fc0b34795fc3669b4202edd97b599eccbedc0474e2d` |
| [Todorbit-1.0.19-beta.10-win-x64-setup.exe.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.10/Todorbit-1.0.19-beta.10-win-x64-setup.exe.sha256) | 109 | `aec72688010d45a64b9bae9beab8fca3c4c2e171bcf4333896995b4d0212e487` |

Windows packages remain unsigned; the Windows digest sidecars/versioned manifest
and GitHub asset digests agree. The Android universal APK is production signed,
package `io.github.hik4.todorbit`, code 33, Android API26+, ARM64/x64; published
metadata/notes/checksums match the locally verified preparer output.

## Upgrade instructions and acceptance boundary

- Windows: back up first. Settings > Software Updates > **Pre-release** > check,
  download, install. Installed mode selects Setup; portable selects ZIP. Keep the
  same Windows account and installation/portable directory. Confirm its existing
  profile after reopening. Direct Setup/ZIP links above are available if needed.
- Android GitHub edition: back up first. Settings > Software Updates >
  **Pre-release** > check > Download Update > Install Update; grant the source
  permission if requested and approve Android's installer, then reopen. A recent
  check may be cached for about ten minutes. The universal APK above is also a
  direct in-place update for a compatible production-signed installation.
- Do not uninstall, clear data or force a downgrade on signature/version errors.
  A debug-signed or different-store installation may not accept this certificate.
  Play flavor has a separate store flow; this release contains no AAB.
- Production updater selection was tested once successfully against the exact
  draft asset identities projected to published classification/date/canonical URLs;
  actual anonymous published inputs were then matched to that projection. Stable
  excludes this release. Physical download/install permission prompts, registered
  Windows upgrade/restart and real phone data retention for beta10 remain unobserved.
- Real Google Drive exchange is **NOT VERIFIED**. Use the detailed disposable-data
  checklist in [manual build acceptance](SYNC_MANUAL_BUILDS.md). Existing encrypted
  recovery remains compatible; Standard/private conversion and cloud passphrase
  changes remain unavailable. Backups are independent; no cloud mutation occurred.

Application implementation is `06b9ded`; release metadata/tooling commit is
`ed23095`. Publication documentation is committed separately without moving the
release tag. Original `docs/DEVELOPMENT.md`, `docs/STORAGE_CLEANUP_2026_11_04.md`
and `docs/STORAGE_MAINTENANCE.md` remain uncommitted and untouched. No merge to
main, website deployment, extra APK variant, AAB or unrelated release mutation.

Final documentation gate 2026-11-04T03:17:56+03:00: `python tools/dev/check-docs.py` on the six final release/ledger documents reports zero errors; `git diff --check` passes. Final ownership hash comparison confirms all three original storage documents plus original OAuth/signing properties are unchanged. These documentation/ownership checks do not rerun application tests. Final docs are committed/pushed on the release branch with `[skip ci]`; the existing release tag remains pinned to `ed23095`.
