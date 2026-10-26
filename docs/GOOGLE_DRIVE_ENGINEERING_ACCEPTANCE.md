# Google Drive engineering follow-up — v1.0.13+14

> **2026-10-26 release update:** enabled v1.0.13 is now published as an
> owner-approved **experimental pre-release**, merged to main with website
> download updates. Public asset/updater/Pages verification passes.
> This supersedes the earlier publication hold below, while preserving
> every skipped/unverified test and unresolved policy limitation. See
> [the publication record](TODORBIT_1_0_13_PUBLICATION.md) and
> [release notes](TODORBIT_1_0_13_RELEASE_NOTES.md). Historical blocked
> conclusions below describe their earlier checkpoints.

2026-10-26, `feature/google-drive-production-readiness`. No main merge, public
release, Cloud configuration change or website edit is authorized. This record
supersedes the unresolved initialization issue in the earlier
[private acceptance report](GOOGLE_DRIVE_PRIVATE_ACCEPTANCE.md).

**Final source: `8d667df`. Local automation/private integration and
[Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40342429612) PASS.
Complete acceptance PARTIAL; public release BLOCKED.** The owner explicitly
skipped clean Windows-user/VM testing for this release; it is a known unverified
area and no Sandbox action is required. Manual GUI limits are recorded below.
Google branding/policy compliance remains unverified. v1.0.13 stays unpublished.

## Fix and safety boundary

The original creation callback committed DDL statement by statement. Drift
wrote `user_version` after the callback, so process death left a partial schema
at version 0. The read-only startup gate then rejected that file. Upgrades had
the same gap between DDL commits and version recording.

- Creation and upgrades now run in SQLite transactions, including the version
  marker. Schema v21, table definitions and supported upgrade versions stay
  unchanged. A process killed before COMMIT leaves the previous complete state.
- Version 0 is explicitly recognized as unfinished initialization. Recovery
  refuses every populated user table. Missing schema objects are completed
  without dropping tables, deleting rows, replacing files or resetting settings.
  Before commit, the resulting schema must match a freshly built current
  database exactly, including tables, columns, indexes and triggers. Unknown or
  incompatible objects cause rollback; errors instruct preservation/recovery.
  The final audit reproduced and fixed SQL LIKE's underscore-wildcard edge
  case: literal-prefix GLOB checks ensure `sqlitecustom` and similar user tables
  cannot disappear from validation. Added empty/populated name regressions.
- Initialization opens inside the startup error boundary, before the controller
  and native companion. Controller-load failures also stop with the startup
  error page instead of escaping startup. Existing schema upgrades retain the
  owner approval and verified Before upgrade backup gate.
- Backup validation now checks the required v20+ reminder table before accepting
  a snapshot. Previously the requirement was added after the check. Valid older
  snapshots remain supported; malformed snapshots are rejected, not repaired.

No authentication, token-store, scope, encryption format, updater, installer
identity or profile-path migration was introduced. Populated version-0 files
and historical partially applied upgrades are never reset automatically; retain
the original and use a reviewed trusted backup/recovery process.

## Regression and local verification

| Check | Result | Evidence/limits |
| --- | --- | --- |
| Initialization regression | PASS | 22 new cases: fresh/zero-byte creation, four old partial creation stages, populated/incompatible schemas, corruption/future versions, existing upgrades/backup, six real process-death cases, repair retry and current data preservation. |
| Real process termination | PASS | Separate Dart processes killed during fresh creation and schema-1 upgrade after early/middle DDL and after version write before COMMIT. WAL recovery leaves schema 0 empty or original v1 rows/schema; normal reopen succeeds. Not a power-loss hardware test. |
| Original failure fixtures | PASS | Both preserved interrupted Source/installer-layout files were recovered in disposable copies to v21/44 tables with integrity OK. New packaged Release also recovered a copy through the actual startup gate/background executor; a populated v0 copy retained its row and exact schema. Error UI unobserved. Originals were not repaired/replaced. |
| Backup completeness regression | PASS | Missing reminder table in v20/v21 rejected without replacing source rows/schema or publishing a managed snapshot. Existing v20 import/migration passes. |
| Complete Flutter suite | PASS | 287/287, zero JSON error events, 423.259 seconds. Includes auth, secure-store mocks, local crypto/SQLite/cloud recovery, settings, migration, UI and profile checks. |
| Flutter analysis | PASS | No issues, 54.8 seconds. |
| Native Release | PASS | Zero warnings/errors; 14.94 seconds. |
| Configuration/package guards | PASS | 11 existing checks, tracked public configuration disabled/empty. |
| Private Windows Release/packages | PASS | Enabled Release (161.7s), Inno Setup 7.1.0 (53.016s), 37-entry portable CRC/full bundle equality, receipt/config/runner/AOT binding and SHA-256 sidecars. Source/Restore/copied installer layout each start/restart with separate empty v21/44-table profiles. Packaged widget self-test passes; Windows Run registration unchanged during smoke. This is not registered installer acceptance. |
| Post-change real Google/recovery | PASS (service API + packaged startup) | Three independent Windows harness runs, 40 actual Google requests, three real refresh exchanges; sole appdata grant. Reused the earlier authorized Source logical secure record without copying it. New disposable Source/Restore data only. Full/settings encryption/upload/readback/list/download, wrong phrase, cancellation and selective settings/hotkey merge pass. New original Release applies full restore and finalizes receipt; all 44 tables/preferences and Before Restore contents match after a separate 15-second restart smoke. GUI unobserved. |
| Scoped cloud cleanup | PASS | Both new objects persisted across packaged recovery/restart, then exactly those two IDs were deleted after backup-ID/private-test-version checks. Every pre-existing object retained. |
| Windows CI | PASS | Final source 8d667df: analysis, 287 tests, 11 config/package gates, Windows Release, portable package, native self-test, Inno Setup compile and checksums. Downloaded candidate passed both SHA-256 sidecars/manifest, 37-entry portable CRC and config/runner/AOT hash receipt. CI uses disabled public config; it is not the enabled private build or a public app release. |
| Live updater check/download | PASS (real GitHub) | Production SoftwareUpdateService checks Stable/Pre-release for setup/ZIP: no update offered above current private 1.0.13. With an explicitly simulated older selector version, it finds actual public v1.0.12 and downloads both assets through approved HTTPS hosts, validating real size/SHA-256 and progress callbacks. No release metadata was invented/changed; no setup was executed. |
| Local portable update/recovery | PASS (real bundled helper) | Actual public v1.0.12 ZIP at a disposable path with spaces; repository-seeded synthetic data. Readiness/parent-exit handshake, deliberate expected-version mismatch/rollback/reopen, then complete v1.0.13 bundle swap/version check/restart pass. Every bundle file matches the private ZIP, all 44 table contents and selected preferences survive both cases, and the exact portable location/profile stays stable. Personal install registration and Windows Run registry hashes unchanged. This exercises the helper/service APIs, not the in-app update button or painted dialogs. |

Full-suite failure cases use mocks where stated by their tests. Real Google
results below are separate. Real consent and reconnect observed by the owner
in the previous private package remain historical evidence, not a new consent
test on this candidate.

Updater evidence: `updater-live-result.json`, `updater-live.log` and
`updater-local/acceptance{,-rollback,-success}.json` under the ignored run.
The rollback case intentionally supplies expected version `99.0.0` to a valid
private v1.0.13 package/stage; rejection restores the original public v1.0.12
bundle and reopens it. The subsequent normal expected-version case installs
the private v1.0.13 portable bundle locally. Neither is a new public release.
Planner fixture writes go through LifeRepository. Registered installed-mode
execution remains unverified: the same AppId would risk the personal per-user
registration. Its real helper preflight rejection, conflict and handoff tests
are covered in the passing suite. Public v1.0.13 updater discovery/download
cannot be checked while the release is deliberately unpublished.

Private run: `.buildlog/private-engineering-final-20261026-174228/`. Evidence files
`real-google-phase1.json`, `real-google-phase2.json`, `real-google-cleanup.json`
contain bounded checks, synthetic preferences, row digests and pseudonymous
account equality, not tokens or recovery phrases. The phrase stayed in memory
and was discarded after recovery staging. Only test-created cloud objects were
downloaded. Phase request counts: 27, 4 and 9 respectively. No post-change
browser sign-in or disconnect/reconnect is claimed; those unchanged flows have
the preceding owner-observed/package and real-service evidence plus mocks.

| Private artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.13-win-x64-setup.exe | 47,132,241 | `436207401892c97fbd800842c6106e851e7923945c1f5145a9f3f8fbaf3a24e0` |
| Todorbit-1.0.13-win-x64-portable.zip | 62,274,586 | `27dcee912a73072f5be28587dc7f0107115e07d1edf1ea03c005602eb882c481` |

Post-harness checks confirm every extracted Release file still matches the
private ZIP. Actual Desktop parameter values were absent from diagnostic logs;
bounded result files exclude access/refresh-token, client-secret and passphrase
fields. These checks are not a guarantee against arbitrary disguised private
data. Both new local synthetic profiles remain for review; all test processes
were closed. Tracked public config is disabled/empty, website/updater/auth/
crypto sources unchanged, no token record copied and no app release created.

Final reviewed source **`8d667df`** is on the existing feature branch. Main
remains `3f3f1cf`; latest public release remains v1.0.12. The initial engineering
CI was cancelled as superseded after the prefix edge case was reproduced; all
results and private hashes above describe the corrected final candidate.
[Final Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40342429612)
passes. Independently downloaded CI artifacts remain under `ci-candidate/` in
the ignored run, with `ci-integrity-summary.json`. They are disabled-config
builds and are not claimed byte-identical to enabled local packages.

## Clean Windows identity and GUI boundary

**SKIPPED by explicit owner decision; known unverified coverage.** Do not require
the owner to enable or launch Sandbox/VM testing for this release. The earlier
prepared handoff is unused historical preparation, not completed acceptance.
No VM, new Windows user, feature enablement, UAC change or reboot was performed
by the agent; no Sandbox process was launched. The personal registered
installation and real profiles remain untouched.

The supported Computer Use native pipe remains unavailable; app/browser
inventory is empty. This session cannot inspect or operate the rendered
Windows UI. No substitute GUI automation or invented visual pass is used.
Registered install/upgrade/uninstall, a genuinely fresh Windows credential
identity, machine prerequisites and trust/SmartScreen behavior are unverified.

Existing light/dark/narrow/large-text backup page and confirmation/cancellation
widget tests pass in the complete suite. They do not establish physical DPI,
keyboard/native input, actual progress painting, new browser consent, or live
backup/restore dialogs. These stay explicitly unverified under the owner's
local-only acceptance scope. Prior owner-observed browser sign-in/reconnect and
new real service/packaged startup evidence remain separate.

## Security and Google policy

The existing installed Desktop JSON still exists and matches project `todorbit`;
no fields or JSON contents are included in this report. Private build parameters
are compiled for users; Release exposes no developer import. Public config must
be restored disabled/empty after packaging. No user tokens/passphrase or full
Desktop JSON is permitted in packages, source, diagnostics or CI.

Reviewed unchanged controls: external-browser PKCE S256/state/loopback checks;
logical profile-keyed Windows DPAPI storage (legacy Credential Manager fallback);
sole drive.appdata permission/appDataFolder; random salt and nonce,
PBKDF2-HMAC-SHA256/600,000 and AES-256-GCM; bounded downloads; remote size/MD5 and
SHA-256 readback; wrong-phrase/tamper rejection; verified snapshots, Before Restore
and settings allowlist. This is a source/regression review, not an independent
cryptographic assessment. APPDATA redirection is not a separate Windows identity.

Dependency advisory recheck: OSV querybatch reported no listed vulnerabilities
for all **115 locked hosted Pub packages**; `dotnet list package --vulnerable
--include-transitive --format json` completed successfully with no vulnerable
packages reported by configured NuGet sources. Raw bounded summaries remain in
the ignored run. This checks published advisories, not unknown vulnerabilities,
Windows/SDK/runtime coverage or exploitability. Installer Authenticode status is
**NotSigned**; clean-machine trust/SmartScreen behavior remains unobserved.

Owner-reported External/In production/Drive API/Data Access state remains
unobserved in Console. Branding/domain ownership remains unverified. Google's
[Drive scope guide](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
lists drive.appdata as non-sensitive. Its
[production policy guidance](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance)
separately covers verified branding, owned domains/homepage and separation of
testing/production projects. Those are unresolved publisher policy questions;
this owner-authorized test reused the existing project/client as instructed.
No new project/client or domain was created. Real account access proves
technical behavior only; it does not establish policy compliance, universal
account eligibility, project quotas or long-term grant lifetime.

## Release decision

**Engineering automation/local private integration PASS; complete acceptance
PARTIAL; public release BLOCKED.** The reported initialization defect and the
schema-prefix validation case are fixed and tested; final CI and real local
portable update/rollback pass. Clean-user/VM and registered/manual GUI checks
are skipped/unverified under the owner's explicit local-only scope; no Sandbox
action is required and this is not an automatic engineering FAIL. Google
branding/public-policy review and explicit owner publication approval remain
unresolved. Broader account/Workspace eligibility, real quota/revocation/offline
interruption and multi-day grants
remain unmeasured beyond the listed mocked cases. No public policy compliance
is inferred from technical access. Keep v1.0.13 unpublished.
