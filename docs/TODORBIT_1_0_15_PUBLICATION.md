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
