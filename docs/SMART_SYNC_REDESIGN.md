# Smart Sync implementation ledger

Current follow-up: [comprehensive verification and confirmed fixes](SMART_SYNC_VERIFICATION.md).
The original implementation below was published as beta 8 at `dd36189`;
[publication evidence](SMART_SYNC_BETA_8_PUBLICATION.md) supersedes the historical
unpublished/build-pending statements. New fixes remain local and are not in beta 8.

Implementation is committed on `feature/smart-sync-redesign`; verification is
partial. See [final verification status](#final-verification-status),
[implemented behavior](#implemented-behavior-for-review),
[two-device acceptance](#two-device-acceptance-procedure) and
[changed files/commits](#changed-files-and-checkpoints). No release or version bump.

## Baseline and audit (2026-11-03)

Branch `feature/smart-sync-redesign` starts at `0dcfb5a`, clean. Published beta 7
runtime source is `2919551` per `UI_UX_STAGE2_PUBLICATION.md`; its newer local
publication documentation is retained. No local release tag is available. App
version stays `1.0.19-beta.7+30`, SQLite schema 26, sync protocol 1, workspace
proof `todorbit-sync-workspace:1:aes256gcm`, encrypted batch format 1.

Existing implementation: shared Google OAuth (Windows PKCE/loopback, Android
Google Identity), profile-keyed OS secure storage, account-bound AES-256-GCM
workspace proof and recovery key. A second device needs the key once; Google
authentication cannot recover this end-to-end key. Persisted device authorization
already avoids repeated entry. Backups use a separate encrypted snapshot format
and are never pruned by sync.

SQLite captures immutable UUID operations, causal parents/visible intervals,
transaction groups, deletions, encrypted outbox retries and incoming batches.
Leases fence concurrent workers. Drive's change feed supplies durable cursors;
downloads are authenticated before atomic application. Independent fields merge;
competing values and unsafe relationships retain both branches. Resolution emits
a new durable operation acknowledging every reviewed head, even when keeping
unchanged bytes. Stale decisions are rejected under the SQL writer lock. Preserve
these working mechanisms rather than replace them with timestamp winners.

Supported scope is the existing 42-table portable allowlist: tasks/completion,
categories/projects, events/exceptions, sessions, availability/scheduling,
recurrence, dependencies/sequences, habits/goals, timers/time entries,
templates/saved views, trash/deletions, hierarchy/checklists/progressive plans,
icons, managed attachment bytes, web links and portable appearance/task/calendar
preferences. External paths/bytes, OS permissions/reminders, widget instances and
placement, windows/sidebar geometry, startup/hotkeys, privacy/PIN, credentials,
keys, updates and transfer receipts remain device-specific. No scope expansion.

Confirmed source issues:

- Sign-in, activation and initial exchange require separate user actions.
- First and additional devices see the same unexplained recovery input.
- Automatic conflicts navigate from build into modal dialogs.
- Foreground events lack a minimum interval; polling continues in background.
- Every controller refresh signals a local change, including remote projection.
- Local triggers arriving during an exchange can be swallowed by the shared job.
- The busy icon hides conflict attention, and its badge has no count label.
- Settings exposes routine, recovery and protocol explanations together.
- Conflict choices lack a concise final confirmation for discarded changes.
- Controller resolution refuses offline decisions despite durable local storage.

## Implementation contract before sensitive changes

Retain schema/protocol/encryption/backup formats: no migration, key upload, remote
deletion, new provider, account service or release. First manual request signs in
and continues activation/exchange. Existing encrypted data must raise a typed
one-time authorization state without creating a replacement key. Lost local key
recovery must authenticate the existing proof and preserve the existing SQL
device binding before saving to the secure vault. Damaged retained credentials
are not silently overwritten.

Automatic work uses startup, bounded active polling, debounced committed changes,
throttled resume and durable network backoff. Polling retries provide connectivity
recovery without adding a network-monitor dependency. No continuous OS background
guarantee. Manual requests bypass retry delay; jobs share one exchange and retain
follow-up local work. Existing platform jobs stay compatible.

Conflict decisions remain versioned causal operations. A failed preflight network
refresh may still allow a decision against retained history: the transaction
revalidates its review token, and unseen new changes remain genuine divergence.
Confirmed decisions remain queued if offline. Structural groups still require
consistent decisions for all coupled records; no partial relational application.

UI scope: Sync icon, compact adaptive Sync dialog, one-time recovery step,
advanced recovery/account controls and conflict review. Apply Ultimate UI/UX Fix
and Build workflows proportionally: hierarchy, honest states, keyboard/Escape,
long accounts, short/narrow viewports, IME, 200% text, both themes, semantics and
nonintrusive conflict attention. Runtime/physical/account evidence is separate
from host tests and rendered images.

## Verification policy and checkpoints

Risk: Critical for orchestration/security and conflict durability, Feature for
layout. Reuse beta 7 evidence for unchanged snapshot formats, native integrations,
migrations and packages; it does not validate this changed application. Run
focused engine/controller/pairing/conflict tests during editing, then the sync
group and full serial suite/analysis at the cross-platform integration checkpoint.
Run feasible isolated platform checks. Real Drive requires an authorized
disposable account; no owner account/profile will be used.

| Invocation / purpose | Source | Result | Reason / limits |
| --- | --- | --- | --- |
| Baseline status/log, architecture/source/test/receipt inspection | `0dcfb5a` | Clean; audit above | New task; prior sync mocks and beta 7 release evidence reviewed, not rerun |
| `verify.ps1 -Mode Quick -ChangedPaths lib/app/sync_controller.dart,lib/data/cloud/sync_engine.dart,lib/data/cloud/sync_pairing_service.dart -Tests test/sync_controller_test.dart,test/smart_sync_controller_test.dart,test/cloud/sync_engine_test.dart,test/cloud/sync_pairing_service_test.dart` | `4b26af5` + orchestration working diff; `.buildlog/verify/20261103-144631-0486/` | PASS: format, analysis, 19 tests, diff check | New: sign-in continuation, second-device one-time code, offline decisions in both directions/new divergence, safe lost-key recovery, scheduling/debounce/follow-up; mocked provider only |
| Dart MCP DTD discover/connect; first analyzer probe then roots.add | Current working source | DTD connected, no running app; analyzer initially rejected missing roots; root registered | New tooling setup, not a runtime pass |
| UI Quick verification `20261103-145048-9954` | `eee62a6` + UI diff | Analysis found two missing-brace lints; corrected | New UI gate; tests not started |
| UI Quick verification `20261103-145207-4385` | UI diff | Analysis PASS; 5 tests pass, 3 fail | New badge semantics, short-landscape probe and original IME geometry; corrected explicit badge label, waited for layout after test scrolling, traced keyboard viewport |
| `flutter test --no-pub --reporter expanded test/sync_conflicts_dialog_test.dart --plain-name 'recovery input'` | UI diff; `.buildlog/smart-sync/recovery-diagnostic.log` | FAIL: focused text bottom 589 while keyboard begins at 504 | Diagnostic rerun to measure original failure; scroll-metrics listener subsequently keeps bottom at 416 |
| `flutter test --no-pub --reporter expanded test/sync_conflicts_dialog_test.dart` | UI diff; `.buildlog/smart-sync/ui-corrected.log` | 19 PASS; one test-cleanup failure | Rerun after viewport/semantics correction and expanded state matrix; semantics assertions pass, dispose handle before end-of-test verification |
| Dart MCP analyzer after roots registration | UI diff | No response within several minutes; terminated wait | Tooling limitation; CLI analysis used successfully instead |
| Isolated Windows `flutter run --no-pub -d windows -t lib/driver_main.dart --dart-define=GOOGLE_DRIVE_ENABLED=false` | UI diff; `.buildlog/smart-sync/windows-live.log` | Debug build PASS, 371.4s; live VM/Driver connected; hot reload PASS; runtime error read empty | New runtime evidence; child APPDATA/LOCALAPPDATA under `.buildlog/smart-sync/windows/`; VM Drift isolate confirms that SQLite path before interaction |
| Windows Driver health, Sync icon, diagnostics and screenshot | Isolated PID 100612, 1264x681 dark | Actual compact disconnected/error dialog inspected; Close visible | No Google account configured/contacted; screenshot is runtime evidence, not real OAuth/sync acceptance. Initial HTTP VM URI rejected; corrected to WebSocket URI |
| Feature `sync` verification `20261103-145838-5806` with explicit main/runtime/controller paths and new controller tests | `eee62a6` + evolving working diff | Analysis PASS; 131 tests PASS, two worker-start barrier failures, one engine-test load failure; stopped before remaining tests | New broad sync gate. The two crash workers missed unchanged 60s startup barriers under resource pressure. The engine test loaded a cached old API after an in-run source edit; this mixed-source run is not final evidence for engine scheduling |
| Offscreen UI capture during that feature run | `.buildlog/smart-sync/images/` | All 20 UI tests PASS; 16 PNGs exported | Desktop/phone conflict comparison, 360x640 six-state Sync matrix at 200% in both themes, keyboard inset 340 at 390x844, short landscape 640x360, semantics, Escape, privacy closure and confirmation. Inspected dark phone conflicts, dark recovery and light synced images with a loaded real Segoe UI font; these are host renders, not native Android |
| `dart run .buildlog/smart-sync/capture_windows.dart` | Verified isolated Windows VM | PASS: `windows-sync-dark.png` | Saves the earlier live disconnected/error state. Two hot reloads passed; a later MCP screenshot request returned an error. The final post-review engine correction was not exercised against a real provider. Closed only verified isolated PID 100612 afterward; non-TTY runner could not accept `q` |
| Fresh `SmartSyncAudit` AVD, port 5592, no snapshots/account/app data | `.buildlog/smart-sync/avd/` | Boot/services observed, no completed app UI acceptance | New platform probe; stopped own emulator when memory was low. User AVDs untouched; synthetic data retained |
| Android Debug helper with existing SDK/JDK21/Gradle cache and Drive disabled | `.buildlog/smart-sync/android-build.log` | Aborted after 1163s, no new APK acceptance | System drive had ~20–30 MiB free; memory also constrained. `jcmd 33780 Thread.print` captured cache file creation wait in `gradle-threads.log`. No cache/data deleted; retry redirects task TEMP/TMP/JVM temp to workspace drive |
| First Full setup `20261103-152232-3077` | Working diff | Format PASS; analysis deliberately interrupted before tests | TEMP directory creation had not completed in an earlier yielded shell. Corrected sequencing/environment; no test pass claimed |
| Full `20261103-152312-2866` with D-drive TEMP/TMP | Working diff | Format PASS; analysis found one test override signature mismatch | `GatedController.refresh` now accepts/forwards the new optional notification flag. No assertion weakened; tests had not started |
| Full `20261103-152615-8466` | Frozen code patch SHA-256 `ac0457e8098cce473d00bb7a1b202e26aeb2f797a091eb6cecce76e714d8886b` against `eee62a6` | Format (311 files) and full analysis PASS; serial suite incomplete | Rerun after override correction/environment isolation. No engine/domain edits during this run; later presentation-only guide acknowledgment gets a focused follow-up |
| Full serial suite continuation | Same engine/domain snapshot | Stopped after 33 PASS, no observed assertion failures in that attempt | Compilation spent minutes per test file on the constrained host. Full aggregate gate remains PENDING; current critical paths selected explicitly below. No blanket pass claimed |
| Android Debug retry with task TEMP/TMP/JVM temp on D: | `.buildlog/smart-sync/android-build-temp-d.log` | Stopped after 797s; no new APK acceptance | Still severe memory/I/O pressure; stopped own wrapper/daemon before serial critical checks. Native Android acceptance remains pending |
| Archive stopped compiler output | Exact C-temp directory `flutter_tools.e0c3fb85`; listener references this run's pairing test; no active process references | Preserved intact under `.buildlog/smart-sync/retained-temp/`, freeing ~52 MiB | Read ownership/time/process boundaries first; explicit source/target containment checks before cross-drive move. No owner data or shared cache changed |
| Critical Quick gate `20261103-154429-2595` | Engine/controller/key recovery and UI refinements | Format and analysis PASS; seven controller cases exceeded default 30s; stopped | Severe host pressure; cleanup errors followed timeouts. No aggregate pass claimed |
| Targeted rerun `flutter test --no-pub --concurrency=1 --timeout=5m` with metadata/guide/follow-up name filters | `.buildlog/smart-sync/final-targeted.log` | Three PASS; in-flight follow-up timed out | Metadata-only engine/controller gates and one-time guide pass; follow-up isolated for diagnosis |
| Isolated follow-up/convergence diagnostics | `followup-isolated.log`, `final-convergence.log` | Failed/incomplete | Foreground rollback-journal test executor could stall the event loop past the lease heartbeat under slow I/O. An arbitrary inner deadline also obscured completion; assertions were retained |
| In-memory fixture diagnostic | `memory-scheduling.log` | Refused by verified-backup ownership guard | Memory cannot establish this database's recovery snapshot. Guard preserved; abandoned memory fixture |
| `flutter test --no-pub --concurrency=1 --reporter expanded --timeout=5m test/cloud/sync_scheduling_test.dart test/smart_sync_controller_test.dart` | `.buildlog/smart-sync/production-executor.log` | Eight PASS | Real database files now use production background executor, WAL, foreign keys and busy timeout. Covers in-flight commit, one-time authorization, native scheduling, offline decisions and concurrent resolution; no assertion weakening |
| `flutter test --no-pub --concurrency=1 --reporter expanded --timeout=5m` with engine, pairing, controller, UI and crash-recovery files | `.buildlog/smart-sync/final-regression.log` | 38 PASS | Includes both real subprocess crash rollback tests and 21 UI tests. Explicit PUB_CACHE prevents isolated crash-worker environment from resolving another tool cache |
| `flutter test --no-pub --concurrency=1 --reporter expanded --timeout=5m test/cloud/sync_engine_test.dart test/cloud/sync_scheduling_test.dart test/smart_sync_controller_test.dart` | `.buildlog/smart-sync/final-orchestration.log` | 18 PASS | Final engine driver additionally preserves manual intent when joining a skipped automatic check. Includes two-device convergence and post-upload automatic success notice |
| Full wrapper `verify.ps1 -Mode Full` | Current source, `.buildlog/verify/20261103-175447-3675/` | Format PASS (312 files); analyzer startup stopped after 227s; no tests started | No analyzer diagnostics or child analysis server appeared. Verbose retry with version checks/analytics suppressed also stopped after artifact checks. Neither attempt is an analysis or full-suite pass; direct source-root analysis selected instead |
| `dart analyze lib`, `dart analyze test`, `dart analyze integration_test`, `dart analyze test_driver` | Current source; `.buildlog/smart-sync/dart-analyze-*.log` | All four roots clean after one missing-braces info was fixed and `lib` rerun | Final `lib` receipt is `dart-analyze-lib-final.log`. No behavior change; formatter also passes. This is direct Dart analysis, separate from the stalled Flutter wrapper |
| Full wrapper retry | `.buildlog/verify/20261103-180243-8677/` | Format PASS; repeated silent Flutter analysis startup stopped | Source frozen except the recorded brace-only lint fix before this run. Direct analysis above provides current-source diagnostics; no wrapper aggregate pass |
| `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter expanded test` | `.buildlog/smart-sync/final-full-tests.log`, `f718cbe` runtime source | Two PASS; stopped after over four minutes loading the next unchanged test file | Full aggregate remains pending. Separate final focused runs cover changed behavior. A Windows build was briefly allowed to overlap the stalled file load; neither overlap nor interrupted runs establishes platform acceptance |
| Python preparation/helper tests and changed-document link check | `python -m unittest discover -s tools -p test_prepare_android_release.py`; corresponding `test_dev_verify.py`; `python tools/dev/check-docs.py` with all five changed docs | 11 preparation PASS, eight helper PASS, zero link/catalog errors | Current verification catalog and documentation routes; no APK/provider claim |
| Final Dart MCP `hot_reload(clearRuntimeErrors: true)` | `f718cbe`; connected IDE DTD | No active app; no final-source reload pass | Earlier isolated UI reloads passed; the isolated app had been closed. Final orchestration changes remain supported by host tests, not a live provider exchange |
| `tools/build-windows-release.ps1` | `f718cbe`, `windows-release-final.log` | Incomplete; initial runner stopped after roughly four minutes | Reached CMake configuration. The retained configure child was identified by parent, command and workspace and stopped before proceeding with the retry; no current binary accepted |
| Same Windows helper with process-local `CI=true`, task TEMP/TMP/PUB_CACHE | `windows-release-ci.log` | Incomplete; stopped after roughly ten minutes | Reached CMake, MSBuild and nested Flutter compilation; no source compiler error observed and no successful current binary. CI was process-local; tracked product configuration stayed disabled. Full owned process tree verified and stopped; no owner process touched. Native/CRT/package post-build gates did not run |

The final focused runs cover setup continuation, retained-binding key recovery,
active polling, resume throttle, local debounce, in-flight follow-up, manual
intent, offline/concurrent resolution and the completed UI. Their scopes overlap;
counts must not be added as distinct tests. No protocol/schema change.

Integration review additionally traced the Windows database watcher: lease/cursor
writes also refresh the controller. Both scheduling boundaries now require actual
pending journal operations before treating a notification as an upload trigger.
The engine checks again after debounce, so already-uploaded edits do not cause a
second network exchange. Native writer edits still queue normally. This new
correction is covered by the final engine/controller checks, including a commit
arriving after the outgoing pass while download is in flight. AppController's
original refresh API and notifications are preserved: refresh can also produce
legitimate recurrence changes. The temporary notification flag was fully removed.

Final integration verification is recorded below. Earlier interrupted runs remain
in this ledger for recovery and are not presented as successful aggregate gates.
No push, merge or publication is authorized.

## Final verification status

Implementation is committed for review. Verification is partial, and this is not
a release acceptance receipt. Current source roots pass direct analysis and
formatting; focused engine/controller/key/UI/crash checks pass as scoped above.
The 38-test regression and 18-test orchestration runs overlap. The latter predates
only the brace-only lint correction in `f718cbe`; no behavior changed afterward.
Python preparation/helper checks pass 11/eight; documentation/catalog checks and
`git diff --check` pass.

Earlier isolated Windows Debug GUI/Driver, screenshots and two successful reloads
establish that recorded UI state only. The final-source reload found no active
app. The attempted current Windows Release and Android Debug builds did not
complete; no new executable/APK is delivered or accepted. Native/widget and
installer sources are unchanged; beta 7 native/package evidence is reusable only
for those unchanged boundaries, not as proof of this application's new behavior.

Before release consideration, complete the full serial suite and current Windows
Release/native/package gates on a responsive host; build and run Android in an
isolated profile. Then perform the two-device procedure below with an explicitly
authorized disposable account. Real Drive OAuth/encrypted exchange, physical
Android keyboard/layout and background restrictions, Windows focus/DPI/keyboard
and assistive-technology behavior remain pending. No real provider was contacted
for acceptance. Do not test against the owner's account or profile. No further
source change or format migration is required merely to resume these checks.

All started task app/emulator/build/test processes have been stopped; retained
synthetic profiles, logs and images are under ignored `.buildlog/smart-sync/`.

## Implemented behavior for review

Manual Sync now signs in when necessary, then safely prepares or reuses the
account's encrypted data, activates capture after a verified recovery snapshot,
and runs the existing exchange. It checks the account/proof and SQL lease,
retries exact staged encrypted uploads, advances authenticated Drive changes,
reconciles safe transaction groups and records the actual outcome. A bounded or
failed exchange remains pending/attention/offline; it cannot announce up to date
prematurely. Restore quarantine still requires explicit reconciliation.

Automatic opportunities are startup, foreground return (15-second minimum),
two-minute active polling and 750-ms committed-change debounce. Pending journal
checks prevent remote projection and SQLite metadata from causing a network/job
feedback loop. An edit committed after the outgoing pass schedules a follow-up.
The durable journal, staged ciphertext and existing exponential retry policy
survive restarts. Connectivity recovery uses those polling/retry opportunities;
there is no new permanent network listener. Background scheduling remains the
existing Android/Windows adapter and remains subject to OS/privacy policy.
Automatic on/off is a device preference. Interval overrides are engine-level;
no new user-facing interval preference was introduced.

Conflict choices remain per record, with counted bulk selection and an explicit
confirmation before competing values/deletions are accepted. Safe independent
fields survive either choice. The consolidated review requires decisions for
all records needing a choice, and consistent choices for structurally coupled
records; partial relational application is not introduced. Decisions are durable
causal descendants of all reviewed heads, even for unchanged local bytes. The
existing transaction rechecks the review token. Offline decisions remain pending
and upload later; genuinely unseen divergence is not falsely acknowledged.
Matching concurrent decisions converge, incompatible ones retain a new conflict.
The UI keeps a counted semantic badge during background work without automatic
modal navigation. Manual sync and Settings provide direct review.

Encryption and recovery retain the existing AES-256-GCM formats and profile-keyed
OS vault. First-device setup is automatic after sign-in, with a recovery-code
reminder. Additional devices get one guided authorization step and then retain
the key securely. A missing vault key can be recovered only by authenticating the
original proof while keeping the existing SQL device identity. A damaged or
incompatible retained credential is preserved for reviewed recovery. Losing all
authorized copies and the recovery code still makes the data unrecoverable;
Google authentication cannot reconstruct the key. Existing optional app locking
remains device-specific. No key/plaintext upload or automatic encryption bypass.

The regular UI contains account, honest status, last successful exchange, one
primary action, automatic sync and conflict attention. Recovery/account controls
and pending-operation details are advanced. The dialog has constrained width,
natural wrapping, one scroll region and reachable Close actions. Actual viewport
metrics keep the recovery input above the keyboard. Both themes, long addresses,
large text, compact/short layouts, Escape, privacy and semantic attention have
focused host coverage. The first-device guide is consumed after viewing/revealing
the code, rather than reopening for every subsequent manual request.

Google Drive still uses the user's own hidden application storage and configured
publisher OAuth application. The existing provider-independent adapter remains;
no new provider, central hosting or end-user developer configuration is added.
The tracked default public configuration remains disabled; local builds with
Drive explicitly disabled cannot establish production OAuth acceptance. Snapshot
backups stay separate and compatible, with no retention/deletion changes.

There is no database or cloud migration: schema 26, protocol 1, account/workspace
identities, immutable operations, tombstones, snapshot formats and backup history
remain compatible. Older supported clients still read the same protocol. Existing
bounded history/review limits remain conservative; no compaction or automatic
history deletion is added. No owner profile or real cloud data is modified.

## Two-device acceptance procedure

Use disposable profiles, synthetic records and an authorized disposable account.
On Windows press Sync, sign in and save the recovery code privately. On Android
press Sync, select the same account and enter that code once. Confirm both devices
show the actual completed exchange before comparing data.

Create/edit/complete/delete synthetic records in both directions. With automatic
sync enabled, leave both apps active and observe arrival after their next check;
repeat foreground and restart opportunities separately. For conflict testing,
take both devices offline, edit the same field differently, reconnect and review
both values. Apply a decision on either device, sync both and restart: the old
conflict should stay resolved. Repeat with a deletion, independent-field edits,
bulk choices, offline decisions and genuinely new divergence. Keep snapshot
backup/recovery acceptance separate from this current-data exchange.

Real-provider, physical-device/OS scheduling, Windows focus/DPI and native
assistive-technology acceptance require their own evidence; mocked storage and
host images do not establish those outcomes.

## Changed files and checkpoints

| Files relative to the repository | Purpose |
| --- | --- |
| `lib/app/sync_controller.dart`, `lib/main.dart` | Setup continuation, lifecycle, honest state, pending-change/native scheduling gates and offline resolution orchestration |
| `lib/data/cloud/sync_engine.dart` | Active polling, resume throttle, debounced incremental triggers, in-flight/manual intent and honest lease contention |
| `lib/data/cloud/sync_pairing_service.dart` | Typed one-time authorization and verified missing-key recovery retaining SQL identity |
| `lib/features/shared/sync_status_button.dart` | Persistent counted accessible conflict attention and explicit manual navigation |
| `lib/features/settings/sync_settings_page.dart`, `lib/features/settings/sync_conflicts_dialog.dart` | Compact onboarding/status, advanced recovery, keyboard geometry, individual/bulk decisions and confirmation |
| `test/cloud/sync_engine_test.dart`, `test/cloud/sync_scheduling_test.dart`, `test/cloud/sync_pairing_service_test.dart` | Scheduling, incremental exchange and key-recovery regression coverage |
| `test/smart_sync_controller_test.dart`, `test/support/mock_sync_drive.dart` | Real-file two-device authorization, offline/concurrent convergence and controlled provider failures |
| `test/sync_conflicts_dialog_test.dart` | 21 layout/state, interaction, semantics, privacy and one-time-guide checks |
| `tools/dev/features.json` | Include the new controller/scheduling cases in the explicit sync verification group |
| `docs/SMART_SYNC_REDESIGN.md`, `docs/GOOGLE_DRIVE_SYNC.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/PROGRESS.md` | Audit, safety contract, behavior, recovery ledger and handoff |

Local checkpoints: `4b26af5` audit/safety contract, `eee62a6` authorization and
automatic exchange, `c9784cf` compact UI/conflict review, `f718cbe` manual intent,
metadata gates and final regressions. Integration evidence follows in the final
documentation commit. Version remains beta 7; no remote push, merge, tag or
publication. Build logs, synthetic profiles,
screenshots and temporary tooling remain ignored local artifacts.
