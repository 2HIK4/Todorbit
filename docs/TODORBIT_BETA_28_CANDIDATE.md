# Todorbit Beta 28 verification and publication

Version `1.0.19-beta.28+51`, Schema 29, on `feature/todorbit-beta27-refinement`.
Exact source `21bae9a3407d6e23b82408f36a6e75b286187d64`.
Published as the Experimental prerelease
[`v1.0.19-beta.28`](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.28).
See the [release notes](TODORBIT_BETA_28_RELEASE_NOTES.md).

## Appearance and compatibility

Graphite Neutral Silver is the approved dark default. The light default,
saved dark palettes, named presets, imports and density retain their values.
To use Silver in an existing profile, choose Customize Theme, Dark,
Dark palette preset, Graphite Neutral Silver, and Save changes. Reset both
palettes restores only the built-in color values. Windows and Android native
fallback accents match the new default.

Nine focused tests covered reset, explicit palettes, preset contrast, import
validation and device-local preference round trip. The Violet orbit was
visible in the real Windows Profile workspace. The orbit widget, asset and
Windows runner icon inputs are unchanged since the polish review.

The [independent critique](BETA_27_POLISH_CRITIQUE.md) and [Calendar measurements](BETA_27_POLISH_IMPLEMENTATION.md)
still apply. Dense Day scroll raster p95 measured 20.00 → 11.09 ms on the
120 Hz host, with 80% of candidate samples above budget. Day-to-Month and
Month-to-Week took longer in the paired run. Physical input, assistive
output and longer sessions remain separate acceptance checks.

## Release gates

- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/45486376666)
  passed Dart analysis, 1,243 Flutter tests with nine opt-in skips, 39
  architecture checks, native writer and hidden-process barriers, companion
  self-test, CRT packaging, installer compilation and checksum generation.
  Artifact `14965278963` supplied the production packages. The setup,
  portable runner and companion report numeric `1.0.19.51` and follow the
  existing unsigned Windows distribution policy. A separate package audit
  matched both Windows hashes and sidecars, checked all 43 portable entries,
  and verified the enabled Drive build receipt against the packaged runner
  and AOT payload.
- The isolated Windows portable upgrade started from the ZIP that matches the
  public Beta 27 hash. The update helper swapped in Beta 28 and restarted the
  app. The synthetic task, SQLite integrity, widget configurations and update
  preference all passed after restart. The test used redirected application
  data and excluded sign-in registration. No installer was executed.
- [Exact-source Android CI](https://github.com/2HIK4/Todorbit/actions/runs/45486377233)
  passed analysis, 76 Flutter and 14 packaging tests, artifact validation and
  two API 35 emulator checks.
- All three production APKs match the published Beta 27 certificate
  `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
  The package ID, build 51, SDK 26 minimum, ABIs, native alignment and private
  file exclusions passed. Android Drive is enabled.
- The [official API 36 runtime](https://github.com/2HIK4/Todorbit/actions/runs/45488464579)
  reported a 16,384-byte page size. The signed x64 APK
  `37298b82f9ae468704dec23ac6562f415ed03c62374ca823402cc8ef12858890`
  upgraded the published Beta 27 APK in place from build 50 to 51. The
  synthetic task and Calendar Month selection survived the upgrade. Task
  completion and reopening passed, with no crash or ANR observed. Cold
  upgraded startup took 3,266 ms in this run. The downloadable Actions
  artifact `14963979762` holds the receipt and captured runtime evidence.

## Public availability and updater discovery

GitHub release `457334982` has 11 assets. The [asset receipt](TODORBIT_BETA_28_PUBLICATION_ASSETS.json)
records their URLs, sizes and SHA-256 values. All 11 public links resolved
without authentication at the expected size. GitHub's reported digests matched
the locally audited files, and the public Android manifest matched byte for
byte. GitHub reports the release as a prerelease and the tag resolves to the
exact candidate. Stable and older releases were preserved. `main` stayed at
`a6d36dc7ed2863a40b7e9bc9c4cdbebc81f2c530`.

The opt-in check of the production updater services from a synthetic Beta 27
identity selected Beta 28 on Experimental for Windows setup and portable
and for Android ARM64 and x64. Stable excluded it on both platforms. Updater
discovery used anonymous public endpoints without installing anything.

## Manual acceptance

- On a separate Windows test installation, install Beta 27 and create a test
  task, save a non-default palette/density and open the native widget. Switch
  to Experimental in Settings → Software Updates, install Beta 28 and confirm
  the task, preferences, widget, and Settings update state after restart.
  Check keyboard focus, screen-reader announcements, and widget placement
  while moving between displays with different scaling.
- On a physical Android test device with synthetic data, update a
  production-signed Beta 27 install from Settings → Software Updates. Confirm
  the installation dialog and retained task, palette and Calendar choice.
  Check Android launcher widget placement, TalkBack, and notifications after
  backgrounding and reopening the app.
- Real two-client Google Drive acceptance requires separate authorization and
  disposable accounts. The packaged configuration and synthetic sync checks
  do not access a real Drive workspace.
