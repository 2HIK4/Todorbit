# Android finalization and developer workflow — 2026-10-30

Branch: `feature/android-mobile`. Recovered implementation: `3b8dcce`;
mechanical formatter baseline: `e19e8ea`; cloud-transfer safeguards: `d88161d`.
Developer workflow/build/test tooling: `b2b264e`.
Product source remains `1.0.18+19`, schema 22. Development update candidates
override only Android versionCode to 20. Nothing is merged or published.

## Development cost and workflow

Start in [Architecture map](ARCHITECTURE_MAP.md), choose a reviewed group from
`tools/dev/features.json`, preview `tools/dev/verify.ps1 -Mode Feature -Feature
<name> -Plan`, then run the smallest justified check. Quick requires explicit
files/tests. Full remains independent, with platform builds/device checks added
explicitly. [Workflow](CODEX_WORKFLOW.md) records the source-size audit and common
modification paths; [Testing](TESTING.md) owns commands and release gates.

No broad source rewrite or new dependency/DI framework. Added bounded command
logs and timing/source receipts, local Windows plugin-junction preparation,
proper native stderr/exit-code handling, repeat-build `-NoPub`, disposable-AVD
downgrade preflight and a Drive runner that retains the test installation.
APK/AAB/encrypted backup outputs are now ignored even outside build folders.
Android CI uses focused host checks; independent Windows CI still owns the full
host suite. Signed Android candidates require both, plus native/emulator checks.
Remote workflow execution remains pending; no changes were pushed.

| Observation | Measured result | Limits |
| --- | --- | --- |
| Baseline full-root analysis | 106.6 s wall / 100.7 s analyzer | Recovered source, warmed dependencies |
| Quick scoped analysis / six safety tests | 12.42 s / 12.22 s wall | Small explicit selection; initial Quick receipt |
| Feature Android updates | 32.81 s analysis / 26.76 s tests; 13 pass | Same source as Full, different load/cache state |
| Full scoped source analysis | 42.22 s wall / 27.5 s analyzer | Explicit lib/test/integration_test/test_driver roots |
| Full serial host suite | 532.57 s wall; 416 pass / one skip | Builds/emulator also active; not a controlled benchmark |
| Changed-source Android APK build | 267.28 s wall / 256.5 s Gradle | Host contention and daemon startup |
| Subsequent unchanged Android build | 20.3 s Gradle | Existing caches retained; demonstrates reuse, not a causal speedup |
| Windows Release | 145.53 s wall / 142.8 s Flutter | Local generated plugin junctions; no system setting change |
| Packaged native self-test | 5.9 s command wall, exit 0 | Fresh private APPDATA/LOCALAPPDATA |
| Full verification output | 1,021 suite-log lines; 28 helper-output lines | Full logs retained; no measured token-savings claim |

Clean Android build and feature-location wall times were not measured. Caches,
SDKs and user files were not moved/deleted to manufacture a baseline. Kotlin
incremental compilation remains disabled for the documented cross-drive issue.
CI remains the reproducible clean-build gate. These mixed-scope observations
must not be presented as a controlled before/after speedup.

## Google Drive

Code uses the existing project, `drive.appdata`, account pinning, shared
AES-256-GCM packages, read-back verification and staged restore. Added last
successful full transfer status, logical SQLite/portable-settings edit detection,
source platform and encryption details, changed/unknown-local-state warnings,
per-profile operation exclusion, pending-restore upload refusal and stale-review
checks through startup/final exclusive SQLite replacement. Before Restore remains
recoverable; each upload keeps a separate cloud version. No synchronization.

Automated format/transport/restore coverage passes, including bidirectional
isolated desktop/mobile profiles, encrypted packages, wrong passphrases,
tampering, interrupted restore, settings portability and preserved IDs/data.
New safety tests cover changes during upload/review/after scheduling, preference
changes, concurrency, failure cleanup, cancellation and successful reopen.

**Real OAuth, real cloud upload/download and Windows/Android cross-client
discovery remain unverified.** No authorized Google test account or Cloud Console
session was supplied. Same account/project registration is an acceptance
requirement, not proof that both clients see the same appDataFolder objects.
Use [exact Cloud instructions](ANDROID_GOOGLE_DRIVE.md); never widen scope or
expose snapshots publicly to bypass a registration/discovery problem.

Actual APK identity: `io.github.hik4.todorbit`, version `1.0.18 (20)`,
arm64-v8a/x86_64. Rechecked APK certificate SHA-1:
`64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`.
SHA-256: `9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73`.

## Android updater and signing

Settings provides channel/check, notes/size, progress/cancel/retry, native
verification and Android permission/installer integration. Tests cover stable /
pre-release / no compatible asset, offline/rate-limit failures, size/SHA-256,
package/code/name/SDK/ABI/signer, signed-content tampering and private-cache paths.
GitHub flavor owns APK installation; Play flavor owns the official store flow
and excludes installer permission/provider/verifier. Play Core acceptance awaits
an actual Play listing/test track.

Live official GitHub inspection found **15 published releases and zero Android
assets**. There is no published official Android update to discover/download.
Fixture-based device acceptance cannot establish that future public network path.
The unpublished signed-candidate workflow prepares distinct APK/AAB assets,
metadata, Markdown notes and checksums, and checks the published versionCode floor.
It never publishes. Actions artifact access follows repository permissions.

Production keystore/CI credentials remain unavailable. Missing signing is rejected
before build; no disposable production identity was invented. Follow
[signing/release instructions](ANDROID_RELEASE.md). Debug-to-production signer
mismatch normally prevents in-place upgrades: export and verify recovery first;
never automatically uninstall a data-bearing installation.

## Verification checkpoint

- Full Flutter suite: **416 pass, one intentional native-service skip**.
- Full source analysis and formatting: pass. Release Python tests: **4 pass**.
- Developer-helper tests: **8 pass**, including stderr warnings versus nonzero
  exits, explicit selection, invalid device guards and failure propagation.
- Quick and Feature modes execute successfully; Full host mode executes all tests
  independently. Documentation links, mapped paths and catalog validate.
- Windows Release and isolated packaged companion self-test: pass.
  Final native-output helper also rebuilds Windows successfully (108.9 s Flutter).
- GitHub debug APK: build, package/signer and seven native-library alignment checks pass.
- Latest disposable-device integration: mobile SQLite/UI/snapshot workflow and
  native APK verification pass (two behavior cases plus framework teardown).
  Actual in-app 19-to-20 rerun passes permission denial/recovery, installer
  cancellation/retry/approval, installation and product relaunch. Installed APK
  SHA-256 matches the candidate. Read-only comparison of all 45 SQLite tables
  finds no changed rows/columns; integrity is `ok`. Two tasks, one event, category
  and project retain stable IDs. Appearance/update preference JSON and widget
  IDs 5/6 retain dark/all/84% Tasks and light/80% Calendar settings. Retained
  backup files are preserved. No real cloud account/token was seeded, so this
  does not establish preservation or recovery of an authorized Google session.
  Both retained launcher widgets visibly render the preserved task/event content
  after product relaunch. Physical phone/OEM/API 26/33/36, TalkBack, 16 KiB-page
  runtime and Play-track behavior remain unobserved.
- Connected MCP analyzer did not return in the bounded attempt; clean CLI analysis
  is static-analysis evidence. Live hot reload/restart succeed; runtime diagnostics
  are clean after correcting acceptance-fixture setup.

Device evidence: `.buildlog/finalize-android-integration.log`,
`finalize-update-{seed,prepare,after-cancel}.log`, `finalize-before-install.tar`,
`finalize-after-install.tar`, `finalize-data-comparison/result.json` and
`finalize-widget-bindings-{before,after}.txt`. Actual system permission and
installer screens were observed; `adb install -r` was used only to deploy the
disposable baseline, never as a substitute for the observed approved update.

The first integration run used default Flutter Drive teardown, which uninstalled
its disposable app. The original test profile was already archived. The installed
SDK source confirmed this behavior; the local harness now explicitly uses
`--keep-app-running`, with a regression guard. Acceptance data and actual launcher
widget bindings were prepared again **before** the package-update comparison.
Fixture setup initially lacked transferred APK metadata after that teardown and
repeated seeding hit a unique category name. The fixture now seeds repeatably,
creates a verified before-install snapshot, and the corrected run passes. These
setup failures are not counted as acceptance passes or product-data loss.

Ignored evidence uses `.buildlog/finalize-*` and `.buildlog/verify/`; the full
host receipt is `20261030-115022-1274/result.json`. AVD `TodorbitAndroidTest`,
`emulator-5580`, API 35, was archived before testing to
`.buildlog/finalize-emulator-before.tar`. No personal profile/account is used.

Current development artifact:
`.buildlog/finalize-deliverables/Todorbit-1.0.18-20-github-debug.apk`, 186,005,971
bytes, SHA-256 `44323c62231ff109d37f773dd5dbb025968621582e9403d874b3901fa8c36c03`.
Incremental APK packaging contains unused ZIP padding; compressed entry contents
total 148,032,283 bytes. Signature/alignment pass; this is not a production asset.

## Owner actions

1. Existing Cloud project `todorbit`: verify the shipped Windows Desktop client,
   enable Drive API, register Android package + debug SHA-1 above, retain only
   `drive.appdata`, and add authorized test users if audience is Testing.
2. On a test phone, connect the same test account; prove Windows upload → Android
   list/decrypt/preview/restore, then Android upload → Windows restore. Check IDs,
   portable themes/settings and Before Restore; exercise denial/revoke/switch/offline.
3. Select and back up a durable production key outside Git; register its SHA-1,
   configure protected `android-signing` secrets/certificate pin, and rehearse
   recovery from a verified exported debug backup before changing signers.
4. Prepare an unpublished public-beta candidate with a higher shared version/code,
   full Windows + Android CI, signed APK/AAB and metadata/checksums. Complete phone,
   OEM/accessibility and 16 KiB-page acceptance. Publication needs separate approval.
5. After an approved compatible GitHub release exists, use Settings → Software
   Updates → Check → Download → Install and approve Android's system dialog.
   Valid same-signer upgrades preserve private data; recreate device-local state
   only after an explicitly chosen, verified signer-transition recovery.
