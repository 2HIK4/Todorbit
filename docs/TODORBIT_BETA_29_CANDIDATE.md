# Todorbit Beta 29 verification and publication

Version `1.0.19-beta.29+52`, Schema 29, on `feature/todorbit-beta27-refinement`.
Exact source `bd9d3375d03964377110943eb7b7a0acd0acc691`.
Published as the Experimental prerelease
[`v1.0.19-beta.29`](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.29).
See the [release notes](TODORBIT_BETA_29_RELEASE_NOTES.md) and
[UI & TDAT review record](UI_TDAT_INDEPENDENT_REVIEW_2026_11_25.md).

## UI, theming and reliability summary

- Replaces hardcoded legacy purple in `TaskDetailsView` with active theme and
  semantic `TodorbitThemeTokens` priority styling, and keeps `_addManualTime`
  scrollable above compact/mobile keyboards.
- Restores Android `Upcoming` planned-day grouping and accessible context,
  colors priority badges on mobile rows and subtasks, dims completed titles,
  preserves `48 dp` Android subtask action targets, and fixes blank-query empty
  search copy.
- Migrates `ThemeDialog` to responsive `AppModalShell` + `DialogActionBar` with
  native desktop `WindowsSettingsFileDialog` JSON import/export, separates the
  scrollable desktop sidebar from its pinned footer with a divider, aligns
  `Workspace`/`Habits`/`Goals`/`Reports` layout & error accents, and shows
  concise start times on narrow overlapping Calendar week cards while keeping
  full ranges in tooltips and semantics.
- Incorporates TDAT artifact-check fail-closed safeguards, offscreen screenshot
  font loading, worktree doctor repair, registry deduplication, and `tools/test-portable-update.ps1`
  runner-HWND (`FLUTTER_RUNNER_WIN32_WINDOW`) targeting.

## Release gates

- [Exact-source Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/45777666379)
  passed full-repo Dart analysis, full-repo serial Flutter tests, TDAT safety,
  architecture and documentation suites, C++ runtime CRT checks, native writer
  and hidden background sync barriers, companion `--self-test`, installer
  compilation, and checksum generation on `bd9d3375d03964377110943eb7b7a0acd0acc691`.
  Artifact `15099180683` supplied the Windows setup (`48,090,441` bytes) and
  portable (`65,505,502` bytes) packages. Both match their `.sha256` sidecars
  and `SHA256SUMS.txt`, report numeric FileVersion `1.0.19.52`, pass PE and
  43-entry portable ZIP audits, follow the existing unsigned Windows policy,
  and carry the enabled Desktop Drive build receipt.
- The isolated Windows portable upgrade started from the published Beta 28
  portable ZIP (`fb1e0d3aac0ef001cbd87f92b825b0cf12f079e07c6f74463c15edff42cb3513`),
  seeded a synthetic task and widget/update preferences in `%TEMP%`, swapped in
  the audited Beta 29 portable ZIP (`261c5ba655b58c98cf70aaafee09b8a535494dccf2cb099ed64db0768d75f850`),
  verified `Update installed: 1.0.19-beta.29`, and restarted `Todorbit.exe` cleanly
  with SQLite integrity and synthetic data intact (no registered installer run).
- [Exact-source Android CI](https://github.com/2HIK4/Todorbit/actions/runs/45777673011)
  passed Android analysis, mobile Flutter suites, release preparation tests,
  debug APK validation, and the API 35 KVM emulator workflow on
  `bd9d3375d03964377110943eb7b7a0acd0acc691`.
- Locally prepared production-signed Beta 29 APKs in `Todorbit-redesign-source`
  passed `:app:testGithubReleaseUnitTest`, native ELF/ZIP 16 KiB alignment,
  Android SDK `minSdk=26`, version code `52 > 51`, and certificate verification
  matching Beta 28 (`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`).
- The [official API 36 runtime](https://github.com/2HIK4/Todorbit/actions/runs/45784257387)
  reported a 16,384-byte page size. Signed x64 APK
  `bec185a1fc49ebd8031bcc35ad1d0728477cbc621911aa9c8fa338a387ad7f84` upgraded
  published Beta 28 APK (`37298b82f9ae468704dec23ac6562f415ed03c62374ca823402cc8ef12858890`)
  from build 51 to 52 in place, retaining synthetic task data and Calendar Month
  selection across restart (`1,350 ms` cold upgraded startup, zero crashes/ANRs).
  Downloadable Actions artifact `15100555302` holds `receipt.json` and captures.

## Public availability and updater discovery

GitHub release `459136042` has 11 assets. The
[asset receipt](TODORBIT_BETA_29_PUBLICATION_ASSETS.json) records their IDs,
URLs, byte sizes, and SHA-256 values. All 11 anonymous public URLs resolved with
matching Content-Length / digests, and the public `Todorbit-1.0.19-beta.29-android-update.json`
matched the locally audited candidate byte for byte. GitHub marks the release as
a prerelease targeting `bd9d3375d03964377110943eb7b7a0acd0acc691`. `main`,
`Stable`, and previous releases/tags remain unchanged (`main` @ `a6d36dc7ed2863a40b7e9bc9c4cdbebc81f2c530`).

Running `test/published_update_discovery_test.dart` against the live public
GitHub endpoints from a synthetic `1.0.19-beta.28` (`51`) identity selected
`v1.0.19-beta.29` (`52`) on Experimental for Windows setup/portable and Android
ARM64/x64 while Stable excluded it on both platforms.

## Manual acceptance

- On an isolated Windows test installation (excluding the owner's personal
  profile), update Beta 28 → Beta 29 via Settings → Software Updates using the
  setup installer and verify retained tasks, preferences, native widget state,
  display-scaling DPI, keyboard focus, and Narrator output.
- On a physical Android test device with synthetic data, update Beta 28 →
  Beta 29 via Settings → Software Updates and verify installation flow, retained
  data/preferences, TalkBack output, and launcher widget behavior.
- Real two-client Google Drive sync/backup acceptance remains separately
  authorized with disposable test accounts.
