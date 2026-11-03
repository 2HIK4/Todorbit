# Smart Sync implementation ledger

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
| Full `20261103-152615-8466` | Frozen code patch SHA-256 `ac0457e8098cce473d00bb7a1b202e26aeb2f797a091eb6cecce76e714d8886b` against `eee62a6` | Format (311 files) and full analysis PASS; serial suite running | Rerun after override correction and environment isolation. No Dart edits during this run; platform work serialized without emulator load |

Orchestration checkpoint: setup continuation, secure retained-binding key recovery,
active polling at two minutes, 15-second resume throttle, 750-ms local debounce,
in-flight follow-up and offline resolution queue pass focused verification.
No protocol/schema change. UI changes remain under implementation and are not
covered by the 19-test orchestration receipt.

Integration review additionally traced the Windows database watcher: lease/cursor
writes also refresh the controller. Both scheduling boundaries now require actual
pending journal operations before treating a notification as an upload trigger.
The engine checks again after debounce, so already-uploaded edits do not cause a
second network exchange. Native writer edits still queue normally. This new
correction invalidates earlier scheduling evidence; current engine/controller
checks must include metadata-only notifications and a commit arriving after the
outgoing pass while download is in flight.

Next: finish the frozen-source serial suite, verify the current engine's
metadata-only/follow-up paths, complete feasible platform builds/runtime probes,
and finalize results. No push, merge or publication authorized.
