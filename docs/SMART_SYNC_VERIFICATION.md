# Smart Sync comprehensive verification

## Scope and identities

Started 2026-11-03 on local branch `maintenance/smart-sync-verification`, clean
baseline `4987a46`. Published beta 8/tag application source:
`dd36189c74548b14ed49fea8b12344ba4d0966fe`, version `1.0.19-beta.8+31`, schema
26, sync protocol 1. Later baseline commits change only the capture harness and
documentation. No push, merge or new publication is authorized for this task.

The owner confirmed no disposable Google account/workspace is available. All
provider checks here therefore use synthetic local contracts. No real OAuth or
Drive API acceptance will be claimed. Personal profiles, Credential Manager
entries, databases and Drive accounts must not be accessed.

## Evidence reused

- [Beta 8 publication receipt](SMART_SYNC_BETA_8_PUBLICATION.md): exact-source
  Windows CI full analysis, 628 tests/one opt-in skip, native/background gates,
  Release/installer/portable, plus Android CI and both emulator integrations.
- Production-signed APK/native alignment and actual 16 KiB x64 code-30 to code-31
  upgrade with retained synthetic data, completion/restart and no crash/ANR.
- All 11 public assets were fully downloaded anonymously and matched original
  build SHA-256; production updater accepts beta and excludes Stable. Original
  package bytes are retained under `.buildlog/verify/smart-sync-beta8/packages/`.
- [Smart Sync implementation ledger](SMART_SYNC_REDESIGN.md): focused
  encryption/recovery, two-device orchestration, scheduling and UI assertions.
  Coverage overlaps the complete CI suite; counts are not additive.

These remain valid for unchanged source/assertions. New host measurements,
missing edge cases and actual runtime surfaces are the current focus. New fixes
are not included in the published beta; affected evidence will be rerun.

## Invocation ledger

Detailed machine evidence: ignored `.buildlog/verify/smart-sync-verification/`.
Record failures and rerun reasons here; do not count planned checks as passes.

| Invocation / scope | Result and identity / new or reuse |
| --- | --- |
| Status, source/tag receipts, guidance and focused sync inventory | Clean baseline; focused branch created; prior exact-source CI/full-suite pass reused |
| Host resource/process/counter snapshot | Windows 11, approximately 5.4 GiB free RAM, C 154 GiB and D 173 GiB free. D queue 7/high busy time in one sample; no Gradle/MSBuild/emulator running. Existing owner widget and IDE Dart tooling preserved. Defender active; no causal antivirus claim |
| SDK startup baseline | Direct Dart version 0.181s; Flutter version 10.179s. Flutter 3.47.7/Dart 3.13.5, pinned original SDK unchanged |
| Three 4 KiB synchronous flushes per volume | C 0.02167/0.00324/0.00531s; D 40.86036/0.51189/0.72078s under measured host load. C maps to NVMe, D to USB StoreJet; historical D flush delay reproduced. Do not attribute this to project size or Defender without additional evidence |
| Repository size inventory | Two Python metadata scans stopped after verified owned PIDs spent minutes within generated `.buildlog`; no complete-size claim. Switched to native read-only `robocopy /L /E /XJ /BYTES` inventory; nothing deleted |
| Isolated C Git worktree / offline pub get | First plugin generation failed symlink prerequisite after dependency resolution; existing junction helper + repeat offline pub get passed, four links, no system settings or dependencies changed |
| Dart MCP targeted analyzer | Initial invocation lacked roots; corrected root registration. Analysis then timed out at 300s; no analysis pass. IDE DTD discovered, not attached to an owner app |
| Production adapter contract run 01 | Two bidirectional CRUD cases PASS, interrupted-upload/retry FAIL; 195.47s wall time, approximately 19s actual tests, rest startup/compilation. Real files and real provider/encryption/controller; HTTP/auth identity synthetic |
| Focused interrupted-upload diagnostic | FAIL reproduced: both devices `needsAttention`, same batch with one missing-marker object and one verified retry. No task reset or missing local history; original receiver had not applied it |
| First receipt-handling correction / contract rerun | Three PASS/two FAIL: proof restart corrected, operation lookup still enforced the marker before authenticated retain. Added the same correction at that first boundary; no assertions weakened |
| Contract fixed run 02 | Five PASS: bidirectional CRUD, retry/restart, lost initial proof, tamper rejection. Extended next for preferences/bulk decisions |
| Contract extended run 03 / focused bulk diagnostic | Five PASS/two FAIL; raw transport exceptions classified `error`, so offline resolution refused. Diagnostic confirms refresh-review message, no local decision accepted |
| Contract fixed run 04 | Seven PASS after classifying `SocketException`/HTTP `ClientException` as offline: both-direction CRUD/preferences, durable retries, proof recovery/wrong-code rejection, well-formed ciphertext GCM tamper rejection, bulk decisions offline/restart both directions and new divergence |
| Full C-root direct analysis | 33.49s, only one braces info in added test; no production diagnostics. Repeat targeted check ran before the delayed source copy landed, so same info remained. Semantic source frozen for full suite; brace-only cleanup follows it |
| Full C Flutter analysis wrapper | Stopped verified owned Flutter tool PID after 140.29s, no output/diagnostics; direct four-root analysis is separate evidence |
| Source formatting | 313 files checked, zero changes; full serial current-source suite subsequently passed as recorded below |
| Published portable runtime | Original initial readiness probe read schema 0 before async creation committed; no reset or product failure. Corrected readiness predicate/polled same process. Schema 26, 52 tables, read-only quick_check OK; child APPDATA/LOCALAPPDATA and location-keyed profile recorded |
| Sandbox preparation + three inert-package regressions | PASS prerelease filenames, numeric Inno registration identity, stable compatibility and bad-hash rejection. Existing published installer registers numeric core `1.0.19`, executable reports beta 8+31 |
| Published packages in actual Windows Sandbox | PASS both package hashes, fresh per-user installation/registration, installed and portable with-spaces create/reopen separate schema-26/52-table profiles/integrity, native self-test, populated in-place setup preserves DB bytes/sentinel, uninstall preserves DB/reinstall. GUI/OAuth not verified. Host result retained; owned Sandbox session closed afterward |
| Windows UI tooling | Node kernel initialization failed `failed to write kernel assets ... path specified`; reset/retry and alternate CUA entry fail identically. No Windows UI-input/visual pass claimed |
| Native size inventories (`robocopy /L`) | `.buildlog`: 63,114,118,969 bytes, 42,831 files/21,616 dirs, 269s. Rest excluding `.buildlog`: 27,184,520,112 bytes, 18,315 files/7,353 dirs, 7s. About 90.3 GB total, link traversal excluded. Exit 1 means files would copy in list-only mode; no files copied/deleted |

## Confirmed beta 8 issue: offline review blocked by transport error type

The real HTTP stack can raise a socket/HTTP-client exception. The engine treated
these as fatal errors while the controller intentionally permits durable offline
decisions only for its offline state. Synthetic CloudFailure fixtures hid this
boundary mismatch. The local fix classifies known transport failures as offline
and emits a generic interrupted-connection notice without URLs/tokens. It does
not change FormatException/security failures or permit stale/invalid reviews.
Both socket and HTTP-client exception cases now save bulk decisions, restart,
upload and converge; new divergence is still detected. This is not in beta 8.

## Confirmed beta 8 issue: interrupted upload can block exchange

A lost response after Drive stores ciphertext but before the final metadata
PATCH leaves an object without `verified=true`. Retrying preserves exact batch
bytes but creates another cloud object; the old object blocks receiving history
forever under the published beta's metadata checks. Initial workspace proof
creation has the same failure window. This is a confirmed local provider-contract
defect affecting published beta 8 code, not a claimed real-Drive reproduction.
No data loss was observed: local journal, keys and encrypted objects remain.

The local fix treats the mutable sender readback flag as transport metadata.
Receivers still require account/workspace/protocol/object identity, byte length,
digest, AES-GCM authentication, authenticated batch/device identity, schema and
causal/relational validation. Only persisted authenticated receipts allow a cache
hit. Outgoing acknowledgement still requires provider readback verification and
the flag. No encryption/format/schema/migration or cloud deletion is introduced.
Wrong recovery codes and tampered ciphertext must remain rejected. This fix is
**not in the published beta**; old clients retain their blocking behavior.

## Runtime/UI coverage

Ultimate UI/UX Audit/Fix scope is Sync status, setup/authorization, advanced
settings and conflict review on Windows/Android; adjacent navigation, themes,
large text, IME, keyboard, resizing and semantics are relevant. Host renders,
native runtime and physical input are separate evidence levels. No full-app
audit or assistive-technology compliance claim is intended.

| Surface / state | Evidence and execution status |
| --- | --- |
| Android published disconnected Sync | INSPECTED_PASS actual production APK, fresh API-35 x64/4 KiB guest, 320x640, light/dark and system 200% text. Screenshots inspected: readable wrapping, visible connection action/Close; Close operated. No Google connect action performed |
| Android connected/syncing/success/offline/auth/recovery/conflict variants | INSPECTED_PASS host widget/controller cases in 635-test suite, including large text, IME inset, confirmation, semantics and privacy. NOT_TESTED as actual authenticated Android UI; no test account |
| Windows published installer/portable startup | INSPECTED_PASS actual fresh Windows Sandbox process/SQLite/install/upgrade preservation; GUI is separately UNVERIFIED |
| Corrected Windows Debug Sync | INSPECTED_PASS actual C Debug build/Driver, isolated APPDATA/LOCALAPPDATA and schema-26 quick_check. Settings > Sync inspected at 1264x681 in dark/light; disabled Drive configuration is explicit/expected. Real hot reload/restart PASS, light theme retained after restart, runtime diagnostics clear. This is newer local source, not published Release |
| Windows native keyboard/DPI/resizing/assistive technology | NOT_TESTED. Native Computer Use kernel initialization fails identically after reset/retry and alternate entry. Flutter Driver recovered the app inspection scope, not physical Windows input |
| Screen reader, physical ARM64/OEM, energy consumption | NOT_TESTED; requires target devices/assistive technology and controlled measurements |

## Completed automated and artifact verification

| Check | Outcome / exact scope |
| --- | --- |
| Full current-source serial Flutter suite | **635 PASS, one existing opt-in native-service skip**, exit 0; 1180.43s wall, 18:46 reported test duration. Real-file crash rollback, schema/startup, backup/encryption/recovery, conflict/concurrency, UI and platform-adapter tests included. Expected test warnings are retained; a green suite is not physical acceptance |
| Final analysis | Four roots `lib test integration_test test_driver`: no issues, direct pinned Dart. Initial 33.49s run had only the subsequently corrected test braces info; final copied-identical SDK run 69.60s clean. No Flutter-wrapper analysis pass claimed |
| Formatting | 313 files, zero changes; final brace-only correction formats unchanged and has clean targeted analysis. No assertion or runtime change after full-suite freeze |
| Python helpers | Eight verification helpers, 11 Android preparation checks and three new Sandbox preparation checks PASS. Focused Full-plan assertion PASS after adding the Sandbox gate; sync catalog includes the new adapter contract test |
| Published beta artifacts | All 11 hashes/public/updater/signing proofs reused from publication; no artifact replaced. Fresh actual Windows Sandbox and API-35 APK checks described above are against `dd36189`, not local fixes |
| Android fresh runtime | Existing production x64 APK code 31, nondebuggable, installed in fresh `SmartSyncVerification` AVD; app rendered, startup crash buffer empty, real disconnected Sync/close/theme/large-text inspected. Existing 16 KiB code-30-to-31 data-preserving upgrade remains separate valid evidence |
| Real Drive | **NOT TESTED**: no disposable account/workspace. Adapter requests/encrypted exchange use a synthetic MockClient transport; OAuth refresh, permissions, account pinning and rate responses have local contract coverage only |

Local application fix commit: `e7eedc1` (`fix(sync): authenticate interrupted
uploads and retain offline decisions`). Harness commit: `9fe20f5`.
No version, signing identity, schema, protocol, backup format or release tag was
changed. No push/merge/publication performed in this task.

### Remaining invocation details

| Invocation / reason | Result |
| --- | --- |
| Final test-only analysis after ordered copy/brace correction | PASS no issues; earlier pending copy had overwritten the first brace fix, so that diagnostic was retained and corrected without altering assertions |
| Full-source direct analysis with private SDK copy | PASS no issues in 69.60s; 587.72 MiB pinned SDK copied read-only from original, executable SHA-256 equal. Emulator was active, so this is not a controlled speedup comparison; original SDK unchanged |
| Quiet flush samples after suite/Sandbox/inventory stopped | C 0.03624/0.00262/0.00263s; D 0.18856/0.11399/0.21680s. AVD boot had just started; no claim of perfectly idle hardware |
| Fresh AVD and first probe | Brand-new C profile, no snapshots/wipe/account. First probe stopped on transient ADB offline before app installation; guest finished initial boot in 149.30s. Corrected bounded wait reuses the same guest, no data reset |
| APK probe and UI navigation | PASS package hash/code/SDK identity, home, startup crash buffer, More > Settings > Sync, light/dark/200% screenshots, Close. No Google consent/password/credential UI operated. Owned emulator stopped via guarded AVD identity; profile retained |
| Hot reload before Debug launch | Connected IDE DTD, no active app; tool executed but no reload pass. Corrected-source Debug launch is recorded separately below |
| Corrected Windows Debug build/run and Driver | PASS `flutter run --no-pub -d windows --target lib/driver_main.dart --machine` in isolated C environment. Verified actual executable/profile before Driver input. DTD attached; hot reload PASS; Settings/Sync dark/light screenshots inspected; hot restart PASS and light theme persisted. First immediate post-restart Driver call saw unregistered extension; re-observed DTD/healthy Driver after initialization, then screenshot succeeded. No runtime errors reported |
| Final archive/identity/cleanup | PASS explicit non-secret C logs copied to ignored task ledger, normalized hashes of all four changed application files and the contract test match committed source. Debug profile quick_check/schema/theme pass after stopping only verified task executables. Original owner widget retained; emulator/Sandbox stopped, synthetic profiles/evidence retained. DTD had already closed with the Flutter tool |
| Final docs/catalog/diff checks | PASS zero link/catalog errors and no whitespace errors; documentation-only follow-up does not invalidate frozen-source test/build results |

## Build/test slowdown findings and scoped corrections

The repository inventory is about **90.3 GB decimal** (84.1 GiB), higher than
the historical 74 GB estimate. Approximately **70% is `.buildlog`**, including
SDKs, retained builds/packages, fixtures and evidence. This is not all disposable
cache. Ordinary source search and analyzer exclusions already exclude generated
trees. Size alone was not established as the cause of tool startup stalls.

Measured causes/constraints:

1. D is a USB StoreJet volume; C is NVMe. Its flush latency was consistently
   higher in both sets, with a 40.9s outlier under load. Native metadata inventory
   of `.buildlog` took 269s. Slow durable writes/metadata are a credible mechanism
   for SQLite, Git, compiler and generated-output stalls; no failing hardware or
   antivirus interference was diagnosed.
2. Free RAM fell from several GiB to **313 MiB** while Sandbox overlapped early
   full-test startup, then recovered to **4.10 GiB** after owned runtime shutdown.
   That overlap is recorded, not a clean performance baseline. Earlier history
   also recorded extreme free-space/RAM pressure; those measurements are dated.
3. Flutter analysis initialization stalled while direct Dart analysis completed.
   A direct Dart version call took 0.181s versus Flutter version 10.179s. There is
   no traced Flutter-tool stack proving a specific internal deadlock. Direct
   root analysis is a verified fallback, not a repaired Flutter-wrapper claim.

Corrections applied: use an isolated persistent C checkout and C temporary
profiles/output, retain locked dependencies and existing caches, use the existing
generated plugin-junction workaround, run heavy platform checks sequentially,
and use direct pinned Dart roots when the Flutter analyzer wrapper stalls.
The full suite now completes. Cold compilation/warm caches, disk placement and
memory overlap differ between runs; no unsupported percentage speedup is claimed.
No cache/history/evidence/key/database deletion, Defender exclusion, global SDK
upgrade or machine-setting change was performed. Keep the original D checkout
and retained evidence; any future space reclamation needs a reviewed inventory.

The private Dart SDK copy did not establish a controlled analyzer speedup:
69.60s under the later workload versus the earlier 33.49s run. The source-copy,
temporary-output and sequential-workload corrections are retained; no claim
that copying the SDK itself fixes Flutter initialization is made.

## Requirement coverage and remaining manual acceptance

| Requirement | Strongest completed evidence / remaining boundary |
| --- | --- |
| Task/event create/edit/complete/delete, both directions | New real-provider/SQLite/encrypted two-device contracts; preferences allowlist and local-only rejection. Actual Windows-to-phone Drive transfer NOT TESTED |
| Different-record/concurrent same-record/deletion edits | Full repository/domain suite, relational/recurrence/CAS safety and retained conflicts. Real simultaneous network devices remain manual |
| Upload/download interruption, repeated retries, duplicate prevention | New lost-HTTP-reply/failed-media/rate-limit/restart contracts; authenticated duplicate batch IDs applied once. Actual process kill during live cloud exchange remains manual |
| Stale revisions/change cursor/offline histories | Full suite: failed pages do not advance durable cursor, 410 rescans retained facts, causal holes/leases/process-death rollback. Long-duration real-device offline behavior NOT TESTED |
| Individual/bulk decisions and persistence | Original individual both-direction/concurrent choices plus new bulk both-direction offline/restart contracts; resolved conflicts disappear, genuine new divergence appears. Live Google upload/second physical device remains manual |
| Icon/count/values/confirmation/semantics | Full UI tests; actual authenticated icons/conflict UI on Windows/Android NOT TESTED without fixture account/runtime tooling |
| Automatic opportunities | Full engine/controller tests: startup, active polling, foreground throttle, debounce, in-flight/manual coalescing, metadata-only no loop, lock/account/automatic opt-out, budget/privacy fencing. Physical OS lifecycle/Doze/force-stop/battery timing NOT TESTED |
| OAuth/token restore/401/permission/quota/account switch | Full local auth/adapter contracts and public bundled config checks; actual Google sign-in/refresh/Drive requests NOT TESTED. Normal published users have no developer-client-ID/configuration-import requirement |
| Schema/protocol/keys/backups/mixed clients | Schema 26/protocol 1/encryption and backup formats unchanged; full migrations/recovery/crash regressions. No mixed old/new physical cloud acceptance. Older clients still contain the interrupted-object blocking defect |

The corrected application has a fresh Windows Debug build/runtime pass. A new
production Windows Release/Android APK containing these fixes was not packaged
or published. Android native/runtime checks above use the exact published APK;
shared corrected logic is covered by the current-source host integration suite.
Future fixed-release packaging/device gates remain required.

### Precise disposable-account procedure

Use two disposable profiles, an explicitly authorized test Google account and
synthetic records; preserve an external verified backup. Record app versions,
OS/ABI, action/time and expected/actual synthetic IDs/results. Never record
passwords, callback URLs, bearer tokens, vault contents or the recovery code.

1. First Windows profile: press Sync and follow normal bundled Google sign-in.
   Record any consent/branding/permission rejection, without bypassing warnings.
   Confirm initial encrypted workspace setup and local recovery snapshot. Save
   the recovery code privately. No developer credentials should be requested.
2. Android: select the same test account. Confirm existing workspace discovery,
   refusal of a deliberately wrong recovery code without local data replacement,
   then one-time authorization using the real code. Restart both; authorization
   and keys should persist without another code request. OAuth alone must not
   recover a lost encryption key.
3. Windows -> Android, then reverse: create/edit/complete/delete uniquely named
   tasks; create/edit/delete events; change theme/first weekday. Wait for an actual
   completed exchange, compare IDs/fields/deletions, then cold-restart both.
   Keep window geometry, startup/notification/privacy policy device-local.
4. Separately observe startup, foreground after >15s, active two-minute polling,
   750ms local debounce and connectivity restoration. Record observed delivery
   rather than assuming those intervals guarantee OS background execution.
5. Offline, edit two independent records and the same field on both devices;
   also delete on one while editing on the other. Reconnect, inspect counted
   icon/competing values, resolve individually and in bulk with confirmation on
   either device. Sync/restart both; old conflict stays resolved and a new later
   divergence still raises attention. Repeat offline decisions and simultaneous
   agreeing/disagreeing decisions. Never delete cloud history to hide a conflict.
6. With disposable data only, interrupt connectivity during upload/download and
   close/reopen an app during exchange. Pending journal/key/record IDs must remain,
   retries must converge without duplicate records, and successful timestamps
   must not advance for failed exchanges. Explicitly test old/new clients only
   after a fixed build is authorized; published beta 8 still has the two defects.
7. Disconnect/reconnect the test account normally; verify key/history retention.
   In the disposable paired profile with synthetic queued edits, attempt another
   disposable account and confirm mismatch blocks sending that history and
   preserves the original key/pending edits. Use a separate fresh profile to test
   the other account independently. Token expiry/refresh and revoked-permission
   behavior need actual API evidence.
8. Keep snapshot backup acceptance separate: export/verify, reject wrong phrase,
   cancel restore without replacing sentinel data, then reviewed restore/restart
   with Before Restore retained. A restored sync profile must require explicit
   reconciliation. Do not prune historical backups for these tests.

Actual 403/quota/429, cloud-side immutable storage/encryption, long offline spans,
OEM restrictions, Windows focus/DPI/keyboard and physical screen-reader checks
remain open. Do not intentionally exhaust quota or create infrastructure costs;
use authorized controlled faults or record naturally occurring errors in a
future live-provider run. Local synthetic cases are not substitutes for that pass.

## GitHub download counts without telemetry

The existing Releases API exposes `assets[].download_count`. This task's beta 8
query observed two downloads per installer/portable/APK: Windows packages total
4, Android APKs total 6 at that query. These include verification activity and
are not installs, unique people or unique devices. Exclude notes/manifests/hash
sidecars when counting platform packages; universal/ABI APK counts overlap users.

```powershell
$release = gh api repos/2HIK4/Todorbit/releases/tags/v1.0.19-beta.8 | ConvertFrom-Json
$release.assets | Select-Object name,download_count
($release.assets | Where-Object name -match '-win-x64-(setup\.exe|portable\.zip)$' |
  Measure-Object download_count -Sum).Sum
($release.assets | Where-Object name -match '-android-(arm64|x64|universal)\.apk$' |
  Measure-Object download_count -Sum).Sum
```

Repeat per published release (or enumerate `/releases?per_page=100` with API
pagination). No tracking SDK, user identifiers, telemetry or statistics server is
needed or added.

## Readiness recommendation

**Keep beta 8 experimental; it is not ready for broader promotion.** Two confirmed
availability/reliability defects are fixed locally, not shipped. No corruption,
key loss or encryption bypass was observed in the completed scope, but live Drive
exchange and physical/mixed-client acceptance remain incomplete. A future fixed
release requires explicit authorization, new exact-source platform/package gates
and the outstanding real-provider checks; this task does not publish one.
