# v1.0.15 widget redesign pre-release publication

Owner authorization: publish the completed `ae649f1` implementation as the next
Windows x64 GitHub pre-release, promoting to main through the established flow.
Latest published version checked through GitHub API/CLI: v1.0.14. New version:
**1.0.15+16**, synchronized with native widget metadata.

Reuse implementation verification in [the report](WIDGET_REDESIGN_IMPLEMENTATION.md).
Version/release preparation does not change application logic, schema v21,
profile paths, installer identity, backup formats or widget preference defaults.
Build/package using the same enabled configuration as the prior public package;
restore the tracked disabled/empty configuration afterward. CI's disabled-config
packages remain CI evidence, not replacements for the enabled release packages.

Mandatory gates: Windows CI on the release source; audited enabled bundle and
receipt; matching installer/portable identities, private-file checks and SHA-256;
packaged native self-test; complete private draft before publication; anonymous
asset digest checks and production updater discovery from v1.0.14 afterward.

Physical Windows acceptance remains pending real-user testing. No registered
installer, physical DPI/input/Win+D or screen-reader pass is claimed. Existing
unsigned and experimental Drive limitations remain. No personal profile or
installation is used for release verification.

Release notes: [v1.0.15](TODORBIT_1_0_15_RELEASE_NOTES.md).
Evidence is retained under ignored `.buildlog/release-1.0.15-20261026/`.

## Candidate evidence

- Feature `ae649f1` and version preparation **a1160692bd854e266e7f331fbe8f8acb232a1bfe**
  fast-forwarded to main. The tag/release targets that exact preparation commit.
- Existing implementation verification is reused. No additional local full suite
  was run for version metadata. Final-source Windows CI is run separately as the
  established release gate, not substituted by historical CI.
- Audited enabled Release build and Inno Setup compilation pass. Both packages
  use the same bundle and exact prior published Desktop configuration. Receipt
  binds config, runner and AOT hashes; portable CRC/all 33 file checks, full bundle
  equality and private-file guards pass. Tracked config restored disabled/empty.
- Bundled native self-test and two-Explorer-HWND lifecycle pass. Versions are
  1.0.15+16 for both app and companion; no physical input/DPI claim.
- Actual portable updater helper upgrades public v1.0.14 to v1.0.15 at the same
  disposable path with spaces, validates version and restarts. Injected wrong
  version rolls back/reopens v1.0.14. All 44 tables, synthetic records,
  theme/calendar preferences and location-derived profile retain their digests;
  personal Windows Run/uninstall fingerprints remain unchanged. No installer ran.
- Widget compatibility check preserves 35% opacity, layout lock, Upcoming view,
  360x430 geometry and disabled startup; Calendar independent hide/show leaves
  Tasks config unchanged in one companion. The first harness asserted immediately
  after asynchronous pipe delivery; the corrected bounded state wait passes.
- Complete private five-asset draft has exact release notes, correct target and
  matching GitHub/local SHA-256 digests. No partial public release was exposed.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.15-win-x64-setup.exe | 47,205,685 | `1b9934dff05b9596e1d05915879f060d719906f77ccbddb4ba221b34e5c7e1ac` |
| Todorbit-1.0.15-win-x64-portable.zip | 62,354,350 | `d3971b8f93e11fc75957cd82104aa4fdda64eb0efd31b188bc03551057d7bea2` |

The draft additionally contains two `.sha256` sidecars and
`Todorbit-1.0.15-SHA256SUMS.txt`. SHA-256 is integrity evidence, not signing.

## Published result (2026-10-27, Asia/Amman)

- [GitHub pre-release v1.0.15](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.15)
  published 2026-10-26 21:03:11 UTC (2026-10-27 00:03:11 Amman), explicitly
  pre-release and not latest Stable. Tag targets **a116069**; documentation
  receipts do not move it. The implementation is **ae649f1** on main.
- [Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40399386479)
  **PASS** on the exact release source: clean analysis, **329 tests passed,
  one opt-in skip**, configuration gates, Windows Release, portable packaging,
  native self-test, installer compilation, checksums and retained CI artifacts.
  Published packages are the locally audited enabled bundle; disabled-config CI
  packages are evidence only. The CI action-runtime deprecation annotation is
  informational; no mandatory gate failed.
- Anonymous release metadata and all five assets are accessible. Exact notes,
  asset sizes and GitHub digests match. Both downloaded public binaries match
  local bytes/SHA-256; portable CRC passes. Checksum sidecars/manifest match.
- The unchanged production `SoftwareUpdateService`, with explicit installed
  version **1.0.14**, selects **v1.0.15** on Pre-release for installer and
  portable, downloads over HTTPS with progress and verifies size/SHA-256.
  Stable excludes the release. Running app metadata separately confirmed
  **1.0.14+15**; no personal channel/profile was changed or updated.
- Initial updater harness invocation supplied mixed relative path separators
  and hit its isolated-evidence guard before network operations. Passing the
  resolved absolute evidence path completes both updater/download checks.
- Real-user physical Windows acceptance is **pending**, including dragging,
  focus/input, DPI, multiple monitors, Win+D, Explorer restart and screen readers.
  Registered installer execution and clean-machine trust remain unverified.
  Packages are unsigned; backup/schema/widget compatibility claims retain the
  bounded evidence above. No website deployment or Google Cloud change was made.

Final receipts: `windows-ci.json/log`, `artifact-verification.json`,
`oauth-provenance.json`, native logs, `updater-local/acceptance*.json`,
`widget-migration.json`, `draft-verification.json`, `public-release.json`,
`public-updater.json`, `public-integrity.json` and five anonymous public downloads.

## Exact upgrade steps

1. Create a verified local backup in Settings > Backups & Cloud.
2. From v1.0.14, open Settings > Software Updates; choose **Pre-release** in
   Update channel and select **Check for Updates**.
3. Confirm **v1.0.15**, select **Download update**, then **Update and Restart**.
   Review the unsigned-update notice and confirm **Install unsigned update**.
4. After reopening, confirm **1.0.15+16**, retained data/widget preferences and
   the same Data profile. Test both calendar modes and live customization.

Manual fallback: installer users close Todorbit/widgets and run the x64 setup
over their existing installation. Portable users keep a backup and the old
bundle, close both processes, and replace the complete bundle at its exact
existing path; extracting elsewhere selects a different portable profile.
