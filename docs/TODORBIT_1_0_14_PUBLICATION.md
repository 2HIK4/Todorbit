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

Preparation and verification in progress. Bounded evidence and private build logs
are retained under ignored `.buildlog/release-1.0.14-20261026/`. No token,
passphrase or full Desktop credentials JSON belongs in source or packages.
