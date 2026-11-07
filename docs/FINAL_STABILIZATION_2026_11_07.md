# Final stabilization and beta 13 preparation (2026-11-07)

Branch `feature/sync-ux-refinement`; starting checkpoint `87e976f`.
Detailed evidence: `D:/AI_Projects/TodorbitPrivateBuilds/stabilization-20261107/evidence`.
One inventory, `000-evidence-inventory.json`, separates reused, new and open checks.
No publication, tag, push, cloud snapshot backup or production profile change.
The three preexisting storage-document edits remain excluded.

## Implemented and verified

- Encryption-mode/account/workspace-pinned private approval: local commit `0e04028`.
  Reuses six focused tests and actual Private round-trip from the prior receipt.
- Routine Sync success now uses a compact themed four-second floating message,
  without settings/close actions; repeat notices are suppressed. Actual problems
  retain actionable UI. Recovery-code copy feedback uses the same component.
  `001-toast-checks.json`: analysis clean; seven focused cases pass, including
  light/dark, 2x text, reduced motion, accessibility and FAB clearance.
- `003` preserves an independent encrypted original-key copy and SQLite backup.
  `004` transfers only the approved disposable account OAuth tokens into a fresh
  isolated recovery profile; no workspace key or original device identity copied.
- `005/006`: fresh repository device, synthetic queued work, actual selected
  database/settings/credential paths and native DPAPI isolation verified.
- `007`: real Google GET-only wrong recovery-code rejection. No key saved,
  queued work unchanged and cloud metadata fingerprints unchanged. Initial
  comparison used unordered metadata serialization; corrected canonical comparison
  passes. Both invocation logs are retained.
- `008`: user entered saved recovery code directly in the new app. Live unlock
  and encrypted exchange pass: queued work uploaded, original immutable history
  retained, integrity/FKs pass, original working key and recovery copy unchanged.
- `009`: local GUI restore fixture prepared using BackupService. A manual backup
  precedes one new queued synthetic task. Recovery app closed; scoped approval
  held at `recovery-live/approval-held-restore-fixture.json`, preventing exchanges.

## Reuse and remaining boundaries

Standard cross-platform CRUD/conflicts/recurrence/restore and Private rich encrypted
round-trip, actual ciphertext/proof checks, retained keys and passphrase pairing
are reused from their final acceptance reports. No full matrix or suite repeated.
Prior schema 27 migrations, native behavior and crypto implementation are unchanged.

Pending: targeted remote synthetic parent change, actual Windows GUI restore,
Before Restore/quarantine/reconciliation/decision-clock verification; final version
and artifact checks; changed Android UI runtime review. Native Computer Use still
fails initialization (missing kernel assets, os error 3), so Windows GUI steps
require user interaction. The retained emulator was gracefully stopped to reclaim
RAM; its authenticated userdata is preserved. Physical OEM/ARM64, readers/DPI,
16 KiB runtime and exact-candidate CI remain separate release gates.

Unpublished beta preparation: `1.0.19-beta.13+36`, following published beta 12.
No beta 13 package or release readiness is claimed until recorded below.

## Live GUI restore and new automatic-restart request

`010` uses a fresh headless device and the approved Private account/key in memory
to change only the synthetic parent Completed -> Not started. No deletion/reset.
Its inherited transport counter labels all non-media requests as metadata;
these counters are not a GET-only claim (the actor uploaded an encrypted batch).
Initial harness analysis found an incorrect repository method; corrected before
execution. The actual exchange passes. `012` production baseline and plaintext
recovery-code scan pass; `013` full analysis passes at the pre-restart source.

`014/015`: user selected the specific manual backup in the Windows GUI and
confirmed replacement. The owned app was restarted; the database opened with
integrity/FKs intact, Sync quarantined, and Before Restore retained the later
queued task. `017`: user reconciled using the retained key, exchanged, chose the
cloud synthetic parent and uploaded the reviewed decision. Later queued task is
present; no blocked heads/duplicate operations or pending uploads. Decision parents
include both branches and its clock advances beyond its prior observed own clock.
Original working Windows/Android profiles remain untouched. Recovery app closed;
approval held at `recovery-live/approval-held-after-GUI-pass.json`.

The owner then requested automatic restart after Apply replacement. This is a new
boundary beyond the already passing GUI journey: local restore now invokes a
bootstrap-owned profile restart, draining Sync/privacy, detaching old observers and
providers and closing SQLite before using the normal guarded startup path. It
retains Before Restore, quarantine, migration/privacy checks and a manual fallback.
No new OS user, process launcher, cloud/key architecture or dependency is added.
`016`: nine targeted restore/import UI cases pass, including cancel, schedule failure,
restart failure and retry. Initial new real-startup test `018` timed out at initial
fake-clock settling, before restart; corrected fixture gives real IO event-loop time
and always closes its database. Its bounded rerun remains pending below.

`011` Windows builds succeeded for public-review and private-test configurations,
with byte-for-byte restoration of retained Standard staged source/bundle. They
precede the new automatic-restart request and are preserved as intermediate
artifacts, **not final candidates**. Affected Windows rebuild is justified by that
new request. No Android rebuild has occurred in this phase yet.

### Automatic local restore restart verified

`018-real-restart-retained-pass`: actual bootstrap restart PASS, including fresh
controller identity, selected records, scheduled marker consumed, original later
work retained in verified Before Restore. Initial harness runs are preserved:
initial fake-clock settling timed out; a three-second IO poll was too short; the
phase diagnostic completed every assertion but cleanup raced directory handles.
The successful fixture is now retained as evidence rather than deleted.
Debug-only phase messages contain no paths, records or credentials. The app
restarts its profile/session within the existing process; it does not force-kill
another process. Failed restart retains the scheduled restore and safe fallback.
Crypto, database replacement and causal algorithms are unchanged.

`019`: changed restart source/tests analyze clean. First readback invocation stopped
locally before Google calls because its access token had expired. The existing
isolated Release app refreshed only its own protected OAuth store and passed the
read-only account/workspace preflight; it was then closed. GET-only readback passed,
authenticating the Private proof and all encrypted batches, matching stored batch
bytes/operation IDs, and finding the GUI decision in actual Drive ciphertext.
No cloud writes/cleanup, account change or repeated Sync matrix in this readback.
User freed RAM (7.28 GiB observed); final affected Windows builds are now running.

## Final packaging checkpoint

`020`: final automatic-restart Windows app/AOT builds, official portable package,
installer compilation and isolated private build pass; retained Standard staged
source/bundle restored byte-for-byte. `021`: full current Dart analysis clean.
`023`: packaged native Release self-test passes in a fresh disposable child.
`024`: ZIP/bundle bytes, private-data exclusions, OAuth configuration/runner/AOT
and checksum checks pass. Public executables are unsigned; installer not executed.

A subsequent executable-version audit found a confirmed packaging mismatch: CMake
forced native FileVersion 1.0.19.0 and stripped the beta suffix, overriding the
synchronized csproj. This is metadata wiring, not a Sync/UI behavior defect.
CMake now forwards full Flutter version and build; the central release-bundle
guard rejects a mismatched companion/app version. `025` rejects the actual old
native metadata and accepts the current isolated private bundle. Only companion
publish and public package refresh are needed; no new AOT or Android rebuild.
Old packages/native binary will remain preserved as intermediate evidence.
Android production-signed beta13 build is running sequentially; no emulator boot
or signed-package installation has occurred in this checkpoint.

## Native runtime and final motion correction

`022` production-signed Android beta13/code36 package passes signer, package,
non-debuggable, ABI/alignment and monotonic-public-version gates. Signing config
and local.properties remain unchanged. `027` stops the task-specific Gradle daemon.
`026/030`: corrected native metadata is 1.0.19.36 / 1.0.19-beta.13+36, central
package guards and packaged self-test pass. Main/AOT were reused byte-for-byte;
old native/packages/checksums are archived. Correction committed `bb9749b`.
`028/029/031`: final private Release isolation/native store probe passes. User
applied the prepared local backup and confirms automatic return without manual
close/reopen. Selected database opened; Before Restore retains later work,
encrypted credentials are byte-identical, integrity/FKs pass, Sync quarantined
and approval held. This closes the actual new Windows automatic-restart boundary.

`032-041`: one retained SSD AVD boot; system_server PID546 stable and crash buffer
empty, PackageManager/GMS/IME/storage healthy. User10 approved Private scope and
schema27/28 operations verified. No APK installed. Temporarily offline; attached
only user10/PID6283, Dart MCP hot restart succeeds and inspector shows the new
AppRestartScope. Native drawer/Settings/disclosure/Sync dialog/task draft/input/
Back/unsaved-discard checks pass. Actual screenshots inspected. IME shown flags
and handwriting toolbar observed; no physical keyboard/TalkBack claim. Offline
Google token acquisition asked for reconnect, while cached disposable label and
protected files remained; no reauthorization or manual exchange attempted.
Standard user0 DB/WAL and Private immutable count remain unchanged; no draft saved.
Both apps force-stopped, network settings restored, AVD shut down gracefully with
userdata retained. Initial restoration check preceded asynchronous WiFi activation;
read-only follow-up verified original settings before shutdown. SDK/DTD detached.
This is hot-restarted debug-source evidence, not final signed APK runtime.

Review then identified a remaining motion gap: ScaffoldMessenger uses its own
animation and did not receive the app's shared no-animation preference. Both
routine success and code-copy messages now pass AppMotion.style explicitly.
`042`: focused analysis clean; five existing routine/copy/guide cases pass and
light/dark 2x offscreen success images were reviewed (synthetic fixture, harness
icon placeholders/focus outlines). New motion tests initially omitted account/
binding and opened setup instead; corrected. Disabled-motion case passes without
accessible-navigation masking; enabled case passes after allowing one final frame
beyond its180ms transition. Only failed new assertions rerun. All logs retained.
This two-call UI correction invalidates previous AOT/package identity only;
Sync/recovery/startup/native/Android UI journey evidence is reused. Affected final
packages must be refreshed; no new matrix, migrations or key operations required.

## Final outcome and owner review

**Ready for isolated private beta review. Not approved for publication.**
Version `1.0.19-beta.13+36`; application source `7783af8` on
`feature/sync-ux-refinement`. Final documentation commits change no implementation.
`046-final-source-artifacts.json` proves current Dart/source/config continuity for
both platform builds and complete ZIP/bundle equality. `043/044` supersede earlier
package identities following the motion correction; all earlier files remain in
recorded intermediate directories. Windows companion matches the exact passing
`030` binary, so its self-test was reused without another native build/test.

| Boundary | Final result / evidence |
| --- | --- |
| Routine success/copy UI | PASS042: compact themed surface,4s dismiss, no routine actions/close, no queued Sync duplicates,2x light/dark captures, explicit motion off/on. Required failures remain actionable. |
| Private recovery | REAL PASS007/008: independent fresh profile, wrong code safe rejection, saved code entered by owner, actual encrypted recovery exchange, original keys/copies unchanged. Passphrase pairing/crypto risks reuse059/060/074. |
| Private GUI restore/decision | REAL PASS014/015/017/019: reviewed snapshot, restart, Before Restore, quarantine, retained key, explicit reconciliation, preserved queued task, reviewed cloud choice, causal clock advancement and uploaded ciphertext readback. |
| Automatic local restore restart | PASS016/018/031: cancel/failure/retry plus actual bootstrap and final private Release owner observation. Current profile remains safely quarantined with its Before Restore and held approval; no second reconciliation/Sync required for this UI check. |
| Post-restore data integrity | PASS045: original managed attachment bytes/hash/ID, task/event category/project, parent/child and named checklist group retained. |
| Windows packaging | PASS043/046: public portable/installer plus independent private variant; full version/build guard, config/runner/AOT identity, ZIP contents/exclusions and checksums. Windows binaries unsigned; installer compiled, not executed in this phase. |
| Android packaging | PASS044: production signer, ID,code36/non-debuggable,arm64/x64,8 libraries' ELF/applicable ZIP alignment, monotonic published version and hashes. Signing config/local.properties unchanged. GitHub APK only; no Play AAB. |
| Android native UI | PASS037-040 for named offline debug-source Settings/navigation/draft/input/Back journeys. Signed final APK execution is NOT TESTED; retained debug35 installation preserved. |
| Final live source deployment | PASS049/050: hot restart after the final motion change, actual user10 Drift database path, both live script sources contain shared motion call, no runtime errors. No expression compiler, new Sync or repeated UI matrix. Initial launch preceded user-unlock readiness; one retry after PackageManager and both users RUNNING_UNLOCKED. |
| Original data and credentials | PASS050/051: Standard Android user0 DB/WAL unchanged, Private immutable28-operation profile retained,18 production Windows file hashes/startup entries and3 unrelated documents unchanged. Original working key/independent copy hashes match; scoped log/snapshot/doc secret scan passes. |
| Current static checks | Whole-source analysis021 plus final changed-source analysis042 and final fixture analysis052 clean; relevant formatting/diff/link checks below. Prior Standard/Private protocol/full-suite closures reused as scoped evidence, not a newly repeated all-green suite. |

Final artifacts are under
`D:/AI_Projects/TodorbitPrivateBuilds/stabilization-20261107/packages/`:

| Artifact | Relative path | SHA-256 |
| --- | --- | --- |
| Windows portable ZIP | `Todorbit-1.0.19-beta.13-win-x64-portable.zip` | `73a973e861e3b1160db353385c65294f484e74beb01fbf1821cb08657817d6f6` |
| Windows installer | `Todorbit-1.0.19-beta.13-win-x64-setup.exe` | `92aa0581f614cebe375fed6822714a86c53f21de6109b7256daa7e4bf6354f4c` |
| Windows private test ZIP | `Todorbit-1.0.19-beta.13-win-x64-PRIVATE-TEST.zip` | `0643ab1b87fc24f787535bc3f5b694b8f39c03fdb738e485ad8eb3557196681c` |
| Android production-signed APK | `Android-production-signed-motion/Todorbit-1.0.19-beta.13-android-universal.apk` | `833d80ec2bf7b2218ace3182fdbf2ce16d5d468d72c7ea0046bb26eee8b6dc23` |

For local Windows testing use only the guarded launcher
`D:/AI_Projects/TodorbitPrivateBuilds/stabilization-20261107/recovery-live/Start-Recovery.ps1`.
It selects `bundles/Windows-private-motion-final`, verifies binary/protection
receipts and uses its fixed Runtime/Profile and independent encrypted store.
No app/emulator is left running. Do not substitute the normal public portable
candidate for this same-account isolated test environment. Existing authenticated
original profiles and all recovery snapshots remain available. Original profiles
retain the28-operation checkpoint; the disposable cloud also contains the later
explicit recovery/restore synthetic records. No cloud cleanup performed.

### Remaining release gates / concise manual checklist

- Exact-candidate Windows/Android CI: NOT RUN, because source remains local and
  push is not authorized. Historical CI is not current-candidate CI.
- Exact installer clean install/upgrade/recovery and Windows10: NOT TESTED.
  Use a disposable environment; retain backups and verify schema26->27 review.
- Native Windows shell/date controls, context menu, keyboard, multi-monitor/DPI
  and Narrator: physical checks remain. Computer Use initialization failed once
  with missing kernel assets/os error3; no repeated broken-tool retries.
- Final production-signed APK runtime/upgrade,16KiB runtime, physical ARM64/OEM,
  launcher sizes/multiple widget IDs, full IME/Back and TalkBack: open. Emulator
  evidence is x64 debug-source only; do not uninstall its signed-in debug app to
  install a differently signed package. Production OAuth client registration is
  owner-reported in the Android guide; this signed candidate's live OAuth is not
  newly verified. Google branding verification remains outstanding/unchanged.
- No device performance trace or universal accessibility/security claim. Local
  SQLite backups contain local data, not cloud-encryption secrets; keep private.
  Cloud snapshot backup, workspace conversion/key rotation and original unfamiliar-
  task root cause remain outside this proof; original cause is still unproven.

Owner's next step: review these private candidates and the remaining release gates.
A separate authorization is required before push/CI staging or publication. No
further sign-in/passphrase entry is required to retain this completed checkpoint.

Final provenance close: `053` compares64 unchanged native/packaging files with the
retained build source and verifies explicitly staged changed-file fingerprints.
`051` verifies production/startup/protected-document and original-key protection.
`052` final changed test-file analysis is clean after fixture corrections.

Local commits since87e976f: `0e04028` (mode/workspace approval), `abf8049`
(account switch/copy/success UI), `4b99e5f` (unpublished version/notes), `9e42c1f`
(automatic restore restart), `bb9749b` (native identity guard), `7783af8` (motion).
The following documentation checkpoint records these results without changing
compiled implementation. The three unrelated storage-document edits stay excluded.


## Beta13 release verification continuation (2026-11-07)

Starting checkpoint `3700185`, branch `feature/sync-ux-refinement`. Evidence is
outside Git at `D:/AI_Projects/TodorbitPrivateBuilds/stabilization-20261107/release-verification/`.
`001-continuity.json` matches the recorded implementation/native source and all
four final package hashes; no application changes or rebuilds. Standard/Private,
restore/reconciliation, native self-test, analysis and package evidence above is
reused for unchanged boundaries. `005-production-protection.json` confirms all
18 production baseline files unchanged; protected storage documents also match.

Two CI verification defects were corrected without changing shipped binaries:
- Release-config test still used fake executable text and lacked source-version
  metadata after the bundle identity guard was added. Initial invocation failed;
  corrected real-PE fixtures and two negative version cases pass all18 checks
  (`002-config-gate-corrected.log`).
- Windows CI passed schema26 to background-worker fixtures although the candidate
  uses27. Privacy/restore checks therefore stopped at the earlier migration gate.
  The helper now derives/checks the source schema; CI removes the stale argument.
  Two focused schema-selector tests pass. Exact worker execution remains pending.

Offline Windows Sandbox is running solely for installer/upgrade acceptance:
2GiB, networking/clipboard disabled, only verified packages/synthetic fixtures
mapped. Authentic published Beta12 installer SHA-256 is
`e8f4a454dbc378dc70f2829d6a96227e8b2542cc43c34ec758b505b827e4e8ab`
(receipt003). Guest runner checkpoints `sandbox-results/acceptance.json`; guest
identity `WDAGUtilityAccount`, host production profiles/credentials not mapped.
It installs12, seeds synthetic schema26 task/event/checklist, then installs13.
Migration approval must use the application's actual confirmation; native Windows
UI automation remains unavailable. Do not claim migration/uninstall passed until
this checkpoint reports PASS. Signed Android runtime in a separate clean AVD and
exact-source remote CI remain pending. No emulator or Google exchange launched.
