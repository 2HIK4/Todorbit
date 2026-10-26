# Google Drive engineering follow-up — v1.0.13+14

2026-10-26, `feature/google-drive-production-readiness`. No main merge, public
release, Cloud configuration change or website edit is authorized. This record
supersedes the unresolved initialization issue in the earlier
[private acceptance report](GOOGLE_DRIVE_PRIVATE_ACCEPTANCE.md).

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
| Initialization regression | PASS | 20 new cases: fresh/zero-byte creation, four old partial creation stages, populated/incompatible schemas, corruption/future versions, existing upgrades/backup, six real process-death cases, repair retry and current data preservation. |
| Real process termination | PASS | Separate Dart processes killed during fresh creation and schema-1 upgrade after early/middle DDL and after version write before COMMIT. WAL recovery leaves schema 0 empty or original v1 rows/schema; normal reopen succeeds. Not a power-loss hardware test. |
| Original failure fixtures | PASS | Both preserved interrupted Source/installer-layout files were recovered in disposable copies to v21/44 tables with integrity OK. New packaged Release also recovered a copy through the actual startup gate/background executor; a populated v0 copy retained its row and exact schema. Error UI unobserved. Originals were not repaired/replaced. |
| Backup completeness regression | PASS | Missing reminder table in v20/v21 rejected without replacing source rows/schema or publishing a managed snapshot. Existing v20 import/migration passes. |
| Complete Flutter suite | PASS | 285/285, zero JSON error events, 485.500 seconds. Includes auth, secure-store mocks, local crypto/SQLite/cloud recovery, settings, migration, UI and profile checks. |
| Flutter analysis | PASS | No issues, 69.0 seconds. |
| Native Release | PASS | Zero warnings/errors; 14.94 seconds. |
| Configuration/package guards | PASS | 11 existing checks, tracked public configuration disabled/empty. |
| Private Windows Release/packages | PASS | Enabled Release (153.6s), Inno Setup 7.1.0 (44.234s), 37-entry portable CRC/full bundle equality, receipt/config/runner/AOT binding and SHA-256 sidecars. Source/Restore/copied installer layout each start/restart with separate empty v21/44-table profiles. Packaged widget self-test passes; Windows Run registration unchanged during smoke. This is not registered installer acceptance. |
| Post-change real Google/recovery | PASS (service API + packaged startup) | Three independent Windows harness runs, 40 actual Google requests, three real refresh exchanges; sole appdata grant. Reused the earlier authorized Source logical secure record without copying it. New disposable Source/Restore data only. Full/settings encryption/upload/readback/list/download, wrong phrase, cancellation and selective settings/hotkey merge pass. New original Release applies full restore and finalizes receipt; all 44 tables/preferences and Before Restore contents match after a separate 15-second restart smoke. GUI unobserved. |
| Scoped cloud cleanup | PASS | Both new objects persisted across packaged recovery/restart, then exactly those two IDs were deleted after backup-ID/private-test-version checks. Every pre-existing object retained. |
| Windows CI | PENDING | Run final feature-branch SHA with disabled public config; no release deployment. |

Full-suite failure cases use mocks where stated by their tests. Real Google
results below are separate. Real consent and reconnect observed by the owner
in the previous private package remain historical evidence, not a new consent
test on this candidate.

Private run: `.buildlog/private-engineering-20261026-170312/`. Evidence files
`real-google-phase1.json`, `real-google-phase2.json`, `real-google-cleanup.json`
contain bounded checks, synthetic preferences, row digests and pseudonymous
account equality, not tokens or recovery phrases. The phrase stayed in memory
and was discarded after recovery staging. Only test-created cloud objects were
downloaded. Phase request counts: 27, 4 and 9 respectively. No post-change
browser sign-in or disconnect/reconnect is claimed; those unchanged flows have
the preceding owner-observed/package and real-service evidence plus mocks.

| Private artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.13-win-x64-setup.exe | 47,131,934 | `43c5719b932293dd4bdeef53e737d4c99306d36ca9161074cc7409e17d421d49` |
| Todorbit-1.0.13-win-x64-portable.zip | 62,274,620 | `4512565bd73ef4f6b0c5346b506efb349606555541c65024ad41fd9e162ff9b9` |

Post-harness checks confirm every extracted Release file still matches the
private ZIP. Actual Desktop parameter values were absent from diagnostic logs;
bounded result files exclude access/refresh-token, client-secret and passphrase
fields. These checks are not a guarantee against arbitrary disguised private
data. Both new local synthetic profiles remain for review; all test processes
were closed. Tracked public config is disabled/empty, website/updater/auth/
crypto sources unchanged, no token record copied and no app release created.

Reviewed source/test/tool/documentation commit **`9a2b964`** was fast-forwarded
only to the existing feature branch. Two normal pushes hit GitHub internal
server errors; the supported Git Data API recreated the exact local tree and
commit SHA and updated the feature ref with `force=false`. Main remains
`3f3f1cf`; latest public release remains v1.0.12. The
[new Windows CI run](https://github.com/2HIK4/Todorbit/actions/runs/40340320929)
was superseded/cancelled after the additional schema-prefix regression was
found. Final source validation/CI is being repeated; enabled artifacts stay
local and CI uses disabled public config. Earlier 285-test/package/Google
results above describe the initial engineering candidate, not final acceptance
of the subsequent prefix fix.

## Clean Windows identity and GUI boundary

**PARTIAL / owner environment action required.** The supported Computer Use
native pipe still reports unavailable; app/browser inventory is empty. This
session cannot inspect or operate the rendered Windows UI. No substitute GUI
automation or invented visual pass is used.

The current token is non-elevated. Windows Sandbox and Hyper-V are installed as
optional features but disabled; no VirtualBox/VMware runner is available. No new
Windows user, VM, feature enablement, UAC change or reboot was performed. The
personal registered installation and real profiles remain untouched.

A guarded [Sandbox handoff](WINDOWS_CLEAN_ACCEPTANCE.md) prepares only the
installer, ZIP, hashes and smoke runner in a read-only mapping; it never maps the
repository, downloaded OAuth JSON or Windows token storage. It also maps one
dedicated empty results directory for bounded smoke evidence. The smoke runner
refuses host execution before any write. Its VM execution is **UNVERIFIED**.

Prepared local configuration:
`.buildlog/sandbox-acceptance-8043b55e0c0b46bbb4724fc01273083e/Todorbit-Acceptance.wsb`.
XML/mapping allowlist, package digest preparation, script parsing and refusal
on the host account pass. Enable Windows Sandbox and restart as described in
the handoff, then open this exact file; return its bounded `results/acceptance.json`
and complete the manual checklist inside the VM. This is the necessary owner
environment action, not a new publication permission request.

Existing light/dark/narrow/large-text backup page and confirmation/cancellation
widget tests pass in the complete suite. They do not establish physical DPI,
keyboard/native input, actual progress painting, browser consent, or live
backup/restore dialogs. Complete those in the clean VM using disposable records
and normal owner authorization, stopping on any Google warning/block.

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
PARTIAL; public release BLOCKED.** No known initialization defect remains from
the reported case. CI is pending. Clean-user registered installer/portable and
manual GUI acceptance, Google branding/policy review and explicit owner
publication approval remain release gates. Broader account/Workspace
eligibility, real quota/revocation/offline interruption and multi-day grants
remain unmeasured beyond the listed mocked cases. No public policy compliance
is inferred from technical access. Keep v1.0.13 unpublished.
