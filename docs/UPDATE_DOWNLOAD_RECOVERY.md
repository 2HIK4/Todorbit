# Update download repair — 2026-10-31

Implementation commit `57d8d59`, unpublished on `feature/android-mobile`. The public
`v1.0.19-beta.1` tag, its assets, production certificate, package identity,
database, backups and Windows installation identities are unchanged.

## Measured package costs

Measured the actual public APK retained under the beta publication evidence and
the actual 1.0.18 Windows packages. A read-only GitHub API check matched their
sizes and SHA-256 metadata. Values below use decimal MB.

| Published artifact | Exact bytes | MB |
| --- | ---: | ---: |
| Android beta 1 universal APK | 51,529,687 | 51.53 |
| Windows 1.0.18 Setup | 47,243,956 | 47.24 |
| Windows 1.0.18 portable ZIP | 62,421,403 | 62.42 |

The APK is 49.14 MiB in binary units. Its ARM64 native entries occupy
24,506,744 bytes and x86-64 entries 25,970,200 bytes. Flutter engines account
for 24,799,288 bytes across the two architectures; compiled Dart `libapp.so`
accounts for 21,956,368 bytes. SQLite and Dart JNI are also needed per ABI.
Native libraries are stored uncompressed for direct Android loading and aligned
to 16 KiB; this is intentional. Compressed Flutter assets are 127,998 bytes and
fonts 126,677 bytes. The 257,628-byte Cupertino font is only 115,944 bytes in
the archive; removing it or other existing assets without auditing their users
would have little benefit and could break functionality.

The Windows portable ZIP contains a 118,667,487-byte self-contained .NET widget
executable (47,207,720 bytes compressed), Flutter DLL (8,844,995 compressed),
and compiled Dart (4,474,570 compressed). The widget intentionally carries its
runtime. Setup uses solid LZMA2; portable uses optimal ZIP compression. No large
duplicate payload was identified. The updater selects **one** package according
to installed versus portable mode; it does not download both.
An entry-content hash scan found only a small duplicated framework shader in
Windows; Android also has tiny identical dependency metadata/resources. These
have distinct runtime paths and are not a meaningful safe size reduction.

Both platforms replace complete packages, so even a one-line fix downloads the
runtime and application together. Flutter already uses release AOT, R8/resource
shrinking and icon tree shaking. No speculative shrinker, native compression,
runtime removal or Windows packaging change was applied.

## ABI packages

`tools/build-android.ps1 -Mode Release -Distribution github -SplitPerAbi` prepares
ARM64, x86-64 and universal APKs in one Gradle build. The universal fallback is
retained. `force-version-code-ignoring-abi=true` deliberately prevents Flutter's
`ABI * 1000 + buildNumber` offsets: all variants must have the **same** release
version code, greater than all previously published codes. Each next release
must advance this common code, including when changing channel or package ABI.

`prepare-android-release.py` accepts optional `--arm64-apk` and `--x64-apk` beside
the mandatory universal APK/AAB. Every variant is checked independently for
production signer, identical package/version/code, exact ABI set, minimum SDK
and native alignment before inclusion in update metadata/checksums. The signed
candidate workflow includes these outputs. No release was published.

Discovery uses Android's ordered `SUPPORTED_ABIS`, preferring the smallest
verified compatible asset for the first supported ABI; metadata order cannot
force universal downloads. Existing universal-only metadata still works.
Native verification checks the actual APK architecture before installation.

The private production-signed validation build (same version name, overridden
code 24, **not a release candidate for publication**) measured:

| Validation APK | Exact bytes | MB | Reduction from public beta 1 |
| --- | ---: | ---: | ---: |
| ARM64 | 25,533,723 | 25.53 | 50.4% |
| x86-64 | 27,051,703 | 27.05 | 47.5% |
| Universal fallback | 51,611,607 | 51.61 | 0.16% larger |

All three have code 24, package `io.github.hik4.todorbit`, the approved
production certificate and exactly their expected ABI sets. Their 4/4/8 native
libraries pass ELF and uncompressed APK ZIP 16 KiB alignment. Split builds
explicitly exclude dependency-only 32-bit JNI entries from the universal
fallback; the unchanged artifact gate caught that packaging defect before the
correction. The extra updater code makes universal slightly larger; savings
come from delivering the appropriate architecture. No compressed native-load
or engine changes were made. Measurements/digests are retained privately in
`.buildlog/updater-package-measurements.json`.

## Persistent transfers and UI

`ResumableUpdateDownload` is shared by both updaters. `.part` bytes and atomic
`.part.json` metadata bind the original official URL, version/code, expected
length and verified release SHA-256. File length is the persisted byte count
and remains authoritative after process death; no stored percentage is trusted.
The selected release is remembered privately so reopening the screen, including
offline after an app restart, restores progress. Completed packages are hashed
again before returning to Ready to install. Android additionally runs native
verification before enabling Install and repeats it at installation.

Pause closes the transfer and retains bytes. Discard explicitly removes partial
transfer files. Navigation pauses an active transfer and the next screen
instance restores it. Connection errors/timeouts preserve partial bytes.
Corrupt completed content fails the full hash and its partial bytes are removed.
Partial files are never installer inputs.

Resume requests the original release URL (fresh redirect resolution), sends
`Range` and strong ETag/Last-Modified `If-Range` when available, and validates
206 start/end/total and validators before appending. A full 200 response
truncates rather than appends and visibly explains the restart. An incomplete
416 response is retained with a Discard/retry explanation; a fully downloaded
partial is verified/promoted locally before requesting anything. Changed
metadata never reuses a different asset's prefix. Missing validators still
require the exact bound digest over the entire completed package.

A one-byte live probe of the public beta asset returned 206,
`Content-Range: bytes 0-0/51529687`, ETag and Accept-Ranges. Basic transfer tests
use local fixtures rather than repeatedly fetching APKs.

Both screens show decimal B/KB/MB/GB/TB (1000 per step), at most one fractional
digit, no trailing `.0`, downloaded/total, percent and measured average speed
after a one-second sample. Examples: `756 KB`, `18.6 MB / 51.5 MB`, `2.4 MB/s`.
Checksums and progress calculations retain exact integer bytes.

Android files moved from evictable cache to private `files/update-apks`; app
backup remains disabled and the update FileProvider exposes only that directory.
Startup no longer deletes retained partials after seven days. Explicit Discard
is available for partial downloads. Windows uses the active profile's existing
`updates/<tag>` directory.

The Android implementation is a persisted, user-resumed HTTP transfer. Android
DownloadManager supports system retries, but its public API has no user-controlled
Pause/Resume pair; remove cancels and removes state. See the
[DownloadManager API](https://developer.android.com/reference/android/app/DownloadManager).
No foreground service, worker, wake lock or new notification permission was added.
Screen lock/Doze/background suspension or force-stop **can interrupt progress**;
the operation is not promised to continue in the background. Reopen Todorbit
and tap Resume. Normal process termination preserves stored bytes. Physical
phone lock/OEM behavior remains a next-beta acceptance check.

## Signing diagnosis and owner recovery

The reported old error is produced only when verified APK signer hashes differ
from the installed signer set. The actual phone is unavailable: its signer has
**not** been measured, so debug signing is a hypothesis, not a confirmed cause.
The public beta APK's known production SHA-256 certificate is:

```text
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
```

The verifier now reads current APK signers with `GET_SIGNING_CERTIFICATES` on
API 28+, retaining the API 26/27 fallback. Release builds require the approved
production publisher and installed-signer equality. Only debuggable builds can
accept same-signer development fixtures. APK cryptographic verification is
still required first. Errors distinguish damaged signature/hash, wrong package,
untrusted candidate publisher, development-to-production incompatibility,
unexpected installed publisher, version/SDK and architecture errors. There is
no signature bypass, uninstall action, database write or data reset.

Use Android SDK platform-tools/build-tools for these **read-only device checks**
from PowerShell; select the phone's serial explicitly if multiple devices exist:

```powershell
adb devices -l
$phone = '<phone-serial>'
adb -s $phone shell dumpsys package io.github.hik4.todorbit |
  Select-String 'versionCode=|versionName='
adb -s $phone shell getprop ro.product.cpu.abilist
$diagnosticRoot = Join-Path $env:TEMP ('todorbit-signing-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $diagnosticRoot | Out-Null
$packagePaths = @(adb -s $phone shell pm path io.github.hik4.todorbit)
$baseApk = ($packagePaths | Where-Object { $_ -match '/base.apk$' } | Select-Object -First 1)
if (!$baseApk) { throw 'Installed base APK was not found; stop here.' }
adb -s $phone pull $baseApk.Trim().Substring(8) (Join-Path $diagnosticRoot 'installed.apk')
apksigner verify --verbose --print-certs (Join-Path $diagnosticRoot 'installed.apk')
# Run this separately against the exact update APK saved on your computer:
apksigner verify --verbose --print-certs '<downloaded-update.apk>'
Get-FileHash -Algorithm SHA256 '<downloaded-update.apk>'
```

Compare **certificate SHA-256**, not the APK file hash. `CN=Android Debug` with
a different hash establishes the development-certificate case. A different
publisher cannot ordinarily update in place to production. Keep the installed
app until an external full snapshot, portable settings and attachments have
been copied and restoration verified on a disposable installation. Only the
owner may then deliberately replace the app and restore. Follow
[the existing migration procedure](ANDROID_PHONE_BETA_TESTING.md), step 2.
Uninstall erases private data; it is never an automatic repair.

If both certificate hashes equal production yet the error repeats, retain both
APKs/version codes and report the non-secret diagnostics. A debug migration
would not fix that case. There is no evidence yet that the phone has such a
same-production-signer failure.

## Validation and next release

Focused local fixture tests cover Range/If-Range, pause/new-service resume,
real child-process termination, ignored Range, changed validator/size/range,
416/503, corrupt prefix, asset binding and final SHA-256. Adapter tests cover
offline release/progress recovery and complete-package reuse. UI tests cover
compact layouts, large text, decimal retained progress and partial-install
exclusion. JVM signing tests exercise production match, development migration,
untrusted publisher and debug-fixture restrictions. Candidate-validator tests
reject ABI offsets, wrong ABI and wrong signer.

The final Feature updater pass passed 50 host tests, targeted analysis of 16
paths, formatting and 11 Python release-validator tests. Its receipt/logs are
ignored under `.buildlog/verify/20261031-173959-9477/`. No full host suite,
Drive OAuth, recurrence/database acceptance or widget acceptance was repeated.
Live hot reload was attempted through Dart MCP; the IDE's DTD had no running
app connection, so UI evidence is widget-test rendering rather than a live
Flutter debug session.
Developer-helper tests also passed (8); documentation links/catalog validation
reported zero errors. Native signing tests are included in the signed-candidate
workflow. Run `:app:testGithubReleaseUnitTest` with
`-Pandroid.onlyEnableUnitTestForTheTestedBuildType=false` to enable the release
unit-test component under this project's
[AGP 9 default](https://developer.android.com/build/releases/agp-9-0-0-release-notes).
All five JVM signing tests passed with no failures/errors/skips; the native
receipt is `.buildlog/updater-native-tests.log` and the XML result is under
`build/app/test-results/testGithubReleaseUnitTest/`. The signed APK build and
its three alignment checks passed in `.buildlog/updater-android-build.log`.
Local setup used the existing Visual Studio CMake/Ninja PATH. Earlier failed
configuration/toolchain and pre-correction universal outputs are superseded by
these measured, validated APKs. No failed output is a publication candidate.

The installed public beta on the disposable production test emulator was pulled
read-only and verified with `apksigner`: one signer, APK v2, the approved
production certificate. Android's package manager accepted its in-place
universal-code-23 to x86-64-code-24 update (`adb install -r`, Success), retaining
the original first-install timestamp. This establishes same-signer package
compatibility; it is not an in-app installer-approval or populated-data audit.
The emulator initially reported a System UI startup ANR while the host was
building, so no physical/GUI acceptance claim is made from that boot.
The test emulator was stopped afterward with its disposable installation retained.

Physical Android lock/background behavior, physical ARM64 installation, OEMs and
the actual phone certificate remain unobserved. Host fixtures/JVM tests do not
establish those behaviors. No Windows native runner/helper/widget code changed;
Windows host updater checks are the relevant regression boundary. Full
publication CI, private signed AAB checks, actual installer approval and the
existing release gates remain mandatory for the next beta. Give that beta a new
version/name/code; do not publish the private build-number-24 validation files
under the old beta tag.

Future differential updates could save substantial runtime bytes, especially
the stable .NET widget and Flutter engines. They require authenticated base and
target manifests, exact base hashes, authenticated patches, free-space checks,
atomic staging, interrupted-patch recovery, rollback and full-package fallback.
Final package hashes/signers must still be verified. That infrastructure is
deferred; no delta protocol was introduced here.
