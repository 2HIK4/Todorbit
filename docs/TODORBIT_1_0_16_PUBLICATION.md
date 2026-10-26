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
