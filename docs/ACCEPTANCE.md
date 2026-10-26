# Windows v1.0 final acceptance record

## Google Drive production candidate (2026-10-26)

Candidate **1.0.13+14**, on `feature/google-drive-production-readiness` from
`198da07`. Public OAuth is **BLOCKED**, not a release PASS. Owner reports
project Todorbit is Testing, Branding URLs are missing, Data Access is empty,
and External status is not independently confirmed. A valid Desktop JSON was
found outside Git, read only for validation, and not bundled. Public config is
disabled/empty; Release hides developer import. No website/app publication,
Google production change, personal installation or production profile change.

| Boundary | Status | Evidence and limits |
| --- | --- | --- |
| Public-client distribution | PARTIAL | Bundled ID/parameter exchange and refresh/restart/reconnect pass mocked tests without a config store. Package gates bind reviewed config to runner/AOT hashes. Actual public client remains disabled pending Google production and clean packaged acceptance. |
| Security/data recovery | PASS (source/automated; historical real evidence retained) | Existing PKCE/state, secure tokens, appdata-only transfers and authenticated encryption retained. Historical real full/settings recovery from 198da07 remains evidence for unchanged service/format, including all 44 tables. New packaged production-client recovery is UNVERIFIED. |
| Consolidated checks | PASS | Focused auth/UI 15/15, config/package gates 11/11, analysis clean, one final serial Flutter suite 264/264 (07:54), zero JSON error events. Existing nonfatal scroll hit-test warnings remain. |
| Native/Windows builds | PASS | Native Release zero warnings/errors, isolated source self-test exit 0; gated Windows Release passed. |
| Candidate packages | PASS | Inno Setup 7.1.0 compile; 37-entry portable CRC and full Release-bundle byte equality; extracted widget self-test; configuration receipt; manifest and per-package SHA-256 checks. Exact-value source/package scan found no owner Desktop parameter. |
| Isolated startup/restart | PASS | Installer-layout bundle and extracted portable at paths with spaces each opened/reopened their intended empty 44-table SQLite profile, integrity OK. Native startup disabled in disposable profiles; actual Windows Run registration unchanged. Not a registered setup/upgrade/uninstall or strict clean Windows-user test. |
| Backups & Cloud visuals | PARTIAL | Narrow 440 px/1.3x dark/light widget checks pass. Physical Release GUI, DPI and native input/Explorer acceptance remain UNVERIFIED; Computer Use native pipe and browser unavailable. |
| Website | PARTIAL | Prepared three-page responsive static site and manual-only Pages deployment; local links/anchors, semantic structure, image metadata, static-only resources and theme contrast pass. Rendered browser/zoom/screen-reader checks and publication/domain verification remain UNVERIFIED. |
| Public release/updater | BLOCKED | No v1.0.13 tag/release/deployment exists. Latest published remains v1.0.12; no new update to discover. |

Initial [Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40291855078)
passed all app checks through packaged self-test, then **FAIL** at compiler
bootstrap because Chocolatey does not carry Inno Setup 7.1.0. Corrected bootstrap
uses the official vendor x64 asset, pinned SHA-256 and explicit compiler path;
local download-only integrity verification passes. A second attempt installed
the official compiler but failed its capped PowerShell version probe. The probe
now captures complete native output and the actual process exit code, retains
the exact 7.1.0 requirement, and runs before expensive app checks.

**Final [Windows CI](https://github.com/2HIK4/Todorbit/actions/runs/40296394097)
PASS at `63b8bc6`:** official compiler integrity/install/version, analysis,
**264 tests**, 11 config gates, Windows Release, portable package, native
self-test, installer compile, checksums and candidate artifact upload. The
downloaded five-file CI artifact passed both package SHA-256 sidecars/manifest,
37-entry portable CRC, disabled OAuth receipt and runner/AOT hash checks.

[Website validation CI](https://github.com/2HIK4/Todorbit/actions/runs/40293992419)
passed; deploy was skipped. Local HTTP checks returned 200 for all pages/assets
and HEAD checks returned 200 for both actual public v1.0.12 download targets.

Unpublished local artifacts:

- Installer: 47,009,648 bytes; SHA-256 `ed1e4001c79b364e9eaf316c35c83777a36f67c69cef165bd6dcf6cadae02e30`.
- Portable: 62,102,671 bytes; SHA-256 `604f8d02faf61fae011cd8769e296b4c24ef02dc535a75c48f84da376a8b7450`.

Downloaded unpublished CI artifacts (separate builds, not claimed byte-identical
to local output), under `.buildlog/ci-release-candidate/`:

- Installer: 47,042,780 bytes; SHA-256 `38b0cbe74b01ccddb6d57263435a9a41e94f66caf7641b027ff3de4fe24976fc`.
- Portable: 63,978,846 bytes; SHA-256 `2a1834426d99df2616b56bc6221e6ecbc91c4470bdb3ba6090bf4b5b471d31b4`.

Exact Cloud actions and strict packaged reproduction are in
[GOOGLE_DRIVE_RELEASE_READINESS.md](GOOGLE_DRIVE_RELEASE_READINESS.md).
Website review/publication instructions are in [website/README.md](../website/README.md).

## Google Drive backups feature (2026-10-25)

| Boundary | Status | Evidence and limits |
| --- | --- | --- |
| Settings > Backups & Cloud / local backups | PASS | Existing local panel embedded, main-sidebar entry removed; isolated live create/verify, recovery receipt, light/dark inspection and narrow 440 px / 1.3x widget checks. |
| Google Desktop sign-in, refresh and secure persistence | PASS | Owner completed real system-browser PKCE consent; forced refresh and profile restart succeeded. Client-secret requirement was discovered against Google and handled by a validated device-local secure configuration import. Credentials stay out of snapshots/binaries/source. |
| Full cloud round trip | PASS | Real upload/readback/download/decryption; wrong-passphrase rejection; explicit preview and confirmation; actual app close/reopen; all 44 SQLite tables matched the uploaded snapshot with IDs/relationships intact, personalization restored and actual opened receipt. Before Restore and settings recovery files verified. |
| Settings cloud round trip | PASS | Real separate upload/download; category preview, canceled confirmation, selected calendar/hotkeys application and conflict merging; complete database digest and unrelated appearance unchanged. |
| History, disconnect/reconnect, deletion | PASS | Both real objects remained after disconnect and reconnection; explicit deletion cancellation/confirmation exercised, then only the two generated disposable objects removed. Both test profiles' tokens and client configuration were cleared. |
| Error cases and profile isolation | PASS (automated) | Final analysis clean and all 262 serial Flutter tests passed. Mocked OAuth cancellation/state errors, expiration/revocation/401 refresh, account switching, paging, offline/quota/interrupted transfer errors; encryption tamper/format/schema gates and isolated profile round trips. Real quota/revocation/account switching/interruption remain UNVERIFIED. |
| Packaging / platform acceptance | PARTIAL | Final configured Windows Release and native build passed; packaged widget self-test exited 0 on an isolated profile. Release bundle and staged source/profile scans excluded the real client secret, disposable passphrase and database/credential files. Real Release GUI, installer/portable packaging, physical DPI/resizing, Android and production OAuth publishing remain UNVERIFIED. |

Setup, format/attachment limits, exact procedure and current evidence are in
[GOOGLE_DRIVE_BACKUP.md](GOOGLE_DRIVE_BACKUP.md). Several Flutter Driver timing
and serialization failures required scoped retries/restarting a disposable
driver; final application runtime inspections were clear. The installed app and
production profile were not changed. This feature branch is not published.

## v1.0.12 UI polish pre-release (2026-10-25)

- Release commit/tag: `ebba16e` / `v1.0.12`, version 1.0.12+13. Feature branch pushed and fast-forwarded into main. Main Windows CI passed analysis, all 245 tests, Release build, and packaged native self-test; duplicate feature CI for the identical SHA was canceled. Tag Windows CI also passed the same gates. [Published v1.0.12](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.12). CI: [main](https://github.com/2HIK4/Todorbit/actions/runs/40194712436), [tag](https://github.com/2HIK4/Todorbit/actions/runs/40195355512).
- Reused the completed local 245-test run, analysis, and isolated dark/light UI inspection. Built the new versioned Release bundle once. Both executables report 1.0.12+13; packaged widget self-test passed under isolated APPDATA/LOCALAPPDATA. Inno Setup 7.1.0 compiled the unsigned installer. Portable ZIP passed CRC, all 34 entries, private-data exclusions, complete bundle byte equality, and embedded helper equality.
- The final ZIP passed the disposable same-version portable helper swap: widget exit, main app automatic restart at the same path, seeded task, SQLite integrity, startup-off preference, and sentinel preservation. This is not a registered installer upgrade or the exact Settings button handoff. No personal installation or profile was modified.
- Installer: 46,904,583 bytes, SHA-256 `376ea4c31d8959d013e0efe28cfbf94de4b9ee2d58aadcdf6a0c0c6445f416d4`. Portable: 61,967,723 bytes, SHA-256 `3a1f31ace88e9753c57b78d25a7dc215698e258cffa9a2d4ac22c1c79dde3575`.
- All four public assets were downloaded and matched local sizes, SHA-256 hashes, GitHub asset digests, and the checksum manifest. The same `SoftwareUpdateService.check` used by Check for Updates selected v1.0.12 for v1.0.11+12 on Pre-release for both package types; `download` validated both packages. Version 1.0.12+13 reported current for both packages, and Stable ignored the pre-release. This checks the real public update service, not a click on the installed application's Settings button.
- Physical resizing/DPI, Release GUI pixels, native widget input/Explorer hosting, Windows sign-in, enabled-lock PIN layout, Windows 10, and registered installer upgrade/uninstall remain manual acceptance limits. Packages remain unsigned.

## UI audit verification follow-up (2026-10-25)

Continues `56a27d0` on `feature/app-ui-layout-audit`. The eight failures in the completed 237/245 run were:

| Test file and exact test name | Diagnosis and correction |
| --- | --- |
| `backup_service_test.dart`: schema 20 import restores an event and recurrence before migrating | 30-second timeout during file-backed restore/migration under the custom workspace-drive temp root. Passed in the normal Windows temp directory with the unchanged timeout. |
| `import_export_test.dart`: full SQLite export imports through reviewed restore | Same storage-latency timeout; unchanged assertions and timeout pass with normal temp. |
| `privacy_test.dart`: failed-attempt delay survives restart | Fixture shared-state race: the original manager's heartbeat remained active while the restarted manager used the same store. Per-manager queues did not coordinate their identical PID-based temporary filenames. Stop/drain/dispose the old owner before constructing the next; assert single fixture ownership and clean up managers even on assertion failure. The original OS error 32 did not identify the locking process, so additional external interference cannot be excluded. |
| `profile_isolation_test.dart`: a new data root starts empty while an existing root keeps its task | Storage-latency timeout while opening/reopening disposable databases; unchanged assertions and timeout pass with normal temp. |
| `task_relationships_test.dart`: disposable v4 projects, tasks, sessions and history migrate to v15 | Storage-latency timeout during disposable schema migration; unchanged assertions and timeout pass with normal temp. |
| `task_resources_test.dart`: portable transfer includes attachment bytes and rejects tampering | Storage-latency timeout during file-backed transfer; unchanged assertions and timeout pass with normal temp. |
| `task_resources_test.dart`: blocked restore keeps live attachment and pending request | Storage-latency timeout during file-backed restore; unchanged assertions and timeout pass with normal temp. |
| `workspace_test.dart`: narrow editor keeps unsaved fields after saving prerequisites | Test interaction timing exposed by increased spacing: it tapped before scrolling settled, missed the expander, then found the background task title. `56a27d0` already added settling and a hittability assertion; keep that correction. No application regression found. |

The six timeout cases had unique disposable roots and no failed data assertions. The earlier custom-temp run took 20:37, versus 00:53 for all 43 focused checks with normal temp and the original 30-second timeout in this follow-up. This supports environment-sensitive I/O timing, not evidence of a storage logic regression; the process responsible for the original delays was not captured. No timeout increase, retry-on-failure, skipped test, or weakened assertion was introduced. Flutter test/build/analyzer processes run sequentially here to avoid native-asset contention seen in the earlier session.

The privacy widget fixture also now awaits shutdown before provider unmount, so its synchronous disposal cannot leave an unawaited session write racing temporary-directory deletion. Production code is unchanged. Previous isolated UI screenshots and Windows Release build remain applicable; no repeat build or visual pass is needed. Physical resizing/DPI, Release GUI, native widget behavior, and enabled-lock PIN layout retain their prior unverified status.

Verification results:

- Focused affected groups: 43/43 passed at the original timeout; after the final widget cleanup adjustment, Privacy: 6/6 passed.
- One final full serial run: **245/245 passed**, zero error events, 04:35. Command: `flutter test --no-pub --concurrency=1 --reporter expanded --file-reporter json:.dart_tool/ui-audit-verification.json`. No retries or timeout overrides. The ignored local JSON report retains individual test results.
- `flutter analyze --no-pub` passed with no issues. Existing nonfatal hit-test warnings remain in Smart Reschedule and the workspace invalid-duration test; no warnings were suppressed.
- Build and visual evidence from `56a27d0` reused because only test fixtures and documentation changed. No production profile, installation, or application settings were accessed.

## v1.0.11 updater handoff (2026-10-24)

| Check | Result | Evidence and limit |
| --- | --- | --- |
| Same-path process conflict | PASS | Focused Windows test runs a disposable `Todorbit.exe` process and confirms the helper refuses the handoff with its PID. |
| Launch during update | PASS | Isolated Release app exits before opening a profile while the helper mutex is held; the helper restart opens one app. The executable is released before replacement. |
| Portable helper swap and profile | PASS | Final ZIP swapped at one disposable path after a running widget exited, automatically reopened Todorbit, and retained a seeded task, valid SQLite database, sentinel, and disabled widget startup preference. |
| Portable failure recovery | PASS | A forced version mismatch after handoff rolled back the binary folder and automatically reopened one previous app with the seeded task and profile intact. |
| Registered installer upgrade and exact in-app button | UNVERIFIED | This Windows account already contains the personal registered installation. Use a disposable Windows account or VM with an older registered Todorbit, seed a task and event and save a backup, then exercise Settings > Software Updates > Update and Restart. Verify one main app and widget, version 1.0.11, profile path, records, themes and settings, plus retry and genuine duplicate-process behavior. Do not use the personal installation for this test. |

## v1.0.9 release acceptance (2026-10-24)

| Original issue | Result | Evidence and remaining check |
| --- | --- | --- |
| Dropdown placement, Update Channel | PARTIAL | The exact Settings control was opened and selected through Flutter Driver in isolated dark and light 1264 × 681 debug GUI runs; screenshots show the menu below the field. A 700 × 650 Windows window opened the menu above the field near the bottom while keeping its label and selected value visible. Shared widget tests cover mouse, keyboard, a 350 × 400 viewport, bottom-edge placement, and 1.3× text scale. Physical DPI remains unchecked. |
| Settings and form spacing | PARTIAL | The exact Update Channel label/field gap and Backup & Restore Import SQLite spacing were inspected in dark and light isolated debug GUI screenshots. Narrow live-window Backup rendering remains to check. |
| About this view, Habits and Goals | PARTIAL | Their individual widget flows and dark/light debug GUI interactions opened and closed the shared information popover; screenshots show both popovers in place. Calendar and Reports use the same control. Physical keyboard interaction remains to check. |
| Widget launch at Windows startup | PARTIAL | Native private-key self-test covers default on, saved off, toggle, duplicate prevention, and stale-path repair. The command starts `TodorbitWidget.exe --widget`, not the main app, and the existing profile-suffix mutex protects a single instance. A real Windows login and registered installer upgrade require an isolated account/VM. |
| CI updater preflight | PASS | The helper now computes SHA-256 through .NET rather than `Get-FileHash`; local preflight and the complete feature, `main`, and tag Windows CI runs passed. |
| Public pre-release and update detection | PASS | v1.0.9 was published from `main` commit `1a41569`. All four public assets downloaded and matched local SHA-256 hashes. `SoftwareUpdateService` selected v1.0.9 for v1.0.8 on the Pre-release channel, downloaded and verified the installer in a temporary directory, and reported v1.0.9 up to date. |
| Installed v1.0.8 update to v1.0.9 | UNVERIFIED | The personal registered installation was not touched. Use a disposable Windows account/VM for the complete installed Update and Restart flow; a portable helper test is not equivalent. |

## Updater repair and v1.0.8 pre-release checkpoint (2026-10-24)

| Check | Result | Evidence and limit |
| --- | --- | --- |
| User's v1.0.6 procedure and failure | PASS (diagnosis) | Pre-release selection, download, Update and Restart, and unsigned confirmation were the intended actions. The personal installed binary is still 1.0.6 and its v1.0.7 helper was staged with no result file. Disposable Dart detached launches returned a PID but did not execute even a minimal PowerShell file; normal launches did. The missing installer is explained by the failed handoff. |
| New helper startup and error handoff | PASS (automated) | A Windows process test exercises ready acknowledgment and continued execution, plus failure before acknowledgment. A mismatched registered path produces a written failure without a ready receipt. |
| Installer completion, cancellation, UAC rejection, and post-install version | UNVERIFIED | Version verification and recovery are implemented, but a real registered upgrade was not run. The current user owns a personal registered installation at the stable AppId and path. Do not replace it for testing. Use a disposable Windows user or VM with an isolated v1.0.6 install and profile. |
| Portable replacement, restart, and profile | PARTIAL | The helper swapped real 1.0.6 → 1.0.7 and 1.0.7 → local 1.0.8 ZIP bundles at disposable paths. The latter profile had a repository-created task and fixed event, update settings, and a sentinel; they remained after automatic restart, with product version 1.0.8+9 and one app process. A wrong digest failed with a receipt and reopened the available app; a repeated helper swap succeeded. The in-app button was not exercised with an available 1.0.8 release. |
| Software Updates action and Markdown | PARTIAL | Narrow 460 px widget test at 1.3 text scale verifies collapsed release headings, Details expansion, and action presence. A live isolated debug screenshot covers the current-version dark Settings screen; available-release live pixels, mouse, keyboard, and DPI remain unchecked. |
| Full application and packaging | PARTIAL | Final analyzer, serial Flutter suite, Windows Release, native widget self-test, Inno package, and portable ZIP checks are recorded in `docs/PROGRESS.md`. An installed upgrade still gates release claims. |
| v1.0.8 pre-release publication | PASS (distribution only) | Feature commit `9d989e1` was merged into `main` at `3d24650` and tagged `v1.0.8`. All four GitHub assets were downloaded after publication; installer, ZIP, checksums, and notes matched local SHA-256 digests. This does not establish installed-upgrade or in-app-button success. |
| Tagged-merge Windows CI | FAIL (one test) | Analysis passed, but helper preflight expected a registration error and instead received `Get-FileHash` not recognized from the CI PowerShell process; 237 tests passed and one failed. Local full and focused suites passed. The CI environment cause remains unresolved, and the helper requires that command at runtime. |

For installed acceptance, create a disposable Windows account or VM with no Todorbit registration. Install the published v1.0.6 setup there using that account's isolated `%APPDATA%` and `%LOCALAPPDATA%`. Create a named task, fixed event, custom theme, and widget preference, then save a verified SQLite backup. From v1.0.6, choose Pre-release, download the target update, and confirm. Because v1.0.6 contains the broken handoff, first manually install a build containing this repair at the **same** AppId/path; then use the repaired in-app updater to upgrade to a later version. Observe installer completion, automatic restart, executable version, restored profile/data, widget state, and one app/widget process. Repeat with installer cancellation, rejected permission, missing package, corrupt digest, running widget, and interrupted setup. Keep the account/VM disposable and never run these checks against the personal installation.

## Settings, backup, and UI audit checkpoint (2026-10-24)

| ID | Result | Evidence and limit |
| --- | --- | --- |
| 01 Fresh Trash/profile isolation | PARTIAL | A fresh isolated debug profile and direct SQLite query had zero records in the user tables and deletion tombstones. The provenance of the user's existing Trash records is unknown because the personal profile was not opened. |
| 02 Calendar header position | PASS | Isolated debug GUI showed unchanged Day control coordinates and adjacent header alignment in Day, Week, and Month; a geometry widget test covers the mode changes. |
| 03 Calendar mode dimensions | PASS | The shared mode control no longer changes height in the geometry test; isolated debug screenshots show the same bounds through all three modes. |
| 04 Custom Event Color | PARTIAL | Live light-theme Primary/Wheel switching, HEX entry, preview, confirmation, and closing worked without a new disposal error. Accent switching and closing are covered by a widget test. A live dark-theme color dialog and physical input remain unchecked. |
| 05 Hotkey presets | PARTIAL | A live disposable profile created a named preset and persisted its active name; unit and widget tests cover binding, conflict, rename/delete, and shortcut dispatch. Full live restart and every preset operation remain unchecked. |
| 06 Reset hotkey state | PARTIAL | Live Default reset buttons appeared disabled; a widget test confirms modified becomes enabled and reset returns to disabled. Live modified-state mouse interaction remains unchecked. |
| 07 Shareable settings | PARTIAL | Allowlisted JSON export/import, schema and size rejection, category selection, persistence, and hotkey merge have focused tests. The dark-theme dialog was inspected live; native file picker interaction remains unchecked. |
| 08 Backup clarity | PASS | Isolated debug GUI showed grouped actions, human dates, collapsed technical details, a restore result, and Before Restore/Before Upgrade history. |
| 09 Restore restart flow | PARTIAL | Staged restore is explicit and shows pending/completed states. Manual close and reopen remain required; automatic restart was not implemented. |
| 10 Schema 20 restored events | PASS | A disposable schema 20 snapshot with a weekly event and task restored through debug startup, received upgrade approval, migrated to schema 21, and displayed the event in Day Calendar. Read-only queries confirmed records and the Before Restore recovery copy. This does not identify the cause of the user's earlier missing events. |
| 11 Sidebar Backups alignment | PASS | Live dark-theme sidebar shows Backups aligned with the Settings utility row after applying their shared padding pattern. |

These are debug GUI and automated checks on disposable profiles. Release pixels, native file dialogs, physical DPI/window resizing, and installed v1.0.6 update behavior are separate release checks; they are not established by this table.

The v1.0.7 release gate passed `flutter analyze --no-pub`, all 234 serial Flutter tests, native .NET Release with zero warnings, Windows Release, and source and packaged widget self-tests. Inno Setup 7.1.0 compiled the installer; the 34-entry portable ZIP passed archive integrity and private-file checks. Package hashes are in the published `SHA256SUMS.txt`. Native file picker interaction, registered installer upgrade, and physical widget/DPI behavior remain unverified on a disposable Windows user or VM.

The v1.0.7 pre-release was published from `66f4693`. All four public assets were downloaded and matched local SHA-256 hashes and GitHub digests. The live update service selected v1.0.7, release notes, and the exact installer/portable package from the GitHub API for a v1.0.6 Pre-release user; a public installer download completed with progress callbacks and digest verification. It reported v1.0.7 as up to date. The installed v1.0.6 Settings screen, update confirmation, installer launch, profile preservation, and post-update widget/process state remain UNVERIFIED because this account's registered installation was not modified.

## v1.0.6 release checkpoint (2026-10-24)

`flutter analyze --no-pub` found no issues; all 229 serial Flutter tests passed with the existing nonfatal workspace scroll hit-test warning. Native .NET and Flutter Windows Release builds passed, as did source and packaged widget self-tests. Inno Setup 7 compiled the installer. The portable ZIP passed its archive integrity check and contains the executable, widget, Flutter/SQLite runtime, update helper, licenses, and portable marker; no profile database, settings, logs, or keys were found.

A same-path disposable portable update using the locally built 1.0.5 ZIP and the new 1.0.6 ZIP succeeded: the helper restarted the app, retained the exact profile database bytes and a sentinel file, and kept a binary rollback folder. The local 1.0.5 ZIP differs from the public 1.0.5 asset, so the same check was repeated with the public package after verifying its published SHA-256 digest; it also passed. The registered installation on this Windows account was not opened or modified. Actual installer upgrade, schema migration approval in the updated GUI, physical widget/Explorer input, Windows 10, and mixed DPI remain unverified; publish as a pre-release.

The v1.0.6 pre-release is published. All four assets were downloaded and their SHA-256 hashes matched the local files and GitHub digests. The built-in selector recognized both exact package names from the live GitHub Releases API for a 1.0.5 user on the Pre-release channel; Stable ignores this pre-release by design.

## Software Updates acceptance (2026-10-24)

| Check | Status | Evidence and limit |
| --- | --- | --- |
| Release selection, exact asset, digest and redirect validation | PASS | Focused update service tests exercise semver, channels, missing digest, corrupt and short downloads, and rejected redirects. |
| Settings controls and persistence | PASS | Widget test and isolated Flutter Driver session covered navigation, version/status display, automatic-check toggle persistence, reopening, and screenshot inspection at 1264 × 681. Physical mouse and DPI behavior remain in the separate manual row. |
| Portable 1.0.4 to 1.0.5 replacement and restart | PASS | Real packaged bundles swapped at one disposable path under temporary APPDATA/LOCALAPPDATA; helper reported success and the new executable remained running. |
| Portable profile and user data | PARTIAL | The disposable schema 20 profile retained a seeded task and event plus valid appearance/custom theme, calendar, widget, and update preference values after the swap. Migration approval and full UI reading of those records remain unverified. |
| Immediate startup failure and corrupt package | PASS | An injected executable that exited immediately caused helper exit 1 and restored the prior binary; a wrong digest failed before changing the binary. Seeded task and event survived. |
| Native widget shutdown | PARTIAL | Isolated widget process accepted the exit command and exited. The helper's refusal to swap a still-running widget is tested separately; live Explorer painting and post-update widget restart are unverified. |
| Registered installer update | UNVERIFIED | The current Windows account has a real Todorbit registration at the stable AppId/path. No separate Windows user or VM was available for a safe installed upgrade, so the registered install was not modified. The helper rejected a mismatched disposable target. |
| Database migration and recovery | PARTIAL | Existing migration and backup tests verify schema 20 to 21 and pre-upgrade snapshot behavior. The real portable swap kept schema 20 untouched pending approval; a live approval and rollback flow was not exercised. |
| Physical Settings, widget, DPI, and keyboard acceptance | UNVERIFIED | Native computer control exposed no app windows. Flutter Driver and widget tests do not establish physical mouse or Explorer behavior. |

No new GitHub Release was created; the installer remains unsigned.

The 2026-10-23 calendar, sidebar, and cross-app UI audit is recorded in
[`CALENDAR_UI_AUDIT.md`](CALENDAR_UI_AUDIT.md). Its schema 21 and interface
results are newer than the historical v1.0.5 record below.
The follow-up from `e10fe1a` fixed Habit editor height, Advanced Search and
Template field gaps, and narrow select/action overflows. Isolated debug GUI
and widget tests support those changes; Release, physical DPI/scrollbar, and
Explorer widget interaction remain manual checks in the linked audit.

## v1.0.5 publication scope (2026-10-21)

This Windows x64 pre-release uses the completed Feedback Round 4 Part 1 and 2,
Feedback Round 5, native widget redesign, and final offscreen control audit.
The detailed evidence below is retained. Windows 11 is the main development and
test platform. Windows 10, live Explorer-hosted widget painting and input,
Win+D, mixed DPI and monitor edges, and actual installed upgrade/uninstall
remain unverified. The installer is unsigned. Do not infer full manual
acceptance from automated self-tests or offscreen renders.

Final candidate gates: `flutter analyze --no-pub` found no issues; all 208
serial Flutter tests passed (one nonfatal existing scroll hit-test warning);
native .NET Release built with zero warnings/errors and its source self-test
passed; Windows Release built, its packaged widget self-test passed, and the
disposable-profile single-instance/profile-isolation script passed. The native
dependency vulnerability query found none in configured sources. An isolated
Release app displayed Todorbit branding and an empty Today view. The native
widget process started but was not targetable through Computer Use, so actual
widget pixels and input remain unverified. No installed app or personal profile
was touched.

## Native widget final control pass (2026-10-21)

| Surface / check | Result | Evidence and limit |
| --- | --- | --- |
| Edit Task date fields and four choices | PARTIAL | The five user screenshots at `D:\AI_Projects\Todorbit_Widget_UI_Review_References` document overlapping date-action borders, text-adjacent dropdown arrows, and clipped/square corners in the prior editor. Two post-fix offscreen render passes in dark/light plus a custom palette show a single date outline, separate 32 px calendar/clear actions, stable trailing arrows, and rounded choice corners. Source self-test checks geometry and clearing. Native date placeholder text did not appear in `DrawToBitmap`; live placeholder and popup input are unverified. |
| Footer and compact layout | PARTIAL | Second wide render shows breathing room after Priority and no divider; 380 px narrow render shows an independent fixed footer and scroll cue. Scrolling by real input remains unverified. |
| Calendar | PARTIAL | Offscreen dark calendar render shows themed cells and month controls. Open/close, keyboard navigation, and screen-edge placement need live checks. |
| Quick Add and main Explorer widget | PARTIAL / UNVERIFIED (GUI) | Offscreen Quick Add capture shows the rounded focus outline; its native placeholder was absent in `DrawToBitmap`, so text rendering and input remain unverified. Main paint/menu code was reviewed, but no Explorer window was available to Computer Use. Old round-four screenshot is historical. |
| Functional and packaging gates | PASS (automated) | Native Release build: zero warnings/errors. Source and packaged self-test passed. Four focused Flutter tests passed. Windows Release build passed. No Flutter source changed, so analysis was not required for this pass. |

The initial screenshot path was absent; the user supplied the five images at
`D:\AI_Projects\Todorbit_Widget_UI_Review_References` afterward. The full
image also shows the former footer divider and final row pressed against it;
the corner crops show artifacts around adjacent rounded controls. These
images establish the baseline symptoms, not their technical causes or the
live result after this commit. Post-fix offscreen captures are diagnostic only;
`DrawToBitmap` does not prove live DWM, Explorer,
popup, DPI, hover, pressed, or keyboard appearance. No production profile,
installed application, or public v1.0.3 assets were changed.
The disposable live `--preview-editor` process was also started, but Computer
Use still reported no native windows; it was stopped without saving a task.

Before treating this as final visual acceptance, use a disposable APPDATA and
LOCALAPPDATA profile and perform these checks on the target Windows desktop:

1. Inspect the widget in dark, light, and a saved custom theme with empty and
   populated views. Resize from 260x230 through wide/tall sizes; review header,
   tabs, long task titles, checkbox, Quick Add, scrolling, opacity, and corners.
2. Open Edit Task at wide and 380 px widths. Tab through every field, scroll to
   Priority, hover/press the footer, open each choice list, use arrows/Enter/
   Escape, and check disabled Project after Category is cleared.
3. Type, choose, clear, and save Scheduled day and Deadline independently.
   Open the calendar near every screen edge, switch months, and verify date
   text, focus, clear hit areas, validation, and saved values after reopening.
4. Repeat the editor at 100%, 125%, 150%, and the highest available DPI on
   each available monitor. Check narrow clipping, popup placement, corner
   pixels, buttons, text scale, focus rings, and footer scroll separation.
5. Exercise Quick Add, row editing, completion, menu, lock, drag/resize, Open
   Todorbit single instance, Win+D, app privacy lock, and 0/30/70/100% opacity.
   Record screenshots and pass/fail with the checklist in `docs/windows-widget.md`.

## Native widget redesign acceptance (2026-10-21)

| Check | Status | Evidence / limit |
| --- | --- | --- |
| Editor dark, light, and 380 px narrow appearance | PARTIAL | Disposable WinForms `DrawToBitmap` renders show themed text, choice/date fields, fixed actions, and a narrow scroll cue. This is offscreen control painting, not an Explorer or DWM screenshot. |
| Date chooser dark and light appearance | PARTIAL | Offscreen native calendar renders show themed day cells, month actions, and selected day. Physical keyboard and popup focus remain unverified. |
| Form layout, keyboard actions, persistence, theme mapping | PASS (automated) | Native self-test covers wide/stacked content height, Save/Cancel bindings, accent contrast, and create/edit persistence. Existing IPC/profile/geometry tests remain passing. |
| Header icon, tabs, rows, empty copy, quick add, opacity, context menu | UNVERIFIED (GUI) | Code and native build inspected. The available computer-use surface returned no native apps; no Explorer-attached widget pixels or pointer interactions were observed. |
| Main-app activation, Win+D, dragging, resizing, layout lock, DPI, monitor edges | UNVERIFIED (GUI) | No physical Windows interaction this round. Existing self-tests cover geometry and IPC only. |

Automated gates: native `dotnet build -c Release` passed with zero warnings/errors;
source and packaged `TodorbitWidget.exe --self-test` passed; focused
`native_widget_service_test.dart` and `desktop_widget_test.dart` passed (3
tests); `flutter analyze` found no issues; `flutter build windows --release`
passed. The current release v1.0.3 was not modified, and no production profile
was opened.

Manual checks on a disposable profile: open the widget in dark, light, and a
custom theme; inspect the menu, Open Todorbit icon/tooltip, all four tabs,
populated and empty lists, long titles, quick add, hover, 0/30/70/100% opacity,
and 260x230, narrow, wide, and tall sizes. Open Edit Task at normal and limited
screen heights; test every field, date picker, clear action, choice popup,
scrolling, Tab/Shift+Tab, Enter/Escape, text selection, validation, and stale
save. Repeat Open Todorbit to confirm one main app window, then move/resize,
lock, change DPI/monitor, and press Win+D. Record actual screenshots and
pass/fail against `docs/windows-widget.md` before a release.

## Feedback round 5 acceptance audit (2026-10-21)

Status here distinguishes functional/automated evidence from actual Windows pixels. `PASS` means the stated requirement has direct interaction evidence; `UNVERIFIED` means implementation exists but the required physical UI path was unavailable. The audit was repeated after the draft-subtask disposal fix and divider cleanup.

| Requirement | Status | Evidence and remaining limit |
| --- | --- | --- |
| Inline red-underlined spelling while typing; no forced corrections or review icon | PASS | Isolated debug GUI showed a red wavy underline on `Writting teh`; controller/channel widget tests verify spans and unchanged input. Title, notes, checklist entry/edit, and subtask entry use the same controller. Physical typing in every field remains a manual check. |
| Scheduled day and Deadline side by side when wide, stacked when narrow | PASS | Both New and Edit use `TaskEditor`; debug GUI showed the two columns at 1265 px. Widget layout test covers 380/740 px and date clearing. Narrow Release pixels remain unverified. |
| Full or compact checklist/subtask text, expansion, Settings persistence | PASS | Debug GUI showed long saved checklist/subtask in both modes and Settings changed the per-profile JSON. Widget tests cover two-line ellipsis, expand/collapse, full text, narrow width, and 1.5x text. |
| Subtle Info popover opens and dismisses by icon or outside | PASS | Debug GUI showed themed popup/quiet icon state; widget test tapped the icon twice and outside. |
| Configured hotkeys trigger actions; conflict/preset/reset/persistence | PASS | Key-event widget test opened New Task and a custom Settings shortcut; binding and preset persistence tests pass. Physical keyboard use in a Release window remains unverified. |
| Major section dividers and optional planning below Subtasks | PASS | Shared task editor tree and debug New/Edit inspection show composition before Status/Priority and Estimates. Second pass removed inner subtask row dividers; focused tests reran. |
| Checklist text selects and copies without edit mode | PASS | Widget test long-pressed a real checklist row, sent Ctrl+C, and captured nonempty clipboard text. Physical mouse selection remains unverified. |
| Resources icons in one row with accessible descriptions | PASS | Debug Edit Task showed the single row; resource widget tests confirm action tooltips and behavior. |
| New Task / Edit Task visual consistency | PASS | Both use the same editor and were inspected in the isolated debug GUI, including schedule and composition. |
| Native widget padding and editor appearance | UNVERIFIED | Code changed and native Release/self-test pass; the Explorer-hosted window was not targetable for visual inspection. |
| Native widget movement, resize, lock, menu, task edit/completion, theme sync, Open Todorbit, repeated clicks, Win+D | UNVERIFIED | Round 4 math/IPC tests and native self-test pass. The packaged widget started and accepted an `exit` IPC command on the same isolated profile as the Release main app. Physical mouse, Explorer shell, and window behavior were not observed this round. |
| Release GUI in both themes and narrow/text-scale/DPI variants | UNVERIFIED | The isolated Release process started and created a disposable database, but computer control exposed no app window. Debug GUI was inspected in both themes at normal desktop width; narrow and DPI are covered by layout tests only. |
| Round 4 regression: recurrence, Smart Reschedule, calendar, focus, views, backup/restore, privacy, profile isolation, IPC | PASS | Full serial Flutter suite covers these repository and widget paths; native self-test and isolated Release startup cover executable startup. Physical native IPC/widget clicks remain unverified. |

Automated final gates: `flutter analyze --no-pub` passed; all 208 serial Flutter tests passed; 14 focused second-pass tests passed; native `dotnet build -c Release` passed with zero warnings/errors; source and packaged `TodorbitWidget.exe --self-test` passed; `flutter build windows --release --no-pub` passed; the single-instance/profile-isolation script passed with ten secondary launches; packaged native widget launch/exit IPC passed with the main app's disposable profile. A first direct widget launch without a database showed the documented "Open the main app first" error; retrying in the correct startup order passed. The full Flutter suite emitted one existing nonfatal scroll hit-test warning in `workspace_test.dart`.

Real GUI evidence: isolated debug Flutter Driver screenshots and actions covered light/dark desktop UI, New/Edit, long text, expansion, Settings, spelling, and Info. The isolated Release executable started and created its database, but the computer-control service returned no desktop app surface. No Release visual, narrow live window, native painted widget/editor, physical hover/focus, DPI, Win+D, or mouse-drag claim is made.

Manual checks on a disposable `APPDATA`/`LOCALAPPDATA` profile:

1. Launch the current `build\windows\x64\runner\Release\Todorbit.exe`. In dark and light, open New Task and an existing Edit Task. Resize to about 1265 px and 760 px, then use Windows 100%, 150%, and any mixed-monitor DPI. Check schedule columns/stacking, section order, dividers, Resources tooltips, Info open/second-click/outside dismissal, text clipping, keyboard focus, and hover/pressed colors.
2. Type `Writting teh report` in task title, notes, checklist entry/edit, and subtask title. Confirm red underlines after a short pause and no text replacement. Use a Windows account with an installed `en-US` spelling dictionary. Check disabled spelling in Settings and restart.
3. Create long checklist and subtask titles. In Task Preferences, switch Full/Compact, expand/collapse, select text directly with the mouse, Ctrl+C, and paste into another app. Restart and verify the mode persists. Repeat with larger Windows text scale.
4. Exercise each displayed hotkey on the physical keyboard: default Ctrl+N, custom Settings, conflicts, reserved keys, preset switch/reset, and persistence after restart. Confirm editors and modal dialogs do not trigger unintended workspace actions.
5. Start the main app first on the disposable profile, then `TodorbitWidget.exe --widget --app-exe <absolute path to Todorbit.exe>`. Follow `docs/windows-widget.md` steps 1–16: drag/resize/lock, right-click menu, editor form, all-edge padding, task input/edit/completion, theme/opacity, repeated Open Todorbit clicks with one app process, and Win+D. Repeat on each available DPI and monitor. Check the privacy steps there with app lock enabled.

## Feedback round 4, part 2 (2026-10-20)

Automated widget tests cover two-line checklist expansion at narrow and wide
widths with larger text, stable checklist dialog width, scheduled date layout
and clearing, Settings/Hotkeys navigation, Info dismissal, and resource actions.
The native widget menu palette is checked by its self-test. These checks do not
substitute for observing the layered widget and Windows control painting.

In the isolated 1.0.4 Release GUI at 1266 x 713, light and dark Settings,
the Widget settings pane, the narrow task schedule/checklist draft layout,
and the Today Info popover were inspected. The Info popover initially had
faint text; the final rebuilt window showed readable text after the fix.
Typing a full draft task through Computer Use was unreliable, so a saved long
checklist row was not visually verified. No production profile was used.

Manual acceptance for the local 1.0.4 candidate on disposable profiles:

1. Inspect long checklist rows in dark and light themes at a 360 px task panel
   and a wider window. Select/copy text, expand/collapse, use every overflow
   action and keyboard navigation, then edit while entering long text.
2. Create a task with Today planned, clear it, set a deadline separately,
   create draft checklist/subtasks, and confirm cancel/save behavior. Review
   completed visible/hidden preferences and each list Info description.
3. Resize Settings to a narrow window. Open every category, change theme,
   hotkeys, task preferences, notifications, widget and privacy controls;
   restart to check persisted choices.
4. Inspect native widget light/dark context menus at normal and mixed DPI,
   including keyboard selection, screen edges, opacity, lock, refresh, and
   dismissal. Open its native task editor, resize it, edit each field, and
   inspect the date pickers and validation messages.
5. Drag/resize and lock the Explorer-hosted widget, restart to verify geometry,
   check Win+D/normal-window layering, and click Open Todorbit ten times with
   the app open and minimized. Check the tooltip, focus, and one process.
6. Drag Explorer files into Resources and review spelling suggestions from the
   installed Windows dictionary. These native input paths still require direct
   GUI observation.

The referenced TodoPilot screenshots are from an older executable: current
source and the isolated Part 1 Release GUI displayed Todorbit. Internal legacy
profile names remain for data compatibility.

## Feedback round 4, part 1 (2026-10-20)

Automated checks run on disposable data. An isolated Release window displayed
Todorbit branding and a Today default in New Task. Ten secondary launches for
the same isolated APPDATA profile left one build process. A second independent
APPDATA profile ran beside it with its own SQLite file. `--appearance` opened
Customize Theme in the existing window; repeating the command left one visible
dialog. The native widget self-test passed, and read-only shell diagnostics
found a visible layered `WS_CHILD` under `SHELLDLL_DefView`. Computer Use did
not expose that Explorer child as a targetable window, so its pixels, mouse
dragging, resizing, lock, DPI, and Win+D behavior remain unverified.

Part 2 manual checks on isolated profiles:

1. Drag the unlocked widget across monitors at 100% and mixed DPI; resize from
   each edge and corner; release, restart, and confirm the exact geometry.
   Repeat with Layout Lock, Win+D, normal-window overlap, task checkbox, and
   the native editor. Confirm repaint has no snap-back or flicker.
2. Repeatedly click Open Todorbit and Customize Theme in the widget with the
   app open and minimized. Check focus, one process/dialog, and Open full
   details routing. Repeat with two independent portable extractions.
3. Use every default hotkey, record a custom combination, test duplicate and
   reserved keys, save/rename/delete/switch presets, restart, and type in
   editors and modal dialogs without unintended actions.
4. Review misspellings in title, notes, checklist, and subtask fields with an
   installed English (United States) Windows dictionary. Check suggestions,
   keep-as-written, technical terms/URLs, and the disabled preference.
5. Drag one and multiple Explorer files into task Resources; confirm target
   highlight, attach/link choice, duplicate path handling, missing/oversized
   file errors, resource labels, and portable-copy versus local-link behavior.
6. Create, edit, reorder, and cancel draft checklist items and subtasks;
   verify independent child dates, no orphan records, and Today/No Date/Anytime
   defaults. Switch completed-task display and reopen a completed task.

Spell checking is an explicit on-demand review, not inline misspelling marks.
The file-drop receiver accepts local Explorer files only. Actual native drop
input and the Windows COM dictionary result still require GUI observation.

## Todorbit 1.0.3 rebrand checkpoint (2026-10-20)

The 1.0.2 Release GUI was later enumerated in an isolated Windows profile. Its
dark and light Today views showed the outlined orbit mark and readable text.
An undated task was created, found in Anytime, and completed. The Settings
data-profile dialog showed the disposable SQLite path.

The extracted 1.0.3 portable GUI opened from a path containing spaces in a
separate temporary APPDATA/LOCALAPPDATA root. It showed the Todorbit title and
mark, began with zero tasks, created a task planned for today, displayed it on
Today, and retained it after a full restart. A second extraction in the same
temporary root opened with zero tasks and created a different location-keyed
profile. The extracted widget self-test passed. An actual installed 1.0.3
fresh start, registered upgrade, uninstall/reinstall, Windows 10, and native
widget shell interactions remain unverified. Older rows below describe their
recorded version-specific GUI evidence; do not treat them as a complete 1.0.3
pass.

## TodoPilot 1.0.2 update (2026-10-19)

The 1.0.2 Release build and packaged widget self-test pass. The final portable
ZIP's extracted widget self-test also passes. The isolated 1.0.2 GUI process
started, but the Windows inspection tool did not enumerate its window. The
transparent in-app sidebar mark is therefore present in source and package but
still needs direct dark/light visual acceptance at 24 px. Rows 2–25 and 27–29
below retain their prior manual status; the 1.0.2 installer, registered upgrade,
uninstall, taskbar/shortcut icons, widget composition/input/DPI, and Windows 10
remain untested. Do not treat the older 1.0.1 GUI observations as a 1.0.2 pass.

Status updated 2026-10-19. Tests use disposable profiles. `Passed` means this
checkpoint's actual Windows Release UI was observed. Automated tests are
reported separately in `PROGRESS.md` and do not turn an unobserved GUI flow into
a manual pass.

| # | End-to-end flow | Status | Evidence or next check |
|---|---|---|---|
| 1 | First launch | Passed | Release window opened on verified isolated APPDATA/LOCALAPPDATA; empty Today rendered. |
| 2 | Create categories, projects, tasks | Manual verification required | A task was created in the final Release app; category/project creation still untested. |
| 3 | Edit, complete, reopen, delete tasks | Manual verification required | Full Release flow untested. |
| 4 | Sequences and dependencies | Manual verification required | Full Release flow untested. |
| 5 | Reschedule preview, cancel, apply | Manual verification required | Prior narrow preview inspection; full Release flow untested. |
| 6 | Schedule Undo and restoration | Manual verification required | Full Release flow untested. |
| 7 | Recurring tasks and series editing | Manual verification required | Full Release flow untested. |
| 8 | Recurrence exceptions and collisions | Manual verification required | Full Release flow untested. |
| 9 | Habit progress | Manual verification required | Full Release flow untested. |
| 10 | Goals and task links | Manual verification required | Full Release flow untested. |
| 11 | Timers and manual work | Manual verification required | Full Release flow untested. |
| 12 | Task templates | Manual verification required | Full Release flow untested. |
| 13 | Saved views | Manual verification required | Full Release flow untested. |
| 14 | Reports and statistics | Manual verification required | Empty report was inspected at an earlier checkpoint; populated result untested. |
| 15 | Reminders | Manual verification required | Actual Windows tray delivery untested. |
| 16 | Archive and restore | Manual verification required | Partial earlier inspection; full Release flow untested. |
| 17 | Trash recovery | Manual verification required | Full Release flow untested. |
| 18 | Database export | Manual verification required | Native file picker untested. |
| 19 | Database import preview | Manual verification required | Native file picker untested. |
| 20 | Next-launch restore | Manual verification required | Native Release flow untested. |
| 21 | Managed attachment add/open | Manual verification required | Native picker and opener untested. |
| 22 | External file, folder, URL links | Manual verification required | Native picker and opener untested. |
| 23 | Missing external resource | Manual verification required | Full Release flow untested. |
| 24 | Enable, unlock, relock privacy | Manual verification required | Disabled dialog visually inspected; computer-use rules barred changing privacy settings through UI automation. |
| 25 | Widget respects lock | Manual verification required | Native self-test covers lock-state decisions; real two-process UI untested. |
| 26 | Restart and persistence | Passed | A task created in the isolated Release app retained its UUID and planned date in SQLite and appeared on Today after a full app restart. |
| 27 | Main app/widget independent lifecycle | Manual verification required | Previously accepted widget build; privacy changes require retest. |
| 28 | Theme synchronization | Manual verification required | Previously accepted widget build; final package requires retest. |
| 29 | Widget after Win+D | Manual verification required | Computer-use rules bar Windows-key automation; user must perform. |
| 30 | Packaged or installed application | Manual verification required | Feedback Round 2 Release bundle opened and its 15 files were rebuilt into the Inno Setup 7.1.0 installer; bundle audit found no database or personal files, and the packaged widget self-test passes. Installed flow remains untested. |
| 31 | New profile versus existing profile | Manual verification required | Disposable database tests pass; newly installed profile and existing personal profile need GUI comparison. |
| 32 | Recurring lecture and single-date cancellation/restoration | Manual verification required | Repository and widget tests pass; isolated Release GUI flow untested. |
| 33 | Event reminder balloon | Manual verification required | Native self-test covers one-off, selected weekday, cancellation, and duplicate claim; actual Windows tray delivery untested. |
| 34 | Task/category/project icon selection | Manual verification required | Persistence tests pass; visual size and reset behavior need Release GUI check. |
| 35 | Checklist and one-level subtask | Manual verification required | Persistence and widget tests pass; full Release GUI flow untested. |
| 36 | Progressive recurring study plan | Manual verification required | Assignment, skip, edit, restart, split, migration, and Calendar/editor tests pass; full Release GUI flow untested. |
| 37 | Focus stopwatch and sidebar mini timer | Passed | In the isolated Feedback Round 2 Release profile, focus visibly advanced from 00:00:00 to 00:00:06, the sidebar mini timer updated, Stop produced a 00:00:14 timer log and stopped state, and the task stayed In progress. Pause/resume still has automated coverage and needs a direct Release visual pass. |
| 38 | Windows title bar and application icon | Partially passed | The final extracted 1.0.1 ZIP visibly shows the transparent outlined orbit in the title bar. Resource 102 is the separate window icon; resource 101 remains the original black-tile icon. Taskbar selection, maximize/restore, DPI, shortcuts, and installer visuals need GUI checks. |
| 39 | Orbit icon in Release app | Partially passed | The primary executable ICO is byte-identical to the previous committed black-tile orbit; the rebuilt executable's extracted associated 32 px icon remains black and white. The new outlined window ICO has 16/20/24/32/48/64 px entries. Start menu, File Explorer, desktop shortcuts, and taskbar still need direct visual checks. |
| 40 | Visual color wheel and HEX | Passed | At 1266×713, the hue ring, saturation/value square, preview, HEX field, and Cancel/Reset/Confirm controls fit without overflow. Mouse wheel selection changed preview and HEX; keyboard HEX edit changed preview and wheel. |
| 41 | Separate palettes and restart persistence | Passed | In an isolated profile, light accent changed to `#BD561A`; saved settings and a full TodoPilot restart retained it while dark accent stayed `#B9A4F4`. Automated persistence test also passed. |
| 42 | Native widget opacity, layout lock, and desktop behavior | Partially passed | Initial isolated GUI launch failed to create the layered child. A Windows-aware manifest fixed creation; read-only inspection then found the visible `WS_EX_LAYERED` child under Explorer at the intended (1520,24) screen position across two monitors. Actual 0/30/70/100% alpha over wallpapers, Win+D, context menu, task hit testing, DPI resize, and independent lifecycle still need direct GUI acceptance. |
| 43 | Portable ZIP and installer | Partially passed | The final 1.0.1 ZIP has 26 entries and no database, settings, backups, logs, or keys. Two extracted copies launched in one disposable application-data root and created separate empty profiles. The Inno Setup installer compiled from the checked Release bundle; no installer installation was performed. Hashes are in `docs/PROGRESS.md`. |
| 44 | Portable persistence and separate copies | Passed | An extracted copy opened with zero tasks, fixed events, goals, habits, work sessions, timer runs, and time entries. One task created in its UI remained after reopening; a second extracted copy opened with zero tasks in a different profile. |
| 45 | Old Life Manager data on fresh start | Partially passed | The unmarked Release executable opened a fresh empty database beside a disposable legacy database with one task and offered a reviewed import. The actual fresh installer operation is untested. |
| 46 | Existing TodoPilot upgrade and widget profile | Partially passed | A disposable legacy database plus valid upgrade marker selected the one-task legacy profile in the Release app; the native widget wrote settings there. Two final packaged portable widgets ran concurrently and commands exited only the matching copy. Actual registered-installer upgrade remains untested. |
| 47 | Uninstall and reinstall | Manual verification required | Source has no personal-profile uninstall deletion. No disposable Windows user or VM was available for an actual installer/uninstaller run; data retention after that operation is unverified. |

The privacy dialog opened in the rebuilt Release app with the default disabled
state and no visible layout overflow at 1266×713. It was closed without
changing settings. A final Release UI run created a disposable Today task and
verified it after restart. No personal database was opened or migrated.

Feedback Round 2 also inspected the rebuilt dark-theme Release at 1266×713 in
a disposable profile. Today, the reorganized new-task editor, empty Calendar,
task row, live focus dialog, stopped work log, and mini timer rendered without
visible overflow. Light-theme Today and its task row also rendered with readable
contrast and matching native caption colors. A disposable task and a short timer
log were created only in that isolated profile. Narrow restored windows,
125%/150% DPI, populated secondary views, and the native widget remain manual
visual checks.
