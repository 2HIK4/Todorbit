# Private encrypted Sync acceptance (2026-11-07)

Base `87e976f`, branch `feature/sync-ux-refinement`, plus the five named dirty
Dart/test files in external receipt 002. **P0 local Windows readiness PASS;
P1 PASS: distinct account and read-only empty Sync namespace verified. Real encrypted exchange NOT TESTED.**

External evidence/root:
`D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107`.
[Preparation and resumption gates](PRIVATE_SYNC_ACCEPTANCE_PLAN_2026_11_07.md).

## Changes and focused verification

- `private_test_environment.dart`: separate `PRIVATE-SYNC-APPROVED.json`, pinned
  account/mode/workspace, no Standard-file fallback. Original Standard approval
  format preserved. Controller setup, runtime exchange and operational probe pass
  actual/expected mode and workspace. Normal builds retain their existing path.
- Four implementation files and `test/private_drive_test.dart` changed. No
  encryption, protocol, database, native credential, OAuth, UI layout or Android
  implementation change. The gate is acceptance-build-only, not a new product
  security boundary against a local user who can edit its files.
- UI/UX Fix scope: existing Windows auth-only Backups & Cloud route and account
  verification/recovery journey. No new controls, redundant account prompts or
  passphrase handling. Correctness: gate fails closed; experience: keep existing
  consent/account picker, defer private setup until identity/preflight. Rendered
  consent, physical input/accessibility and Private recovery UI remain untested.

| Invocation / evidence | Result, scope and reason |
| --- | --- |
| Read-only Git/source/receipt inspection | Checkpoint and three protected documents preserved; existing assets located. No broad source scan. |
| `dart format` / `dart analyze` on four changed implementation files and private test | PASS. Exact paths/argv/hashes in `evidence/002-local-checks.json`. Necessary changed guard/caller coverage. |
| Flutter test, `--no-pub --concurrency=1 --dart-define=TODORBIT_PRIVATE_DRIVE_TEST=true test/private_drive_test.dart` | PASS 6, fresh synthetic child environment. Wrong account/workspace/mode, missing/malformed/unapproved file, no Standard fallback, plus selected-store behavior. No Google requests. |
| Existing redacting `run-step.py ... build`, `build-windows-release.ps1 -PrivateDriveTest` | PASS, one affected Windows build. Same external OAuth config; no secret values exposed. Receipt 005; ZIP/main/AOT hashes below. Original staged source and Standard bundle restored byte-for-byte. No Android build. |
| Actual new Windows launch / `--private-store-probe` | PASS receipt 006: child-reported APPDATA/LOCALAPPDATA/executable/database/credential paths, native encrypted-store round trip/cleanup, empty schema27, integrity/FK, unbound capture, automatic off, both approval files absent. Only auth-ready marker enabled afterward. |
| Production/Standard preservation | Receipts 001/006/007: 18 production file hashes, startup values, Android Standard DB/WAL unchanged. Recovery copies/artifacts/Standard credentials not altered. |
| Android read-only user capability / `pm create-user`, `install-existing --user 10` | PASS user10, distinct UID1010209, same existing APK. User0 retained. New user not started or authenticated; private runtime path and Play authorization still require observation. No emulator restart/new AVD. |
| Diagnostics corrected | First historical log reader expected UTF-8 but file was UTF-16; no sensitive content emitted. First nested ADB shell hash command returned empty output; assertion stopped before mutation. Direct `run-as sha256sum` captured valid baseline. Two guessed engine-part paths were absent; actual source retained. No application failure inferred. |
| Documentation link/diff/source check | Required lightweight closure; no additional application tests. |

Current production baseline remains the owner-approved quiescent baseline from
Standard acceptance. ACL on new root removes inherited grants and allows only
current user/SYSTEM/Administrators. Credentials/passphrases are never printed.
Release candidate uses the new AOT; no unrelated debug/Standard app was hot-reloaded.
The retained emulator remains idle in user0; no extra guest user was started during
the Windows build. One memory sample before build was about 3.56 GiB available;
no Windows/Android acceptance interaction ran concurrently.

## Evidence reused rather than repeated

[Standard final receipt](CROSS_PLATFORM_STANDARD_SYNC_2026_11_06.md#final-outcome-2026-11-07-utc03)
establishes shared CRUD, recurrence, conflicts, tombstones, relationships,
attachments, data integrity, restart and restored clocks within its recorded
scope. Do not run that matrix again for Private.

Receipt 008 references existing `integration-1.log` lines 422/423/590/592/623:
encrypted codec/authentication boundaries, key retention after ambiguous upload,
lost-key recovery, and passphrase/code recovery with wrong-credential nonpersistence.
The old workspace-format hash differs only by an explanatory comment; pairing
since 574cd0d differs only by mechanical braces. The passphrase test itself matches
its historical hash. These deterministic passes are reused, not real cloud proof.
Native DPAPI/concurrency/failure/cleanup and packaging evidence remain applicable
because native source/config is unchanged; fresh root/runtime identity has its
own observed check. Full suites, native self-tests and Android rebuild skipped.

## Minimal remaining Private-only execution

1. User connects the SECOND unused disposable account in the new Windows candidate.
   Record receipt ID, compare against Standard, obtain owner confirmation if ID
   cannot independently identify the intended account. Read-only complete Sync
   namespace preflight with startup exchange blocked; stop for unexpected data.
2. Only after identity/empty namespace and approved scope, derive the initial
   workspace ID with the existing account-bound workspaceFor function. Issue a
   Private approval pinned to that account/mode/planned workspace, then create it
   through the existing flow. User chooses passphrase and saves recovery code
   privately. Verify returned proof/workspace identity. No approval file exists
   now. No conversion or Start New Sync.
3. Start Android user10 and verify actual UID/native data root, empty independent
   DB and secure store, Play services and second-account identity. User signs in
   there once. Join using passphrase. Test one incorrect credential before correct
   recovery; verify no saved key/upload on failure. Use a separate clean recovery
   context for the code, not a copied unlocked key.
4. One encrypted representative round-trip: project/category, parent/child,
   named checklist, event-project relation and tiny managed attachment; edit one
   field on Android and read back on Windows. Compare stable IDs, relationships,
   attachment bytes, table/integrity/FK results. Inspect decoded remote encrypted
   envelopes for fixture text/attachment leakage and verify authenticated decode;
   document public metadata rather than claim all metadata hidden.
5. One restart/key-retention and repeated-check boundary. Add encrypted retry or
   local restore/quarantine/re-unlock/reconciliation only where existing encrypted
   deterministic/Standard evidence leaves a distinct risk (for example retained
   encrypted outbox bytes and retained/missing keys). Do not repeat generic CRUD,
   recurrence, delete/conflict matrices. Local snapshots are not automatically
   encrypted by Private Sync. Cloud snapshot backup remains separate/unexecuted.

## Candidate and interruption checkpoint

Windows ZIP: `D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107\packages\Todorbit-1.0.19-beta.12-schema27-private-approval-win-x64.zip`

SHA-256: `5c3ff766eee8287ce58bbd38b73d4fbe894129e8175bce6b3571f529915f61ef`

Bundle: `D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107\bundles\Windows`

Main SHA-256: `6fff86fb6cb048fe721d9aedc49dab1d95798fd2ef16c20e686554f64d928e49`

AOT SHA-256: `a628fe50ead2f60732804c94ed5d4a8b717e1b6417ec6daac6a6cdef09405a02`

Running owned Windows PID7488, persistent root `D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107\Runtime`.
Launcher `Start-PrivateEncrypted.ps1` in the external root refuses either Sync
approval for auth-only launches and verifies artifact/production hashes. Do not
reuse it to exchange; prepare an explicit account/workspace-bound phase after P1.
Android serial emulator-5582; Standard user0 and dormant Private user10.

**Next action:** in the new Windows candidate, Backups & Cloud, click Connect
Google Drive, choose the second unused disposable account (not Standard or a
personal account), and complete consent. Then report connected. Do not set up
Sync, enter a passphrase or send secrets yet. Both approval files remain absent.
No Private cloud exchange, account ID, workspace or ciphertext result is claimed.

On resume read receipts002/005/006/007/008, verify owned process/profile/account
identities, then continue P1 without rebuilding, repeating tests or signing in
again unnecessarily. No commit/push/tag/publication/version change this session.

## P1 identity stop (2026-11-07, 10:58 UTC+03)

The new receipt observed at07:57:34Z has a nonempty Google Drive permissionId
identical to the preserved Standard receipt. Owner reported a second disposable
account, but the actual receipt does not establish separation. Stopped before
any Google request, cloud listing, approval creation or workspace setup. This is
an account-selection mismatch, not evidence of a Private Sync protocol defect.

External receipt `evidence/010-P1-identity-block.json` records comparisons without
printing account identifiers. Both Sync approvals remain absent;18 production
paths and three protected documents still match. Running owned PID7488/profile
unchanged. No builds/tests/setup repeated, no Android user switch or cloud writes.

Next user action: in the NEW private Windows candidate only, Backups & Cloud,
Disconnect, then Connect Google Drive and choose a DIFFERENT unused disposable
account (Use another account if needed). Source review confirms Windows Disconnect
only deletes this selected local credential store; it does not revoke Google's
shared grant or delete cloud content. Standard's separate token file/profile is
untouched. Do not disconnect Standard or revoke app access in Google settings.

After reconnection require a newer account receipt and distinct stable account ID
before read-only preflight. Leave Private setup/passphrase/recovery steps pending;
do not use the earlier Next action to proceed to workspace creation. No preflight
PASS or empty-cloud claim is made. No credential contents were read or logged.

### P1 reconnection still matches (2026-11-07)

Receipt now advances to08:00:26Z, confirming a new connection completed in the
same owned PID7488/private executable, but its Google permissionId still matches
Standard. This is not a stale receipt or the wrong running executable. Receipt011
records the blocked retry without exposing IDs. No Google request/approval or
workspace creation followed. Ask whether a genuinely different underlying Google
account was selected rather than repeat OAuth blindly. Alias addresses do not
establish a different account; actual OAuth identity remains the gate.

## P1 resolved and Windows account-switch fix (2026-11-07)

Owner clarified earlier attempts used the same disposable email, then disconnected
and connected a new Google account. Receipt observed08:04:11Z is distinct from
Standard. Its actual authenticated read-only preflight returned0 Sync objects
(receipts012/013). All Sync-table fingerprints remain identical; integrity/FK
checks pass. This establishes the Todorbit Sync namespace only, not an inventory
of the entire Drive account. No workspace/cloud write occurred during preflight.
The earlier identity failures remain recorded, not relabeled as passing exchanges.

Confirmed UX cause: Reconnect intentionally pins the current account and rejects
a different identity without replacing its credentials. Windows hid the existing
Android Switch Google account action, leaving repeated reconnect attempts unclear.
Fix: expose that same confirmed switch action on Windows and label reconnect
Reconnect current account. No OAuth/token policy or account-binding guard changed.
Explicit switch first disconnects only the chosen local store, clears old backup
history, asks Google for another account and displays its new label.

- Targeted analysis/format: two changed files, PASS.
- New desktop switch UI regression: cancelling confirmation preserves account and
  makes no connect/disconnect call; confirming disconnects before connect and
  displays the new label with old label removed, PASS.
- Existing auth account-switch rejection/stale-object test: PASS, reused after
  the UI fixture correction. No broad suite or Standard matrix repeated.
- Initial UI assertion failed because the shell converted a Unicode separator
  in test source to a question mark. Test now asserts the actual account labels
  independently of that separator; only the failed UI case reran and passed.
  Initial result printer also hit its Windows code page; escaped output preserved
  diagnostic evidence. Receipts014/016 retain both failures and passing follow-up.
- Only the affected Windows candidate is rebuilt (receipt015); Android already
  exposes switch, so its APK remains valid for Private interoperability. Its newer
  reconnect wording is source-only until a later necessary Android build.

Next gate after loading the fixed candidate: prepare local Private approval pinned
to the verified second account and account-derived initial workspace UUID. This
permits only that mode/workspace; there is no Standard approval or automatic new
pairing. User must choose/confirm a passphrase and privately save the generated
recovery code in Sync > Encryption options > Set up Private Encrypted Sync.
No passphrase/code is requested in chat, logs or screenshots.

### Current user boundary: P2 private setup ready

New fixed Windows candidate built in103.4s and launched as owned PID15524 from
`bundles/Windows-account-switch` under the same external root. Account connection
survives without another sign-in; actual child database/credential/profile paths
remain the verified Runtime paths. Original Standard bundle/staged source and
previous private artifacts are preserved byte-identical. Production18 and three
protected docs still match. Native/OAuth/Android binaries were not rebuilt.

New portable ZIP: `D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107\packages\Todorbit-1.0.19-beta.12-schema27-private-account-switch-win-x64.zip`

SHA-256: `78e4a38145a32bc2f60a1104b0410849ef299825dac3dc44823156e78e8c6d1b`

Main SHA-256: `7c1571d553a6342d617332429202c02f7a53f827b11961b94fc76d7fa5b8c683`

AOT SHA-256: `3ce44a452815386f9a6620188aab59832f0b03771ca1bc8dd05fdb3484b357ca`

Receipt017 pins a LOCAL `PRIVATE-SYNC-APPROVED.json` to the second account,
private mode and its expected initial workspace UUID, derived by the unchanged
account-bound algorithm. This is setup permission, not proof of a created cloud
workspace. No Standard approval exists; no cloud writes/exchanges or workspace
creation have occurred. SQLite capture is still unbound/empty, automatic off.
The earlier statements about both approvals absent describe the P1 preflight.

**Next user action:** close Backups & Cloud, open Settings > Sync > Encryption
options > Set up Private Encrypted Sync. Choose and confirm a test passphrase,
save the displayed recovery code privately outside chat/Git/logs, acknowledge it,
and select Connect with encryption. Then report completion. Do not choose ordinary
Standard Connect or Start New Sync. No secret screenshots or values requested.
This is the next unavoidable secret-handling interaction; Android remains dormant
in its prepared separate user10, with Standard user0 untouched.

After user setup, verify the actual private proof/mode/workspace and ciphertext
before the narrow cross-platform Private plan. Reuse prior full Standard matrices.
The launcher supports explicit `-PrivateSetup` only with matching pinned approval;
normal auth-only/preflight launches still refuse either approval. Do not rerun
build015 or tests014 merely to resume. Source/diff/links and production preservation
checks close this checkpoint; no commit/push/tag/version/publication change.

## Recovery-code copy control and fresh setup (2026-11-07)

User requested a copy icon next to the recovery code. Added a keyboard/semantics-
labelled IconButton beside the selectable code, with Copy recovery code tooltip
and success feedback after Clipboard.setData. The code remains selectable; row
wrap/spacing uses existing dialog constraints. Privacy lock prevents copy and
existing dialog closure is retained. No encryption or credential format changed.

User posted test credential material in chat. Automation never reused or stored
those values, requested no secret capture and made no cloud requests during this
change. Local capture was still unpaired/automatic off. The scoped approval was
held unchanged while the user cancelled the unsaved dialog, then restored
byte-for-byte after the updated app loaded. A fresh setup generates a NEW code;
posted code must not be reused. No paired workspace was reset or deleted.

| Check / receipt | Result / scope |
| --- | --- |
| Format/targeted analysis, two changed Dart/test files | PASS; receipt020 exact argv/hashes. |
| Existing private encryption setup light/dark large-text cases, extended clipboard assertions; privacy closure case | PASS3, using generated synthetic keys with mocked clipboard. Exact displayed code copied, icon discoverable; no real key logged. No full widget suite or protocol/Standard rerun. |
| Affected Windows build/package, receipt021 | PASS. Standard staged source/bundle and previous private packages preserved/restored. Android APK unchanged; no native source change. |
| Owner cancellation and updated launch, receipt023 | PASS. Owned PID32004, same verified account, actual isolated database/credential paths, capture unpaired/automatic off. Original setup approval restored only for fresh setup. Production18/protected3 match; no production operation/cloud call. |

Latest bundle: `D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107\bundles\Windows-recovery-copy`

Latest ZIP: `D:\AI_Projects\TodorbitPrivateBuilds\private-encrypted-20261107\packages\Todorbit-1.0.19-beta.12-schema27-private-recovery-copy-win-x64.zip`

SHA-256: `3b1d30e1c9cb3c545e0cde3b6339882463b956983c4297e33b87379e0608246e`

Main/AOT SHA-256: `a103a346b2bf7f3af8b894388b0b1f68b36080d46639ca70636d8369faf2f3e5` /
`7ed7185c724d2fd7868b12b08a012ba0b6b77e8e54818b8a4c4ec79f90ff438b`.

Existing launcher selects this exact build. On resume use receipts020/021/023;
do not repeat builds/tests or sign-in. Android user10 remains dormant, Standard
user0 and original account/workspace untouched. Clipboard/large-text evidence is
widget-level, not a new physical accessibility claim. Native DPAPI/crypto evidence
is reused; Release cold launch applies the updated code without hot-reloading the
unrelated Standard/debug app.

**Next:** open a fresh Private setup; enter a fresh passphrase directly in app,
use the new icon to save the NEW recovery code privately, acknowledge and Connect
with encryption. Never send secrets in chat or screenshots. Report completion
only. No release/version/commit/push/tag/publication change.

## P2 activation failure diagnosed: test-approval namespace (2026-11-07)

User reported generic Sync did not finish. Local capture remained unpaired,
automatic off, no batches/last success/error code. Approval account matched but
workspace did not match the PRODUCT-derived UUID. Operator had used Python's
NAMESPACE_DNS (6ba7b810); actual workspaceFor uses6ba7b811 (URL). Earlier checks
repeated the same incorrect Python shortcut and therefore did not independently
verify the product-derived ID. This was a test-harness configuration error, not
a confirmed crypto/application defect. The application correctly blocked setup.

A small offline Windows Dart AOT executable imported actual workspace-format code
and used generated synthetic keys/password. It proved private proof create,
verification and passphrase unlock PASS, and independently reported the approval
UUID comparison FALSE. Compile/run logs025 retained; no Google/token-store call
or real credential use. No whole application build or full suite rerun.

Only local approval metadata was corrected with the exact product namespace.
Original approval bytes and historical scope017 remain archived; corrected scope
is026. Launcher validates that scope. A workspace-only Dart follow-up027 reports
TRUE; unchanged crypto work was NOT rerun. Receipt028 records boundary/state,
without credential contents. No application source/database/cloud object reset.

**Next user action:** reopen Settings > Sync > Encryption options > Set up Private
Encrypted Sync. Enter the passphrase only inside app, save the NEW recovery code
privately, acknowledge and Connect with encryption. Previous failed dialog was
closed without saving its key; its displayed code must not be reused for the new
attempt. No app restart/rebuild/sign-in is needed for this corrected local gate.
Do not use ordinary Standard Sync/Start New Sync or send credentials in chat.
Private real cloud proof/ciphertext/cross-device acceptance remains unverified.

## Real Windows Private PASS; Android authorization boundary (2026-11-07)

Corrected approval allowed actual private setup: pinned second account/workspace,
capture enabled, real successful exchange, no failure/error, SQLite integrity/FK
PASS (receipt029). Same isolated profile/DPAPI store; no production account use.

| Additional Private risk / actual action | Result and evidence |
| --- | --- |
| Real private proof and initial encrypted preference batch | PASS031. Live Google account matches; authenticated proof/mode/protocol2 verified with memory-only retained key; batch decrypted/authenticated, remote/local bytes and9 operation IDs match. Four metadata/two media GETs, no mutating HTTP allowed in readback. |
| Key retained across ordinary Windows close/relaunch | PASS within fixture upload. Saved key loaded and real encryption/exchange works without another password or sign-in. No independent full restart matrix repeated. |
| One representative rich Windows fixture | PASS033 creation and actual Private upload. Category/project, parent/child link, named checklist/item, event-project and small managed file. Synthetic canary only; local Before-fixture backup retained. No CRUD/recurrence/deletion/conflict matrix repeated. |
| Real fixture ciphertext confidentiality/bytes | PASS035 closure. Canary absent from remote ciphertext and present after authenticated decrypt; exact managed bytes SHA, ciphertext/local batch bytes and operation IDs verified. Prior proof/batch unchanged metadata checks reused; only new batch downloaded. |
| Initial fixture verifier failure | Harness expected SQL `$blob` shape, while canonical Sync uses `$bytes`. Authenticated readback had succeeded but final attachment assertion failed. Original failure retained; diagnosis and final byte check used already downloaded ciphertext OFFLINE, without any repeated Google GET/upload. No application defect inferred. |
| Android independent boundary | PASS native launch, UID1010209, `/data/user/10/io.github.hik4.todorbit/files`, empty schema27 DB, unbound capture/automatic off and integrity/FK. Same registered APK installed-existing; no new Android build/AVD/emulator restart. |
| Standard/production preservation | PASS050: Standard user0 SQLite/WAL hashes unchanged;18 production paths and3 protected docs match. Windows original bundles/source/credentials remain; no Standard cloud object accessed. |

Readback reused the existing native DPAPI bridge pattern, rebuilt as a tiny external
READ-ONLY helper fixed to this private root and two allowed purposes. It uses the
unchanged production credential-store header/locking and zeroes native buffers.
Tokens/workspace key remain in memory only, never exported to plaintext files,
arguments or receipts. Headless transport refuses non-GET, sign-in and deletion;
refresh refused if token expires. Raw retained cloud artifacts are encrypted
proof/batches, not decrypted credentials. Scopes/account IDs remain private receipts.

Windows candidate is closed. Correct local approval restored byte-for-byte after
each fenced readback. Pending0; final counts are in receipt051. Prior tokens,
code/passphrase host tests, protocol/merge/native/Standard matrices are reused;
this is real Private Windows evidence, not yet Windows/Android acceptance.

Android user10 is now at native Google sign-in (MinuteMaidActivity), opened via
Backups > Connect Google Drive, an auth-only route. No Android account verified,
paired workspace or exchange yet. Do not take credential-screen screenshots,
dump password fields, enter credentials or switch back to Standard user0.
The primary Standard Todorbit process was stopped only in user0, data preserved.

Environmental boundary: new secondary-user app cold launch took time before its
VM/rendered empty Today appeared. AOD initially hid the activity: system diagnostics
showed Asleep then nonsecure/unlocked keyguard, no sampled app fatal marker.
Waking/dismissing the NONSECURE keyguard and allowing rendering produced working
native navigation. Only user10 screen timeout was extended for acceptance; old
value retained in041. No password bypass, service disabling, wipe or reboot.
No screenshot/tree captured after Google authorization UI opened.

**Next user action:** complete emulator Google sign-in and Drive consent using
the same SECOND disposable account as Windows Private (not Standard). Return to
Todorbit Backups showing connected; tell me when done. Do NOT create/pair/enable
Sync yet. Next verify exact account ID and existing Private workspace/protocol,
then let user enter the private passphrase in-app for pairing. Recovery-code and
wrong-credential/reconciliation cases remain limited to genuine Private gaps.
All detailed actions/logs033-051 retained outside Git; no commit/push/publication.

## Android account/private preflight PASS; unlock required (2026-11-07)

Receipt053: actual user10 SyncController account ID equals Windows Private,
needsReconnect false, no binding/automatic/enabled/pending data. No emulator
restart, new APK, sign-in repeat or cloud exchange. Keyboard visibility was
changed only for user10 (receipt052); user completed sign-in.

Receipt054: one actual Android provider read-only listing returns3 records.
Workspace/protocol metadata and all IDs/sizes/MD5 values match the already
verified Windows private proof and two encrypted batches. No repeated media
fetch or foreign account/workspace access. Proof crypto evidence031 reused.

Supported Set up sync discovery reads the existing private proof and presents
its passphrase/recovery flow. Receipt057 confirms needsRecovery true and
passwordAvailable true, still unpaired/automatic off/pending0. No new workspace
or Android exchange/records created. Fields alone were inspected through VM;
no credential values or screenshots. Account labels in navigation receipts redacted.

Diagnostics: startup service log marker had rotated, so reused the previously
observed connection only after confirming same private PID19415. Initial provider
inspector looked for nonexistent controller.storage; it stopped before API call.
Correct pairing.storage and actual SDK Future flags then completed the listing.
These are harness corrections, not application failures; no tests/builds repeated.

Production18 and protected3 still match. Receipt058 is the resume checkpoint.
**Next user action:** in Android Sync, enter the SAME Windows Private passphrase
in Encryption passphrase, then tap **Authorize this device**. This unlocks/pairs
the existing verified Private workspace and permits its first exchange. Do not
choose Private NEW setup, Start New Sync or another account. Do not send the
passphrase/recovery code/screenshots. Report only completion or safe error text.
Afterward verify received fixture IDs/relations/attachment bytes and one Android
edit returned to Windows. Code-based recovery/incorrect-credential/restore gaps
remain pending; reuse Standard matrices. Windows closed; emulator stays signed in.

## Scoped Private acceptance outcome (2026-11-07)

**Real Windows/Android Private round trip PASS within this narrow scope. Not a
release approval or a claim of every recovery/platform workflow passing.** Source
remains87e976f plus the previously recorded guard/account-switch/copy UI changes.
No product code, dependencies, binaries or version changed during this stage.

| Additional Private guarantee | Evidence / result |
| --- | --- |
| Correct passphrase cross-device pairing | REAL PASS059/060. Android user10 matches exact account/workspace in private mode, with a distinct device ID. First receive preserves all Windows fixture stable IDs and relationships. |
| Windows fixture arrives with managed bytes | REAL PASS060. All43 portable tables equal, two tasks/one event/one managed resource, correct category/project/event relation, parent/child/checklist groups/items and exact attachment SHA. |
| Android to Windows encrypted return | REAL PASS073. Native Android completes the synthetic parent; Windows receives completion. All43 portable tables and immutable facts equal,28 operations and4 encrypted batch hashes each; pending0/conflicts0/waiting0 and integrity/FK pass. Original notes retained. |
| Retained keys after app restart | REAL PASS Windows fixture launch and Android068. No additional passphrase/sign-in. Same private account/workspace, enabled/private mode and pending0. App restart only, no emulator reboot. |
| Recovery-code path and bad credentials | OFFLINE PASS074 using actual downloaded private proof with fresh empty memory vaults. Correct code authenticates, valid wrong code and wrong passphrase reject without saving. Code source is approved private protected store in memory; NOT validation of user's external saved copy or another real Google pairing. |
| Local backup/key separation | OFFLINE actual-artifact PASS074. Real private local SQLite backup contains neither raw key nor recovery string. Recovered key authenticates its retained encrypted history. No live key deletion, actual GUI restore/reconciliation or cloud snapshot action. |
| Existing protocol/retry/restore evidence | REUSED Standard real causal/restore/interruption assertions and unchanged deterministic private codec/pairing/outbox behavior. No full CRUD/recurrence/deletion/conflict matrix or full test suite repeated. |
| Production/Standard isolation | PASS075.18 production hashes, startup, three protected docs and Standard Android user0 DB/WAL unchanged. Tested/built source matches manifests. Authenticated profiles, key stores, recovery copies and cloud history preserved. |

### Verification failures and scope corrections

Native text-fixture automation failed to persist its intended note; verification
caught unchanged data. It did NOT establish a data-loss/application defect. The
script also initially excluded the task card's actual Button semantics, then an
exact native text assertion was not met. No typed draft was treated as a passing
exchange. Draft belonged only to this synthetic fixture and was discarded.
Used one completion toggle instead, appropriate for the encryption-focused return
path. Its first UI-header assertion preceded frame settling; later native header
and persisted SQLite confirmed one completion, without toggling again. Notes
remain exactly the original fixture text. Receipts063-072 preserve attempts.

An initial snapshot/check failed before its planned stop; its shell then started
Windows anyway. The brief overlap is disclosed; both isolated accounts/workspace
remained correct. Android was stopped and verified before the final Windows pull.
Both profiles remain intact. Later conditional shell guard prevents continuation
on failed snapshot checks. No protocol repair, data rollback or repeated full
matrix was justified by these harness issues.

Android native launch returned a wait timeout and a first VM inspection saw a
null startup snapshot. Existing process was retained; bounded field wait then
confirmed retained private pairing, no sign-in/key prompt and no app error claim.
No AVD wipe/restart or unhealthy-environment retry loop was used.

### Remaining limits and preserved checkpoint

- User-saved recovery-code copy has not been entered into an actual second
  platform UI. Actual key-loss GUI recovery and full Private GUI backup restore/
  reconciliation have NOT been executed. Offline real-proof/key/history checks
  cover their specific cryptographic boundary; Standard evidence covers unchanged
  causal restore behavior. Do not describe this as a complete real recovery pass.
- No new active encrypted lost-response/force-kill experiment; immutable encrypted
  bytes match across devices, retained-key restarts pass, prior scoped interrupted
  transport/deterministic evidence reused. Cloud snapshot backups remain out of scope.
- Physical/OEM/ARM64/16KiB, assistive tech, current packaging/installer and exact-
  source CI remain release gates. No new universal UI/performance/security claim.
- Original unfamiliar-task cause remains unproven; no Private delete/resurrection
  matrix repeated. Representative fixture has no duplicate/missing records.

Receipt075 is the final compact resume/checkpoint file. Both task-owned Todorbit
apps are closed to conserve RAM; retained emulator remains running in user10 with
account/profile/keys preserved. Standard user0 remains unchanged/offline. Do not
rerun successful setup, sign-in, builds or matrices merely to resume.

Next recommended work: secure scoped verified source/docs in a separate local
checkpoint task, or explicitly scope a live key-loss/GUI-restore follow-up if
that evidence is required. No additional secret/sign-in interaction is needed
for this completed narrow round-trip checkpoint. No commit/push/tag/publication
or version change was performed.

## Live recovery and GUI restore follow-up completed (2026-11-07)

The earlier scoped outcome remains historical. Its actual key-loss/recovery-code
and GUI restore gaps are now closed in an independent Windows recovery context:
user-saved code entered locally, live encrypted exchange, real wrong-code read-only
rejection, GUI replacement/Before Restore/quarantine/reconciliation, reviewed
conflict decision upload and clock checks all pass. Final Release automatic local
restore restart also passes after the owner's requested improvement. Original
working profiles, independent key copies and cloud history are preserved.
See [stabilization evidence and final candidate limits](FINAL_STABILIZATION_2026_11_07.md).
No repeated Standard/Private matrix, new workspace or cloud snapshot testing.
