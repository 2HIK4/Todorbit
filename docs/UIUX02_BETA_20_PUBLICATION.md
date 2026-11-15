# UIUX-02 beta 20 publication receipt — 2026-11-15

**PUBLISHED experimental prerelease:** [v1.0.19-beta.20](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.20),
release ID `445908356`, published 2026-11-15 08:57:00 UTC / **11:57:00 UTC+03:00**.
Version `1.0.19-beta.20+43`, Android code 43, numeric Windows PE 1.0.19.43,
schema 28; prerelease=true, draft=false, latest=false. Stable is unchanged.

## Source and checkpoint

- Approved UIUX-02 checkpoint: `6d32ce83afae08df1f993eb748c35b7d9e5763d1`, parent
  `61bde1c54c01d6d3f55dbc8b9a4585712cdf9750`, on `codex/independent-beta-review`.
  All 24 original review source/config/test hashes matched before checkpointing.
  The exact 25-path staged set was reviewed for unrelated/generated/private data.
  Only mechanical blank-line cleanup changed the original review receipt.
- Published tag/release commit: **`6156613d8c9b47c2bec06a8329b1ff1ad9be5432`**.
  Windows CI and signed-artifact runtime use that exact commit.
- Signed APK was built from `ff96dcb5b82b15250e51b5200c5b85b11d1f9d12`.
  Every production/build input is identical at the published tag; subsequent
  qualification changes affect only tests and documentation. A Git diff over
  lib/android/windows/native/config/tools/installer/pubspec/lock/license confirmed
  equality, so no redundant third Android build was performed.
- Version commit `02a0785` synchronized Flutter/native metadata and notes.
  Qualification commit `ff96dcb` addressed strict baseline lint diagnostics;
  `6156613` repaired seven stale/font-dependent test fixtures. No production
  behavior change, dependency change, schema/Sync/key/account/profile migration,
  application/provider/installer/IPC rename, force push or old tag move occurred.
- No personal database, credentials or device profile was used. The three
  pre-existing unrelated untracked documents retain their original SHA-256s.
  Windows Drive stays disabled/empty; Android retains its existing configuration.
  Public license is unchanged. [Release notes](TODORBIT_BETA_20_RELEASE_NOTES.md).

## Assets and integrity

All ten assets were inspected in a private draft, with uploaded state, sizes and
GitHub SHA-256 digests matching local files before publication. Post-publication
anonymous release metadata and every asset HEAD returned HTTP 200. All seven
small notes/metadata/checksum files were downloaded and hashed; large binaries
were not redundantly downloaded after their upload digests matched.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [ANDROID-RELEASE-NOTES.md](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/ANDROID-RELEASE-NOTES.md) | 1967 | `95ef197547616a4c26a8a8b4522f98b8c6ba4384d7f9a680b53ba9b4856de0e8` |
| [ANDROID-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/ANDROID-SHA256SUMS.txt) | 316 | `4145b3274dd704924c7073bce3f5a14f9559fe6544084a03a53aa1557128ae95` |
| [Todorbit-1.0.19-beta.20-android-universal.apk](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-android-universal.apk) | 53776483 | `f7277b05048da30843eae18cb2b4a77543526e865c499b8052e819dd5ae8edf0` |
| [Todorbit-1.0.19-beta.20-android-universal.apk.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-android-universal.apk.sha256) | 113 | `6ea52816b05769ee48c9a743da733cd978d3f7ec7841543b74d0370b1139b62f` |
| [Todorbit-1.0.19-beta.20-android-update.json](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-android-update.json) | 421 | `269baf89bcd4fb92fc2773fc04f21152c67de8e9aecbc7f2c15ef7227b0f797c` |
| [Todorbit-1.0.19-beta.20-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-SHA256SUMS.txt) | 221 | `21d64446465d21804adbc4a4d697990a899d59632e9f42842c95fc29221af1bd` |
| [Todorbit-1.0.19-beta.20-win-x64-portable.zip](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-win-x64-portable.zip) | 65103193 | `205cfcb92347b66791fea8f303f465c8730a29cf6f437f7322a0f8ea32c2fbc1` |
| [Todorbit-1.0.19-beta.20-win-x64-portable.zip.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-win-x64-portable.zip.sha256) | 112 | `4ea1a7f5c9a180b3fdc5111fa77a84833799fb40c49936427d0b01f4e50fd5f0` |
| [Todorbit-1.0.19-beta.20-win-x64-setup.exe](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-win-x64-setup.exe) | 47802689 | `4b931f7e5381dd6911aba8e6a18c17fe084b313d7bddf961fb6c41d55ad079ab` |
| [Todorbit-1.0.19-beta.20-win-x64-setup.exe.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.20/Todorbit-1.0.19-beta.20-win-x64-setup.exe.sha256) | 109 | `5762921a5f0f117faaf1eec0c5daffc36103294d8b13ab445136921e95e032c2` |

The universal GitHub APK has arm64-v8a/x86_64 Flutter engines, minSdk 26,
targetSdk 36, package `io.github.hik4.todorbit`, code 43, non-debuggable release
configuration and unchanged widget providers. Binary manifest inspection confirms
SurfaceRefreshReceiver remains non-exported. All eight native libraries pass
ELF/APK ZIP alignment. `prepare-android-release.py --apk-only` verified signer,
package/version, ABI/minSdk, non-debuggable state and code monotonicity against
all published Android metadata. No Play AAB was requested or published.

Production certificate SHA-256 remains
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
The retained Beta 19 APK first matched its published digest
`dc014710dec8ca27bf9f8c975754732351de179dec15d9856748ff26e2467620`;
both APK signatures then matched that same production certificate. No key was
created/replaced and no signing material was disclosed or committed.

Windows packages remain **unsigned**. Both executables have numeric PE version
1.0.19.43 and product version 1.0.19-beta.20+43; the main executable's FileVersion
text also retains the semantic beta string, while the native companion's string
is numeric. Independent audit passed sidecars/manifests, full ZIP CRC/structure,
required native/runtime/license/helper files, private-file exclusions, normalized
license/helper source equality, and AOT/main/config receipt hashes. Microsoft CRT
signature/bundle checks passed. Installer and packaging scripts are unchanged
from Beta 19; Inno 7.1.0 preserves the existing AppId and beta display version.

## Executed verification and evidence reuse

Local logs/receipts are ignored under `.buildlog/uiux02-publication/`.
The reviewed UIUX-02 source/tests/renders and unaffected data/Sync/native evidence
were reused within the [original receipt's](UIUX02_CODEX_REVIEW_2026_11_15.md)
limits. No local full Flutter/JVM suite or full analyzer was repeated.

| Invocation / source | Actual result and necessity |
| --- | --- |
| Strict scoped analyze, calendar_view/task_editor | PASS, 10.9s; braces-only fixes for two previously recorded infos that would block strict Windows CI. |
| [Windows CI 43690416483](https://github.com/2HIK4/Todorbit/actions/runs/43690416483), `02a0785` | FAILED at full analysis: 17 infos/one unused local outside the prior scoped review; no tests/build. |
| `dart fix --apply --code=curly_braces_in_flow_control_structures,use_null_aware_elements,unnecessary_underscores,unused_local_variable`; six changed files reviewed | Applied mechanical syntax fixes; retained awaited fixture creation. Unrelated suggested flutter_driver production dependency was rejected/restored. No suppressions or CI weakening. |
| Strict scoped six-file repair analysis | PASS, zero issues, 8.6s. Four braces-only production diffs independently compared after whitespace/braces normalization. Initial equivalence probe used wrong Windows decoding; corrected UTF-8 comparison passed. |
| [Windows CI 43691060241](https://github.com/2HIK4/Todorbit/actions/runs/43691060241), `ff96dcb` | Full analysis PASS; 992 tests passed, 7 failed, 9 skipped. Packaging held; failure diagnostics retained. |
| Seven-case focused Flutter run over advanced_task_ui_quality, mobile_calendar_date_following, populated_ui_journeys, progressive_plan_widget and task_editor_ui_polish | PASS 7/7 in 60s after repairing stale series/plan button labels, overnight timeline assertion, SDK font loading and scroll-before-tap. Assertions remain active; overnight assertion additionally checks stored 23:00 start is preserved. No text-scale reduction. |
| Strict analysis of five changed fixture/helper files | PASS, zero issues, 13.7s. |
| [Final Windows CI 43693602896](https://github.com/2HIK4/Todorbit/actions/runs/43693602896), exact tag source | **PASS: 999 tests, 9 opt-in skips**, clean full analysis, development/helper/schema/configuration gates, Release build, CRT checks, portable build, native writer/background barriers, isolated native self-test, installer and checksums. This existing required packaging workflow includes its host suite; no duplicate local full run/build. |
| [Android validation 43690419404](https://github.com/2HIK4/Todorbit/actions/runs/43690419404), `02a0785` | Both host and isolated update integration jobs PASS. Reused for unchanged Android functional/assertion/dependency boundaries; subsequent production edits are reviewed lint syntax only. Not mislabeled as exact-tag CI. |
| `tools/build-android.ps1 -Mode Release -Distribution github`, initial/final | Initial `02a0785` build PASS, 289.2s, preserved intermediate; final production-source `ff96dcb` build PASS, 117.2s. Second build justified by the actual strict-CI qualification edits; no build after test-only qualification. Eight-library alignment PASS. Existing production configuration used. |
| `prepare-android-release.py --apk-only --version 1.0.19-beta.20 --version-code 43 ...`; signature/badging/binary manifest/private-entry checks | PASS; official production certificate, ID, code floor, names, receiver privacy, ABI/alignment and no private key/database entries. Private-file classifier checked with positive controls. |
| [Exact signed APK runtime 43694416334](https://github.com/2HIK4/Todorbit/actions/runs/43694416334) | PASS on API-36 x64, 16,384-byte pages, stable no-app baseline, Flutter render, task create/restart/complete, no observed crash/ANR. Actual production Beta 19/code 42 upgraded to code 43 and retained its task. Candidate asset ID 750329257; exact APK hash above. |
| Independent Windows package/PE/CRT audit | PASS. First checker incorrectly assumed both FileVersion text fields were numeric; inspected actual PE numeric parts and documented semantic main-string format, then corrected that checker. No artifact rebuild. |
| Existing prepare-windows-sandbox-acceptance tool plus private previous-version fixture extension | PASS in fresh WDAG identity: verified packages, actual Beta 19 installer → Beta 20, correct registration/path/version, byte-for-byte populated database/sentinel retention, separate installed/portable schema-28/54-table create/reopen/integrity, native packaged self-test, uninstall preserving data and successful reinstall. No credentials/profile mapped; GUI/OAuth remain UNVERIFIED. Extension retained original preservation assertions; only added prior installer and version checks. |
| Complete draft inspection, publication and anonymous verification | PASS, all ten uploaded asset hashes/sizes/names; source/tag/notes/classification checked before `gh release edit --draft=false --prerelease --latest=false`. Draft asset upload was awaited; early guards held publication while upload was incomplete. Private drafts were retrieved by ID after tag endpoint returned 404. |
| Live production updater service check | PASS, one combined network test (5s) with isolated APPDATA/LOCALAPPDATA. Windows setup/portable and Android ARM64/x64 offer Beta 20 from Beta 19, Android code/hash correct; Stable excludes it. No owner-profile installer run. |
| Existing release/tag preservation comparison | PASS, every prior public/draft release's tag/target/classification/notes/assets unchanged; every prior Git tag unchanged; only new Beta 20 added. No Stable release existed before and none was added. |

Final 16-KiB receipt: `.buildlog/uiux02-publication/runtime-evidence/receipt.json`.
Sandbox receipt: `.buildlog/uiux02-publication/windows-sandbox-result.json` and
`.buildlog/sandbox-acceptance-df0c3df32c0f444f8e238a8e54c9923a/results/acceptance.json`.
Package/public manifests: `final-assets.json`, `public-verification.json`,
`android-identity-continuity.json`, `windows-identities.json` and
`candidate-provenance.json` in the publication log directory. Failures were
retained and corrected; no passing result is inferred for an unexecuted check.

## User acceptance and remaining gaps

**Open Todorbit → Software Updates → Pre-release channel → Check for updates →
Download/Install the experimental beta.** Android uses the normal system approval
and reopen flow; no uninstall or manual APK replacement is required for an
existing production-signed install. The production discovery path is verified;
actual physical Update-button/OS installation interaction remains user acceptance.

Still pending: overnight physical Doze/reboot/clock-zone/widget refresh; installed
launcher widget IDs/configuration/navigation/alarm preservation; physical ARM64/
OEM and nonlinear large-text/IME/TalkBack/locale acceptance; affected Windows
pointer/keyboard/DPI/UI interactions and registered in-app handoff; remaining
product-wide audit coverage and real Google account/recovery journeys. Emulator
package/task preservation and Sandbox installer checks do not close those gaps.
[Deferred verification](DEFERRED_VERIFICATION.md) retains them explicitly.

## Skills, instructions and Git state

Applied AGENTS.md, CODEX_WORKFLOW.md, TESTING.md/test ledger, RELEASE.md,
ANDROID_RELEASE.md/ANDROID_UPDATES.md/SOFTWARE_UPDATES.md, reviewed UIUX-02 and
ARCH-01 provenance, Todorbit Engineering Quality (including Git Discipline and
resource/evidence rules), Regression and the specialized Dart static-analysis
skill. No separate Git/release skill was installed or new process introduced.
Previously loaded Ultimate UI/UX guidance remained applicable to fixture checks.

A documentation-only evidence commit follows publication; it does not change the
immutable tag/runtime inputs or invalidate package evidence. Tracked working tree
and index are clean after that checkpoint; only the three unrelated pre-existing
untracked documents remain. No builds/caches/secrets/machine-specific settings
were committed; local tool/environment paths in receipts are provenance only.

Final documentation validation: six changed release/tracking Markdown documents
passed the existing local-link/map/catalog checker (zero errors); staged diff/
whitespace, immutable tag and all three unrelated-file hashes were checked.
No product tests or builds were repeated for these documentation-only updates.
