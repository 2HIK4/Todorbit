# Android software updates

**Settings > Software Updates** displays the installed package's actual version
name and version code, distribution, channel, last successful check, available
version/date/size, Markdown notes, download progress and installation status.
Checks are user initiated. Stable excludes prereleases; Pre-release includes
stable and experimental releases. A higher Android version code is mandatory;
semantic-version downgrades are excluded too. A newer code under the same version
name is supported. Windows updater selection and installation are unchanged.

## Official release contract

Only published, non-draft releases from `2HIK4/Todorbit` are inspected. Windows-only
releases are ignored. Android candidates need both APK and metadata GitHub assets,
each with GitHub's `sha256:` asset digest and an exact official download path.
Release metadata is independently named:

```json
{
  "formatVersion": 1,
  "packageName": "io.github.hik4.todorbit",
  "versionName": "1.0.19",
  "versionCode": 20,
  "minSdk": 26,
  "apks": [{
    "name": "Todorbit-1.0.19-android-universal.apk",
    "abis": ["arm64-v8a", "x86_64"],
    "size": 12345678,
    "sha256": "<64 lowercase hexadecimal characters>"
  }]
}
```

For tag `v1.0.19`, this is `Todorbit-1.0.19-android-update.json`.
Names `android-arm64.apk` and `android-x64.apk` are also recognized when their
metadata lists the actual packaged ABI. Do not use Flutter split-ABI offset
version codes accidentally; the production workflow packages one universal APK
with one monotonic version code. Both packaged ABIs must contain the Flutter
engine. 32-bit ARM is outside the current artifact support.

GitHub response size/timeouts are bounded, checks are cached for ten minutes with
ETag revalidation, and rate limits prevent immediate repeated requests. Metadata
downloads are SHA-256 checked before parsing. Incomplete Android assets show an
actionable error. No compatible release yields a clear current-version message.
No first public Android release exists merely because this implementation does.

## Download and install

1. Check for updates and review notes.
2. Download Update. Storage is checked for download plus staging space. Cancel
   interrupts the request; failed/partial downloads are removed. Retry is explicit.
3. A complete size/digest match is followed by native verification with AOSP's
   `ApkVerifier` and PackageManager metadata. Checks cover APK signature integrity,
   exact installed signing certificate set, package name, expected higher code,
   expected version name, minimum SDK and actual packaged/device ABI overlap.
   SHA-256 alone does not establish publisher identity. Certificate rotation is
   conservatively rejected; use the same durable signing key for GitHub updates.
4. Install Update explains Android's unknown-app-source permission if needed and
   opens the system settings only after the user chooses it. Denial/cancellation
   returns to the verified download. A granted permission is not requested again.
5. Verification runs again immediately before a narrowly scoped FileProvider URI
   opens Android's package installer. Android asks for installation approval and
   performs its own signature/package checks. No silent installation, uninstall,
   data reset or automatic restart is attempted. Reopen from the launcher afterward.

APK files live in `cacheDir/update-apks/`; only that directory is exposed by the
non-exported update provider, with temporary read permission. Valid downloads are
reused after rechecking their digest/signature. Partial files are cleared on the
next check/download; files older than seven days are removed on app startup or
update settings use. Android can evict cache at any time; redownload if necessary.

## GitHub versus Google Play

`--flavor github` includes APK verification/installation, the update FileProvider
and `REQUEST_INSTALL_PACKAGES`. `--flavor play` compiles a different native updater
with only the official Play listing flow, and includes neither that permission
nor the APK installer/verification dependency/provider. Its screen sends the user
to the official Play listing/library, where Play controls installation. Play
In-App Updates can be adopted when a real Play listing/test track exists; the
current implementation uses the supported official store flow. Both flavors keep
the same package name, so production distribution/signing must be chosen before
claiming cross-store upgrade compatibility. Never bundle a GitHub APK as a Play
artifact. Public publishing is a separate owner decision.

## Acceptance

Unit/widget checks cover parsing, channels, source identity, checksums, partial
cleanup, cancellation, cache reuse, errors, mobile large text and Play separation.
Use the disposable-emulator procedure in [signing and releases](ANDROID_RELEASE.md)
to establish actual installation/data persistence. Mocked permission/installer
results and a successful APK build do not establish physical-phone acceptance.
