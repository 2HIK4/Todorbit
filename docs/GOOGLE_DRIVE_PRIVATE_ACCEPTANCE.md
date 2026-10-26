# Google Drive private v1.0.13 acceptance

> **2026-10-26 release update:** enabled v1.0.13 is now published as an
> owner-approved **experimental pre-release**, merged to main with website
> download updates. Public asset/updater/Pages verification passes.
> This supersedes the earlier publication hold below, while preserving
> every skipped/unverified test and unresolved policy limitation. See
> [the publication record](TODORBIT_1_0_13_PUBLICATION.md) and
> [release notes](TODORBIT_1_0_13_RELEASE_NOTES.md). Historical blocked
> conclusions below describe their earlier checkpoints.

**Engineering follow-up:** the initialization defect recorded below is now
fixed and regression-tested; see the newer
[engineering acceptance report](GOOGLE_DRIVE_ENGINEERING_ACCEPTANCE.md).
This document preserves the original private test evidence and its limits.

2026-10-26, production-readiness branch. This is a private test, not approval
to publish v1.0.13, merge app changes to main, edit the website or change Google
Cloud configuration.

**Final result: PASS for the private core Google Drive tests; PARTIAL for
complete packaged acceptance; public release remains BLOCKED.** The tested
external account connected and reconnected without a reported Google warning
or block. v1.0.13 remains unpublished.

## Configuration and permissions

Owner-reported Console state: **Todorbit**, project ID **todorbit**, External,
**In production**, Drive API enabled, only **drive.appdata** in Data Access.
Branding is unverified. Console state is not independently observed.

The existing external installed Desktop JSON exists, contains the required
Desktop parameters/localhost configuration and matches project ID `todorbit`.
No client/project was created. Only its two build parameters are reused;
complete downloaded JSON, tokens and passphrases are excluded from packages.

Source requests exactly `https://www.googleapis.com/auth/drive.appdata`, with
offline access, consent/account selection, PKCE S256 and a state-validated IPv4
loopback callback. No openid/email/profile, full Drive or drive.file scope is
requested. Account identity uses Drive's `about.user` with the existing scope.
All storage operations use `appDataFolder`. Release bundles its parameters and
has no developer JSON-import controls. Ordinary users connect and authorize.

Google classifies [drive.appdata as non-sensitive](https://developers.google.com/workspace/drive/api/guides/api-specific-auth).
Its [Audience guide](https://support.google.com/cloud/answer/15549945?hl=en)
separates production audience from verified name/logo display and sensitive/
restricted scope approval. The 100-new-user warning cap is described for apps
requesting unapproved sensitive/restricted scopes; do not infer that cap solely
from unverified branding. Workspace, Advanced Protection and other restrictions
may still apply. Actual consent behavior and this project's quota need evidence.

## Isolation and packaging

The existing three-field configuration is enabled temporarily for private
build/packaging, then restored byte-for-byte to disabled/empty in `finally`.
The enabled private config, packages, logs and test profiles stay ignored under
`.buildlog/`. No public CI/artifact upload or app publication is authorized.

Source and Restore launchers select separate APPDATA/LOCALAPPDATA roots and
location-keyed portable profiles, with widget sign-in launch disabled before
startup. Always restart through the launcher. Directly opening the EXE selects
a different data root. APPDATA redirection is not a fresh Windows Credential
Manager identity; token keys are isolated by absolute database path. Strict
fresh Windows-user/VM acceptance is a separate limit.

Reinspection of locked `flutter_secure_storage_windows` 4.2.2 found its primary
`DpapiJsonFileMapStorage` encrypts the JSON map using Windows DPAPI in the OS
application-support directory; native AES-GCM/Credential Manager storage is a
backward-compatible fallback/migration path. Thus the previous AES-GCM-only
description in release-readiness documentation was too narrow and is corrected.
Physical secure storage is Windows-user/application scoped; profile-path hash
keys isolate logical records. This test reads/refreshes only the authorized
Source record and does not enumerate unrelated credentials. The website's
generic Windows-protected-storage wording remains accurate and unchanged.

Compile the installer but do not run it on the personal Windows account.
Installer-layout smoke uses a copied Release bundle; it is not a registered
installer test. No personal installation, database or settings are used.

## Owner authorization checkpoint

**Completed (owner-observed):** the owner confirmed the isolated Source path,
used an account outside the previous OAuth test-user list and reported that
the private packaged v1.0.13 connected successfully. Google showed **no
unverified-app warning** and **no authorization block**. This is evidence for
that account/attempt, not a project-wide quota measurement or verification
approval. After the tested local disconnect, the owner authorized the same
account again in the isolated private Release package and reported successful
reconnection, the connected account displayed, **no security warning** and
**no authorization block**. The agent did not view either consent screen.
An independent post-reconnect process verified the same account, real refresh,
exact appdata-only grant and retention of both snapshots before cleanup.
No Google security or verification control was bypassed.

## Acceptance checklist and evidence boundary

The full and settings-only packaged procedure remains in
[release readiness](GOOGLE_DRIVE_RELEASE_READINESS.md#required-packaged-acceptance--unverified)
for manual completion using only disposable profiles. Create tasks/events/relationships
through the app, recognizable preferences/hotkeys, and separate encrypted full
and settings-only snapshots with a privately retained recovery passphrase.
Verify upload/readback completion, listing, download, wrong-passphrase rejection,
preview cancellation, full restore after restart, all 44 tables/personalization,
Before Restore preservation and finalized startup receipt. Settings-only
recovery must preserve all task/event rows and unrelated settings, including
selective categories/hotkey merge.

Confirm token/account/history persistence after launcher restart, a real refresh
after token expiry (restart alone does not prove refresh), disconnect/reconnect
and retained history. Never delete pre-existing cloud objects. Scope historical
debug-client results, automated SQLite/crypto round trips and mocked auth/
transfer failures separately from real enabled packaged evidence. Record any
Google warning or limitation; one account's success cannot establish project
cap usage or unrestricted availability.

## Evidence status

| Check | Status | Evidence boundary |
| --- | --- | --- |
| Source/config inspection | PASS | Existing Desktop JSON matches todorbit; exact appdata-only request; bundled Release parameters and no developer import. |
| Flutter analysis | PASS | No issues, 125.9 seconds. |
| Full serial Flutter suite | PASS | 264/264, zero JSON error events, 466.371 seconds. Includes 12 auth/Drive mock tests, 4 cloud SQLite/crypto round trips, 3 cloud UI tests, 10 local backup tests, 3 settings transfer tests, 6 privacy and 4 profile-isolation tests. |
| Public configuration/package guards | PASS | 11 existing enabled/disabled/malformed/private-file/stale-receipt checks. |
| Native Release | PASS | Zero warnings/errors. |
| Enabled Windows Release | PASS | Existing wrapper, compiled v1.0.13+14 with the existing project/client parameters. |
| Private installer/portable | PASS | Inno Setup 7.1.0; ZIP CRC (37 entries), complete Release bundle equality, enabled config/runner/AOT receipt, known private-file exclusions and SHA-256 manifest/sidecars. |
| Disposable normal startup/restart | PASS (process/schema smoke) | Source, Restore and copied installer layout each start/restart with v21, 44-table empty databases and integrity OK. Extracted widget self-test passes; Windows Run registry unchanged. No rendered GUI claim or registered installer acceptance. |
| Interrupted first initialization | FAIL (unfixed recovery case) | First fixed-delay smoke force-killed initialization; incomplete schema 0 was rejected on restart. Fixtures retained; final normal smoke uses fresh profiles and schema readiness, which does not fix interruption recovery. |
| Real packaged Google sign-in | PASS (owner-observed) | Owner confirms isolated Source path and an account outside the old test list: connected, no unverified-app warning, no block. Agent did not inspect the consent screen. Project quota/cap remains unmeasured. |
| Real Windows secure-session load/refresh/list | PASS (service harness) | Independent Windows harness loaded the production Source secure record after packaged app exit, performed one real refresh exchange plus account identity check, and listed appDataFolder. Three real Google requests; no mocks. |
| Real encrypted backup/transfer | PASS (service harness) | Full and settings snapshots uploaded to real Google appDataFolder; production provider verified size/MD5, SHA-256 readback and verified metadata. Both listed and downloaded; ciphertext excluded plaintext test labels/passphrase. 27 real requests in phase 1. |
| Wrong passphrase and cancellation | PASS (service APIs) | Real downloaded full ciphertext rejected the wrong phrase with target data/settings unchanged. Preview without confirmation and scheduled-restore cancellation preserved target state. No confirmation-dialog UI interaction is claimed. |
| Real settings-only recovery | PASS (service APIs) | Real downloaded settings payload had no DB; hotkey name collision merged, calendar-only application worked, all SQLite rows and unrelated preferences stayed unchanged. Settings upload created no SQLite snapshot. |
| Real full recovery | PASS (packaged startup + service verification) | Original private Release applied the downloaded/staged full snapshot on Restore startup. All 44 tables and supported personalization matched. Before Restore matched every previous target table and settings JSON; receipt finalized opened; device cloud profile ID was not copied. |
| Session/history persistence | PASS (real Windows processes) | Independent harness processes load the same Source account, force real refresh/identity and list both objects after packaged restoration. The original package also launched normally again after recovery; all 44 tables/preferences and finalized receipt still match. |
| Actual granted scope | PASS | Google's stored token response after real refresh contains exactly https://www.googleapis.com/auth/drive.appdata. No extra scope was returned. |
| Real disconnect | PASS (production service/storage) | Production disconnect cleared Source account/session; a new GoogleDriveAuth using the same Windows secure store loaded no session. No planner data or Google grant was deleted. |
| Real reconnect | PASS (owner-observed + real service verification) | Owner reports same-account reconnect and displayed account with no warning/block. Independent secure-session load, real refresh/identity and listing confirm the same account, sole appdata grant and both retained snapshots. |
| Scoped cloud cleanup | PASS (real Google API) | Deleted only the exact two object IDs created by this run after checking their backup IDs/private test version. Listing confirms both removed and every pre-existing object retained. Reconnect verification/cleanup used 9 real requests and one refresh exchange. |

Initial build failed because this non-elevated Windows session cannot create
plugin symbolic links. Restored generated directory links as ordinary local
NTFS junctions to the installed pub cache; the normal build then passed. No
SDK/app code, Windows security setting or Google OAuth control was changed.

Full-suite auth/Drive networking uses mocks; SQLite/cryptography round trips
execute actual local implementations. Neither is a real Google grant.

The first smoke helper force-stopped fresh initialization after seven seconds.
Source and installer-layout fixtures were left with partial schema version 0;
the app's existing migration gate rejected them on restart. Both empty fixtures
were preserved under the ignored run's `interrupted-startup/` directory and
fresh profiles prepared. The corrected helper waits for schema v21/44 tables
and drains normal engine stderr directly (PowerShell 5 can otherwise promote
the engine notice to a terminating parent error). Interrupted first-start
recovery remains a recorded usability/reliability limitation, not a Google
authorization or cloud-restore result. No production database was involved.

Private local run: `.buildlog/private-drive-20261026-151411/`. The ignored
`packages/` folder contains the installer, ZIP, manifest and two sidecars:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.13-win-x64-setup.exe | 47,125,384 | `6748063e5b3bacf47672f9c90ea4e56040f2ab7186fcf8ab7746292363f9c1c3` |
| Todorbit-1.0.13-win-x64-portable.zip | 62,272,218 | `4d29909dd56443ef48f58fc27959fd8e973c2839feacdef41ae1d1a5d42b1be5` |

Final post-reconnect verification rechecked both hashes, ZIP CRC and every
extracted Release file against the ZIP. Both active disposable databases still
have integrity OK, schema 21 and 44 tables. All six bounded real-Google result
files pass; 13 diagnostic logs contain neither actual Desktop parameter value.

Source launcher: `powershell -NoProfile -ExecutionPolicy Bypass -File .buildlog/launch-private-drive.ps1 -Profile Source`
(use `-Profile Restore` for the separate target after closing Source). The
launcher drains application diagnostics without logging during consent. The
owner verified the Source path containing
`acceptance/Source/Roaming/TodoPilot/portable-d9466644fb3f8f37` for initial
authorization and reconnect. The private app is now closed; the reconnected
Source session and synthetic local Source/Restore fixtures remain for review.

Private core tests **PASS**; complete packaged acceptance remains **PARTIAL**.
Real cloud recovery, refresh, restart, disconnect and reconnect passed.
App-control inventory remains empty
and the supported Computer Use plugin reports its native pipe unavailable.
The private Windows service harness therefore exercises production Dart/cloud/
repository/secure-storage code directly. It is not automated interaction with
the packaged backup/settings dialogs. The original Release packages stay intact.

The harness is a separate Debug test entry point in the ignored `.buildlog/`
directory, built into `build/windows/x64/runner/Debug/`; it is not part of the
Release candidate or an end-user configuration requirement. It uses bundled
parameters and the real production Source secure-token store, no imported
developer configuration and no mocked HTTP. Source and Restore were empty
before seeding; persistent planner writes used `LifeRepository`. Only the two
new objects recorded in `real-google-phase1.json` were downloaded. No existing
cloud object was modified or downloaded. The randomized recovery phrase stayed
in process memory, was never logged/persisted, and was discarded after staging
and testing recovery. After proving retention across disconnect/reconnect,
exactly those two test objects were deleted. Pre-existing cloud objects remain.

Direct evidence is in the ignored run's `real-google-probe.json`,
`real-google-phase1.json`, `real-google-phase2-first.json`,
`real-google-phase2.json`, `real-google-disconnect.json` and
`real-google-cleanup.json`. These record only
checks, test object identifiers, row digests, test preferences and pseudonymous
account equality; no access/refresh tokens or recovery phrase.

Real HTTP counts: probe 3, upload/recovery staging 27,
first recovery verification 4, post-normal-restart verification 4, disconnect
phase 3, reconnect verification/cleanup 9: **50 requests and six real refresh
exchanges** across six harness runs. Each phase completed account identity
verification. These are actual Google API requests, not new consent grants or
user-cap measurements. The Source/Restore fixtures each now contain five test
tasks plus synthetic related records; every one of the 44 tables (including
empty tables) matched the uploaded source snapshot after packaged recovery.

Technical conclusion: this observed outside-old-test-list account can use the
bundled private client and real Drive backup/recovery while branding is
unverified. No warning/block was reported by the owner on initial consent or
reconnect.
This does not establish every Google/Workspace account's eligibility, project
user quota, multi-day grant lifetime, UI acceptance or policy/branding approval.
No app source, version, website, public release, main branch or Cloud setting
was changed. Tracked OAuth configuration is restored to disabled/empty.

## Release blockers at the original private checkpoint

- **Unfixed first-start interruption recovery:** a force-stop during initial
  database creation can leave a partial schema-0 profile that startup refuses
  to open. Fix and verify safe recovery without silently discarding user data.
- **Packaged/manual acceptance incomplete:** run the enabled installer and
  portable build in a fresh Windows user/VM. Complete rendered backup/settings
  dialogs, confirmations, progress/errors, keyboard, light/dark and DPI checks.
  APPDATA-isolated service tests and copied installer-layout smoke do not
  replace these checks.
- **Branding and policy unresolved:** no verified branding/domain or Google
  approval is claimed. This account's successful authorization does not settle
  public-distribution policy. Project-wide quotas/user limits, other account
  policies, multi-day persistence and real revocation/offline/quota failures
  remain unmeasured; failure-path mocks are separate evidence.
- **Publication held by owner:** public configuration stays disabled/empty.
  Final reviewed configuration, CI on the final app SHA and explicit release
  approval are still required. No v1.0.13 tag, public artifact or updater entry
  was created.

Recommendation: keep v1.0.13 private, fix first-start interruption recovery,
then finish fresh-user packaged/UI acceptance and the public policy review.
There is no remaining owner sign-in action for this private test. Public
release readiness remains **BLOCKED**.
