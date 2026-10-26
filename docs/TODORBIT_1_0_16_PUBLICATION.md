# v1.0.16 refinement pre-release publication

Owner explicitly authorized implementation, promotion and publication of the next
Windows x64 GitHub pre-release after mandatory gates pass. Latest public version
at preparation was v1.0.15; candidate version is **1.0.16+17**, synchronized with
the native widget. Source and final receipts will be recorded below.

[Implementation, recovery and bounded verification](WIDGET_REFINEMENTS_SUPPORT.md).
[Release notes](TODORBIT_1_0_16_RELEASE_NOTES.md).

The established release flow uses Windows CI for exact-source full analysis,
serial tests, configuration gates, Windows Release, packaged native self-test,
installer, portable and checksums. Locally published packages retain the same
approved enabled Drive parameters as v1.0.15; CI's disabled configuration remains
evidence only. Build configuration is restored afterward. No personal profile,
installed application, Run entry or OAuth/Google Cloud configuration is changed.

The candidate is prepared as a private complete five-asset draft. Publication
requires CI success, matching app/widget identity, audited config/runner/AOT
receipt, full portable bundle equality/CRC, private-file guards, native self-test
and matching SHA-256 sidecars/manifest. Official support destination must appear
as `https://paypal.me/2hussam4` in source, tests and the compiled AOT bundle.

After publication, verify anonymous metadata/assets, Pre-release classification,
version/commit, public hashes and production updater discovery/download from
v1.0.15 for installer and portable. Stable must exclude the new pre-release.
Use the existing isolated portable helper harness for rollback/swap/restart;
never execute the installer against the owner's normal Windows account.

Physical Windows DPI/input, magnetic alignment feel, Win+D, Explorer restart,
multiple monitors, screen readers and registered installer execution remain
unverified. These are documented pre-release acceptance items; packages remain
unsigned. Checksums do not replace publisher signing.

Ignored evidence directory: `.buildlog/release-1.0.16-20261027/`.

## Published result — 2026-10-27 (Asia/Amman)

- [Public pre-release v1.0.16](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.16)
  published **2026-10-26 23:34:04 UTC / 2026-10-27 02:34:04 Amman**.
  It is explicitly Pre-release, not latest Stable. Tag and release target
  **6e3b64be67b36e001b4f13115c37c1921156c84c**. Implementation is **23526bf**;
  the final source adds two mechanical analyzer corrections. Documentation
  receipts do not move the tag.
- [Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40418348308)
  **PASS** on that source: clean analysis, **340 tests passed / one opt-in skip**,
  11 OAuth/configuration/stale-bundle checks, Windows Release, native self-test,
  portable, installer, checksums and retained CI artifact. The initial source's
  CI stopped at two lint infos before tests; the corrected run supplies the
  single final full-suite pass. Node action-runtime deprecation is informational.
- Both final local binaries report **1.0.16+17**. The audited enabled Windows
  bundle retains the exact prior approved Desktop build parameters, with bound
  config/runner/AOT hashes. All 33 portable entries pass CRC, full bundle equality
  and private-file guards. The compiled AOT includes the official PayPal URL.
  No credential/config values were added to source; tracked config is restored.
- Packaged `--self-test` and actual-HWND `--lifecycle-self-test` pass. Legacy
  full-month data preserves 1.3x text and hidden title; Tasks opacity, layout
  lock, Upcoming view, geometry and disabled startup survive. Calendar hide/show
  remains independent and only one companion runs. No physical input claim.
- The real bundled helper upgrades the public v1.0.15 portable copy at the same
  disposable path with spaces, validates version and restarts. Injected wrong
  version rolls back and reopens v1.0.15. All 44 tables, synthetic task/category,
  theme/calendar settings and location-keyed profile retain their digests. The
  new version creates its once-only support receipt. Personal Windows Run and
  registered installation fingerprints remain unchanged; no installer executed.
- A complete private five-asset draft passed exact notes, source, sizes and
  GitHub SHA-256 checks before publication. Anonymous HTML/API access, all five
  asset digests/sidecars/manifest, and byte-for-byte public binary downloads pass.
  The public portable ZIP also passes CRC.
- The unchanged production `SoftwareUpdateService`, with installed version
  **1.0.15**, discovers **v1.0.16**, downloads over HTTPS with progress and verifies
  bytes/SHA-256 in both installer and portable modes. **Stable excludes it**.
  Packages were not executed by this discovery/download check. PowerShell
  classified harmless Dart build-hook stderr as a wrapper error after both
  checks completed; the saved PASS receipts and exact downloaded hashes were
  independently validated without repeating the transfers.
- The local portable packager correctly refused the pre-lint candidate ZIP.
  It was moved into ignored evidence, then only packaging/checksums were rerun
  against the corrected bundle and final installer. The stale ZIP was not uploaded.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.16-win-x64-setup.exe | 47,212,373 | `057e78184ea1635d4c683a2517bcf54f33e5bb98472fb5293592bbca00c12ee2` |
| Todorbit-1.0.16-win-x64-portable.zip | 62,368,829 | `6fc6705d87f1b17f08ddb9fbd03ce0479f710c7d595812033190170bc6633eef` |

The release additionally contains both `.sha256` sidecars and
`Todorbit-1.0.16-SHA256SUMS.txt`. GitHub's automatic source archives are separate
from these five uploaded assets. Packages remain unsigned.

Final evidence: `windows-ci.json/log`, `local-analyze.log`, build/package logs,
`oauth-provenance.json`, `artifact-verification.json`, packaged native logs,
`updater-local/acceptance*.json`, `widget-migration.json`,
`draft-verification.json`, `ready-to-publish.json`, `public-release.json`,
`public-updater.json`, `public-integrity.json` and anonymous `public-assets/`.

## Upgrade and manual acceptance

1. Create a verified local backup in **Settings > Backups & Cloud**.
2. Open **Settings > Software Updates**, select **Pre-release**, then
   **Check for Updates** and confirm **v1.0.16**.
3. Select **Download update > Update and Restart** and review the unsigned-update
   confirmation. After reopening, confirm **1.0.16+17** and the same Data profile.
4. Test the Calendar with several events: scroll its agenda, change dates and
   resize short/tall/wide windows. Dates should stay compact as the agenda grows.
5. Resize/drag nearby widgets to align edges; restart and check saved bounds,
   independent visibility and Lock Layout. Repeat at your normal DPI/monitors.
6. Open Support Todorbit, confirm the optional PayPal destination and dismissal.
   The brief introduction should appear once after upgrade, with static feedback
   when reduced motion is enabled.
7. Check quick-task focus, main-app/widget independence, Win+D and Explorer
   restart. These physical interactions and registered installer execution remain
   **UNVERIFIED** by the automated checks above.

Manual fallback: download the matching setup/portable asset from the release and
verify its published checksum. Keep a backup; portable replacements must retain
the exact existing application path to keep the location-derived profile.
