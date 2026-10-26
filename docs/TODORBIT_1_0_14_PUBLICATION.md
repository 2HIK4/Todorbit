# v1.0.14 widget customization pre-release publication

Owner approval: 2026-10-26. Publishing a GitHub **pre-release**, safely merging
the completed feature to main, reusing the existing enabled Desktop OAuth build
configuration, and updating GitHub Pages are explicitly authorized. No personal
installation/profile upgrade, Google Cloud change, Sandbox or VM is authorized
or required. Manual UI testing follows publication by owner choice.

Implementation: `d355ee2`, `feature/widget-customization-calendar`, fast-forwarded
into local main from `3d499fb`. Version **1.0.14+15**, with matching native version.
Release changes preserve the implementation and do not alter SQLite schema v21,
profile paths, updater service/helper, installer AppId, OAuth scopes/storage,
encryption or startup registration identity.

Reuse the completed **303 passing tests** (304 cases including one opt-in skip),
clean analysis, Windows/native builds and separately passing real-companion test
recorded in [the implementation report](WIDGET_CUSTOMIZATION_UPDATE.md).
Additional work is limited to final CI, enabled build/package checks, version and
artifact identity, migration/update compatibility, publication and public links.
No repeated local full suite or general UI audit is needed for version metadata.

The exact enabled configuration from the v1.0.13 engineering run is reused;
the tracked source default is restored disabled/empty after packaging. Published
binaries must be enabled, bound to their config/runner/AOT receipt and checked
against the prior published configuration. Disabled CI artifacts are not substitutes.

Physical DPI, Win+D, screen-reader/manual native interaction and registered
installer/clean-machine trust remain unverified. Google branding/full policy
compliance is not claimed. See [release notes](TODORBIT_1_0_14_RELEASE_NOTES.md).

## Publication evidence

Bounded evidence and private build logs are retained under ignored
`.buildlog/release-1.0.14-20261026/`. No token,
passphrase or full Desktop credentials JSON belongs in source or packages.

- Release source: `b5993962a3a282202fc8c4c1bddf9cffb7a7488d` on main, including
  feature `d355ee2`. Tracked configuration restored disabled/empty; published
  packages are the separately built enabled artifacts, not CI packages.
- Exact v1.0.13 parameter/configuration hash matches the prior published ZIP
  receipt. Both new packages come from the same enabled Release bundle.
  Receipt binds configuration, runner and AOT hashes. Portable CRC, all 33 files,
  full Release bundle equality, native version/resources and private-file guards
  pass. Inno Setup compilation passes; no installer was executed.
- [Final Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40379476407)
  **PASS** at release source: clean analysis, 303 tests passed/one opt-in skip,
  11 configuration gates, Windows Release, portable, native self-test, Inno Setup
  and checksums. Disabled CI assets are retained as CI evidence only.
- Packaged native persistence/configuration self-test and two-HWND lifecycle
  pass. These do not establish physical input, DPI or Win+D behavior.
- Actual bundled portable helper at a disposable path with spaces: readiness and
  parent-exit handoff, injected wrong-version rollback to public v1.0.13/reopen,
  then full v1.0.14+15 swap/version check/restart pass. All 44 tables and selected
  theme/calendar preferences retain identical digests; schema stays v21.
- Post-upgrade native Tasks migration preserves 35% shell opacity, layout lock,
  Upcoming view, 360x430 geometry and disabled sign-in launch. Calendar initially
  disabled; independent show/hide leaves Tasks configuration unchanged. Exactly
  one companion process serves both. Personal uninstall/Windows Run registration
  fingerprints remain unchanged. All test processes closed; fixtures retained.

| Published artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.14-win-x64-setup.exe | 47,183,801 | `c249b62abce037214d27dea80ee1fd6c92096f7a438600b119cfa57c1134b48f` |
| Todorbit-1.0.14-win-x64-portable.zip | 62,340,162 | `f6970ade45fb40a8b0aef092cb6891fd0f2157466f24a8d3a3e94d8d3d68951c` |

## Published result

- [GitHub pre-release v1.0.14](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.14)
  published 2026-10-26 18:58:32 UTC, explicitly pre-release and not Stable/latest.
  Tag targets **b599396**. All five assets are uploaded; anonymous release metadata,
  exact Markdown notes, sizes/GitHub SHA-256 digests and downloaded checksums pass.
  Both public binaries match the accepted hashes above; public ZIP CRC passes.
- The unchanged production `SoftwareUpdateService`, invoked with explicit
  `currentVersion: 1.0.13`, selects **v1.0.14** in Pre-release for both installer
  and portable. Actual HTTPS downloads pass size/SHA-256, allowed-host and
  progress checks. Stable excludes it. No profile/channel was changed and no
  downloaded package was executed. The unchanged helper preserves automatic
  close/install/restart; actual portable rollback/restart is verified above,
  while registered installer execution and painted update UI remain unverified.
- [Approved Pages deployment](https://github.com/2HIK4/Todorbit/actions/runs/40382531966)
  **PASS** at b599396. Static checks pass; anonymous live HTTPS checks match all
  eight files, all nine external links pass, and installer/portable links belong
  to actual v1.0.14 assets. [Official website](https://2hik4.github.io/Todorbit/).
  The first live probe preceded deployment and correctly rejected old bytes;
  the completed post-deployment check passes. Rendered browser QA unverified.
- Initial CLI binary uploads stalled; only completed checksum assets were in the
  private draft. Bounded sequential uploads completed with matching server
  digests, then the complete five-asset draft was verified before publication.
  No partial public release was exposed.

Evidence: `windows-ci.json/log`, `artifact-verification.json`, `oauth-provenance.json`,
`bundle-versions.json`, native logs, `updater-local/acceptance*.json`,
`widget-migration.json`, `draft-verification.json`, `public-release.json`,
`public-updater.json`, `public-integrity.json`, `pages-ci.json`, `website-live.json`
and five public downloads. Subsequent documentation receipts do not move the tag.
No personal update or Google API/Cloud operation was performed.
