# Android Drive and updater acceptance — 2026-10-30

Branch: `feature/android-mobile`, baseline `63965f5`. This continuation adds
uncommitted implementation/tests/docs on that branch; it does not publish or
move a release tag. Product version remains `1.0.18+19` in source. Development
update candidates override only the APK version code to 20.

## Implemented behavior

- Android Drive enabled by default, GIS account selection/pinning, identity-only
  secure storage, expiring/401 token recovery, reconnect/disconnect/switch and
  cancellation, denied-consent, Play-services and network errors. No client
  secret, new scope, account service, Firebase, backend or synchronization.
- Existing Windows/Android encrypted full/settings snapshot format, manifests,
  remote read-back checks, preview and recoverable staged replacement are reused.
  Linked external files remain outside portable attachment contents.
- Android Software Updates with actual installed name/code, channel, last check,
  date/size/Markdown notes, download/progress/cancel/retry, bounded app-private
  cache, SHA-256 verification, native APK signature/publisher/identity/code/SDK/ABI
  checks and user-approved Android installation/permission handling.
- Separate GitHub and Play native flavors. Play uses the official store listing
  flow and excludes install permission, update FileProvider and APK verifier.
- Protected, read-only Android candidate CI, durable-signing setup, monotonic
  published-code gate, APK/AAB identity/signature/native alignment and Play bundle
  checks, Markdown notes, checksums and update metadata. No publication action.

## Automated/build evidence

| Check | Result | Ignored local evidence |
| --- | --- | --- |
| Full Flutter suite | 403 pass, one intentional native-service skip | `.buildlog/android-drive-updates-full-tests.log` |
| Final focused Android auth/updater/UI | 24 pass, including cancellation during identity verification/storage, expiry, cleanup and large text | `.buildlog/android-updates-focused-latest.log` |
| Mobile settings/footer regression | 14 pass | `.buildlog/android-updates-mobile-version-tests.log` |
| Static analysis of lib/test/integration_test/test_driver | No issues | `.buildlog/android-updates-current-analysis.log` |
| Release version/source failure gates | Four Python tests pass | `python -m unittest discover -s tools -p test_prepare_android_release.py` |
| GitHub debug APK, code 19 | Build passes | `.buildlog/android-drive-updates-build-2.log` |
| GitHub debug APK, code 20, final product entry point | Build passes | `.buildlog/android-updates-final-phone-build.log` |
| Play debug AAB | Build passes | `.buildlog/android-updates-current-play-build.log` |
| Native alignment | Seven packaged libraries pass in APK and AAB | `tools/verify-android-artifact.py` |
| APK signer/integrity | APK Signature Scheme v2 verifies with local debug certificate | `.buildlog/android-updates-final-apk-signature.log` |
| Play AAB signature/configuration | JAR verifies; actual BundleConfig has PAGE_ALIGNMENT_16K | `.buildlog/android-updates-final-play-signature.log`, `android-updates-final-play-bundle-config.log` |
| Play exclusion | Actual merged manifest has no install permission/provider; actual DEX has neither APK verifier nor update-provider class | Local artifact inspection |
| Production gate | Rejects missing keystore; AAB verifier compiles and rejects debuggable bundles | `.buildlog/android-updates-release-signing-gate.log` |
| Windows Release, isolated checkout | Build passes | `.buildlog/android-updates-windows-release.log` |
| Packaged Windows native self-test | Exit 0 with private APPDATA/LOCALAPPDATA | `.buildlog/android-updates-native-selftest.log` |
| Workflow syntax/PowerShell | YAML and modified PowerShell scripts parse; no publication step | Local parser checks |

Full-suite coverage includes cloud upload/list/download/read-back, codec tampering,
wrong passphrase, all-table full backup recovery, interrupted/failed restore,
Before Restore retention, schema migrations and bidirectional snapshots across
separate desktop/mobile profiles. These establish format/data compatibility,
not authorized Drive access across two OAuth client registrations.

One manifest-merger conflict between attachment/update FileProviders was fixed
using a distinct GitHub provider class, then the APK rebuilt successfully.
UI harness fixes address asynchronous disk fixtures, lazy scrolling and the
deliberately animated busy state while a permission dialog is open. Final
focused tests pass; earlier failed attempts are not counted as passes.

## Device checks

Device validation uses the established disposable **TodorbitAndroidTest** API 35
x86-64 AVD (`emulator-5580`), with no personal account/profile. Its original files
and preferences were archived in `.buildlog/android-updates-original-test-profile.tar`
before same-certificate `install -r` instrumentation; no uninstall/data reset was
used. A separate fresh **TodorbitUpdateTest** AVD (`emulator-5582`) did not complete
Android service startup reliably and was stopped with its disk retained. Compiler
daemons are stopped before device work to reduce host disk/memory contention.
An earlier interrupted staging attempt is not counted as installation acceptance.

The combined integration runner and signed negative fixtures cover actual native
APK verification. The installation harness uses a local signed fixture for
discovery/download, while retaining the actual update screen, native verifier,
permission settings, FileProvider and system installer. It never publishes a
test release.

Observed on the final rerun: the mobile create/edit/complete/event/persistence/restore
workflow and native APK verification both pass. Native verification accepts the same-signer
candidate and rejects wrong package, signer, expected version/name, older code,
incompatible SDK/ABI, wrong checksum, tampered signed content and paths outside
the private cache. Evidence: `.buildlog/android-updates-final-device-integration.log`
and `android-updates-final-device-logcat.log` (two behavior tests plus
the framework teardown case).

Earlier reruns encountered emulator system ANRs, an empty transferred fixture and
a driver semantics teardown assertion. After verified fixture transfer and an
early connection to the current VM service, the final run reports all tests passed.

A first fixture transfer through Windows `adb shell` stopped at byte 0x1A and
produced a truncated APK. The native verifier rejected it. Subsequent stdin
transfers also proved unreliable for small fixtures. Both repeatable scripts now
use `adb push`, copy into the disposable app's private fixture directory, compare
device/host SHA-256 and remove the temporary staging file before running tests.
The test entry points also now delegate the native background callback to the
production implementation; the production entry point already had that callback.

The actual in-app installation sequence **passes** on that isolated AVD:

1. Same-debug-certificate acceptance app at version `1.0.18 (19)` opens the
   production application, creates a task and event through AppController, and
   saves dark appearance. Existing task/event/project/category data and two
   configured launcher widgets remain in place.
2. The real update screen loads a local candidate fixture, verifies it natively
   and offers Install Update. Its Markdown notes, version/code, size and status
   render correctly. Network discovery/transport is separately covered by mocks;
   this device fixture does not establish a published GitHub update.
3. The rationale opens Android's actual Install unknown apps screen. Returning
   with the switch off shows the permission-denial message and retains the APK.
4. Retrying, enabling the source and returning opens Android's actual update
   approval prompt via the production FileProvider. Cancel leaves code 19
   installed and displays the cancellation/retry status.
5. Retry opens the system prompt without another source-permission request.
   Approving Update installs the final product APK at code 20. Installed
   `base.apk` SHA-256 exactly matches the delivered candidate below. The old
   process disconnects, as expected; reopening MainActivity shows the normal
   product application with the preserved event and dark appearance.
6. Read-only checks of copied SQLite files report `integrity_check=ok` and exact
   row/column equality for both tasks, both events, both categories and the
   project, including stable IDs. Appearance JSON remains `theme=dark`; widget
   IDs 2/3 retain theme, opacity and filter values. No uninstall/reset is used.

Evidence: `.buildlog/android-updates-installed-package.txt`,
`android-updates-data-preservation.json`, before/after profile archives, and
screenshots `android-updates-permission-rationale.png`,
`android-updates-unknown-source-denied.png`, `android-updates-permission-denial-result.png`,
`android-updates-system-install-prompt.png`, `android-updates-install-canceled-result.png`
and `android-updates-relaunch-screen.png`. Android startup/system ANRs were
observed under this constrained emulator/host; Wait resumed the app, and the
completed installation/data checks above are separate from those interruptions.
The CLI harness now waits for the first rendered frame before interacting.
The relaunched product Software Updates screen displays `1.0.18`, build `20`,
GitHub distribution and the retained Stable selection. Its actual GitHub check
returns “No newer compatible Android update is available.” Evidence:
`android-updates-final-version-screen.png`, `android-updates-live-github-result.json`
and `android-updates-live-github-screen.png`. This does not prove downloading an
as-yet unpublished official Android release.
The post-update launcher Tasks widget visibly renders both preserved tasks;
`android-updates-final-home-screen.png` and `android-updates-final-appwidget.txt`
record the rendered widget and retained Tasks/Calendar provider registrations.
The owned test emulator was stopped after evidence capture, retaining its disk.

Live Dart diagnostics report no runtime errors and a hot reload succeeds after
attaching with the device VM port. An initial reload without an attached compiler
failed, and a host-forwarded port supplied as a device port could not attach;
these tooling attempts are not reported as successful reloads.

## Artifacts and external gates

Directory: `.buildlog/android-update-deliverables/`, with `SHA256SUMS.txt`.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Todorbit-1.0.18-20-github-debug.apk` | 148099424 | `c133d448b8dacce95f570593ef2883b88ca45086f6dee9861163c8dea38ce31a` |
| `Todorbit-1.0.18-19-github-debug.apk` | 148097936 | `1e421e4a4e5fc8926f2c21cdd46d3ab5a3244a71c61a85de2765cccc57090450` |
| `Todorbit-1.0.18-19-play-debug.aab` | 78467345 | `a4b1fa9133e1de16bc8336a4f9c4320ea68d4d293b6e1c5640beadc3a18d8a26` |

- `Todorbit-1.0.18-20-github-debug.apk`: current phone test candidate, package
  `io.github.hik4.todorbit`, version name `1.0.18`, code `20`, arm64-v8a/x86_64.
- `Todorbit-1.0.18-19-github-debug.apk`: development baseline.
- `Todorbit-1.0.18-19-play-debug.aab`: development-only Play variant verification;
  not directly installable and not a Play publication candidate.

All use the existing local debug identity. SHA-256 certificate:
`9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73`.
Actual debug SHA-1 was rechecked and matches
`64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`.

**Real Android OAuth is unverified.** Register the package/certificate in the
existing `todorbit` project using [the exact setup guide](ANDROID_GOOGLE_DRIVE.md).
No authorized Google test account was available here. Live Windows-to-Android
and Android-to-Windows Drive discovery/restore therefore remain unverified.

**Production signing is unavailable.** The owner must select/backup the durable
key and configure local credentials/protected CI secrets using
[the signing guide](ANDROID_RELEASE.md). No production identity was invented and
no production APK/AAB or public Android release was produced. Debug-to-production
signing transitions need exported verified backups and explicit manual choice;
the updater never uninstalls an app to resolve mismatch.

Physical phone/OEM/API 26/33/36, Play-less authorization, physical TalkBack,
16 KiB-page execution and first public-release/Play-track acceptance remain
external/manual gates. Remote CI configuration has not been pushed or executed.
