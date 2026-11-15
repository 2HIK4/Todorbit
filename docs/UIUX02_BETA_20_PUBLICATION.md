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

## Release qualification executions and repairs

- Candidate `02a0785`: Windows CI 43690416483 stopped at analysis, 17 style infos
  and one unused local. No tests/packages were produced. Reviewed mechanical
  braces/null-aware collection/unused callback-name fixes, retaining awaited
  event creation; strict scoped six-file analysis passed in 8.6s. The automated
  fixer also proposed moving flutter_driver to production dependencies; rejected
  and restored pubspec exactly. No dependency change or suppressed diagnostics.
  A first textual equivalence assertion used Windows default decoding and failed;
  the UTF-8 comparison passed for all four braces-only production files.
- Qualification source `ff96dcb`: Windows CI 43691060241 passed full analysis,
  then 992 tests passed, 7 failed, 9 opt-in skips. Packages were not produced.
  Three failures were stale recurrence action labels. One overnight fixture
  expected legacy `Continues` copy rather than the current midnight-clipped
  timeline label; it now also verifies the stored original 23:00 start remains.
  Three visual failures used synthetic Ahem because capture-font environment
  variables were absent in CI. The helper now resolves bundled Roboto/icons
  from the existing Flutter SDK by default; no dependency or scale reduction.
  Sound options are scrolled into view before tapping. Assertions remain active.
- Only those seven failures were rerun locally, without capture environment
  overrides: all seven passed in 60s. Changed-fixture strict analysis is recorded
  in fixture-analysis.log. Final CI rerun is required to complete the existing
  packaging workflow; no repeated local full suite is used.
- Android validation 43690419404 on `02a0785`: both host and isolated update
  integration jobs passed. Reused for unchanged Android functional boundaries;
  subsequent production edits are reviewed lint syntax only.
- Signed APK build `02a0785` passed alignment (289.2s); preserved as an intermediate.
  The final production-source `ff96dcb` build passed (117.2s), 8 ELF/ZIP alignment
  checks. Production signer matches the retained public Beta 19 APK, whose hash
  matches GitHub metadata. Final candidate is package io.github.hik4.todorbit,
  code 43 > 42, minSdk 26, arm64-v8a/x86_64, provider names retained and packaged
  SurfaceRefreshReceiver non-exported. SHA-256:
  `f7277b05048da30843eae18cb2b4a77543526e865c499b8052e819dd5ae8edf0`.
  Existing preparation script passed identity/signer/debuggable/ABI/alignment and
  code monotonicity across every published Android manifest. No Play AAB requested.

Remaining pending checks are unchanged; nothing is publicly published yet.
