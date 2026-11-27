# Todorbit Beta 30 verification and publication

Version `1.0.19-beta.30+53`, Schema 29, on `feature/todorbit-beta27-refinement`.
Exact source `253f4ed560018bfbb9acc9f1e110c823c77041d1`.
Published as the Experimental prerelease
[`v1.0.19-beta.30`](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30).
See the [release notes](TODORBIT_BETA_30_RELEASE_NOTES.md) and
[Progress](PROGRESS.md).

## UI, theming and reliability summary

- Replaces the 4-way white backdrop halo in `TodorbitWidget.exe` with a directional `(0, 1) + (1, 1)` contrast lift (`WidgetText.cs`), aligns `"taskRow"` underlay composition with `"content"` / `palette.Row`, and fixes translucent Light/Dark surface mutation and opaque hover blends (`WidgetSurfaces.cs`).
- Implements continuous 16 ms eased pixel scrolling across Windows Tasks and Calendar widgets via shared `WidgetScrollAxis` honoring OS `MouseWheelScrollLines` and `SPI_GETCLIENTAREAANIMATION` reduced-motion preferences, resets task scroll on `DateToday` / midnight rollover / UIA `"Return to today"`, fixes Calendar agenda viewport bottom clipping, disposes timers/popups on `WmDestroy`, and verifies zero idle repaints (`idle_paints_250ms = 0`).
- Embeds the complete Hotkeys editor (`HotkeysEditorView`) inline inside **Settings > Hotkeys** (with search, live recording, conflict checks, named preset management, `Tab`/`Escape` and keyboard `Save`/`Cancel` focus preservation, and standalone `HotkeysDialog` parity).
- Integrates PR #3 data/search reliability fixes (`BackupService` clock-rollback snapshot retention, `ResumableUpdateDownload` damaged full-partial restart & case-insensitive `Content-Encoding`, `Workspace` non-cancelled fixed event search, `MobileWorkspace` trimmed task/event/location search & 48 dp targets) plus TDAT bounded watchdogs, suite checkpoints with `-Resume`, and workspace path hygiene.

## Release gates

- Owner visual acceptance approved on isolated Windows Release candidate (`build/windows/x64/runner/Release`) covering desktop widget Light/Dark rendering, continuous pixel scrolling, and embedded Settings > Hotkeys.
- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/46066659736) passed full-repo Dart analysis, full-repo serial Flutter tests, TDAT safety/watchdog/hygiene checks, Windows Release build (`googleDriveEnabled: true`, `privateDriveTest: false`), Microsoft-signed C++ CRT validation, portable ZIP (`39` files, PE `1.0.19-beta.30+53` / `1.0.19.53`), native sync writer, hidden background sync barriers, companion `--self-test`, Inno Setup installer compilation (`setup.exe` `1.0.19.53`), and SHA-256 checksums on `253f4ed560018bfbb9acc9f1e110c823c77041d1`.
- Isolated Beta 29 → Beta 30 portable upgrade (`tools/test-portable-update.ps1`) swapped audited Beta 29 (`261c5ba655b58c98cf70aaafee09b8a535494dccf2cb099ed64db0768d75f850`) to audited Beta 30 (`7421ca6d61a84c32e9c1462490732d0356d7a2a11d745b4a7f365cb31055a7d2`) in `%TEMP%`, restarted cleanly (`19.22s`), and preserved SQLite integrity and synthetic data.
- [Exact-source Android CI](https://github.com/2HIK4/Todorbit/actions/runs/46066664484) passed Android analysis, 9 Android/mobile Flutter suites, `test_prepare_android_release.py`, debug APK validation, and the API 35 KVM emulator integration workflow on `253f4ed560018bfbb9acc9f1e110c823c77041d1`.
- Locally prepared production-signed Beta 30 Android APKs (`universal`, `arm64-v8a`, `x86_64`) and Play AAB (`release/android-beta30`) passed `:app:testGithubReleaseUnitTest` (`151.79s`), 16 KiB ELF/ZIP alignment, `minSdk=26`, `versionCode 53 > 52`, and signer certificate parity (`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`).
- [Official Android API 36 `16 KiB` runtime](https://github.com/2HIK4/Todorbit/actions/runs/46068388702) confirmed `pageSize: 16384`. Exact signed Beta 30 x64 APK (`2f63cec1111f15e01d53dafa6aa40fce7be85c459b4a68df6c899d0f289a0cda`, build `53`) upgraded published Beta 29 x64 APK (`bec185a1fc49ebd8031bcc35ad1d0728477cbc621911aa9c8fa338a387ad7f84`, build `52`) in place, retaining synthetic task data and Calendar Month selection across restart (`2,128 ms` cold upgraded startup, `1,582 ms` reopen, zero crashes/ANRs). Artifact `15231583650` holds `receipt.json` and logs.

## Public availability and updater discovery

GitHub release `461064408` (`v1.0.19-beta.30`) has 11 assets recorded in [TODORBIT_BETA_30_PUBLICATION_ASSETS.json](TODORBIT_BETA_30_PUBLICATION_ASSETS.json). All 11 anonymous public URLs resolved HTTP `200` with exact sizes and SHA-256 checksums. GitHub marks the release as a prerelease (`latest=false`) targeting `253f4ed560018bfbb9acc9f1e110c823c77041d1`; `Stable` and previous releases/tags remain untouched.

Running `test/published_update_discovery_test.dart` against live GitHub endpoints from a `1.0.19-beta.29` (`52`) identity selected `v1.0.19-beta.30` (`53`) on Experimental for Windows setup/portable and Android ARM64/x64 while Stable excluded it on both platforms.

## Remaining manual acceptance

- Physical Windows multi-monitor DPI variations, `Win+D` across displays, Narrator/TalkBack assistive output, physical Android OEM/device install flows, and separately authorized two-client live Google Drive tests remain open acceptance gates (excluding the owner's personal profile and Windows Sandbox).
