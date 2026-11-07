# Real Windows/Android Standard Sync acceptance (2026-11-06/07)

**Final: authorized real Standard Sync acceptance PASS within the exercised scope.** The reproduced restore-decision failure now has a packaged correction and passing real replay. Both corrected candidates converge at383 operations across43 portable tables, pending/conflicts/waiting zero. No release approval. Branch `feature/sync-ux-refinement`,
HEAD `4dcda12`. Owner authorized only the verified spare Google account,
existing Standard workspace `315ab404-bbd0-55d3-b0d1-10afafe13fbc`, isolated
Windows candidate and retained Android emulator, with synthetic data. No Start
New Sync, Private Sync, cloud snapshot testing, cloud cleanup or publication.

Evidence is outside Git under
`D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\evidence\cross-platform-standard`.
Receipts include local UTC+03 timestamps or explicit UTC timestamps. Current
dirty-source hashes are in `235-current-source-and-artifacts.json`; previous isolation inputs and
binary identities retain their separate receipts. Protected storage documents
remain unchanged. Tokens and credential contents are never printed; account metadata remains in private receipts outside Git.

## Verified checkpoint

Android joined the existing workspace through **Set up sync**, with independent
device ID `0ca9c2e0-090c-40d5-93c6-b9162d0dfaa4`. It completed a real Google Drive
exchange at 19:48 UTC+03: up to date, no pending work, waiting groups or conflicts.
The account ID matched the verified Windows spare receipt before pairing.

The DB/WAL-only readback at 19:50 (`12-first-download/comparison.json`) passes
SQLite integrity and foreign-key checks, schema 27, all **43 portable tables**
equal to Windows, and all **81 Windows immutable operations** retained unchanged.
There are 12 tasks (10 active, two soft-deleted), two events (one active), and
90 Android journal rows, versus 81 Windows rows. Device-local journal counts are
not assumed equal: portable records and original operation identities are the
comparison boundary. Recurrence slots, parent/subtask and named checklist rows,
category/project/event assignment, managed attachment bytes and metadata match.
The two deleted tasks did not reappear in this first download.

After a later debugger reattachment failed and the Android app terminated,
`15-after-runtime-crash/comparison.json` again shows identical DB/WAL hashes,
all 43 tables matching, no missing/changed Windows operations and valid integrity.
This proves persistence through that observed termination; it does not establish
interruption during an active upload or determine the crash's cause.

## Confirmed defects and correction boundary

1. **Android pairing/reconciliation database identity.** SQLite reports
   `/data/data/...`, while the recovery service uses `/data/user/0/...`; these
   are the same file and directory on this guest. String comparison rejected
   the legitimate Before Sync snapshot before activation. The scoped guard now
   checks physical identity of both database and journal directory, with the
   same basename. A hard link in a different WAL directory remains rejected.
   Activation and restored reconciliation share this guard. No schema, journal
   identity, cloud protocol, token store or workspace ownership change.
   Focused alias, different-database and different-journal hard-link regressions
   pass, alongside the relevant existing journal/restore tests. Live hot reload
   applied the correction before the successful first exchange.
2. **Android network-constrained background jobs.** The manifest lacked
   `ACCESS_NETWORK_STATE`, required from Android 14 for the existing network
   job constraints. The foreground exchange succeeded but reported background
   checks unavailable. Added that normal permission. A native instrumentation
   probe was attempted but abandoned. The real production scheduling call
   and registered network job are the passing OS evidence recorded below.
   [Android's JobInfo contract](https://developer.android.com/reference/android/app/job/JobInfo.Builder#setRequiredNetworkType(int))
   documents the requirement. Actual scheduler acceptance passed; background
   delivery under Doze/OEM restrictions remains unverified.

The original APK remains preserved; first-download evidence used that APK plus
the documented live Dart correction, not an unchanged packaged-source claim.
One corrected Android Debug build is justified so the fix survives restart.
The unchanged private Windows binary is reused; its canonical Windows database
path did not encounter the Android alias defect.

The later app SIGSEGV is retained in `crash-after-checkpoint.log`: one frame in
Dart-generated code during debugger evaluation after reattachment. No established
root cause or application-code crash fix is claimed. The same buffer includes a
Bluetooth HCI timeout abort in another process. `system_server` remained PID572;
do not relabel these as a reproduced system-server/ART boot failure.

## Production isolation checkpoint

At 22:18 the old baseline guard stopped further exchange: production privacy
session and encrypted-credential hashes had changed, and DB/WAL were locked.
Process metadata showed the installed production app/widget launched at about
20:41â€“20:42, after the earlier checkpoint. No credential contents or personal
records were read. Startup configuration and three protected docs still matched.

The owner confirmed using production Todorbit during the pause, closed it and
authorized a fresh baseline. All 18 original paths were hashed twice after
verifying the installed processes were closed. The original baseline/recovery
copies are retained; `production-cross-quiescent-before.json` is the new baseline.
The local Windows acceptance helper now uses that baseline explicitly. The
mismatch is explained by owner-confirmed activity, not asserted to be a private
candidate write. `safety-stop.json` and `safety-stop-resolved.json` preserve both
states; no bypass or silent rebaseline occurred.

## Invocation and reuse ledger

Detailed per-phase XML/PNG, commands, manifests and logs remain in the evidence
directory. Failures are retained and superseded only for their named boundary.

| Invocation / evidence | Outcome and scope / reason |
| --- | --- |
| Supported Android Set up sync; exception probes | Failed before capture on real database path aliases; stacks retained. No replacement workspace or fixture upload. |
| `flutter test --no-pub --concurrency=1` with new recovery identity and existing journal/restore files | Initial compile fixture failed; next run 11 passed/two Windows `mklink` separator fixture failures. Normalized fixture paths; reran only the two failed cases, both passed. Logs `path-alias-regression-1/2/3.log`; no failed product assertion suppressed. |
| Targeted `dart analyze` on two recovery parts and regression | No issues; `path-alias-analyze.log`. Subsequent test-only native path normalization does not change product statements. |
| Isolated Flutter attach / Dart MCP hot reload | Initial unsupported flag/port attempts retained. Correct guest-port attach and one-library reload applied guard; actual library probe and successful pairing establish deployment. No personal app attached. |
| `android_action.dart 11-controlled-manual auto-off` | Supported controller disabled Android automatic exchanges for controlled tests. |
| `snapshot.py 12-first-download compare` | Real first Android exchange: 43 tables and 81 Windows facts match; integrity/FK pass. |
| Resumed attach and `13-background-diagnostic` | Evaluator lost connection; no diagnostic receipt claiming success. Guest app SIGSEGV retained, cause unproven. |
| Production baseline guard and metadata diagnosis | Failed closed; owner-confirmed production use and fresh double-hash baseline recorded separately. |
| `snapshot.py 15-after-runtime-crash compare` | Same database/WAL bytes and portable/immutable assertions pass after termination. |
| `build-changed-android.ps1` | One necessary changed-source Debug build; current result pending. Preserves/restores original local.properties bytes and reuses existing SDK/JDK/CMake/Gradle cache. |
| Reused Windows real Standard milestone | [Windows upload/download, duplicate replay, local restore/reconcile and lost-reply results](REAL_STANDARD_SYNC_2026_11_06.md) remain valid for the unchanged binary. Host mirror is not called Android. |
| Reused auth/emulator evidence | [Spare-account identity and read-only workspace inventory](ANDROID_DRIVE_READINESS_2026_11_06.md), same retained Play AVD/data/image. No sign-in repetition, wipe or new AVD. |

## Historical scenario status at the first checkpoint

| Scenario | Status at this checkpoint |
| --- | --- |
| Existing workspace pairing; real Windows records arriving on Android | PASS after scoped fix deployed live; packaged restart check pending |
| Stable IDs, 43-table relationships, original causal facts, attachment bytes | PASS for first download and post-termination readback |
| Existing task tombstones remain deleted | PASS for first download; repeated bidirectional resurrection probe pending |
| New Windows â†’ Android creation/updates | Pending controlled fixtures |
| Android â†’ Windows creation/updates | Pending controlled fixtures |
| Bidirectional task/event deletion and completion | Pending controlled fixtures |
| Offline edit/delete conflict and reviewed resolution | Pending real cross-device divergence |
| Repeated exchange without duplicates/loss | Pending repeated Android exchanges |
| Recurring instances/exceptions, composition, category/project/event assignment | Existing Windows data readback PASS; new Android-authored cases pending |
| Managed resource metadata and attachment bytes in both directions | Existing Windows data readback PASS; Android-authored case pending |
| Interrupted active exchange and retry | Pending; observed idle/debugger termination is not this assertion |
| Android local backup/restore, restart and reconciliation | Pending; Windows prior result reused only for Windows |
| Background scheduler/native fixed permission | Pending packaged native probe; foreground already passed |
| Final production hashes/startup and protected source | Fresh authorized baseline established; final comparison pending |

No full suite, unchanged Windows rebuild, commit, push, tag or release. Original
unfamiliar-task cause remains unproven; no personal data used to reproduce it.

## Continuation through 23:04 UTC+03

The first changed APK build passed in 346.7 seconds and all seven native-library
ELF/applicable ZIP alignment checks passed. It was archived as
`packages\Todorbit-1.0.19-beta.12-schema27-android-sync-alias-debug.apk` under the
private root. `fixed-apk-identity.json` records its exact SHA-256/size. The package,
version35 and debug certificate match the retained original APK. Installed with
explicit emulator serial and `install -r -t`; no uninstall/clear. Native restart
retained the account, workspace, device ID and Automatic Sync off.

The packaged app downloaded the new Windows fixture through its native Sync
button. `29-native-windows-download` matches all43 tables and117 operations on
both devices. Native Android forms/input then created a task with notes and
completed it; a compiler-free invocation of the real Android repository deleted
the designated synthetic event. Actual controller Automatic Sync enabled a real
exchange, with OS JobScheduler2028 successfully registered with a network
constraint and no scheduler warning. Automatic was disabled again. The Windows
candidate retrieved these changes: `52-bidirectional-first-compare` matches all43
tables and121 operations, no pending/conflicts or integrity/FK failures.

For the offline case, both Android Wi-Fi and mobile data were explicitly disabled
(previous values retained and later restored). Native editing appended a title
change to the Windows fixture's conflict task. Windows concurrently deleted the
same ID and independently updated the parent, Android-authored task and event.
On reconnect, the real Android exchange retained one conflict. The native review
showed **Restore â€“ This device** versus **Keep deletion â€“ Cloud**. Selected the
latter, reviewed the confirmation for exactly one deletion, then confirmed Apply
decisions. Both versions remained until application. `79-resolution-convergence`
matches all43 tables and132 operations on both devices, pending/conflicts zero.
`reviewed-delete-causal-proof.json` verifies the resolution directly names both
the edited and deleted heads as parents and retains the tombstone. No silent
resurrection or discarded unresolved edit occurred in this scenario.

Additional native Android journeys created a named checklist/item, a full subtask
and a project-linked calendar event; edited the notes that Windows had sent back;
and used the real Documents picker/Downloads to attach a synthetic63-byte file.
Stable IDs, parent/group memberships, category/project IDs, stored content and
SHA-256 were checked before exchange (`android-rich-fixture-ids.json`). Android
uploaded them and Windows retrieved them. `125-rich-cross-platform-compare`
matches all43 tables and140 immutable operations on both endpoints. These are
real Android app writes and real Google Drive transport, not a host mirror.

Android then edited its event and soft-deleted its new child with both networks
disabled. A native Sync tap was followed by a read-only VM observation of
`busy=true`, then force-stop of only the verified private package/PID19780.
`137-controlled-interruption.json` records the preconditions; the emulator and
authenticated userdata remain running/intact. Both pending immutable operations
survived unchanged (`interrupted-pending-preservation.json`, snapshots133/138).
This is interruption of an active requested exchange before network completion,
**not** an Android lost-reply-after-commit claim. Recovery/retry is pending next.
Windows separately uploaded its normal event deletion and a synthetic recovery
sentinel (`cross140-windows-event-delete`); Android has not yet retrieved them.

### Further defect and tooling boundaries

- A Sync status action snackbar persisted during accessible navigation and
  covered the editor's Create button. Initial covered taps did not save anything;
  DB verification caught this. Native downward dismissal uncovered Create, and
  the task then saved. Added `showCloseIcon` to the routine status snackbar,
  consistent with the existing Standard introduction. The focused recovery-guide
  widget case now verifies persistence with accessible navigation and explicit
  Close dismissal; it passes. No protocol/Sync-state change. This one-line UI
  change is the reason for the second, final Android build currently in progress.
- Repeated compiled debugger expressions invoking the background callback caused
  the same Dart-code SIGSEGV even after a clean APK launch. Stopped using that
  evaluator path. Normal native UI and VM `invoke` of existing compiled
  repository/controller methods work without that crash. This distinguishes a
  debugger-assisted reproduction from an established ordinary-user app crash.
- Corrected external VM Future polling: an unfinished Future's null listener
  slot was incorrectly treated as a completed null result. Null receipts were
  not accepted as proof; actual DB/account/native UI checks supersede them.
  HTTP VM list arguments also required the service's URI list encoding; rejected
  parameter attempts made no mutations. Regular invocation avoids an expression
  compiler and is labelled separately from native touch/keyboard journeys.
- Corrected external UIA evidence: failed dumps can return exit0 and leave an old
  remote XML file. The helper now requires a newly named hierarchy plus a
  successful dump message before every tap. Post-action dump failures cause a
  fresh observation, never automatic repeat of the action. Unicode console
  output and expected offscreen/covered controls were diagnosed separately.
- Cold native launch initially timed out and Google Play reported ANRs during
  host RAM pressure. Cancelled the owned native-test build client, stopped only
  the task Gradle daemon, normally closed private Windows and waited for memory
  recovery. Available RAM recovered from about0.5GiB to over6GiB; no personal
  process was terminated. The retained emulator/system_server were not restarted.
  Initial native-test wrapper treated stderr warnings as PowerShell errors; no
  application compiler failure or native-test pass is claimed for that attempt.

### Additional invocation index

Each numbered native action has its XML/dump output, with successful actions in
`ui-actions.jsonl`. Individual phase JSONs identify scope/account/path checks.
Snapshot directories retain DB/WAL-only hashes, comparisons and integrity checks.

| Command / phase group | Actual result and boundary |
| --- | --- |
| `windows_fixture_test.dart` /14, private helper cross16, native tap26, compare29 | Windows rich creation/upload and real Android readback PASS,117 operations each. |
| Native forms31â€“42; snapshot38/43 | Post-dump and covered-save attempts retained; only42/43 establishes saved Android task/notes. |
| Native completion45; Android repository invocation46; controller47/48 | Real Android task completion/event deletion uploaded; actual network-constrained scheduling PASS, then Automatic off. |
| Backup enum probe /49 | Initial static-field inspector error; corrected enum-instance lookup. Actual Android `BackupService.createBackup(manual)` PASS, snapshot path retained; no cloud backup. |
| Private Windows cross50/51, compare52 | Androidâ†’Windows creation, completion and event deletion PASS;121 operations each. |
| Native offline edit53â€“58; `windows_updates_test.dart` /59; compare60; cross61/62 | Local divergence and real Windows upload PASS. Initial causal-query helper used raw UUID rather than structured record key; corrected query verifies retained heads. |
| Native exchange63; conflict64â€“72; cross74/78; compare79 | Explicit one-record keep-deletion resolution, propagated tombstone and both-head parent proof PASS;132 operations each. Phases70/71 precede final confirmation, not a resolution success. |
| Native Android edits/resources/composition/events77â€“119; snapshot120; upload121; cross123/124; compare125 | Both-direction parent/child, named membership, event-project, attachment bytes and follow-up edit PASS;140 operations each. Wrong parent-column name in external verifier corrected to `task_parent_links`. |
| Native Android event edit128â€“131 and repository child deletion132; snapshots133/135/138 | Two pending facts preserved. Initial retained-widget callback selector was ambiguous and aborted before action; actual native tap137 observes busy and force-stops owned app. Retry not yet complete. |
| `windows_recovery_fixtures_test.dart` /139; cross140/141 | Windows event deletion and new cloud recovery sentinel upload PASS. Private Windows normally closed. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/sync_conflicts_dialog_test.dart --name 'the first-device recovery guide'` | One focused accessible-navigation/Close regression PASS; `sync-message-close-regression.log`. Unchanged other conflict cases reused. |
| `dart format` on five affected Dart files | Zero changes. |
| `dart analyze` on the same five Dart files | No issues; `final-focused-analyze.log`. No full-suite rerun. |
| `build-final-android.ps1` | Necessary UI correction packaging in progress; first APK and local.properties evidence retained under separate names. |

Latest repeated Windows safety checks (cross141 at23:04) match all18 refreshed
production paths, startup, private runtime/account and frozen executable/AOT
identities. No personal profile, cloud workspace or credential content accessed.
The three protected storage-document hashes remain matched. Final recovery,
repeat-exchange and production checks remain pending; this is not a completed
all-scenarios acceptance report yet.

## Storage stall and reviewable continuation plan (23:50 UTC+03)

The final application build passed in211 seconds, including seven-library
alignment. Installed APK matches the archived SHA-256
`4463604f7b10c20bc650517dbd51b4e5d5c073b853d8d0ab8e104a9cac1b7e8b`:
`packages\Todorbit-1.0.19-beta.12-schema27-android-sync-recovery-ui-debug.apk`
(187,134,954 bytes). Version35/package/debug certificate unchanged. Both APKs,
original retained APK and local.properties byte hashes are preserved. Current
main APK includes all three fixes; Windows binary remains unchanged.

The optional native test compiled, but Gradle's generated manifest exposed only
the existing widget runner, so a second instrumentation component could not be
started. A reuse attempt through the registered runner became I/O-bound during
Gradle configuration. Cancelled only its recorded client/daemon, archived the
test-source attempt and removed the unexecuted extra test code from the working
tree. Existing widget runner is unchanged. No native-fixture pass is claimed;
the actual production scheduling call and registered network job from47 remain
the real OS evidence. Logs `native-scheduling-build-2/3.log`, manifest/blame and
stop-process receipts retain the distinction. No repeated application rebuild.

The app's cold restart stalled before account readiness. Root VM inspection and
UIA timed out; no new exchange was authorized by the harness. After the owner
freed memory, host available RAM briefly measured7.9GiB. Restarted **only the app**
once under that changed condition, without restarting/wiping the emulator.
The same `system_server` PID572 and QEMU PID24052 remain. Launch/resource reads
and app-private hashing still stall. Guest `top` reported167% I/O wait across
two CPUs, with about1.6GiB guest memory available; host disk samples included
135.6ms average read latency/queue11.6. These are observed pressure/stalls,
not proof of a single hardware or application root cause. No matching disk/
storage-error events were found in the sampled last hour. No drive-failure claim.
SIGQUIT trace collection was inconclusive; debuggerd required root, which was
not used. No credential/heap dump or privilege bypass.

The writable AVD and emulator executable are on **external USB D:** (StoreJet
Transcend), not the internal NVMe. D: has277.9GiB free, so it is not full. The
effective kernel/system/vendor image paths are already on the internal C: SDK.
The AVD's writable files total about1.35GiB. The launcher requests2048MiB, but
the generated hardware file records2560MiB and guest memory agrees; this is
recorded rather than assuming the requested value took effect.

A verified **synthetic DB-only** recovery checkpoint has been copied to
`C:\Users\User\AppData\Local\TodorbitPrivateTesting\RecoveryCheckpoint-20261106`.
Both copies pass schema27/integrity/FK checks; Android's last verified snapshot
retains its two pending operations and Windows has zero pending. The source is
the previously verified Android snapshot138, **not a claim that the currently
stalled live disk was freshly verified**. No OAuth/Google credential files were
copied. `ssd-recovery-checkpoint.json` records byte hashes and source boundaries.

Smallest proposed environment change, **not yet executed**:

1. Gracefully stop the single task AVD and verify QEMU exits. Do not force-stop
   its storage backend if shutdown cannot flush; retain evidence and stop there.
2. Copy the same retained `.avd` directory and verified emulator37.2.13 software
   to `C:\Users\User\AppData\Local\TodorbitPrivateTesting\AndroidSSD-20261106`,
   with owner/SYSTEM/Administrators permissions and offline hash verification.
   C: has112.4GiB free. Preserve D: originals; no wipe, new AVD or new downloads.
3. Redirect only the task-owned AVD locator to the SSD copy, retain the original
   locator, same AVD name/device identity, port and existing C: system image.
   Guard against running the retained source and copied identity simultaneously.
4. Start that same authenticated AVD once from SSD. Requalify system services,
   database/account/workspace and pending immutable facts before any exchange.
   Then resume retry, no-duplicate/tombstone and local restore/reconcile cases.

This needs owner approval because the latest instruction explicitly says
**continue without restarting the emulator**. There is no approval requirement
invented by a skill. Until that constraint changes or this environment recovers,
the current Android retry/restore/repeated-cycle scenarios remain BLOCKED.
Existing workspace/history and authenticated userdata are preserved; no Start
New Sync, account switch, Private Sync or cloud snapshot action is proposed.


## Approved SSD relocation and resumed exchange (2026-11-07, UTC+03)

The owner explicitly approved one controlled relocation/restart. The guest
accepted a graceful shutdown and QEMU exited; no storage backend was forcibly
killed. Copied the same AVD and verified emulator 37.2.13 to
`C:\Users\User\AppData\Local\TodorbitPrivateTesting\AndroidSSD-20261106`.
The offline manifest verifies 461 files / 7,582,922,545 bytes. All four copied
qcow2 image checks passed, relative backing paths needed no rebase, and D:
originals remain. Only the task locator and copied derived absolute paths changed.
Owner/SYSTEM/Administrators permissions restrict the SSD root. No wipe, replacement
AVD, account reset, new download or simultaneous duplicate device was used.
`ssd-relocation-owner-approval.json`, `ssd-copy-manifest.json`, image-check logs,
`ssd-path-switch.json` and `ssd-boot-launch.json` retain the exact scope.

Boot completed in47.665 seconds. PackageManager, Google Play Services and app
launching resumed; the first cold app launch exceeded its short wait, then
completed. Initial snapshot153 was too early for the DB/WAL; fresh156 succeeded.
Receipt157 verifies the same authenticated spare account, workspace and original
Android device ID. Both queued immutable operations survived unchanged. Host RAM
remains limited (0.89GiB free of15.74 at04:01); no build/compiler/emulator restart
was repeated. Observed responsiveness improved after the controlled storage move;
this does not prove that USB storage was the sole cause of every prior crash.

| Invocation / evidence | Result and boundary |
| --- | --- |
| Native159 Sync after SSD account/pending verification; status162 | Real Google exchange passed, pending/conflicts zero. |
| Windows cross164 receive / cross166 close; snapshot167 | All43 portable tables equal; both journals144, all immutable Windows facts retained, integrity/FK pass.22 task rows,5 tombstoned;6 event rows,3 active. Android edit/child deletion and Windows event deletion arrive correctly. |
| Native168/169 status dismissal | Final APK visibly exposes Close; native tap dismisses the persistent status message. Actual UI correction verified. |
| Native170?180 local recovery navigation | Network disabled with automatic Sync already off. Opened Settings/Data and app/Backups/local history. No cloud snapshot operation performed. |
| Private VM selector probe181 / screen182 | Private handler was not callable via this selector; no confirmation or restore scheduled. Switched to observed native row, without compiled evaluation. |
| Native183?186 exact manual backup review/confirmation | Reviewed Nov6 22:43 backup:20 tasks/4 events. App confirmation explicitly replaces on next launch and retains Before Restore. Scheduled through native Confirm replacement. |
|187?192 app restart/quarantine | Restored local schema27 snapshot, integrity/FK pass. Same workspace bound; Sync disabled/quarantined and automatic off. Initial immediate auth read was not ready;195 verifies account after initialization. No emulator restart. |
| Before Restore196 | SHA matches app receipt; integrity/FK pass; all144 pre-restore operations retained. Initial probe guessed wrong table name; corrected read-only query to sync_journal, without copying/replacing again. |
| Native197?204 restored reconciliation | Packaged alias guard passes. Fresh Android device ID in same account/workspace; all144 immutable facts retained,59 pending reconciliation operations, automatic off. Older snapshot has intentionally older portable values pending review. |
| Native205 exchange /208?212 review | Real exchange exposes8 waiting groups and5 user decisions (7 detailed records including compatible internal rows). Every cloud candidate exactly matches the verified current Windows row; retained read-only review JSON212. |
| Native213?215 counted resolution | Selected reviewed cloud values; confirmation names5 decisions/2 deletions. Applied normally; no silent discard. |
| Status217 / native219 retry | Decisions durable, pending7, conflicts/waiting zero; requested manual exchange to finish their upload. Completion still pending at this checkpoint. |
| Safety193 / source216 | All18 production hashes, startup and3 protected docs match.20 frozen private-isolation sources unchanged; product/build hashes match final APK inputs. Abandoned native probe removed; existing widget runner unchanged. |


## Restore-decision defect and current stop boundary (2026-11-07)

**Confirmed application defect, not damaged Drive content:** after local restore,
newer Before Restore journal rows were retained as already known. The ordinary
unknown-row closure therefore did not advance their received clocks. Applying
reviewed decisions made those newer groups visible while recording a smaller
observed clock. Outgoing revision validation correctly rejected the resulting
seven decisions before staging/upload, with `FormatException: Invalid sync revision`.
The generic UI warning described cloud verification even though this failure
originated in the local outgoing queue.

A read-only debugger exception pause captured the exact stack in
`SyncExchangeRepository.prepareNextSyncBatch`, without compiled expressions,
credentials or heap dumps. Exception pausing was disabled and the isolate resumed.
Snapshot223 and227 both show all43 portable tables equal to Windows:22 task rows,
17 active/5 deleted,6 events/3 active. All144 pre-restore immutable operations are
retained. Android now has210 operations, including59 restoration candidates and
7 decisions; the latter remain local, never staged, pending. Cloud received the
59 valid candidates; they are retained history, not a replacement workspace.
Windows remains at144 operations and has not exchanged those later candidates.

Minimal correction in `lib/data/sync_restore_repository.dart`: after recording
the restored view as a concurrent action, merge the known retained per-device
sequence maxima into received history before enabling later local actions.
Workspace/account filters remain; no immutable operation, protocol, schema,
credential, encryption or workspace ownership is rewritten. The enhanced
`test/sync_restore_repository_test.dart` proves the older restored action does
not acknowledge later work, while a subsequent reviewed decision encodes,
downloads and applies on a peer with the correct observation clock. Original
queued ciphertext and Before Restore hash assertions remain.

| Invocation / evidence | Outcome and necessity |
| --- | --- |
|221?224 local queue diagnosis | Real upload blocked;7 pending,0 conflicts,0 waiting. Actual FormatException stack captured; all portable data still matches. No cloud reset or cleanup. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/sync_restore_repository_test.dart --name 'restore retains'` | `restore-decision-clock-repro.log`: FAIL with the exact real Invalid sync revision, before product correction. New assertion extends previously insufficient restore evidence through decision upload. |
| Corrected restore + alias files | `restore-decision-clock-corrected.log`: alias3 PASS; restore fixture did not compile because its new peer call omitted required lease. Product assertion not suppressed. |
| Corrected restore single file | `restore-decision-clock-corrected-2.log`: encoding now passes; new peer harness incorrectly required every intermediate group to apply rather than allowing an unresolved ancestor before its later decision. |
| Final restore single file | `restore-decision-clock-corrected-3.log`: PASS. Drain uses the same applied/needsReview progression as the engine; final peer title and zero-conflict assertions pass. Existing alias3 passes reused; no full-suite rerun. |
| `dart format` / focused `dart analyze` | Formatting applied only affected files. Initial analyzer found one now-unnecessary fixture cast; removed it. `restore-clock-analyze-final.log`: No issues. Mechanical cast removal does not invalidate behavioral pass. |
| Own Android Flutter attach / Dart MCP hot reload / runtime errors | Attach to verified PID5086 only; hot reload succeeded with0 libraries, no unhandled runtime errors. Loaded-script inspection229 confirms clock fix is **not deployed**. No real corrected-flow pass claimed. Detached only the owned SDK attachment; guest/account remain. |
|227 /234 immutable queue verification | All210 immutable operation tuples unchanged;7 decisions have no staged batch. Never rewrote their observed JSON, marked them uploaded, or erased them to pass acceptance. |
| Windows cross230 read-only preflight / cross232 normal close /233 | REAL Drive GET:21 objects, all11 original IDs/properties retained, one same workspace proof, protocol2/account/workspace match. Final preflight does not claim fresh media-byte hashes. No Sync from Windows at this checkpoint. |
|228 /235 | All18 production paths/startup/protected3 docs match.20 frozen isolation sources unchanged. Current source hashes and final APK recorded separately: the clock fix is not packaged or real-service retested. |

The prior Android build remains the exact tested187,134,954-byte artifact, SHA-256
`4463604f7b10c20bc650517dbd51b4e5d5c073b853d8d0ab8e104a9cac1b7e8b`,
at `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\packages\Todorbit-1.0.19-beta.12-schema27-android-sync-recovery-ui-debug.apk`.
It contains the alias, network permission and snackbar fixes, **not** the later
clock correction. No fourth application build was run merely to overwrite this
known evidence or before resolving how to recover the immutable invalid queue.
The Windows ZIP/main/AOT remain unchanged and separately verified by cross232.

### Historical assessment before approved checkpoint recovery

These rows concern **real Google Drive**, except explicitly identified host
regressions. They do not convert adapter/simulated evidence into service results.

| Scenario | Result / exact evidence and limit |
| --- | --- |
| Same spare account, existing workspace pairing | PASS: supported Set up sync, stable workspace/protocol; account equality rechecked after SSD move and local restore. No replacement/reset/retirement. |
| First Windows download / stable IDs / causal facts | PASS:12 tasks/2 events,43 portable tables, all81 original Windows operations retained. Later complete convergence at117,121,132,140 and144 operations. |
| Windows-created tasks/events and updates on Android | PASS: rich Windows seed and later title, notes, date/status/priority, assignments and event-series updates verified in native UI and SQLite. |
| Android-created task/event, notes and edits on Windows | PASS: native Android task/event forms, task completion, edited event and notes transported through real exchanges and43-table comparison. Some synthetic setup/deletion actions use real compiled repository/controller methods, not native touch. |
| Task/event deletion in both directions | PASS before restore: Windows task/event deletion and Android event/child deletion arrive. Five task tombstones and three deleted event rows remain at144-operation convergence. |
| Offline edit versus deletion / explicit resolution | PASS: Android offline edit and Windows deletion expose one real conflict. Reviewed Keep deletion, explicit counted confirmation, both-parent decision proof and132-operation convergence. No silent change discard. |
| Deleted-task resurrection investigation | PASS for exercised first download, concurrent delete/edit decision, later exchanges/restart/interruption: stable deleted IDs remain deleted. Older local restore intentionally shows older values under quarantine; reviewed resolution restores final deletions. Original unfamiliar-task cause still **unproven**. |
| Recurrence instances and event exceptions | PASS for Windows-authored daily task instances and event moved/cancelled exceptions transferred/read back with preserved IDs. Android-authored recurrence edits/new exceptions were not separately exercised; BLOCKED for that extra direction. |
| Parent/subtask and named checklists | PASS: Windows seed and Android-created full child/named checklist/item transport, relations and child deletion verified. |
| Categories/projects/event-project association | PASS: entity rows and selected assignments match, including native Android event assignment. Android creation of a new category/project itself was not separately exercised. |
| Managed attachment/resource metadata | PASS: Windows bytes/metadata read on Android; Android file-picker63-byte managed attachment matches Windows SHA and relationship at140-operation convergence. External device-local links are not claimed portable file contents. |
| App restart and persistence | PASS: packaged app restart, retained account, data/integrity; actual process termination retains immutable facts. No general crash-free claim. |
| Active interrupted exchange / retry | PASS: network-off Sync observed busy, owned app force-stopped;2 pending facts survive unchanged. After SSD recovery, real retry159 and Windows164 converge at144 with pending0. Not a lost-reply-after-server-commit test. |
| Duplicate prevention / repeat exchanges | PASS for stable IDs/counts across the completed exchanges and retry, no unexpected tasks. Dedicated final post-restore no-op cycles BLOCKED by invalid decision queue; not claimed complete. |
| Local backup/restore/quarantine | PASS: native reviewed exact backup, Before Restore verified144 facts, atomic reopen, schema/integrity/FK, disabled/quarantined Sync, fresh restored device in same workspace. No cloud snapshot test. |
| Restored reconciliation / decision upload | FAIL in packaged candidate: all histories retained and portable values correct, but7 invalid local decisions block upload. Source correction + host peer regression PASS; corrected real-service rerun BLOCKED. |
| Network background scheduling | PASS: actual registered network job after normal permission fix. Delivery under background restrictions/Doze is not established. |
| Production isolation / original cloud retention | PASS against refreshed owner-authorized18-path baseline, startup, protected3 docs and frozen20 isolation sources. All11 original cloud IDs/properties retained. No personal credential content inspected. |
| Private Sync / cloud snapshot backups / physical phone | NOT TESTED: explicitly excluded. Physical OEM/ARM64/16KiB, full platform/manual and exact-source release CI remain separate. |

**Not ready for a private beta release.** Routine cross-platform Standard Sync
has substantial real-service passes, but restored-decision recovery is incomplete
and the latest fix is not packaged. HEAD/branch remain `4dcda12` /
`feature/sync-ux-refinement`; changes are uncommitted by instruction. No push,
tag, release version change, cloud deletion, publication or production profile use.

Smallest proposed recovery, awaiting explicit approval: preserve the failed SSD
profile and its210-operation queue, make a separate SSD copy of the retained
signed-in pre-restore AVD checkpoint, then switch the task locator with one
controlled shutdown/restart. Same spare account/workspace; no cloud cleanup or
journal rewriting. This needs an exception to the owner's no-profile-reset and
single-restart boundary. No new Google sign-in is expected from that retained
checkpoint, but account/workspace must be reverified before any exchange. Do not
boot both copies simultaneously or reuse the failed fresh device's sequence IDs.
The preserved invalid decisions selected exactly the existing Windows values;
no synthetic logical edit is silently abandoned. If recovery is approved, first
verify that fact again, package only the changed Android fix as needed, resolve
the retained restoration candidates explicitly and complete final no-op/recovery
checks. Do not call the interrupted current run all-green.


Final pause236/237: stopped only Android package PID5086 after verifying account,
workspace, private database, idle state, automatic off and exactly7 pending
operations. Emulator remains running with authenticated userdata; Windows closed.
Afterward production18 paths/startup/protected3 docs still match. Available host
RAM measured1.48GiB after closing the task app and SDK attachment. Final affected
Dart formatting check passes; documentation links and `git diff --check` pass.
No checkpoint switch was performed without the pending owner answer.


## Approved checkpoint recovery (2026-11-07, 08:50 onward UTC+03)

Owner approved the explicit checkpoint-recovery question. Receipts239/240
reverify production isolation and record permission for one additional controlled
shutdown/restart, preserving both the failed profile and original checkpoint.
Guest shutdown was graceful; no forced QEMU termination. Offline failed-profile
manifest242 retains75 files and the unchanged210-operation/seven-decision state.
The recovery copy243 matches all75 original checkpoint file hashes recorded
before its first SSD use. All four qcow2 checks244 pass; no rebase/repair/wipe.
Only copied derived hardware paths and the task locator changed. The new AVD is
`C:\Users\User\AppData\Local\TodorbitPrivateTesting\AndroidSSD-Recovery-20261107\AVD\TodorbitStandardLowRam20261106.avd`.
It reuses verified emulator37.2.13 binaries; root ACL is owner/SYSTEM/Administrators.
The prior failed SSD and D: checkpoint remain unchanged and will not run together.
Read-only comparison245 confirms every archived decision value is already present
in verified Windows data; no unresolved logical edit is silently abandoned.

A necessary changed-source Android build is running with the existing helper,
SDK/JDK/CMake/cache. Windows, unrelated builds and full tests are not repeated.
Exact command is in `build-recovery-clock-android.ps1`, output in
`android-recovery-clock-build.log`; original local.properties is restored in
finally. New build/account/recovered-history qualification and real exchanges
remain pending; the earlier FAIL is retained until its corrected real rerun.


### Recovery execution and corrected replay (09:02-09:18 UTC+03)

The one necessary changed Android build passed in442.7 seconds. Its187,138,135-byte
APK is `packages\Todorbit-1.0.19-beta.12-schema27-android-restore-clock-debug.apk`,
SHA-256 `be70eb2a5f9c093e437377e9e164dfefaa9ea776736c9b7cb5e76b4d497c1095`.
Certificate/package/version35 match the registered original; all7 native-library
alignment checks pass. Fixed source marker is present in kernel_blob.bin and in
the actual loaded script254. This supersedes the earlier0-library reload as
proof of deployment. Original APKs remain unchanged; local.properties restored
byte-for-byte. Existing Kotlin/SDK XML warnings remain, not application errors.
Read-only jcmd246 showed cache/configuration work; initial shell parsing of the
thread excerpt failed, corrected without restarting/repeating the build.

Guest248 booted in55.083 seconds, PM/GMS/Play paths respond, user0 and explicit
serial/name verified. Networking disabled before app launch. Stopped only daemons
in the task-specific Gradle home after build, preserving normal user caches.
Snapshot249 failed because a cleanly closed SQLite DB has no WAL, not corruption.
The external helper now requires the DB and accepts an absent WAL only when its
absence and DB hash remain stable across copying.250 passes schema27/integrity/FK:
original Android device/sequence26,142 journal rows/two pending operations. Both
pending immutable facts exactly match Windows; no counter reuse. Install252 used
-r -t, preserving app data. First cold activity wait timed out while loading;
early readiness probe produced no receipt. Fresh255 verifies the same spare
account/workspace, automatic off and2 pending. No extra AVD restart or sign-in.

**Correction to the earlier read-only receipt:** Windows now has203 journal rows,
not144. Its private metadata probe lists only metadata, but normal startup also
starts the separately approved automatic Sync engine. Thus cross230 additionally
downloaded the59 valid restoration candidates before closing. The claim that the
entire launch performed no exchange was incorrect. Portable values stayed equal
to the144-operation checkpoint; one competing group remained retained. No data
was overwritten or cloud data erased. The pre-approval auth gate still prevented
this before Standard approval existed. A Windows wrapper holding the existing
approval gate closed was prepared outside Git but has not been executed; final
metadata checks instead use the already-running Android production provider's
read-only list method with automatic Sync off, avoiding startup ambiguity.

| Invocation / evidence | Result / necessity |
| --- | --- |
|258 native first recovered exchange;259/260 | Real Google exchange: two old operations replay safely,59 restore candidates retained,5 user decisions in1 waiting group. |
|261 /262 | Both endpoints203 journal rows;43 tables equal. Read-only comparison confirms all five current-device choices match verified Windows values. |
|263-266 native counted review/apply | Selected current-device values; explicit5-decision/2-deletion confirmation. Real upload succeeds; pending/conflicts/waiting zero. Invalid7 IDs stay in archived failed profile. |
| Windows cross268 receive / cross269 close /270 | Real convergence:262 operations on both,43 tables equal, all immutable facts retained, schema/integrity/FK pass.22 task rows/5 deleted,6 events/3 active. |
|271-286 exact fixed restore replay | Automatic off/network disabled; native Settings/local history selects same Nov6 22:43 backup (20 tasks/4 events), explicit replacement confirmation, app-only restart. |
|287-292 | Quarantine/disabled Sync verified before network restoration. Before Restore hash/integrity/FK pass,262 facts preserved. Same spare account/workspace reverified; no cloud snapshot action. |
|293-298 native reconciliation / invariant | Fresh device87ec2dd0-7ed4-46db-8333-7add57322f58, same workspace.321 rows retain all262 immutable facts plus59 restored actions. Received history covers retained original Android sequence85; restored actions still observe the old snapshot rather than acknowledging newer work. Invalid7 IDs absent from this active profile. |
|299-304 real exchange/review |59 candidates uploaded; five displayed decisions verified individually against current Windows cloud values. Competing histories retained. |
|305-307 native decision application | Explicit5 decisions/2 deletions confirmed. Real upload result still pending at this checkpoint. |

The host alias/restore and snackbar regressions, formatting/analysis, Windows
binary/native/installer and existing unrelated evidence are reused only within
their unchanged boundaries. No new source changes after the packaged clock fix.
No full suite, unchanged Windows rebuild, account switch, production profile use,
cloud cleanup, commit or release.


### Corrected real restore PASS and final recurrence check

Receipt308 confirms the previously failing decision upload now succeeds on the
fixed APK: pending/conflicts/waiting zero, Decisions synced. Windows309 receives
it; close310 and snapshot311 show both journals382, all43 portable tables equal,
all prior immutable facts retained, integrity/FK pass. No invalid-operation
rewriting, workspace replacement or cloud cleanup was used. The historical FAIL
and seven invalid decisions remain archived in the failed SSD profile.

Read-only Android provider invocation312 uses the actual compiled
GoogleDriveProvider.list on the already verified idle controller, automatic off.
It returns25 real Drive objects; all original11 IDs/names/sizes/MD5/properties and
same proof unchanged. No media download or startup engine is involved in this
specific metadata call. The unused Windows preflight wrapper is not counted as
a passing test. The earlier cross230 startup-exchange correction stands.

Native recurring-instance completion316 targets the unique unfinished Nov7
occurrence after checking its task/slot identity. An initial read-only diagnostic
assumed recurrence_series_id lived on tasks; corrected to the actual
recurrence_occurrences relationship before any tap. Stable task/slot identities
and all unrelated task values are preserved; Today changes from2/3 to3/3. One
operation383 uploads and reaches Windows320. Close321/snapshot322 show all43
tables equal,22 task rows/5 deleted and6 events/3 active, pending0. This also
exercises an ordinary Android edit after corrected restore reconciliation.

Metadata323 establishes26 objects before final no-op checks. Windows read-only
snapshot324 records the no-op baseline. Native325/manual completion327 and
Windows328/close329 pass with no pending/conflicts. Native330 starts the second
manual Android check; completion and remaining final comparisons are pending.


## Final outcome (2026-11-07, UTC+03)

**Ready for continued controlled private beta testing of Standard Sync with these
isolated candidates. Not approved for public release or publication.** No remaining
confirmed defect is unresolved in the exercised corrected Android recovery flow.
The Windows candidate now packages the same shared correction; its real exchange
passes, while its corrected GUI restore journey has not been separately repeated.
Full candidate CI and the remaining physical/platform release checklist are not
satisfied by this receipt. No new account action is required.

| Real Standard scenario | Final result and evidence |
| --- | --- |
| Same spare account and existing workspace | PASS. Android339/343 and Windows348 match approved receipt; workspace315ab404-bbd0-55d3-b0d1-10afafe13fbc and original proof remain unchanged. |
| Initial Windows records arriving on Android | PASS. Original81 facts,12 task/2 event rows and43 portable tables verified; all original144 checkpoint facts still byte-identical including prior values/visibility in342. |
| Windows to Android creation/updates | PASS. Rich fixtures, status/priority/dates/notes, category/project and event-series updates matched. |
| Android to Windows creation/updates/completion | PASS. Native task/event forms, notes, child/checklist/resource creation and later event edit matched. Some fixture/deletion setup uses compiled repository methods; not every step was native touch. |
| Task/event deletions in both directions | PASS. Stable deleted IDs retained:5 task tombstones and3 deleted event rows at final383 convergence. |
| Offline edit/delete conflict | PASS. Explicit Keep deletion decision, counted confirmation, both causal parents preserved and real convergence. |
| Recurring instances/exceptions | PASS for Windows-created instances/moved-cancelled event exceptions transferred, plus native Android instance completion after restore. Task/occurrence IDs and unrelated values unchanged326. New Android-authored recurrence rules or new event exceptions were not separately created. |
| Parent/subtasks/named checklists | PASS. Bidirectional records/relations, Android-created child/group/item and child deletion. |
| Categories/projects/event-project assignments | PASS. Rows and assignments preserved, including Android event assignment. Android creation of new category/project entities itself was not separately exercised. |
| Managed attachments | PASS. Both-direction bytes/metadata/relationships match; two independent fixture content SHA-256 checks pass336. |
| Active interrupted exchange/retry | PASS. Offline in-flight force-stop preserves two pending facts; real retry and checkpoint replay converge without duplicate tasks. Android lost-response-after-server-commit is not claimed; prior Windows-only result retains its original scope. |
| Local backup/restore/quarantine | PASS. Same20-task/4-event backup, explicit native replacement review, Before Restore262 retained, restart/quarantine and account/workspace verified before reconciliation. No cloud snapshot upload, download, restore or deletion tested. |
| Corrected restored reconciliation/decision upload | PASS on corrected Android APK. Old view remains concurrent; retained clocks repaired, decisions verified/confirmed and really uploaded. Windows309 readback reaches382 operations. Historical FAIL and invalid7 remain archived, never rewritten. |
| Normal mutation after restore | PASS. Native Android recurring completion produces383rd operation; Windows320 receives it. |
| Repeated checks/duplicates/integrity | PASS. Two native Android manual checks325/330 and two Windows requests328/332; both record new successes. All43 portable tables including timestamps, journal rows and batch bytes unchanged. Drive's26 objects unchanged across323/335. |
| Restart/pairing persistence | PASS. App-only restart337 preserves fresh device87ec2dd0-7ed4-46db-8333-7add57322f58, account/workspace, Standard mode and383 operations. Schema27/integrity/FK pass; no pending/recovery prompt. |
| Corrected Windows private candidate | PASS for build/package/config/native-runner continuity and real Sync348;383 records remain converged350. Same20 isolation sources and native executable, updated shared AOT. Separate corrected Windows GUI restore remains NOT TESTED. |
| Metadata-only preflight fence | PASS after fixing existing operational wrapper. Startup exchange gate held closed, owned app closed, original approval restored byte-for-byte. All Sync-table fingerprints unchanged353;26 metadata objects returned. Earlier cross230 startup exchange is disclosed above. |
| Production and data isolation | PASS.355 retains18 production path hashes, startup and protected3 docs.356 verifies20 isolation source hashes in both roots, updated shared inputs and artifact hashes. No personal profile/account/cloud content used. |

The final data set has22 task rows (5 deleted),6 event rows (3 active),383 journal
operations on each device, no pending mutations/conflicts/waiting groups, and no
foreign-key/integrity errors.336 proves all pre-failure portable values survive
except the explicitly intended recurring completion. No unexpected resurrection
was reproduced; the original unfamiliar-task report remains **unproven**.

### Corrected private artifacts

Both retain version1.0.19-beta.12+35/schema27; no release version change.

| Artifact | Exact local path / SHA-256 |
| --- | --- |
| Windows private portable ZIP | `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\packages\Todorbit-1.0.19-beta.12-schema27-isolated-drive-recovery-clock-win-x64.zip` / `defa015feea24edc4d0ffde7e86850b8136b212ca30807359ceea534fe313ecd` |
| Windows running bundle | `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\source\build\windows\x64\runner\Release` / main `f11e0d60641345c849b87f5a6fd047792be449e81099904f2ac912d1bb3d60f7`, AOT `e9d8ed3dae26c03631fa4d6cfd8b9907a1999c17ec5f53ca5f8c20c2e851caf8` |
| Android debug APK | `D:\AI_Projects\TodorbitPrivateBuilds\isolated-drive-20261106\packages\Todorbit-1.0.19-beta.12-schema27-android-restore-clock-debug.apk` / `be70eb2a5f9c093e437377e9e164dfefaa9ea776736c9b7cb5e76b4d497c1095` |

The Windows ZIP is15,971,826 bytes, unsigned, same28 private-package entries,
without companion, profile data or credentials. Android APK is187,138,135 bytes,
same registered debug certificate, seven-library alignment pass. Neither is a
public-release approval. Original ZIP/binaries/APKs remain; old Windows bundle is
also retained at `bundles\before-recovery-clock-win-20261107` with its original AOT.

### Final invocation/reuse closure

| Invocation / receipt | Result and scope / necessity |
| --- | --- |
|308-312 | Fixed real restore upload/readback PASS;382 operations/43 tables. Actual Android read-only metadata lists25 objects, original11 complete metadata unchanged. |
|313-326 | Wrong assumed recurrence column diagnosed before mutation; correct occurrence table checked. Native instance completion and real Windows receive PASS,383 operations/43 tables. |
|323-336 | Final no-op baseline and two manual checks/platform PASS. Journals, batches,43 tables and26 cloud objects unchanged; successful-exchange timestamps advance. Two attachment content hashes verified. |
|337-345 | Installed Android APK hash, app-only restart, fresh pairing/account persistence and144 original complete immutable facts PASS. Current-process sampled error markers zero. Actual light720x1280 screenshot341 reviewed: readable completion/events, working icons and reachable actions; not universal visual/accessibility evidence. Production18/startup/protected3 match. |
|346 Windows preservation/input staging | Original ZIP hash/bundle preserved; only sync_repository.dart, sync_restore_repository.dart and sync_status_button.dart copied from validated root.20 private-isolation inputs unchanged, same OAuth config and dependencies, parallelism2. |
| `run-step.py <346 plan> build` | Windows Release109.9s PASS, three signed Microsoft CRTs staged/verified. One needed shared-fix build, no native companion/full-suite/installer run. Logs windows-recovery-clock-build.log and existing redacted logs/build-result receipt. |
|347 packaging/config/AOT proof | Initial read-only hash comparison failed solely on uppercase receipt vs lowercase digest; normalized comparison, no rebuild.28-entry ZIP/CRC and config equality pass, specific corrected recovery SQL present in new AOT and absent in old. Native main unchanged. |
|348/349/350 | Actual new Windows private candidate real Sync PASS/pending0, normal owned close,43-table/383-operation convergence. No new sign-in. Private runtime paths/reparse checks and production baseline verified. |
|351-353 corrected existing metadata wrapper | Startup gate held closed through metadata GET and app close; approval bytes restored. All Sync tables unchanged. Earlier startup side effect corrected operationally without another app/source change. |
|354 credential-cache hygiene |839 generated text files inspected;3 command/config caches sanitized without printing OAuth values. Changes resolve physically inside private build source. Compiled artifacts/source/config remain unchanged; sanitized caches are not evidence for another build. |
|355/356 final safety/continuity | Production18/startup/protected3 match; both roots'20 isolation source hashes match; three shared files match analyzed/tested source; artifact hashes verified. |

Focused host regression failures, compilation/fixture corrections and their final
passes remain in the earlier ledger. No full suite was rerun. Unchanged crypto,
transport, ownership, native credentials/process isolation, native widgets and
installer checks are reused only for their existing source/artifact boundaries.
Windows native GUI/installer and physical Android/OEM behavior are not inferred
from repository/VM interactions or emulator screenshots.

### Preserved state and next stage

Windows candidate is closed. The one authenticated emulator remains running from
`C:\Users\User\AppData\Local\TodorbitPrivateTesting\AndroidSSD-Recovery-20261107`,
automatic Sync off. Failed SSD profile and D: checkpoint stay offline/preserved;
do not run both copies of the old device identity simultaneously. The archived
invalid7 operations are never imported or rewritten. Existing recovery copies,
Before Restore snapshots, history and all cloud test objects are retained.

At345, available host RAM is5.30GiB of15.74; QEMU working set0.81GiB is one
process measurement, not total emulator/GPU usage. No Sandbox, new Windows user,
physical phone, new OAuth account or repeated emulator restart was used. The
single additional checkpoint restart was explicitly approved. Earlier I/O stalls
are observed environmental evidence; no unsupported claim that RAM alone caused
the old Sandbox/ART/system-server failures is made.

Before wider beta/public release, complete relevant [platform acceptance](UI_UX_PLATFORM_ACCEPTANCE.md):
Windows shell/input/DPI/Narrator and updated-candidate GUI/installer journeys;
Android launcher widgets, IME/Back/TalkBack, OEM/ARM64 and16KiB runtime; normal
release packaging and exact-candidate CI. No signed/public installer was produced.
Private Sync and cloud snapshot backups remain out of scope. Private Sync needs
separate explicit authorization, a second selected disposable account/isolated
profiles, and deliberate passphrase/recovery-code handling; no mode/account switch
was performed. Branch/HEAD remain feature/sync-ux-refinement /4dcda12, all changes
uncommitted by instruction. No push/tag/publication or production consent changes.


Documentation closure357: the first report-finalization pass encountered the
Windows default-code-page reader, then the diagnostic printer could not emit an
arrow. Explicit UTF-8 readers and escaped diagnostic output corrected this.
Nineteen encoding-only historical Progress lines were restored to their exact
HEAD text; all new checkpoint insertions remain, and the entire historical body
matches HEAD. No application rebuild/test was justified by documentation alone.
Current and earlier acceptance reports now link to this final outcome.


Final closure360/361: actual Android read-only metadata remains exactly26 objects,
including unchanged original11 names/IDs/sizes/MD5/properties after the updated
Windows candidate exchange and gated preflight. Production18 path hashes, startup
and protected3 documents still match. No further Sync or user action is needed
for the exercised Standard plan. All existing artifacts and cloud history remain.


## Local repository checkpoint (2026-11-07)

The completed implementation is secured in local commits `e6a95ca` (private
Windows credential/profile and side-effect isolation) and `3e2e0e5` (recovery
identity, scheduling permission, status dismissal and restored decision clocks).
Historical build references to 4dcda12 plus dirty manifests remain accurate; these
commits preserve the verified implementation rather than describe new builds.
The accompanying documentation commit records this mapping; no version changes.

Read-only continuity receipt 362 verifies all 27 changed application/test files
against the final acceptance hashes, including all 20 private-isolation inputs.
The isolated Windows source has those 20 inputs and three shared fix files
byte-identical to the repository. All 188 runtime Dart files match after line-ending
normalization; 53 unchanged files are CRLF/LF-only differences. An initial overly
strict whole-runtime byte comparison stopped on these differences; classification
confirmed no code drift, without rewriting either tree. The Windows-only staging
tree intentionally differs in the Android manifest, three newer regression-test
files and ignored android/local.properties; the Android artifact was built from
the verified repository inputs. No missing fix was inferred from those unrelated
Windows-build inputs. Both private packages plus Windows main/AOT hashes match.

Known OAuth values/encodings and common live-credential patterns were checked
without displaying values; none occur in the explicit staging allowlists. Only
20 isolation files, 7 Sync fix/test files and the relevant documentation are staged.
Git index content is compared with verified working files after Git line-ending
normalization. No secrets, private logs, binaries, credential files or machine
configuration are included. The three preexisting storage-document hashes match
and remain outside these commits. Credentials, profiles, snapshots and test
artifacts were not modified. Detailed commit/check receipts 362/363 remain beside
the acceptance evidence, outside Git.

Existing regression, analysis, build and real-service results are reused because
implementation/dependencies/configuration/artifacts remain unchanged. This
checkpoint executes only file/hash/secret-exclusion/staged-content checks and
git diff --check. No test suite, build, emulator/application launch, Google Drive
operation, push, tag, publication, Private Sync or version change is performed.
Remaining risks are the already recorded physical/platform and corrected Windows
GUI restore coverage gaps, exact-candidate CI, and the still-unproven original
unfamiliar-task cause. Recommended next work is to close those acceptance gaps
before wider distribution; this checkpoint starts no new testing phase.
