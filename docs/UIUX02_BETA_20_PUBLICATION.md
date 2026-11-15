# UIUX-02 beta 20 publication receipt — 2026-11-15

Status: PREPARING; no publication claimed by this initial receipt.

Reviewed checkpoint: `6d32ce8` on `codex/independent-beta-review`, parent
`61bde1c54c01d6d3f55dbc8b9a4585712cdf9750`. All 24 raw source/config/test hashes
matched [UIUX-02 review identity](UIUX02_REVIEW_SOURCE_MANIFEST_2026_11_15.json)
before the checkpoint; the 25-path staged set was checked for unrelated/generated
files and sensitive content. Only mechanical blank-line cleanup was made to the
review receipt. Three pre-existing untracked documents remain untouched.

Candidate: `1.0.19-beta.20+43`, Android code 43, native PE 1.0.19.43.
Shared/native version declarations, changelog and release documentation change
after the checkpoint. Two existing missing-braces style diagnostics would fail
the strict Windows CI analyzer; added braces around those same single statements
in calendar_view.dart and task_editor.dart without changing behavior. Scoped
strict analysis of those two files passed (10.9s; lint-release-gate.log). Product schema, protocol, signing and package IDs
remain unchanged. [Release notes](TODORBIT_BETA_20_RELEASE_NOTES.md).

Existing scoped review tests, renders and source review are reused within their
recorded limits. No local full Flutter/JVM suite or full analysis rerun is
planned. Required existing Windows packaging/CI and Android validation run on the
exact committed candidate; local Android signing and package-specific identity,
signature, alignment, hashes and updater checks remain required. Logs and frozen
GitHub release/tag inventory are under ignored `.buildlog/uiux02-publication/`.

No Stable release existed in the preflight release inventory; /releases/latest
returned 404. All existing releases/tags and asset identities will be compared
after publication. Current latest prerelease is beta 19/build 42.

Pending: signed APK, Windows installer/portable, draft inspection, exact-source
CI, exact-artifact runtime requirement, public assets and production updater
discovery. Physical launcher Doze/reboot, installed-device/IME/TalkBack and
Windows interaction acceptance remain explicit gaps in
[Deferred verification](DEFERRED_VERIFICATION.md).
